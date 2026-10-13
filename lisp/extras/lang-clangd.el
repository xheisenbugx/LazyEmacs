;;; lang-clangd.el --- C and C++ with native tree-sitter modes and clangd -*- lexical-binding: t; -*-

;;; Commentary:
;; Emacs ships c-ts-mode and c++-ts-mode and lsp-mode ships a clangd client,
;; so C and C++ need no extra packages (LazyVim's lang.clangd extra).  This:
;;
;; - adds the c and cpp grammars to `lazyemacs-grammars' (install them with
;;   `SPC h T') and uses the native modes once those grammars exist;
;; - starts clangd automatically when it is installed, as LazyEmacs does for
;;   the languages it configures by default.
;;
;; clangd reads compile_commands.json; generate it with your build system,
;; for example `cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON'.

;;; Code:

(require 'init-languages)

(dolist (language '(c cpp))
  (add-to-list 'lazyemacs-grammars language t))
(add-to-list 'lazyemacs-grammar-libraries 'c-ts-mode t)
(dolist (entry '((c-mode c-ts-mode (c))
                 (c++-mode c++-ts-mode (cpp))
                 (c-or-c++-mode c-or-c++-ts-mode (c cpp))))
  (add-to-list 'lazyemacs-language-modes entry t))
(lazyemacs-refresh-language-modes)

(defun my/clangd-available-p (&rest _)
  "Return clangd's path in C and C++ buffers when it is installed."
  (and (derived-mode-p 'c-mode 'c-ts-mode 'c++-mode 'c++-ts-mode)
       (executable-find "clangd")))

;; `my/lsp-ensure' starts a server only when this check finds it installed.
(advice-add 'my/language-server-available-p :before-until #'my/clangd-available-p)
(dolist (hook '(c-mode-hook c-ts-mode-hook c++-mode-hook c++-ts-mode-hook))
  (add-hook hook #'my/lsp-ensure))

(provide 'lang-clangd)
;;; lang-clangd.el ends here
