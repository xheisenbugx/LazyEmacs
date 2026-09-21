;;; init-completion.el --- Pickers, minibuffer actions, and code completion -*- lexical-binding: t; -*-

;;; Commentary:
;; This is the Emacs equivalent of LazyVim's picker/completion layer:
;; Vertico renders candidates, Orderless filters them, Marginalia annotates
;; them, Consult supplies commands, and Embark supplies context-sensitive
;; actions.  Corfu and Cape provide completion inside editing buffers.

;;; Code:

;;; Minibuffer fundamentals

(setq enable-recursive-minibuffers t
      completion-cycle-threshold 3
      completions-detailed t
      completion-ignore-case t
      read-buffer-completion-ignore-case t
      read-file-name-completion-ignore-case t
      read-extended-command-predicate #'command-completion-default-include-p
      minibuffer-prompt-properties
      '(read-only t cursor-intangible t face minibuffer-prompt))

(minibuffer-depth-indicate-mode 1)
(file-name-shadow-mode 1)

(use-package vertico
  :demand t
  :init
  (vertico-mode 1)
  :custom
  (vertico-cycle t)
  (vertico-count 15)
  (vertico-resize t)
  :bind
  (:map vertico-map
        ("M-RET" . vertico-exit-input)))

;; The directory extension makes DEL move up through path components and keeps
;; shadowed path text tidy while using find-file.
(use-package vertico-directory
  :ensure nil
  :after vertico
  :bind
  (:map vertico-map
        ("RET" . vertico-directory-enter)
        ("DEL" . vertico-directory-delete-char)
        ("M-DEL" . vertico-directory-delete-word))
  :hook
  (rfn-eshadow-update-overlay . vertico-directory-tidy))

;; Save completion sessions so `M-R' can repeat the last picker.
(use-package vertico-repeat
  :ensure nil
  :after vertico
  :hook
  (minibuffer-setup . vertico-repeat-save)
  :bind
  (:map vertico-map
        ("M-P" . vertico-repeat-previous)
        ("M-N" . vertico-repeat-next)))

(use-package orderless
  :demand t
  :custom
  ;; Space-separated components can match in any order.  `basic' remains as a
  ;; fallback for dynamic completion tables that require prefix matching.
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides
   '((file (styles partial-completion basic)))))

(use-package marginalia
  :demand t
  :init
  (marginalia-mode 1)
  :custom
  (marginalia-align 'right))

;;; Search and navigation pickers

(defun my/consult-find ()
  "Find a file with fd when available, otherwise use POSIX find."
  (interactive)
  (call-interactively
   (if (executable-find "fd") #'consult-fd #'consult-find)))

(use-package consult
  :demand t
  :init
  ;; Use Consult's preview UI for registers and xref results.
  (unless (advice-member-p #'consult-register-window #'register-preview)
    (advice-add #'register-preview :override #'consult-register-window))
  (setq register-preview-delay 0.4
        xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)
  :custom
  ;; Preview every supported candidate automatically after a short pause.  The
  ;; debounce keeps fast candidate movement smooth without removing previews.
  (consult-preview-key '(:debounce 0.2 any))
  (consult-narrow-key "<")
  :config
  ;; File-backed and cross-buffer previews remain automatic, but wait until
  ;; candidate movement pauses.  This avoids repeatedly opening/fontifying
  ;; candidates while preserving the live-preview workflow.
  (consult-customize
   consult-buffer consult-project-buffer
   consult-bookmark consult-recent-file consult-xref
   consult-source-bookmark consult-source-file-register
   consult-source-recent-file consult-source-project-recent-file
   :preview-key '(:debounce 0.4 any))
  ;; Keep the configuration's original exception: grep commands can start an
  ;; expensive recursive process, so M-. requests their preview explicitly.
  (consult-customize consult-ripgrep consult-git-grep consult-grep
                     :preview-key "M-."))

(use-package consult-dir
  :after (consult vertico)
  :bind
  (:map vertico-map
        ("C-x C-d" . consult-dir)
        ("C-x C-j" . consult-dir-jump-file)))

(use-package embark
  :demand t
  :init
  ;; C-h after a leader prefix now opens an Embark-powered list of commands.
  (setq prefix-help-command #'embark-prefix-help-command))

(use-package embark-consult
  :after (embark consult)
  :init
  ;; Consult 3.4 removed `consult-preview-at-point-mode'.  Older versions of
  ;; this configuration added it to the collect hook, which made Emacs try to
  ;; autoload that deleted function from embark-consult.  Remove the stale hook
  ;; when reloading the config; current embark-consult installs its replacement,
  ;; `consult--default-completion-list-preview-setup', automatically.
  (remove-hook 'embark-collect-mode-hook #'consult-preview-at-point-mode))

(defun my/find-file-cwd ()
  "Pick a file under the current directory, without switching to project root."
  (interactive)
  (funcall (if (executable-find "fd") #'consult-fd #'consult-find) default-directory))

(defun my/recent-files-cwd ()
  "Pick a recent file under the current directory."
  (interactive)
  (let* ((directory default-directory)
         (recentf-list (seq-filter (lambda (file) (file-in-directory-p file directory))
                                   recentf-list)))
    (consult-recent-file)))

(defun my/search-cwd ()
  "Search text under the current directory."
  (interactive)
  (consult-ripgrep default-directory))

(defun my/search-open-buffers ()
  "Search lines across all open buffers."
  (interactive)
  (consult-line-multi t))

(defun my/search-text-at-point ()
  "Return the selected text or symbol, requiring a single line."
  (let ((text (if (use-region-p)
                  (buffer-substring-no-properties (region-beginning) (region-end))
                (thing-at-point 'symbol t))))
    (unless (and text (not (string-empty-p text)))
      (user-error "Select text or place point on a symbol"))
    (when (string-match-p "\n" text)
      (user-error "Select a single line for this search"))
    text))

(defun my/search-word (&optional cwd)
  "Search the selected text or symbol literally; with CWD use current directory."
  (interactive)
  (let* ((text (my/search-text-at-point))
         (consult-ripgrep-args
          (if (stringp consult-ripgrep-args)
              (concat consult-ripgrep-args " --fixed-strings")
            (append consult-ripgrep-args '("--fixed-strings")))))
    (consult-ripgrep (and cwd default-directory) text)))

(defun my/search-word-cwd ()
  "Search selected text or symbol literally in the current directory."
  (interactive)
  (my/search-word t))

(defun my/search-replace-edit-export ()
  "Enter native editing in a newly exported grep buffer."
  (when (derived-mode-p 'grep-mode) (my/local-actions-edit)))

(defun my/search-replace ()
  "Search the project, then press RET to export editable grep results.
Edits update source buffers; finish with backslash c and save files explicitly."
  (interactive)
  (let ((embark-after-export-hook
         (cons #'my/search-replace-edit-export embark-after-export-hook))
        ;; Vertico installs its map after minibuffer setup starts.  Bind the
        ;; map itself so its normal RET cannot replace the export action.
        (vertico-map
         (make-composed-keymap
          (define-keymap "RET" #'embark-export "<return>" #'embark-export)
          vertico-map)))
    (consult-ripgrep)))

;;; In-buffer completion

(use-package corfu
  :demand t
  :init
  (global-corfu-mode 1)
  (corfu-history-mode 1)
  :hook
  (corfu-mode . corfu-popupinfo-mode)
  :custom
  (corfu-cycle t)
  (corfu-auto t)
  (corfu-auto-prefix 2)
  (corfu-auto-delay 0.15)
  (corfu-preview-current nil)
  (corfu-preselect 'prompt)
  (corfu-on-exact-match nil)
  (corfu-quit-at-boundary 'separator)
  (corfu-quit-no-match 'separator)
  (corfu-popupinfo-delay '(0.6 . 0.2))
  :bind
  (:map corfu-map
        ("TAB" . corfu-next)
        ([tab] . corfu-next)
        ("S-TAB" . corfu-previous)
        ([backtab] . corfu-previous)
        ("RET" . corfu-insert)
        ("M-d" . corfu-popupinfo-documentation)
        ("M-l" . corfu-popupinfo-location)))

(defun my/add-cape-completion-functions ()
  "Append useful fallback completion sources in the current buffer.

Language-server completion remains first, while files, keywords, and words in
the current buffer fill the gaps."
  (add-hook 'completion-at-point-functions #'cape-file 80 t)
  (add-hook 'completion-at-point-functions #'cape-keyword 90 t)
  (add-hook 'completion-at-point-functions #'cape-dabbrev 100 t))

(use-package cape
  :commands (cape-file cape-keyword cape-dabbrev)
  :custom
  (cape-dabbrev-check-other-buffers nil)
  :hook
  ((prog-mode text-mode conf-mode) . my/add-cape-completion-functions))

;;; Discoverability

(use-package which-key
  :ensure nil
  :demand t
  :diminish
  :init
  (which-key-mode 1)
  :custom
  (which-key-idle-delay 0.35)
  (which-key-idle-secondary-delay 0.05)
  (which-key-sort-order 'which-key-key-order-alpha))

(use-package helpful
  :commands
  (helpful-callable helpful-variable helpful-key helpful-command
                    helpful-function))

(provide 'init-completion)
;;; init-completion.el ends here
