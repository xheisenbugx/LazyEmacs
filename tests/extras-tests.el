;;; extras-tests.el --- Optional extras (LazyExtras) -*- lexical-binding: t; -*-
(require 'ert)
(require 'cl-lib)
(require 'init-extras)

(defmacro lazyemacs-extras-test--with-user-dir (&rest body)
  "Run BODY with a temporary private directory and no enabled extras."
  (declare (indent 0))
  `(let ((lazyemacs-user-directory (make-temp-file "lazyemacs-extras-user-" t))
         (lazyemacs-extras nil)
         (lazyemacs-extras-loaded nil)
         (lazyemacs-failed-extras nil))
     (unwind-protect (progn ,@body)
       (ignore-error permission-denied (delete-directory lazyemacs-user-directory t)))))

(ert-deftest lazyemacs-extras/discovery-lists-descriptions ()
  (let ((available (lazyemacs-extras-available)))
    (dolist (name '(coding-format-on-save editor-subword ui-relative-numbers ui-zen lang-clangd))
      (should (assq name available))
      (should (> (length (alist-get name available)) 10)))
    (should (equal (alist-get 'editor-subword available)
                   "CamelCase-aware word motions and edits"))))

(ert-deftest lazyemacs-extras/unknown-extra-errors-clearly ()
  (lazyemacs-extras-test--with-user-dir
    (let ((message (cadr (should-error (lazyemacs-extras-load 'no-such-extra) :type 'user-error))))
      (should (string-match-p "Unknown LazyEmacs extra .no-such-extra." message))
      (should (string-match-p "editor-subword" message)))
    (should-error (lazyemacs-extras-toggle 'no-such-extra) :type 'user-error)
    ;; At startup an unknown extra is reported, not fatal.
    (let ((lazyemacs-extras '(no-such-extra)))
      (cl-letf (((symbol-function 'display-warning) #'ignore))
        (lazyemacs-load-extras))
      (should (assq 'no-such-extra lazyemacs-failed-extras)))))

(ert-deftest lazyemacs-extras/enabling-loads-and-persists ()
  (lazyemacs-extras-test--with-user-dir
    (let ((was-subword global-subword-mode))
      (unwind-protect
          (progn
            (global-subword-mode -1)
            (should (lazyemacs-extras-toggle 'editor-subword))
            (should global-subword-mode)
            (should (memq 'editor-subword lazyemacs-extras-loaded))
            (should (file-exists-p (expand-file-name "extras.eld" lazyemacs-user-directory)))
            (should (equal (lazyemacs-extras-saved) '(editor-subword)))
            ;; The browser shows it as enabled.
            (with-current-buffer (lazyemacs-extras)
              (goto-char (point-min))
              (should (search-forward "editor-subword" nil t))
              (should (string-match-p "enabled" (buffer-substring (line-beginning-position)
                                                                  (line-end-position))))
              (quit-window t))
            ;; Disabling persists and asks for a restart.
            (should-not (lazyemacs-extras-toggle 'editor-subword))
            (should-not (lazyemacs-extras-saved)))
        (global-subword-mode (if was-subword 1 -1))))))

(ert-deftest lazyemacs-extras/early-el-selection-loads-and-is-protected ()
  (lazyemacs-extras-test--with-user-dir
    (let ((lazyemacs-extras '(ui-relative-numbers))
          (display-line-numbers-type display-line-numbers-type))
      (unwind-protect
          (progn
            (lazyemacs-load-extras)
            (should (eq (default-value 'display-line-numbers-type) 'relative))
            (should (equal (lazyemacs-extras-enabled) '(ui-relative-numbers)))
            (should-error (lazyemacs-extras-toggle 'ui-relative-numbers) :type 'user-error))
        (setq-default display-line-numbers-type t)))))

(ert-deftest lazyemacs-extras/every-extra-loads ()
  (lazyemacs-extras-test--with-user-dir
    (let ((was-subword global-subword-mode)
          (lazyemacs-grammars (copy-sequence lazyemacs-grammars))
          (major-mode-remap-alist (copy-sequence major-mode-remap-alist))
          (display-line-numbers-type display-line-numbers-type))
      (unwind-protect
          (dolist (extra (lazyemacs-extras-available))
            (lazyemacs-extras-load (car extra))
            (should (featurep (car extra))))
        (when (bound-and-true-p apheleia-global-mode) (apheleia-global-mode -1))
        (global-subword-mode (if was-subword 1 -1))
        (setq-default display-line-numbers-type t)
        (advice-remove 'my/language-server-available-p #'my/clangd-available-p)))
    (should (eq (keymap-lookup my/leader-ui-map "z") #'my/zen-mode))
    (with-temp-buffer
      (my/zen-mode 1)
      (should-not mode-line-format)
      (my/zen-mode -1)
      (should mode-line-format))))

(ert-deftest lazyemacs-extras/package-keys-and-dashboard ()
  (with-temp-buffer
    (emacs-lisp-mode)
    (evil-local-mode 1)
    (evil-normal-state)
    (dolist (pair '(("SPC l l" . list-packages) ("SPC l u" . lazyemacs-update-packages)
                    ("SPC l r" . lazyemacs-lock-restore) ("SPC l s" . lazyemacs-lock-status)
                    ("SPC l x" . lazyemacs-extras)))
      (should (eq (key-binding (kbd (car pair))) (cdr pair)))))
  (should (eq (keymap-lookup lazyemacs-dashboard-mode-map "x") #'lazyemacs-extras)))

(setq kill-emacs-hook nil)
(ert-run-tests-batch-and-exit "lazyemacs-extras/")
