;;; init-editing.el --- Editing helpers shared with Evil -*- lexical-binding: t; -*-

;;; Commentary:
;; The helpers here complement Evil with selection, movement, whitespace, and
;; undo tools.  Modal state and Vim operators live exclusively in init-evil.el.

;;; Code:

(setq scroll-step 1
      scroll-conservatively 101
      scroll-margin 3
      hscroll-step 1
      hscroll-margin 2
      tab-always-indent 'complete
      undo-limit (* 64 1024 1024)
      undo-strong-limit (* 96 1024 1024)
      undo-outer-limit (* 960 1024 1024))

(setq-default indent-tabs-mode nil
              tab-width 2
              fill-column 100
              truncate-lines t)

;; These built-in modes make editing behave like a contemporary text editor
;; while retaining the usual Emacs commands and kill ring.
(delete-selection-mode 1)
(electric-pair-mode 1)
(show-paren-mode 1)
(repeat-mode 1)
(global-subword-mode 1)

(setq show-paren-delay 0.1
      show-paren-when-point-inside-paren t
      show-paren-context-when-offscreen 'overlay
      electric-pair-preserve-balance t)

;; Wrap prose but keep source code horizontally stable.
(add-hook 'text-mode-hook #'visual-line-mode)

(use-package expand-region
  :commands er/expand-region)

(use-package avy
  :commands (avy-goto-char-timer avy-goto-word-1)
  :custom
  (avy-timeout-seconds 0.35)
  (avy-all-windows t))

(use-package move-text
  :commands (move-text-up move-text-down))

(use-package crux
  :commands
  (crux-move-beginning-of-line crux-smart-kill-line
   crux-switch-to-previous-buffer crux-rename-file-and-buffer
   crux-delete-file-and-buffer crux-open-with
   crux-cleanup-buffer-or-region))

(use-package comment-dwim-2
  :commands comment-dwim-2)

(defun my-copy-to-osx (text)
  (let ((process-connection-type nil))
    (let ((proc (start-process "pbcopy" nil "pbcopy")))
      (process-send-string proc text)
      (process-send-eof proc))))

(defun my-paste-from-osx ()
  (shell-command-to-string "pbpaste"))

;; Only hook these functions up if we are in a terminal AND running on macOS
(when (and (not (display-graphic-p))
           (eq system-type 'darwin))
  (setq interprogram-cut-function 'my-copy-to-osx)
  (setq interprogram-paste-function 'my-paste-from-osx))

;; Only whitespace on edited lines is removed, so saving an old file does not
;; create a huge unrelated whitespace diff.
(use-package ws-butler
  :hook
  ((prog-mode text-mode conf-mode) . ws-butler-mode))

;; Vundo visualizes the same built-in undo-redo history used by Evil's `u' and
;; `C-r', so opening it does not introduce a second undo implementation.
(use-package vundo
  :commands vundo)

(use-package sudo-edit
  :commands sudo-edit)

(provide 'init-editing)
;;; init-editing.el ends here
