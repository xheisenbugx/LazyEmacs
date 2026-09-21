;;; init-keymaps.el --- Discoverable Evil and C-c leader maps -*- lexical-binding: t; -*-

;;; Commentary:
;; SPC is the primary LazyVim-style leader in Evil's Normal, Visual, and Motion
;; states.  Emacs reserves C-c followed by a letter for users, so the same maps
;; are also available there from every state.  Pause after either prefix to see
;; the named groups in Which Key.

;;; Code:

(declare-function flycheck-display-error-at-point "flycheck" ())

;;; Leader groups

(defvar my/leader-buffer-map nil "Buffer commands.")
(setq my/leader-buffer-map
      (define-keymap
	:prefix 'my/leader-buffer-prefix
	"b" #'crux-switch-to-previous-buffer
	"i" #'ibuffer
	"d" #'kill-current-buffer
	"k" #'kill-current-buffer
	"K" #'kill-buffer
	"n" #'next-buffer
	"p" #'previous-buffer
	"r" #'revert-buffer
	"s" #'scratch-buffer))

(defvar my/leader-code-map nil "Language, compilation, and formatting commands.")
(setq my/leader-code-map
      (define-keymap
	:prefix 'my/leader-code-prefix
	"a" #'my/lsp-code-actions
	"c" #'compile
	"C" #'recompile
	"d" #'eldoc-doc-buffer
	"f" #'my/format-buffer
	"i" #'my/lsp-file-symbols
	"l" #'my/lsp-start
	"o" #'my/lsp-organize-imports
	"q" #'my/lsp-code-actions
	"r" #'my/lsp-rename
	"R" #'my/lsp-restart
	"s" #'my/lsp-workspace-symbols
	"x" #'my/lsp-shutdown))

(defvar my/leader-error-map nil "Diagnostic commands.")
(setq my/leader-error-map
      (define-keymap
	:prefix 'my/leader-error-prefix
	"b" #'my/lsp-file-diagnostics
	"d" #'flycheck-display-error-at-point
	"f" #'consult-flycheck
	"L" #'flycheck-list-errors
	"l" #'my/lsp-diagnostics
	"n" #'flycheck-next-error
	"p" #'flycheck-previous-error
	"P" #'my/lsp-diagnostics))

(defvar my/leader-file-map nil "File and directory commands.")
(setq my/leader-file-map
      (define-keymap
	:prefix 'my/leader-file-prefix
	"b" #'consult-bookmark
	"c" #'my/open-init-file
	"d" #'consult-dir
	"D" #'crux-delete-file-and-buffer
	"e" #'dirvish-side
	"f" #'find-file
	"j" #'dired-jump
	"o" #'crux-open-with
	"p" #'my/copy-buffer-file-name
	"r" #'consult-recent-file
	"R" #'crux-rename-file-and-buffer
	"s" #'save-buffer
	"S" #'write-file
	"u" #'sudo-edit))

(defvar my/leader-git-map nil "Git and hunk commands.")
(setq my/leader-git-map
      (define-keymap
	:prefix 'my/leader-git-prefix
	"b" #'magit-blame-addition
	"d" #'magit-diff-buffer-file
	"f" #'magit-file-dispatch
	"g" #'magit-status
	"h" #'diff-hl-show-hunk
	"l" #'magit-log-current
	"n" #'diff-hl-next-hunk
	"p" #'diff-hl-previous-hunk
	"r" #'diff-hl-revert-hunk
	"s" #'diff-hl-stage-current-hunk
	"y" #'git-link
	"Y" #'git-link-commit))

(defvar my/leader-help-map nil "Help and documentation commands.")
(setq my/leader-help-map
      (define-keymap
	:prefix 'my/leader-help-prefix
	"c" #'helpful-command
	"f" #'helpful-callable
	"i" #'info
	"k" #'helpful-key
	"K" #'describe-keymap
	"l" #'consult-info
	"m" #'describe-mode
	"p" #'describe-package
        "D" #'lazyemacs-doctor
	"v" #'helpful-variable))

(defvar my/leader-jump-map nil "Navigation commands.")
(setq my/leader-jump-map
      (define-keymap
	:prefix 'my/leader-jump-prefix
	"b" #'xref-go-back
	"c" #'avy-goto-char-timer
	"d" #'my/lsp-find-definitions
	"f" #'xref-go-forward
	"l" #'consult-goto-line
	"i" #'my/lsp-find-implementations
	"o" #'consult-outline
	"r" #'my/lsp-find-references
	"s" #'my/lsp-file-symbols
	"w" #'avy-goto-word-1))

(defvar my/leader-multiple-cursors-map nil "Multiple-cursor commands.")
(setq my/leader-multiple-cursors-map
      (define-keymap
	:prefix 'my/leader-multiple-cursors-prefix
	"a" #'evil-mc-make-all-cursors
	"l" #'evil-mc-make-cursor-in-visual-selection-beg
	"n" #'evil-mc-make-and-goto-next-match
	"p" #'evil-mc-make-and-goto-prev-match
	"s" #'evil-mc-skip-and-goto-next-match
	"u" #'evil-mc-undo-last-added-cursor
	"q" #'evil-mc-undo-all-cursors))

(defvar my/leader-mail-map nil "Email commands.")
(setq my/leader-mail-map
      (define-keymap
	:prefix 'my/leader-mail-prefix
	"b" #'mu4e-search-bookmark
	"c" #'mu4e-compose-new
	"i" #'my/mu4e-initialize-index
	"j" #'mu4e-search-maildir
	"m" #'my/mu4e-open
	"s" #'mu4e-search
	"u" #'mu4e-update-mail-and-index))

(defvar my/leader-org-map nil "Org commands.")
(setq my/leader-org-map
      (define-keymap
	:prefix 'my/leader-org-prefix
	"a" #'org-agenda
	"c" #'org-capture
	"d" #'my/org-agenda-dashboard
	"l" #'org-store-link))

(defvar my/leader-project-map nil "Project commands.")
(setq my/leader-project-map
      (define-keymap
	:prefix 'my/leader-project-prefix
	"b" #'consult-project-buffer
	"c" #'project-compile
	"d" #'project-dired
	"e" #'my/project-ghostel
	"f" #'project-find-file
	"k" #'project-kill-buffers
	"p" #'project-switch-project
	"r" #'project-query-replace-regexp
	"s" #'consult-ripgrep
	"t" #'my/project-ghostel
	"T" #'my/project-ghostel-new))

(defvar my/leader-session-map nil "Configuration and session commands.")
(setq my/leader-session-map
      (define-keymap
	:prefix 'my/leader-session-prefix
	"f" #'my/open-init-file
	"p" #'my/package-upgrade-all
	"s" #'my/session-save
	"l" #'my/session-restore
	"q" #'save-buffers-kill-emacs
	"r" #'my/reload-init-file))

(defvar my/leader-search-map nil "Search and filtering commands.")
(setq my/leader-search-map
      (define-keymap
	:prefix 'my/leader-search-prefix
	"b" #'consult-line
	"d" #'my/lsp-diagnostics
	"f" #'my/consult-find
	"s" #'consult-lsp-file-symbols
	"g" #'consult-ripgrep
	"r" #'project-query-replace-regexp
	"S" #'my/lsp-workspace-symbols
	"i" #'consult-imenu
	"k" #'consult-keep-lines
	"l" #'consult-line
	"L" #'consult-line-multi
	"m" #'consult-man
	"o" #'consult-lsp-file-symbols
	"u" #'consult-focus-lines))

(defvar my/leader-terminal-map nil "Shell and terminal commands.")
(setq my/leader-terminal-map
      (define-keymap
	:prefix 'my/leader-terminal-prefix
	"e" #'ghostel
	"n" #'my/project-ghostel-new
	"p" #'my/project-ghostel
	"s" #'ghostel
	"t" #'ghostel))

(defvar my/leader-ui-map nil "UI toggles.")
(setq my/leader-ui-map
      (define-keymap
	:prefix 'my/leader-ui-prefix
	"d" #'my/lsp-toggle-diagnostics
	"f" #'my/toggle-format-on-save
	"h" #'global-hl-line-mode
	"l" #'display-line-numbers-mode
	"L" #'my/toggle-relative-line-numbers
	"t" #'my/toggle-theme
	"T" #'toggle-truncate-lines
	"v" #'visual-line-mode
	"w" #'whitespace-mode))

(defvar my/leader-window-map nil "Window and layout commands.")
(setq my/leader-window-map
      (define-keymap
	:prefix 'my/leader-window-prefix
	"1" #'delete-other-windows
	"=" #'balance-windows
	"d" #'delete-window
	"h" #'windmove-left
	"j" #'windmove-down
	"k" #'windmove-up
	"l" #'windmove-right
	"m" #'my/window-zoom
	"o" #'ace-window
	"r" #'winner-redo
	"s" #'split-window-below
	"u" #'winner-undo
	"v" #'split-window-right
	"<left>" #'windmove-left
	"<down>" #'windmove-down
	"<up>" #'windmove-up
	"<right>" #'windmove-right))

(defvar my/leader-workspace-map nil "Sessions (tab groups) and their tabs.")
(setq my/leader-workspace-map
      (define-keymap
	:prefix 'my/leader-workspace-prefix
	"[" #'project-tab-sessions-previous-tab
	"]" #'project-tab-sessions-next-tab
	"b" #'project-tab-sessions-switch-tab
	"g" #'project-tab-sessions-switch
	"G" #'tab-bar-change-tab-group
	"k" #'tab-bar-close-tab
	"n" #'tab-bar-new-tab
	"N" #'my/session-new-layout
	"r" #'tab-bar-rename-tab
	"u" #'tab-bar-history-back
	"R" #'tab-bar-history-forward))

(defvar my/leader-run-map nil "Project tasks and focused tests.")
(setq my/leader-run-map
      (define-keymap
	:prefix 'my/leader-run-prefix
	"r" #'my/project-run-task
	"R" #'my/project-rerun-task
	"f" #'my/project-test-file
	"t" #'my/project-test-nearest
	"o" #'my/project-task-output
	"n" #'my/project-task-next-error
	"T" #'my/project-task-terminal))

(defun my/toggle-relative-line-numbers ()
  "Toggle absolute/relative numbering in this buffer."
  (interactive)
  (setq-local display-line-numbers-type
              (if (eq display-line-numbers-type 'relative) t 'relative))
  (display-line-numbers-mode 1))

(defun my/project-explorer ()
  "Toggle the Dirvish sidebar at the current project root."
  (interactive)
  (let ((default-directory (if-let* ((project (project-current nil)))
                               (project-root project) default-directory)))
    (call-interactively #'dirvish-side)))

(defvar my/leader-snippet-map nil "Snippet commands.")
(setq my/leader-snippet-map
      (define-keymap
	:prefix 'my/leader-snippet-prefix
	"i" #'yas-insert-snippet
	"n" #'yas-new-snippet
	"v" #'yas-visit-snippet-file))

;; Install only letter-based sub-prefixes under C-c.  This preserves C-c C-c,
;; C-c C-k, and other mode-specific conventions used by Org, compilation, and
;; programming modes.
(keymap-global-set "C-c b" my/leader-buffer-map)
(keymap-global-set "C-c c" my/leader-code-map)
(keymap-global-set "C-c e" #'my/project-explorer)
(keymap-global-set "C-c x" my/leader-error-map)
(keymap-global-set "C-c r" my/leader-run-map)
(keymap-global-set "C-c f" my/leader-file-map)
(keymap-global-set "C-c g" my/leader-git-map)
(keymap-global-set "C-c h" my/leader-help-map)
(keymap-global-set "C-c j" my/leader-jump-map)
(keymap-global-set "C-c m" my/leader-multiple-cursors-map)
(keymap-global-set "C-c M" my/leader-mail-map)
(keymap-global-set "C-c o" my/leader-org-map)
(keymap-global-set "C-c p" my/leader-project-map)
(keymap-global-set "C-c q" my/leader-session-map)
(keymap-global-set "C-c s" my/leader-search-map)
(keymap-global-set "C-c t" my/leader-terminal-map)
(keymap-global-set "C-c u" my/leader-ui-map)
(keymap-global-set "C-c w" my/leader-window-map)
(keymap-global-set "C-c y" my/leader-snippet-map)
(keymap-global-set "C-c z" my/leader-workspace-map)

;; Select tabs within the current session; Super+0 selects its tenth tab.
(dotimes (index 10)
  (let ((number (1+ index)))
    (keymap-global-set (format "s-%d" (mod number 10))
                       (lambda () (interactive) (project-tab-sessions-select-tab number)))))
(keymap-global-set "C-<tab>" #'project-tab-sessions-next-tab)
(keymap-global-set "C-S-<tab>" #'project-tab-sessions-previous-tab)
(keymap-global-set "C-x t g" #'project-tab-sessions-switch)
(keymap-global-set "s-p" #'project-tab-sessions-switch)
(keymap-global-set "s-t" #'tab-bar-new-tab)
(keymap-global-set "s-r" #'tab-bar-rename-tab)
(keymap-global-set "s-w" #'tab-bar-close-tab)
(keymap-global-set "C-x t P" #'project-tab-sessions-group-from-project)

;; Install the same hierarchy under SPC in Evil states.  General supplies the
;; descriptive group metadata consumed by Which Key.  Keeping the definition
;; here also means the complete leader is visible in one module.
(general-define-key
 :states '(normal visual motion)
 :keymaps 'override
 :prefix "SPC"
 "SPC" '(project-find-file :which-key "Project files")
 "," '(consult-project-buffer :which-key "Project buffers")
 "/" '(consult-ripgrep :which-key "Search project")
 "-" '(split-window-below :which-key "Split below")
 "|" '(split-window-right :which-key "Split right")
 "b" '(:keymap my/leader-buffer-map :which-key "Buffers")
 "c" '(:keymap my/leader-code-map :which-key "Code")
 "e" '(my/project-explorer :which-key "Explorer")
 "x" '(:keymap my/leader-error-map :which-key "Errors")
 "r" '(:keymap my/leader-run-map :which-key "Run")
 "f" '(:keymap my/leader-file-map :which-key "Files")
 "g" '(:keymap my/leader-git-map :which-key "Git")
 "h" '(:keymap my/leader-help-map :which-key "Help")
 "j" '(:keymap my/leader-jump-map :which-key "Jump")
 "m" '(:keymap my/leader-multiple-cursors-map :which-key "Multiple cursors")
 "M" '(:keymap my/leader-mail-map :which-key "Mail")
 "o" '(:keymap my/leader-org-map :which-key "Org")
 "p" '(:keymap my/leader-project-map :which-key "Projects")
 "q" '(:keymap my/leader-session-map :which-key "Session")
 "s" '(:keymap my/leader-search-map :which-key "Search")
 "t" '(:keymap my/leader-terminal-map :which-key "Terminal")
 "u" '(:keymap my/leader-ui-map :which-key "UI toggles")
 "w" '(:keymap my/leader-window-map :which-key "Windows")
 "y" '(:keymap my/leader-snippet-map :which-key "Snippets")
 "z" '(:keymap my/leader-workspace-map :which-key "Workspaces"))

;;; Evil-native navigation

;; Flash motions also compose with operators and extend Visual selections.
;; Override Evil Collection's mode-local s/S and character-motion bindings.
(general-define-key
 :states '(normal visual motion operator) :keymaps 'override
 "s" #'flash-evil-jump
 "S" #'flash-treesitter
 "f" #'flash-char-find
 "t" #'flash-char-find-to
 "F" #'flash-char-find-backward
 "T" #'flash-char-find-to-backward
 ";" #'flash-char-repeat
 "," #'flash-char-repeat-reverse)

(general-define-key
 :states 'operator :keymaps 'override
 "S" #'my/flash-treesitter-object)

;; These are the high-frequency code-navigation bindings familiar from Vim and
;; LazyVim.  Their leader equivalents remain available and discoverable.
(general-define-key
 :states 'normal :keymaps 'override
 (kbd "gd") #'my/lsp-find-definitions
 (kbd "gi") #'my/lsp-find-implementations
 (kbd "gI") #'my/lsp-find-implementations
 (kbd "gr") #'my/lsp-find-references
 (kbd "K") #'eldoc-doc-buffer
 (kbd "] d") #'flycheck-next-error
 (kbd "[ d") #'flycheck-previous-error
 (kbd "]q") #'next-error
 (kbd "[q") #'previous-error
 (kbd "] b") #'next-buffer
 (kbd "[ b") #'previous-buffer)

;; Ctrl plus a home-row direction moves between windows without requiring the
;; leader, including while inserting text or typing in a terminal.
(general-define-key
 :states '(normal insert visual motion emacs replace)
 :keymaps 'override
 "C-h" #'windmove-left
 "C-j" #'windmove-down
 "C-k" #'windmove-up
 "C-l" #'windmove-right)

;; Ghostel's char mode overrides even Evil maps to forward keys to the PTY.
;; Reserve the same window commands in its terminal input maps as well.
(with-eval-after-load 'ghostel
  (dolist (map (list ghostel-mode-map ghostel-semi-char-mode-map
                     ghostel-char-mode-map))
    (keymap-set map "C-h" #'windmove-left)
    (keymap-set map "C-j" #'windmove-down)
    (keymap-set map "C-k" #'windmove-up)
    (keymap-set map "C-l" #'windmove-right)))

;;; Familiar Emacs shortcuts upgraded with richer commands

(keymap-global-set "C-s" #'consult-line)
(keymap-global-set "M-y" #'consult-yank-pop)
(keymap-global-set "C-x b" #'consult-buffer)
(keymap-global-set "C-x p b" #'consult-project-buffer)
(keymap-global-set "C-x p e" #'my/project-ghostel)
(keymap-global-set "C-x p s" #'my/project-ghostel)
(keymap-global-set "C-x g" #'magit-status)
(keymap-global-set "C-x k" #'kill-current-buffer)
(keymap-global-set "C-x K" #'kill-buffer)
(keymap-global-set "C-x o" #'ace-window)
(keymap-global-set "C-/" #'my/ghostel-toggle)
(keymap-global-set "C-_" #'my/ghostel-toggle)
(keymap-global-set "C-x C-d" #'consult-dir)
(keymap-global-set "C-x C-j" #'dired-jump)
(keymap-global-set "C-x u" #'vundo)
(keymap-global-set "C-." #'embark-act)
(keymap-global-set "C-;" #'embark-dwim)
(keymap-global-set "C-=" #'er/expand-region)
(keymap-global-set "C-:" #'avy-goto-char-timer)
(keymap-global-set "C-a" #'crux-move-beginning-of-line)
(keymap-global-set "C-k" #'crux-smart-kill-line)
(keymap-global-set "M-;" #'comment-dwim-2)
(keymap-global-set "M-R" #'vertico-repeat)
(keymap-global-set "M-g c" #'avy-goto-char-timer)
(keymap-global-set "M-g w" #'avy-goto-word-1)
(keymap-global-set "M-g g" #'consult-goto-line)
(keymap-global-set "M-g i" #'consult-imenu)
(keymap-global-set "M-s r" #'consult-ripgrep)
(keymap-global-set "C-`" #'popper-toggle)
(keymap-global-set "M-`" #'popper-cycle)
(keymap-global-set "C-M-`" #'popper-toggle-type)

;; (defun my-mark-line ()
;;   (interactive)
;;   (push-mark (line-beginning-position))
;;   (goto-char (line-end-position))
;;   (activate-mark))

;; (define-key global-map (kbd "C-S-SPC") #'my-mark-line)

;; Helpful is a drop-in improvement for the built-in help namespace.
(keymap-global-set "C-h f" #'helpful-callable)
(keymap-global-set "C-h v" #'helpful-variable)
(keymap-global-set "C-h k" #'helpful-key)
(keymap-global-set "C-h x" #'helpful-command)

;; Friendly labels make the C-c fallback read like the SPC leader menu.
(which-key-add-keymap-based-replacements
  global-map
  "C-c b" '("Buffers" . my/leader-buffer-prefix)
  "C-c c" '("Code" . my/leader-code-prefix)
  "C-c e" "Explorer"
  "C-c x" '("Errors" . my/leader-error-prefix)
  "C-c r" '("Run" . my/leader-run-prefix)
  "C-c f" '("Files" . my/leader-file-prefix)
  "C-c g" '("Git" . my/leader-git-prefix)
  "C-c h" '("Help" . my/leader-help-prefix)
  "C-c j" '("Jump" . my/leader-jump-prefix)
  "C-c m" '("Multiple cursors" . my/leader-multiple-cursors-prefix)
  "C-c M" '("Mail" . my/leader-mail-prefix)
  "C-c o" '("Org" . my/leader-org-prefix)
  "C-c p" '("Projects" . my/leader-project-prefix)
  "C-c q" '("Session" . my/leader-session-prefix)
  "C-c s" '("Search" . my/leader-search-prefix)
  "C-c t" '("Terminal" . my/leader-terminal-prefix)
  "C-c u" '("UI toggles" . my/leader-ui-prefix)
  "C-c w" '("Windows" . my/leader-window-prefix)
  "C-c y" '("Snippets" . my/leader-snippet-prefix)
  "C-c z" '("Workspaces" . my/leader-workspace-prefix))

(provide 'init-keymaps)
;;; init-keymaps.el ends here

;; Mail is an opt-in integration; do not advertise unavailable commands.
(unless lazyemacs-enable-mail
  (keymap-global-unset "C-c M")
  (general-define-key :states '(normal visual motion)
                      :keymaps 'override :prefix "SPC" "M" nil))
