;;; init-ui.el --- Theme, modeline, and visual feedback -*- lexical-binding: t; -*-

;;; Commentary:
;; The goal is a quiet but information-rich interface: a readable
;; theme, icons where they aid scanning, and clear navigation feedback.

;;; Code:

(require 'seq)

(setq inhibit-startup-screen t
      initial-scratch-message nil
      ring-bell-function #'ignore
      visible-bell nil
      frame-title-format '("%b — Emacs")
      cursor-in-non-selected-windows nil
      resize-mini-windows 'grow-only
      ;; When more input is waiting, keep the UI responsive and let idle
      ;; redisplay finish fontification afterward.
      redisplay-skip-fontification-on-input t)

;; Hide chrome that duplicates keyboard commands or consumes editing space.
(menu-bar-mode -1)
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(tooltip-mode -1)
(blink-cursor-mode 1)
(column-number-mode 1)
(size-indication-mode 1)
(setq-default cursor-type 'bar)

;; Theme choices come from the distribution options: Catppuccin Mocha for dark
;; and Emacs's bundled Modus Operandi for light.  `SPC u b' toggles them and
;; `SPC u C' previews any installed theme.
(defvaralias 'my/dark-theme 'lazyemacs-dark-theme)
(defvaralias 'my/light-theme 'lazyemacs-light-theme)

(defun my/load-theme (theme)
  "Disable active themes and load THEME."
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme theme t))

(defun my/toggle-theme ()
  "Toggle between the configured dark and light themes."
  (interactive)
  (my/load-theme
   (if (memq my/dark-theme custom-enabled-themes)
       my/light-theme
     my/dark-theme)))

(use-package catppuccin-theme
  :demand t
  :config
  (my/load-theme my/dark-theme))

;;; Fonts

(defvaralias 'my/preferred-monospace-fonts 'lazyemacs-fonts)

(defun my/apply-font (&optional frame)
  "Apply the first available preferred font to FRAME."
  (with-selected-frame (or frame (selected-frame))
    (when (display-graphic-p)
      (when-let* ((font (seq-find (lambda (family)
                                  (member family (font-family-list)))
                                my/preferred-monospace-fonts)))
        (set-face-attribute 'default frame
                            :family font :height lazyemacs-font-height :weight 'regular)
        (set-face-attribute 'fixed-pitch frame
                            :family font :height lazyemacs-font-height :weight 'regular)))))

(my/apply-font)
(add-hook 'after-make-frame-functions #'my/apply-font)

;;; Everyday visual cues

(setq display-line-numbers-type t
      display-line-numbers-width-start t
      highlight-nonselected-windows nil)

(global-hl-line-mode 1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

(when (fboundp 'context-menu-mode)
  (context-menu-mode 1))

(when (fboundp 'pixel-scroll-precision-mode)
  (setq pixel-scroll-precision-use-momentum nil)
  (pixel-scroll-precision-mode 1))

;; nerd-icons is shared by the modeline and Dirvish.
;; Run `M-x nerd-icons-install-fonts' once if icons appear as empty boxes.
(use-package nerd-icons
  :defer t)

(use-package doom-modeline
  :hook (after-init . doom-modeline-mode)
  :custom
  (doom-modeline-height 20)
  (doom-modeline-buffer-file-name-style 'truncate-upto-project)
  (doom-modeline-icon t)
  (doom-modeline-minor-modes nil)
  (doom-modeline-workspace-name nil)
  (doom-modeline-project-detection 'project))

;; TODO/FIXME/HACK highlighting, like LazyVim's todo-comments.nvim.  `]t'/`[t'
;; move between them and `SPC s t' searches the whole project.
(use-package hl-todo
  :hook ((prog-mode conf-mode yaml-mode) . hl-todo-mode)
  :commands (hl-todo-next hl-todo-previous)
  :custom
  (hl-todo-keyword-faces
   '(("TODO" . "#89b4fa") ("FIXME" . "#f38ba8") ("FIX" . "#f38ba8")
     ("BUG" . "#f38ba8") ("HACK" . "#fab387") ("WARN" . "#f9e2af")
     ("WARNING" . "#f9e2af") ("PERF" . "#cba6f7") ("NOTE" . "#a6e3a1")
     ("TEST" . "#94e2d5"))))

;; Indent guides, like LazyVim's snacks.indent.  Toggle with `SPC u g'.
;; Terminal frames draw the guides with characters instead of stipples.
(use-package indent-bars
  :hook ((prog-mode yaml-mode yaml-ts-mode) . indent-bars-mode)
  :custom
  (indent-bars-prefer-character (not (display-graphic-p)))
  (indent-bars-color '(highlight :face-bg t :blend 0.25))
  (indent-bars-highlight-current-depth '(:blend 0.6))
  (indent-bars-width-frac 0.15)
  (indent-bars-pad-frac 0.1)
  (indent-bars-no-descend-string t))

(provide 'init-ui)
;;; init-ui.el ends here
