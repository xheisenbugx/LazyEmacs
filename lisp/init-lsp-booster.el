;;; init-lsp-booster.el --- Accelerate local lsp-mode servers -*- lexical-binding: t; -*-

;;; Commentary:
;; emacs-lsp-booster sits between Emacs and a local stdio language server.  It
;; parses JSON outside Emacs, converts responses into quickly readable Emacs
;; bytecode, and buffers reads and writes on separate threads.  The integration
;; is deliberately conditional: remote and network-based servers keep their
;; normal commands, and lsp-mode works normally when the executable is absent.

;;; Code:

(defgroup my/lsp-booster nil
  "Faster transport and decoding for local lsp-mode servers."
  :group 'my/development)

(defcustom my/lsp-booster-enabled t
  "Whether to use emacs-lsp-booster when its executable is available.

The booster is used only for local, standard-input/output language servers and
only with lsp-mode's plist protocol representation.  Restart an LSP workspace
after changing this option."
  :type 'boolean
  :group 'my/lsp-booster)

(defun my/lsp-booster--parse-bytecode (original-function &rest arguments)
  "Decode booster bytecode, otherwise call ORIGINAL-FUNCTION with ARGUMENTS."
  (or (when (eq (following-char) ?#)
        (let ((bytecode (read (current-buffer))))
          (when (byte-code-function-p bytecode)
            (funcall bytecode))))
      (apply original-function arguments)))

(defun my/lsp-booster--resolve-command (original-function command
                                                          &optional test-p)
  "Wrap the command returned by ORIGINAL-FUNCTION for COMMAND.

TEST-P is lsp-mode's executable-presence check; it must see the original
language-server command instead of the wrapper."
  (let ((resolved-command (funcall original-function command test-p)))
    (if (and my/lsp-booster-enabled
             (not test-p)
             (not (file-remote-p default-directory))
             lsp-use-plists
             (not (fboundp 'json-rpc-connection))
             (executable-find "emacs-lsp-booster"))
        (progn
          ;; Resolve the server explicitly because a graphical Emacs may have
          ;; a richer `exec-path' than the PATH inherited by child processes.
          (when-let ((server (executable-find (car resolved-command))))
            (setcar resolved-command server))
          (cons (executable-find "emacs-lsp-booster") resolved-command))
      resolved-command)))

;; The decoder must be installed before the first boosted response arrives.
;; Advice is idempotent, which also makes evaluating this module again safe.
(unless (advice-member-p #'my/lsp-booster--parse-bytecode 'json-parse-buffer)
  (advice-add 'json-parse-buffer :around #'my/lsp-booster--parse-bytecode))

(with-eval-after-load 'lsp-mode
  (unless (advice-member-p #'my/lsp-booster--resolve-command
                           'lsp-resolve-final-command)
    (advice-add 'lsp-resolve-final-command
                :around #'my/lsp-booster--resolve-command)))

(provide 'init-lsp-booster)
;;; init-lsp-booster.el ends here
