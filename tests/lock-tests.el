;;; lock-tests.el --- Package lockfile and doctor sections -*- lexical-binding: t; -*-
;; Every test uses temporary directories and fake package descriptions; none
;; touches the shared elpa/ directory or the committed lockfile.
(require 'ert)
(require 'cl-lib)
(require 'init-lock)

(defun lazyemacs-lock-test--git (directory &rest arguments)
  "Run git ARGUMENTS in DIRECTORY for test setup and return its output."
  (let ((default-directory (file-name-as-directory directory)))
    (with-temp-buffer
      (unless (eql 0 (apply #'call-process "git" nil t nil
                            "-c" "user.name=Test" "-c" "user.email=test@example.invalid"
                            "-c" "commit.gpgsign=false" "-c" "init.defaultBranch=main"
                            arguments))
        (error "git %S failed: %s" arguments (buffer-string)))
      (string-trim (buffer-string)))))

(defun lazyemacs-lock-test--repo ()
  "Create a temporary Git repository with two commits; return (DIR FIRST SECOND)."
  (let ((dir (make-temp-file "lazyemacs-lock-repo-" t)))
    (lazyemacs-lock-test--git dir "init" "--quiet")
    (lazyemacs-lock-test--git dir "remote" "add" "origin" "git@example.com:owner/repo.git")
    (write-region "one\n" nil (expand-file-name "file.el" dir))
    (lazyemacs-lock-test--git dir "add" ".")
    (lazyemacs-lock-test--git dir "commit" "--quiet" "-m" "one")
    (let ((first (lazyemacs-lock-test--git dir "rev-parse" "HEAD")))
      (write-region "two\n" nil (expand-file-name "file.el" dir))
      (lazyemacs-lock-test--git dir "commit" "--quiet" "-am" "two")
      (list dir first (lazyemacs-lock-test--git dir "rev-parse" "HEAD")))))

(defun lazyemacs-lock-test--alist (vc-dir)
  "Return a fake `package-alist' with two archive packages and a VC one in VC-DIR."
  (list (list 'zeta (package-desc-create :name 'zeta :version '(2 0) :archive "melpa"))
        (list 'alpha (package-desc-create :name 'alpha :version '(1 2 3) :archive "gnu"))
        (list 'vcpkg (package-desc-create :name 'vcpkg :version '(0 1) :kind 'vc :dir vc-dir))))

(ert-deftest lazyemacs-lock/git-metadata-read-without-git ()
  (pcase-let ((`(,dir ,_first ,second) (lazyemacs-lock-test--repo)))
    (unwind-protect
        (progn
          (should (equal (lazyemacs-lock-git-commit dir) second))
          (should (equal (lazyemacs-lock-git-url dir) "https://example.com/owner/repo"))
          ;; Packed refs (after git gc) resolve too.
          (lazyemacs-lock-test--git dir "pack-refs" "--all")
          (should (equal (lazyemacs-lock-git-commit dir) second))
          (should-not (lazyemacs-lock-git-commit temporary-file-directory)))
      (delete-directory dir t))))

(ert-deftest lazyemacs-lock/write-read-round-trip-is-sorted ()
  (pcase-let* ((`(,dir ,_first ,second) (lazyemacs-lock-test--repo))
               (file (make-temp-file "lazyemacs-lock-" nil ".eld")))
    (unwind-protect
        (let ((entries (lazyemacs-lock-installed (lazyemacs-lock-test--alist dir))))
          (should (equal (mapcar #'car entries) '(alpha vcpkg zeta)))
          (should (equal (alist-get 'alpha entries) '(:version "1.2.3" :archive "gnu")))
          (should (equal (alist-get 'vcpkg entries)
                         `(:version "0.1" :vc "https://example.com/owner/repo" :commit ,second)))
          (lazyemacs-lock-write file entries)
          (should (equal (lazyemacs-lock-read file) entries))
          (with-temp-buffer
            (insert-file-contents file)
            (should (looking-at-p ";;; lazyemacs-lock.eld"))
            ;; One package per line keeps diffs reviewable.
            (should (search-forward "\n (vcpkg " nil t))))
      (delete-directory dir t)
      (delete-file file))))

(ert-deftest lazyemacs-lock/diff-reports-missing-changed-and-extra ()
  (let ((locked '((alpha :version "1.0" :archive "gnu")
                  (gone :version "3.0" :archive "gnu")
                  (same :version "1.0")
                  (vcpkg :version "0.1" :vc "https://x" :commit "aaa")))
        (installed '((alpha :version "1.1" :archive "gnu")
                     (new :version "1.0")
                     (same :version "1.0")
                     (vcpkg :version "0.1" :vc "https://x" :commit "bbb"))))
    (should (equal (mapcar (lambda (d) (list (car d) (cadr d)))
                           (lazyemacs-lock-diff locked installed))
                   '((changed alpha) (missing gone) (extra new) (changed vcpkg))))
    (should-not (lazyemacs-lock-diff locked locked))))

(ert-deftest lazyemacs-lock/restore-refuses-offline-and-never-downgrades-silently ()
  (let ((lazyemacs-offline t))
    (cl-letf (((symbol-function 'process-file) (lambda (&rest _) (ert-fail "Ran git")))
              ((symbol-function 'package-install) (lambda (&rest _) (ert-fail "Installed"))))
      (should (string-match-p "LAZYEMACS_OFFLINE"
                              (cadr (should-error (lazyemacs-lock-restore) :type 'user-error))))))
  (let* ((package-alist nil) (package-archive-contents nil)
         (plan (lazyemacs-lock-restore-plan
                '((alpha :version "1.0" :archive "gnu")
                  (vcpkg :version "0.1" :vc "https://x" :commit "aaa"))
                '((alpha :version "1.1" :archive "gnu")
                  (vcpkg :version "0.1" :vc "https://x" :commit "bbb")))))
    (should (string-match-p "newest release" (nth 3 (seq-find (lambda (s) (eq (cadr s) 'alpha)) plan))))
    (should (eq (car (seq-find (lambda (s) (eq (cadr s) 'vcpkg)) plan)) 'checkout))))

(ert-deftest lazyemacs-lock/vc-checkout-moves-branch-to-locked-commit ()
  (pcase-let ((`(,dir ,first ,_second) (lazyemacs-lock-test--repo)))
    (unwind-protect
        (progn
          (lazyemacs-lock-vc-checkout dir first)
          (should (equal (lazyemacs-lock-git-commit dir) first))
          ;; Still on the branch, so a later upgrade can fast-forward.
          (should (equal (lazyemacs-lock-test--git dir "symbolic-ref" "--short" "HEAD") "main"))
          (with-temp-buffer
            (insert-file-contents (expand-file-name "file.el" dir))
            (should (equal (buffer-string) "one\n"))))
      (delete-directory dir t))))

;; Defined by other modules when their features are loaded.
(defvar lazyemacs-sesh-directory)
(defvar lazyemacs-failed-modules)

(ert-deftest lazyemacs-lock/doctor-sections-render-without-processes ()
  (let* ((sessions (make-temp-file "lazyemacs-sesh-" t))
         (lazyemacs-sesh-directory sessions)
         (lazyemacs-lock-file (expand-file-name "missing-lock.eld" sessions))
         (lazyemacs-failed-modules '((init-broken error "boom"))))
    (unwind-protect
        (progn
          (write-region (number-to-string (emacs-pid)) nil (expand-file-name "mine.lock" sessions))
          (write-region "999999999" nil (expand-file-name "old.lock" sessions))
          (cl-letf (((symbol-function 'call-process) (lambda (&rest _) (ert-fail "Launched tool")))
                    ((symbol-function 'process-file) (lambda (&rest _) (ert-fail "Launched tool")))
                    ((symbol-function 'start-process) (lambda (&rest _) (ert-fail "Launched tool"))))
            (lazyemacs-doctor))
          (with-current-buffer "*LazyEmacs Doctor*"
            (let ((text (buffer-string)))
              (dolist (heading '("Failed modules: init-broken (boom)"
                                 "Language tooling" "Python" "Package lockfile"
                                 "no readable lockfile" "Extras" "Session locks"
                                 "this Emacs" "STALE"))
                (should (string-search heading text))))))
      (delete-directory sessions t))))

(setq kill-emacs-hook nil)
(ert-run-tests-batch-and-exit "lazyemacs-lock/")
