;;; evil-startup-tests.el --- Emacs 31 Evil startup regression -*- lexical-binding: t; -*-
(require 'ert)
(require 'evil)

(ert-deftest lazyemacs/evil-0-normal-post-command-after-major-mode-change ()
  ;; Loading init.el alone never runs the interactive post-command hook.
  (should (boundp 'evil-mode-buffers))
  (save-window-excursion
    (with-temp-buffer
      (switch-to-buffer (current-buffer))
      (insert "first line\nsecond line\n")
      (dolist (mode '(text-mode emacs-lisp-mode fundamental-mode))
        (funcall mode)
        (evil-local-mode 1)
        (evil-normal-state)
        (should-not (evil-initializing-p))
        (goto-char (point-min))
        (evil-normal-post-command)
        (execute-kbd-macro (kbd "j k"))
        (should (= (line-number-at-pos) 1))))))

(ert-deftest lazyemacs/evil-compat-preserves-existing-queue ()
  (let ((evil-mode-buffers (list (current-buffer))))
    (load "init-evil-compat" nil t)
    (should (equal evil-mode-buffers (list (current-buffer))))))

(ert-deftest lazyemacs/evil-compat-repairs-missing-queue ()
  (let ((previous evil-mode-buffers))
    (unwind-protect
        (progn
          (makunbound 'evil-mode-buffers)
          (load "init-evil-compat" nil t)
          (should (boundp 'evil-mode-buffers))
          (should-not evil-mode-buffers)
          (should-not (evil-initializing-p)))
      (setq evil-mode-buffers previous))))

(setq kill-emacs-hook nil)
(ert-run-tests-batch-and-exit "lazyemacs/evil-")
