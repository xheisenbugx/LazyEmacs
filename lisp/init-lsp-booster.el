;;; init-lsp-booster.el --- Buffered local LSP transport -*- lexical-binding: t; -*-
;;; Commentary:
;; Keep the booster's separate I/O threads, using ordinary JSON responses.
;; A global JSON decoder must never read or execute Lisp from unrelated data.
;;; Code:

(defgroup my/lsp-booster nil
  "Buffered transport for local lsp-mode servers."
  :group 'my/development)

(defcustom my/lsp-booster-enabled t
  "Use emacs-lsp-booster for local stdio servers when installed.
Bytecode conversion is disabled; Emacs parses ordinary JSON.  Restart Emacs
when migrating from the old bytecode integration, and restart an LSP
workspace after changing this option."
  :type 'boolean :group 'my/lsp-booster)

(defun my/lsp-booster--resolve-command (original-function command &optional test-p)
  "Wrap ORIGINAL-FUNCTION's resolved COMMAND except during TEST-P probes."
  (let ((resolved (funcall original-function command test-p)))
    (if-let* ((_ (and my/lsp-booster-enabled (not test-p)
                     (not (file-remote-p default-directory))
                     (not (fboundp 'json-rpc-connection))
                     (consp resolved) (stringp (car resolved))))
              (booster (executable-find "emacs-lsp-booster")))
        ;; Do not mutate lsp-mode's original command list.
        (append (list booster "--disable-bytecode" "--"
                      (or (executable-find (car resolved)) (car resolved)))
                (cdr resolved))
      resolved)))

;; Remove the old global decoder when this module is explicitly reloaded.
;; Existing bytecode-producing servers must be stopped before doing so.
(advice-remove 'json-parse-buffer 'my/lsp-booster--parse-bytecode)
(with-eval-after-load 'lsp-mode
  (advice-add 'lsp-resolve-final-command :around #'my/lsp-booster--resolve-command))

(provide 'init-lsp-booster)
;;; init-lsp-booster.el ends here
