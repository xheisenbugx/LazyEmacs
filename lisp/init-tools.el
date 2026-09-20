;;; init-tools.el --- Shells, terminals, and remote files -*- lexical-binding: t; -*-

;;; Commentary:
;; Ghostel is the terminal for interactive shells and project commands.

;;; Code:

(defun my/project-ghostel ()
  "Open or reuse a Ghostel terminal rooted at the current project."
  (interactive)
  (require 'ghostel)
  (call-interactively #'ghostel-project))

(defun my/project-ghostel-new ()
  "Start a fresh Ghostel shell at the current project's root every time."
  (interactive)
  (require 'ghostel)
  ;; A non-numeric prefix requests a new terminal instance, never reuse.
  (ghostel-project '(4)))

(defun my/ghostel-toggle ()
  "Show or hide this workspace's Ghostel pane without stopping its shell."
  (interactive)
  (require 'ghostel)
  (require 'tab-bar)
  ;; Store ownership on the tab itself, so renaming or reordering workspaces
  ;; keeps their terminals and two workspaces with the same name stay separate.
  (let* ((tab (tab-bar--current-tab-find))
         (terminal (alist-get 'my/ghostel-buffer tab))
         (buffer (and (buffer-live-p terminal) terminal))
         (window (and buffer (get-buffer-window buffer)))
         (action '((display-buffer-in-side-window)
                   (side . bottom) (slot . 0) (window-height . 0.33))))
    (if window
        (quit-window nil window)
      (if buffer
          (pop-to-buffer buffer action)
        (let* ((project (project-current nil))
               (default-directory (if project (project-root project) default-directory))
               (created (ghostel-create
                        (format "*ghostel:%s*" (alist-get 'name tab)) action)))
          (setf (alist-get 'my/ghostel-buffer
                          (cdr (tab-bar--current-tab-find)))
                created))))))

(use-package ghostel
  :commands (ghostel ghostel-create ghostel-project)
  :custom
  (ghostel-kill-buffer-on-exit t)
  :config
  ;; C-/ can arrive as C-_ depending on the keyboard/terminal.  Keep both
  ;; forms available even when Ghostel otherwise forwards keys to the shell.
  (dolist (map (list ghostel-mode-map ghostel-semi-char-mode-map
                     ghostel-char-mode-map))
    (keymap-set map "C-/" #'my/ghostel-toggle)
    (keymap-set map "C-_" #'my/ghostel-toggle)))

(use-package evil-ghostel
  :after (ghostel evil)
  :hook
  (ghostel-mode . evil-ghostel-mode)
  :config
  (evil-define-key* '(normal insert visual motion emacs) evil-ghostel-mode-map
    (kbd "C-/") #'my/ghostel-toggle
    (kbd "C-_") #'my/ghostel-toggle))

(use-package tramp
  :ensure nil
  :defer t
  :custom
  (tramp-default-method "ssh")
  (remote-file-name-inhibit-cache nil)
  (tramp-use-ssh-controlmaster-options t)
  (tramp-verbose 1)
  :config
  ;; Let packages such as Dirvish and compilation start truly asynchronous
  ;; processes over normal SSH connections.
  (connection-local-set-profile-variables
   'remote-direct-async-process
   '((tramp-direct-async-process . t)))
  (connection-local-set-profiles
   '(:application tramp :protocol "ssh")
   'remote-direct-async-process))

(provide 'init-tools)
;;; init-tools.el ends here
