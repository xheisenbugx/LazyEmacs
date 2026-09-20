;;; local-actions-tests.el --- Local action transitions -*- lexical-binding: t; -*-
(require 'ert)
(require 'grep)
(require 'replace)

(ert-deftest my/local-actions-grep-keeps-evil-motions ()
  (with-temp-buffer
    (grep-mode)
    (evil-local-mode 1)
    (evil-normal-state)
    (evil-normalize-keymaps)
    (should (eq (key-binding (kbd "e")) #'evil-forward-word-end))
    (should (eq (key-binding (kbd "\\ e")) #'my/local-actions-edit))
    (should (eq (key-binding (kbd "i")) #'my/local-actions-edit))
    (my/local-actions-edit)
    (should (eq major-mode 'grep-edit-mode))
    (should (eq evil-state 'normal))
    (should (eq (key-binding (kbd "i")) #'evil-insert))
    (should (eq (key-binding (kbd "\\ c")) #'my/local-actions-finish))
    (should-error (my/local-actions-refresh) :type 'user-error)
    (my/local-actions-finish)
    (should (eq major-mode 'grep-mode))
    (should (eq (key-binding (kbd "\\ e")) #'my/local-actions-edit))))

(ert-deftest my/local-actions-occur-roundtrip ()
  (with-temp-buffer
    (occur-mode)
    (evil-local-mode 1)
    (evil-normal-state)
    (my/local-actions-edit)
    (should (eq major-mode 'occur-edit-mode))
    (should (eq (key-binding (kbd "\\ c")) #'my/local-actions-finish))
    (my/local-actions-finish)
    (should (eq major-mode 'occur-mode))
    (should my/local-actions-mode)))

(ert-deftest my/local-actions-dired-roundtrip ()
  (let* ((directory (make-temp-file "local-actions-" t))
         (buffer (dired-noselect directory)))
    (unwind-protect
        (with-current-buffer buffer
          (evil-local-mode 1)
          (evil-normal-state)
          (my/local-actions-edit)
          (should (eq major-mode 'wdired-mode))
          (should (eq (key-binding (kbd "\\ c")) #'my/local-actions-finish))
          (my/local-actions-finish)
          (should (eq major-mode 'dired-mode)))
      (kill-buffer buffer)
      (delete-directory directory t))))

(ert-deftest my/local-actions-does-not-claim-other-buffers ()
  (with-temp-buffer
    (fundamental-mode)
    (should-not my/local-actions-mode)
    (should-error (my/local-actions-edit) :type 'user-error)))

(setq kill-emacs-hook nil)
(ert-run-tests-batch-and-exit "my/local-actions-")
