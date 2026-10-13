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
       ;; Windows keeps a directory locked while a file-notify watch (Dired,
       ;; auto-revert) is open on it; a leftover temp directory is harmless.
       (when (fboundp 'file-notify-rm-all-watches) (file-notify-rm-all-watches))
       (ignore-error permission-denied (delete-directory ,directory t)))))

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

(ert-deftest my/audit-alt-space-leader-outside-insert-state ()
  (dolist (state '(normal emacs))
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

;;; Projects and tasks

(ert-deftest my/audit-repository-root-wins-and-tasks-use-nearest-manifest ()
  (my/audit-with-git-repo root
    (let* ((package (expand-file-name "packages/a/" root))
           (source (expand-file-name "src/" package)))
      (make-directory source t)
      (write-region "{\"scripts\": {\"build\": \"tsc\"}}" nil (expand-file-name "package.json" package))
      (write-region "{}" nil (expand-file-name "package.json" root))
      (let ((default-directory source))
        (should (file-equal-p (project-root (project-current)) root))
        (should (file-equal-p (my/task-root) package))
        (should (assoc "script: build" (my/task-choices (my/task-root)))))
      ;; Without a manifest below the repository root, tasks use the root.
      (make-directory (expand-file-name "docs/" root))
      (let ((default-directory (expand-file-name "docs/" root)))
        (should (file-equal-p (my/task-root) root)))))
  ;; Outside version control a manifest still defines the project.
  (let ((root (file-name-as-directory (make-temp-file "lazyemacs-audit-plain-" t))))
    (unwind-protect
        (let ((default-directory (expand-file-name "lib/" root)))
          (make-directory default-directory)
          (write-region "module x\n" nil (expand-file-name "go.mod" root))
          (should (file-equal-p (project-root (project-current)) root)))
      (ignore-error permission-denied (delete-directory root t)))))

(ert-deftest my/audit-go-nearest-test-on-its-own-line ()
  (let ((root (file-name-as-directory (make-temp-file "lazyemacs-audit-go-" t))))
    (unwind-protect
        (with-temp-buffer
          (setq buffer-file-name (expand-file-name "x_test.go" root))
          (setq-local major-mode 'go-mode)
          (insert "package x\n\nfunc TestOne(t *testing.T) {}\n\nfunc TestTwo(t *testing.T) {\n}\n")
          (goto-char (point-min))
          (search-forward "func TestTwo")
          (beginning-of-line)
          (should (string-match-p "TestTwo" (my/task-test-command root t)))
          (set-buffer-modified-p nil)
          (setq buffer-file-name nil))
      (ignore-error permission-denied (delete-directory root t)))))

;;; Editing

(ert-deftest my/audit-w-treats-camel-case-as-one-word ()
  (should-not (bound-and-true-p global-subword-mode))
  (save-window-excursion
    (with-temp-buffer
      (switch-to-buffer (current-buffer))
      (insert "fooBarBaz next")
      (goto-char (point-min))
      (evil-local-mode 1)
      (evil-normal-state)
      (execute-kbd-macro "w")
      (should (looking-at "next")))))

(ert-deftest my/audit-clipboard-is-chosen-per-frame ()
  (let (copied native)
    (cl-letf (((symbol-function 'my/clipboard-copy) (lambda (text) (setq copied text)))
              ((symbol-function 'my/clipboard-command) (lambda (_) '(pbcopy "pbcopy")))
              (my/clipboard-default-cut-function (lambda (text) (setq native text))))
      (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) nil)))
        (my/clipboard-cut "terminal"))
      (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t)))
        (my/clipboard-cut "graphical"))
      (should (equal copied "terminal"))
      (should (equal native "graphical")))))

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
      (ignore-error permission-denied (delete-directory directory t)))))

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
      (ignore-error permission-denied (delete-directory directory t)))))

;;; Folding and structural motions

