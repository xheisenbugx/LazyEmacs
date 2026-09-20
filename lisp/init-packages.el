;;; init-packages.el --- Package archives and use-package -*- lexical-binding: t; -*-

;;; Commentary:
;; package.el is intentionally used instead of a second package manager.  It is
;; built into Emacs, works well with use-package, and keeps this configuration
;; easy to understand and repair from `M-x list-packages'.

;;; Code:

(require 'package)

(defun my/disable-automatic-native-compilation ()
  "Disable every automatic native-compilation entry point.

This is repeated here in addition to early-init.el so the protection remains
active when init.el is loaded directly, reloaded, or used by a daemon/client
workflow.  Explicit `native-compile' calls remain available."
  (setq native-comp-jit-compilation nil
        native-comp-deferred-compilation nil
        native-comp-enable-subr-trampolines nil
        package-native-compile nil))

(my/disable-automatic-native-compilation)

;; Loading comp.el declares some of these variables.  Reapply the policy after
;; that library loads so no package can restore its defaults as a side effect.
(with-eval-after-load 'comp
  (my/disable-automatic-native-compilation))

(defun my/package--quiet-quickstart-refresh (original-function &rest arguments)
  "Call ORIGINAL-FUNCTION with ARGUMENTS without generated-autoload noise.

The quickstart file concatenates package autoloads, so its byte compiler cannot
see definitions that will exist when those packages load.  Suppress only those
`free-vars', `unresolved', and `make-local' false positives; all other
byte-compiler warnings and every warning from hand-written configuration remain
visible."
  ;; package-quickstart.el writes its own safe file-local warning value, which
  ;; would otherwise override the narrow setting below.  Temporarily stop only
  ;; that variable from being accepted as file-local while this generated file
  ;; is compiled.  Restore the normal safety predicate immediately afterward.
  (let ((byte-compile-warnings '(not free-vars unresolved make-local))
        (safe-predicate (get 'byte-compile-warnings 'safe-local-variable)))
    (unwind-protect
        (progn
          (put 'byte-compile-warnings 'safe-local-variable nil)
          (apply original-function arguments))
      (put 'byte-compile-warnings 'safe-local-variable safe-predicate))))

(unless (advice-member-p #'my/package--quiet-quickstart-refresh
                         #'package-quickstart-refresh)
  (advice-add #'package-quickstart-refresh :around
              #'my/package--quiet-quickstart-refresh))

;; `no-littering' normally relocates this cache, but it cannot do so until
;; after package.el has initialized.  Choose the final location up front so
;; every startup can load the quickstart cache instead of scanning all package
;; directories, and so newly installed packages are immediately on `load-path'.
(setq package-quickstart-file
      (locate-user-emacs-file "var/package-quickstart.el"))

;; GNU and NonGNU ELPA are preferred for stable releases.  MELPA supplies the
;; actively developed packages that are not published in those archives.
(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/"))
      package-archive-priorities
      '(("gnu" . 3)
        ("nongnu" . 2)
        ("melpa" . 1))
      package-install-upgrade-built-in t
      package-native-compile nil
      package-quickstart t)

;; early-init.el disables automatic initialization, so do it exactly once here.
(package-initialize)

;; Fresh installations need archive metadata before :ensure can resolve packages.
(unless package-archive-contents
  (package-refresh-contents))
(require 'use-package)

(setq use-package-always-ensure t
      use-package-compute-statistics nil
      use-package-expand-minimally t
      use-package-enable-imenu-support t)

;; Load no-littering before packages choose locations for caches and state.
;; Backups and auto-saves themselves are configured in init-core.el.
(use-package no-littering
  :demand t)

(defun my/package-refresh ()
  "Refresh package metadata and the quickstart cache without native compilers."
  (interactive)
  ;; Dynamic bindings make this safe even if package.el or Customize changed a
  ;; global value earlier in the session.
  (let ((package-native-compile nil)
        (native-comp-jit-compilation nil)
        (native-comp-deferred-compilation nil)
        (native-comp-enable-subr-trampolines nil))
    (package-refresh-contents)
    (when (fboundp 'package-quickstart-refresh)
      (package-quickstart-refresh))))

(defun my/package-upgrade-all ()
  "Refresh and upgrade packages without launching native compilers."
  (interactive)
  (let ((package-native-compile nil)
        (native-comp-jit-compilation nil)
        (native-comp-deferred-compilation nil)
        (native-comp-enable-subr-trampolines nil))
    (package-refresh-contents)
    (package-upgrade-all)
    (when (fboundp 'package-quickstart-refresh)
      (package-quickstart-refresh))))

(provide 'init-packages)
;;; init-packages.el ends here
