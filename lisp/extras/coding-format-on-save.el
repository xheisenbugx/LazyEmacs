;;; coding-format-on-save.el --- Format every file on save with Apheleia -*- lexical-binding: t; -*-

;;; Commentary:
;; LazyVim formats on save by default; LazyEmacs leaves it off so opening an
;; unfamiliar project never rewrites files.  This extra turns it on globally
;; from startup.  `SPC u f' still toggles it for the session and `SPC u F' for
;; one buffer; `SPC c f' formats on demand either way.  Formatters come from
;; Apheleia's per-mode defaults, Biome when the project configures it, or the
;; directory-local `apheleia-formatter'.

;;; Code:

(require 'apheleia)
(apheleia-global-mode 1)

(provide 'coding-format-on-save)
;;; coding-format-on-save.el ends here