(ert-deftest my/audit-folds-nest-and-answer-evil-z-commands ()
  (with-temp-buffer
    (insert "function outer() {\n  const a = 1;\n  if (a) {\n    call();\n  }\n  return a;\n}\n")
    (treesit-parser-create 'typescript)
    (my/fold-setup)
    (should my/structural-folding)
    (goto-char (point-min))
    (search-forward "call")
    (my/toggle-fold)
    (should (= 1 (length (my/structural-folds (point-min) (point-max)))))
    ;; Toggling the outer block keeps the folded inner block.
    (goto-char (point-min))
    (search-forward "const")
    (my/toggle-fold)
    (should (= 2 (length (my/structural-folds (point-min) (point-max)))))
    ;; za on the folded line opens that fold.
    (goto-char (point-min))
    (my/toggle-fold)
    (should (= 1 (length (my/structural-folds (point-min) (point-max)))))
    (evil-open-folds)
    (should-not (my/structural-folds (point-min) (point-max)))
    (evil-close-folds)
    (should (= 2 (length (my/structural-folds (point-min) (point-max)))))))

(ert-deftest my/audit-folding-without-parser-uses-evil-providers ()
  (require 'org)
  (with-temp-buffer
    (org-mode)
    (insert "* Heading\nbody\n* Next\n")
    (goto-char (point-min))
    (let (handler)
      (cl-letf (((symbol-function 'evil-fold-action)
                 (lambda (list action)
                   (setq handler (seq-find (lambda (entry) (evil--mode-p (car entry))) list))
                   (should (eq action :toggle)))))
        (my/toggle-fold))
      ;; Org keeps Evil's outline folding instead of gaining Hideshow.
      (should (memq 'org-mode (car handler))))
    (should-not (bound-and-true-p hs-minor-mode)))
  (with-temp-buffer
    (emacs-lisp-mode)
    (insert "(defun first ()\n  1)\n\n(defun second ()\n  2)\n")
    (should (bound-and-true-p hs-minor-mode))
    (goto-char (point-min))
    (my/next-function 1)
    (should (looking-at "(defun second"))
    (my/previous-function 1)
    (should (bobp))))

;;; Formatting, language servers and diagnostics

(ert-deftest my/audit-missing-formatter-falls-back-to-lsp-or-indent ()
  (require 'apheleia)
  (let ((apheleia-formatters (cons '(lazyemacs-fake . ("lazyemacs-no-such-formatter" "-"))
                                   apheleia-formatters)))
    (should-not (my/formatter-available-p 'lazyemacs-fake))
    (should (my/formatter-available-p 'lisp-indent))
    (with-temp-buffer
      (let ((lsp-managed-mode t) lsp-formatted indented)
        (cl-letf (((symbol-function 'my/project-formatter) #'ignore)
                  ((symbol-function 'apheleia--get-formatters) (lambda (&rest _) '(lazyemacs-fake)))
                  ((symbol-function 'apheleia-format-buffer) (lambda (&rest _) (ert-fail "Ran a missing formatter")))
                  ((symbol-function 'lsp-feature?) (lambda (_) t))
                  ((symbol-function 'lsp-format-buffer) (lambda () (setq lsp-formatted t)))
                  ((symbol-function 'indent-region) (lambda (&rest _) (setq indented t))))
          (my/format-buffer)
          (should lsp-formatted)
          (setq lsp-managed-mode nil)
          (my/format-buffer)
          (should indented))))))

(ert-deftest my/audit-json-without-grammar-uses-the-json-server ()
  (with-temp-buffer
    (delay-mode-hooks (js-json-mode))
    (cl-letf (((symbol-function 'executable-find)
               (lambda (name &rest _) (and (equal name "vscode-json-language-server") "/bin/json"))))
      (should (equal (my/language-server-available-p) "/bin/json"))))
  (should (memq #'my/lsp-ensure js-json-mode-hook)))

(ert-deftest my/audit-flycheck-for-elisp-files-without-checkdoc ()
  (require 'flycheck)
  (should (memq 'emacs-lisp-checkdoc flycheck-disabled-checkers))
  (let ((directory (make-temp-file "lazyemacs-audit-elisp-" t)))
    (unwind-protect
        (with-temp-buffer
          (setq buffer-file-name (expand-file-name "config.el" directory))
          (cl-letf (((symbol-function 'flycheck-buffer) #'ignore))
            (emacs-lisp-mode)
            (should flycheck-mode))
          (set-buffer-modified-p nil)
          (setq buffer-file-name nil))
      (ignore-error permission-denied (delete-directory directory t))))
  (with-temp-buffer
    (emacs-lisp-mode)
    (should-not (bound-and-true-p flycheck-mode))))

;;; Dashboard, recent files and history

(ert-deftest my/audit-remote-recent-files-are-never-probed ()
  (let ((recentf-list '("/scp:host:/srv/remote.txt" "/docker:box:/app/x.py"))
        (local (make-temp-file "lazyemacs-audit-recent-"))
        probed)
    (unwind-protect
        (progn
          (push local recentf-list)
          (cl-letf* ((original (symbol-function 'file-exists-p))
                     ((symbol-function 'file-exists-p)
                      (lambda (file)
                        (when (string-match-p "\\`/\\(?:scp\\|docker\\):" file)
                          (ert-fail (format "Probed remote file %s" file)))
                        (push file probed)
                        (funcall original file)))
                     ((symbol-function 'file-in-directory-p)
                      (lambda (file &rest _)
                        (when (file-remote-p file) (ert-fail "Resolved a remote file"))
                        nil))
                     ((symbol-function 'consult-recent-file) #'ignore))
            (with-current-buffer (lazyemacs-dashboard-buffer)
              (unwind-protect
                  (progn
                    (should (string-match-p "remote.txt" (buffer-string)))
                    (should (member local probed)))
                (kill-buffer)))
            (let ((default-directory temporary-file-directory))
              (my/recent-files-cwd))))
      (delete-file local))))

(ert-deftest my/audit-dashboard-redraws-only-for-width-and-keeps-line ()
  (save-window-excursion
    (let ((recentf-list nil) renders)
      (switch-to-buffer (lazyemacs-dashboard-buffer))
      (lazyemacs-dashboard--render)
      (forward-line 12)
      (set-window-point (selected-window) (point))
      (let ((line (line-number-at-pos)))
        (advice-add 'lazyemacs-dashboard--render :before (lambda (&rest _) (push t renders))
                    '((name . audit-spy)))
        (unwind-protect
            (progn
              (lazyemacs-dashboard--resize (selected-window))
              (should-not renders)
              (setq lazyemacs-dashboard--width 1)
              (lazyemacs-dashboard--resize (selected-window))
              (should renders)
              (should (= line (line-number-at-pos (window-point)))))
          (advice-remove 'lazyemacs-dashboard--render 'audit-spy)
          (kill-buffer))))))

(ert-deftest my/audit-dashboard-q-closes-client-frames-only ()
  (should (eq (keymap-lookup lazyemacs-dashboard-mode-map "q") #'save-buffers-kill-terminal)))

(ert-deftest my/audit-kill-ring-is-not-written-to-disk ()
  (should-not (memq 'kill-ring savehist-additional-variables)))

;;; Packages and option names

(ert-deftest my/audit-upgrade-all-leaves-built-in-packages-alone ()
  (let (built-in quickstart said)
    (cl-letf (((symbol-function 'package-upgrade-all)
               (lambda (&rest _) (setq built-in package-install-upgrade-built-in)))
              ((symbol-function 'package-quickstart-refresh) (lambda () (setq quickstart t)))
              ((symbol-function 'message) (lambda (format &rest args) (setq said (apply #'format format args)))))
      (should package-install-upgrade-built-in)
      (my/package-upgrade-all)
      (should-not built-in)
      (should quickstart)
      (should (string-match-p "restart" said)))))

(ert-deftest my/audit-org-disputed-keys-are-set-before-org-loads ()
  (require 'org)
  (should org-replace-disputed-keys)
  (should (eq (keymap-lookup org-mode-map "S-<up>") nil)))

(ert-deftest my/audit-current-option-names ()
  (require 'tramp)
  (require 'tramp-sh)
  (should (eq tramp-use-connection-share t))
  (should-not native-comp-jit-compilation))

(setq kill-emacs-hook nil)
(ert-run-tests-batch-and-exit "my/audit-")
