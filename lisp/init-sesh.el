;;; init-sesh.el --- sesh-style sessions: one picker, per-session files -*- lexical-binding: t; -*-

;;; Commentary:
;; A session is a native tab group (see init-workspaces.el); this module makes
;; sessions work like https://github.com/joshmedeski/sesh does for tmux:
;;
;; - One picker, `lazyemacs-sesh-connect' (s-p, SPC TAB g, SPC p p), lists
;;   live sessions, saved-but-closed sessions, configured sessions, known
;;   projects, zoxide directories, and the current repository's Git worktrees.
;;   Every entry goes through `lazyemacs-sesh-connect-to', so choosing a name
;;   or a directory always does the right thing: switch, restore, build, or
;;   create.
;; - Each session is saved to its own file under var/sessions/ (its tabs,
;;   window layouts, file/Dired/terminal buffers, project root, and last use)
;;   and is loaded only when you connect to it.  This replaces the single
;;   global desktop; the desktop is kept only to import an older save.
;; - A lock file per session lets two Emacs processes own different sessions.
;; - Sessions can be declared in user/config.el (`lazyemacs-define-session')
;;   or in a project's `.lazyemacs-session.el' data file.  A project file is
;;   read, never loaded, and its commands run only after you trust it.
;; - Buffers remember which sessions showed them, so `SPC ,' and H/L stay
;;   inside the current session while every buffer remains reachable.
;;
;; bin/lazyemacs-connect connects from a shell (tmux, sesh, zoxide) through
;; emacsclient.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'tab-bar)
(require 'project)
(require 'url-util)
(require 'project-tab-sessions)
(require 'init-session)
(require 'init-workspaces)

(declare-function consult--multi "consult")
(declare-function consult--buffer-query "consult")
(declare-function consult--buffer-state "consult")
(declare-function consult--buffer-pair "consult")
(declare-function consult-buffer "consult")
(declare-function consult-ripgrep "consult")
(declare-function magit-status-setup-buffer "magit-status")
(declare-function lazyemacs-dashboard "init-dashboard")
(declare-function my/terminal-create "init-tools")
(declare-function my/terminal-send "init-tools")
(declare-function my/project-ghostel "init-tools")
(defvar lazyemacs-dashboard)

;;; Options

(defgroup lazyemacs-sesh nil
  "Sesh-style project sessions."
  :group 'lazyemacs
  :prefix "lazyemacs-sesh-")

(defcustom lazyemacs-sesh-directory (no-littering-expand-var-file-name "sessions/")
  "Directory holding one saved file and one lock file per session."
  :type 'directory)

(defcustom lazyemacs-sesh-state-file (no-littering-expand-var-file-name "sesh-state.eld")
  "File recording which sessions were open when Emacs last exited."
  :type 'file)

(defcustom lazyemacs-sesh-trust-file (no-littering-expand-var-file-name "sesh-trusted.eld")
  "File recording trusted `.lazyemacs-session.el' files by root and SHA-256."
  :type 'file)

(defcustom lazyemacs-sesh-restore-on-startup t
  "Non-nil reopens the sessions that were open when Emacs last exited.
Starting Emacs with --no-desktop skips the restore once."
  :type 'boolean)

(defcustom lazyemacs-sesh-save-interval 60
  "Idle seconds before live sessions are saved, or nil to save only on exit."
  :type '(choice (const :tag "Only on exit and switch" nil) natnum))

(defcustom lazyemacs-sesh-zoxide-limit 200
  "Maximum number of zoxide directories shown in the session picker."
  :type 'natnum)

(defcustom lazyemacs-sesh-clone-directory
  (if (file-directory-p "~/Workspace/") "~/Workspace/" "~/")
  "Directory into which `lazyemacs-sesh-clone' clones repositories."
  :type 'directory)

(defcustom lazyemacs-sesh-open-root-function #'dired
  "Function called with the root directory of a newly created session."
  :type 'function)

(defcustom lazyemacs-sesh-scope-buffers t
  "Non-nil makes `SPC ,' and H/L prefer buffers shown in this session."
  :type 'boolean)

(defcustom lazyemacs-sesh-mode-line t
  "Non-nil shows the current session name in the mode line."
  :type 'boolean)

(defcustom lazyemacs-sesh-local-file ".lazyemacs-session.el"
  "Name of the per-project session data file."
  :type 'string)

(defvar lazyemacs-sesh-sessions nil
  "Configured sessions as (NAME . PLIST); see `lazyemacs-define-session'.")

(defvar lazyemacs-sesh-history nil
  "Minibuffer history for session pickers.")

(defvar lazyemacs-sesh--previous nil
  "Session that was current before the last session switch.")

(defvar lazyemacs-sesh--inhibit-save nil
  "Non-nil after `lazyemacs-sesh-stop-saving' for the rest of this Emacs.")

(defvar lazyemacs-sesh--written (make-hash-table :test #'equal)
  "Last text written per session, to skip identical writes.")

(defvar lazyemacs-sesh--no-restore-arg (member "--no-desktop" command-line-args)
  "Non-nil when Emacs was started with --no-desktop.
Desktop removes the flag during `after-init-hook', so read it at load time.")

(defvar-local lazyemacs-sesh--buffer-sessions nil
  "Names of the sessions in which this buffer has been shown.")
(put 'lazyemacs-sesh--buffer-sessions 'permanent-local t)

;;; Live sessions

(defun lazyemacs-sesh--current ()
  "Return the current session name."
  (alist-get 'group (tab-bar--current-tab-find)))

(defun lazyemacs-sesh--live-p (name)
  "Return non-nil when NAME is a live session in the selected frame."
  (and (stringp name) (project-tab-sessions--tabs name) t))

(defun lazyemacs-sesh--live-names ()
  "Return live session names, current first and then most recent."
  (delq nil (my/session-names)))

(defun lazyemacs-sesh--live-root (name)
  "Return the project root of live session NAME."
  (seq-some (lambda (entry) (alist-get 'project-tab-sessions-root (cdr entry)))
            (project-tab-sessions--tabs name)))

(defun lazyemacs-sesh--dir (directory)
  "Return DIRECTORY as a canonical directory name.
Remote names are only expanded, to avoid opening connections."
  (let ((expanded (expand-file-name directory)))
    (file-name-as-directory
     (if (file-remote-p expanded) expanded (file-truename expanded)))))

(defun lazyemacs-sesh--live-for-root (root)
  "Return the live session whose project root is ROOT."
  (seq-find (lambda (name) (equal root (lazyemacs-sesh--live-root name)))
            (lazyemacs-sesh--live-names)))

;;; Session files

(defun lazyemacs-sesh--file (name &optional extension)
  "Return the file for session NAME, with EXTENSION (default \".eld\").
Names are percent-encoded, so every name maps to a portable file name."
  (expand-file-name (concat (url-hexify-string name) (or extension ".eld"))
                    lazyemacs-sesh-directory))

(defun lazyemacs-sesh--read-file (file)
  "Read the first form of FILE as data, or return nil.
`read' never evaluates code, so this is safe for untrusted files."
  (ignore-errors
    (with-temp-buffer
      (insert-file-contents file)
      (read (current-buffer)))))

(defun lazyemacs-sesh--write-file (file data)
  "Write DATA readably to FILE, atomically."
  (make-directory (file-name-directory file) t)
  (let ((temp (concat file ".tmp"))
        (print-length nil) (print-level nil) (print-circle nil)
        (coding-system-for-write 'utf-8-unix))
    (with-temp-file temp
      (insert ";; LazyEmacs session data -*- mode: lisp-data -*-\n")
      (prin1 data (current-buffer))
      (insert "\n"))
    (rename-file temp file t)))

(defun lazyemacs-sesh--saved-data (name)
  "Return the saved data for session NAME, or nil."
  (let ((data (lazyemacs-sesh--read-file (lazyemacs-sesh--file name))))
    (and (plistp data) (equal (plist-get data :name) name) data)))

(defun lazyemacs-sesh--saved ()
  "Return all saved session data, most recently used first."
  (when (file-directory-p lazyemacs-sesh-directory)
    (sort (seq-filter (lambda (data) (and (plistp data) (stringp (plist-get data :name))))
                      (mapcar #'lazyemacs-sesh--read-file
                              (directory-files lazyemacs-sesh-directory t "\\.eld\\'")))
          (lambda (a b) (> (or (plist-get a :last-used) 0)
                           (or (plist-get b :last-used) 0))))))

(defun lazyemacs-sesh--saved-for-root (root)
  "Return saved data whose root is ROOT."
  (seq-find (lambda (data) (equal root (plist-get data :root))) (lazyemacs-sesh--saved)))

;;; Locks

(defun lazyemacs-sesh--pid-alive-p (pid)
  "Return non-nil when PID is a running Emacs process on this host.
Checking the command name keeps a recycled PID from pinning a lock."
  (when-let* ((attributes (ignore-errors (process-attributes pid))))
    (let ((command (alist-get 'comm attributes)))
      (or (not command) (string-match-p "emacs" (downcase command))))))

(defun lazyemacs-sesh--lock-owner (name)
  "Return the lock plist of NAME when another live Emacs owns it."
  (let* ((lock (lazyemacs-sesh--read-file (lazyemacs-sesh--file name ".lock")))
         (pid (and (plistp lock) (plist-get lock :pid)))
         (host (plist-get lock :host)))
    (cond ((not (integerp pid)) nil)
          ((not (equal host (system-name))) lock) ; cannot check; respect it
          ((= pid (emacs-pid)) nil)
          ((lazyemacs-sesh--pid-alive-p pid) lock))))

(defun lazyemacs-sesh--lock (name)
  "Lock session NAME for this Emacs, or signal a `user-error'."
  (when-let* ((owner (lazyemacs-sesh--lock-owner name)))
    (user-error "Session %s is open in another Emacs (PID %s on %s); delete %s if that is wrong"
                name (plist-get owner :pid) (plist-get owner :host)
                (lazyemacs-sesh--file name ".lock")))
  (let ((file (lazyemacs-sesh--file name ".lock")))
    (unless (equal (plist-get (lazyemacs-sesh--read-file file) :pid) (emacs-pid))
      (lazyemacs-sesh--write-file file (list :pid (emacs-pid) :host (system-name))))))

(defun lazyemacs-sesh--unlock (name)
  "Release this Emacs's lock on session NAME."
  (let ((file (lazyemacs-sesh--file name ".lock")))
    (when (equal (plist-get (lazyemacs-sesh--read-file file) :pid) (emacs-pid))
      (delete-file file))))

;;; Serializing layouts

(defun lazyemacs-sesh--map-state (state function)
  "Copy window STATE, renaming each buffer with FUNCTION.
Window histories are dropped: they name buffers that are not restored."
  (cond ((not (consp state)) state)
        ((and (eq (car state) 'buffer) (consp (cdr state)) (stringp (cadr state)))
         `(buffer ,(funcall function (cadr state)) ,@(cddr state)))
        ((proper-list-p state)
         (mapcar (lambda (item) (lazyemacs-sesh--map-state item function))
                 (seq-remove (lambda (item)
                               (and (consp item) (memq (car item) '(prev-buffers next-buffers))))
                             state)))
        (t (cons (lazyemacs-sesh--map-state (car state) function)
                 (lazyemacs-sesh--map-state (cdr state) function)))))

(defun lazyemacs-sesh--terminal-p (buffer)
  "Return non-nil when BUFFER is a terminal or a saved terminal placeholder."
  (with-current-buffer buffer
    (derived-mode-p 'ghostel-mode 'my/session-terminal-mode 'eshell-mode
                    'term-mode 'vterm-mode)))

(defun lazyemacs-sesh--buffer-spec (buffer)
  "Describe how to recreate BUFFER, or return nil if it is not restorable."
  (with-current-buffer buffer
    (cond (buffer-file-name (list :file buffer-file-name))
          ((derived-mode-p 'dired-mode) (list :dired (expand-file-name default-directory)))
          ((lazyemacs-sesh--terminal-p buffer)
           (list :terminal (expand-file-name (or my/session-terminal-directory
                                                 default-directory)))))))

(defun lazyemacs-sesh--tab-state (tab frame)
  "Return the writable window state of TAB on FRAME."
  (if (eq (car tab) 'current-tab)
      (window-state-get (frame-root-window frame) 'writable)
    (alist-get 'ws tab)))

(defun lazyemacs-sesh--serialize (name &optional frame)
  "Return the saved form of session NAME on FRAME, or nil if not live there."
  (let* ((frame (or frame (selected-frame)))
         (tabs (seq-filter (lambda (tab) (equal name (alist-get 'group tab)))
                           (funcall tab-bar-tabs-function frame)))
         (current (seq-position tabs 'current-tab (lambda (tab type) (eq (car tab) type)))))
    (when tabs
      (list
       :version 1
       :name name
       :root (seq-some (lambda (tab) (alist-get 'project-tab-sessions-root tab)) tabs)
       :last-used (if current (float-time)
                    (apply #'max 0 (mapcar (lambda (tab) (or (alist-get 'time tab) 0)) tabs)))
       :current (or current
                    (seq-position tabs (seq-reduce (lambda (best tab)
                                                     (if (> (or (alist-get 'time tab) 0)
                                                            (or (alist-get 'time best) 0))
                                                         tab best))
                                                   tabs (car tabs))))
       :tabs
       (mapcar
        (lambda (tab)
          (let* ((buffers nil)
                 (state (lazyemacs-sesh--map-state
                         (lazyemacs-sesh--tab-state tab frame)
                         (lambda (buffer-name)
                           (when-let* ((buffer (get-buffer buffer-name))
                                       (spec (lazyemacs-sesh--buffer-spec buffer)))
                             (push (cons buffer-name spec) buffers))
                           buffer-name))))
            (list :name (alist-get 'name tab)
                  :explicit (and (alist-get 'explicit-name tab) t)
                  :state state
                  :buffers (nreverse buffers))))
        tabs)))))

(defun lazyemacs-sesh--worth-saving-p (data)
  "Return non-nil when DATA holds a root, files, or named layouts."
  (or (plist-get data :root)
      (seq-some (lambda (tab) (or (plist-get tab :buffers) (plist-get tab :explicit)))
                (plist-get data :tabs))))

(defun lazyemacs-sesh--save (name &optional quiet)
  "Save live session NAME to its file.  Return non-nil when saved.
With QUIET, skip sessions owned by another Emacs instead of signaling."
  (when-let* (((not lazyemacs-sesh--inhibit-save))
              (data (lazyemacs-sesh--serialize name))
              ((lazyemacs-sesh--worth-saving-p data)))
    (if (and quiet (lazyemacs-sesh--lock-owner name))
        nil
      (lazyemacs-sesh--lock name)
      (let ((text (prin1-to-string (plist-put (copy-sequence data) :last-used nil)))
            (file (lazyemacs-sesh--file name)))
        ;; Unreadable objects would make the whole file unloadable later.
        (when (string-match-p "#<" text)
          (setq data (plist-put data :tabs
                                (mapcar (lambda (tab)
                                          (if (string-match-p "#<" (prin1-to-string tab))
                                              (plist-put (copy-sequence tab) :state nil)
                                            tab))
                                        (plist-get data :tabs)))))
        (unless (and (equal text (gethash name lazyemacs-sesh--written))
                     (file-exists-p file))
          (lazyemacs-sesh--write-file file data)
          (puthash name text lazyemacs-sesh--written))
        t))))

(defun lazyemacs-sesh-save (name)
  "Save session NAME now (the current session interactively)."
  (interactive (list (lazyemacs-sesh--read "Save session: " t)))
  (unless (lazyemacs-sesh--live-p name) (user-error "No live session named %s" name))
  (let ((lazyemacs-sesh--inhibit-save nil))
    (if (lazyemacs-sesh--save name)
        (message "Saved session %s" name)
      (message "Session %s has nothing to save" name))))

(defun lazyemacs-sesh--write-state ()
  "Record the live sessions and the current one for the next startup."
  (unless lazyemacs-sesh--inhibit-save
    (lazyemacs-sesh--write-file
     lazyemacs-sesh-state-file
     (list :sessions (seq-filter #'lazyemacs-sesh--saved-data (lazyemacs-sesh--live-names))
           :current (lazyemacs-sesh--current)
           :previous lazyemacs-sesh--previous))))

(defun lazyemacs-sesh-save-all (&optional quiet)
  "Save every live session and remember them for the next startup.
With QUIET, skip sessions owned by another Emacs instead of failing."
  (interactive)
  (when (and lazyemacs-sesh--inhibit-save (called-interactively-p 'interactive))
    (setq lazyemacs-sesh--inhibit-save nil))
  (let ((saved 0) (skipped nil))
    (dolist (name (lazyemacs-sesh--live-names))
      ;; Sessions owned by another Emacs are skipped, never overwritten.
      (cond ((lazyemacs-sesh--save name t) (setq saved (1+ saved)))
            ((lazyemacs-sesh--lock-owner name) (push name skipped))))
    (lazyemacs-sesh--write-state)
    (unless quiet
      (message "Saved %d session%s%s" saved (if (= saved 1) "" "s")
               (if skipped (format "; %s open in another Emacs" (string-join skipped ", ")) "")))
    saved))

(defun lazyemacs-sesh-stop-saving ()
  "Stop saving sessions for the rest of this Emacs, like LazyVim's `SPC q d'.
Saved files are kept; quitting will not overwrite them.  `SPC q S' resumes."
  (interactive)
  (setq lazyemacs-sesh--inhibit-save t)
  (message "Sessions will not be saved in this Emacs"))

;;; Restoring layouts

(defun lazyemacs-sesh--restore-buffer (spec name)
  "Recreate the buffer described by SPEC (originally called NAME), or nil."
  (pcase spec
    (`(:file ,file) (and (file-readable-p file) (find-file-noselect file)))
    (`(:dired ,directory) (and (file-directory-p directory) (dired-noselect directory)))
    (`(:terminal ,directory)
     (let ((live (get-buffer name)))
       (if (and live (lazyemacs-sesh--terminal-p live)) live
         (my/session-restore-terminal nil name directory))))))

(defun lazyemacs-sesh--put-state (state buffers)
  "Show window STATE in the selected tab, recreating BUFFERS specs.
Missing files and directories are skipped; their windows show *scratch*."
  (let* ((fallback (get-scratch-buffer-create))
         (state (lazyemacs-sesh--map-state
                 state
                 (lambda (name)
                   (let* ((spec (cdr (assoc name buffers)))
                          (buffer (if spec (lazyemacs-sesh--restore-buffer spec name)
                                    (get-buffer name))))
                     (buffer-name (or buffer fallback)))))))
    (delete-other-windows)
    (when state
      (condition-case err
          (window-state-put state (selected-window) 'safe)
        (error (message "Could not restore a layout: %s" (error-message-string err))
               (delete-other-windows)
               (switch-to-buffer fallback))))
    ;; Nothing survived: show the start screen instead of empty windows.
    (when (seq-every-p (lambda (window) (eq (window-buffer window) fallback))
                       (window-list nil 'nomini))
      (delete-other-windows)
      (if (and (bound-and-true-p lazyemacs-dashboard) (fboundp 'lazyemacs-dashboard))
          (lazyemacs-dashboard)
        (switch-to-buffer fallback)))))

(defun lazyemacs-sesh--new-tab (name root)
  "Open a tab in session NAME with project ROOT and select it."
  (if (lazyemacs-sesh--live-p name)
      (let ((tab-bar-new-tab-choice "*scratch*")) (tab-bar-new-tab))
    (project-tab-sessions-switch name))
  (unless (equal name (lazyemacs-sesh--current)) (tab-bar-change-tab-group name))
  (when root (project-tab-sessions--set-root (tab-bar--current-tab-find) root)))

(defun lazyemacs-sesh--restore (data)
  "Make the saved session DATA live and select its last active layout."
  (let ((name (plist-get data :name))
        (root (plist-get data :root)))
    (lazyemacs-sesh--lock name)
    (dolist (tab (or (plist-get data :tabs) '((:name nil))))
      (lazyemacs-sesh--new-tab name (and root (file-directory-p root) root))
      (when (plist-get tab :explicit) (tab-bar-rename-tab (plist-get tab :name)))
      (lazyemacs-sesh--put-state (plist-get tab :state) (plist-get tab :buffers))
      (lazyemacs-sesh--track-windows (selected-frame)))
    (let ((count (length (project-tab-sessions--tabs name))))
      (project-tab-sessions-select-tab (1+ (min (1- count) (or (plist-get data :current) 0)))))
    (puthash name (prin1-to-string (plist-put (copy-sequence data) :last-used nil))
             lazyemacs-sesh--written)
    name))

;;; Connecting

(defun lazyemacs-sesh--note-switch (from to)
  "Remember FROM as the previous session after switching to TO."
  (when (and from (not (equal from to)))
    (setq lazyemacs-sesh--previous from)))

(defun lazyemacs-sesh--after-select (from-tab to-tab)
  "Save the session left when moving from FROM-TAB to TO-TAB."
  (let ((from (alist-get 'group from-tab))
        (to (alist-get 'group to-tab)))
    (unless (equal from to)
      (lazyemacs-sesh--note-switch from to)
      (when (lazyemacs-sesh--live-p from)
        (ignore-errors (lazyemacs-sesh--save from t))))))

(defun lazyemacs-sesh--unique-name (name root)
  "Return NAME, or NAME qualified by ROOT if another session uses it."
  (let ((candidate name) (suffix 1))
    (while (or (lazyemacs-sesh--live-p candidate)
               (let ((data (lazyemacs-sesh--saved-data candidate)))
                 (and data (not (equal root (plist-get data :root)))))
               (and (assoc candidate lazyemacs-sesh-sessions)
                    (not (equal root (lazyemacs-sesh--configured-root candidate)))))
      (setq candidate (format "%s (%s)%s" name (abbreviate-file-name (or root "new"))
                              (if (= suffix 1) "" (format " <%d>" suffix)))
            suffix (1+ suffix)))
    candidate))

(defun lazyemacs-sesh--create (name &optional root)
  "Create an empty session NAME, bound to project ROOT when non-nil."
  (lazyemacs-sesh--lock name)
  (lazyemacs-sesh--new-tab name root)
  (when root
    (let ((default-directory root))
      (funcall lazyemacs-sesh-open-root-function root)))
  name)

(defun lazyemacs-sesh--connect-directory (directory)
  "Connect to the session for DIRECTORY's project, creating it if needed."
  (let* ((directory (lazyemacs-sesh--dir directory))
         (project (project-current nil directory))
         (root (if project (project-tab-sessions--root project) directory)))
    (when project (project-remember-project project))
    (if-let* ((live (lazyemacs-sesh--live-for-root root)))
        (project-tab-sessions-switch live)
      (if-let* ((data (lazyemacs-sesh--saved-for-root root)))
          (lazyemacs-sesh--restore data)
        (let ((name (lazyemacs-sesh--unique-name
                     (if project (project-name project)
                       (file-name-nondirectory (directory-file-name root)))
                     root)))
          (if-let* ((config (lazyemacs-sesh--local-config root)))
              (lazyemacs-sesh--build (or (plist-get config :name) name)
                                     (plist-put config :root root)
                                     (lazyemacs-sesh--local-file root))
            (lazyemacs-sesh--create name root)))))))

(defun lazyemacs-sesh-connect-to (target)
  "Connect to TARGET: a session name, a directory, or a new session name.
A live session is selected, a saved one is restored, a configured one is
built, and a directory opens (or creates) the session for its project."
  (interactive (list (lazyemacs-sesh--read "Connect to session or directory: ")))
  (setq target (string-trim target))
  (when (string-empty-p target) (user-error "Session name is empty"))
  (let ((from (lazyemacs-sesh--current)))
    (unless (equal from target)
      (when (lazyemacs-sesh--live-p from) (ignore-errors (lazyemacs-sesh--save from t))))
    (prog1
        (cond ((lazyemacs-sesh--live-p target) (project-tab-sessions-switch target))
              ((lazyemacs-sesh--saved-data target)
               (lazyemacs-sesh--restore (lazyemacs-sesh--saved-data target)))
              ((assoc target lazyemacs-sesh-sessions)
               (lazyemacs-sesh--build target (cdr (assoc target lazyemacs-sesh-sessions)) t))
              ((and (or (string-match-p "[/\\~]" target) (member target '("." "..")))
                    (file-directory-p (expand-file-name target)))
               (lazyemacs-sesh--connect-directory target))
              (t (lazyemacs-sesh--create target)))
      (lazyemacs-sesh--note-switch from (lazyemacs-sesh--current)))))

(defun lazyemacs-sesh-last ()
  "Switch to the previous session, restoring it if it was closed."
  (interactive)
  (let ((previous lazyemacs-sesh--previous))
    (unless (and previous (not (equal previous (lazyemacs-sesh--current)))
                 (or (lazyemacs-sesh--live-p previous)
                     (lazyemacs-sesh--saved-data previous)))
      (user-error "No previous session"))
    (lazyemacs-sesh-connect-to previous)))

;;; Picker

(defun lazyemacs-sesh--branch (root)
  "Return ROOT's Git branch by reading .git/HEAD, without running Git."
  (when (and root (not (file-remote-p root)))
    (let ((git (expand-file-name ".git" root)))
      ;; Worktrees and submodules have a .git file pointing at the real one.
      (when (file-regular-p git)
        (setq git (with-temp-buffer
                    (insert-file-contents git)
                    (and (re-search-forward "^gitdir: *\\(.+\\)$" nil t)
                         (expand-file-name (match-string 1) root)))))
      (when-let* ((head (and git (expand-file-name "HEAD" git)))
                  ((file-readable-p head)))
        (let ((ref (string-trim (with-temp-buffer (insert-file-contents head) (buffer-string)))))
          (if (string-prefix-p "ref: refs/heads/" ref)
              (substring ref 16)
            (substring ref 0 (min 7 (length ref)))))))))

(defun lazyemacs-sesh--ago (time)
  "Describe TIME (seconds since the epoch) relative to now."
  (if (not (numberp time)) ""
    (let ((seconds (- (float-time) time)))
      (cond ((< seconds 60) "now")
            ((< seconds 3600) (format "%dm ago" (/ seconds 60)))
            ((< seconds 86400) (format "%dh ago" (/ seconds 3600)))
            (t (format "%dd ago" (/ seconds 86400)))))))

(defun lazyemacs-sesh--annotation (root layouts time &optional directory-p)
  "Format an annotation from ROOT, LAYOUTS count and last-used TIME.
DIRECTORY-P omits ROOT, which is then already the candidate itself."
  (let ((branch (lazyemacs-sesh--branch root)))
    (concat
     (unless directory-p
       (propertize (format " %-36s" (if root (abbreviate-file-name root) "no project"))
                   'face 'completions-annotations))
     (propertize (format " %-18s" (or branch "")) 'face 'font-lock-constant-face)
     (unless directory-p
       (concat
        (propertize (format " %-10s" (if layouts (format "%d layout%s" layouts (if (= layouts 1) "" "s")) ""))
                    'face 'completions-annotations)
        (propertize (format " %s" (lazyemacs-sesh--ago time)) 'face 'shadow))))))

(defun lazyemacs-sesh--configured-root (name)
  "Return the canonical root of configured session NAME."
  (when-let* ((root (plist-get (cdr (assoc name lazyemacs-sesh-sessions)) :root)))
    (lazyemacs-sesh--dir root)))

(defun lazyemacs-sesh--zoxide-directories ()
  "Return zoxide's directories, most frequent first, or nil without zoxide."
  (when-let* ((zoxide (executable-find "zoxide")))
    (with-temp-buffer
      ;; A remote default directory cannot be a process's working directory.
      (let ((default-directory (expand-file-name "~/")))
        (when (eq 0 (ignore-errors (call-process zoxide nil '(t nil) nil "query" "--list")))
          (seq-take (split-string (buffer-string) "\n" t) lazyemacs-sesh-zoxide-limit))))))

(defun lazyemacs-sesh--git (directory &rest args)
  "Run Git with ARGS in DIRECTORY; return its output or nil on failure."
  (when-let* ((git (executable-find "git"))
              ((not (file-remote-p directory))))
    (with-temp-buffer
      (let ((default-directory (file-name-as-directory directory)))
        (when (eq 0 (apply #'call-process git nil '(t nil) nil args))
          (buffer-string))))))

(defun lazyemacs-sesh--worktrees (&optional directory)
  "Return the Git worktrees of DIRECTORY's repository, main worktree first."
  (let ((directory (or directory
                       (lazyemacs-sesh--live-root (lazyemacs-sesh--current))
                       default-directory)))
    (when (and (file-directory-p directory) (locate-dominating-file directory ".git"))
      (when-let* ((output (lazyemacs-sesh--git directory "worktree" "list" "--porcelain")))
        (let (worktrees)
          (dolist (line (split-string output "\n" t))
            (when (string-prefix-p "worktree " line)
              (push (file-name-as-directory (substring line 9)) worktrees)))
          (nreverse worktrees))))))

(defun lazyemacs-sesh--claim (directories taken)
  "Return DIRECTORIES not in hash TAKEN, canonicalized, and claim them."
  (let (result)
    (dolist (directory directories)
      (let ((canonical (ignore-errors (lazyemacs-sesh--dir directory))))
        (when (and canonical (not (gethash canonical taken))
                   (or (file-remote-p canonical) (file-directory-p canonical)))
          (puthash canonical t taken)
          (push canonical result))))
    (nreverse result)))

(defun lazyemacs-sesh--sources ()
  "Return the `consult--multi' sources of the session picker."
  (let* ((live (lazyemacs-sesh--live-names))
         (saved (lazyemacs-sesh--saved))
         (saved-names (mapcar (lambda (data) (plist-get data :name)) saved))
         (dormant (seq-remove (lambda (data) (member (plist-get data :name) live)) saved))
         (configured (seq-remove (lambda (name) (or (member name live) (member name saved-names)))
                                 (mapcar #'car lazyemacs-sesh-sessions)))
         (taken (make-hash-table :test #'equal))
         (item (lambda (icon target &optional display)
                 (cons (if (string-empty-p icon) (or display target)
                         (concat icon " " (or display target)))
                       target))))
    ;; A directory that already has a session is reached through that session.
    (dolist (name live)
      (when-let* ((root (lazyemacs-sesh--live-root name))) (puthash root t taken)))
    (dolist (data saved)
      (when-let* ((root (plist-get data :root))) (puthash root t taken)))
    (dolist (name configured)
      (when-let* ((root (ignore-errors (lazyemacs-sesh--configured-root name))))
        (puthash root t taken)))
    (let* ((worktrees (lazyemacs-sesh--claim (lazyemacs-sesh--worktrees) taken))
           (projects (lazyemacs-sesh--claim (project-known-project-roots) taken))
           (zoxide (and (executable-find "zoxide")
                        (lazyemacs-sesh--claim (lazyemacs-sesh--zoxide-directories) taken)))
           (directory-annotate (lambda (directory)
                                 (lazyemacs-sesh--annotation directory nil nil t)))
           (directory-source
            (lambda (name narrow icon directories)
              (list :name name :narrow narrow :category 'lazyemacs-session
                    :items (mapcar (lambda (directory)
                                     (funcall item icon directory (abbreviate-file-name directory)))
                                   directories)
                    :annotate directory-annotate))))
      (delq nil
            (list
             (list :name "Sessions" :narrow ?s :category 'lazyemacs-session
                   :items (mapcar (lambda (name) (funcall item "●" name)) live)
                   :annotate (lambda (name)
                               (lazyemacs-sesh--annotation
                                (lazyemacs-sesh--live-root name)
                                (length (project-tab-sessions--tabs name))
                                (if (equal name (lazyemacs-sesh--current)) (float-time)
                                  (my/session-last-used name (funcall tab-bar-tabs-function))))))
             (list :name "Saved" :narrow ?d :category 'lazyemacs-session
                   :items (mapcar (lambda (data) (funcall item "◌" (plist-get data :name))) dormant)
                   :annotate (lambda (name)
                               (let ((data (seq-find (lambda (data) (equal name (plist-get data :name)))
                                                     dormant)))
                                 (lazyemacs-sesh--annotation (plist-get data :root)
                                                             (length (plist-get data :tabs))
                                                             (plist-get data :last-used)))))
             (list :name "Configured" :narrow ?c :category 'lazyemacs-session
                   :items (mapcar (lambda (name) (funcall item "⚙" name)) configured)
                   :annotate (lambda (name)
                               (lazyemacs-sesh--annotation
                                (ignore-errors (lazyemacs-sesh--configured-root name))
                                (length (plist-get (cdr (assoc name lazyemacs-sesh-sessions)) :layouts))
                                nil)))
             (funcall directory-source "Worktrees" ?w "" worktrees)
             (funcall directory-source "Projects" ?p "" projects)
             (and zoxide (funcall directory-source "Zoxide" ?z "" zoxide)))))))

(defun lazyemacs-sesh-connect ()
  "Pick a session, project, zoxide directory, or worktree and connect to it.
Narrow with s (live), d (saved), c (configured), w (worktrees), p (projects)
and z (zoxide).  Typing a new name creates an empty session.  C-. acts on
the candidate: detach, kill, rename, forget, open its root, and more."
  (interactive)
  (require 'consult)
  (let ((selected (consult--multi (lazyemacs-sesh--sources)
                                  :prompt "Connect: "
                                  :require-match nil
                                  :sort nil
                                  :history 'lazyemacs-sesh-history)))
    (when (and selected (not (string-empty-p (string-trim (car selected)))))
      (lazyemacs-sesh-connect-to (car selected)))))

(defun lazyemacs-sesh--read (prompt &optional live-only)
  "Read a session name with PROMPT; LIVE-ONLY limits completion to live ones.
Any input is accepted, so Embark can pass directory candidates too."
  (let ((names (if live-only (lazyemacs-sesh--live-names)
                 (delete-dups (append (lazyemacs-sesh--live-names)
                                      (mapcar (lambda (data) (plist-get data :name))
                                              (lazyemacs-sesh--saved))
                                      (mapcar #'car lazyemacs-sesh-sessions))))))
    (completing-read prompt
                     (lambda (string predicate action)
                       (if (eq action 'metadata)
                           '(metadata (category . lazyemacs-session)
                                      (annotation-function . my/session-annotation)
                                      (display-sort-function . identity))
                         (complete-with-action action names string predicate)))
                     nil nil nil 'lazyemacs-sesh-history (lazyemacs-sesh--current))))

;;; Detach, kill, rename, forget

(defun lazyemacs-sesh--leave (name)
  "Select a session other than NAME, creating Main when NAME is the last one."
  (let ((others (remove name (lazyemacs-sesh--live-names))))
    (cond
     ((not (equal name (lazyemacs-sesh--current))))
     ((and lazyemacs-sesh--previous (member lazyemacs-sesh--previous others))
      (project-tab-sessions-switch lazyemacs-sesh--previous))
     (others (project-tab-sessions-switch (car others)))
     (t
      ;; The last session is closing: open a fresh default session.  When it
      ;; is the default session itself, use a temporary name until it closes.
      (let ((tab-bar-new-tab-choice "*scratch*")) (tab-bar-new-tab))
      (tab-bar-change-tab-group (if (equal name project-tab-sessions-default-group)
                                    " lazyemacs-sesh-new"
                                  project-tab-sessions-default-group))
      (when (and (bound-and-true-p lazyemacs-dashboard) (fboundp 'lazyemacs-dashboard))
        (lazyemacs-dashboard))))))

(defun lazyemacs-sesh--close (name)
  "Close the layouts of live session NAME, keeping buffers and processes."
  (lazyemacs-sesh--leave name)
  (tab-bar-close-group-tabs name)
  (when (project-tab-sessions--tabs " lazyemacs-sesh-new")
    (dolist (entry (project-tab-sessions--tabs " lazyemacs-sesh-new"))
      (tab-bar-change-tab-group project-tab-sessions-default-group (car entry))))
  (lazyemacs-sesh--unlock name)
  (setq lazyemacs-sesh--previous name)
  (force-mode-line-update t))

(defun lazyemacs-sesh-detach (name)
  "Save session NAME and close its layouts, keeping its buffers.
Connect again (s-p) to bring the layouts back."
  (interactive (list (lazyemacs-sesh--read "Detach session: " t)))
  (unless (lazyemacs-sesh--live-p name) (user-error "No live session named %s" name))
  (lazyemacs-sesh--save name)
  (lazyemacs-sesh--close name)
  (message "Detached session %s" name))

(defun lazyemacs-sesh--kill-candidates (name root)
  "Return the buffers that killing session NAME with ROOT would kill."
  (let ((others (remove name (lazyemacs-sesh--live-names))))
    (seq-filter
     (lambda (buffer)
       (let ((sessions (buffer-local-value 'lazyemacs-sesh--buffer-sessions buffer))
             (name-of (buffer-name buffer)))
         (and (not (string-prefix-p " " name-of))
              (not (member name-of '("*scratch*" "*Messages*")))
              (not (equal name-of (bound-and-true-p lazyemacs-dashboard-buffer-name)))
              (not (seq-intersection sessions others))
              (if root
                  (let ((file (with-current-buffer buffer
                                (or buffer-file-name (expand-file-name default-directory)))))
                    (and (not (file-remote-p file))
                         (file-in-directory-p file root)))
                (equal sessions (list name))))))
     (buffer-list))))

(defun lazyemacs-sesh-kill (name)
  "Close session NAME and kill its buffers and their processes.
Buffers under the session root that another live session shows are kept.
The saved file stays; use `lazyemacs-sesh-forget' to delete it."
  (interactive (list (lazyemacs-sesh--read "Kill session: " t)))
  (unless (lazyemacs-sesh--live-p name) (user-error "No live session named %s" name))
  (let* ((root (lazyemacs-sesh--live-root name))
         (victims (lazyemacs-sesh--kill-candidates name root)))
    (when (y-or-n-p (format "Kill session %s and %d buffer%s%s? " name (length victims)
                            (if (= (length victims) 1) "" "s")
                            (if root (format " under %s" (abbreviate-file-name root)) "")))
      ;; Killing discards the live layout; only detaching saves it.
      (let ((lazyemacs-sesh--inhibit-save t)) (lazyemacs-sesh--close name))
      (save-some-buffers nil (lambda () (memq (current-buffer) victims)))
      (dolist (buffer victims)
        (when (buffer-live-p buffer)
          (when-let* ((process (get-buffer-process buffer)))
            (set-process-query-on-exit-flag process nil))
          (kill-buffer buffer)))
      (message "Killed session %s" name))))

(defun lazyemacs-sesh-rename (name new-name)
  "Rename session NAME to NEW-NAME, live or saved, including its file."
  (interactive
   (let ((name (lazyemacs-sesh--read "Rename session: ")))
     (list name (read-string "New session name: " name))))
  (setq new-name (string-trim new-name))
  (when (string-empty-p new-name) (user-error "Session name is empty"))
  (unless (equal name new-name)
    (when (or (lazyemacs-sesh--live-p new-name) (lazyemacs-sesh--saved-data new-name))
      (user-error "Session %s already exists" new-name))
    (let ((data (lazyemacs-sesh--saved-data name)))
      (unless (or data (lazyemacs-sesh--live-p name))
        (user-error "No session named %s" name))
      (when (lazyemacs-sesh--live-p name)
        (lazyemacs-sesh--lock name)
        (my/session-rename name new-name))
      (dolist (buffer (buffer-list))
        (with-current-buffer buffer
          (when (member name lazyemacs-sesh--buffer-sessions)
            (setq lazyemacs-sesh--buffer-sessions
                  (cons new-name (delete name lazyemacs-sesh--buffer-sessions))))))
      (when (equal lazyemacs-sesh--previous name) (setq lazyemacs-sesh--previous new-name))
      (when data
        (lazyemacs-sesh--write-file (lazyemacs-sesh--file new-name)
                                    (plist-put (copy-sequence data) :name new-name))
        (delete-file (lazyemacs-sesh--file name)))
      (lazyemacs-sesh--unlock name)
      (remhash name lazyemacs-sesh--written)
      (when (lazyemacs-sesh--live-p new-name)
        (lazyemacs-sesh--lock new-name)
        (lazyemacs-sesh--save new-name t)))))

(defun lazyemacs-sesh-forget (name)
  "Delete the saved file of session NAME.  A live session must be closed first."
  (interactive (list (lazyemacs-sesh--read "Forget saved session: ")))
  (when (lazyemacs-sesh--live-p name)
    (user-error "Session %s is open; detach or kill it before forgetting it" name))
  (let ((file (lazyemacs-sesh--file name)))
    (unless (file-exists-p file) (user-error "No saved session named %s" name))
    (when (lazyemacs-sesh--lock-owner name)
      (user-error "Session %s is open in another Emacs" name))
    (delete-file file)
    (lazyemacs-sesh--unlock name)
    (remhash name lazyemacs-sesh--written)
    (message "Forgot session %s" name)))

;;; Configured sessions

(defun lazyemacs-define-session (name &rest plist)
  "Declare session NAME, built the first time you connect to it.
PLIST supports :root (a directory), :startup (a function run in the root
after the layouts are built), and :layouts, a list of (NAME . LAYOUT) where
LAYOUT is a plist of any of:
  :file FILE        visit FILE (relative to the root)
  :dired DIRECTORY  show DIRECTORY in Dired (split right of a file)
  :terminal COMMAND start a terminal in the root and run COMMAND (\"\" for a shell)
  :command COMMAND  call COMMAND in the root after the rest of the layout
Once saved, the session restores from its file; use the Embark action
\"rebuild\" (b) to build it from this declaration again."
  (setf (alist-get name lazyemacs-sesh-sessions nil nil #'equal) plist)
  name)

(defun lazyemacs-sesh--local-file (root)
  "Return ROOT's session data file name."
  (expand-file-name lazyemacs-sesh-local-file root))

(defun lazyemacs-sesh--local-config (root)
  "Read ROOT's `.lazyemacs-session.el' as data, or return nil."
  (let ((file (lazyemacs-sesh--local-file root)))
    (when (and (not (file-remote-p file)) (file-readable-p file))
      (let ((data (lazyemacs-sesh--read-file file)))
        (if (plistp data) data
          (message "Ignoring %s: it must contain one property list" file)
          nil)))))

(defun lazyemacs-sesh--runs-commands-p (plist)
  "Return non-nil when session PLIST would run commands."
  (or (plist-get plist :startup)
      (seq-some (lambda (layout)
                  (and (consp layout)
                       (or (plist-get (cdr layout) :terminal) (plist-get (cdr layout) :command))))
                (plist-get plist :layouts))))

(defun lazyemacs-sesh--file-hash (file)
  "Return the SHA-256 of FILE's contents."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert-file-contents-literally file)
    (secure-hash 'sha256 (current-buffer))))

(defun lazyemacs-sesh--trusted-p (file)
  "Return non-nil when FILE, as it is now, has been trusted."
  (let ((trusted (lazyemacs-sesh--read-file lazyemacs-sesh-trust-file)))
    (and (listp trusted)
         (member (cons (expand-file-name file) (lazyemacs-sesh--file-hash file)) trusted)
         t)))

(defun lazyemacs-sesh--trust (file)
  "Ask once whether commands in FILE may run; return non-nil if trusted.
The answer is tied to the file's contents, so any edit asks again."
  (or (lazyemacs-sesh--trusted-p file)
      (when (y-or-n-p (format "Allow %s to run its terminal and startup commands? "
                              (abbreviate-file-name file)))
        (let* ((key (cons (expand-file-name file) (lazyemacs-sesh--file-hash file)))
               (trusted (lazyemacs-sesh--read-file lazyemacs-sesh-trust-file)))
          (lazyemacs-sesh--write-file
           lazyemacs-sesh-trust-file
           (cons key (seq-remove (lambda (entry) (equal (car-safe entry) (car key)))
                                 (and (listp trusted) trusted)))))
        t)))

(defun lazyemacs-sesh--build-layout (session layout-name layout root allowed)
  "Fill the selected tab of SESSION with LAYOUT named LAYOUT-NAME in ROOT.
Commands run only when ALLOWED; otherwise terminals become placeholders."
  (let* ((default-directory root)
         (file (plist-get layout :file))
         (directory (plist-get layout :dired))
         (terminal (plist-get layout :terminal))
         (command (plist-get layout :command))
         (shown nil))
    (delete-other-windows)
    (when (and file (file-readable-p (expand-file-name file root)))
      (find-file (expand-file-name file root))
      (setq shown t))
    (when (and directory (file-directory-p (expand-file-name directory root)))
      (when shown (select-window (split-window-right)))
      (dired (expand-file-name directory root))
      (setq shown t))
    (when terminal
      (when shown (select-window (split-window-below)))
      (let ((name (format "*%s:%s*" session layout-name)))
        (if (not allowed)
            (switch-to-buffer (my/session-restore-terminal nil name root))
          (let ((buffer (my/terminal-create name '(display-buffer-same-window))))
            (when (and (stringp terminal) (not (string-empty-p terminal)))
              (my/terminal-send buffer terminal)))))
      (setq shown t))
    (when (and command allowed)
      (if (commandp command) (call-interactively command) (funcall command)))
    (unless shown
      (when (or file directory)
        (message "Session %s: skipped missing %s" session (or file directory)))
      (dired root))))

(defun lazyemacs-sesh--build (name plist trust)
  "Build session NAME from configuration PLIST.
TRUST is t for configuration from the user's own files, or the data file
whose commands need a one-time confirmation."
  (let* ((root (lazyemacs-sesh--dir (or (plist-get plist :root) default-directory)))
         (layouts (or (plist-get plist :layouts) '(("main" :dired "."))))
         (allowed (or (eq trust t)
                      (not (lazyemacs-sesh--runs-commands-p plist))
                      (lazyemacs-sesh--trust trust))))
    (unless (file-directory-p root)
      (user-error "Session %s: directory %s does not exist" name root))
    (unless allowed
      (message "Session %s: commands from %s were not run" name (abbreviate-file-name trust)))
    (lazyemacs-sesh--lock name)
    (dolist (layout layouts)
      (let ((layout-name (format "%s" (car layout))))
        (lazyemacs-sesh--new-tab name root)
        (tab-bar-rename-tab layout-name)
        (lazyemacs-sesh--build-layout name layout-name (cdr layout) root allowed)
        (lazyemacs-sesh--track-windows (selected-frame))))
    (project-tab-sessions-select-tab 1)
    (when-let* ((startup (plist-get plist :startup))
                ((and allowed (functionp startup))))
      (let ((default-directory root)) (funcall startup)))
    name))

(defun lazyemacs-sesh-rebuild (name)
  "Rebuild session NAME from its configuration, replacing its live layouts."
  (interactive (list (lazyemacs-sesh--read "Rebuild session: ")))
  (let* ((root (or (lazyemacs-sesh--live-root name)
                   (plist-get (lazyemacs-sesh--saved-data name) :root)))
         (configured (cdr (assoc name lazyemacs-sesh-sessions)))
         (local (and (not configured) root (lazyemacs-sesh--local-config root))))
    (unless (or configured local)
      (user-error "Session %s has no configuration to rebuild from" name))
    (when (lazyemacs-sesh--live-p name)
      ;; Build under the real name, then drop the old layouts.
      (dolist (entry (project-tab-sessions--tabs name))
        (setf (alist-get 'group (cdr (cdr entry))) " lazyemacs-sesh-old")))
    (if configured
        (lazyemacs-sesh--build name configured t)
      (lazyemacs-sesh--build name (plist-put local :root root) (lazyemacs-sesh--local-file root)))
    (when (project-tab-sessions--tabs " lazyemacs-sesh-old")
      (tab-bar-close-group-tabs " lazyemacs-sesh-old"))
    (project-tab-sessions-switch name)))

;;; Actions in the session root

(defun lazyemacs-sesh--connect-root (target)
  "Connect to TARGET and return its root directory."
  (lazyemacs-sesh-connect-to target)
  (or (lazyemacs-sesh--live-root (lazyemacs-sesh--current))
      (user-error "Session %s has no project directory" target)))

(defun lazyemacs-sesh-dired (target)
  "Connect to TARGET and open its root in Dired."
  (interactive (list (lazyemacs-sesh--read "Open session root: ")))
  (dired (lazyemacs-sesh--connect-root target)))

(defun lazyemacs-sesh-magit (target)
  "Connect to TARGET and show its Git status."
  (interactive (list (lazyemacs-sesh--read "Git status of session: ")))
  (let ((root (lazyemacs-sesh--connect-root target)))
    (require 'magit)
    (magit-status-setup-buffer root)))

(defun lazyemacs-sesh-terminal (target)
  "Connect to TARGET and show its project terminal."
  (interactive (list (lazyemacs-sesh--read "Terminal in session: ")))
  (let ((default-directory (lazyemacs-sesh--connect-root target)))
    (my/project-ghostel)))

(defun lazyemacs-sesh-find-file (target)
  "Connect to TARGET and find a file in its root."
  (interactive (list (lazyemacs-sesh--read "Find file in session: ")))
  (let ((default-directory (lazyemacs-sesh--connect-root target)))
    (if (project-current nil default-directory)
        (project-find-file)
      (call-interactively #'find-file))))

(defun lazyemacs-sesh-ripgrep (target)
  "Connect to TARGET and search its root with ripgrep."
  (interactive (list (lazyemacs-sesh--read "Search session: ")))
  (consult-ripgrep (lazyemacs-sesh--connect-root target)))

;;; Worktrees and clones

(defun lazyemacs-sesh--target-directory (target)
  "Return the directory of session or directory TARGET."
  (or (lazyemacs-sesh--live-root target)
      (plist-get (lazyemacs-sesh--saved-data target) :root)
      (ignore-errors (lazyemacs-sesh--configured-root target))
      (and (file-directory-p (expand-file-name target)) (lazyemacs-sesh--dir target))
      (user-error "No directory for %s" target)))

(defun lazyemacs-sesh-worktree-add (target branch)
  "Create a Git worktree for BRANCH beside TARGET's repository and connect.
The worktree goes to ../REPO-BRANCH; BRANCH is created when it is new."
  (interactive
   (list (lazyemacs-sesh--read "Repository session or directory: ")
         (read-string "Branch for the new worktree: ")))
  (setq branch (string-trim branch))
  (when (string-empty-p branch) (user-error "Branch name is empty"))
  (let* ((directory (lazyemacs-sesh--target-directory target))
         (main (or (car (lazyemacs-sesh--worktrees directory))
                   (user-error "%s is not in a Git repository" directory)))
         (repo (file-name-nondirectory (directory-file-name main)))
         (worktree (expand-file-name
                    (format "%s-%s" repo (replace-regexp-in-string "[/\\\\:]" "-" branch))
                    (file-name-directory (directory-file-name main))))
         (exists (lazyemacs-sesh--git main "show-ref" "--verify" "--quiet"
                                      (concat "refs/heads/" branch))))
    (unless (file-directory-p worktree)
      (with-temp-buffer
        (let ((default-directory main))
          (unless (eq 0 (apply #'call-process "git" nil t nil "worktree" "add"
                               (if exists (list worktree branch)
                                 (list "-b" branch worktree))))
            (user-error "git worktree add failed: %s" (string-trim (buffer-string)))))))
    (lazyemacs-sesh-connect-to worktree)))

(defun lazyemacs-sesh--clone-target (url)
  "Return the directory name for cloning URL."
  (let ((name (replace-regexp-in-string
               "\\.git\\'" ""
               (car (last (split-string (string-trim-right url "/+") "[/:]" t))))))
    (expand-file-name name lazyemacs-sesh-clone-directory)))

(defun lazyemacs-sesh-clone (url &optional directory)
  "Clone URL into `lazyemacs-sesh-clone-directory' and connect to it.
With a prefix argument, ask for the DIRECTORY.  Cloning runs in the
background; its output is in the *lazyemacs-clone* buffer."
  (interactive
   (let ((url (read-string "Clone repository URL: ")))
     (list url (when current-prefix-arg
                 (read-directory-name "Clone into: " nil nil nil
                                      (file-name-nondirectory (lazyemacs-sesh--clone-target url)))))))
  (when (string-empty-p (string-trim url)) (user-error "Repository URL is empty"))
  (let ((target (expand-file-name (or directory (lazyemacs-sesh--clone-target url))))
        (buffer (get-buffer-create "*lazyemacs-clone*")))
    (when (file-exists-p target) (user-error "%s already exists" target))
    (make-directory (file-name-directory (directory-file-name target)) t)
    (with-current-buffer buffer
      (let ((inhibit-read-only t)) (erase-buffer) (insert "git clone " url "\n")))
    (make-process
     :name "lazyemacs-clone"
     :buffer buffer
     :command (list (or (executable-find "git") "git") "clone" "--" url target)
     :sentinel (lambda (process _event)
                 (when (memq (process-status process) '(exit signal))
                   (if (and (eq (process-status process) 'exit)
                            (zerop (process-exit-status process)))
                       (progn (message "Cloned %s" url)
                              (lazyemacs-sesh-connect-to target))
                     (display-buffer buffer)
                     (message "Cloning %s failed; see *lazyemacs-clone*" url)))))))

;;; Shell entry point (bin/lazyemacs-connect)

(defun lazyemacs-sesh--client-frames ()
  "Return visible frames that can show a session, most recent first."
  (seq-filter (lambda (frame)
                (and (frame-visible-p frame)
                     (not (eq frame terminal-frame))
                     (not (frame-parameter frame 'parent-frame))))
              (cons (selected-frame) (frame-list))))

(defun lazyemacs-sesh-cli-has-frame-p ()
  "Return t when a visible frame exists, for `lazyemacs-connect -c'."
  (and (lazyemacs-sesh--client-frames) t))

(defun lazyemacs-sesh-cli-connect (target)
  "Connect to TARGET in the most recent visible frame and raise it.
Called by bin/lazyemacs-connect through emacsclient."
  (let ((frame (or (car (lazyemacs-sesh--client-frames)) (selected-frame))))
    (with-selected-frame frame
      (lazyemacs-sesh-connect-to target))
    (select-frame-set-input-focus frame)
    (lazyemacs-sesh--current)))

;;; Restoring the sessions open at exit

(defun lazyemacs-sesh-restore (&optional startup)
  "Reopen the sessions that were open when Emacs last exited.
With STARTUP, replace the pristine startup layout instead of keeping it."
  (interactive)
  (let* ((state (lazyemacs-sesh--read-file lazyemacs-sesh-state-file))
         (state (and (plistp state) state))
         (names (seq-filter #'lazyemacs-sesh--saved-data (plist-get state :sessions)))
         (current (plist-get state :current))
         (pristine (and startup (lazyemacs-sesh--current)))
         restored)
    (cond
     ((and (not names) startup) nil)
     ((not names)
      (user-error "No saved sessions to restore; sessions are saved on exit or with SPC q S"))
     (t
      ;; At startup the default session is an empty tab: let a saved version
      ;; of it restore in place instead of selecting the empty one.
      (when pristine (tab-bar-change-tab-group " lazyemacs-sesh-startup"))
      (dolist (name names)
        (unless (lazyemacs-sesh--live-p name)
          (condition-case err
              (progn (lazyemacs-sesh--restore (lazyemacs-sesh--saved-data name))
                     (push name restored))
            (user-error (message "%s" (error-message-string err))))))
      (when pristine
        (let ((others (remove " lazyemacs-sesh-startup" (lazyemacs-sesh--live-names))))
          (if (not others)
              (tab-bar-change-tab-group pristine)
            (when (equal (lazyemacs-sesh--current) " lazyemacs-sesh-startup")
              (project-tab-sessions-switch (car others)))
            (tab-bar-close-group-tabs " lazyemacs-sesh-startup"))))
      (when (lazyemacs-sesh--live-p current)
        (project-tab-sessions-switch current))
      (setq lazyemacs-sesh--previous
            (let ((previous (plist-get state :previous)))
              (and (not (equal previous (lazyemacs-sesh--current))) previous)))
      (message "Restored %d session%s" (length restored) (if (= (length restored) 1) "" "s"))
      (nreverse restored)))))

(defun lazyemacs-sesh-restore-last ()
  "Restore the most recently used saved session that is not open."
  (interactive)
  (let ((data (seq-find (lambda (data) (not (lazyemacs-sesh--live-p (plist-get data :name))))
                        (lazyemacs-sesh--saved))))
    (unless data (user-error "No closed saved session"))
    (lazyemacs-sesh-connect-to (plist-get data :name))))

(defun lazyemacs-sesh-import-desktop ()
  "Restore the desktop saved by older LazyEmacs versions as sessions.
Each restored tab group is then saved to its own session file."
  (interactive)
  (my/session-restore-desktop)
  (message "Imported the desktop as %d session files" (lazyemacs-sesh-save-all t)))

(defun lazyemacs-sesh--startup ()
  "Restore the sessions open at exit unless disabled or in batch mode."
  (when (and lazyemacs-sesh-restore-on-startup
             (not lazyemacs-sesh--no-restore-arg)
             (not noninteractive))
    (condition-case err
        (lazyemacs-sesh-restore t)
      (error (message "Could not restore sessions: %s" (error-message-string err))))))

(defun lazyemacs-sesh--startup-daemon (&rest _)
  "Restore sessions in the first client frame of a daemon."
  (remove-hook 'server-after-make-frame-hook #'lazyemacs-sesh--startup-daemon)
  (lazyemacs-sesh--startup))

(defun lazyemacs-sesh--kill-emacs ()
  "Save sessions and release this Emacs's locks."
  (ignore-errors (lazyemacs-sesh-save-all t))
  (dolist (name (lazyemacs-sesh--live-names))
    (ignore-errors (lazyemacs-sesh--unlock name))))

;;; Session-scoped buffers

(defun lazyemacs-sesh--mark-buffer (buffer session)
  "Record that BUFFER was shown in SESSION."
  (when (and session (buffer-live-p buffer)
             (not (string-prefix-p " " (buffer-name buffer)))
             (not (minibufferp buffer)))
    (with-current-buffer buffer
      (unless (member session lazyemacs-sesh--buffer-sessions)
        (push session lazyemacs-sesh--buffer-sessions)))))

(defun lazyemacs-sesh--track-windows (frame)
  "Record the buffers shown on FRAME as belonging to its current session."
  (let ((session (alist-get 'group (tab-bar--current-tab-find nil frame))))
    (dolist (window (window-list frame 'nomini))
      (lazyemacs-sesh--mark-buffer (window-buffer window) session))))

(defun lazyemacs-sesh-buffer-p (buffer &optional session)
  "Return non-nil when BUFFER was shown in SESSION (default: the current one)."
  (let ((session (or session (lazyemacs-sesh--current))))
    (or (not session)
        (member session (buffer-local-value 'lazyemacs-sesh--buffer-sessions
                                            (get-buffer buffer))))))

(defvar lazyemacs-sesh-buffer-source
  (list :name "Session buffers" :narrow ?s :category 'buffer :face 'consult-buffer
        :history 'buffer-name-history :default t
        :state (lambda () (consult--buffer-state))
        :items (lambda ()
                 (consult--buffer-query :sort 'visibility
                                        :predicate #'lazyemacs-sesh-buffer-p
                                        :as #'consult--buffer-pair)))
  "Consult source of buffers shown in the current session.")

(defvar lazyemacs-sesh-all-buffers-source
  (list :name "All buffers" :narrow ?a :hidden t :category 'buffer :face 'consult-buffer
        :history 'buffer-name-history
        :state (lambda () (consult--buffer-state))
        :items (lambda () (consult--buffer-query :sort 'visibility :as #'consult--buffer-pair)))
  "Consult source of every buffer, hidden until narrowed with `a'.")

(defvar lazyemacs-sesh-buffer-sources
  '(lazyemacs-sesh-buffer-source lazyemacs-sesh-all-buffers-source
    consult-source-recent-file)
  "Sources of `lazyemacs-sesh-buffer'.")

(defun lazyemacs-sesh-buffer ()
  "Switch to a buffer of this session; type `a SPC' to see all buffers."
  (interactive)
  (require 'consult)
  (if lazyemacs-sesh-scope-buffers
      (consult-buffer lazyemacs-sesh-buffer-sources)
    (consult-buffer)))

(defun lazyemacs-sesh--skip-buffer-p (_window buffer _bury-or-kill)
  "Return non-nil when BUFFER does not belong to the current session."
  (not (lazyemacs-sesh-buffer-p buffer)))

(defun my/session-previous-buffer ()
  "Show the previous buffer of this window that belongs to this session."
  (interactive)
  (let ((switch-to-prev-buffer-skip (if lazyemacs-sesh-scope-buffers
                                        #'lazyemacs-sesh--skip-buffer-p
                                      switch-to-prev-buffer-skip)))
    (previous-buffer)))

(defun my/session-next-buffer ()
  "Show the next buffer of this window that belongs to this session."
  (interactive)
  (let ((switch-to-prev-buffer-skip (if lazyemacs-sesh-scope-buffers
                                        #'lazyemacs-sesh--skip-buffer-p
                                      switch-to-prev-buffer-skip)))
    (next-buffer)))

;;; Display

(defun lazyemacs-sesh-tab-bar-others ()
  "Tab bar item counting the other live sessions, dimmed; click to switch."
  (let ((others (remove (lazyemacs-sesh--current) (lazyemacs-sesh--live-names))))
    (when others
      `((lazyemacs-sesh-others
         menu-item ,(propertize (format " +%d " (length others)) 'face 'shadow)
         lazyemacs-sesh-connect
         :help ,(concat "Other sessions: " (string-join others ", ")))))))

(defun lazyemacs-sesh-mode-line-string ()
  "Return the current session name for the mode line."
  (when-let* ((name (and lazyemacs-sesh-mode-line (lazyemacs-sesh--current))))
    (propertize (format " %s " name) 'face 'shadow
                'help-echo "Session (s-p switches)")))

(defvar lazyemacs-sesh-mode-line-construct '(:eval (lazyemacs-sesh-mode-line-string))
  "Mode line construct showing the current session.")
(put 'lazyemacs-sesh-mode-line-construct 'risky-local-variable t)

(defun lazyemacs-sesh-dashboard-insert (indent width)
  "Insert up to five recent sessions into the dashboard at INDENT, WIDTH wide."
  (let* ((live (lazyemacs-sesh--live-names))
         (entries
          (seq-take
           (sort (delete-dups
                  (append
                   (mapcar (lambda (name) (cons name (float-time))) live)
                   (seq-remove (lambda (entry) (member (car entry) live))
                               (mapcar (lambda (data) (cons (plist-get data :name)
                                                            (plist-get data :last-used)))
                                       (lazyemacs-sesh--saved)))))
                 (lambda (a b) (> (or (cdr a) 0) (or (cdr b) 0))))
           5)))
    (when entries
      (insert "\n" (make-string indent ?\s)
              (propertize "Sessions" 'face 'lazyemacs-dashboard-heading) "\n")
      (pcase-dolist (`(,name . ,time) entries)
        (let* ((age (if (member name live) "open" (lazyemacs-sesh--ago time)))
               (label (truncate-string-to-width name (max 10 (- width (length age) 2)) nil nil "…")))
          (insert (make-string indent ?\s))
          (insert-text-button label 'action (lambda (_) (lazyemacs-sesh-connect-to name))
                              'follow-link t)
          (insert (make-string (max 1 (- width (string-width label) (length age))) ?\s)
                  (propertize age 'face 'shadow) "\n"))))))

;;; Embark actions

(dolist (binding '(("RET" . lazyemacs-sesh-connect-to)
                   ("d" . lazyemacs-sesh-detach)
                   ("k" . lazyemacs-sesh-detach)
                   ("D" . lazyemacs-sesh-kill)
                   ("r" . lazyemacs-sesh-rename)
                   ("o" . lazyemacs-sesh-dired)
                   ("g" . lazyemacs-sesh-magit)
                   ("t" . lazyemacs-sesh-terminal)
                   ("f" . lazyemacs-sesh-find-file)
                   ("/" . lazyemacs-sesh-ripgrep)
                   ("x" . lazyemacs-sesh-forget)
                   ("w" . lazyemacs-sesh-worktree-add)
                   ("b" . lazyemacs-sesh-rebuild)
                   ("s" . lazyemacs-sesh-save)))
  (keymap-set my/embark-session-map (car binding) (cdr binding)))

(with-eval-after-load 'embark
  ;; Keep the picker open after actions that change the list, and refresh it.
  (dolist (action '(lazyemacs-sesh-detach lazyemacs-sesh-rename lazyemacs-sesh-forget
                    lazyemacs-sesh-save))
    (setf (alist-get action embark-quit-after-action) nil))
  (dolist (action '(lazyemacs-sesh-detach lazyemacs-sesh-rename lazyemacs-sesh-forget))
    (add-to-list 'embark-post-action-hooks `(,action embark--restart))))

;;; Compatibility with earlier session commands

(defalias 'my/session-save #'lazyemacs-sesh-save-all
  "Save every live session (formerly the global desktop).")
(defalias 'my/session-restore #'lazyemacs-sesh-restore
  "Reopen the sessions open at exit (formerly the global desktop).")
(defalias 'my/session-stop-saving #'lazyemacs-sesh-stop-saving
  "Stop saving sessions for the rest of this Emacs.")

;;; Activation

(add-hook 'tab-bar-tab-post-select-functions #'lazyemacs-sesh--after-select)
(add-hook 'window-buffer-change-functions #'lazyemacs-sesh--track-windows)
(unless (memq #'lazyemacs-sesh-tab-bar-others tab-bar-format)
  (setq tab-bar-format (append tab-bar-format '(lazyemacs-sesh-tab-bar-others))))
(unless (member 'lazyemacs-sesh-mode-line-construct (ensure-list global-mode-string))
  ;; A mode-line list starting with a symbol is a conditional, so lead with "".
  (setq global-mode-string
        (append (if (and (consp global-mode-string) (stringp (car global-mode-string)))
                    global-mode-string
                  (cons "" (ensure-list global-mode-string)))
                '(lazyemacs-sesh-mode-line-construct))))

;; Batch runs (tests, scripts) never restore, autosave, or write on exit.
(unless noninteractive
  (add-hook 'kill-emacs-hook #'lazyemacs-sesh--kill-emacs)
  (when lazyemacs-sesh-save-interval
    (run-with-idle-timer lazyemacs-sesh-save-interval t #'lazyemacs-sesh-save-all t))
  (if (daemonp)
      (add-hook 'server-after-make-frame-hook #'lazyemacs-sesh--startup-daemon)
    (add-hook 'after-init-hook #'lazyemacs-sesh--startup 90)))

(provide 'init-sesh)
;;; init-sesh.el ends here
