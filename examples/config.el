;;; config.el --- Personal packages, keys, and overrides -*- lexical-binding: t; -*-
;; Copy to user/config.el.  It loads last, after every LazyEmacs module.
;; Keep distribution files unmodified so `git pull' updates cleanly.

;; Settings for packages that load later belong in `with-eval-after-load'.
(with-eval-after-load 'org
  (setq org-log-done 'time))

;; Add keys to the leader.  The string is what Which Key shows.
;; (keymap-set my/leader-map "z" '("Zen mode" . olivetti-mode))
;; (keymap-set my/leader-git-map "t" '("Time machine" . git-timemachine))

;; Add a package, like a file in LazyVim's lua/plugins/.
;; (use-package olivetti
;;   :commands olivetti-mode)

;; Format on save everywhere (SPC u f toggles it per session).
;; (apheleia-global-mode 1)

;; Start a language server automatically for another language.
;; (add-hook 'java-ts-mode-hook #'my/lsp-start)

;; (keymap-global-set "<f5>" #'recompile)
;; (with-eval-after-load 'mu4e
;;   (setq mu4e-sent-folder "/Sent"
;;         mu4e-drafts-folder "/Drafts"
;;         mu4e-trash-folder "/Trash"
;;         mu4e-refile-folder "/Archive"))
