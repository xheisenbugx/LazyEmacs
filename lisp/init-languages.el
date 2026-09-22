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
    (sh-mode bash-ts-mode (bash)))
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
