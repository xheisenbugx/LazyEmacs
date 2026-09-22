;;; init-vcs.el --- Git porcelain, gutter signs, and repository links -*- lexical-binding: t; -*-

;;; Commentary:
;; Magit is the primary Git interface.  diff-hl supplies the equivalent of
;; LazyVim's Git signs and hunk actions, while git-link creates browser URLs for
;; the selected line or current revision.

;;; Code:

(use-package magit
  :commands
  (magit-status magit-blame-addition magit-log-current
                magit-diff-buffer-file magit-file-dispatch)
  :custom
  (magit-diff-refine-hunk 'all)
  (magit-display-buffer-function
   #'magit-display-buffer-same-window-except-diff-v1))

(use-package diff-hl
  :demand t
  :init
  (global-diff-hl-mode 1)
  :custom
  ;; Keep source-control signs on the left and Flycheck diagnostics on the right.
  (diff-hl-side 'left)
  (diff-hl-update-async t)
  (diff-hl-disable-on-remote t)
  :config
  ;; Do not enable diff-hl-flydiff globally.  It launches a VCS diff after only
  ;; 0.3 seconds of idle time, which competes directly with Consult's debounce
  ;; and LSP's idle processing.  Signs still refresh on save and Magit refresh;
  ;; `M-x diff-hl-flydiff-mode' remains available when live unsaved signs matter.
  (add-hook 'magit-post-refresh-hook #'diff-hl-magit-post-refresh))

(use-package git-link
  :commands (git-link git-link-commit)
  :custom
  ;; Opening immediately mirrors the common "copy/open permalink" workflow.
  (git-link-open-in-browser t))

(defun my/git-browse ()
  "Open a repository link for the current file or selection."
  (interactive)
  (require 'git-link)
  (let ((git-link-open-in-browser t)) (call-interactively #'git-link)))

(defun my/git-copy-link ()
  "Copy a repository link without opening a browser."
  (interactive)
  (require 'git-link)
  (let ((git-link-open-in-browser nil)) (call-interactively #'git-link)))

(defun my/git-status-cwd ()
  "Open Magit for the repository containing the current directory.
Unlike `magit-status', this never asks which repository to use."
  (interactive)
  (require 'magit)
  (magit-status-setup-buffer
   (or (magit-toplevel default-directory)
       (user-error "The current directory is not inside a Git repository"))))

(defun my/git-log-cwd ()
  "Show the current branch's log limited to the current directory."
  (interactive)
  (require 'magit)
  (let ((root (or (magit-toplevel default-directory)
                  (user-error "The current directory is not inside a Git repository"))))
    (magit-log-setup-buffer (list (or (magit-get-current-branch) "HEAD"))
                            (car (magit-log-arguments))
                            (list (file-relative-name default-directory root)))))

(defun my/git-diff-upstream ()
  "Diff the working tree against the current branch's upstream."
  (interactive)
  (require 'magit)
  (unless (magit-get-upstream-branch)
    (user-error "The current branch has no upstream"))
  (magit-diff-range "@{upstream}"))

(provide 'init-vcs)
;;; init-vcs.el ends here
