;;; init-evil-compat.el --- Evil compatibility with Emacs 31 -*- lexical-binding: t; -*-
;;; Commentary:
;; Evil 1.15.0's `evil-initializing-p' reads `evil-mode-buffers', formerly
;; defined by `define-globalized-minor-mode'.  Emacs 31 enables buffers
;; immediately instead of maintaining that deferred initialization queue.
;; Freshly compiled Evil therefore declares the variable without binding it,
;; and its Normal-state post-command hook signals `void-variable'.
;; Keep the now-unused queue empty.  `defvar' preserves any existing queue
;; from Evil compiled with an older macro.  Load this before enabling Evil;
;; do not edit installed package files or suppress post-command errors.
;;; Code:

(defvar evil-mode-buffers nil
  "Legacy Evil initialization queue; empty with Emacs 31's immediate setup.")

(provide 'init-evil-compat)
;;; init-evil-compat.el ends here
