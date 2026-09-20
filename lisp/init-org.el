;;; init-org.el --- Notes, tasks, agenda, and capture -*- lexical-binding: t; -*-

;;; Commentary:
;; Org is configured as the native notes/task workspace.  org-modern improves
;; presentation without changing the underlying plain-text files.

;;; Code:

(declare-function org-heading-components "org" ())
(declare-function org-get-deadline-time "org" (pom &optional inherit))
(declare-function org-get-scheduled-time "org" (pom &optional inherit))
(declare-function org-agenda "org-agenda" (&optional arg keys restriction))

(defun my/org-agenda-include-priority-no-date ()
  "Keep priority-A headings that have no deadline or scheduled date.

Return nil for a matching heading so `org-agenda' includes it.  Return the
beginning of the next line for every other heading, as required by
`org-agenda-skip-function'."
  (let ((position (point)))
    (if (and (eq (nth 3 (org-heading-components)) ?A)
             (not (org-get-deadline-time position))
             (not (org-get-scheduled-time position)))
        nil
      (line-beginning-position 2))))

(defun my/org-agenda-dashboard ()
  "Open the focused daily agenda dashboard."
  (interactive)
  (org-agenda nil "d"))

(use-package org
  :ensure nil
  :commands (org-agenda org-capture org-store-link)
  :hook
  (org-mode . visual-line-mode)
  :custom
  (org-support-shift-select t)
  (org-directory lazyemacs-org-directory)
  (org-startup-indented t)
  (org-hide-emphasis-markers t)
  (org-return-follows-link t)
  (org-src-fontify-natively t)
  (org-src-tab-acts-natively t)
  (org-edit-src-content-indentation 0)
  ;; Keep the agenda in the current window and make entries compact and
  ;; predictable: category, time, then heading text.
  (org-agenda-window-setup 'current-window)
  (org-agenda-prefix-format "%c\t %t %s")
  (org-agenda-sorting-strategy
   '((agenda habit-down time-up priority-down category-keep)
     (todo priority-down category-keep)
     (tags priority-down category-keep)
     (search category-keep)))
  (org-agenda-compact-blocks nil)
  (org-agenda-block-separator ?—)
  (org-agenda-time-leading-zero t)
  (org-agenda-show-current-time-in-grid t)
  (org-agenda-current-time-string (concat "Now " (make-string 60 ?.)))
  (org-agenda-time-grid
   '((daily today require-timed)
     (0600 0700 0800 0900 1000 1100 1200 1300 1400 1500
           1600 1700 1800 1900 2000 2100 2200 2300)
     "" ""))
  :config
  (setq org-replace-disputed-keys t)
  (make-directory org-directory t)
  (setq org-confirm-babel-evaluate t)
  (setq org-log-done 'time)

  ;; Org Babel only loads the Emacs Lisp executor by default.  Register the
  ;; languages used by this configuration so source blocks have matching
  ;; `org-babel-execute:LANGUAGE' functions when they are evaluated.
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((python . t)
     (shell . t)
     (emacs-lisp . t)))

  (setq org-agenda-files
        (list org-directory)
        org-capture-templates
        `(("t" "Task" entry
           (file+headline ,(expand-file-name "tasks.org" org-directory) "Tasks")
           "* TODO %?\n  Created: %U\n  %i")
          ("n" "Note" entry
           (file+headline ,(expand-file-name "inbox.org" org-directory) "Notes")
           "* %?\n  Created: %U\n  %i")
          ("j" "Journal" entry
           (file+olp+datetree ,(expand-file-name "journal.org" org-directory))
           "* %<%H:%M> %?\n  Entered: %U\n\n%i"
           :empty-lines 1)))

  ;; This follows Protesilaos Stavrou's native block-agenda approach.  Each
  ;; block performs one focused query, so no third-party grouping package is
  ;; necessary and entries cannot leak from one date range into another.
  (setq org-agenda-custom-commands
        '(("d" "Daily agenda and top priority tasks"
           ((tags-todo "*"
             ((org-agenda-overriding-header
               "Important tasks without a date\n")
              (org-agenda-skip-function
               #'my/org-agenda-include-priority-no-date)
              (org-agenda-block-separator nil)))

            ;; Scan one agenda day while allowing scheduled entries from the
            ;; past year.  A one-day delay excludes tasks scheduled for today.
            (agenda ""
             ((org-agenda-overriding-header "\nPending scheduled tasks")
              (org-agenda-time-grid nil)
              (org-agenda-start-on-weekday nil)
              (org-agenda-span 1)
              (org-agenda-show-all-dates nil)
              (org-scheduled-past-days 365)
              (org-scheduled-delay-days 1)
              (org-agenda-entry-types '(:scheduled))
              (org-agenda-skip-function
               '(org-agenda-skip-entry-if 'todo 'done))
              (org-agenda-block-separator nil)
              (org-agenda-format-date "")))

            (agenda ""
             ((org-agenda-overriding-header "\nToday's agenda\n")
              (org-agenda-span 1)
              (org-deadline-warning-days 0)
              (org-scheduled-past-days 0)
              (org-agenda-skip-function
               '(org-agenda-skip-entry-if 'todo 'done))
              (org-agenda-block-separator nil)
              (org-agenda-format-date "%A %-e %B %Y")))

            (agenda ""
             ((org-agenda-overriding-header "\nNext three days\n")
              (org-agenda-start-on-weekday nil)
              (org-agenda-start-day "+1d")
              (org-agenda-span 3)
              (org-deadline-warning-days 0)
              (org-agenda-skip-function
               '(org-agenda-skip-entry-if 'todo 'done))
              (org-agenda-block-separator nil)))

            ;; Start after the preceding three-day block and display only
            ;; actual deadlines during the following fourteen days.
            (agenda ""
             ((org-agenda-overriding-header
               "\nUpcoming deadlines (+14d)\n")
              (org-agenda-time-grid nil)
              (org-agenda-start-on-weekday nil)
              (org-agenda-start-day "+4d")
              (org-agenda-span 14)
              (org-agenda-show-all-dates nil)
              (org-deadline-warning-days 0)
              (org-agenda-entry-types '(:deadline))
              (org-agenda-skip-function
               '(org-agenda-skip-entry-if 'todo 'done))
              (org-agenda-block-separator nil))))
           ((org-agenda-fontify-priorities nil)
            (org-agenda-dim-blocked-tasks nil))))))


(use-package org-modern
  :after org
  :hook
  (org-mode . org-modern-mode)
  :custom
  (org-modern-star '("◉" "○" "✸" "✿"))
  (org-modern-table nil)
  (org-modern-list '((43 . "➤") (45 . "–") (42 . "•"))))

(provide 'init-org)
;;; init-org.el ends here
