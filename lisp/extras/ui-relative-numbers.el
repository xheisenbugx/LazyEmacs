;;; ui-relative-numbers.el --- Relative line numbers everywhere, like LazyVim -*- lexical-binding: t; -*-

;;; Commentary:
;; LazyVim numbers lines relative to the cursor so counts such as 5j can be
;; read off the gutter.  LazyEmacs shows absolute numbers by default;
;; `SPC u L' still switches one buffer between relative and absolute.

;;; Code:

(setq-default display-line-numbers-type 'relative)

;; Buffers that were already numbered switch now, not only new ones.
(dolist (buffer (buffer-list))
  (with-current-buffer buffer
    (when (bound-and-true-p display-line-numbers-mode)
      (setq-local display-line-numbers 'relative))))

(provide 'ui-relative-numbers)
;;; ui-relative-numbers.el ends here
