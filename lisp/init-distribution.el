;;; init-distribution.el --- LazyEmacs public configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Stable user-facing options, private configuration loading, and diagnostics.
;; Every `lazyemacs-*' option below is part of the public interface: set it in
;; user/early.el (loaded before any feature module) and restart Emacs.

;;; Code:

(require 'package)

(defgroup lazyemacs nil
  "An Evil-first Emacs distribution inspired by LazyVim."
  :group 'convenience
  :link '(url-link "https://github.com/xheisenbugx/LazyEmacs"))

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

(defcustom lazyemacs-offline (equal (getenv "LAZYEMACS_OFFLINE") "1")
  "Prevent package downloads and metadata refreshes.
Set LAZYEMACS_OFFLINE=1 before startup to use installed packages only.
Missing dependencies produce an error naming the package.  This option
controls package management, not network access by language servers or tools."
  :type 'boolean :group 'lazyemacs)

(defcustom lazyemacs-prefer-tree-sitter t
  "Use native language modes when their grammars are already installed.
No grammars are downloaded automatically.  Restart after changing this option."
  :type 'boolean :group 'lazyemacs)

(defcustom lazyemacs-dark-theme 'catppuccin
  "Dark theme used at startup and by the theme toggle."
  :type 'symbol :group 'lazyemacs)

(defcustom lazyemacs-light-theme 'modus-operandi-tinted
  "Light theme used by the theme toggle."
  :type 'symbol :group 'lazyemacs)

(defcustom lazyemacs-fonts
  '("BlexMono Nerd Font Mono" "JetBrainsMono Nerd Font Mono" "Iosevka Nerd Font Mono"
    ;; Platform defaults: macOS, Linux, then Windows.
    "Menlo" "DejaVu Sans Mono" "Cascadia Mono" "Consolas")
  "Font families to try in order; retain the Emacs font if none is installed."
  :type '(repeat string) :group 'lazyemacs)

(defcustom lazyemacs-font-height 140
  "Default font height in tenths of a point."
  :type 'integer :group 'lazyemacs)

(defcustom lazyemacs-dashboard t
  "Show the LazyEmacs dashboard when Emacs starts without files to visit."
  :type 'boolean :group 'lazyemacs)

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
  (let ((mode major-mode)
        (managed (bound-and-true-p lsp-managed-mode))
        ;; Probe local tools even when the command was invoked in TRAMP.
        (default-directory (expand-file-name "~/")))
    (with-help-window "*LazyEmacs Doctor*"
      (princ (format "LazyEmacs environment\n\nEmacs: %s\nSystem: %s\nSource: %s\nState: %s\nPrivate: %s\n"
                     emacs-version system-type
                     (if (boundp 'lazyemacs-root-directory) lazyemacs-root-directory "not loaded")
                     user-emacs-directory lazyemacs-user-directory))
      (princ (format "Package network: %s\nCurrent mode: %s\nLSP attached here: %s\n"
                     (if lazyemacs-offline "offline" "allowed for installation/updates")
                     mode (if managed "yes" "no")))
      (princ "\nTools (missing tools affect only the named feature)\n")
      (dolist (entry (append
                      '(("git" . "projects and Git") ("rg" . "project text search")
                        ("fd" . "file search; find is the fallback")
                        ("fdfind" . "Debian/Ubuntu fd alternative")
                        ("cc" . "grammar compilation") ("cmake" . "native module builds")
                        ("typescript-language-server" . "JS/TS LSP")
                        ("basedpyright-langserver" . "Python LSP")
                        ("pyright-langserver" . "Python LSP alternative")
                        ("pylsp" . "Python LSP alternative")
                        ("gopls" . "Go LSP") ("rust-analyzer" . "Rust LSP")
                        ("vscode-json-language-server" . "JSON LSP")
                        ("vscode-css-language-server" . "CSS LSP")
                        ("vscode-html-language-server" . "HTML LSP")
                        ("yaml-language-server" . "YAML LSP")
                        ("docker-langserver" . "Dockerfile LSP")
                        ("lua-language-server" . "Lua LSP")
                        ("bash-language-server" . "Bash LSP")
                        ("emacs-lsp-booster" . "optional buffered JSON transport")
                        ("debugpy-adapter" . "Python debugging (pip install debugpy)")
                        ("dlv" . "Go debugging")
                        ("aspell" . "spell checking (or hunspell)"))
                      (when lazyemacs-enable-mail
                        '(("mu" . "mail index") ("mbsync" . "mail sync")
                          ("msmtp" . "mail delivery")))))
        (princ (format "%-30s %-25s %s\n" (car entry)
                       (or (executable-find (car entry)) "MISSING") (cdr entry))))
      (princ (format "\nDynamic modules: %s\nTree-sitter: %s\nMail enabled: %s\nRecovery enabled: %s\n"
                     (and (boundp 'module-file-suffix) module-file-suffix)
                     (and (fboundp 'treesit-available-p) (treesit-available-p))
                     lazyemacs-enable-mail lazyemacs-enable-recovery))
      (when (fboundp 'treesit-language-available-p)
        (princ "\nGrammar availability (no automatic downloads)\n")
        (dolist (language (if (boundp 'lazyemacs-grammars) lazyemacs-grammars
                            '(typescript tsx javascript python go rust json css yaml bash)))
          (princ (format "%-16s %s\n" language
                         (if (treesit-language-available-p language) "ready" "missing or incompatible"))))
        (princ "Install missing grammars with SPC h T (M-x lazyemacs-install-grammars), then reopen the file.\n"))
      (when (boundp 'package-alist)
        (princ "\nInstalled packages (versions; VC packages may report 0)\n")
        (dolist (entry (sort (copy-sequence package-alist)
                            (lambda (a b) (string< (symbol-name (car a)) (symbol-name (car b))))))
          (princ (format "%-30s %s\n" (car entry)
                         (package-version-join (package-desc-version (cadr entry))))))))))

(make-directory lazyemacs-user-directory t)
(provide 'init-distribution)
;;; init-distribution.el ends here
