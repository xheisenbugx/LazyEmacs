;;; init-session.el --- Saved terminals, layouts, and reversible focus -*- lexical-binding: t; -*-

;;; Commentary:
;; Sessions are saved one file each by init-sesh.el.  This module keeps the
;; pieces shared with the older global desktop: terminal placeholders (a
;; saved shell comes back as a buffer that starts a fresh one), the tab filter
;; that keeps process objects and zoom snapshots out of saved frames, zoom,
;; and reading a desktop saved by earlier versions so it can be imported.

;;; Code:
(require 'desktop)
(require 'tab-bar)
(require 'seq)

;; Terminal-only Evil hooks must not be restored into placeholder buffers.
;; A fresh Ghostel shell enables its integration through the normal mode hook.
(add-to-list 'desktop-minor-mode-table '(evil-ghostel-mode nil))

(defvar my/session-directory (no-littering-expand-var-file-name "desktop/")
  "Directory containing this configuration's saved desktop.")

(defun my/session-filter-tabs (original current filtered parameters saving)
  "Apply ORIGINAL's tab filter and remove transient objects when SAVING."
  (let ((result (funcall original current filtered parameters saving)))
    (if (not saving) result
      (mapcar (lambda (tab)
                (if (not (consp tab)) tab
                  (let ((copy (copy-sequence tab)))
                    (dolist (key '(my/ghostel-buffer my/ghostel-cwd-buffers my/zoom-state))
                      (setq copy (assq-delete-all key copy)))
                    copy))) result))))

(unless (advice-member-p #'my/session-filter-tabs 'frameset-filter-tabs)
  (advice-add 'frameset-filter-tabs :around #'my/session-filter-tabs))

(defun my/session-restore-desktop ()
  "Restore the desktop saved by earlier versions, with its tab groups.
Used by `lazyemacs-sesh-import-desktop'; sessions now have their own files."
  (interactive)
  (unless (file-exists-p (expand-file-name desktop-base-file-name my/session-directory))
    (user-error "No saved desktop in %s" my/session-directory))
  (when (eq (desktop-owner my/session-directory) (emacs-pid))
    (desktop-release-lock my/session-directory))
  (desktop-read my/session-directory)
  ;; Reading claims the desktop lock; nothing writes this desktop any more.
  (when (eq (desktop-owner my/session-directory) (emacs-pid))
    (desktop-release-lock my/session-directory)))

(defun my/session-new-layout (name)
  "Create a named layout tab in the current project session."
  (interactive (list (completing-read "Layout name: "
                                      '("implementation" "tests" "review") nil nil)))
  (when (string-empty-p (string-trim name)) (user-error "Layout name is empty"))
  ;; A named layout starts from the current code view, rather than a shell.
  (let ((tab-bar-new-tab-choice nil)) (tab-bar-new-tab))
  (tab-bar-rename-tab name))

(defun my/window-zoom ()
  "Maximize the selected code window, or restore this tab's previous layout."
  (interactive)
  (let* ((tab (tab-bar--current-tab-find))
         (state (alist-get 'my/zoom-state tab)))
    (if state
        (progn
          (window-state-put state (frame-root-window) 'safe)
          (setf (alist-get 'my/zoom-state (cdr tab)) nil))
      (when (window-parameter nil 'window-side)
        (user-error "Select a regular code window before zooming"))
      (let ((snapshot (window-state-get (frame-root-window))))
        (delete-other-windows)
        (setf (alist-get 'my/zoom-state (cdr tab)) snapshot)))))

;; Desktop restores files and layouts, never terminal processes. A dead shell
;; is represented by a small buffer explaining how to open a fresh shell.
(defvar-local my/session-terminal-directory nil)
(define-derived-mode my/session-terminal-mode special-mode "Saved terminal"
  "Placeholder for a terminal from an earlier Emacs process.")

(defun my/session-terminal-open ()
  "Replace a saved terminal placeholder with a fresh Ghostel shell."
  (interactive)
  (let ((default-directory (if (and my/session-terminal-directory
                                    (file-directory-p my/session-terminal-directory))
                               my/session-terminal-directory default-directory))
        (old (current-buffer)))
    (let ((fresh (my/terminal-create nil '(display-buffer-same-window))))
      (setf (alist-get 'my/ghostel-buffer (cdr (tab-bar--current-tab-find))) fresh)
      (kill-buffer old))))
(keymap-set my/session-terminal-mode-map "RET" #'my/session-terminal-open)

(defun my/session-terminal-data (_directory)
  "Save only the current terminal directory, never its running process."
  default-directory)

(defun my/session-restore-terminal (_file name data)
  "Restore a terminal NAME as a placeholder in directory DATA."
  (let ((buffer (get-buffer-create name)))
    (with-current-buffer buffer
      (my/session-terminal-mode)
      (setq-local my/session-terminal-directory data)
      (when (and (stringp data) (file-directory-p data))
        (setq default-directory data))
      (setq-local desktop-save-buffer #'my/session-terminal-data)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "Saved terminal layout\n\nPress RET to start a fresh Ghostel shell.\n"
                "Previous terminal processes are not resumed.\n")))
    buffer))

(defun my/session-track-terminal ()
  "Teach desktop how to save the location of a Ghostel terminal."
  (setq-local desktop-save-buffer #'my/session-terminal-data))
(add-hook 'ghostel-mode-hook #'my/session-track-terminal)
(with-eval-after-load 'ghostel
  (dolist (buffer (buffer-list))
    (with-current-buffer buffer
      (when (derived-mode-p 'ghostel-mode) (my/session-track-terminal)))))
(add-to-list 'desktop-buffer-mode-handlers '(ghostel-mode . my/session-restore-terminal))
(add-to-list 'desktop-buffer-mode-handlers
             '(my/session-terminal-mode . my/session-restore-terminal))

(setq desktop-path (list my/session-directory)
      desktop-dirname my/session-directory
      desktop-base-file-name "emacs-desktop"
      desktop-base-lock-name "emacs-desktop.lock"
      desktop-save t
      desktop-auto-save-timeout 120
      desktop-restore-frames t
      desktop-restore-eager 5
      desktop-load-locked-desktop nil)

;; Per-session files (init-sesh.el) replace `desktop-save-mode'; the desktop
;; settings above only describe where an older desktop can be imported from.

(provide 'init-session)
;;; init-session.el ends here
