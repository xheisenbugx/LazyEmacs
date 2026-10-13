;;; ui-zen.el --- Zen mode on SPC u z: centered text without distractions -*- lexical-binding: t; -*-

;;; Commentary:
;; A small built-in stand-in for LazyVim's Snacks zen mode (or the olivetti
;; package): `SPC u z' centers the current buffer in its window with wide
;; margins and hides line numbers and the mode line.  Toggle it again to
;; restore them.  `my/zen-width' sets the width of the text column.

;;; Code:

(defcustom my/zen-width 100
  "Text width, in columns, of buffers in `my/zen-mode'."
  :type 'integer :group 'lazyemacs)

(defvar-local my/zen--saved nil
  "Settings replaced by `my/zen-mode', restored when it is turned off.")

(defun my/zen--update-margins (&optional _frame)
  "Center every window that shows a `my/zen-mode' buffer."
  (dolist (window (window-list nil 'no-minibuffer))
    (with-current-buffer (window-buffer window)
      (if (bound-and-true-p my/zen-mode)
          (let ((margin (max 0 (/ (- (window-total-width window) my/zen-width) 2))))
            (set-window-margins window margin margin))
        (set-window-margins window left-margin-width right-margin-width)))))

(define-minor-mode my/zen-mode
  "Center this buffer and hide its line numbers and mode line."
  :lighter " Zen"
  (if my/zen-mode
      (progn
        (setq my/zen--saved (list mode-line-format
                                  (bound-and-true-p display-line-numbers-mode)))
        (setq-local mode-line-format nil)
        (display-line-numbers-mode -1)
        ;; Margins are per window, so recompute them whenever windows resize.
        (add-hook 'window-size-change-functions #'my/zen--update-margins))
    (pcase-let ((`(,mode-line ,numbers) my/zen--saved))
      (setq-local mode-line-format mode-line)
      (when numbers (display-line-numbers-mode 1))))
  (my/zen--update-margins))

(with-eval-after-load 'init-keymaps
  (keymap-set my/leader-ui-map "z" '("Zen mode" . my/zen-mode)))

(provide 'ui-zen)
;;; ui-zen.el ends here
