;;; init-session.el --- Persistent desktops and reversible focus -*- lexical-binding: t; -*-

;;; Commentary:
;; Desktop and tab-bar already serialize native layouts, file positions, tab
;; groups, and project roots.  Keep process objects and zoom snapshots out.

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

(defun my/session-save ()
  "Save file buffers and native tab groups, without saving buffer contents."
  (interactive)
  (when-let* ((owner (desktop-owner my/session-directory)))
    (unless (eq owner (emacs-pid))
      (user-error "Session is locked by Emacs PID %s; close that session before saving" owner)))
  (make-directory my/session-directory t)
  (desktop-save my/session-directory)
  (message "Saved project sessions"))

(defun my/session-restore ()
  "Restore the saved desktop and its project groups."
  (interactive)
  (unless (file-exists-p (expand-file-name desktop-base-file-name my/session-directory))
    (user-error "No saved session yet; sessions are saved on exit or with SPC q S"))
  (when (eq (desktop-owner my/session-directory) (emacs-pid))
    (desktop-release-lock my/session-directory))
  (desktop-read my/session-directory))

(defun my/session-stop-saving ()
  "Stop saving the desktop for the rest of this Emacs session.
The previously saved session is kept; like LazyVim's `SPC q d', quitting will
not overwrite it.  Restart Emacs to resume automatic saving."
  (interactive)
  (desktop-save-mode -1)
  (when (eq (desktop-owner my/session-directory) (emacs-pid))
    (desktop-release-lock my/session-directory))
  (message "This session will not be saved"))

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

;; Never enable persistence in batch checks or overwrite a live desktop there.
(unless noninteractive
  (make-directory my/session-directory t)
  (desktop-save-mode 1))

(provide 'init-session)
;;; init-session.el ends here
