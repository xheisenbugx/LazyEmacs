;;; init-core.el --- Safe defaults, persistence, and macOS integration -*- lexical-binding: t; -*-

;;; Commentary:
;; This module contains behavior that should be available everywhere, before
;; any UI or programming-language package is loaded.

;;; Code:

(setq load-prefer-newer t
      use-short-answers t
      sentence-end-double-space nil
      require-final-newline t
      kill-do-not-save-duplicates t
      kill-ring-max 300
      save-interprogram-paste-before-kill t
      read-process-output-max (* 4 1024 1024)
      process-adaptive-read-buffering nil
      ;; Git is the only configured VCS.  Avoid probing every built-in backend
      ;; whenever a local file is visited.
      vc-handled-backends '(Git)
      confirm-kill-emacs #'y-or-n-p
      use-dialog-box nil
      use-file-dialog nil)

;; Prefer UTF-8 at every boundary unless a file explicitly declares otherwise.
(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8-unix)
(set-default-coding-systems 'utf-8-unix)

;; Recovery files live in ignored state directories, away from source trees.
(let ((backups (locate-user-emacs-file "var/backups/"))
      (autosaves (locate-user-emacs-file "var/auto-save/")))
  (make-directory backups t)
  (make-directory autosaves t)
  (setq make-backup-files lazyemacs-enable-recovery
        backup-inhibited (not lazyemacs-enable-recovery)
        backup-directory-alist `(("." . ,backups))
        backup-by-copying t
        version-control t
        kept-new-versions 6
        kept-old-versions 2
        delete-old-versions t
        auto-save-default lazyemacs-enable-recovery
        auto-save-file-name-transforms `((".*" ,autosaves t))
        auto-save-list-file-prefix (expand-file-name ".saves-" autosaves)
        create-lockfiles t))

;; macOS Command becomes Super, Option stays Meta, and right Option remains
;; available for entering accented/international characters.
(when (eq system-type 'darwin)
  (setq mac-command-modifier 'super
        mac-option-modifier 'meta
        mac-right-option-modifier 'none
        ns-use-proxy-icon nil
        frame-resize-pixelwise t))

(use-package diminish
  :demand t)

;; gcmh raises the allocation threshold while typing and collects while idle.
;; LSP and completion allocate heavily, so the active threshold intentionally
;; matches gcmh's 1 GiB default.  The former 128 MiB value allowed collections
;; in the middle of Consult sessions even on this high-memory machine.
(use-package gcmh
  :demand t
  :diminish
  :custom
  (gcmh-low-cons-threshold (* 16 1024 1024))
  (gcmh-high-cons-threshold (* 1024 1024 1024))
  ;; Wait for a genuine pause instead of collecting between picker keystrokes.
  (gcmh-idle-delay 15)
  :config
  (gcmh-mode 1))

;; GUI applications on macOS do not inherit the interactive shell's PATH.
;; Import it early so lsp-mode, formatters, ripgrep, and Ghostel find the same tools
;; that are available in Terminal.app.
(use-package exec-path-from-shell
  :if (and (eq system-type 'darwin)
           (memq window-system '(mac ns x)))
  :demand t
  :custom
  (exec-path-from-shell-variables
   '("PATH" "MANPATH" "GOPATH" "PYENV_ROOT" "NVM_DIR" "MISE_DATA_DIR"))
  :config
  (exec-path-from-shell-initialize))

;;; Persistent history

(use-package savehist
  :ensure nil
  :init
  (savehist-mode 1)
  :custom
  (history-length 1000)
  (savehist-autosave-interval 60)
  (savehist-additional-variables
   '(kill-ring search-ring regexp-search-ring)))

(use-package saveplace
  :ensure nil
  :init
  (save-place-mode 1))

(defvar my/recentf-save-timer nil "Periodic recent-file save timer.")

(use-package recentf
  :ensure nil
  :init
  (recentf-mode 1)
  :custom
  (recentf-max-saved-items 500)
  (recentf-auto-cleanup 'never)
  (recentf-exclude
   '("/tmp/" "/ssh:" "/sudo:" "COMMIT_EDITMSG" "git-rebase-todo"))
  :config
  ;; Save periodically, not only on exit.  Waiting for the first interval keeps
  ;; this disk write away from the first picker or automatic LSP startup.
  (when (timerp my/recentf-save-timer)
    (cancel-timer my/recentf-save-timer))
  (setq my/recentf-save-timer
        (run-at-time (* 5 60) (* 5 60) #'recentf-save-list)))

(use-package so-long
  :ensure nil
  :init
  ;; Protect the editor from pathological one-line/minified files.
  (global-so-long-mode 1))

(use-package autorevert
  :ensure nil
  :init
  (global-auto-revert-mode 1)
  :custom
  ;; Prefer macOS file notifications over scanning every buffer each interval.
  ;; Dired and other non-file buffers remain manually refreshable with `g'.
  (auto-revert-avoid-polling t)
  (global-auto-revert-non-file-buffers nil)
  (auto-revert-verbose nil))

(use-package uniquify
  :ensure nil
  :custom
  ;; Show enough of a path to distinguish buffers with identical filenames.
  (uniquify-buffer-name-style 'forward)
  (uniquify-separator " / ")
  (uniquify-after-kill-buffer-p t))

;;; Small configuration helpers

(defun my/open-init-file ()
  "Open the main configuration entry point."
  (interactive)
  (find-file (expand-file-name "config.el" lazyemacs-user-directory)))

(defun my/reload-init-file ()
  "Evaluate one configuration module explicitly.
Restart Emacs after changing early-init.el or package initialization."
  (interactive)
  (let* ((directory (expand-file-name "lisp/" user-emacs-directory))
         (file (completing-read "Reload module: "
                                (directory-files directory nil "\\.el\\'") nil t)))
    (when (equal file "init-packages.el")
      (user-error "Restart Emacs after changing package initialization"))
    (load-file (expand-file-name file directory))
    (message "Evaluated %s; removed settings may still require a restart" file)))

(defun my/copy-buffer-file-name ()
  "Copy the current file or Dired directory path to the kill ring."
  (interactive)
  (if-let* ((path (or buffer-file-name
                     (and (derived-mode-p 'dired-mode)
                          default-directory))))
      (progn
        (kill-new (abbreviate-file-name path))
        (message "Copied %s" (abbreviate-file-name path)))
    (user-error "The current buffer is not visiting a file or directory")))

;; A server makes subsequent `emacsclient' invocations effectively instant.
;; Batch validation must not leave a background server behind.
(use-package server
  :ensure nil
  :if (not noninteractive)
  :config
  (unless (server-running-p)
    (server-start)))

(provide 'init-core)
;;; init-core.el ends here
