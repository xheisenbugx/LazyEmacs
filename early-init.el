;;; early-init.el --- Work done before the package system starts -*- lexical-binding: t; -*-

;;; Commentary:
;; Emacs loads this file before init.el and before it creates the first
;; graphical frame.  Only startup and frame settings belong here; ordinary
;; editor configuration lives in the modules under lisp/.

;;; Code:

;; init-packages.el initializes package.el explicitly.  Preventing the implicit
;; initialization here avoids doing the same work twice.
(setq package-enable-at-startup nil)

;; lsp-mode expands its protocol accessors differently at compile time when
;; this variable is set.  The plist representation allocates less and is the
;; package's recommended fast path.  This must happen before package.el can
;; load either lsp-protocol.elc or its native-compiled counterpart.
(setenv "LSP_USE_PLISTS" "true")

;; Allocate freely while loading the configuration.  Runtime garbage
;; collection is managed by gcmh in init-core.el.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; Keep file-name handlers available.  Private configuration, package files,
;; and restored desktops can use compressed or remote files during startup.

;; Avoid frame resizing and font-cache compaction while the first frame is
;; being assembled.  Both can cause visible startup flicker.
(setq frame-inhibit-implied-resize t
      inhibit-compacting-font-caches t)

;; Remove graphical chrome before the frame exists, so it never flashes on
;; screen.  The commands are repeated in init-ui.el for daemon-created frames.
(dolist (parameter '((menu-bar-lines . 0)
                     (tool-bar-lines . 0)
                     (vertical-scroll-bars . nil)))
  (add-to-list 'default-frame-alist parameter))

;; Never launch native compilation from an interactive session.  The previous
;; warning/worker variables were from older Emacs versions and are not bound
;; during Emacs 30 early startup, so their `boundp' guards silently did
;; nothing.  JIT compilation then spawned workers while files were previewed,
;; and package refreshes queued entire packages (including tests).  Normal
;; byte-compiled packages and Emacs's bundled system .eln files still work.
(setq native-comp-jit-compilation nil
      native-comp-deferred-compilation nil
      native-comp-enable-subr-trampolines nil)

(defun my/restore-startup-state ()
  "Restore settings that were changed temporarily for startup."
  ;; If gcmh is active, keep its high threshold.  The fallback is intentionally
  ;; moderate for sessions started without the rest of this configuration.
  (setq gc-cons-threshold
        (if (bound-and-true-p gcmh-mode)
            gcmh-high-cons-threshold
          (* 64 1024 1024))
        gc-cons-percentage 0.1))

(defun my/report-startup-time ()
  "Report completed startup without changing runtime settings."
  ;; gcmh performs the post-startup collection after a real idle period.  A
  ;; separate two-second timer used to race with the first picker or LSP jump.
  (message "Emacs loaded in %.2fs with %d garbage collections"
           (float-time (time-subtract after-init-time before-init-time))
           gcs-done))

;; Restore before command-line files and desktop hooks are processed.  init.el
;; also calls this from an unwind-protect, including when private config fails.
(add-hook 'after-init-hook #'my/restore-startup-state -100)
(add-hook 'emacs-startup-hook #'my/report-startup-time)

(provide 'early-init)
;;; early-init.el ends here
