;;; init-dashboard.el --- Startup dashboard -*- lexical-binding: t; -*-

;;; Commentary:
;; The Emacs counterpart of LazyVim's start screen.  It appears when Emacs
;; starts without files to visit (and in new emacsclient frames), offers the
;; same one-key actions as LazyVim, and lists recent files and projects.
;; Disable it with (setq lazyemacs-dashboard nil) in user/early.el.
;;
;; The dashboard uses Emacs state so its single-letter actions are not
;; shadowed by Evil motions; SPC still opens the leader menu.

;;; Code:

(require 'seq)
(require 'recentf)

(defconst lazyemacs-dashboard-logo
  '(
    "██╗      █████╗ ███████╗██╗   ██╗███████╗███╗   ███╗ █████╗  ██████╗███████╗"
    "██║     ██╔══██╗╚══███╔╝╚██╗ ██╔╝██╔════╝████╗ ████║██╔══██╗██╔════╝██╔════╝"
    "██║     ███████║  ███╔╝  ╚████╔╝ █████╗  ██╔████╔██║███████║██║     ███████╗"
    "██║     ██╔══██║ ███╔╝    ╚██╔╝  ██╔══╝  ██║╚██╔╝██║██╔══██║██║     ╚════██║"
    "███████╗██║  ██║███████╗   ██║   ███████╗██║ ╚═╝ ██║██║  ██║╚██████╗███████║"
    "╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝")
  "Wide logo, shown when the window is wide enough.")

(defconst lazyemacs-dashboard-actions
  '(("f" "Find file" find-file)
    ("n" "New file" my/new-file)
    ("p" "Projects" project-switch-project)
    ("g" "Find text" consult-ripgrep)
    ("r" "Recent files" consult-recent-file)
    ("c" "Config" my/open-init-file)
    ("s" "Restore session" my/session-restore)
    ("l" "Packages" list-packages)
    ("q" "Quit" save-buffers-kill-emacs))
  "Dashboard actions as (KEY LABEL COMMAND), matching LazyVim's start screen.")

(defvar lazyemacs-dashboard-buffer-name "*lazyemacs*")

