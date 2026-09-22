;;; init-navigation.el --- Buffers, windows, projects, and files -*- lexical-binding: t; -*-

;;; Commentary:
;; project.el and Dired remain the foundation.  Consult adds fast selection,
;; Dirvish makes Dired feel like a modern file explorer, and Popper keeps
;; temporary output buffers from disrupting the working layout.

;;; Code:

;;; Windows and workspaces

(use-package ace-window
  :commands ace-window
  :custom
  (aw-scope 'frame)
  (aw-background t))

(use-package windmove
  :ensure nil
  :commands
  (windmove-left windmove-right windmove-up windmove-down))

(use-package winner
  :ensure nil
  :init
  ;; Winner provides undo/redo for window layouts.
  (winner-mode 1))

;; Native tab groups act as sessions; tabs hold ordinary window layouts.
(require 'init-workspaces)

;; Treat compilation, help, and diagnostics as recallable popups.
;; C-` toggles the latest popup, so these buffers stay close without taking
;; permanent space from code windows.
(defun my/popper-evil-normal-state ()
  "Enable Evil navigation in output popups, preserving interactive input."
  (unless (or (minibufferp)
              (derived-mode-p 'comint-mode 'term-mode 'eshell-mode 'ghostel-mode))
    (evil-local-mode 1)
    (evil-normal-state)))

(defun my/popper-display-popup (buffer &optional alist)
  "Display BUFFER with ALIST and enter Evil Normal state."
  (let ((window (popper-select-popup-at-bottom buffer alist)))
    (with-current-buffer (window-buffer window)
      (my/popper-evil-normal-state))
    window))

(use-package popper
  :demand t
  :hook (popper-open-popup . my/popper-evil-normal-state)
  :custom
  (popper-reference-buffers
   '("\\*Messages\\*"
     "\\*Warnings\\*"
     "\\*Compile-Log\\*"
     "\\*Async Shell Command\\*"
     help-mode
     helpful-mode
     compilation-mode
     flycheck-error-list-mode))
  (popper-display-function #'my/popper-display-popup)
  (popper-window-height 0.33)
  :config
  (popper-mode 1)
  (popper-echo-mode 1))

;;; Projects

(use-package project
  :ensure nil
  :demand t
  :custom
  (project-switch-commands 'project-find-file)
  :config
  ;; Recognize common project manifests even before a repository has its first
  ;; commit.  Version-control roots are still preferred when present.
  (when (boundp 'project-vc-extra-root-markers)
    (setq project-vc-extra-root-markers
          '("package.json" "pyproject.toml" "Cargo.toml" "go.mod"
            "pnpm-workspace.yaml" ".projectile"))))

;;; Dired and Dirvish

(use-package dired
  :ensure nil
  :commands (dired dired-jump)
  :custom
  (dired-kill-when-opening-new-dired-buffer t)
  (dired-dwim-target t)
  (dired-recursive-copies 'always)
  (dired-recursive-deletes 'top)
  (delete-by-moving-to-trash t)
  (dired-mouse-drag-files t)
  :config
  (put 'dired-find-alternate-file 'disabled nil)

  ;; Dirvish's rich listing works best with GNU ls.  Linux ships it as `ls';
  ;; Homebrew and the BSD ports install it as `gls'.  Without GNU ls, keep the
  ;; portable switches.  Windows uses Emacs's built-in ls emulation.
  (cond
   ((eq system-type 'windows-nt)
    (require 'ls-lisp)
    (setq ls-lisp-dirs-first t
          ls-lisp-use-insert-directory-program nil
          dired-listing-switches "-alh"))
   ((or (executable-find "gls") (eq system-type 'gnu/linux))
    (when-let* ((gls (executable-find "gls")))
      (setq insert-directory-program gls))
    (setq dired-use-ls-dired t
          dired-listing-switches
          "-l --almost-all --human-readable --group-directories-first --no-group"))
   (t (setq dired-listing-switches "-alh"))))

(use-package dired-x
  :ensure nil
  :after dired
  :custom
  (dired-omit-verbose nil))

;; Dirvish is still Dired underneath, so standard Dired commands and Emacs
;; keybindings continue to work.  `dirvish-side' provides a Neo-tree-like
;; project sidebar; `dirvish' opens the full file manager with previews.
(use-package dirvish
  ;; Dirvish must install its Dired advice before the first `dired-noselect'.
  ;; Loading it eagerly costs a little startup time but never affects ordinary
  ;; source-file visits and keeps the first file-manager invocation correct.
  :demand t
  :init
  ;; NonGNU ELPA keeps optional extensions in a subdirectory that package.el
  ;; does not add to `load-path' automatically.
  (when-let* ((library (locate-library "dirvish")))
    (add-to-list 'load-path
                 (expand-file-name "extensions/"
                                   (file-name-directory library))))
  (dirvish-override-dired-mode)
  :custom
  (dirvish-attributes
   '(vc-state subtree-state nerd-icons collapse git-msg file-time file-size))
  (dirvish-side-attributes
   '(vc-state nerd-icons collapse file-size))
  (dirvish-large-directory-threshold 20000)
  (dirvish-mode-line-format
   '(:left (sort symlink) :right (omit yank index)))
  :config
  (require 'dirvish-history)
  (require 'dirvish-subtree)
  (require 'dirvish-side)
  :bind
  (:map dirvish-mode-map
        ("?" . dirvish-dispatch)
        ("TAB" . dirvish-subtree-toggle)
        ("M-f" . dirvish-history-go-forward)
        ("M-b" . dirvish-history-go-backward)))

(use-package diredfl
  :hook
  ((dired-mode . diredfl-mode)
   (dirvish-directory-view-mode . diredfl-mode)))

(defun my/new-file ()
  "Create an unnamed buffer; saving prompts for a file name."
  (interactive)
  (switch-to-buffer (generate-new-buffer "untitled"))
  (funcall (default-value 'major-mode)))

(defun my/scratch-toggle ()
  "Switch to scratch, or back to the previous buffer."
  (interactive)
  (if (equal (buffer-name) "*scratch*")
      (switch-to-buffer (other-buffer))
    (switch-to-buffer (get-scratch-buffer-create))))

(defun my/kill-other-file-buffers (&optional invisible-only)
  "Kill other file buffers, optionally only those INVISIBLE-ONLY.
Preserve special buffers and processes.  Modified files retain kill prompts."
  (interactive)
  (let ((current (current-buffer)))
    (dolist (buffer (buffer-list))
      (when (and (not (eq buffer current))
                 (buffer-local-value 'buffer-file-name buffer)
                 (not (get-buffer-process buffer))
                 (or (not invisible-only) (not (get-buffer-window buffer t))))
        (kill-buffer buffer)))))

(defun my/kill-invisible-file-buffers ()
  "Kill invisible file buffers, preserving the current buffer."
  (interactive)
  (my/kill-other-file-buffers t))

(defun my/kill-buffer-and-window ()
  "Kill this buffer and close its window, respecting cancellation."
  (interactive)
  (when (one-window-p t) (user-error "Cannot close the only window"))
  (when (kill-buffer (current-buffer)) (delete-window)))

(provide 'init-navigation)
;;; init-navigation.el ends here
