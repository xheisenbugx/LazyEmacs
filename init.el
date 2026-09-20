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

(when (version< emacs-version "31.1")
  (error "LazyEmacs requires Emacs 31.1 or newer (including 31.1 development builds)"))

(defconst lazyemacs-root-directory
  (file-name-directory (or load-file-name user-init-file))
  "Directory containing the LazyEmacs distribution.")
(defconst my/lisp-directory
  (expand-file-name "lisp/" lazyemacs-root-directory))
(add-to-list 'load-path my/lisp-directory)
(require 'init-distribution)
(lazyemacs-load-user-file "early.el")
(require 'init-packages)
(setq custom-file (expand-file-name "custom.el" lazyemacs-user-directory))
(load custom-file 'noerror 'nomessage)

;; The load order follows dependencies; keymaps come last because they refer to
;; commands defined by all preceding feature modules.
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
                   init-tools
                   init-tasks
                   init-session
                   init-org
                   init-keymaps
                   init-local-actions))
  (require feature))

(when lazyemacs-enable-mail
  (require 'init-mail))
(lazyemacs-load-user-file "config.el")

(provide 'init)
;;; init.el ends here
