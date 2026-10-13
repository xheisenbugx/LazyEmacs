;;; audit-regression-tests.el --- Regressions found by the configuration audit -*- lexical-binding: t; -*-
(require 'ert)
(require 'cl-lib)

(defvar lsp-managed-mode)

;;; Keymap precedence: mode-local keys beat LazyEmacs's global Evil keys

(defmacro my/audit-with-git-repo (directory &rest body)
  "Run BODY with DIRECTORY bound to a fresh Git repository."
  (declare (indent 1))
  `(let ((,directory (file-name-as-directory (make-temp-file "lazyemacs-audit-git-" t))))
     (unwind-protect
         (let ((default-directory ,directory))
           (call-process "git" nil nil nil "init" "-q")
           ,@body)
       (delete-directory ,directory t))))

(ert-deftest my/audit-magit-keeps-its-own-keys ()
  (require 'magit)
  (my/audit-with-git-repo root
    (write-region "x" nil (expand-file-name "a.txt" root))
    (let ((buffer (magit-status-setup-buffer root)))
      (unwind-protect
          (with-current-buffer buffer
            (should (eq evil-state 'normal))
            (should (memq (key-binding "s") '(magit-stage magit-stage-file magit-stage-files magit-stage-dwim)))
            (should (eq (key-binding "f") #'magit-fetch))
            (should (eq (key-binding "F") #'magit-pull))
            (should (eq (key-binding (kbd "gr")) #'magit-refresh)))
        (let ((magit-buffer (get-buffer buffer)))
          (when magit-buffer (kill-buffer magit-buffer)))))))

(ert-deftest my/audit-dired-keeps-refresh-and-marks ()
  (my/audit-with-git-repo root
    (let ((buffer (dired-noselect root)))
      (unwind-protect
          (with-current-buffer buffer
            (evil-normal-state)
            (should (memq (key-binding (kbd "gr")) '(revert-buffer dired-do-redisplay)))
            (should-not (eq (key-binding "t") #'flash-char-find-to))
            (should-not (eq (key-binding "s") #'flash-evil-jump)))
        (kill-buffer buffer)))))

(ert-deftest my/audit-ctrl-h-is-help-while-typing-and-windows-in-normal ()
  (with-temp-buffer
    (fundamental-mode)
    (evil-local-mode 1)
    (evil-insert-state)
    (should-not (eq (key-binding (kbd "C-h")) #'windmove-left))
    (should (memq (key-binding (kbd "C-h f")) '(helpful-callable describe-function)))
    (evil-emacs-state)
    (should (memq (key-binding (kbd "C-h f")) '(helpful-callable describe-function)))
    (evil-normal-state)
    (should (eq (key-binding (kbd "C-h")) #'windmove-left))))

(ert-deftest my/audit-flash-and-code-keys-in-ordinary-buffers ()
  (dolist (mode '(fundamental-mode prog-mode))
    (with-temp-buffer
      (funcall mode)
      (evil-local-mode 1)
      (evil-normal-state)
      (should (eq (key-binding "s") #'flash-evil-jump))
      (should (eq (key-binding (kbd "gr")) #'my/lsp-find-references))
      (should (eq (key-binding (kbd "gd")) #'my/lsp-find-definitions))
      (should (eq (key-binding (kbd "gi")) #'evil-insert-resume))
      (should (eq (key-binding (kbd "]e")) #'my/next-error-diagnostic))
      (should (eq (key-binding (kbd "]q")) #'next-error))
      (should (eq (key-binding "K") #'evil-lookup)))))

(ert-deftest my/audit-alt-space-leader-in-every-state ()
  (dolist (state '(normal insert emacs))
    (with-temp-buffer
      (special-mode)
      (evil-local-mode 1)
      (evil-change-state state)
      (should (eq (key-binding (kbd "M-SPC f f")) #'project-find-file)))))

(ert-deftest my/audit-k-asks-for-fresh-documentation ()
  (should (eq evil-lookup-func #'my/show-documentation))
  (with-temp-buffer
    (fundamental-mode)
    (let (forced)
      (cl-letf (((symbol-function 'eldoc-print-current-symbol-info)
                 (lambda (&optional interactive) (setq forced interactive))))
        (my/show-documentation)
        (should forced))))
  (require 'helpful)
  (with-temp-buffer
    (emacs-lisp-mode)
    (insert "car")
    (goto-char (point-min))
    (let (described)
      (cl-letf (((symbol-function 'helpful-symbol) (lambda (symbol) (setq described symbol))))
        (my/show-documentation)
        (should (eq described 'car)))))
  (with-temp-buffer
    (let ((lsp-managed-mode t) hovered)
      (cl-letf (((symbol-function 'lsp-feature?) (lambda (method) (equal method "textDocument/hover")))
                ((symbol-function 'lsp-describe-thing-at-point) (lambda () (setq hovered t))))
        (my/show-documentation)
        (should hovered)))))

;;; Completion

(ert-deftest my/audit-corfu-return-inserts-only-a-selected-candidate ()
  (require 'corfu)
  (with-temp-buffer
    ;; Stand-in for Corfu's transient keymap, above the global map.
    (use-local-map corfu-map)
    (let ((corfu--index -1))
      ;; Without a selection RET reaches the ordinary newline command.
      (should (eq (key-binding (kbd "RET")) #'newline)))
    (let ((corfu--index 0))
      (should (eq (key-binding (kbd "RET")) #'corfu-insert)))))

;;; Startup robustness

(ert-deftest my/audit-failed-module-is-reported-and-skipped ()
  (let* ((directory (make-temp-file "lazyemacs-audit-modules-" t))
         (load-path (cons directory load-path))
         (lazyemacs-strict-modules nil)
         (lazyemacs-failed-modules nil)
         (debug-on-error nil)
         warnings)
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "lazyemacs-audit-broken.el" directory)
            (insert ";;; -*- lexical-binding: t; -*-\n(error \"broken module\")\n"))
          (with-temp-file (expand-file-name "lazyemacs-audit-fine.el" directory)
            (insert ";;; -*- lexical-binding: t; -*-\n(provide 'lazyemacs-audit-fine)\n"))
          (cl-letf (((symbol-function 'display-warning)
                     (lambda (&rest args) (push args warnings))))
            (should-not (lazyemacs-require-module 'lazyemacs-audit-broken))
            (should (lazyemacs-require-module 'lazyemacs-audit-fine)))
          (should (equal (mapcar #'car lazyemacs-failed-modules) '(lazyemacs-audit-broken)))
          (should (= 1 (length warnings)))
          (let ((recentf-list nil))
            (with-current-buffer (lazyemacs-dashboard-buffer)
              (unwind-protect
                  (should (string-match-p "Failed to load: lazyemacs-audit-broken" (buffer-string)))
                (kill-buffer))))
          (lazyemacs-doctor)
          (with-current-buffer "*LazyEmacs Doctor*"
            (should (string-match-p "Failed modules: lazyemacs-audit-broken" (buffer-string))))
          ;; Batch runs stay strict, so CI and tests still fail loudly.
          (let ((lazyemacs-strict-modules t))
            (should-error (lazyemacs-require-module 'lazyemacs-audit-broken))))
      (delete-directory directory t))))

(defun my/audit-run-init (user-directory form)
  "Start a disposable Emacs using USER-DIRECTORY, evaluate FORM, return output."
  (let ((process-environment
         (append (list (concat "LAZYEMACS_USER_DIR=" user-directory) "LAZYEMACS_OFFLINE=1")
                 process-environment))
        (root lazyemacs-root-directory))
    (with-temp-buffer
      (call-process
       (expand-file-name invocation-name invocation-directory) nil t nil
       "-Q" "--batch"
       "--eval" (prin1-to-string
                 `(setq user-emacs-directory ,(file-name-as-directory user-directory)
                        package-user-dir ,(expand-file-name "elpa" root)))
       "--load" (expand-file-name "early-init.el" root)
       "--load" (expand-file-name "init.el" root)
       "--eval" (prin1-to-string `(princ (format "RESULT:%S" ,form))))
      (goto-char (point-min))
      (and (re-search-forward "RESULT:\\(.*\\)" nil t) (read (match-string 1))))))

(ert-deftest my/audit-customize-wins-over-module-defaults ()
  ;; init-completion sets corfu-cycle to t with use-package :custom.
  (let ((directory (make-temp-file "lazyemacs-audit-custom-" t)))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "custom.el" directory)
            (insert ";;; -*- lexical-binding: t; -*-\n(custom-set-variables '(corfu-cycle nil))\n"))
          (should (equal (my/audit-run-init directory '(list :cycle corfu-cycle)) '(:cycle nil))))
      (delete-directory directory t))))

(setq kill-emacs-hook nil)
(ert-run-tests-batch-and-exit "my/audit-")
