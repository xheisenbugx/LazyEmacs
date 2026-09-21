;;; init-workspaces.el --- Project tab sessions -*- lexical-binding: t; -*-

;;; Commentary:
;; Project/session behavior lives in the GitHub-hosted package.
;; This module supplies presentation and session actions; shortcuts live in
;; init-keymaps.el.

;;; Code:

(require 'embark)

(use-package project-tab-sessions
  :vc (:url "https://github.com/xheisenbugx/project-tab-sessions"
       :rev :newest)
  :demand t
  :custom
  (tab-bar-show 1)
  (tab-bar-close-button-show nil)
  (tab-bar-new-tab-choice "*scratch*")
  (tab-bar-new-tab-group t)
  (tab-bar-tab-hints t)
  (tab-bar-format '(project-tab-sessions-format))
  (tab-bar-tab-name-format-function #'project-tab-sessions-tab-name-format)
  (tab-bar-tab-group-format-function #'project-tab-sessions-group-format)
  :config
  (tab-bar-mode 1)
  (tab-bar-history-mode 1)
  (project-tab-sessions-mode 1))

(defun my/session-names ()
  "Return session names, current first and then most recently visited."
  (let* ((tabs (funcall tab-bar-tabs-function))
         (current (alist-get 'group (tab-bar--current-tab-find tabs)))
         (names (delete-dups (mapcar (lambda (tab) (alist-get 'group tab)) tabs))))
    (cl-stable-sort
     names (lambda (a b)
             (cond ((equal a current) (not (equal b current)))
                   ((equal b current) nil)
                   (t (> (my/session-last-used a tabs)
                         (my/session-last-used b tabs))))))))

(defun my/session-last-used (group tabs)
  "Return the most recent timestamp for GROUP in TABS."
  (apply #'max 0 (mapcar (lambda (tab)
                          (if (equal group (alist-get 'group tab))
                              (or (alist-get 'time tab) 0) 0))
                        tabs)))

(defun my/session-annotation (group)
  "Describe GROUP's current status, layout count and project directory."
  (let* ((entries (project-tab-sessions--tabs group))
         (root (seq-some (lambda (entry)
                           (alist-get 'project-tab-sessions-root (cdr entry)))
                         entries)))
    (propertize
     (format "  %-7s %d tab%s  %s"
             (if (equal group (alist-get 'group (tab-bar--current-tab-find)))
                 "current" "")
             (length entries) (if (= (length entries) 1) "" "s")
             (if root (abbreviate-file-name root) "no project"))
     'face 'completions-annotations)))

(defun my/session-completion-table (string predicate action)
  "Complete live session names for STRING, PREDICATE and ACTION."
  (if (eq action 'metadata)
      '(metadata (category . lazyemacs-session)
                 (annotation-function . my/session-annotation)
                 (display-sort-function . identity)
                 (cycle-sort-function . identity))
    (complete-with-action action (my/session-names) string predicate)))

(defun my/session-switch (group)
  "Switch to GROUP, or create it, with session-specific Embark actions."
  (interactive
   (list (completing-read "Switch or create session: "
                          #'my/session-completion-table)))
  (project-tab-sessions-switch group))

(defun my/session-close (group)
  "Close GROUP's layouts, preserving its buffers and processes.
Keep at least one session open in the selected frame."
  (interactive
   (list (completing-read "Close session: "
                          #'my/session-completion-table nil t)))
  (let ((tabs (funcall tab-bar-tabs-function)))
    (unless (seq-some (lambda (tab) (equal group (alist-get 'group tab))) tabs)
      (user-error "No live session named %s" group))
    (unless (seq-some (lambda (tab) (not (equal group (alist-get 'group tab)))) tabs)
      (user-error "Keep one session open; create another session first"))
    (tab-bar-close-group-tabs group)))

(defun my/session-rename (group new-name)
  "Rename every layout in GROUP to NEW-NAME, preserving project ownership."
  (interactive
   (let ((group (completing-read "Rename session: "
                                #'my/session-completion-table nil t)))
     (list group (read-string "New session name: " group))))
  (setq new-name (string-trim new-name))
  (let ((entries (project-tab-sessions--tabs group)))
    (unless entries (user-error "No live session named %s" group))
    (when (string-empty-p new-name) (user-error "Session name is empty"))
    (when (and (not (equal group new-name))
               (project-tab-sessions--tabs new-name))
      (user-error "Session %s already exists" new-name))
    ;; Update together: moving tabs one at a time can detach their project root.
    (dolist (entry entries)
      (setf (alist-get 'group (cdr (cdr entry))) new-name
            (alist-get 'project-tab-sessions-group (cdr (cdr entry))) new-name))
    (force-mode-line-update t)))

(defun my/session-open-directory (group)
  "Open GROUP's project directory in Dired."
  (interactive
   (list (completing-read "Open session directory: "
                          #'my/session-completion-table nil t)))
  (let ((root (seq-some (lambda (entry)
                          (alist-get 'project-tab-sessions-root (cdr entry)))
                        (project-tab-sessions--tabs group))))
    (unless root (user-error "Session %s has no associated project" group))
    (unless (file-directory-p root) (user-error "Directory no longer exists: %s" root))
    (project-tab-sessions-switch group)
    (dired root)))

(defun my/session-save-desktop (group)
  "Save the desktop containing GROUP and all other live sessions."
  (interactive
   (list (completing-read "Save desktop containing session: "
                          #'my/session-completion-table nil t)))
  (unless (project-tab-sessions--tabs group)
    (user-error "No live session named %s" group))
  (my/session-save))

(defvar my/embark-session-map (make-sparse-keymap)
  "Embark actions for live project sessions.")
(set-keymap-parent my/embark-session-map embark-general-map)
(dolist (binding '(("RET" . my/session-switch)
                   ("k" . my/session-close)
                   ("r" . my/session-rename)
                   ("o" . my/session-open-directory)
                   ("s" . my/session-save-desktop)))
  (keymap-set my/embark-session-map (car binding) (cdr binding)))

(with-eval-after-load 'embark
  (add-to-list 'embark-keymap-alist
               '(lazyemacs-session . my/embark-session-map))
  ;; Preserve the user's default for every unrelated Embark action.
  (unless (listp embark-quit-after-action)
    (setq embark-quit-after-action `((t . ,embark-quit-after-action))))
  (dolist (action '(my/session-close my/session-rename my/session-save-desktop))
    (setf (alist-get action embark-quit-after-action) nil))
  (dolist (action '(my/session-close my/session-rename))
    (add-to-list 'embark-post-action-hooks `(,action embark--restart))))

(defun my/session-first-tab ()
  "Select the first layout in this session."
  (interactive)
  (project-tab-sessions-select-tab 1))

(defun my/session-last-tab ()
  "Select the last layout in this session."
  (interactive)
  (project-tab-sessions-select-tab (length (project-tab-sessions--tabs))))

(defun my/session-close-other-tabs ()
  "Close this session's other layouts without touching other sessions."
  (interactive)
  (dolist (entry (reverse (project-tab-sessions--tabs)))
    (unless (eq (cadr entry) 'current-tab)
      (tab-bar-close-tab (car entry)))))

(provide 'init-workspaces)
;;; init-workspaces.el ends here
