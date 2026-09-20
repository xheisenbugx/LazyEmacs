;;; early.el --- Options loaded before packages and modules -*- lexical-binding: t; -*-
;; Copy to user/early.el. This is NOT Emacs's early-init.el.
(setq lazyemacs-font-height 140
      lazyemacs-fonts '("JetBrainsMono Nerd Font Mono" "DejaVu Sans Mono")
      lazyemacs-enable-recovery t
      lazyemacs-enable-mail nil
      lazyemacs-org-directory (expand-file-name "~/org/"))
;; Optional mail identity (also requires external mu/mbsync/msmtp configuration):
;; (setq lazyemacs-enable-mail t
;;       my/mu4e-user-full-name "Your Name"
;;       my/mu4e-user-mail-address "you@example.com"
;;       my/mu4e-mbsync-channel "default")
