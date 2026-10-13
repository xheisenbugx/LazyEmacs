;;; init-lock.el --- Package lockfile for reproducible releases -*- lexical-binding: t; -*-

;;; Commentary:
;; The counterpart of lazy.nvim's lazy-lock.json.  `lazyemacs-lock.eld' at the
;; root of the distribution records every installed package: its version and
;; archive, or for packages installed from Git (package-vc) the repository and
;; exact commit.  The file is plain Lisp data, sorted by name, so it can be
;; committed and reviewed like any other change.
;;
;; Nothing here runs automatically.  `SPC l u' upgrades packages and then
;; *offers* to record the result; `SPC l s' compares the lock with what is
;; installed; `SPC l r' moves Git packages back to their locked commits.
;;
;; Package archives (GNU ELPA, NonGNU ELPA, MELPA) publish only their newest
;; version, so an archive package that differs from the lock cannot be
;; downgraded.  Restore says so and leaves it installed instead of silently
;; replacing it with something else.
;;
;; Git metadata is read straight from each checkout's .git directory, so the
;; status report and the doctor never launch a process.  Only restore runs git.

;;; Code:

(require 'package)
(require 'seq)
(require 'subr-x)
(require 'init-distribution)

(declare-function package-vc-rebuild "package-vc")
(declare-function package-vc-install "package-vc")
(declare-function my/package-upgrade-all "init-packages")

(defcustom lazyemacs-lock-file
  (expand-file-name "lazyemacs-lock.eld"
                    (if (boundp 'lazyemacs-root-directory)
                        lazyemacs-root-directory
                      user-emacs-directory))
  "Package lockfile written by `lazyemacs-lock-write'."
  :type 'file :group 'lazyemacs)

;;; Git metadata without running git

(defun lazyemacs-lock--read-file (file)
  "Return FILE's trimmed contents, or nil when it is not readable."
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (string-trim (buffer-string)))))

(defun lazyemacs-lock--git-dir (directory)
  "Return the Git directory of the checkout at DIRECTORY, or nil.
Handles both a .git directory and a .git file pointing elsewhere."
  (let ((dot-git (expand-file-name ".git" directory)))
    (cond ((file-directory-p dot-git) dot-git)
          ((file-regular-p dot-git)
           (when-let* ((text (lazyemacs-lock--read-file dot-git))
                       ((string-match "\\`gitdir: *\\(.+\\)" text)))
             (expand-file-name (match-string 1 text) directory))))))

(defun lazyemacs-lock--git-common-dir (git-dir)
  "Return the directory holding shared refs and config for GIT-DIR."
  (if-let* ((common (lazyemacs-lock--read-file (expand-file-name "commondir" git-dir))))
      (expand-file-name common git-dir)
    git-dir))

(defun lazyemacs-lock--git-ref (git-dir ref)
  "Return the commit REF (such as refs/heads/main) names in GIT-DIR."
  (let ((common (lazyemacs-lock--git-common-dir git-dir)))
    (or (seq-some (lambda (dir) (lazyemacs-lock--read-file (expand-file-name ref dir)))
                  (delete-dups (list git-dir common)))
        (when-let* ((packed (lazyemacs-lock--read-file
                             (expand-file-name "packed-refs" common))))
          (when (string-match (format "^\\([0-9a-f]+\\) %s$" (regexp-quote ref)) packed)
            (match-string 1 packed))))))

(defun lazyemacs-lock-git-commit (directory)
  "Return the commit checked out in the Git repository at DIRECTORY, or nil."
  (when-let* ((git-dir (lazyemacs-lock--git-dir directory))
              (head (lazyemacs-lock--read-file (expand-file-name "HEAD" git-dir)))
              (commit (if (string-prefix-p "ref: " head)
                          (lazyemacs-lock--git-ref git-dir (string-trim (substring head 5)))
                        head)))
    (and (string-match-p "\\`[0-9a-f]\\{40,64\\}\\'" commit) commit)))

(defun lazyemacs-lock-git-url (directory)
  "Return the origin URL of the Git repository at DIRECTORY, or nil."
  (when-let* ((git-dir (lazyemacs-lock--git-dir directory))
              (config (expand-file-name "config" (lazyemacs-lock--git-common-dir git-dir)))
              ((file-readable-p config)))
    (with-temp-buffer
      (insert-file-contents config)
      (when (re-search-forward "^\\[remote \"origin\"\\]" nil t)
        (let ((end (save-excursion (if (re-search-forward "^\\[" nil t) (point) (point-max)))))
          (when (re-search-forward "^[ \t]*url[ \t]*=[ \t]*\\(.+?\\)[ \t]*$" end t)
            (lazyemacs-lock--public-url (match-string 1))))))))

