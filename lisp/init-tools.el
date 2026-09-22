;;; init-tools.el --- Shells, terminals, and remote files -*- lexical-binding: t; -*-

;;; Commentary:
;; Ghostel (libghostty) is the terminal for interactive shells and project
;; commands on macOS, Linux, and Windows.  It needs an Emacs built with dynamic
;; module support; on builds without it, the same commands open Eshell so every
;; terminal key keeps working.

;;; Code:

(defvar eshell-buffer-name)
(declare-function eshell-send-input "esh-mode")
(declare-function ghostel-send-string "ghostel")

(defun my/ghostel-available-p ()
  "Return non-nil when this Emacs can load Ghostel's native module."
  (and (fboundp 'module-load) module-file-suffix t))

(defun my/terminal-create (name action)
  "Create a terminal buffer called NAME and display it with ACTION.
Use Ghostel when possible and Eshell otherwise."
  (if (my/ghostel-available-p)
      (progn (require 'ghostel) (ghostel-create name action))
    (let ((buffer (save-window-excursion
                    (let ((eshell-buffer-name (or name "*eshell*")))
                      (eshell t)))))
      (pop-to-buffer buffer action)
      buffer)))

(defun my/terminal-send (buffer string)
  "Send STRING followed by a newline to terminal BUFFER."
  (with-current-buffer buffer
    (if (derived-mode-p 'eshell-mode)
        (progn (goto-char (point-max)) (insert string) (eshell-send-input))
      (ghostel-send-string (concat string "\n")))))

(defun my/ghostel-pane (fresh cwd toggle)
  "Show a tab-owned terminal, optionally FRESH, in CWD or the project root.
When TOGGLE is non-nil, hide an already visible pane without killing it."
  (let* ((tab (tab-bar--current-tab-find))
         (directory (file-name-as-directory
                     (expand-file-name
                      (if cwd default-directory
                        (if-let* ((project (project-current nil)))
                            (project-root project) default-directory)))))
         (terminals (alist-get 'my/ghostel-cwd-buffers tab))
         (terminal (if cwd (alist-get directory terminals nil nil #'equal)
                     (alist-get 'my/ghostel-buffer tab)))
         (buffer (and (not fresh) (buffer-live-p terminal) terminal))
         (window (and buffer (get-buffer-window buffer)))
         (action '((display-buffer-in-side-window)
                   (side . bottom) (slot . 0) (window-height . 0.33))))
    (cond
     ((and toggle window) (quit-window nil window) buffer)
     (buffer (pop-to-buffer buffer action) buffer)
     (t
      (let* ((default-directory directory)
             (created (my/terminal-create
                       (format "*ghostel:%s%s*" (alist-get 'name tab)
                               (if cwd ":cwd" "")) action)))
        (if cwd
            (setf (alist-get directory
                             (alist-get 'my/ghostel-cwd-buffers (cdr tab))
                             nil nil #'equal) created)
          (setf (alist-get 'my/ghostel-buffer (cdr tab)) created))
        created)))))

(defun my/project-ghostel (&optional fresh)
  "Show this tab's project terminal; with prefix FRESH, start a new shell."
  (interactive "P")
  (my/ghostel-pane fresh nil nil))

(defun my/directory-ghostel (&optional fresh)
  "Show this tab's current-directory terminal; with prefix FRESH, create one."
  (interactive "P")
  (my/ghostel-pane fresh t nil))

(defun my/project-ghostel-new ()
  "Start an independent project shell for an interactive task."
  (interactive)
  (if (my/ghostel-available-p)
      (progn (require 'ghostel) (ghostel-project '(4)))
    (let ((default-directory (if-let* ((project (project-current nil)))
                                 (project-root project) default-directory)))
      (my/terminal-create "*eshell:project*" nil))))

(defun my/ghostel-toggle ()
  "Show or hide this tab's project terminal without stopping its shell."
  (interactive)
  (my/ghostel-pane nil nil t))

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
