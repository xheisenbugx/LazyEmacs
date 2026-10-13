;;; init-doctor.el --- Extra sections for the LazyEmacs doctor -*- lexical-binding: t; -*-

;;; Commentary:
;; `lazyemacs-doctor' (SPC h D) lives in init-distribution.el so it works even
;; when a feature module fails.  The sections here need the feature modules:
;; modules that failed to load, formatter and language-server executables per
;; language, and stale session locks.  Like the rest of the doctor they only
;; look: no process is launched and nothing is installed.

;;; Code:

(require 'seq)
(require 'subr-x)
(require 'init-distribution)

(defvar apheleia-mode-alist)
(defvar apheleia-formatters)

(defconst lazyemacs-doctor-languages
  '(("Python" (python-ts-mode python-mode)
     ("basedpyright-langserver" "pyright-langserver" "pylsp"))
    ("TypeScript/JavaScript" (typescript-ts-mode typescript-mode js-ts-mode)
     ("typescript-language-server"))
    ("Go" (go-ts-mode go-mode) ("gopls"))
    ("Rust" (rust-ts-mode rust-mode) ("rust-analyzer"))
    ("JSON" (json-ts-mode js-json-mode) ("vscode-json-language-server"))
    ("CSS" (css-ts-mode css-mode) ("vscode-css-language-server"))
    ("HTML" (html-ts-mode mhtml-mode html-mode) ("vscode-html-language-server"))
    ("YAML" (yaml-ts-mode yaml-mode) ("yaml-language-server"))
    ("Dockerfile" (dockerfile-ts-mode dockerfile-mode) ("docker-langserver"))
    ("Lua" (lua-ts-mode lua-mode) ("lua-language-server"))
    ("Shell" (bash-ts-mode sh-mode) ("bash-language-server"))
    ("C/C++ (lang-clangd extra)" (c-ts-mode c-mode) ("clangd")))
  "Languages checked by the doctor as (NAME MODES SERVERS).
SERVERS mirror `my/language-server-available-p'; any one of them is enough.
Formatters are looked up in Apheleia's configuration for MODES.")

(defun lazyemacs-doctor--formatters (modes)
  "Return Apheleia's formatter executables for the first of MODES it knows."
  (when (and (boundp 'apheleia-mode-alist) (boundp 'apheleia-formatters))
    (when-let* ((formatter (seq-some (lambda (mode) (alist-get mode apheleia-mode-alist)) modes)))
      (delete-dups
       (seq-keep (lambda (name)
                   ;; Commands are lists like ("prettier" ...) or ("apheleia-npx"
                   ;; "prettier" ...), whose wrapper ships with Apheleia.  Lisp
                   ;; formatters have no executable to check.
                   (let ((command (alist-get name apheleia-formatters)))
                     (when (consp command)
                       (seq-find (lambda (part)
                                   (and (stringp part) (not (string-prefix-p "apheleia-" part))))
                                 command))))
                 (ensure-list formatter))))))

(defun lazyemacs-doctor--executables (names)
  "Describe which of NAMES are installed, or say none are needed."
  (if (null names)
      "-"
    (mapconcat (lambda (name) (format "%s %s" name (if (executable-find name) "ok" "MISSING")))
               names ", ")))

(defun lazyemacs-doctor-language-section ()
  "Print formatter and language-server availability for each language."
  ;; Apheleia's tables are plain data; loading the library starts nothing.
  (require 'apheleia nil t)
  (princ "\nLanguage tooling (formatter | language server; one server suffices)\n")
  (pcase-dolist (`(,name ,modes ,servers) lazyemacs-doctor-languages)
    (princ (format "%-26s %s | %s\n" name
                   (lazyemacs-doctor--executables (lazyemacs-doctor--formatters modes))
                   (lazyemacs-doctor--executables servers)))))

(defun lazyemacs-doctor-failed-modules-section ()
  "Print the modules that failed to load during startup, if any."
  (princ "\nModule loading\n")
  (if-let* ((failed (bound-and-true-p lazyemacs-failed-modules)))
      (dolist (entry failed)
        (princ (if (consp entry)
                   (format "FAILED %s: %s\n" (car entry)
                           (if (stringp (cdr entry)) (cdr entry) (format "%S" (cdr entry))))
                 (format "FAILED %s\n" entry))))
    (princ "All modules loaded.\n")))

(defun lazyemacs-doctor--lock-pid (file)
  "Return the process id recorded in session lock FILE, or nil."
  (when-let* ((text (or (file-symlink-p file)
                        (ignore-errors
                          (with-temp-buffer (insert-file-contents file) (buffer-string))))))
    ;; Emacs-style locks read user@host.PID:boot; plain locks contain the pid.
    (when (or (string-match "\\.\\([0-9]+\\)\\(?::\\|\\'\\)" text)
              (string-match "\\([0-9]+\\)" text))
      (string-to-number (match-string 1 text)))))

(defun lazyemacs-doctor-session-locks-section ()
  "Print session lock files with their owning process, when sessions are on."
  (when-let* ((directory (bound-and-true-p lazyemacs-sesh-directory))
              ((file-directory-p directory)))
    (princ "\nSession locks\n")
    (let ((locks (directory-files directory t "\\.lock\\'")))
      (unless locks (princ "No session is locked.\n"))
      (dolist (file locks)
        (let ((pid (lazyemacs-doctor--lock-pid file)))
          (princ (format "%-30s pid %-8s %s\n" (file-name-nondirectory file)
                         (or pid "?")
                         (cond ((null pid) "unknown owner")
                               ((eql pid (emacs-pid)) "this Emacs")
                               ((process-attributes pid) "running")
                               (t "STALE (process gone; safe to delete)")))))))))

(add-hook 'lazyemacs-doctor-sections #'lazyemacs-doctor-failed-modules-section -90)
(add-hook 'lazyemacs-doctor-sections #'lazyemacs-doctor-language-section)
(add-hook 'lazyemacs-doctor-sections #'lazyemacs-doctor-session-locks-section 30)

(provide 'init-doctor)
;;; init-doctor.el ends here
