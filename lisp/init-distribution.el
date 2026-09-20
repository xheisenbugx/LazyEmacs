;;; init-distribution.el --- LazyEmacs public configuration -*- lexical-binding: t; -*-
;;; Commentary:
;; Stable user-facing options, private configuration loading, and diagnostics.
;;; Code:
(defgroup lazyemacs nil "An Evil-first Emacs distribution." :group 'convenience)
(defcustom lazyemacs-user-directory
  (expand-file-name (or (getenv "LAZYEMACS_USER_DIR") "user/") user-emacs-directory)
  "Private configuration directory.  Set LAZYEMACS_USER_DIR before startup."
  :type 'directory :group 'lazyemacs)
(defcustom lazyemacs-enable-mail nil
  "Load the optional mu4e integration.  Restart after changing this option."
  :type 'boolean :group 'lazyemacs)
(defcustom lazyemacs-enable-recovery t
  "Keep backup and auto-save recovery files under var/."
  :type 'boolean :group 'lazyemacs)
(defcustom lazyemacs-dark-theme 'catppuccin
  "Dark theme used at startup and by the theme toggle."
  :type 'symbol :group 'lazyemacs)
(defcustom lazyemacs-light-theme 'modus-operandi-tinted
  "Light theme used by the theme toggle."
  :type 'symbol :group 'lazyemacs)
(defcustom lazyemacs-fonts
  '("JetBrainsMono Nerd Font Mono" "Iosevka Nerd Font Mono" "Menlo" "DejaVu Sans Mono")
  "Font families to try in order; retain the Emacs font if none is installed."
  :type '(repeat string) :group 'lazyemacs)
(defcustom lazyemacs-font-height 140
  "Default font height in tenths of a point."
  :type 'integer :group 'lazyemacs)
(defcustom lazyemacs-org-directory (expand-file-name "org/" (getenv "HOME"))
  "Directory for Org agenda and capture files."
  :type 'directory :group 'lazyemacs)

(defun lazyemacs-load-user-file (name)
  "Load private file NAME if it exists, preserving errors for diagnosis."
  (let ((file (expand-file-name name lazyemacs-user-directory)))
    (when (file-exists-p file)
      (load file nil 'nomessage))))

(defun lazyemacs-doctor ()
  "Display a read-only environment report; never install or run external tools."
  (interactive)
  (with-help-window "*LazyEmacs Doctor*"
    (princ (format "LazyEmacs environment\n\nEmacs: %s\nSystem: %s\nConfig: %s\nPrivate: %s\n\n"
                   emacs-version system-type user-emacs-directory lazyemacs-user-directory))
    (dolist (command '("git" "rg" "fd" "cc" "cmake" "libtool" "typescript-language-server"
                       "basedpyright-langserver" "gopls" "rust-analyzer"
                       "emacs-lsp-booster" "mu" "mbsync" "msmtp"))
      (princ (format "%-28s %s\n" command (or (executable-find command) "not found (feature dependent)"))))
    (princ (format "\nDynamic modules: %s\nTree-sitter: %s\nMail enabled: %s\nRecovery enabled: %s\n"
                   (and (boundp 'module-file-suffix) module-file-suffix)
                   (and (fboundp 'treesit-available-p) (treesit-available-p))
                   lazyemacs-enable-mail lazyemacs-enable-recovery))))

(make-directory lazyemacs-user-directory t)
(provide 'init-distribution)
;;; init-distribution.el ends here
