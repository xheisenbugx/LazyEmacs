;;; config.el --- User overrides loaded after modules -*- lexical-binding: t; -*-
;; Copy to user/config.el. Keep distribution modules unmodified for easy updates.
;; Delayed packages need delayed overrides:
(with-eval-after-load 'org
  (setq org-log-done 'time))
;; (keymap-global-set "<f5>" #'recompile)
;; (with-eval-after-load 'mu4e
;;   (setq mu4e-sent-folder "/Sent"
;;         mu4e-drafts-folder "/Drafts"
;;         mu4e-trash-folder "/Trash"
;;         mu4e-refile-folder "/Archive"))