(defun lazyemacs-lock--public-url (url)
  "Return URL in a form anyone can clone.
A checkout cloned over SSH (git@host:owner/repo.git) needs the cloner's key,
so the lockfile records the equivalent HTTPS address instead."
  (if (string-match "\\`[^@/]+@\\([^:/]+\\):\\(.+?\\)\\(?:\\.git\\)?\\'" url)
      (format "https://%s/%s" (match-string 1 url) (match-string 2 url))
    url))

;;; Lock entries

(defun lazyemacs-lock--plist (&rest pairs)
  "Return the property list PAIRS without properties whose value is nil."
  (let (plist)
    (while pairs
      (when (cadr pairs)
        (setq plist (append plist (list (car pairs) (cadr pairs)))))
      (setq pairs (cddr pairs)))
    plist))

(defun lazyemacs-lock--archive (desc)
  "Return the archive that provides installed package DESC, or nil.
Installed packages do not record their archive, so look for the archive
offering the same version, then the one package.el would prefer."
  (or (package-desc-archive desc)
      (let ((available (cdr (assq (package-desc-name desc) package-archive-contents))))
        (when-let* ((match (or (seq-find (lambda (candidate)
                                           (equal (package-desc-version candidate)
                                                  (package-desc-version desc)))
                                         available)
                               (car (seq-sort-by
                                     (lambda (candidate)
                                       (alist-get (package-desc-archive candidate)
                                                  package-archive-priorities 0 nil #'equal))
                                     #'> available)))))
          (package-desc-archive match)))))

(defun lazyemacs-lock--local-checkout (desc)
  "Return the external checkout DESC was installed from, if any.
`package-vc-install-from-checkout' links a developer's own working copy."
  (alist-get :vc-dir (package-desc-extras desc)))

(defun lazyemacs-lock-entry (desc)
  "Return the lock entry (NAME . PLIST) describing installed package DESC."
  (let ((name (package-desc-name desc))
        (version (package-version-join (package-desc-version desc)))
        (extras (package-desc-extras desc)))
    (cons name
          (if (eq (package-desc-kind desc) 'vc)
              (let ((dir (or (lazyemacs-lock--local-checkout desc) (package-desc-dir desc))))
                (lazyemacs-lock--plist
                 :version version
                 :vc (or (lazyemacs-lock-git-url dir) (alist-get :url extras) t)
                 :commit (or (lazyemacs-lock-git-commit dir) (alist-get :commit extras))))
            (lazyemacs-lock--plist :version version
                                   :archive (lazyemacs-lock--archive desc))))))

(defun lazyemacs-lock-installed (&optional alist)
  "Return lock entries for every package in ALIST (default `package-alist')."
  ;; The local archive cache lets entries name their archive.  Reading it never
  ;; touches the network.
  (when (and (null alist) (null package-archive-contents))
    (ignore-errors (package-read-all-archive-contents)))
  (seq-sort-by (lambda (entry) (symbol-name (car entry))) #'string<
               (mapcar (lambda (package) (lazyemacs-lock-entry (cadr package)))
                       (or alist package-alist))))

;;; Reading and writing the lockfile

(defconst lazyemacs-lock--header
  ";;; lazyemacs-lock.eld --- Installed package versions -*- mode: lisp-data; -*-
;; Written by `M-x lazyemacs-lock-write' (offered after SPC l u).  Commit it to
;; make an installation reproducible; SPC l r restores Git packages to these
;; commits.  Each entry is (NAME :version V [:archive A] [:vc URL :commit SHA]).
"
  "Comment written at the top of the lockfile.")

(defun lazyemacs-lock-format (entries)
  "Return the lockfile text for ENTRIES, one package per line."
  (let ((print-length nil) (print-level nil) (print-escape-newlines t))
    (concat lazyemacs-lock--header
            "("
            (mapconcat #'prin1-to-string entries "\n ")
            ")\n")))

(defun lazyemacs-lock-read (&optional file)
  "Return the entries recorded in FILE (default `lazyemacs-lock-file').
Return nil when the file does not exist."
  (let ((file (or file lazyemacs-lock-file)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (let ((data (condition-case err (read (current-buffer))
                      (error (user-error "Cannot read %s: %s" file (error-message-string err))))))
          (unless (and (listp data)
                       (seq-every-p (lambda (entry) (and (consp entry) (symbolp (car entry))
                                                         (plistp (cdr entry))))
                                    data))
            (user-error "%s is not a LazyEmacs lockfile" file))
          data)))))

(defun lazyemacs-lock-write (&optional file entries)
  "Record the installed packages in FILE (default `lazyemacs-lock-file').
ENTRIES defaults to `lazyemacs-lock-installed'.  Return the file name."
  (interactive)
  (let ((file (or file lazyemacs-lock-file))
        (entries (or entries (lazyemacs-lock-installed))))
    (with-temp-file file
      (insert (lazyemacs-lock-format entries)))
    (when (called-interactively-p 'interactive)
      (message "Locked %d packages in %s" (length entries) (abbreviate-file-name file)))
    file))

;;; Comparing the lock with installed packages

(defun lazyemacs-lock--same-p (locked installed)
  "Return non-nil when LOCKED and INSTALLED plists describe the same package."
  (if (or (plist-get locked :vc) (plist-get installed :vc))
      (and (plist-get locked :vc) (plist-get installed :vc)
           (equal (plist-get locked :commit) (plist-get installed :commit)))
    (equal (plist-get locked :version) (plist-get installed :version))))

(defun lazyemacs-lock-diff (locked installed)
  "Compare LOCKED with INSTALLED entries.
Return a sorted list of (STATUS NAME LOCKED-PLIST INSTALLED-PLIST) where
STATUS is `missing' (locked, not installed), `changed', or `extra' (installed,
not locked)."
  (let (differences)
    (pcase-dolist (`(,name . ,plist) locked)
      (let ((current (alist-get name installed)))
        (cond ((not (assq name installed)) (push (list 'missing name plist nil) differences))
              ((not (lazyemacs-lock--same-p plist current))
               (push (list 'changed name plist current) differences)))))
    (pcase-dolist (`(,name . ,plist) installed)
      (unless (assq name locked)
        (push (list 'extra name nil plist) differences)))
    (seq-sort-by (lambda (difference) (symbol-name (cadr difference))) #'string< differences)))

(defun lazyemacs-lock--describe (plist)
  "Return a short description of the package version in PLIST."
  (cond ((null plist) "-")
        ((plist-get plist :vc)
         (format "%s (git %s)" (plist-get plist :version)
                 (substring (or (plist-get plist :commit) "unknown") 0
                            (min 7 (length (or (plist-get plist :commit) "unknown"))))))
        (t (format "%s%s" (plist-get plist :version)
                   (if-let* ((archive (plist-get plist :archive))) (format " (%s)" archive) "")))))

(defun lazyemacs-lock-summary ()
  "Return a one-line comparison of the lockfile with installed packages."
  (if-let* ((locked (ignore-errors (lazyemacs-lock-read))))
      (let ((differences (lazyemacs-lock-diff locked (lazyemacs-lock-installed))))
        (if differences
            (format "%d difference%s from %s (SPC l s for details)"
                    (length differences) (if (cdr differences) "s" "")
                    (file-name-nondirectory lazyemacs-lock-file))
          (format "in sync (%d packages)" (length locked))))
    (format "no readable lockfile at %s (M-x lazyemacs-lock-write)"
            (abbreviate-file-name lazyemacs-lock-file))))

;;; Status buffer

(defvar-keymap lazyemacs-lock-mode-map
  :doc "Keys for `lazyemacs-lock-mode'."
  :parent special-mode-map
  "g" #'lazyemacs-lock-status
  "w" #'lazyemacs-lock-write-and-refresh
  "r" #'lazyemacs-lock-restore)

(define-derived-mode lazyemacs-lock-mode special-mode "Lock"
  "Major mode for the LazyEmacs package lock report."
  (setq-local truncate-lines t))

(defun lazyemacs-lock-status ()
  "Show how installed packages differ from the lockfile."
  (interactive)
  (let ((locked (lazyemacs-lock-read))
        (installed (lazyemacs-lock-installed))
        (buffer (get-buffer-create "*LazyEmacs Lock*")))
    (with-current-buffer buffer
      (lazyemacs-lock-mode)
      (let ((inhibit-read-only t)
            (differences (lazyemacs-lock-diff locked installed)))
        (erase-buffer)
        (insert (propertize "LazyEmacs package lock\n\n" 'face 'bold)
                (format "Lockfile:   %s%s\n" (abbreviate-file-name lazyemacs-lock-file)
                        (if (file-exists-p lazyemacs-lock-file) "" " (not written yet)"))
                (format "Locked:     %d packages\nInstalled:  %d packages\n"
                        (length locked) (length installed))
                (format "Status:     %s\n\n"
                        (if differences (format "%d differences" (length differences)) "in sync")))
        (when differences
          (insert (format "  %-8s %-28s %-28s %s\n" "" "Package" "Locked" "Installed"))
          (pcase-dolist (`(,status ,name ,lock ,current) differences)
            (insert (format "  %-8s %-28s %-28s %s\n" status name
                            (lazyemacs-lock--describe lock)
                            (lazyemacs-lock--describe current))))
          (insert "\n"))
        (insert (substitute-command-keys
                 "\\<lazyemacs-lock-mode-map>\\[lazyemacs-lock-write-and-refresh] record installed versions   \\[lazyemacs-lock-restore] restore Git packages   \\[lazyemacs-lock-status] refresh   \\[quit-window] quit\n"))
        (goto-char (point-min))))
    (pop-to-buffer buffer)
    buffer))

(defun lazyemacs-lock-write-and-refresh ()
  "Record installed packages in the lockfile after confirmation, then refresh."
  (interactive)
  (when (y-or-n-p (format "Overwrite %s with the installed versions? "
                          (file-name-nondirectory lazyemacs-lock-file)))
    (lazyemacs-lock-write)
    (lazyemacs-lock-status)))

;;; Restoring

(defun lazyemacs-lock--available (name version)
  "Return the archive description of NAME at VERSION, if an archive offers it."
  (seq-find (lambda (desc) (equal (package-version-join (package-desc-version desc)) version))
            (cdr (assq name package-archive-contents))))

(defun lazyemacs-lock-restore-plan (locked installed)
  "Return restore steps that bring INSTALLED back to LOCKED.
Each step is (ACTION NAME LOCKED-PLIST NOTE).  ACTION is `checkout' (move a
Git package to its locked commit), `vc-install', `install', or `keep' (no safe
way to restore; NOTE explains why)."
  (let (plan)
    (pcase-dolist (`(,status ,name ,lock ,current) (lazyemacs-lock-diff locked installed))
      (let ((desc (cadr (assq name package-alist))))
        (push
         (pcase status
           ('extra (list 'keep name lock "not in the lockfile; left installed (M-x package-delete removes it)"))
           ((guard (plist-get lock :vc))
            (cond ((not (stringp (plist-get lock :vc)))
                   (list 'keep name lock "the lockfile has no repository URL for it"))
                  ((eq status 'missing)
                   (list 'vc-install name lock (format "install %s at %s" (plist-get lock :vc)
                                                       (plist-get lock :commit))))
                  ((not (plist-get current :vc))
                   (list 'keep name lock "installed from an archive, locked from Git; reinstall it with package-vc-install"))
                  ((and desc (lazyemacs-lock--local-checkout desc))
                   (list 'keep name lock "linked to your own checkout; check out the commit there yourself"))
                  (t (list 'checkout name lock (format "check out %s" (plist-get lock :commit))))))
           ((guard (plist-get current :vc))
            (list 'keep name lock "installed from Git, locked from an archive; reinstall it with package-install"))
           (_
            (let ((available (lazyemacs-lock--available name (plist-get lock :version))))
              (cond ((and available (or (eq status 'missing)
                                        (version-list-< (version-to-list (plist-get current :version))
                                                        (version-to-list (plist-get lock :version)))))
                     (list 'install name lock (format "install %s from %s" (plist-get lock :version)
                                                      (package-desc-archive available))))
                    ((eq status 'missing)
                     (list 'keep name lock (format "archives no longer offer %s; install the current version with M-x package-install"
                                                   (plist-get lock :version))))
                    (t (list 'keep name lock
                             (format "ELPA archives keep only their newest release, so %s cannot be reinstalled; keeping %s"
                                     (plist-get lock :version) (plist-get current :version))))))))
         plan)))
    (nreverse plan)))

(defun lazyemacs-lock--git (directory &rest arguments)
  "Run git with ARGUMENTS in DIRECTORY; return its output or signal an error."
  (let ((default-directory (file-name-as-directory directory)))
    (with-temp-buffer
      (let ((status (apply #'process-file "git" nil t nil arguments)))
        (unless (eql status 0)
          (error "git %s failed in %s: %s" (string-join arguments " ")
                 directory (string-trim (buffer-string))))
        (string-trim (buffer-string))))))

(defun lazyemacs-lock-vc-checkout (directory commit)
  "Move the Git package checkout at DIRECTORY to COMMIT.
Fetch only when COMMIT is not already present.  On a branch, `reset --keep'
moves the branch (so later upgrades fast-forward from it) and refuses to
discard local edits; a detached checkout simply checks the commit out."
  (unless (ignore-errors (lazyemacs-lock--git directory "cat-file" "-e" (concat commit "^{commit}")))
    (lazyemacs-lock--git directory "fetch" "--quiet" "origin"))
  (if (ignore-errors (lazyemacs-lock--git directory "symbolic-ref" "-q" "HEAD"))
      (lazyemacs-lock--git directory "reset" "--quiet" "--keep" commit)
    (lazyemacs-lock--git directory "checkout" "--quiet" commit)))

(defun lazyemacs-lock--apply (step)
  "Carry out restore STEP; return a line describing the outcome."
  (pcase-let ((`(,action ,name ,lock ,note) step))
    (condition-case err
        (pcase action
          ('checkout
           (let ((desc (cadr (assq name package-alist))))
             (lazyemacs-lock-vc-checkout (package-desc-dir desc) (plist-get lock :commit))
             (require 'package-vc)
             (package-vc-rebuild desc)
             (format "restored  %s to %s" name (plist-get lock :commit))))
          ('vc-install
           (require 'package-vc)
           (package-vc-install (cons name (list :url (plist-get lock :vc))) (plist-get lock :commit))
           (format "installed %s at %s" name (plist-get lock :commit)))
          ('install
           (package-install (lazyemacs-lock--available name (plist-get lock :version)) t)
           (format "installed %s %s" name (plist-get lock :version)))
          (_ (format "kept      %s: %s" name note)))
      (error (format "FAILED    %s: %s" name (error-message-string err))))))

(defun lazyemacs-lock-restore ()
  "Bring installed packages back to the versions in the lockfile.
Git packages are checked out at their locked commits and rebuilt.  Archive
packages are only installed when an archive still offers the locked version;
everything else is listed and kept as installed.  Asks before changing
anything, and refuses while `lazyemacs-offline' is set."
  (interactive)
  (when lazyemacs-offline
    (user-error "Restoring packages needs the network; unset LAZYEMACS_OFFLINE and restart Emacs"))
  (let* ((locked (or (lazyemacs-lock-read)
                     (user-error "No lockfile at %s; write one with M-x lazyemacs-lock-write"
                                 (abbreviate-file-name lazyemacs-lock-file))))
         (plan (lazyemacs-lock-restore-plan locked (lazyemacs-lock-installed)))
         (actions (seq-remove (lambda (step) (eq (car step) 'keep)) plan)))
    (if (null plan)
        (message "Installed packages already match %s" (file-name-nondirectory lazyemacs-lock-file))
      (with-help-window "*LazyEmacs Restore*"
        (princ "Restore plan\n\n")
        (pcase-dolist (`(,action ,name ,_ ,note) plan)
          (princ (format "  %-10s %-28s %s\n" action name note)))
        (unless actions
          (princ "\nNothing can be restored automatically; installed packages are unchanged.\n")))
      (when (and actions
                 (yes-or-no-p (format "Apply %d restore step%s? Packages marked keep stay as installed. "
                                      (length actions) (if (cdr actions) "s" ""))))
        (let ((results (mapcar #'lazyemacs-lock--apply actions)))
          (when (fboundp 'package-quickstart-refresh)
            (package-quickstart-refresh))
          (with-help-window "*LazyEmacs Restore*"
            (princ "Restore results (restart Emacs to load restored packages)\n\n")
            (dolist (line results) (princ (concat "  " line "\n")))))))))

;;; Updating, the lazy.nvim way

(defun lazyemacs-update-packages ()
  "Upgrade all packages, show what changed, and offer to update the lockfile.
Nothing is written unless you confirm, so an unwanted upgrade can still be
undone with `lazyemacs-lock-restore' for Git packages."
  (interactive)
  (my/package-upgrade-all)
  (lazyemacs-lock-status)
  (when (and (lazyemacs-lock-diff (lazyemacs-lock-read) (lazyemacs-lock-installed))
             (y-or-n-p (format "Record the installed versions in %s? "
                               (file-name-nondirectory lazyemacs-lock-file))))
    (lazyemacs-lock-write)
    (lazyemacs-lock-status)))

;;; Doctor

(defun lazyemacs-lock-doctor-section ()
  "Print the lockfile summary for `lazyemacs-doctor'."
  (princ (format "\nPackage lockfile\n%s\n" (lazyemacs-lock-summary))))

(add-hook 'lazyemacs-doctor-sections #'lazyemacs-lock-doctor-section 10)

(provide 'init-lock)
;;; init-lock.el ends here
