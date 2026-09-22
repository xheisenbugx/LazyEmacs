;;; distribution-tests.el --- Public configuration contract -*- lexical-binding: t; -*-
(require 'ert)
(require 'cl-lib)
(require 'init-distribution)
(require 'init-package-policy)
(defvar lazyemacs-test-root
  (file-name-directory (directory-file-name (file-name-directory load-file-name))))
(ert-deftest lazyemacs/defaults-are-portable ()
  (should lazyemacs-enable-recovery)
  (should-not lazyemacs-enable-mail)
  (should (file-name-absolute-p lazyemacs-org-directory))
  (should (listp lazyemacs-fonts)))
(ert-deftest lazyemacs/user-files-are-optional-and-errors-are-visible ()
  (let ((lazyemacs-user-directory (make-temp-file "lazyemacs-user-" t)))
    (unwind-protect
        (progn
          (should-not (lazyemacs-load-user-file "missing.el"))
          (with-temp-file (expand-file-name "broken.el" lazyemacs-user-directory)
            (insert ";;; -*- lexical-binding: t; -*-\n(error \"user config failure\")"))
          (should-error (lazyemacs-load-user-file "broken.el")))
      (delete-directory lazyemacs-user-directory t))))
(ert-deftest lazyemacs/user-file-is-evaluated ()
  (let ((lazyemacs-user-directory (make-temp-file "lazyemacs-user-" t))
        (lazyemacs-font-height 140))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "early.el" lazyemacs-user-directory)
            (insert ";;; -*- lexical-binding: t; -*-\n(setq lazyemacs-font-height 120)"))
          (lazyemacs-load-user-file "early.el")
          (should (= lazyemacs-font-height 120)))
      (delete-directory lazyemacs-user-directory t))))
(ert-deftest lazyemacs/doctor-does-not-launch-tools ()
  (cl-letf (((symbol-function 'call-process) (lambda (&rest _) (ert-fail "Launched tool")))
            ((symbol-function 'start-process) (lambda (&rest _) (ert-fail "Launched tool"))))
    (lazyemacs-doctor)
    (with-current-buffer "*LazyEmacs Doctor*"
      (should (string-match-p "Recovery enabled" (buffer-string)))
      (should (string-match-p "Package network" (buffer-string)))
      (should (string-match-p "Grammar availability" (buffer-string))))))

(ert-deftest lazyemacs/offline-missing-packages-fail-before-network ()
  (let ((lazyemacs-offline t))
    (cl-letf (((symbol-function 'package-installed-p) (lambda (_) nil))
              ((symbol-function 'use-package-ensure-elpa)
               (lambda (&rest _) (ert-fail "Attempted installation"))))
      (should (string-match-p
               "Missing package imaginary"
               (error-message-string
                (should-error (lazyemacs-ensure-package 'imaginary '(t) nil)))))
      (should-error
       (lazyemacs-ensure-vc-package
        (lambda (&rest _) (ert-fail "Attempted VC installation"))
        '(imaginary (:url "https://example.invalid") nil))))))

(ert-deftest lazyemacs/offline-installed-packages-and-ensure-nil-work ()
  (let ((lazyemacs-offline t))
    (cl-letf (((symbol-function 'package-installed-p) (lambda (_) t)))
      (lazyemacs-ensure-package 'installed '(t) nil)
      (lazyemacs-ensure-package 'unmanaged '(nil) nil)
      (lazyemacs-ensure-vc-package #'use-package-vc-install
                                  '(installed (:url "https://example.invalid") nil)))))

(ert-deftest lazyemacs/offline-rejects-explicit-refresh-before-network ()
  (let ((lazyemacs-offline t))
    (cl-letf (((symbol-function 'url-retrieve-synchronously)
               (lambda (&rest _) (ert-fail "Attempted download"))))
      (should-error (package-refresh-contents) :type 'user-error)
      (should-error (package-install 'imaginary) :type 'user-error)
      (should-error (package-vc-upgrade 'imaginary) :type 'user-error))))

(ert-deftest lazyemacs/startup-failure-restores-gc-and-keeps-handlers ()
  (let ((gc-cons-threshold gc-cons-threshold)
        (gc-cons-percentage gc-cons-percentage)
        (file-name-handler-alist '(("test" . ignore)))
        (after-init-hook nil)
        (emacs-startup-hook nil))
    (load (expand-file-name "early-init.el" lazyemacs-test-root) nil t)
    (should (equal file-name-handler-alist '(("test" . ignore))))
    (should (= gc-cons-threshold most-positive-fixnum))
    (cl-letf (((symbol-function 'lazyemacs-load-user-file)
               (lambda (_) (error "Broken private configuration"))))
      (should-error (load (expand-file-name "init.el" lazyemacs-test-root) nil t)))
    (should (< gc-cons-threshold most-positive-fixnum))
    (should (= gc-cons-percentage 0.1))
    (should (equal file-name-handler-alist '(("test" . ignore))))))

(ert-run-tests-batch-and-exit "lazyemacs/")
