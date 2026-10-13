;;; init.el --- Evil Emacs IDE entry point -*- lexical-binding: t; -*-

;;; Commentary:
;; This file is deliberately small.  Each area of the editor lives in a
;; separate, documented module under lisp/, which makes it easy to disable or
;; replace one feature without navigating a monolithic init file.
;;
;; The configuration aims for the conveniences associated with LazyVim and
;; uses Evil as its single modal editing layer.  C-c remains a non-modal alias
;; for the SPC leader hierarchy.

;;; Code:

(unwind-protect
    (progn
      ;; 31.0.90 and later are the 31.1 pretests and release candidates.
      (when (version< emacs-version "31.0.90")
        (error "LazyEmacs requires Emacs 31.1 or newer (31.1 pretests 31.0.90+ also work)"))

      (defconst lazyemacs-root-directory
        (file-name-directory (or load-file-name user-init-file))
        "Directory containing the LazyEmacs distribution.")
      (defconst my/lisp-directory
        (expand-file-name "lisp/" lazyemacs-root-directory))
      (add-to-list 'load-path my/lisp-directory)
      (require 'init-distribution)
      (lazyemacs-load-user-file "early.el")
      ;; Customize's file is loaded twice.  This early load lets the options
      ;; read while modules load (such as `lazyemacs-enable-mail') see saved
      ;; values; the load after the modules below makes saved values win over
      ;; the defaults that `use-package' :custom sets while modules load.
      (setq custom-file (expand-file-name "custom.el" lazyemacs-user-directory))
      (load custom-file 'noerror 'nomessage)
      (require 'init-packages)

      ;; The load order follows dependencies; keymaps come last because they refer to
      ;; commands defined by all preceding feature modules.  A module that fails
      ;; is reported and skipped so the rest, keymaps included, still load
      ;; (see `lazyemacs-require-module').
      (dolist (feature '(init-core
                         init-ui
                         init-completion
                         init-editing
                         init-evil
                         init-navigation
                         init-vcs
                         init-structure
                         init-development
                         init-lsp-booster
                         init-debug
                         init-tools
                         init-tasks
                         init-session
                         init-org
                         init-keymaps
                         init-local-actions
                         init-dashboard))
        (lazyemacs-require-module feature))

      (when lazyemacs-enable-mail
        (lazyemacs-require-module 'init-mail))
      (load custom-file 'noerror 'nomessage)
      (lazyemacs-load-user-file "config.el"))
  (when (fboundp 'my/restore-startup-state)
    (my/restore-startup-state)))

(provide 'init)
;;; init.el ends here
