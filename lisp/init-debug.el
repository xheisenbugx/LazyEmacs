;;; init-debug.el --- Debug Adapter Protocol debugging with Dape -*- lexical-binding: t; -*-

;;; Commentary:
;; This is the Emacs counterpart of LazyVim's nvim-dap extra.  Dape speaks the
;; Debug Adapter Protocol and ships configurations for debugpy, delve, CodeLLDB,
;; js-debug and others.  Adapters are external programs: install the one for
;; your language (for example `pip install debugpy' or `go install
;; github.com/go-delve/delve/cmd/dlv@latest') before starting a session.
;;
;; Keys live under `SPC d' (see init-keymaps.el).  `SPC d c' starts a session
;; when none is running and continues otherwise, exactly like LazyVim.

;;; Code:

(use-package dape
  :commands
  (dape dape-breakpoint-toggle dape-breakpoint-expression dape-breakpoint-log
        dape-breakpoint-remove-all dape-continue dape-until dape-next
        dape-step-in dape-step-out dape-pause dape-restart dape-quit
        dape-repl dape-info dape-select-session dape-watch-dwim
        dape-evaluate-expression dape-stack-select-up dape-stack-select-down)
  :custom
  ;; Dape's default layout already mirrors nvim-dap-ui: scopes, stack, and
  ;; breakpoints on the left with the REPL below.  Show variable values
  ;; inline next to the code being stepped through.
  (dape-inlay-hints t))

(declare-function dape--live-connections "dape")

(defun my/debug-continue ()
  "Continue the running debug session, or start a new one."
  (interactive)
  (require 'dape)
  (if (dape--live-connections)
      (call-interactively #'dape-continue)
    (call-interactively #'dape)))

(provide 'init-debug)
;;; init-debug.el ends here
