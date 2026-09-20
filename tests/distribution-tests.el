;;; distribution-tests.el --- Public configuration contract -*- lexical-binding: t; -*-
(require 'ert)
(require 'cl-lib)
(require 'init-distribution)
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
  (cl-letf (((symbol-function 'call-process) (lambda (&rest _) (ert-fail "Launched tool"))))
    (lazyemacs-doctor)
    (with-current-buffer "*LazyEmacs Doctor*"
      (should (string-match-p "Recovery enabled" (buffer-string))))))
(ert-run-tests-batch-and-exit "lazyemacs/")
