;;; init-mail.el --- Email with mu4e, mbsync, and msmtp -*- lexical-binding: t; -*-

;;; Commentary:
;; mu4e reads the Maildir synchronized by mbsync and delegates outgoing mail to
;; msmtp.  Homebrew installs mu4e outside package.el, so this module derives the
;; site-lisp directory from the installed `mu' executable instead of hard-coding
;; a Homebrew version or running `brew' during every Emacs startup.
;;
;; Credentials remain exclusively in mbsync/msmtp configuration and the macOS
;; Keychain.  Nothing in this module contains a password or application token.

;;; Code:

(require 'subr-x)

(defgroup my/mail nil
  "Optional mail integration settings."
  :group 'mail)

(defcustom my/mu4e-user-full-name user-full-name
  "Full name used in outgoing mail."
  :type 'string
  :group 'my/mail)

(defcustom my/mu4e-user-mail-address ""
  "Email address used by mu4e and msmtp."
  :type 'string
  :group 'my/mail)

(defcustom my/mu4e-maildir (expand-file-name "~/Mail")
  "Root Maildir initialized by `mu init'."
  :type 'directory
  :group 'my/mail)

(defcustom my/mu4e-mbsync-channel "default"
  "mbsync channel used to retrieve mail."
  :type 'string
  :group 'my/mail)

(defun my/mu4e-library-directory ()
  "Return Homebrew's mu4e library directory, or nil when unavailable.

The `mu' executable is normally a symlink into Homebrew's Cellar.  Resolving
that link gives us the matching version's prefix and avoids a subprocess call
to `brew --prefix' on every startup."
  (when-let* ((mu (executable-find "mu"))
              (bin-directory (file-name-directory (file-truename mu)))
              (prefix (file-name-directory
                       (directory-file-name bin-directory)))
              (directory (expand-file-name
                          "share/emacs/site-lisp/mu/mu4e/" prefix))
              ((file-directory-p directory)))
    directory))

(when-let ((directory (my/mu4e-library-directory)))
  (add-to-list 'load-path directory))

(defun my/mu4e-index-ready-p ()
  "Return non-nil when the mu database is initialized and readable."
  (when-let ((mu (executable-find "mu")))
    (eq 0 (call-process mu nil nil nil "info"))))

(defun my/mu4e-initialize-index ()
  "Initialize and index `my/mu4e-maildir' for the configured address.

This is deliberately an explicit command because `mu init' creates state
outside this repository.  Run it once with `C-c M i' after mbsync has created
the Maildir."
  (interactive)
  (when (string-empty-p my/mu4e-user-mail-address)
    (user-error "Set my/mu4e-user-mail-address in user/early.el first"))
  (unless (file-directory-p my/mu4e-maildir)
    (user-error "Maildir does not exist: %s" my/mu4e-maildir))
  (let ((mu (or (executable-find "mu")
                (user-error "Cannot find the mu executable")))
        (buffer (get-buffer-create "*mu initialization*")))
    (with-current-buffer buffer
      (erase-buffer))
    (let ((init-status
           (call-process mu nil buffer t
                         "init"
                         "--maildir" my/mu4e-maildir
                         "--personal-address" my/mu4e-user-mail-address)))
      (unless (eq init-status 0)
        (display-buffer buffer)
        (user-error "mu init failed; see %s" (buffer-name buffer))))
    (let ((index-status (call-process mu nil buffer t "index")))
      (if (eq index-status 0)
          (progn
            (kill-buffer buffer)
            (message "mu database initialized and indexed"))
        (display-buffer buffer)
        (user-error "mu index failed; see %s" (buffer-name buffer))))))

(defun my/mu4e-open ()
  "Open mu4e, explaining how to initialize mu first when necessary."
  (interactive)
  (unless (my/mu4e-index-ready-p)
    (user-error "mu is not initialized; run C-c M i first"))
  (call-interactively #'mu4e))

(use-package mu4e
  ;; mu4e ships with Homebrew's mu package, not ELPA.
  :ensure nil
  :commands
  (mu4e mu4e-compose-new mu4e-search mu4e-search-bookmark
         mu4e-search-maildir mu4e-update-mail-and-index)
  :init
  (unless (locate-library "mu4e")
    (display-warning
     'init-mail
     "mu4e was not found; install mu and add its mu4e directory to load-path and restart Emacs"
     :warning))
  :custom
  (user-full-name my/mu4e-user-full-name)
  (user-mail-address my/mu4e-user-mail-address)
  (mail-user-agent 'mu4e-user-agent)

  ;; mu4e 1.14 obtains the root Maildir and personal addresses directly from
  ;; the mu database.  The initializer above passes both values to `mu init';
  ;; this replaces the old `mu4e-maildir' and
  ;; `mu4e-compose-dont-reply-to-self' options from older configurations.

  ;; Retrieve mail through the existing mbsync channel, then let mu4e update
  ;; its index.  Automatic updates only run while mu4e itself is open.
  (mu4e-get-mail-command
   (format "%s %s"
           (shell-quote-argument (or (executable-find "mbsync") "mbsync"))
           (shell-quote-argument my/mu4e-mbsync-channel)))
  (mu4e-update-interval 300)
  (mu4e-index-update-in-background t)
  (mu4e-confirm-quit nil)
  (mu4e-change-filenames-when-moving t)

  ;; Gnus renders mu4e messages in current releases.  These replace the old,
  ;; obsolete `mu4e-view-show-images' and `mu4e-view-prefer-html' variables:
  ;; show embedded images, keep remote HTTP images blocked for privacy, and
  ;; prefer plain text when a multipart message contains both representations.
  (gnus-inhibit-images nil)
  (gnus-blocked-images "http")
  (mm-discouraged-alternatives '("text/html" "text/richtext"))

  (mu4e-compose-format-flowed t)
  (message-kill-buffer-on-exit t)

  ;; Generic Maildir folders; override these for your provider in user/config.el.
  (mu4e-sent-messages-behavior 'sent)
  (mu4e-sent-folder "/Sent")
  (mu4e-drafts-folder "/Drafts")
  (mu4e-trash-folder "/Trash")
  (mu4e-refile-folder "/Archive")
  (mu4e-trash-without-flag t)

  ;; msmtp reads the From header and chooses the matching account from its own
  ;; configuration.  Authentication therefore stays outside Emacs.
  (message-send-mail-function #'message-send-mail-with-sendmail)
  (sendmail-program (or (executable-find "msmtp") "msmtp"))
  (message-sendmail-f-is-evil t)
  (message-sendmail-extra-arguments '("--read-envelope-from"))
  (message-sendmail-envelope-from 'header)

  (mu4e-headers-date-format "%Y-%m-%d %H:%M")
  (mu4e-headers-time-format "%H:%M")
  (mu4e-headers-fields
   '((:human-date . 12)
     (:flags . 6)
     (:from . 25)
     (:subject)))

  (mu4e-bookmarks
   '((:name "Unread"
      :query "flag:unread AND NOT flag:trashed"
      :key ?u)
     (:name "Today"
      :query "date:today..now"
      :key ?t)
     (:name "Last 7 days"
      :query "date:7d..now"
      :key ?w)
     (:name "With attachments"
      :query "flag:attach"
      :key ?a)
     (:name "Inbox"
      :query "maildir:/Inbox"
      :key ?i))))

(provide 'init-mail)
;;; init-mail.el ends here