(defface lazyemacs-dashboard-logo '((t :inherit font-lock-keyword-face :weight bold))
  "Face for the dashboard logo."
  :group 'lazyemacs)
(defface lazyemacs-dashboard-key '((t :inherit font-lock-constant-face :weight bold))
  "Face for dashboard action keys."
  :group 'lazyemacs)
(defface lazyemacs-dashboard-heading '((t :inherit font-lock-function-name-face :weight bold))
  "Face for dashboard section headings."
  :group 'lazyemacs)
(defface lazyemacs-dashboard-footer '((t :inherit shadow))
  "Face for the dashboard footer."
  :group 'lazyemacs)

(defvar-keymap lazyemacs-dashboard-mode-map
  :doc "Keys for `lazyemacs-dashboard-mode'."
  :parent button-buffer-map
  "j" #'next-line
  "k" #'previous-line
  "RET" #'push-button)

(define-derived-mode lazyemacs-dashboard-mode special-mode "Dashboard"
  "Major mode for the LazyEmacs start screen."
  (setq-local cursor-type nil
              buffer-read-only t
              truncate-lines t
              display-line-numbers nil)
  (add-hook 'window-size-change-functions #'lazyemacs-dashboard--resize nil t))

(pcase-dolist (`(,key ,_label ,command) lazyemacs-dashboard-actions)
  (keymap-set lazyemacs-dashboard-mode-map key command))
(with-eval-after-load 'init-keymaps
  (keymap-set lazyemacs-dashboard-mode-map "SPC" my/leader-map))
(with-eval-after-load 'evil
  (evil-set-initial-state 'lazyemacs-dashboard-mode 'emacs))

(defun lazyemacs-dashboard--insert-centered (text width &optional face)
  "Insert TEXT centered in WIDTH columns using FACE, then a newline."
  (insert (make-string (max 0 (/ (- width (string-width text)) 2)) ?\s)
          (if face (propertize text 'face face) text)
          "\n"))

(defun lazyemacs-dashboard--insert-button (label action indent)
  "Insert a button showing LABEL that calls ACTION, indented by INDENT."
  (insert (make-string indent ?\s))
  (insert-text-button label 'action (lambda (_) (funcall action)) 'follow-link t)
  (insert "\n"))

(defun lazyemacs-dashboard--render ()
  "Draw the dashboard for the selected window's width."
  (let* ((inhibit-read-only t)
         (window (get-buffer-window (current-buffer)))
         (width (if window (window-width window) 80))
         (logo-width (apply #'max (mapcar #'string-width lazyemacs-dashboard-logo)))
         (column-width 44)
         (indent (max 0 (/ (- width column-width) 2))))
    (erase-buffer)
    (insert "\n\n")
    (if (> width (+ logo-width 4))
        (dolist (row lazyemacs-dashboard-logo)
          (lazyemacs-dashboard--insert-centered
           (concat row (make-string (- logo-width (string-width row)) ?\s))
           width 'lazyemacs-dashboard-logo))
      (lazyemacs-dashboard--insert-centered "L A Z Y E M A C S" width 'lazyemacs-dashboard-logo))
    (insert "\n")
    (lazyemacs-dashboard--insert-centered "Evil Emacs, the LazyVim way" width 'shadow)
    (insert "\n\n")
    (pcase-dolist (`(,key ,label ,command) lazyemacs-dashboard-actions)
      (insert (make-string indent ?\s))
      (insert (propertize key 'face 'lazyemacs-dashboard-key) "   ")
      (insert-text-button label 'action (lambda (_) (call-interactively command))
                          'follow-link t 'face 'default)
      (insert "\n"))
    (when-let* ((files (seq-take (seq-filter #'file-exists-p
                                             (bound-and-true-p recentf-list))
                                 5)))
      (insert "\n" (make-string indent ?\s)
              (propertize "Recent files" 'face 'lazyemacs-dashboard-heading) "\n")
      (dolist (file files)
        (lazyemacs-dashboard--insert-button
         (truncate-string-to-width (abbreviate-file-name file) column-width nil nil "…")
         (lambda () (find-file file)) indent)))
    (when-let* ((projects (and (fboundp 'project-known-project-roots)
                               (seq-take (project-known-project-roots) 5))))
      (insert "\n" (make-string indent ?\s)
              (propertize "Projects" 'face 'lazyemacs-dashboard-heading) "\n")
      (dolist (root projects)
        (lazyemacs-dashboard--insert-button
         (truncate-string-to-width (abbreviate-file-name root) column-width nil nil "…")
         (lambda () (project-switch-project root)) indent)))
    (insert "\n\n")
    (lazyemacs-dashboard--insert-centered
     (format "LazyEmacs loaded %d packages in %.2fs"
             (length package-activated-list)
             (if after-init-time
                 (float-time (time-subtract after-init-time before-init-time))
               0))
     width 'lazyemacs-dashboard-footer)
    (goto-char (point-min))
    (when (search-forward-regexp (concat "^ *" (caar lazyemacs-dashboard-actions) " ") nil t)
      (goto-char (match-end 0)))))

(defun lazyemacs-dashboard--resize (window)
  "Re-center the dashboard shown in WINDOW after its size changes."
  (with-current-buffer (window-buffer window)
    (when (derived-mode-p 'lazyemacs-dashboard-mode)
      (lazyemacs-dashboard--render))))

(defun lazyemacs-dashboard-buffer ()
  "Return the dashboard buffer, freshly rendered."
  (let ((buffer (get-buffer-create lazyemacs-dashboard-buffer-name)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'lazyemacs-dashboard-mode)
        (lazyemacs-dashboard-mode))
      (lazyemacs-dashboard--render))
    buffer))

(defun lazyemacs-dashboard ()
  "Show the LazyEmacs start screen."
  (interactive)
  (switch-to-buffer (lazyemacs-dashboard-buffer))
  ;; Render again now that the buffer has a window to center in.
  (lazyemacs-dashboard--render))

(defun lazyemacs-dashboard--startup ()
  "Show the dashboard if startup left only the scratch buffer on screen.
Files named on the command line and restored desktops take precedence."
  (when (and lazyemacs-dashboard
             (one-window-p t)
             (equal (buffer-name (window-buffer)) "*scratch*"))
    (lazyemacs-dashboard)))

(unless noninteractive
  (add-hook 'emacs-startup-hook #'lazyemacs-dashboard--startup 90)
  ;; emacsclient -c without files shows `initial-buffer-choice'.
  (when (and lazyemacs-dashboard (daemonp))
    (setq initial-buffer-choice #'lazyemacs-dashboard-buffer)))

(provide 'init-dashboard)
;;; init-dashboard.el ends here
