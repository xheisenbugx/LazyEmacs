;;; init-local-actions.el --- Evil local actions for result buffers -*- lexical-binding: t; -*-

;;; Commentary:
;; Backslash is a small local leader in grep, Occur, Dired, compilation, and
;; Embark collection buffers.  It exposes the native editing workflows
;; (grep-edit, occur-edit, WDired) behind the same keys everywhere, so
;; project-wide search and replace works like LazyVim's grug-far.

;;; Code:

(require 'evil)
(require 'general)

(defun my/results-show ()
  "Show the result buffer used by next-error and previous-error."
  (interactive)
  (pop-to-buffer (next-error-find-buffer)))

(defun my/local-actions-editing-p ()
  "Return non-nil in a supported editable results buffer."
  (derived-mode-p 'grep-edit-mode 'occur-edit-mode 'wdired-mode))

(defun my/local-actions-edit ()
  "Edit grep results, Occur matches, or Dired names using native commands."
  (interactive)
  (cond
   ((my/local-actions-editing-p) (user-error "Already editing results"))
   ((derived-mode-p 'grep-mode) (grep-change-to-grep-edit-mode))
   ((derived-mode-p 'occur-mode) (occur-edit-mode))
   ((derived-mode-p 'dired-mode)
    (require 'wdired)
    (wdired-change-to-wdired-mode))
   (t (user-error "Export to grep, Occur, or Dired before editing")))
  (my/local-actions-mode 1)
  (evil-normal-state))

(defun my/local-actions-finish ()
  "Finish editing results, without implying rollback or saving source files."
  (interactive)
  (cond
   ((derived-mode-p 'grep-edit-mode) (grep-edit-save-changes))
   ((derived-mode-p 'occur-edit-mode) (occur-cease-edit))
   ((derived-mode-p 'wdired-mode) (wdired-finish-edit))
   (t (user-error "This buffer is not editing results")))
  (my/local-actions-mode 1)
  (evil-normal-state))

(defun my/local-actions-refresh ()
  "Refresh browsing results, refusing to interrupt an edit session."
  (interactive)
  (when (my/local-actions-editing-p)
    (user-error "Finish editing with \\ c before refreshing"))
  (revert-buffer))

(defun my/local-actions-follow ()
  "Toggle following grep, Occur, or compilation results while browsing."
  (interactive)
  (unless (and (not (my/local-actions-editing-p))
               (derived-mode-p 'grep-mode 'occur-mode 'compilation-mode))
    (user-error "Follow is available while browsing grep, Occur, or compilation results"))
  (next-error-follow-minor-mode 'toggle))

(defvar my/local-actions-map
  (let ((map (make-sparse-keymap)))
    (define-key map "e" #'my/local-actions-edit)
    (define-key map "c" #'my/local-actions-finish)
    (define-key map "r" #'my/local-actions-refresh)
    (define-key map "f" #'my/local-actions-follow)
    (define-key map "a" #'embark-act)
    (define-key map "q" #'quit-window)
    map)
  "Actions available under the backslash local leader.")

(define-minor-mode my/local-actions-mode
  "Provide Evil local actions under backslash in Normal state."
  :lighter nil
  :keymap (make-sparse-keymap))
(evil-define-minor-mode-key 'normal 'my/local-actions-mode
  (kbd "\\") my/local-actions-map)
(with-eval-after-load 'which-key
  (which-key-add-keymap-based-replacements my/local-actions-mode-map
    "\\" "Local actions")
  (which-key-add-keymap-based-replacements my/local-actions-map
    "e" "Edit results" "c" "Finish editing" "r" "Refresh results"
    "f" "Follow results" "a" "Embark actions" "q" "Close window"))

(dolist (hook '(grep-mode-hook grep-edit-mode-hook occur-mode-hook
                occur-edit-mode-hook dired-mode-hook wdired-mode-hook
                compilation-mode-hook embark-collect-mode-hook))
  (add-hook hook #'my/local-actions-mode))

(defun my/grep-native-edit-binding (&rest _)
  "Keep Evil Collection's optional Wgrep shortcut on the native editor."
  (when (boundp 'grep-mode-map)
    (evil-define-key 'normal grep-mode-map "i" #'my/local-actions-edit)))
(with-eval-after-load 'grep (my/grep-native-edit-binding))
(add-hook 'evil-collection-setup-hook #'my/grep-native-edit-binding)

(provide 'init-local-actions)
;;; init-local-actions.el ends here
