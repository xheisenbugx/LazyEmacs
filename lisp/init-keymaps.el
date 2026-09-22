;;; init-keymaps.el --- LazyVim-style leader, Evil keys, and C-c aliases -*- lexical-binding: t; -*-

;;; Commentary:
;; SPC is the primary LazyVim-style leader in Evil's Normal, Visual, and Motion
;; states.  Emacs reserves C-c followed by a letter for users, so every leader
;; group is also available there from any state (for example `C-c f f').
;;
;; Every leader binding is declared in a table of (KEY DESCRIPTION COMMAND).
;; The description is what Which Key displays, mirroring LazyVim's labels.
;; The complete leader is the keymap `my/leader-map', so private configuration
;; can extend it directly:
;;
;;   (keymap-set my/leader-map "z" '("Zen" . my/zen-command))
;;   (keymap-set my/leader-file-map "x" '("Delete this file" . crux-delete-file-and-buffer))
;;
;; Keys follow https://www.lazyvim.org/keymaps.  Differences are listed in
;; docs/keymaps.md under "Intentional differences".

;;; Code:

(require 'seq)
(require 'evil)

;;; Leader construction

(defun lazyemacs-define-leader-map (symbol bindings &optional parent)
  "Define prefix command SYMBOL from BINDINGS and return its keymap.
BINDINGS is a list of (KEY DESCRIPTION COMMAND).  KEY uses `keymap-set'
syntax.  DESCRIPTION is shown by Which Key; COMMAND may itself be a keymap.
PARENT, when non-nil, supplies inherited bindings (used for `SPC w')."
  (let ((map (make-sparse-keymap)))
    (when parent (set-keymap-parent map parent))
    (pcase-dolist (`(,key ,description ,command) bindings)
      (keymap-set map key (if description (cons description command) command)))
    (fset symbol map)
    map))

;; Leader commands from libraries that do not autoload them.
(autoload 'consult-compile-error "consult-compile" nil t)
(autoload 'profiler-report "profiler" nil t)

;;; Small commands that only exist to give the leader LazyVim semantics

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

(defun my/command-history ()
  "Pick a previously executed M-x command and run it again."
  (interactive)
  (unless extended-command-history
    (user-error "No command history yet; run a command with M-x first"))
  (let ((name (completing-read "Command history: " extended-command-history nil t)))
    (add-to-history 'extended-command-history name)
    (setq prefix-arg current-prefix-arg)
    (command-execute (intern name) 'record)))

(defun my/messages ()
  "Show the message log, Emacs's notification history."
  (interactive)
  (pop-to-buffer (messages-buffer)))

(defun my/open-changelog ()
  "Open the LazyEmacs changelog."
  (interactive)
  (find-file-read-only (expand-file-name "CHANGELOG.md" lazyemacs-root-directory)))

(defun my/redraw ()
  "Clear search highlighting and redraw the frame, like LazyVim's `SPC u r'."
  (interactive)
  (when (fboundp 'evil-ex-nohighlight) (evil-ex-nohighlight))
  (lazy-highlight-cleanup t)
  (redraw-display))

(defun my/toggle-autopairs ()
  "Toggle automatic bracket pairing in this buffer."
  (interactive)
  (electric-pair-local-mode (if electric-pair-mode -1 1))
  (message "Auto pairs %s" (if electric-pair-mode "enabled" "disabled")))

(defun my/toggle-spelling ()
  "Toggle spell checking; prose buffers check all text, code only comments."
  (interactive)
  (require 'ispell)
  (unless (executable-find ispell-program-name)
    (user-error "Install aspell, hunspell, or enchant to enable spell checking"))
  (cond ((bound-and-true-p flyspell-mode) (flyspell-mode -1))
        ((derived-mode-p 'prog-mode) (flyspell-prog-mode))
        (t (flyspell-mode 1)))
  (message "Spell checking %s" (if (bound-and-true-p flyspell-mode) "enabled" "disabled")))

(defun my/toggle-tab-bar ()
  "Toggle the tab line that shows sessions and layouts."
  (interactive)
  (tab-bar-mode (if tab-bar-mode -1 1)))

(defun my/inspect-tree ()
  "Show the tree-sitter syntax tree for this buffer."
  (interactive)
  (unless (treesit-parser-list)
    (user-error "This buffer needs a native tree-sitter major mode and grammar"))
  (treesit-explore-mode 'toggle))

(declare-function profiler-running-p "profiler")
(declare-function profiler-stop "profiler")

(defun my/profiler-toggle ()
  "Start the CPU/memory profiler, or stop it and show the report."
  (interactive)
  (require 'profiler)
  (if (profiler-running-p)
      (progn (profiler-stop) (profiler-report))
    (profiler-start 'cpu+mem)
    (message "Profiler started; press SPC d p p again to stop and report")))

;;; Leader groups

(lazyemacs-define-leader-map
 'my/leader-buffer-prefix
 '(("b" "Switch to other buffer" crux-switch-to-previous-buffer)
   ("d" "Delete buffer" kill-current-buffer)
   ("D" "Delete buffer and window" my/kill-buffer-and-window)
   ("o" "Delete other buffers" my/kill-other-file-buffers)
   ("i" "Delete invisible buffers" my/kill-invisible-file-buffers)
   ("j" "Pick buffer" consult-buffer)
   ("K" "Kill buffer…" kill-buffer)))

(lazyemacs-define-leader-map
 'my/leader-code-prefix
 '(("a" "Code action" my/lsp-code-actions)
   ("A" "Source action" my/lsp-source-actions)
   ("c" "Run codelens" my/lsp-run-codelens)
   ("C" "Refresh codelens" my/lsp-refresh-codelens)
   ("d" "Line diagnostics" my/show-diagnostic-at-point)
   ("f" "Format" my/format-buffer)
   ("l" "LSP info" lsp-describe-session)
   ("m" "Install language server" my/lsp-install-server)
   ("o" "Organize imports" my/lsp-organize-imports)
   ("r" "Rename symbol" my/lsp-rename)
   ("R" "Rename file" crux-rename-file-and-buffer)
   ("s" "Symbols" my/lsp-file-symbols)))

(lazyemacs-define-leader-map
 'my/leader-debug-profiler-prefix
 '(("p" "Toggle profiler" my/profiler-toggle)
   ("h" "Profiler report" profiler-report)))

(lazyemacs-define-leader-map
 'my/leader-debug-prefix
 `(("a" "Run with arguments" dape)
   ("b" "Toggle breakpoint" dape-breakpoint-toggle)
   ("B" "Conditional breakpoint" dape-breakpoint-expression)
   ("c" "Run/Continue" my/debug-continue)
   ("C" "Run to cursor" dape-until)
   ("e" "Eval expression" dape-evaluate-expression)
   ("i" "Step into" dape-step-in)
   ("j" "Down stack frame" dape-stack-select-down)
   ("k" "Up stack frame" dape-stack-select-up)
   ("l" "Restart" dape-restart)
   ("L" "Log point" dape-breakpoint-log)
   ("o" "Step out" dape-step-out)
   ("O" "Step over" dape-next)
   ("P" "Pause" dape-pause)
   ("r" "Toggle REPL" dape-repl)
   ("s" "Session" dape-select-session)
   ("t" "Terminate" dape-quit)
   ("u" "Debugger UI" dape-info)
   ("w" "Watch expression" dape-watch-dwim)
   ("X" "Remove all breakpoints" dape-breakpoint-remove-all)
   ("p" "Profiler" ,(symbol-function 'my/leader-debug-profiler-prefix))))

(lazyemacs-define-leader-map
 'my/leader-error-prefix
 '(("x" "Diagnostics (workspace)" my/lsp-diagnostics)
   ("X" "Buffer diagnostics" my/lsp-file-diagnostics)
   ("f" "Flycheck picker" consult-flycheck)
   ("l" "Location list" flycheck-list-errors)
   ("L" "Location list" flycheck-list-errors)
   ("q" "Quickfix list" my/results-show)
   ("Q" "Quickfix list" my/results-show)
   ("t" "Todo" my/search-todos)
   ("T" "Todo/Fix/Fixme" my/search-fixmes)))

(lazyemacs-define-leader-map
 'my/leader-file-prefix
 '(("b" "Buffers" consult-project-buffer)
   ("B" "Buffers (all)" consult-buffer)
   ("c" "Private config" my/open-init-file)
   ("d" "Recent directories" consult-dir)
   ("D" "Delete file" crux-delete-file-and-buffer)
   ("e" "Explorer (root)" my/project-explorer)
   ("E" "Explorer (cwd)" dirvish-side)
   ("f" "Find files (root)" project-find-file)
   ("F" "Find files (cwd)" my/find-file-cwd)
   ("g" "Find files (git)" project-find-file)
   ("j" "Dired here" dired-jump)
   ("n" "New file" my/new-file)
   ("o" "Open externally" crux-open-with)
   ("p" "Projects" project-switch-project)
   ("r" "Recent" consult-recent-file)
   ("R" "Recent (cwd)" my/recent-files-cwd)
   ("s" "Save" save-buffer)
   ("S" "Save as" write-file)
   ("t" "Terminal (root)" my/project-ghostel-new)
   ("T" "Terminal (cwd)" my/directory-ghostel)
   ("u" "Sudo edit" sudo-edit)
   ("y" "Copy path" my/copy-buffer-file-name)))

(lazyemacs-define-leader-map
 'my/leader-git-hunk-prefix
 '(("b" "Blame line" magit-blame-addition)
   ("d" "Diff this" magit-diff-buffer-file)
   ("p" "Preview hunk" diff-hl-show-hunk)
   ("r" "Reset hunk" diff-hl-revert-hunk)
   ("R" "Reset buffer" vc-revert)
   ("s" "Stage hunk" diff-hl-stage-current-hunk)
   ("u" "Unstage file" diff-hl-unstage-file)))

(lazyemacs-define-leader-map
 'my/leader-git-prefix
 `(("b" "Blame" magit-blame-addition)
   ("B" "Browse (open)" my/git-browse)
   ("c" "Commits" magit-log-current)
   ("d" "Diff (file)" magit-diff-buffer-file)
   ("D" "Diff (upstream)" my/git-diff-upstream)
   ("f" "File history" magit-log-buffer-file)
   ("g" "Magit (root)" magit-status)
   ("G" "Magit (cwd)" my/git-status-cwd)
   ("l" "Log" magit-log-current)
   ("L" "Log (cwd)" my/git-log-cwd)
   ("s" "Status" magit-status)
   ("S" "Stash" magit-stash)
   ("Y" "Copy link" my/git-copy-link)
   ("h" "Hunks" ,(symbol-function 'my/leader-git-hunk-prefix))))

(lazyemacs-define-leader-map
 'my/leader-help-prefix
 '(("c" "Command" helpful-command)
   ("D" "LazyEmacs doctor" lazyemacs-doctor)
   ("f" "Function" helpful-callable)
   ("i" "Info manuals" info)
   ("k" "Key" helpful-key)
   ("K" "Keymap" describe-keymap)
   ("l" "Search manuals" consult-info)
   ("m" "Major mode" describe-mode)
   ("p" "Package" describe-package)
   ("T" "Install tree-sitter grammars" lazyemacs-install-grammars)
   ("v" "Variable" helpful-variable)))

(lazyemacs-define-leader-map
 'my/leader-jump-prefix
 '(("b" "Back" xref-go-back)
   ("c" "Char (avy)" avy-goto-char-timer)
   ("f" "Forward" xref-go-forward)
   ("l" "Line" consult-goto-line)
   ("o" "Outline" consult-outline)
   ("w" "Word (avy)" avy-goto-word-1)))

(lazyemacs-define-leader-map
 'my/leader-multiple-cursors-prefix
 '(("a" "All matches" evil-mc-make-all-cursors)
   ("l" "Cursor per selected line" evil-mc-make-cursor-in-visual-selection-beg)
   ("n" "Next match" evil-mc-make-and-goto-next-match)
   ("p" "Previous match" evil-mc-make-and-goto-prev-match)
   ("s" "Skip match" evil-mc-skip-and-goto-next-match)
   ("u" "Undo last cursor" evil-mc-undo-last-added-cursor)
   ("q" "Remove all cursors" evil-mc-undo-all-cursors)))

(lazyemacs-define-leader-map
 'my/leader-mail-prefix
 '(("b" "Bookmarks" mu4e-search-bookmark)
   ("c" "Compose" mu4e-compose-new)
   ("i" "Initialize index" my/mu4e-initialize-index)
   ("j" "Maildir" mu4e-search-maildir)
   ("m" "Open mail" my/mu4e-open)
   ("s" "Search" mu4e-search)
   ("u" "Update" mu4e-update-mail-and-index)))

(lazyemacs-define-leader-map
 'my/leader-org-prefix
 '(("a" "Agenda" org-agenda)
   ("c" "Capture" org-capture)
   ("d" "Daily dashboard" my/org-agenda-dashboard)
   ("l" "Store link" org-store-link)))

(lazyemacs-define-leader-map
 'my/leader-project-prefix
 '(("b" "Buffers" consult-project-buffer)
   ("c" "Compile" project-compile)
   ("d" "Dired" project-dired)
   ("f" "Find file" project-find-file)
   ("k" "Kill buffers" project-kill-buffers)
   ("p" "Switch project" project-switch-project)
   ("s" "Search" consult-ripgrep)))

(lazyemacs-define-leader-map
 'my/leader-session-prefix
 '(("d" "Don't save current session" my/session-stop-saving)
   ("f" "Private config" my/open-init-file)
   ("l" "Restore last session" my/session-restore)
   ("p" "Upgrade packages" my/package-upgrade-all)
   ("q" "Quit all" save-buffers-kill-emacs)
   ("r" "Reload module" my/reload-init-file)
   ("s" "Restore session" my/session-restore)
   ("S" "Save session" my/session-save)))

(lazyemacs-define-leader-map
 'my/leader-search-prefix
 '(("\"" "Registers" evil-show-registers)
   ("/" "Search history" consult-isearch-history)
   ("b" "Buffer lines" consult-line)
   ("B" "Grep open buffers" my/search-open-buffers)
   ("c" "Command history" my/command-history)
   ("C" "Commands" execute-extended-command)
   ("d" "Diagnostics" my/lsp-diagnostics)
   ("D" "Buffer diagnostics" my/lsp-file-diagnostics)
   ("f" "Find files (fd)" my/consult-find)
   ("g" "Grep (root)" consult-ripgrep)
   ("G" "Grep (cwd)" my/search-cwd)
   ("h" "Help pages" consult-info)
   ("H" "Highlights (faces)" list-faces-display)
   ("i" "Imenu" consult-imenu)
   ("j" "Jumps" evil-collection-consult-jump-list)
   ("k" "Keymaps" describe-bindings)
   ("l" "Location list" consult-flycheck)
   ("m" "Marks" consult-mark)
   ("M" "Man pages" consult-man)
   ("q" "Quickfix list" consult-compile-error)
   ("r" "Search and replace" my/search-replace)
   ("R" "Resume" vertico-repeat)
   ("s" "Symbols" my/lsp-file-symbols)
   ("S" "Symbols (workspace)" my/lsp-workspace-symbols)
   ("t" "Todo" my/search-todos)
   ("T" "Todo/Fix/Fixme" my/search-fixmes)
   ("u" "Undo tree" vundo)
   ("w" "Word (root)" my/search-word)
   ("W" "Word (cwd)" my/search-word-cwd)))

(lazyemacs-define-leader-map
 'my/leader-test-prefix
 '(("l" "Run last" my/project-test-last)
   ("o" "Show output" my/project-test-output)
   ("r" "Run nearest" my/project-test-nearest)
   ("S" "Stop" my/project-test-stop)
   ("t" "Run file" my/project-test-file)
   ("T" "Run all test files" my/project-test-all)))

(lazyemacs-define-leader-map
 'my/leader-ui-prefix
 '(("A" "Tabline" my/toggle-tab-bar)
   ("b" "Dark background" my/toggle-theme)
   ("C" "Colorscheme" consult-theme)
   ("d" "Diagnostics" my/lsp-toggle-diagnostics)
   ("f" "Auto format (global)" my/toggle-global-format-on-save)
   ("F" "Auto format (buffer)" my/toggle-format-on-save)
   ("g" "Indent guides" indent-bars-mode)
   ("h" "Inlay hints" my/lsp-toggle-inlay-hints)
   ("i" "Inspect position" describe-char)
   ("I" "Inspect tree" my/inspect-tree)
   ("l" "Line numbers" display-line-numbers-mode)
   ("L" "Relative numbers" my/toggle-relative-line-numbers)
   ("p" "Auto pairs" my/toggle-autopairs)
   ("r" "Redraw / clear highlight" my/redraw)
   ("s" "Spelling" my/toggle-spelling)
   ("w" "Wrap" visual-line-mode)
   ("Z" "Zoom window" my/window-zoom)))

;; `SPC w' is Vim's CTRL-W, exactly as in LazyVim: every `evil-window-map'
;; key works (s v w W q o c x r R H J K L + - < > = _ |), plus these extras.
(lazyemacs-define-leader-map
 'my/leader-window-prefix
 '(("1" "Only this window" delete-other-windows)
   ("a" "Ace window" ace-window)
   ("d" "Delete window" delete-window)
   ("h" "Go left" windmove-left)
   ("j" "Go down" windmove-down)
   ("k" "Go up" windmove-up)
   ("l" "Go right" windmove-right)
   ("m" "Zoom (maximize)" my/window-zoom)
   ("u" "Undo layout" winner-undo)
   ("U" "Redo layout" winner-redo)
   ("<left>" nil windmove-left)
   ("<down>" nil windmove-down)
   ("<up>" nil windmove-up)
   ("<right>" nil windmove-right))
 evil-window-map)

(lazyemacs-define-leader-map
 'my/leader-run-prefix
 '(("n" "Next task failure" my/project-task-next-error)
   ("o" "Task output" my/project-task-output)
   ("r" "Run task" my/project-run-task)
   ("R" "Rerun task" my/project-rerun-task)
   ("T" "Run task in terminal" my/project-task-terminal)))

(lazyemacs-define-leader-map
 'my/leader-workspace-prefix
 '(("<tab>" "New tab" tab-bar-new-tab)
   ("TAB" "New tab" tab-bar-new-tab)
   ("[" "Previous tab" project-tab-sessions-previous-tab)
   ("]" "Next tab" project-tab-sessions-next-tab)
   ("b" "Pick tab" project-tab-sessions-switch-tab)
   ("d" "Close tab" tab-bar-close-tab)
   ("f" "First tab" my/session-first-tab)
   ("g" "Sessions" my/session-switch)
   ("G" "Move tab to session" tab-bar-change-tab-group)
   ("l" "Last tab" my/session-last-tab)
   ("N" "New named layout" my/session-new-layout)
   ("o" "Close other tabs" my/session-close-other-tabs)
   ("r" "Rename tab" tab-bar-rename-tab)
   ("R" "Layout history forward" tab-bar-history-forward)
   ("u" "Layout history back" tab-bar-history-back)))

(lazyemacs-define-leader-map
 'my/leader-snippet-prefix
 '(("i" "Insert snippet" yas-insert-snippet)
   ("n" "New snippet" yas-new-snippet)
   ("v" "Visit snippet file" yas-visit-snippet-file)))

;; Keep the historical variable names; private configurations may use them.
(defvar my/leader-buffer-map (symbol-function 'my/leader-buffer-prefix))
(defvar my/leader-code-map (symbol-function 'my/leader-code-prefix))
(defvar my/leader-debug-map (symbol-function 'my/leader-debug-prefix))
(defvar my/leader-error-map (symbol-function 'my/leader-error-prefix))
(defvar my/leader-file-map (symbol-function 'my/leader-file-prefix))
(defvar my/leader-git-map (symbol-function 'my/leader-git-prefix))
(defvar my/leader-help-map (symbol-function 'my/leader-help-prefix))
(defvar my/leader-jump-map (symbol-function 'my/leader-jump-prefix))
(defvar my/leader-multiple-cursors-map (symbol-function 'my/leader-multiple-cursors-prefix))
(defvar my/leader-mail-map (symbol-function 'my/leader-mail-prefix))
(defvar my/leader-org-map (symbol-function 'my/leader-org-prefix))
(defvar my/leader-project-map (symbol-function 'my/leader-project-prefix))
(defvar my/leader-run-map (symbol-function 'my/leader-run-prefix))
(defvar my/leader-session-map (symbol-function 'my/leader-session-prefix))
(defvar my/leader-search-map (symbol-function 'my/leader-search-prefix))
(defvar my/leader-test-map (symbol-function 'my/leader-test-prefix))
(defvar my/leader-ui-map (symbol-function 'my/leader-ui-prefix))
(defvar my/leader-window-map (symbol-function 'my/leader-window-prefix))
(defvar my/leader-workspace-map (symbol-function 'my/leader-workspace-prefix))
(defvar my/leader-snippet-map (symbol-function 'my/leader-snippet-prefix))

;; (KEY DESCRIPTION MAP C-c-ALIAS).  Groups with a nil alias are SPC-only.
(defconst lazyemacs-leader-groups
  `(("b" "Buffers" ,my/leader-buffer-map "b")
    ("c" "Code" ,my/leader-code-map "c")
    ("d" "Debug" ,my/leader-debug-map "d")
    ("f" "Files" ,my/leader-file-map "f")
    ("g" "Git" ,my/leader-git-map "g")
    ("h" "Help" ,my/leader-help-map "h")
    ("j" "Jump" ,my/leader-jump-map "j")
    ("m" "Multiple cursors" ,my/leader-multiple-cursors-map "m")
    ,@(when lazyemacs-enable-mail
        `(("M" "Mail" ,my/leader-mail-map "M")))
    ("o" "Org" ,my/leader-org-map "o")
    ("p" "Projects" ,my/leader-project-map "p")
    ("q" "Quit/Session" ,my/leader-session-map "q")
    ("r" "Run tasks" ,my/leader-run-map "r")
    ("s" "Search" ,my/leader-search-map "s")
    ("t" "Tests" ,my/leader-test-map "t")
    ("u" "UI toggles" ,my/leader-ui-map "u")
    ("w" "Windows" ,my/leader-window-map "w")
    ("x" "Diagnostics/quickfix" ,my/leader-error-map "x")
    ("y" "Snippets" ,my/leader-snippet-map "y")
    ("TAB" "Tabs" ,my/leader-workspace-map "z")
    ("<tab>" "Tabs" ,my/leader-workspace-map nil))
  "Leader groups, their Which Key labels, and their C-c aliases.")

(defconst lazyemacs-leader-commands
  '(("SPC" "Find files (root)" project-find-file)
    ("," "Buffers" consult-project-buffer)
    ("/" "Grep (root)" consult-ripgrep)
    (":" "Command history" my/command-history)
    ("." "Toggle scratch" my/scratch-toggle)
    ("`" "Other buffer" crux-switch-to-previous-buffer)
    ("-" "Split below" split-window-below)
    ("|" "Split right" split-window-right)
    ("?" "Buffer keymaps" which-key-show-full-major-mode)
    ("e" "Explorer (root)" my/project-explorer)
    ("E" "Explorer (cwd)" dirvish-side)
    ("l" "Packages" list-packages)
    ("L" "LazyEmacs changelog" my/open-changelog)
    ("n" "Notification history" my/messages))
  "Single-key leader commands.")

(defvar my/leader-map
  (let ((map (make-sparse-keymap)))
    (pcase-dolist (`(,key ,description ,command) lazyemacs-leader-commands)
      (keymap-set map key (cons description command)))
    (pcase-dolist (`(,key ,description ,group ,_alias) lazyemacs-leader-groups)
      (keymap-set map key (cons description group)))
    map)
  "The complete SPC leader keymap.  Add private bindings with `keymap-set'.")

;; Install the leader under SPC in Evil states.  General's override map takes
;; precedence over mode maps, so the leader behaves identically everywhere.
(general-define-key
 :states '(normal visual motion)
 :keymaps 'override
 "SPC" my/leader-map)

;; Install only letter-based sub-prefixes under C-c.  This preserves C-c C-c,
;; C-c C-k, and other mode-specific conventions used by Org, compilation, and
;; programming modes.
(pcase-dolist (`(,_key ,description ,group ,alias) lazyemacs-leader-groups)
  (when alias
    (keymap-global-set (concat "C-c " alias) (cons description group))))
(keymap-global-set "C-c e" '("Explorer" . my/project-explorer))

;;; Tabs, sessions, and Super shortcuts

;; Select tabs within the current session; Super+0 selects its tenth tab.
(dotimes (index 10)
  (let ((number (1+ index)))
    (keymap-global-set (format "s-%d" (mod number 10))
                       (lambda () (interactive) (project-tab-sessions-select-tab number)))))
(keymap-global-set "C-<tab>" #'project-tab-sessions-next-tab)
(keymap-global-set "C-S-<tab>" #'project-tab-sessions-previous-tab)
(keymap-global-set "C-x t g" #'my/session-switch)
(keymap-global-set "C-x t P" #'project-tab-sessions-group-from-project)
(keymap-global-set "s-p" #'my/session-switch)
(keymap-global-set "s-t" #'tab-bar-new-tab)
(keymap-global-set "s-r" #'tab-bar-rename-tab)
(keymap-global-set "s-w" #'tab-bar-close-tab)

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

;; High-frequency LazyVim code navigation.  Leader equivalents remain available.
(general-define-key
 :states 'normal :keymaps 'override
 "gd" #'my/lsp-find-definitions
 "gi" nil
 "gI" #'my/lsp-find-implementations
 "gy" #'my/lsp-find-type-definition
 "gD" #'my/lsp-find-declaration
 "gK" #'my/lsp-signature-help
 "gai" #'my/lsp-incoming-calls
 "gao" #'my/lsp-outgoing-calls
 "gr" #'my/lsp-find-references
 "K" #'eldoc-doc-buffer
 "]d" #'flycheck-next-error
 "[d" #'flycheck-previous-error
 "]e" #'my/next-error-diagnostic
 "[e" #'my/previous-error-diagnostic
 "]w" #'my/next-warning-diagnostic
 "[w" #'my/previous-warning-diagnostic
 "]h" #'diff-hl-next-hunk
 "[h" #'diff-hl-previous-hunk
 "]t" #'hl-todo-next
 "[t" #'hl-todo-previous
 "]q" #'next-error
 "[q" #'previous-error
 "]b" #'next-buffer
 "[b" #'previous-buffer
 ;; LazyVim resizes windows with Ctrl+arrows.  macOS may reserve these for
 ;; Mission Control; `SPC w +/-/</>' is the portable alternative.
 "C-<up>" #'evil-window-increase-height
 "C-<down>" #'evil-window-decrease-height
 "C-<left>" #'evil-window-decrease-width
 "C-<right>" #'evil-window-increase-width)

;; mini.surround's gs* keys, as shipped by LazyVim.  Vim-surround's ys/cs/ds
;; remain available through Evil Surround.
(general-define-key
 :states 'normal :keymaps 'override
 "gsa" #'evil-surround-region
 "gsd" #'evil-surround-delete
 "gsr" #'evil-surround-change)
(general-define-key
 :states 'visual :keymaps 'override
 "gsa" #'evil-surround-region)

;; LazyVim keeps the selection after shifting it, so repeated < or > work.
(defun my/visual-shift-left ()
  "Shift the selection left and keep it selected."
  (interactive)
  (evil-shift-left evil-visual-beginning evil-visual-end)
  (evil-normal-state)
  (evil-visual-restore))

(defun my/visual-shift-right ()
  "Shift the selection right and keep it selected."
  (interactive)
  (evil-shift-right evil-visual-beginning evil-visual-end)
  (evil-normal-state)
  (evil-visual-restore))

(general-define-key
 :states 'visual :keymaps 'override
 "<" #'my/visual-shift-left
 ">" #'my/visual-shift-right)

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
(defvar ghostel-mode-map)
(defvar ghostel-semi-char-mode-map)
(defvar ghostel-char-mode-map)
(with-eval-after-load 'ghostel
  (dolist (map (list ghostel-mode-map ghostel-semi-char-mode-map
                     ghostel-char-mode-map))
    (keymap-set map "C-h" #'windmove-left)
    (keymap-set map "C-j" #'windmove-down)
    (keymap-set map "C-k" #'windmove-up)
    (keymap-set map "C-l" #'windmove-right)))

;;; Editing-buffer shortcuts

(define-minor-mode my/editor-shortcuts-mode
  "LazyVim editing keys, excluding terminals, minibuffers and special buffers."
  :lighter nil :keymap (make-sparse-keymap))
(evil-define-minor-mode-key '(normal insert visual replace) 'my/editor-shortcuts-mode
  (kbd "C-s") #'save-buffer
  (kbd "M-j") #'move-text-down
  (kbd "M-k") #'move-text-up)
(evil-define-minor-mode-key 'normal 'my/editor-shortcuts-mode
  (kbd "H") #'previous-buffer
  (kbd "L") #'next-buffer)

(defun my/editor-shortcuts-setup ()
  "Enable editing shortcuts only in ordinary editing buffers."
  (my/editor-shortcuts-mode
   (if (and (not (minibufferp))
            (not (derived-mode-p 'special-mode 'comint-mode 'term-mode 'ghostel-mode))
            (or (derived-mode-p 'prog-mode 'text-mode 'conf-mode)
                (eq major-mode 'fundamental-mode))) 1 -1)))
(add-hook 'after-change-major-mode-hook #'my/editor-shortcuts-setup)
(dolist (buffer (buffer-list))
  (with-current-buffer buffer (my/editor-shortcuts-setup)))

;;; Familiar Emacs shortcuts upgraded with richer commands

(keymap-global-set "C-s" #'consult-line)
(keymap-global-set "M-y" #'consult-yank-pop)
(keymap-global-set "C-x b" #'consult-buffer)
(keymap-global-set "C-x p b" #'consult-project-buffer)
(keymap-global-unset "C-x p e")
(keymap-global-unset "C-x p s")
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
(keymap-global-unset "M-<up>")
(keymap-global-unset "M-<down>")
(keymap-global-unset "C-:")
(keymap-global-set "C-a" #'crux-move-beginning-of-line)
(keymap-global-set "C-k" #'crux-smart-kill-line)
(keymap-global-set "M-;" #'comment-dwim-2)
(keymap-global-set "M-R" #'vertico-repeat)
(keymap-global-unset "M-g c")
(keymap-global-unset "M-g w")
(keymap-global-set "M-g g" #'consult-goto-line)
(keymap-global-set "M-g i" #'consult-imenu)
(keymap-global-set "M-s r" #'consult-ripgrep)
(keymap-global-set "C-`" #'popper-toggle)
(keymap-global-set "M-`" #'popper-cycle)
(keymap-global-set "C-M-`" #'popper-toggle-type)

;; Helpful is a drop-in improvement for the built-in help namespace.
(keymap-global-set "C-h f" #'helpful-callable)
(keymap-global-set "C-h v" #'helpful-variable)
(keymap-global-set "C-h k" #'helpful-key)
(keymap-global-set "C-h x" #'helpful-command)

(provide 'init-keymaps)
;;; init-keymaps.el ends here
