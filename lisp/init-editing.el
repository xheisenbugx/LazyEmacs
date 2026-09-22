;;; init-editing.el --- Editing helpers shared with Evil -*- lexical-binding: t; -*-

;;; Commentary:
;; The helpers here complement Evil with selection, movement, whitespace, and
;; undo tools.  Modal state and Vim operators live exclusively in init-evil.el.

;;; Code:

(require 'seq)

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

;;; System clipboard in terminal frames

;; Graphical frames already share the system clipboard.  Emacs in a terminal
;; does not, so yanking with `y' would never reach other applications.  Use the
;; platform's clipboard tools when they exist: pbcopy/pbpaste on macOS,
;; wl-copy/wl-paste on Wayland, xclip or xsel on X11.  Emacs's OSC 52 support
;; (`xterm-extra-capabilities') remains an alternative over SSH.

(defconst my/clipboard-commands
  '((pbcopy "pbcopy") (wl-copy "wl-copy") (xclip "xclip" "-selection" "clipboard")
    (xsel "xsel" "--clipboard" "--input"))
  "Copy commands tried in order, as (NAME PROGRAM ARGS...).")

(defconst my/clipboard-paste-commands
  '((pbpaste "pbpaste") (wl-paste "wl-paste" "--no-newline")
    (xclip "xclip" "-selection" "clipboard" "-o") (xsel "xsel" "--clipboard" "--output"))
  "Paste commands tried in order, as (NAME PROGRAM ARGS...).")

(defun my/clipboard-command (commands)
  "Return the first entry of COMMANDS whose program is installed."
  (seq-find (lambda (entry)
              (and (executable-find (cadr entry))
                   ;; Wayland tools need a Wayland session, X11 tools a display.
                   (pcase (car entry)
                     ((or 'wl-copy 'wl-paste) (getenv "WAYLAND_DISPLAY"))
                     ((or 'xclip 'xsel) (getenv "DISPLAY"))
                     (_ t))))
            commands))

(defun my/clipboard-copy (text)
  "Copy TEXT to the system clipboard from a terminal frame."
  (when-let* ((entry (my/clipboard-command my/clipboard-commands)))
    (let* ((process-connection-type nil)
           (process (apply #'start-process "clipboard-copy" nil (cdr entry))))
      (process-send-string process text)
      (process-send-eof process))))

(defun my/clipboard-paste ()
  "Return the system clipboard's text, or nil if it matches the last kill."
  (when-let* ((entry (my/clipboard-command my/clipboard-paste-commands)))
    (let ((text (with-output-to-string
                  (with-current-buffer standard-output
                    (apply #'call-process (cadr entry) nil t nil (cddr entry))))))
      (unless (or (string-empty-p text) (equal text (car kill-ring)))
        text))))

(defun my/clipboard-setup-terminal ()
  "Share the kill ring with the system clipboard in terminal-only sessions.
Daemons are skipped: their graphical frames use the native clipboard."
  (when (and (not (display-graphic-p))
             (not (daemonp))
             (not noninteractive)
             (not (eq system-type 'windows-nt))
             (my/clipboard-command my/clipboard-commands))
    (setq interprogram-cut-function #'my/clipboard-copy
          interprogram-paste-function #'my/clipboard-paste)))

(my/clipboard-setup-terminal)

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
