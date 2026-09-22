;;; init-development.el --- Tree-sitter, LSP, diagnostics, and formatting -*- lexical-binding: t; -*-

;;; Commentary:
;; lsp-mode is the sole Language Server Protocol client.  It integrates with
;; xref, ElDoc, Corfu, and Flycheck.  Apheleia handles asynchronous
;; format-on-save independently of the language server.

;;; Code:

(require 'seq)

(defgroup my/development nil
  "Programming and language-server settings."
  :group 'tools)

(defcustom my/lsp-visual-extras nil
  "Whether lsp-mode should continuously maintain extra visual decorations.

When non-nil, enable reference highlighting, headerline breadcrumbs, inlay
hints, and modeline code-action indicators.  These are attractive but each can
request data or rebuild overlays as point and buffers change.  Diagnostics,
completion, Eldoc, xref, and every explicit LSP command work either way."
  :type 'boolean
  :group 'my/development)

(defcustom my/lsp-diagnostics-enabled t
  "Whether LSP diagnostics should be enabled when a client starts.

This controls lsp-mode's Flycheck diagnostics integration.  Change it through
Customize for a persistent default, or use
`my/lsp-toggle-diagnostics' to toggle diagnostics during a session."
  :type 'boolean
  :group 'my/development)

(defcustom my/lsp-auto-start-delay 0.25
  "Idle seconds before automatically loading lsp-mode for a new buffer.

The short delay lets Emacs display and fontify a file before loading lsp-mode
for the first time.  `my/lsp-start' remains an immediate manual command."
  :type 'number
  :group 'my/development)

(defvar flycheck-current-errors)
(defvar flycheck-display-errors-function)

(defvar-local my/lsp-auto-start-timer nil
  "Pending automatic lsp-mode startup timer for the current buffer.")

;;; Tree-sitter and language modes

;; Level 3 retains comprehensive syntax highlighting while avoiding the most
;; decorative and expensive level-4 captures during buffer previews.
(setq treesit-font-lock-level 3)

;; Avoid treesit-auto's global `set-auto-mode-0' advice.  On macOS it probed
;; every grammar several times for every visited or previewed file, adding
;; roughly 1.5 seconds to `find-file' and therefore to Consult previews too.
;; Use the built-in modes directly for grammars that are already installed;
;; ordinary major modes remain dependable fallbacks on other machines.
(require 'init-languages)

(use-package markdown-mode
  :mode
  (("README\\.md\\'" . gfm-mode)
   ("\\.md\\'" . markdown-mode))
  :custom
  (markdown-fontify-code-blocks-natively t)
  (markdown-command "pandoc"))

(use-package yaml-mode
  :mode "\\.ya?ml\\'")

(use-package terraform-mode
  :mode "\\.tf\\'")

(use-package dotenv-mode
  :mode "\\.env\\(?:\\..*\\)?\\'")

(use-package go-mode
  :mode "\\.go\\'")

(use-package rust-mode
  :mode "\\.rs\\'")

(use-package lua-mode
  :mode "\\.lua\\'")

(use-package dockerfile-mode
  :mode "\\(?:Dockerfile\\|Containerfile\\)\\(?:\\..*\\)?\\'")

(use-package graphql-mode
  :mode "\\.graphqls?\\'")

;; Prisma mode is not currently published in the configured ELPA archives.
;; conf-mode provides dependable comments/indentation instead of making startup
;; depend on an unversioned Git checkout.
(add-to-list 'auto-mode-alist '("\\.prisma\\'" . conf-mode))

(use-package restclient
  :mode "\\.http\\'")

(use-package editorconfig
  :demand t
  :init
  (editorconfig-mode 1))

;;; Language Server Protocol

(defun my/executable-find-any (&rest commands)
  "Return the first executable found among COMMANDS."
  (seq-some #'executable-find commands))

(defun my/lsp-add-installed-servers-to-path ()
  "Put servers installed by `SPC c m' on `exec-path'.
lsp-mode installs npm-based servers below `var/lsp/servers/npm/'.  Adding
their executable directories lets automatic startup detect them exactly like
servers installed by the system package manager."
  (let ((npm (no-littering-expand-var-file-name "lsp/servers/npm/")))
    (when (file-directory-p npm)
      (dolist (package (directory-files npm t directory-files-no-dot-files-regexp))
        (let ((bin (if (eq system-type 'windows-nt)
                       package
                     (expand-file-name "bin" package))))
          (when (file-directory-p bin)
            (add-to-list 'exec-path bin t)))))))

(my/lsp-add-installed-servers-to-path)

(defun my/language-server-available-p ()
  "Return non-nil when this buffer's language server is installed.

This guard prevents lsp-mode from prompting or emitting an error every time a
language without an installed server is opened."
  (cond
   ((derived-mode-p 'typescript-mode 'typescript-ts-mode 'tsx-ts-mode
                    'js-mode 'js-ts-mode 'jsx-ts-mode)
    (my/executable-find-any "typescript-language-server"))
   ((derived-mode-p 'python-mode 'python-ts-mode)
    (my/executable-find-any
     "basedpyright-langserver" "pyright-langserver" "pylsp"))
   ((derived-mode-p 'go-mode 'go-ts-mode)
    (my/executable-find-any "gopls"))
   ((derived-mode-p 'rust-mode 'rust-ts-mode)
    (my/executable-find-any "rust-analyzer"))
   ((derived-mode-p 'json-mode 'json-ts-mode)
    (my/executable-find-any "vscode-json-language-server"))
   ((derived-mode-p 'css-mode 'css-ts-mode)
    (my/executable-find-any "vscode-css-language-server"))
   ((derived-mode-p 'html-mode 'html-ts-mode)
    (my/executable-find-any "vscode-html-language-server"))
   ((derived-mode-p 'yaml-mode 'yaml-ts-mode)
    (my/executable-find-any "yaml-language-server"))
   ((derived-mode-p 'dockerfile-mode 'dockerfile-ts-mode)
    (my/executable-find-any "docker-langserver"))
   ((derived-mode-p 'lua-mode 'lua-ts-mode)
    (my/executable-find-any "lua-language-server"))
   ;; bash-language-server does not attach to zsh/fish scripts.
   ((and (derived-mode-p 'sh-mode 'bash-ts-mode)
         (memq (bound-and-true-p sh-shell) '(sh bash)))
    (my/executable-find-any "bash-language-server"))
   (t nil)))

(defun my/lsp-start ()
  "Start lsp-mode in the current buffer."
  (interactive)
  ;; lsp-pyright is a separate client package.  Requiring it before startup
  ;; registers basedpyright/pyright for both Python major modes.
  (when (derived-mode-p 'python-mode 'python-ts-mode)
    (require 'lsp-pyright))
  (lsp-deferred))

(defun my/lsp-ensure ()
  "Schedule lsp-mode when a local language server is installed.

Deferring the package load until Emacs is idle keeps the initial file visit and
Consult preview responsive."
  (when (and (not (file-remote-p default-directory))
             (or (my/language-server-available-p)
                 ;; Installation is asynchronous; detect newly installed servers.
                 (progn (my/lsp-add-installed-servers-to-path)
                        (my/language-server-available-p))))
    (when (timerp my/lsp-auto-start-timer)
      (cancel-timer my/lsp-auto-start-timer))
    (setq my/lsp-auto-start-timer
          (run-with-idle-timer
           my/lsp-auto-start-delay nil
           (lambda (buffer)
             (when (buffer-live-p buffer)
               (with-current-buffer buffer
                 (setq my/lsp-auto-start-timer nil)
                 (when (and (not (bound-and-true-p lsp-mode))
                            (not (file-remote-p default-directory))
                            (my/language-server-available-p))
                   (my/lsp-start)))))
           (current-buffer)))))

;;; Commands used by the leader keymaps

(defun my/lsp-code-actions ()
  "Select an lsp-mode code action."
  (interactive)
  (call-interactively #'lsp-execute-code-action))

(defun my/lsp-rename ()
  "Rename the symbol at point using lsp-mode."
  (interactive)
  (call-interactively #'lsp-rename))

(defun my/lsp-organize-imports ()
  "Organize imports using lsp-mode."
  (interactive)
  (call-interactively #'lsp-organize-imports))

(defun my/lsp-source-actions ()
  "Select a source-level code action, such as fixing all or sorting imports."
  (interactive)
  (my/lsp-require-feature "textDocument/codeAction")
  (lsp-execute-code-action-by-kind "source"))

(defun my/lsp-run-codelens ()
  "Pick and run a code lens in the current buffer."
  (interactive)
  (my/lsp-require-feature "textDocument/codeLens")
  (unless (bound-and-true-p lsp-lens-mode) (lsp-lens-mode 1))
  (lsp-avy-lens))

(defun my/lsp-refresh-codelens ()
  "Refresh code lenses in the current buffer."
  (interactive)
  (my/lsp-require-feature "textDocument/codeLens")
  (lsp-lens-refresh t))

(defun my/lsp-install-server ()
  "Install a language server into LazyEmacs's state, like LazyVim's Mason.
Servers that lsp-mode cannot install automatically must be installed with
your platform's package manager or the language's own toolchain."
  (interactive)
  (require 'lsp-mode)
  (call-interactively #'lsp-install-server)
  (message "Installing in the background; reopen the file once it finishes"))

(defun my/lsp-restart ()
  "Restart the active lsp-mode workspace."
  (interactive)
  (call-interactively #'lsp-workspace-restart))

(defun my/lsp-shutdown ()
  "Shut down the active lsp-mode workspace."
  (interactive)
  (call-interactively #'lsp-workspace-shutdown))

(defun my/lsp-workspace-symbols ()
  "Select a symbol from the active lsp-mode workspace."
  (interactive)
  (call-interactively #'consult-lsp-symbols))

(defun my/lsp-file-symbols ()
  "Select file symbols using LSP when attached, otherwise Imenu."
  (interactive)
  (call-interactively
   (if (bound-and-true-p lsp-managed-mode)
       #'consult-lsp-file-symbols
     #'consult-imenu)))

(defun my/lsp-find-definitions ()
  "Use LSP definitions in managed buffers, otherwise use the xref backend."
  (interactive)
  (call-interactively
   (if (bound-and-true-p lsp-managed-mode)
       #'lsp-find-definition
     #'xref-find-definitions)))

(defun my/lsp-find-implementations ()
  "Find implementations using lsp-mode."
  (interactive)
  (call-interactively #'lsp-find-implementation))

(defun my/lsp-find-references ()
  "Use LSP references in managed buffers, otherwise use the xref backend."
  (interactive)
  (call-interactively
   (if (bound-and-true-p lsp-managed-mode)
       #'lsp-find-references
     #'xref-find-references)))

(defun my/lsp-require-feature (method)
  "Require an attached server supporting METHOD."
  (require 'lsp-mode)
  (unless (and (bound-and-true-p lsp-managed-mode) (lsp-feature? method))
    (user-error "The current LSP server does not support %s" method)))

(defun my/lsp-find-type-definition ()
  "Find the type definition at point."
  (interactive)
  (my/lsp-require-feature "textDocument/typeDefinition")
  (call-interactively #'lsp-find-type-definition))

(defun my/lsp-find-declaration ()
  "Find the declaration at point."
  (interactive)
  (my/lsp-require-feature "textDocument/declaration")
  (call-interactively #'lsp-find-declaration))

(defun my/lsp-signature-help ()
  "Show signature help without taking over Ctrl-K window navigation."
  (interactive)
  (my/lsp-require-feature "textDocument/signatureHelp")
  (lsp-signature-activate))

(defun my/lsp-toggle-inlay-hints ()
  "Toggle inlay hints in the current managed buffer."
  (interactive)
  (my/lsp-require-feature "textDocument/inlayHint")
  (lsp-inlay-hints-mode 'toggle))

(defun my/lsp-call-hierarchy (outgoing)
  "Pick incoming callers, or callees when OUTGOING is non-nil."
  ;; lsp-mode names the capability callHierarchy; the wire request uses prepare.
  (my/lsp-require-feature "textDocument/callHierarchy")
  (let* ((items (lsp-request "textDocument/prepareCallHierarchy"
                             (lsp--text-document-position-params)))
         (choices (seq-map-indexed
                   (lambda (item index)
                     (cons (format "%d: %s" (1+ index) (plist-get item :name)) item))
                   items))
         (item (cond ((null choices) (user-error "No callable symbol at point"))
                     ((null (cdr choices)) (cdar choices))
                     (t (cdr (assoc (completing-read "Symbol: " choices nil t) choices)))))
         (calls (lsp-request (if outgoing "callHierarchy/outgoingCalls"
                              "callHierarchy/incomingCalls")
                            (list :item item)))
         (locations (seq-map
                     (lambda (call)
                       (let ((target (plist-get call (if outgoing :to :from))))
                         (list :uri (plist-get target :uri)
                               :range (plist-get target :selectionRange)))) calls))
         (xrefs (lsp--locations-to-xref-items locations)))
    (unless xrefs (user-error "No %s calls" (if outgoing "outgoing" "incoming")))
    (xref-show-xrefs (lambda () xrefs) nil)))

(defun my/lsp-incoming-calls ()
  "Find callers of the symbol at point."
  (interactive)
  (my/lsp-call-hierarchy nil))

(defun my/lsp-outgoing-calls ()
  "Find callees of the symbol at point."
  (interactive)
  (my/lsp-call-hierarchy t))

(defun my/diagnostic-next-level (level count)
  "Visit COUNT diagnostics of exactly LEVEL in the current buffer."
  (require 'flycheck)
  (let* ((positions (sort
                     (delete-dups
                      (mapcar #'flycheck-error-pos
                              (seq-filter (lambda (error)
                                            (eq (flycheck-error-level error) level))
                                          flycheck-current-errors))) #'<))
         (candidates (if (< count 0)
                         (reverse (seq-filter (lambda (p) (< p (point))) positions))
                       (seq-filter (lambda (p) (> p (point))) positions)))
         (target (nth (1- (abs count)) candidates)))
    (unless target (user-error "No more %s diagnostics" level))
    (goto-char target)
    (my/show-diagnostic-at-point)))

(defun my/next-error-diagnostic (count)
  "Move forward COUNT error diagnostics."
  (interactive "p")
  (my/diagnostic-next-level 'error count))
(defun my/previous-error-diagnostic (count)
  "Move backward COUNT error diagnostics."
  (interactive "p")
  (my/diagnostic-next-level 'error (- count)))
(defun my/next-warning-diagnostic (count)
  "Move forward COUNT warning diagnostics."
  (interactive "p")
  (my/diagnostic-next-level 'warning count))
(defun my/previous-warning-diagnostic (count)
  "Move backward COUNT warning diagnostics."
  (interactive "p")
  (my/diagnostic-next-level 'warning (- count)))

;; Evil checks the outer command before it runs.  These wrappers must carry
;; their own jump property so C-o can return even after a same-file LSP jump.
(with-eval-after-load 'evil
  (dolist (command '(my/lsp-find-definitions
                     my/lsp-find-implementations
                     my/lsp-find-references
                     my/lsp-find-type-definition my/lsp-find-declaration
                     my/lsp-incoming-calls my/lsp-outgoing-calls))
    (evil-set-command-property command :jump t)))

(defun my/lsp-diagnostics ()
  "Select a diagnostic from the active lsp-mode workspace."
  (interactive)
  (call-interactively #'consult-lsp-diagnostics))

(defun my/lsp-file-diagnostics ()
  "Select a diagnostic from the current file."
  (interactive)
  (call-interactively #'consult-lsp-file-diagnostics))

;; The leader commands are wrappers, so Consult sees their names in
;; `this-command'.  Give them the same delayed automatic preview as their
;; underlying xref and consult-lsp commands.
(with-eval-after-load 'consult
  (consult-customize
   my/lsp-find-definitions my/lsp-find-implementations my/lsp-find-references
   my/lsp-diagnostics my/lsp-file-diagnostics
   my/lsp-workspace-symbols my/lsp-file-symbols
   :preview-key '(:debounce 0.4 any)))

(defun my/lsp-apply-diagnostics-default ()
  "Apply `my/lsp-diagnostics-enabled' to the current managed buffer."
  (unless my/lsp-diagnostics-enabled
    ;; lsp-mode has a diagnostics integration mode in addition to Flycheck.
    (when (bound-and-true-p lsp-diagnostics-mode)
      (lsp-diagnostics-mode -1))
    (when (bound-and-true-p flycheck-mode)
      (flycheck-mode -1))))

(defun my/lsp-toggle-diagnostics ()
  "Toggle lsp-mode Flycheck diagnostics in the current buffer.

The new value also becomes the default for managed buffers opened later in
this Emacs session.  Use Customize to persist the choice across restarts."
  (interactive)
  (unless (bound-and-true-p lsp-managed-mode)
    (user-error "Start an LSP server before toggling its diagnostics"))
  (let ((enable (not (and (bound-and-true-p lsp-diagnostics-mode)
                          (bound-and-true-p flycheck-mode)))))
    (setq my/lsp-diagnostics-enabled enable)
    (require 'lsp-diagnostics)
    (require 'flycheck)
    (if enable
        (progn
          (lsp-diagnostics-mode 1)
          (flycheck-mode 1))
      (lsp-diagnostics-mode -1)
      (flycheck-mode -1))
    (message "Diagnostics %s" (if enable "enabled" "disabled"))))

;;; lsp-mode

(defun my/lsp-mode-setup ()
  "Apply buffer-local integration after lsp-mode starts."
  (lsp-enable-which-key-integration)
  ;; Run after lsp-mode's own configure hooks have enabled their provider.
  (add-hook 'lsp-configure-hook #'my/lsp-apply-diagnostics-default t t))

(use-package lsp-mode
  :commands
  (lsp lsp-deferred lsp-format-buffer lsp-rename lsp-organize-imports
       lsp-execute-code-action lsp-find-definition lsp-find-implementation
       lsp-find-references lsp-describe-session
       lsp-workspace-restart lsp-workspace-shutdown)
  :hook
  (lsp-mode . my/lsp-mode-setup)
  :init
  ;; basedpyright is the configured Python server.  Disable ty-ls so lsp-mode
  ;; does not attach two Python servers when the optional `ty' binary exists.
  (setq lsp-disabled-clients
        (cons 'ty-ls
              (remove 'ty-ls
                      (and (boundp 'lsp-disabled-clients)
                           lsp-disabled-clients))))
  :custom
  ;; C-c L exposes lsp-mode's complete built-in command map while C-c c keeps
  ;; the smaller command set defined by this configuration.
  (lsp-keymap-prefix "C-c L")
  ;; project.el already knows our manifest files, so reuse its root directly
  ;; instead of prompting to import every new project into lsp-mode's session.
  (lsp-auto-guess-root t)
  (lsp-guess-root-without-session t)
  ;; `:none' disables lsp-mode's Company setup, not its CAPF.  The LSP CAPF
  ;; remains active and is rendered by Corfu.
  (lsp-completion-provider :none)
  (lsp-completion-enable t)
  (lsp-enable-snippet t)
  ;; Flycheck is the only diagnostics frontend.
  (lsp-diagnostics-provider :flycheck)
  ;; lsp-mode uses this timer for highlights, links, lenses, and other refresh
  ;; work.  Half a second is its documented performance-oriented setting.
  (lsp-idle-delay 0.5)
  (lsp-log-io nil)
  (lsp-keep-workspace-alive nil)
  ;; Most language servers watch their own workspace.  lsp-mode's additional
  ;; recursive watchers can become expensive in monorepos and generated trees.
  (lsp-enable-file-watchers nil)
  ;; Tree-sitter/major modes provide these presentation features without extra
  ;; protocol traffic or overlays maintained after every server notification.
  (lsp-enable-folding nil)
  (lsp-enable-links nil)
  (lsp-enable-text-document-color nil)
  (lsp-lens-enable my/lsp-visual-extras)
  ;; Keep navigation responsive by default.  Set `my/lsp-visual-extras' to t
  ;; before this module loads if the continuously updated decorations are worth
  ;; their extra requests and redisplay work on a particular setup.
  (lsp-enable-symbol-highlighting my/lsp-visual-extras)
  (lsp-headerline-breadcrumb-enable my/lsp-visual-extras)
  (lsp-modeline-code-actions-enable my/lsp-visual-extras)
  (lsp-enable-on-type-formatting nil)
  (lsp-inlay-hint-enable my/lsp-visual-extras)
  (lsp-eldoc-render-all nil)
  (lsp-session-file
   (no-littering-expand-var-file-name "lsp/session-v1"))
  (lsp-server-install-dir
   (no-littering-expand-var-file-name "lsp/servers/"))
  :config
  ;; LSP candidates have their own completion category.  Explicitly selecting
  ;; Orderless avoids a server-specific prefix-only fallback.
  (add-to-list 'completion-category-overrides
               '(lsp-capf (styles orderless))))

(use-package lsp-pyright
  :after lsp-mode
  :defer t
  :init
  (setq lsp-pyright-langserver-command
        (if (executable-find "basedpyright-langserver")
            "basedpyright"
          "pyright")))

(use-package consult-lsp
  :after (consult lsp-mode)
  :commands
  (consult-lsp-diagnostics consult-lsp-file-diagnostics
   consult-lsp-symbols consult-lsp-file-symbols)
  :config
  (consult-customize
   consult-lsp-diagnostics consult-lsp-file-diagnostics
   consult-lsp-symbols consult-lsp-file-symbols
   :preview-key '(:debounce 0.4 any)))

;; Adding a mode here enables automatic lsp-mode startup when its server is
;; installed locally.
(dolist (hook '(python-mode-hook python-ts-mode-hook
                js-mode-hook js-ts-mode-hook jsx-ts-mode-hook
                typescript-mode-hook typescript-ts-mode-hook tsx-ts-mode-hook
                go-mode-hook go-ts-mode-hook
                rust-mode-hook rust-ts-mode-hook
                json-mode-hook json-ts-mode-hook
                css-mode-hook css-ts-mode-hook
                html-mode-hook html-ts-mode-hook
                yaml-mode-hook yaml-ts-mode-hook
                dockerfile-mode-hook dockerfile-ts-mode-hook
                lua-mode-hook lua-ts-mode-hook
                sh-mode-hook bash-ts-mode-hook))
  (add-hook hook #'my/lsp-ensure))

;;; Diagnostics and documentation

(defun my/show-diagnostic-at-point ()
  "Show diagnostics explicitly in the echo area, without opening Eldoc."
  (interactive)
  (require 'flycheck)
  (let ((flycheck-display-errors-function #'flycheck-display-error-messages))
    (flycheck-display-error-at-point)))

(use-package flycheck
  :commands
  (flycheck-list-errors flycheck-next-error flycheck-previous-error)
  :custom
  ;; lsp-mode uses Flycheck's idle-change refresh to redisplay diagnostics that
  ;; the server pushed while a buffer is modified.  A generous delay keeps
  ;; that necessary refresh away from active typing.
  (flycheck-check-syntax-automatically '(save mode-enabled idle-change))
  (flycheck-idle-change-delay 0.8)
  ;; Keep error underlines/list navigation, but do not feed errors to Eldoc
  ;; or show them automatically when point lands on an error.
  (flycheck-display-errors-function nil)
  (flycheck-indication-mode 'right-fringe)
  (flycheck-emacs-lisp-load-path 'inherit))

(use-package consult-flycheck
  :after (consult flycheck)
  :commands consult-flycheck)

(use-package eldoc
  :ensure nil
  :custom
  (eldoc-idle-delay 0.35)
  (eldoc-echo-area-use-multiline-p nil)
  (eldoc-documentation-strategy #'eldoc-documentation-compose-eagerly))

;;; Formatting

(defun my/project-formatter ()
  "Honor explicit formatter settings and project Biome configuration.
Otherwise retain Apheleia's mode defaults.  Use directory-local
`apheleia-formatter' for projects with a different formatting policy."
  (unless (or (file-remote-p default-directory)
              (local-variable-p 'apheleia-formatter))
    (when (and (derived-mode-p 'js-mode 'js-ts-mode 'typescript-ts-mode
                              'tsx-ts-mode 'typescript-mode 'json-mode 'json-ts-mode
                              'css-mode 'css-ts-mode)
               (or (locate-dominating-file default-directory "biome.json")
                   (locate-dominating-file default-directory "biome.jsonc")))
      (setq-local apheleia-formatter 'biome))))

(defun my/format-buffer (&optional beg end)
  "Format the buffer, or the region BEG to END without formatting outside it."
  (interactive (when (use-region-p) (list (region-beginning) (region-end))))
  (if (and beg end)
      (progn
        (when (and (bound-and-true-p evil-visual-state-minor-mode)
                   (eq evil-visual-selection 'block))
          (user-error "Select a contiguous region for range formatting"))
        (unless (and (bound-and-true-p lsp-managed-mode)
                     (lsp-feature? "textDocument/rangeFormatting"))
          (user-error "Range formatting needs a supporting LSP server; use = to indent"))
        (lsp-format-region beg end))
    (require 'apheleia)
    (my/project-formatter)
    (if-let* ((formatters (apheleia--get-formatters)))
        (apheleia-format-buffer formatters)
      (if (and (bound-and-true-p lsp-managed-mode)
               (lsp-feature? "textDocument/formatting"))
          (lsp-format-buffer)
        (indent-region (point-min) (point-max))))))

(defun my/toggle-global-format-on-save ()
  "Toggle format-on-save across eligible buffers, including future buffers."
  (interactive)
  (require 'apheleia)
  (apheleia-global-mode (if (bound-and-true-p apheleia-global-mode) -1 1))
  (message "Global format on save %s" (if apheleia-global-mode "enabled" "disabled")))

(defun my/toggle-format-on-save ()
  "Toggle Apheleia's format-on-save behavior in the current buffer."
  (interactive)
  ;; Keep the formatter completely off the file-opening path until requested.
  (require 'apheleia)
  (my/project-formatter)
  (if (bound-and-true-p apheleia-mode)
      (apheleia-mode -1)
    (apheleia-mode 1))
  (message "Format on save %s" (if apheleia-mode "enabled" "disabled")))

(use-package apheleia
  :commands (apheleia-mode apheleia-format-buffer)
  :hook (apheleia-mode . my/project-formatter))

;;; Snippets and compilation

(use-package yasnippet
  :diminish yas-minor-mode
  :hook
  ((prog-mode text-mode conf-mode) . yas-minor-mode)
  :commands (yas-insert-snippet yas-new-snippet yas-visit-snippet-file))

;; Yasnippet is only the expansion engine; it intentionally ships without a
;; general-purpose snippet library.  Install the maintained community
;; collection so common programming and text modes have useful snippets.
;; `no-littering' keeps `etc/yasnippet/snippets/' in `yas-snippet-dirs' as a
;; separate location for snippets created with `yas-new-snippet'.
(use-package yasnippet-snippets
  ;; Its autoload initializes the collection when Yasnippet first starts.  Keep
  ;; this declaration deferred so startup does not scan snippets prematurely.
  :defer t)

(use-package compile
  :ensure nil
  :commands (compile recompile project-compile)
  :custom
  (compilation-scroll-output 'first-error)
  (compilation-always-kill t)
  (compilation-ask-about-save nil))

(provide 'init-development)
;;; init-development.el ends here
