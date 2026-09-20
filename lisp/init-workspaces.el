;;; init-workspaces.el --- Project tab sessions -*- lexical-binding: t; -*-

;;; Commentary:
;; Project/session behavior lives in the GitHub-hosted package.
;; This module only chooses presentation; shortcuts live in init-keymaps.el.

;;; Code:

(use-package project-tab-sessions
  :vc (:url "https://github.com/xheisenbugx/project-tab-sessions"
       :rev :newest)
  :demand t
  :custom
  (tab-bar-show 1)
  (tab-bar-close-button-show nil)
  (tab-bar-new-tab-choice "*scratch*")
  (tab-bar-new-tab-group t)
  (tab-bar-tab-hints t)
  (tab-bar-format '(project-tab-sessions-format))
  (tab-bar-tab-name-format-function #'project-tab-sessions-tab-name-format)
  (tab-bar-tab-group-format-function #'project-tab-sessions-group-format)
  :config
  (tab-bar-mode 1)
  (tab-bar-history-mode 1)
  (project-tab-sessions-mode 1))

(provide 'init-workspaces)
;;; init-workspaces.el ends here
