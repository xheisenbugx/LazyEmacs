;;; init-evil.el --- Vim-style modal editing with Evil -*- lexical-binding: t; -*-

;;; Commentary:
;; Evil is the only modal editing layer in this configuration.  The companion
;; packages below make Evil behave consistently across Emacs applications and
;; provide the editing features normally expected from a modern Vim setup.
;; Emacs bindings remain available in Insert state and through the C-c leader
;; aliases defined in init-keymaps.el.

;;; Code:

(use-package evil
  :demand t
  :init
  ;; These variables must be set before Evil loads because they determine
  ;; which native Emacs keys Evil is allowed to replace.
  (setq evil-want-integration t
        evil-want-keybinding nil
        evil-want-C-u-scroll t
        evil-want-C-d-scroll t
        evil-want-C-i-jump t
        evil-undo-system 'undo-redo
        evil-respect-visual-line-mode t
        evil-search-module 'isearch
        evil-split-window-below t
        evil-vsplit-window-right t)
  :config
  (evil-mode 1)

  ;; Start ordinary editing buffers in Normal state.  These interactive Emacs
  ;; interfaces either receive purpose-built bindings from Evil Collection or
  ;; work best when keystrokes are passed through unchanged.
  (dolist (mode '(custom-mode
                  debugger-mode
                  messages-buffer-mode
                  special-mode
                  term-mode))
    (evil-set-initial-state mode 'emacs))

  ;; Escape always returns to Normal state and also dismisses transient UI.
  (define-key evil-insert-state-map (kbd "C-g") #'evil-normal-state)
  (define-key evil-visual-state-map (kbd "C-g") #'evil-normal-state))

(use-package evil-collection
  :after evil
  :demand t
  :custom
  ;; Evil Collection covers Dired/Dirvish, Magit, Org Agenda, Consult, Help,
  ;; compilation buffers, and many other non-editing Emacs interfaces.
  (evil-collection-want-unimpaired-p t)
  :config
  (evil-collection-init))

(use-package general
  :after evil
  :demand t)

(use-package flash
  :vc (:url "https://github.com/Prgebish/flash"
       :rev :newest)
  :after evil
  :demand t
  :custom
  (flash-multi-window t)
  (flash-label-position 'after)
  (flash-char-jump-labels t)
  (flash-char-multi-line t)
  ;; Keep movement/editing and repeat keys available after a character jump.
  (flash-char-reserved-labels "hjkliardc;,")
  :config
  (require 'flash-evil)
  (require 'flash-treesitter)
  (flash-char-setup-evil-keys)

  ;; Upstream S enters Visual state, but does not return an operator range.
  ;; Reuse its picker while capturing the node instead of changing Evil state.
  (evil-define-text-object my/flash-treesitter-object (count &optional beg end type)
    "Select a Flash Tree-sitter node for a pending Evil operator."
    (ignore count beg end type)
    (let (range)
      (cl-letf (((symbol-function 'flash-treesitter--select-match)
                 (lambda (match)
                   (setq range
                         (evil-range (flash-match-pos-value match)
                                     (flash-match-end-pos-value match)
                                     'exclusive :expanded t)))))
        (flash-treesitter))
      (or range (user-error "Flash selection cancelled")))))

(use-package evil-surround
  :after evil
  :demand t
  :config
  ;; Examples: `ysiw"' surrounds a word; `cs"'' changes its delimiters; `ds"'
  ;; removes them.  The same operators work on Visual selections.
  (global-evil-surround-mode 1))

(use-package evil-nerd-commenter
  :after evil
  :demand t
  :config
  ;; `gc' is a proper Evil operator: combine it with a motion or text object
  ;; (`gcip' comments a paragraph), or use it directly on a Visual selection.
  (evil-define-key '(normal visual) 'global
    (kbd "gc") #'evilnc-comment-operator))

(use-package evil-mc
  :init
  (setq evil-mc-cursors-keymap-prefix "g z")
  :after evil
  :demand t
  :config
  ;; Keep gr exclusively for references.  SPC m and gz use the same engine.
  (evil-define-key* '(normal visual) evil-mc-key-map
    (kbd "gr") nil
    (kbd "gz") evil-mc-cursors-map)
  (global-evil-mc-mode 1))

(provide 'init-evil)
;;; init-evil.el ends here
