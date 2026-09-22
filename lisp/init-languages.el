;;; init-languages.el --- Native modes with dependable fallbacks -*- lexical-binding: t; -*-
;;; Commentary:
;; Probe installed grammars once, not for every file or Consult preview.
;; Compilation and downloading remain explicit user actions.
;;; Code:
(require 'treesit)
(require 'seq)

(defconst lazyemacs-language-modes
  '((typescript-mode typescript-ts-mode (typescript))
    (js-mode js-ts-mode (javascript))
    (python-mode python-ts-mode (python))
    (go-mode go-ts-mode (go))
    (rust-mode rust-ts-mode (rust))
    (css-mode css-ts-mode (css))
    (json-mode json-ts-mode (json))
    (js-json-mode json-ts-mode (json))
    (yaml-mode yaml-ts-mode (yaml))
    (sh-mode bash-ts-mode (bash))
    (lua-mode lua-ts-mode (lua))
    (dockerfile-mode dockerfile-ts-mode (dockerfile))
    (conf-toml-mode toml-ts-mode (toml)))
  "Fallback mode, native mode, and required grammars for supported languages.")

(defun lazyemacs-typescript-fallback-mode ()
  "Use regular TypeScript mode, even if TypeScript's native mode is enabled.
This preserves a non-parser fallback for TSX when only the TS grammar exists."
  (interactive)
  (typescript-mode))

(defun lazyemacs-refresh-language-modes ()
  "Select native modes whose grammars exist, preserving private remappings.
Run after installing a grammar, then reopen the file or use normal-mode."
  (interactive)
  (dolist (entry lazyemacs-language-modes)
    (pcase-let ((`(,fallback ,native ,grammars) entry))
      (let ((mapping (cons fallback native)))
        (if (and lazyemacs-prefer-tree-sitter (fboundp native)
                 (seq-every-p #'treesit-language-available-p grammars))
            (unless (assq fallback major-mode-remap-alist)
              (add-to-list 'major-mode-remap-alist mapping))
          (setq major-mode-remap-alist (delete mapping major-mode-remap-alist))))))
  ;; TSX has a separate grammar.  Without it, TypeScript mode still provides
  ;; editing, highlighting, and LSP instead of silently using Fundamental mode.
  (setf (alist-get "\\.tsx\\'" auto-mode-alist nil nil #'equal)
        (if (and lazyemacs-prefer-tree-sitter
                 (treesit-language-available-p 'tsx))
            'tsx-ts-mode 'lazyemacs-typescript-fallback-mode)))

;;; Grammar installation (the equivalent of nvim-treesitter's :TSInstall)

(defconst lazyemacs-grammar-libraries
  '(typescript-ts-mode js python go-ts-mode rust-ts-mode css-mode json-ts-mode
    yaml-ts-mode sh-script lua-ts-mode dockerfile-ts-mode toml-ts-mode)
  "Libraries whose loading registers grammar sources in Emacs 31.")

(defcustom lazyemacs-grammars
  '(typescript tsx javascript jsdoc python go gomod rust css json yaml bash lua
    dockerfile toml)
  "Grammars installed by `lazyemacs-install-grammars'."
  :type '(repeat symbol) :group 'lazyemacs)

(defun lazyemacs-install-grammars (&optional force)
  "Download and compile missing tree-sitter grammars, then enable native modes.
With prefix argument FORCE, reinstall every grammar in `lazyemacs-grammars'.
Compiling needs git and a C compiler (Xcode tools, build-essential, or MSYS2
gcc on Windows).  Nothing is downloaded automatically at startup."
  (interactive "P")
  (dolist (library lazyemacs-grammar-libraries)
    (require library nil t))
  (let (installed failed)
    (dolist (language lazyemacs-grammars)
      (when (or force (not (treesit-language-available-p language)))
        (if (not (assq language treesit-language-source-alist))
            (push language failed)
          (condition-case err
              (progn (treesit-install-language-grammar language)
                     (push language installed))
            (error (push language failed)
                   (message "Grammar %s failed: %s" language
                            (error-message-string err)))))))
    (lazyemacs-refresh-language-modes)
    (message "Grammars installed: %s%s"
             (if installed (string-join (mapcar #'symbol-name (nreverse installed)) " ")
               "none needed")
             (if failed (format "; failed: %s (see *Messages*)"
                                (string-join (mapcar #'symbol-name (nreverse failed)) " "))
               ""))))

(use-package typescript-mode
  :mode (("\\.[cm]?ts\\'" . typescript-mode)
         ("\\.tsx\\'" . typescript-mode)))

;; Emacs 31 declares typescript-mode as an extra parent of its native mode.
;; Define that parent's ancestry before Yasnippet merges JS/TS snippet tables;
;; an autoload alone leaves prog-mode before typescript-mode and creates a cycle.
(with-eval-after-load 'typescript-ts-mode
  (require 'typescript-mode))

(lazyemacs-refresh-language-modes)
(provide 'init-languages)
;;; init-languages.el ends here
