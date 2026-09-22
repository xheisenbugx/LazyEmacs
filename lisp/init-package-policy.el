;;; init-package-policy.el --- Explicit package network policy -*- lexical-binding: t; -*-
;;; Commentary:
;; Installed configurations must be usable and testable without network access.
;;; Code:
(require 'package)
(require 'use-package)
(require 'use-package-ensure)
(require 'init-distribution)

(defun lazyemacs-package-network-check (&rest _)
  "Refuse package network operations when `lazyemacs-offline' is enabled."
  (when lazyemacs-offline
    (user-error "Package management is offline; unset LAZYEMACS_OFFLINE and restart to install or update")))

(defun lazyemacs-ensure-package (name args state &optional no-refresh)
  "Ensure NAME with ARGS and STATE, checking offline prerequisites first.
NO-REFRESH is passed through to use-package."
  (when lazyemacs-offline
    (dolist (ensure args)
      (let ((package (if (eq ensure t) name ensure)))
        (when (consp package) (setq package (car package)))
        (when (and package (not (package-installed-p package)))
          (error "Missing package %s in offline mode; launch once with LAZYEMACS_OFFLINE unset" package)))))
  (use-package-ensure-elpa name args state no-refresh))

(defun lazyemacs-ensure-vc-package (original spec &optional local-path)
  "Check offline prerequisites before ORIGINAL installs SPEC from LOCAL-PATH."
  (when (and lazyemacs-offline (not (package-installed-p (car spec))))
    (error "Missing VC package %s in offline mode; launch once with LAZYEMACS_OFFLINE unset" (car spec)))
  (funcall original spec local-path))

(setq use-package-ensure-function #'lazyemacs-ensure-package)
(advice-add 'use-package-vc-install :around #'lazyemacs-ensure-vc-package)
(dolist (command '(package-refresh-contents package-install package-vc-install
                   package-upgrade-all package-vc-upgrade package-vc-upgrade-all))
  (advice-add command :before #'lazyemacs-package-network-check))

(provide 'init-package-policy)
;;; init-package-policy.el ends here
