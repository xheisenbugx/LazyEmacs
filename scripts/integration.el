;;; integration.el --- Exercise installed packages with disposable state -*- lexical-binding: t; -*-
(let* ((root (file-name-directory (directory-file-name (file-name-directory load-file-name))))
       (state (make-temp-file "lazyemacs-integration-" t))
       (suite (or (getenv "LAZYEMACS_TEST_SUITE") "config-tests.el")))
  (setq user-emacs-directory (file-name-as-directory state)
        package-user-dir (expand-file-name "elpa" root))
  (setenv "LAZYEMACS_USER_DIR" (expand-file-name "user" state))
  (setq treesit-extra-load-path
        (list (expand-file-name "var/treesit" root)
              (expand-file-name "tree-sitter" root)))
  (load (expand-file-name "early-init.el" root) nil t)
  (load (expand-file-name "init.el" root) nil t)
  (unless (and make-backup-files auto-save-default create-lockfiles
               (not (featurep 'init-mail))
               (not (keymap-lookup global-map "C-c M")))
    (error "Distribution recovery or opt-in mail contract failed"))
  ;; Existing suites suppress shutdown state writers.  Clean temporary state
  ;; via advice because those suites intentionally clear kill-emacs-hook.
  (advice-add 'kill-emacs :before (lambda (&rest _) (delete-directory state t)))
  (load (expand-file-name suite (expand-file-name "tests" root)) nil t))
