;;; init-extras.el --- Optional feature bundles (LazyVim's LazyExtras) -*- lexical-binding: t; -*-

;;; Commentary:
;; An extra is one file in lisp/extras/ that turns on something LazyEmacs does
;; not do by default: format on save, camelCase word motions, a language, and
;; so on.  Its first line is its description, exactly like any Emacs package.
;;
;; There are two ways to enable extras, and both are kept:
;;
;; - `M-x lazyemacs-extras' (also `SPC l x' and the dashboard's `x') lists
;;   every extra and toggles them, like LazyVim's :LazyExtras.  The selection
;;   is data in user/extras.eld, so nothing edits your Lisp files.
;; - `lazyemacs-extras' in user/early.el, for selections kept with the rest of
;;   your configuration (for example in a dotfiles repository).
;;
;; Extras load after every LazyEmacs module and before user/config.el, so they
;; may adjust any module and your config.el may still override them.  A broken
;; extra is reported as a warning and never stops startup.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'lisp-mnt)
(require 'init-distribution)

(defcustom lazyemacs-extras nil
  "Extras to load, as symbols naming files in lisp/extras/.
Set this in user/early.el.  Extras enabled with `M-x lazyemacs-extras' are
stored in user/extras.eld and load in addition to these."
  :type '(repeat symbol) :group 'lazyemacs)

(defvar lazyemacs-extras-directory
  (expand-file-name "extras/" (file-name-directory (or load-file-name buffer-file-name)))
  "Directory containing the extras shipped with LazyEmacs.")

(add-to-list 'load-path lazyemacs-extras-directory)

(defvar lazyemacs-extras-loaded nil
  "Extras loaded in this session, most recent first.")

(defvar lazyemacs-failed-extras nil
  "Extras that signaled an error while loading, as (NAME . ERROR-MESSAGE).")

(defun lazyemacs-extras-file ()
  "Return the file that stores extras toggled with `lazyemacs-extras'."
  (expand-file-name "extras.eld" lazyemacs-user-directory))

;;; Discovery

(defun lazyemacs-extras-available ()
  "Return every shipped extra as (NAME . DESCRIPTION), sorted by name."
  (mapcar (lambda (file)
            (cons (intern (file-name-base file))
                  (or (lm-summary file) "")))
          (directory-files lazyemacs-extras-directory t "\\`[^.].*\\.el\\'")))

(defun lazyemacs-extras--check (name)
  "Signal a clear error unless NAME is a shipped extra."
  (unless (assq name (lazyemacs-extras-available))
    (user-error "Unknown LazyEmacs extra `%s'; available: %s" name
                (mapconcat (lambda (extra) (symbol-name (car extra)))
                           (lazyemacs-extras-available) ", "))))

;;; The saved selection

(defun lazyemacs-extras-saved ()
  "Return the extras stored in user/extras.eld."
  (let ((file (lazyemacs-extras-file)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (let ((data (ignore-error end-of-file (read (current-buffer)))))
          (unless (and (listp data) (seq-every-p #'symbolp data))
            (user-error "%s should contain a list of extra names" file))
          data)))))

(defun lazyemacs-extras-save (names)
  "Store NAMES as the extras toggled interactively, in user/extras.eld."
  (make-directory (file-name-directory (lazyemacs-extras-file)) t)
  (with-temp-file (lazyemacs-extras-file)
    (insert ";; LazyEmacs extras enabled with M-x lazyemacs-extras.  -*- mode: lisp-data; -*-\n"
            (let ((print-length nil)) (prin1-to-string (sort (copy-sequence names) #'string<)))
            "\n")))

(defun lazyemacs-extras-enabled ()
  "Return every enabled extra: `lazyemacs-extras', then the saved selection."
  (delete-dups (append lazyemacs-extras (lazyemacs-extras-saved))))

;;; Loading

(defun lazyemacs-extras-load (name)
  "Load extra NAME now; signal an error if no such extra exists."
  (lazyemacs-extras--check name)
  (load (expand-file-name (symbol-name name) lazyemacs-extras-directory) nil 'nomessage)
  (cl-pushnew name lazyemacs-extras-loaded))

(defun lazyemacs-load-extras ()
  "Load every enabled extra, reporting failures without stopping startup."
  (dolist (name (condition-case err (lazyemacs-extras-enabled)
                  (error (display-warning 'lazyemacs (error-message-string err) :error)
                         lazyemacs-extras)))
    (condition-case err
        (lazyemacs-extras-load name)
      (error
       (push (cons name (error-message-string err)) lazyemacs-failed-extras)
       (display-warning 'lazyemacs
                        (format "Extra `%s' was not loaded: %s" name (error-message-string err))
                        :error)))))

(defun lazyemacs-extras-toggle (name)
  "Enable extra NAME, or disable it if enabled, and save the selection.
Enabling loads the extra immediately; disabling takes effect after a restart.
Return non-nil when NAME is now enabled."
  (lazyemacs-extras--check name)
  (let ((saved (lazyemacs-extras-saved)))
    (cond ((memq name lazyemacs-extras)
           (user-error "`%s' is enabled by `lazyemacs-extras' in user/early.el; remove it there" name))
          ((memq name saved)
           (lazyemacs-extras-save (delq name saved))
           (message "Disabled extra `%s'; restart Emacs to unload it" name)
           nil)
          (t
           (lazyemacs-extras-save (cons name saved))
           (condition-case err
               (progn (lazyemacs-extras-load name)
                      (message "Enabled extra `%s'" name))
             (error (message "Enabled extra `%s'; it loads after a restart (%s)"
                             name (error-message-string err))))
           t))))

;;; The extras browser

(defun lazyemacs-extras--entries ()
  "Return `tabulated-list-entries' for the extras browser."
  (let ((enabled (lazyemacs-extras-enabled)))
    (mapcar (pcase-lambda (`(,name . ,description))
              (list name
                    (vector (cond ((memq name lazyemacs-extras) "● early.el")
                                  ((memq name enabled)
                                   (if (memq name lazyemacs-extras-loaded) "● enabled" "● restart"))
                                  ((memq name lazyemacs-extras-loaded) "○ restart")
                                  (t "○"))
                            (symbol-name name)
                            description)))
            (lazyemacs-extras-available))))

(defvar-keymap lazyemacs-extras-mode-map
  :doc "Keys for `lazyemacs-extras-mode'."
  "x" #'lazyemacs-extras-toggle-at-point
  "RET" #'lazyemacs-extras-toggle-at-point
  "o" #'lazyemacs-extras-visit)

(define-derived-mode lazyemacs-extras-mode tabulated-list-mode "Extras"
  "Major mode listing LazyEmacs extras.
\\<lazyemacs-extras-mode-map>\\[lazyemacs-extras-toggle-at-point] toggles the extra at point; \\[lazyemacs-extras-visit] opens its source."
  (setq tabulated-list-format [("State" 11 t) ("Extra" 26 t) ("Description" 0 nil)]
        tabulated-list-entries #'lazyemacs-extras--entries)
  (tabulated-list-init-header))

(with-eval-after-load 'evil
  (evil-set-initial-state 'lazyemacs-extras-mode 'emacs))

(defun lazyemacs-extras ()
  "List LazyEmacs extras and toggle them, like LazyVim's :LazyExtras."
  (interactive)
  (let ((buffer (get-buffer-create "*LazyEmacs Extras*")))
    (with-current-buffer buffer
      (lazyemacs-extras-mode)
      (tabulated-list-print))
    (pop-to-buffer buffer)
    (message "x or RET toggles an extra; o opens its source")
    buffer))

(defun lazyemacs-extras-toggle-at-point ()
  "Toggle the extra on the current line."
  (interactive)
  (if-let* ((name (tabulated-list-get-id)))
      (progn (lazyemacs-extras-toggle name)
             (tabulated-list-print t))
    (user-error "No extra on this line")))

(defun lazyemacs-extras-visit ()
  "Open the source of the extra on the current line."
  (interactive)
  (if-let* ((name (tabulated-list-get-id)))
      (find-file-read-only (expand-file-name (format "%s.el" name) lazyemacs-extras-directory))
    (user-error "No extra on this line")))

;;; Doctor

(defun lazyemacs-extras-doctor-section ()
  "Print enabled and failed extras for `lazyemacs-doctor'."
  (princ (format "\nExtras (M-x lazyemacs-extras)\nEnabled: %s\n"
                 (if-let* ((enabled (ignore-errors (lazyemacs-extras-enabled))))
                     (mapconcat #'symbol-name enabled " ")
                   "none")))
  (pcase-dolist (`(,name . ,message) lazyemacs-failed-extras)
    (princ (format "FAILED %s: %s\n" name message))))

(add-hook 'lazyemacs-doctor-sections #'lazyemacs-extras-doctor-section 20)

(provide 'init-extras)
;;; init-extras.el ends here
