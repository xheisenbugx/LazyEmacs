;;; bootstrap.el --- Install LazyEmacs packages without opening a frame -*- lexical-binding: t; -*-

;;; Commentary:
;; Run from the checkout that Emacs will use as its init directory:
;;
;;   emacs --batch --load scripts/bootstrap.el              # packages only
;;   emacs --batch --load scripts/bootstrap.el --grammars   # plus tree-sitter grammars
;;
;; This performs the downloads that the first interactive launch would do, so
;; that launch is fast and any network or compiler problem is reported in the
;; terminal.  It installs into this checkout's elpa/ and var/ directories and
;; never touches another Emacs configuration.

;;; Code:

(let* ((root (file-name-directory
              (directory-file-name (file-name-directory load-file-name))))
       (grammars (member "--grammars" command-line-args-left)))
  ;; Emacs would otherwise reject the flag as an unknown option.
  (setq command-line-args-left (delete "--grammars" command-line-args-left))
  (when (equal (getenv "LAZYEMACS_OFFLINE") "1")
    (error "Unset LAZYEMACS_OFFLINE to bootstrap; installation needs the network"))
  ;; package.el computed its directories from the default init directory
  ;; before this script ran; point every one of them at the checkout.
  (setq user-emacs-directory root
        package-user-dir (expand-file-name "elpa" root)
        package-gnupghome-dir (expand-file-name "elpa/gnupg" root))
  (message "Installing LazyEmacs packages into %selpa/ ..." root)
  (load (expand-file-name "early-init.el" root) nil t)
  (load (expand-file-name "init.el" root) nil t)
  (when (fboundp 'package-quickstart-refresh)
    (package-quickstart-refresh))
  (when grammars
    (message "Compiling tree-sitter grammars ...")
    (lazyemacs-install-grammars))
  (message "LazyEmacs is ready: %d packages installed.  Start Emacs normally."
           (length package-activated-list)))

;;; bootstrap.el ends here
