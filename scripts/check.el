;;; check.el --- Offline syntax and public API checks -*- lexical-binding: t; -*-
(let* ((root (file-name-directory (directory-file-name (file-name-directory load-file-name))))
       (state (make-temp-file "lazyemacs-check-" t)))
  (setq user-emacs-directory state)
  (add-hook 'kill-emacs-hook (lambda () (delete-directory state t)))
  (dolist (directory '("." "lisp" "examples" "tests" "scripts"))
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
