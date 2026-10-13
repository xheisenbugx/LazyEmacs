;;; check.el --- Offline syntax and public API checks -*- lexical-binding: t; -*-
;;
;; With LAZYEMACS_BYTE_COMPILE=1 this instead byte-compiles every module in
;; lisp/ against the installed packages and fails on any compiler warning.
;; The .elc files go to a temporary directory, never next to the sources.
;; scripts/test.py runs this pass unless --offline-only is given, because it
;; needs the packages in elpa/.
(defun lazyemacs-check-byte-compile (root state)
  "Byte-compile ROOT's lisp/init-*.el into STATE; exit non-zero on warnings."
  (require 'bytecomp)
  ;; Start LazyEmacs first, as the integration suites do.  Modules then
  ;; compile with every package and sibling module loaded, so only genuine
  ;; problems are reported (unknown functions or variables, wrong argument
  ;; counts, obsolete names), not the order in which modules load.
  (setq package-user-dir (expand-file-name "elpa" root))
  (load (expand-file-name "early-init.el" root) nil t)
  (load (expand-file-name "init.el" root) nil t)
  (let* ((output (file-name-as-directory (expand-file-name "elc" state)))
         (byte-compile-dest-file-function
          (lambda (file) (expand-file-name (concat (file-name-base file) ".elc") output)))
         (warnings 0)
         (byte-compile-log-warning-function
          (let ((log byte-compile-log-warning-function))
            (lambda (&rest args)
              (setq warnings (1+ warnings))
              (apply log args))))
         failed)
    (make-directory output t)
    (dolist (file (directory-files (expand-file-name "lisp" root) t "\\`init-.*\\.el\\'"))
      ;; Mail support is optional and needs mu4e from the system's mu.
      (unless (and (string-suffix-p "init-mail.el" file) (not (locate-library "mu4e")))
        (let ((before warnings))
          (unless (and (byte-compile-file file) (= before warnings))
            (push (file-name-nondirectory file) failed)))))
    (if failed
        (progn (message "Byte compilation warnings in: %s" (string-join (nreverse failed) ", "))
               (kill-emacs 1))
      (message "Byte-compiled every module without warnings")
      (kill-emacs 0))))

(let* ((root (file-name-directory (directory-file-name (file-name-directory load-file-name))))
       (state (make-temp-file "lazyemacs-check-" t)))
  (setq user-emacs-directory (file-name-as-directory state))
  (setenv "LAZYEMACS_USER_DIR" (expand-file-name "user" state))
  (setenv "LAZYEMACS_OFFLINE" "1")
  (add-hook 'kill-emacs-hook (lambda () (delete-directory state t)))
  (when (getenv "LAZYEMACS_BYTE_COMPILE")
    (lazyemacs-check-byte-compile root state))
  (dolist (directory '("." "lisp" "lisp/extras" "examples" "tests" "scripts"))
    (dolist (file (directory-files (expand-file-name directory root) t "\\.el\\'"))
      (with-temp-buffer
        (insert-file-contents file)
        (emacs-lisp-mode)
        (check-parens)
        (goto-char (point-min))
        (condition-case nil
            (while t (read (current-buffer)))
          (end-of-file nil)))))
  (add-to-list 'load-path (expand-file-name "lisp" root))
  (load (expand-file-name "tests/distribution-tests.el" root) nil t))
