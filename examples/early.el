;;; early.el --- Options loaded before packages and modules -*- lexical-binding: t; -*-
;; Copy to user/early.el.  This is NOT Emacs's early-init.el: it runs after it,
;; before any LazyEmacs feature module.  Restart Emacs after editing.

(setq lazyemacs-font-height 140
      lazyemacs-fonts '("JetBrainsMono Nerd Font Mono" "DejaVu Sans Mono")
      lazyemacs-dark-theme 'catppuccin
      lazyemacs-light-theme 'modus-operandi-tinted
      lazyemacs-dashboard t
      lazyemacs-enable-recovery t
      lazyemacs-enable-mail nil
      lazyemacs-prefer-tree-sitter t
      lazyemacs-org-directory (expand-file-name "~/org/"))

;; Catppuccin flavor: latte, frappe, macchiato, or mocha.
;; (setq catppuccin-flavor 'macchiato)

;; LSP breadcrumbs, reference highlights, inlay hints, and code lenses.
;; (setq my/lsp-visual-extras t)

;; For an already installed setup: set LAZYEMACS_OFFLINE=1 before launch.

;; Optional mail identity (also requires external mu/mbsync/msmtp configuration):
;; (setq lazyemacs-enable-mail t
;;       my/mu4e-user-full-name "Your Name"
;;       my/mu4e-user-mail-address "you@example.com"
;;       my/mu4e-mbsync-channel "default")
