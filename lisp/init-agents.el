;;; init-agents.el --- Coding agents in sessions: status, picker, worktrees -*- lexical-binding: t; -*-

;;; Commentary:
;; Run several coding agents (Claude Code, Codex, or any terminal agent) and
;; always know which one needs you, in the spirit of herdr, T3 Code and
;; LazyVim's sidekick.nvim:
;;
;; - An agent is a Ghostel terminal running the agent's CLI, owned by a
;;   session.  `SPC a n' starts a task in a new tab here or in a new Git
;;   worktree with its own session; `SPC a a' toggles an agent beside the code.
;; - Status (working, blocked, done, error) comes from the agents themselves:
;;   Claude Code and Codex report it to the terminal with OSC 7501, Ghostel's
;;   program status protocol, which Ghostel records per buffer.  Nothing polls
;;   and no agent configuration is touched.  An agent that does not report
;;   shows as idle while it runs.  Any Ghostel terminal whose program reports
;;   a status with an app name counts as an agent, so one started by hand in a
;;   project shell is listed too.
;; - The mode line counts agents by state, the tab bar marks agent tabs and
;;   other sessions with agents waiting, `SPC a s' is a picker sorted by
;;   urgency with Embark actions, `SPC a j' jumps to the next agent that needs
;;   you, and `SPC a l' toggles a sidebar.  A notification appears when an
;;   agent needs you and you are looking elsewhere.
;; - `SPC a r' reviews an agent's changes in Magit, `SPC a c' pushes its
;;   branch and opens a pull request, and `SPC a x' closes the task, removing
;;   its worktree and session.
;; - Sessions save their agents.  A restored agent is a placeholder; RET
;;   resumes the conversation (`claude --resume ID', `codex resume --last').

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'tab-bar)
(require 'init-tools)
(require 'init-sesh)

(declare-function ghostel-exec "ghostel")
(declare-function ghostel-paste-string "ghostel")
(declare-function ghostel-send-string "ghostel")
(declare-function ghostel--buffer-focused-p "ghostel")
(declare-function ghostel-status-buffer-state "ghostel-status")
(declare-function magit-status-setup-buffer "magit-status")
(declare-function magit-diff-working-tree "magit-diff")
(declare-function flycheck-error-line "flycheck")
(declare-function flycheck-error-level "flycheck")
(declare-function flycheck-error-message "flycheck")
(declare-function flymake-diagnostics "flymake")
(declare-function flymake-diagnostic-beg "flymake")
(declare-function flymake-diagnostic-text "flymake")
(declare-function flymake-diagnostic-type "flymake")
(declare-function dired-get-filename "dired")
(declare-function alert "alert")
(declare-function notifications-notify "notifications")
(declare-function evil-set-initial-state "evil-core")

(defvar ghostel-program-status)
(defvar ghostel-title)
(defvar ghostel--process)
(defvar ghostel-kill-buffer-on-exit)
(defvar ghostel-status-auto-acknowledge)
(defvar ghostel-notification-functions)
(defvar ghostel-program-status-functions)
(defvar ghostel-exit-functions)
(defvar ghostel-query-before-killing)
(defvar flycheck-current-errors)
(defvar embark-general-map)
(defvar embark-keymap-alist)
(defvar my/leader-map)

;;; Options

(defgroup lazyemacs-agents nil
  "Coding agents in sessions."
  :group 'lazyemacs
  :prefix "lazyemacs-agent-")

(defcustom lazyemacs-agents
  '(("claude" :program "claude" :args lazyemacs-agent-claude-args)
    ("codex" :program "codex" :args lazyemacs-agent-codex-args))
  "Agents you can start, as (NAME . PLIST).
:program is the executable.  :args is a list of arguments, given before
the task's prompt, or a function called with the agent's DATA, RESUME
and PROMPT that returns every argument; only a function can resume a
conversation.  An agent that does not report its status with OSC 7501
shows as idle while it runs.  For example, to add Aider:

  (add-to-list \\='lazyemacs-agents \\='(\"aider\" :program \"aider\"))"
  :type '(alist :key-type string :value-type plist))

(defcustom lazyemacs-agent-default "claude"
  "Agent that `SPC a n' and `SPC a a' start; a prefix argument asks."
  :type 'string)

(defcustom lazyemacs-agent-branch-prefix "agent/"
  "Prefix of the branches made for tasks in a new worktree."
  :type 'string)

(defcustom lazyemacs-agent-notify t
  "How to tell you an agent needs you while you look elsewhere.
t shows a message, plus a desktop notification when no Emacs frame has
focus; `message' only shows the message; nil stays quiet."
  :type '(choice (const :tag "Message and desktop" t)
                 (const :tag "Message only" message)
                 (const :tag "Nothing" nil)))

(defcustom lazyemacs-agent-mode-line t
  "Non-nil counts agents by state in the mode line."
  :type 'boolean)

(defcustom lazyemacs-agent-side-width 0.4
  "Width of the window `SPC a a' shows an agent in, as a fraction."
  :type 'number)

(defcustom lazyemacs-agent-sidebar-width 42
  "Width of the agents sidebar in columns."
  :type 'natnum)

(defcustom lazyemacs-agent-glyphs
  '((blocked . "◆") (error . "✗") (done . "✓") (working . "●") (idle . "○")
    (stopped . "■"))
  "Glyph per agent state, in the mode line, tab bar, picker and sidebar."
  :type '(alist :key-type symbol :value-type string))

(defcustom lazyemacs-agent-prompts
  '(("Explain" . "Explain {this}.")
    ("Review file" . "Review {file} for bugs, edge cases and readability.")
    ("Fix diagnostics" . "Fix these diagnostics in {file}:\n{diagnostics}")
    ("Write tests" . "Write tests for {this}.")
    ("Simplify" . "Simplify {this} without changing what it does.")
    ("Document" . "Add documentation comments to {this}.")
    ("Review changes" . "Review the uncommitted changes in this repository and point out problems."))
  "Prompts for `SPC a p', as (NAME . TEMPLATE).
{this} is the selection or the line at point, {file} the file, {selection}
the selected text, and {diagnostics} this buffer's errors and warnings."
  :type '(alist :key-type string :value-type string))

(defcustom lazyemacs-agent-commit-prompt
  "Commit all your changes with a clear commit message.  Do not push."
  "What `SPC a c' asks an agent when its checkout has uncommitted changes."
  :type 'string)

(defface lazyemacs-agent-blocked '((t :inherit error :weight bold))
  "Agents waiting for your approval or answer.")
(defface lazyemacs-agent-error '((t :inherit error))
  "Agents that failed.")
(defface lazyemacs-agent-done '((t :inherit success))
  "Agents that finished and you have not looked at yet.")
(defface lazyemacs-agent-working '((t :inherit warning))
  "Agents at work.")
(defface lazyemacs-agent-idle '((t :inherit shadow))
  "Agents waiting for a new task.")
(defface lazyemacs-agent-stopped '((t :inherit shadow))
  "Agents not running, which can be resumed.")

(defconst lazyemacs-agent--urgency '(blocked error done working idle stopped)
  "States most urgent first.")

(defconst lazyemacs-agent--attention '(blocked error done)
  "States that need you.")

;;; Agent commands

(defun lazyemacs-agent--safe-prompt (prompt)
  "Return PROMPT so that a CLI cannot read it as an option."
  (if (string-prefix-p "-" prompt) (concat " " prompt) prompt))

(defun lazyemacs-agent-claude-args (data resume prompt)
  "Arguments for Claude Code running agent DATA, RESUME or with PROMPT.
The conversation id is the agent's id, so resuming finds it exactly."
  (append (if resume
              (list "--resume" (plist-get data :id))
            (append (list "--session-id" (plist-get data :id))
                    (let ((task (plist-get data :task)))
                      (and task (not (string-empty-p task)) (list "--name" task)))))
          (and prompt (not resume) (not (string-empty-p prompt))
               (list (lazyemacs-agent--safe-prompt prompt)))))

(defun lazyemacs-agent-codex-args (_data resume prompt)
  "Arguments for Codex, RESUME or with PROMPT.
Resuming continues the most recent conversation in the agent's directory."
  (if resume
      (list "resume" "--last")
    (and prompt (not (string-empty-p prompt))
         (list (lazyemacs-agent--safe-prompt prompt)))))

(defun lazyemacs-agent--definition (name)
  "Return the plist of agent NAME from `lazyemacs-agents'."
  (cdr (assoc name lazyemacs-agents)))

(defun lazyemacs-agent--installed ()
  "Return the names of the agents whose program is installed."
  (seq-filter (lambda (name)
                (executable-find (plist-get (lazyemacs-agent--definition name) :program)))
              (mapcar #'car lazyemacs-agents)))

(defun lazyemacs-agent--default ()
  "Return the agent to start without asking."
  (let ((installed (lazyemacs-agent--installed)))
    (cond ((member lazyemacs-agent-default installed) lazyemacs-agent-default)
          (installed (car installed))
          (t lazyemacs-agent-default))))

(defun lazyemacs-agent--require-terminal ()
  "Signal a `user-error' unless agents can run in a Ghostel terminal."
  (unless (my/ghostel-available-p)
    (user-error "Agents run in Ghostel terminals, which need Emacs built with module support")))

(defun lazyemacs-agent--command (data resume prompt)
  "Return the argv starting agent DATA, RESUME or with PROMPT.
Signal a `user-error' when the agent is unknown or not installed."
  (let* ((name (plist-get data :agent))
         (definition (or (lazyemacs-agent--definition name)
                         (user-error "No agent named %s in `lazyemacs-agents'" name)))
         (program (plist-get definition :program))
         (args (plist-get definition :args))
         (default-directory (plist-get data :directory)))
    (unless (executable-find program (file-remote-p default-directory))
      (user-error "%s is not installed (looked for %s)" name program))
    (cons program
          (if (functionp args)
              (funcall args data resume prompt)
            (append args (and prompt (not resume) (not (string-empty-p prompt))
                              (list (lazyemacs-agent--safe-prompt prompt))))))))

;;; Agents

(defvar-local lazyemacs-agent nil
  "This buffer's agent: a printable plist.
:agent names the entry of `lazyemacs-agents', :id identifies it (Claude's
conversation id), :task is its task, :name the name the agent gave its
conversation, :directory where it runs, :session the session that owns
it, and a task in its own worktree has :worktree t, its :branch and the
:base branch it started from.")
(put 'lazyemacs-agent 'permanent-local t)

(defvar-local lazyemacs-agent--changed nil
  "When this agent's state last changed, as a float time.")
(put 'lazyemacs-agent--changed 'permanent-local t)

(defun lazyemacs-agent--uuid ()
  "Return a random UUID (version 4)."
  (let ((bytes (mapcar (lambda (_) (random 256)) (make-list 16 nil))))
    (setf (nth 6 bytes) (logior #x40 (logand (nth 6 bytes) #x0f))
          (nth 8 bytes) (logior #x80 (logand (nth 8 bytes) #x3f)))
    (let ((hex (mapconcat (lambda (byte) (format "%02x" byte)) bytes "")))
      (format "%s-%s-%s-%s-%s" (substring hex 0 8) (substring hex 8 12)
              (substring hex 12 16) (substring hex 16 20) (substring hex 20)))))

(defun lazyemacs-agent--make (agent directory task &rest props)
  "Return the data of a new AGENT working on TASK in DIRECTORY, plus PROPS."
  (append (list :agent agent :id (lazyemacs-agent--uuid) :task (string-trim (or task ""))
                :directory (file-name-as-directory (expand-file-name directory))
                :session (lazyemacs-sesh--current) :created (float-time))
          props))

(defun lazyemacs-agent--app (buffer)
  "Return the app name BUFFER's program reports with OSC 7501, or nil."
  (and (boundp 'ghostel-program-status)
       (seq-some (lambda (entry) (plist-get (cdr entry) :app))
                 (buffer-local-value 'ghostel-program-status buffer))))

(defun lazyemacs-agent-p (buffer)
  "Return non-nil when BUFFER is an agent.
That is a terminal LazyEmacs started an agent in, a stopped agent, or any
terminal whose program reports its status with an app name."
  (and (buffer-live-p buffer)
       (or (buffer-local-value 'lazyemacs-agent buffer)
           (lazyemacs-agent--app buffer))
       t))

(defun lazyemacs-agent--managed-p (buffer)
  "Return non-nil when LazyEmacs started BUFFER's agent."
  (and (buffer-live-p buffer) (buffer-local-value 'lazyemacs-agent buffer) t))

(defun lazyemacs-agent-buffers ()
  "Return the agent buffers, most recently used first."
  (seq-filter #'lazyemacs-agent-p (buffer-list)))

(defun lazyemacs-agent--data (buffer)
  "Return BUFFER's agent data, describing an agent LazyEmacs did not start."
  (or (buffer-local-value 'lazyemacs-agent buffer)
      (list :agent (lazyemacs-agent--app buffer) :task (buffer-name buffer)
            :directory (buffer-local-value 'default-directory buffer))))

(defun lazyemacs-agent--find (id)
  "Return the agent buffer whose id is ID."
  (and id (seq-find (lambda (buffer)
                      (equal id (plist-get (buffer-local-value 'lazyemacs-agent buffer) :id)))
                    (buffer-list))))

(defvar-local lazyemacs-agent--transcript-read nil
  "Non-nil once this stopped agent's transcript was searched for a name.")

(defvar-local lazyemacs-agent--shown-name nil
  "The conversation name the agent views last showed for this agent.")

(defun lazyemacs-agent--clean-name (title data)
  "Return terminal TITLE as the name of agent DATA's conversation, or nil.
Drops the spinner Claude Code puts before it, and titles that only name
the agent."
  (when (stringp title)
    (let ((name (string-trim (replace-regexp-in-string "\\`[[:space:]✳✻✽✶✢·*⠀-⣿]+" "" title)))
          (agent (plist-get data :agent)))
      (unless (or (string-empty-p name)
                  (member-ignore-case
                   name (delq nil (list "Claude Code" "Codex" agent
                                        (and (stringp agent)
                                             (plist-get (lazyemacs-agent--definition agent) :program))))))
        name))))

(defun lazyemacs-agent--transcript-name (data)
  "Return the name Claude Code saved for agent DATA's conversation, or nil.
A name given with /rename wins over the one Claude made up."
  (when-let* ((id (plist-get data :id))
              ((stringp id))
              ((string-match-p "\\`[[:xdigit:]-]+\\'" id))
              (file (car (file-expand-wildcards
                          (expand-file-name (concat "projects/*/" id ".jsonl")
                                            (or (getenv "CLAUDE_CONFIG_DIR") "~/.claude"))))))
    (with-temp-buffer
      (when (ignore-errors (insert-file-contents file) t)
        (seq-some (pcase-lambda (`(,type . ,key))
                    (goto-char (point-max))
                    (when (re-search-backward (format "^{\"type\":\"%s\"" type) nil t)
                      (let ((record (ignore-errors
                                      (json-parse-string
                                       (buffer-substring (point) (line-end-position))
                                       :object-type 'plist))))
                        (lazyemacs-agent--clean-name (plist-get record key) data))))
                  '(("custom-title" . :customTitle) ("agent-name" . :agentName)
                    ("ai-title" . :aiTitle)))))))

(defun lazyemacs-agent--remember-name (buffer name)
  "Save NAME as the conversation name of BUFFER's agent, and return it."
  (with-current-buffer buffer
    (unless (equal name (plist-get lazyemacs-agent :name))
      (setq lazyemacs-agent (plist-put (copy-sequence lazyemacs-agent) :name name))))
  name)

(defun lazyemacs-agent--name (buffer)
  "Return the name BUFFER's agent gives its conversation, or nil.
A running agent's terminal title is the live name: Claude Code shows the
conversation's name there, including one given with /rename.  The name is
remembered and saved with the session, so a stopped or restored agent
keeps it; a Claude Code agent stopped before its name was seen reads it
from the conversation's transcript, once."
  (let* ((data (lazyemacs-agent--data buffer))
         (managed (lazyemacs-agent--managed-p buffer))
         (running (lazyemacs-agent--running-p buffer))
         (live (and running (boundp 'ghostel-title)
                    (lazyemacs-agent--clean-name (buffer-local-value 'ghostel-title buffer) data))))
    (cond
     (live (if managed (lazyemacs-agent--remember-name buffer live) live))
     ((plist-get data :name))
     ((and managed (not running)
           (not (buffer-local-value 'lazyemacs-agent--transcript-read buffer)))
      (with-current-buffer buffer (setq lazyemacs-agent--transcript-read t))
      (when-let* ((name (lazyemacs-agent--transcript-name data)))
        (lazyemacs-agent--remember-name buffer name))))))

(defun lazyemacs-agent--title (buffer)
  "Return the name of BUFFER's agent's conversation, its task, or the agent."
  (let* ((data (lazyemacs-agent--data buffer))
         (task (plist-get data :task)))
    (cond ((lazyemacs-agent--name buffer))
          ((and task (not (string-empty-p task))) task)
          (t (format "%s" (or (plist-get data :agent) (buffer-name buffer)))))))

(defun lazyemacs-agent--title-changed ()
  "Redraw the agent views when this terminal's agent shows a new name."
  (when (lazyemacs-agent-p (current-buffer))
    (let ((name (lazyemacs-agent--name (current-buffer))))
      (unless (equal name lazyemacs-agent--shown-name)
        (setq lazyemacs-agent--shown-name name)
        (lazyemacs-agent--schedule-refresh)))))

(defun lazyemacs-agent--running-p (buffer)
  "Return non-nil when BUFFER's agent process is running."
  (and (buffer-live-p buffer)
       (with-current-buffer buffer
         (and (derived-mode-p 'ghostel-mode)
              (bound-and-true-p ghostel--process)
              (process-live-p ghostel--process)))
       t))

(defun lazyemacs-agent-state (buffer)
  "Return the state of BUFFER's agent: one of `lazyemacs-agent--urgency'."
  (cond ((not (lazyemacs-agent--running-p buffer)) 'stopped)
        ((ghostel-status-buffer-state buffer '(blocked error done working idle)))
        (t 'idle)))

(defun lazyemacs-agent--kind (buffer)
  "Return why BUFFER's blocked agent waits: `permission', `question' or nil."
  (and (boundp 'ghostel-program-status)
       (seq-some (lambda (entry)
                   (and (eq (plist-get (cdr entry) :state) 'blocked)
                        (plist-get (cdr entry) :kind)))
                 (buffer-local-value 'ghostel-program-status buffer))))

(defun lazyemacs-agent--describe (buffer state)
  "Describe BUFFER's agent in STATE in a few words."
  (pcase state
    ('blocked (pcase (lazyemacs-agent--kind buffer)
                ('permission "needs approval")
                ('question "has a question")
                ('auth "needs login")
                (_ "waiting for you")))
    ('error "failed")
    ('done "done")
    ('working "working")
    ('idle "idle")
    (_ "stopped")))

(defun lazyemacs-agent--glyph (state)
  "Return STATE's glyph in STATE's face."
  (propertize (or (alist-get state lazyemacs-agent-glyphs) "?")
              'face (intern (format "lazyemacs-agent-%s" state))))

(defun lazyemacs-agent--session-for-directory (directory)
  "Return the live session with the innermost root containing DIRECTORY."
  (let ((directory (ignore-errors (lazyemacs-sesh--dir directory)))
        best best-root)
    (when directory
      (dolist (name (lazyemacs-sesh--live-names))
        (let ((root (lazyemacs-sesh--live-root name)))
          (when (and root (string-prefix-p root directory)
                     (> (length root) (length best-root)))
            (setq best name best-root root)))))
    best))

(defun lazyemacs-agent--session (buffer)
  "Return the name of the session BUFFER's agent belongs to."
  (let* ((data (lazyemacs-agent--data buffer))
         (stored (plist-get data :session)))
    (or (and (lazyemacs-sesh--live-p stored) stored)
        (lazyemacs-agent--session-for-directory (plist-get data :directory))
        (car (buffer-local-value 'lazyemacs-sesh--buffer-sessions buffer))
        stored)))

(defun lazyemacs-agent--age (buffer)
  "Describe how long ago BUFFER's agent last changed state."
  (lazyemacs-sesh--ago (or (buffer-local-value 'lazyemacs-agent--changed buffer)
                           (plist-get (lazyemacs-agent--data buffer) :created))))

(defun lazyemacs-agent--sorted (buffers)
  "Return BUFFERS most urgent first; equal states keep their order."
  (seq-sort-by (lambda (buffer)
                 (seq-position lazyemacs-agent--urgency (lazyemacs-agent-state buffer)))
               #'< buffers))

(defun lazyemacs-agent--session-agents (&optional session)
  "Return the agents of SESSION (default: the current one), most recent first."
  (let ((session (or session (lazyemacs-sesh--current))))
    (seq-filter (lambda (buffer) (equal session (lazyemacs-agent--session buffer)))
                (lazyemacs-agent-buffers))))

;;; Choosing an agent

(defvar lazyemacs-agent--candidates nil
  "The last picker's (CANDIDATE . BUFFER) pairs, for Embark actions.")

(defvar lazyemacs-agent-history nil
  "Minibuffer history of agent pickers.")

(defun lazyemacs-agent--candidate-list (buffers)
  "Return (CANDIDATE . BUFFER) pairs for BUFFERS, most urgent first."
  (let ((seen (make-hash-table :test #'equal)))
    (mapcar (lambda (buffer)
              (let* ((title (lazyemacs-agent--title buffer))
                     (count (puthash title (1+ (gethash title seen 0)) seen)))
                (cons (if (= count 1) title (format "%s <%d>" title count)) buffer)))
            (lazyemacs-agent--sorted buffers))))

(defun lazyemacs-agent--affixation (candidates)
  "Add each agent's state glyph and a description to CANDIDATES."
  (mapcar
   (lambda (candidate)
     (let* ((buffer (cdr (assoc candidate lazyemacs-agent--candidates)))
            (state (and buffer (lazyemacs-agent-state buffer)))
            (data (and buffer (lazyemacs-agent--data buffer))))
       (list candidate
             (if state (concat (lazyemacs-agent--glyph state) " ") "  ")
             (if (not buffer) ""
               (concat
                (propertize (format "  %-15s" (lazyemacs-agent--describe buffer state))
                            'face (intern (format "lazyemacs-agent-%s" state)))
                (propertize (format " %-8s" (or (plist-get data :agent) ""))
                            'face 'completions-annotations)
                (propertize (format " %-24s" (or (plist-get data :branch)
                                                 (abbreviate-file-name (or (plist-get data :directory) ""))))
                            'face 'font-lock-constant-face)
                (propertize (format " %s" (lazyemacs-agent--age buffer)) 'face 'shadow))))))
   candidates))

(defun lazyemacs-agent--read (prompt &optional buffers)
  "Read an agent with PROMPT among BUFFERS (default: all); return its buffer."
  (let ((buffers (or buffers (lazyemacs-agent-buffers))))
    (unless buffers (user-error "No agents; start one with SPC a n or SPC a a"))
    (setq lazyemacs-agent--candidates (lazyemacs-agent--candidate-list buffers))
    (let* ((candidates lazyemacs-agent--candidates)
           (group (lambda (candidate transform)
                    (if transform candidate
                      (or (when-let* ((buffer (cdr (assoc candidate candidates))))
                            (lazyemacs-agent--session buffer))
                          "No session"))))
           (choice (completing-read
                    prompt
                    (lambda (string predicate action)
                      (if (eq action 'metadata)
                          `(metadata (category . lazyemacs-agent)
                                     (group-function . ,group)
                                     (affixation-function . lazyemacs-agent--affixation)
                                     (display-sort-function . identity)
                                     (cycle-sort-function . identity))
                        (complete-with-action action candidates string predicate)))
                    nil t nil 'lazyemacs-agent-history)))
      (or (cdr (assoc choice candidates))
          (user-error "No agent called %s" choice)))))

(defun lazyemacs-agent--target (prompt &optional predicate)
  "Return the agent a command acts on, reading one with PROMPT if unclear.
Candidates satisfy PREDICATE.  The agent on the sidebar line, the current
buffer's agent, the only one shown in this tab, or the only one in this
session are used without asking."
  (let* ((candidates (seq-filter (or predicate #'always) (lazyemacs-agent-buffers)))
         (at-point (and (derived-mode-p 'lazyemacs-agents-mode)
                        (get-text-property (point) 'lazyemacs-agent)))
         (visible (seq-filter (lambda (buffer) (get-buffer-window buffer)) candidates))
         (session (seq-filter (lambda (buffer)
                                (equal (lazyemacs-agent--session buffer) (lazyemacs-sesh--current)))
                              candidates)))
    (cond ((memq at-point candidates) at-point)
          ((memq (current-buffer) candidates) (current-buffer))
          ((and visible (null (cdr visible))) (car visible))
          ((and session (null (cdr session))) (car session))
          (candidates (lazyemacs-agent--read prompt candidates))
          (t (user-error "No agent to act on")))))

;;; Showing agents

(defun lazyemacs-agent--display-side (buffer)
  "Show BUFFER in a window beside the code and return that window."
  (or (get-buffer-window buffer)
      (display-buffer buffer `((display-buffer-in-direction)
                               (direction . right) (window . main)
                               (window-width . ,lazyemacs-agent-side-width)))))

(defun lazyemacs-agent--tab-index (buffer)
  "Return the index of the tab in this frame that holds BUFFER's agent."
  (seq-position (funcall tab-bar-tabs-function) buffer
                (lambda (tab buffer)
                  (or (eq buffer (alist-get 'lazyemacs-agent (cdr tab)))
                      (and (not (eq (car tab) 'current-tab))
                           (let (found)
                             (lazyemacs-sesh--map-state
                              (alist-get 'ws (cdr tab))
                              (lambda (name)
                                (when (equal name (buffer-name buffer)) (setq found t))
                                name))
                             found))))))

(defun lazyemacs-agent--visit-session (buffer)
  "Switch to the session of BUFFER's agent, restoring it if detached."
  (let ((session (lazyemacs-agent--session buffer)))
    (when (and session (not (equal session (lazyemacs-sesh--current)))
               (or (lazyemacs-sesh--live-p session) (lazyemacs-sesh--saved-data session)))
      (lazyemacs-sesh-connect-to session))))

(defun lazyemacs-agent-show (buffer)
  "Show agent BUFFER in its session, in its own tab when it has one."
  (interactive (list (lazyemacs-agent--read "Show agent: ")))
  (lazyemacs-agent--visit-session buffer)
  (let ((window (get-buffer-window buffer)))
    (cond
     (window (select-window window))
     ((when-let* ((index (lazyemacs-agent--tab-index buffer)))
        (tab-bar-select-tab (1+ index))
        (if-let* ((window (get-buffer-window buffer)))
            (select-window window)
          (switch-to-buffer buffer))
        t))
     (t (pop-to-buffer buffer '((display-buffer-reuse-window display-buffer-same-window))))))
  buffer)

(defun lazyemacs-agent-select ()
  "Pick an agent, most urgent first, and show it.
Embark actions on a candidate: RET show, r review, c pull request,
s stop, R resume and x close."
  (interactive)
  (lazyemacs-agent-show (lazyemacs-agent--read "Agent: ")))

(defun lazyemacs-agent-next ()
  "Show the next agent that needs you, most urgent first.
Repeating walks blocked, failed and finished agents in turn."
  (interactive)
  (let* ((waiting (lazyemacs-agent--sorted
                   (seq-filter (lambda (buffer)
                                 (memq (lazyemacs-agent-state buffer) lazyemacs-agent--attention))
                               (lazyemacs-agent-buffers))))
         (position (seq-position waiting (current-buffer))))
    (cond ((null waiting) (user-error "No agent needs you"))
          ((and position (null (cdr waiting))) (message "Only this agent needs you"))
          (t (lazyemacs-agent-show
              (nth (if position (mod (1+ position) (length waiting)) 0) waiting))))))

(defun lazyemacs-agent--tab-windows ()
  "Return the windows of the selected tab that show an agent."
  (seq-filter (lambda (window) (lazyemacs-agent-p (window-buffer window)))
              (window-list nil 'nomini)))

(defun lazyemacs-agent-detach ()
  "Hide the agents shown in this tab; they keep running."
  (interactive)
  (let ((windows (lazyemacs-agent--tab-windows)))
    (unless windows (user-error "No agent is showing in this tab"))
    (dolist (window windows)
      (when (window-live-p window) (quit-window nil window)))))

(defun lazyemacs-agent-toggle (&optional choose)
  "Show this session's agent beside the code, or hide it.
With no agent in the session, start `lazyemacs-agent-default' in the
project root; with prefix argument CHOOSE, ask which agent to start."
  (interactive "P")
  (if (lazyemacs-agent--tab-windows)
      (lazyemacs-agent-detach)
    (if-let* ((buffer (car (lazyemacs-agent--session-agents))))
        (select-window (lazyemacs-agent--display-side buffer))
      (lazyemacs-agent--start
       (lazyemacs-agent--make (lazyemacs-agent--choose choose) (lazyemacs-agent--root) "")
       nil 'side))))

;;; Starting agents

(defun lazyemacs-agent--root ()
  "Return the project root, or the current directory outside a project."
  (if-let* ((project (project-current nil)))
      (expand-file-name (project-root project))
    (expand-file-name default-directory)))

(defun lazyemacs-agent--choose (ask)
  "Return the agent to start, asking among the installed ones when ASK."
  (if (not ask)
      (lazyemacs-agent--default)
    (completing-read "Agent: " (or (lazyemacs-agent--installed) (mapcar #'car lazyemacs-agents))
                     nil t nil nil (lazyemacs-agent--default))))

(defun lazyemacs-agent--buffer-name (data)
  "Return a buffer name for the agent DATA."
  (generate-new-buffer-name
   (format "*%s: %s*" (plist-get data :agent)
           (truncate-string-to-width
            (let ((task (plist-get data :task)))
              (if (and task (not (string-empty-p task))) task
                (file-name-nondirectory (directory-file-name (plist-get data :directory)))))
            40 nil nil "…"))))

(defun lazyemacs-agent--claim-tab (buffer data)
  "Name the selected tab after DATA's task and mark it as BUFFER's tab."
  (tab-bar-rename-tab (truncate-string-to-width
                       (let ((task (plist-get data :task)))
                         (if (string-empty-p task) (plist-get data :agent) task))
                       24 nil nil "…"))
  (setf (alist-get 'lazyemacs-agent (cdr (tab-bar--current-tab-find))) buffer))

(defun lazyemacs-agent--exec (buffer data resume prompt &optional argv)
  "Run agent DATA in terminal BUFFER, RESUME or with PROMPT; return BUFFER.
ARGV, when given, is the command already built by `lazyemacs-agent--command'."
  (require 'ghostel)
  (let ((argv (or argv (lazyemacs-agent--command data resume prompt))))
    (with-current-buffer buffer
      (setq default-directory (plist-get data :directory))
      (ghostel-exec buffer (car argv) (cdr argv)))
    (with-current-buffer buffer
      (setq-local lazyemacs-agent data
                  lazyemacs-agent--changed (float-time)
                  ;; Keep a finished agent's output; RET resumes from the list.
                  ghostel-kill-buffer-on-exit nil
                  ;; `done' means unread: looking at the agent acknowledges it.
                  ghostel-status-auto-acknowledge 'seen
                  ;; This module notifies about agents itself.
                  ghostel-notification-functions nil)
      (add-hook 'kill-buffer-hook #'lazyemacs-agent--schedule-refresh nil t))
    (lazyemacs-agent--schedule-refresh)
    buffer))

(defun lazyemacs-agent--start (data prompt display)
  "Start agent DATA with PROMPT and return its buffer.
DISPLAY is `tab' for a new tab in this session, `here' to replace this
tab's windows, or `side' to show it beside the code."
  (lazyemacs-agent--require-terminal)
  (let* ((argv (lazyemacs-agent--command data nil prompt))
         (buffer (get-buffer-create (lazyemacs-agent--buffer-name data))))
    (with-current-buffer buffer (setq default-directory (plist-get data :directory)))
    ;; Show the buffer first: the terminal takes the size of its window.
    (pcase display
      ('tab (let ((tab-bar-new-tab-choice "*scratch*")) (tab-bar-new-tab))
            (switch-to-buffer buffer)
            (lazyemacs-agent--claim-tab buffer data))
      ('here (delete-other-windows)
             (switch-to-buffer buffer)
             (lazyemacs-agent--claim-tab buffer data))
      (_ (select-window (lazyemacs-agent--display-side buffer))))
    (condition-case err
        (lazyemacs-agent--exec buffer data nil prompt argv)
      (error (kill-buffer buffer)
             (signal (car err) (cdr err))))))

(defun lazyemacs-agent--slug (text)
  "Return TEXT as a short branch-name fragment."
  (let ((slug (string-trim (replace-regexp-in-string "[^a-z0-9]+" "-" (downcase text)) "-+" "-+")))
    (string-trim-right (truncate-string-to-width slug 40) "-+")))

(defun lazyemacs-agent--branch-for (root task agent)
  "Return an unused branch name in ROOT's repository for TASK run by AGENT."
  (let* ((slug (lazyemacs-agent--slug task))
         (base (concat lazyemacs-agent-branch-prefix
                       (if (string-empty-p slug)
                           (format "%s-%s" agent (format-time-string "%m%d-%H%M"))
                         slug)))
         (branch base)
         (suffix 2))
    (while (lazyemacs-sesh--git root "show-ref" "--verify" "--quiet" (concat "refs/heads/" branch))
      (setq branch (format "%s-%d" base suffix)
            suffix (1+ suffix)))
    branch))

(defun lazyemacs-agent--new-arguments ()
  "Read the arguments of `lazyemacs-agent-new'."
  (let* ((agent (lazyemacs-agent--choose current-prefix-arg))
         (task (read-string (format "Task for %s (empty starts it without one): " agent)))
         (root (lazyemacs-agent--root))
         (where (if (and (not (file-remote-p root)) (lazyemacs-sesh--worktrees root))
                    (pcase (car (read-multiple-choice
                                 "Run it in"
                                 '((?h "here" "This checkout, in a new tab of this session")
                                   (?w "worktree" "A new Git worktree, branch and session"))))
                      (?w 'worktree)
                      (_ 'here))
                  'here)))
    (list task agent where)))

(defun lazyemacs-agent-new (task agent where)
  "Start AGENT on TASK, WHERE is `here' or `worktree'; return its buffer.
Here, the agent gets a new tab in this session.  In a worktree, it gets a
new branch named after the task, a worktree beside the repository and a
session of its own, as `SPC TAB w' makes.  TASK is the agent's first
prompt.  With a prefix argument, ask which agent to start."
  (interactive (lazyemacs-agent--new-arguments))
  (let ((root (lazyemacs-agent--root))
        (task (string-trim task)))
    (pcase where
      ('worktree
       (let* ((base (lazyemacs-sesh--branch root))
              (branch (lazyemacs-agent--branch-for root task agent)))
         ;; Check the agent before making a worktree that would sit unused.
         (lazyemacs-agent--command (lazyemacs-agent--make agent root task) nil nil)
         (lazyemacs-sesh-worktree-add root branch)
         (let ((directory (or (lazyemacs-sesh--live-root (lazyemacs-sesh--current))
                              (user-error "The worktree session has no directory"))))
           (lazyemacs-agent--start
            (lazyemacs-agent--make agent directory task :worktree t :branch branch :base base)
            task 'here))))
      (_ (lazyemacs-agent--start (lazyemacs-agent--make agent root task) task 'tab)))))

;;; Sending context

(defun lazyemacs-agent--context ()
  "Capture what the current buffer can tell an agent, as a plist."
  (let* ((file (cond (buffer-file-name buffer-file-name)
                     ((derived-mode-p 'dired-mode)
                      (or (dired-get-filename nil t) default-directory))))
         (region (and (use-region-p) (cons (region-beginning) (region-end)))))
    (list :file file
          :line (line-number-at-pos)
          :region (and region (list (line-number-at-pos (car region))
                                    (line-number-at-pos (if (and (> (cdr region) (car region))
                                                                 (eq (char-before (cdr region)) ?\n))
                                                            (1- (cdr region))
                                                          (cdr region)))
                                    (buffer-substring-no-properties (car region) (cdr region))))
          :language (string-remove-suffix "-mode" (string-remove-suffix "-ts-mode" (symbol-name major-mode)))
          :diagnostics (lazyemacs-agent--diagnostics))))

(defun lazyemacs-agent--diagnostics ()
  "Return this buffer's diagnostics as (LINE LEVEL MESSAGE) lists."
  (cond
   ((bound-and-true-p flycheck-mode)
    (mapcar (lambda (error)
              (list (flycheck-error-line error) (flycheck-error-level error)
                    (flycheck-error-message error)))
            flycheck-current-errors))
   ((bound-and-true-p flymake-mode)
    (mapcar (lambda (diagnostic)
              (list (line-number-at-pos (flymake-diagnostic-beg diagnostic))
                    (flymake-diagnostic-type diagnostic)
                    (flymake-diagnostic-text diagnostic)))
            (flymake-diagnostics)))))

(defun lazyemacs-agent--path (file directory)
  "Return FILE relative to DIRECTORY when inside it, else abbreviated."
  (if (and directory (file-in-directory-p file directory))
      (file-relative-name file directory)
    (abbreviate-file-name file)))

(defun lazyemacs-agent--format (kind context directory)
  "Return KIND of CONTEXT for an agent running in DIRECTORY.
KIND is `this', `file', `selection' or `diagnostics'."
  (let* ((file (plist-get context :file))
         (path (and file (lazyemacs-agent--path file directory)))
         (region (plist-get context :region)))
    (pcase kind
      ('file (if path (concat "@" path) (user-error "This buffer has no file")))
      ('selection
       (unless region (user-error "Select some text first"))
       (pcase-let ((`(,start ,end ,text) region))
         (concat (if path (format "@%s#L%d-%d\n" path start end) "")
                 "```" (plist-get context :language) "\n"
                 (string-trim-right text "\n") "\n```\n")))
      ('diagnostics
       (unless (plist-get context :diagnostics)
         (user-error "This buffer has no diagnostics"))
       (mapconcat (pcase-lambda (`(,line ,level ,message))
                    (format "- %s:%s: %s: %s" (or path "buffer") line level message))
                  (plist-get context :diagnostics) "\n"))
      (_ (cond (region (lazyemacs-agent--format 'selection context directory))
               (path (format "@%s#L%d" path (plist-get context :line)))
               (t (user-error "Nothing to send here; open a file or select text")))))))

(defun lazyemacs-agent--send-target ()
  "Return the running agent of this session to send to, asking among several."
  (let* ((agents (seq-filter #'lazyemacs-agent--running-p (lazyemacs-agent--session-agents)))
         (visible (seq-filter #'get-buffer-window agents)))
    (cond ((null agents)
           (user-error "No running agent in this session; start one with SPC a a or SPC a n"))
          ((null (cdr agents)) (car agents))
          ((and visible (null (cdr visible))) (car visible))
          (t (lazyemacs-agent--read "Send to agent: " agents)))))

(defun lazyemacs-agent--send (text agent)
  "Paste TEXT into AGENT's prompt without submitting it, and show AGENT."
  (with-current-buffer agent (ghostel-paste-string text))
  (select-window (lazyemacs-agent--display-side agent))
  agent)

(defun lazyemacs-agent--submit (agent text)
  "Send TEXT to AGENT and submit it."
  (with-current-buffer agent (ghostel-paste-string text))
  ;; Let the agent take the paste before the Return that submits it.
  (run-at-time 0.3 nil (lambda ()
                         (when (buffer-live-p agent)
                           (with-current-buffer agent (ghostel-send-string "\r"))))))

(defun lazyemacs-agent--send-kind (kind)
  "Send KIND of the current buffer's context to this session's agent."
  (let* ((context (lazyemacs-agent--context))
         (agent (lazyemacs-agent--send-target))
         (text (lazyemacs-agent--format kind context (plist-get (lazyemacs-agent--data agent) :directory))))
    (lazyemacs-agent--send (if (string-suffix-p "\n" text) text (concat text " ")) agent)))

(defun lazyemacs-agent-send-this ()
  "Send the selection, or a reference to this line, to the session's agent."
  (interactive)
  (lazyemacs-agent--send-kind 'this))

(defun lazyemacs-agent-send-file ()
  "Send a reference to this file to the session's agent."
  (interactive)
  (lazyemacs-agent--send-kind 'file))

(defun lazyemacs-agent-send-selection ()
  "Send the selected text, with its location, to the session's agent."
  (interactive)
  (lazyemacs-agent--send-kind 'selection))

(defun lazyemacs-agent--expand (template context directory)
  "Fill TEMPLATE's placeholders from CONTEXT for an agent in DIRECTORY."
  (replace-regexp-in-string
   "{\\(this\\|file\\|selection\\|diagnostics\\)}"
   (lambda (match)
     ;; Formatting runs regexps of its own; the replacement needs this match.
     (save-match-data
       (lazyemacs-agent--format (intern (substring match 1 -1)) context directory)))
   template t t))

(defun lazyemacs-agent-prompt (name)
  "Send prompt NAME from `lazyemacs-agent-prompts' to the session's agent."
  (interactive
   (list (completing-read
          "Prompt: "
          (lambda (string predicate action)
            (if (eq action 'metadata)
                `(metadata (annotation-function
                            . ,(lambda (name)
                                 (propertize (concat "  " (car (split-string (cdr (assoc name lazyemacs-agent-prompts)) "\n")))
                                             'face 'completions-annotations))))
              (complete-with-action action lazyemacs-agent-prompts string predicate)))
          nil t)))
  (let* ((context (lazyemacs-agent--context))
         (agent (lazyemacs-agent--send-target))
         (template (or (cdr (assoc name lazyemacs-agent-prompts)) (user-error "No prompt %s" name))))
    (lazyemacs-agent--send
     (lazyemacs-agent--expand template context (plist-get (lazyemacs-agent--data agent) :directory))
     agent)))

;;; Reviewing and finishing tasks

(defun lazyemacs-agent--directory (buffer)
  "Return the existing directory BUFFER's agent works in."
  (let ((directory (plist-get (lazyemacs-agent--data buffer) :directory)))
    (unless (and directory (file-directory-p directory))
      (user-error "%s no longer exists" (or directory "The agent's directory")))
    directory))

(defun lazyemacs-agent--dirty-p (directory)
  "Return non-nil when DIRECTORY's checkout has uncommitted changes."
  (let ((status (lazyemacs-sesh--git directory "status" "--porcelain")))
    (and status (not (string-empty-p (string-trim status))))))

(defun lazyemacs-agent-review (buffer)
  "Review the changes of BUFFER's agent in Magit.
A task in its own worktree shows everything since it branched from its
base, committed or not; other agents show the checkout's status."
  (interactive (list (lazyemacs-agent--target "Review agent: ")))
  (let* ((directory (lazyemacs-agent--directory buffer))
         (base (plist-get (lazyemacs-agent--data buffer) :base))
         (fork (and base (lazyemacs-sesh--git directory "merge-base" base "HEAD"))))
    (lazyemacs-agent--visit-session buffer)
    (let ((default-directory directory))
      (cond ((not (require 'magit nil t)) (vc-dir directory))
            ((and fork (not (string-empty-p (string-trim fork))))
             (magit-diff-working-tree (string-trim fork)))
            (t (magit-status-setup-buffer directory))))))

(defun lazyemacs-agent-pull-request (buffer)
  "Push the branch of BUFFER's agent and open a pull request.
Uncommitted changes come first: the agent can commit them, or Magit opens
for you to.  The pull request is opened with the GitHub CLI when installed."
  (interactive (list (lazyemacs-agent--target "Pull request for agent: ")))
  (let* ((directory (lazyemacs-agent--directory buffer))
         (branch (or (lazyemacs-sesh--branch directory)
                     (user-error "%s is not on a Git branch" (abbreviate-file-name directory)))))
    (cond
     ((lazyemacs-agent--dirty-p directory)
      (if (and (lazyemacs-agent--running-p buffer)
               (y-or-n-p (format "Uncommitted changes in %s.  Ask the agent to commit them? "
                                 (abbreviate-file-name directory))))
          (progn (lazyemacs-agent--submit buffer lazyemacs-agent-commit-prompt)
                 (message "Asked the agent to commit; run SPC a c again when it is done"))
        (if (require 'magit nil t) (magit-status-setup-buffer directory) (vc-dir directory))
        (message "Commit the changes, then run SPC a c again")))
     ((y-or-n-p (format "Push %s to origin and open a pull request? " branch))
      (let ((default-directory directory))
        (compile (concat "git push -u origin HEAD"
                         (if (executable-find "gh") " && gh pr create --web --fill" ""))))
      (unless (executable-find "gh")
        (message "Pushing %s; install the GitHub CLI (gh) to open pull requests from here"
                 branch))))))

(defun lazyemacs-agent--kill (buffer)
  "Kill agent BUFFER and its process without asking."
  (when (buffer-live-p buffer)
    (let ((kill-buffer-query-functions nil)
          (ghostel-query-before-killing nil))
      (kill-buffer buffer))))

(defun lazyemacs-agent--swap (old new)
  "Show NEW wherever agent buffer OLD is shown, and hand it OLD's tabs."
  (dolist (window (get-buffer-window-list old nil t))
    (set-window-buffer window new))
  (dolist (frame (frame-list))
    (dolist (tab (funcall tab-bar-tabs-function frame))
      (when (eq old (alist-get 'lazyemacs-agent (cdr tab)))
        (setf (alist-get 'lazyemacs-agent (cdr tab)) new)))))

(defun lazyemacs-agent--replace (buffer make)
  "Replace agent BUFFER by the buffer MAKE returns, keeping BUFFER's name.
MAKE is called with the name; BUFFER is killed afterwards."
  (let ((name (buffer-name buffer)))
    (with-current-buffer buffer
      (rename-buffer (generate-new-buffer-name (concat " " name " (old)"))))
    (let ((new (funcall make name)))
      (lazyemacs-agent--swap buffer new)
      (lazyemacs-agent--kill buffer)
      (lazyemacs-agent--schedule-refresh)
      new)))

(defun lazyemacs-agent-stop (buffer)
  "Stop BUFFER's agent; resume it later with RET or `SPC a R'."
  (interactive (list (lazyemacs-agent--target "Stop agent: " #'lazyemacs-agent--running-p)))
  (unless (lazyemacs-agent--managed-p buffer)
    (user-error "LazyEmacs did not start %s; stop it in its terminal" (buffer-name buffer)))
  (when (or (not (called-interactively-p 'any))
            (y-or-n-p (format "Stop %s? " (lazyemacs-agent--title buffer))))
    (let ((data (buffer-local-value 'lazyemacs-agent buffer)))
      (lazyemacs-agent--replace buffer (lambda (name) (lazyemacs-agent--placeholder data name))))))

(defun lazyemacs-agent-resume (buffer)
  "Resume BUFFER's stopped agent, continuing its conversation."
  (interactive (list (lazyemacs-agent--target
                      "Resume agent: "
                      (lambda (buffer) (and (lazyemacs-agent--managed-p buffer)
                                            (not (lazyemacs-agent--running-p buffer)))))))
  (when (lazyemacs-agent--running-p buffer)
    (user-error "%s is already running" (lazyemacs-agent--title buffer)))
  (lazyemacs-agent--require-terminal)
  (let* ((data (copy-sequence (buffer-local-value 'lazyemacs-agent buffer)))
         (argv (progn (lazyemacs-agent--directory buffer)
                      (lazyemacs-agent--command data t nil))))
    (unless (get-buffer-window buffer)
      (lazyemacs-agent-show buffer))
    (lazyemacs-agent--replace
     buffer (lambda (name)
              (let ((new (get-buffer-create name)))
                ;; Shown before it starts, so the terminal gets the window's size.
                (lazyemacs-agent--swap buffer new)
                (lazyemacs-agent--exec new data t nil argv))))))

(defun lazyemacs-agent-close (buffer)
  "Close the task of BUFFER's agent: stop it and close its tab.
A task in its own worktree also loses its session and the worktree;
its branch is kept."
  (interactive (list (lazyemacs-agent--target "Close agent task: " #'lazyemacs-agent--managed-p)))
  (let* ((data (lazyemacs-agent--data buffer))
         (title (lazyemacs-agent--title buffer))
         (directory (plist-get data :directory))
         (worktree (and (plist-get data :worktree) directory (file-directory-p directory)
                        (lazyemacs-sesh--dir directory)))
         (session (and worktree (lazyemacs-sesh--live-for-root worktree)))
         (victims (and session (lazyemacs-sesh--kill-candidates session worktree)))
         force)
    (when (y-or-n-p (if worktree
                        (format "Close %s, its session and worktree %s (branch %s stays)? "
                                title (abbreviate-file-name worktree) (plist-get data :branch))
                      (format "Close %s? " title)))
      (when (and worktree
                 (or (lazyemacs-agent--dirty-p worktree)
                     (seq-some (lambda (victim) (and (buffer-file-name victim)
                                                     (buffer-modified-p victim)))
                               victims)))
        (unless (yes-or-no-p (format "%s has changes that are not committed.  Delete them? "
                                     (abbreviate-file-name worktree)))
          (user-error "Kept %s; commit or stash its changes first" title))
        (setq force t))
      ;; Close a task's own tab, unless it is the last one of its session.
      (let ((index (lazyemacs-agent--tab-index buffer)))
        (when (and index (not worktree)
                   (cdr (project-tab-sessions--tabs (lazyemacs-agent--session buffer))))
          (tab-bar-close-tab (1+ index))))
      (lazyemacs-agent--kill buffer)
      (when worktree
        (let ((main (car (lazyemacs-sesh--worktrees worktree)))
              (saved (or session (plist-get (lazyemacs-sesh--saved-for-root worktree) :name))))
          (when session
            (let ((lazyemacs-sesh--inhibit-save t)) (lazyemacs-sesh--close session)))
          (dolist (victim victims)
            (when (buffer-live-p victim)
              (with-current-buffer victim (set-buffer-modified-p nil))
              (lazyemacs-agent--kill victim)))
          (when (and saved (file-exists-p (lazyemacs-sesh--file saved)))
            (lazyemacs-sesh-forget saved))
          (with-temp-buffer
            (let ((default-directory (or main temporary-file-directory)))
              (unless (eq 0 (apply #'call-process "git" nil t nil "worktree" "remove"
                                   (append (and force '("--force")) (list worktree))))
                (user-error "git worktree remove failed: %s" (string-trim (buffer-string))))))))
      (lazyemacs-agent--schedule-refresh)
      (message "Closed %s%s" title
               (if worktree (format "; branch %s is kept" (plist-get data :branch)) "")))))

;;; Stopped agents

(defvar-keymap lazyemacs-agent-placeholder-mode-map
  :doc "Keys of a stopped agent."
  :parent special-mode-map
  "RET" #'lazyemacs-agent-resume
  "r" #'lazyemacs-agent-review
  "c" #'lazyemacs-agent-pull-request
  "x" #'lazyemacs-agent-close)

(define-derived-mode lazyemacs-agent-placeholder-mode special-mode "Agent (stopped)"
  "A stopped agent, saved with its session; RET resumes it."
  (setq-local truncate-lines t))

(defun lazyemacs-agent--placeholder (data &optional name)
  "Return a buffer standing for the stopped agent DATA, called NAME."
  (let* ((buffer (get-buffer-create (or name (lazyemacs-agent--buffer-name data))))
         (directory (plist-get data :directory)))
    (with-current-buffer buffer
      (lazyemacs-agent-placeholder-mode)
      (setq-local lazyemacs-agent data
                  lazyemacs-agent--changed (float-time))
      (setq default-directory (if (and directory (file-directory-p directory))
                                  directory
                                (expand-file-name "~/")))
      (add-hook 'kill-buffer-hook #'lazyemacs-agent--schedule-refresh nil t)
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (lazyemacs-agent--glyph 'stopped) " "
                (propertize (format "%s — %s" (plist-get data :agent) (lazyemacs-agent--title buffer))
                            'face 'bold)
                "\n\nStopped.  RET resumes the conversation, r reviews its changes,\n"
                "c opens a pull request and x closes the task.\n\n")
        (insert (format "Directory  %s%s\n" (abbreviate-file-name (or directory ""))
                        (if (and directory (file-directory-p directory)) "" " (gone)")))
        (when-let* ((branch (plist-get data :branch)))
          (insert (format "Branch     %s%s\n" branch
                          (if-let* ((base (plist-get data :base))) (format " (from %s)" base) ""))))
        (insert (format "Session    %s\n" (or (plist-get data :session) "none")))
        (goto-char (point-min))))
    buffer))

;;; Saving agents with their sessions

(defconst lazyemacs-agent--saved-keys
  '(:agent :id :task :name :directory :session :worktree :branch :base :created)
  "Keys of an agent's data that sessions save.")

(defun lazyemacs-agent--saved-data (buffer &optional session)
  "Return BUFFER's agent data to save, owned by SESSION when given."
  (let ((data (buffer-local-value 'lazyemacs-agent buffer)) result)
    (dolist (key lazyemacs-agent--saved-keys)
      (when-let* ((value (if (and session (eq key :session)) session (plist-get data key))))
        (setq result (append result (list key value)))))
    result))

(defun lazyemacs-agent--buffer-spec (buffer)
  "Describe agent BUFFER for a saved layout, or nil if it is not an agent."
  (when (lazyemacs-agent--managed-p buffer)
    (list :agent (lazyemacs-agent--saved-data buffer))))

(defun lazyemacs-agent--restore-buffer (spec name)
  "Recreate the agent SPEC from a saved layout as NAME, or nil."
  (pcase spec
    (`(:agent ,data)
     (or (lazyemacs-agent--find (plist-get data :id))
         (lazyemacs-agent--placeholder
          data (if (get-buffer name) (generate-new-buffer-name name) name))))))

(defun lazyemacs-agent--session-data (name)
  "Return session NAME's agents to save, as (:agents LIST)."
  (when-let* ((agents (seq-filter (lambda (buffer)
                                    (and (lazyemacs-agent--managed-p buffer)
                                         (equal name (lazyemacs-agent--session buffer))))
                                  (lazyemacs-agent-buffers))))
    (list :agents (mapcar (lambda (buffer) (lazyemacs-agent--saved-data buffer name)) agents))))

(defun lazyemacs-agent--restore-session (data)
  "Bring back the agents of restored session DATA that no layout showed."
  (dolist (agent (plist-get data :agents))
    (unless (lazyemacs-agent--find (plist-get agent :id))
      (lazyemacs-agent--placeholder agent)))
  (lazyemacs-agent--schedule-refresh))

;;; Status changes and notifications

(defun lazyemacs-agent--emacs-focused-p ()
  "Return non-nil when an Emacs frame has keyboard focus."
  (seq-some (lambda (frame) (memq (frame-focus-state frame) '(t unknown))) (frame-list)))

(defun lazyemacs-agent--desktop-notify (title body)
  "Show a desktop notification with TITLE and BODY, where possible."
  (cond ((and (require 'alert nil t) (fboundp 'alert)) (alert body :title title))
        ((and (eq system-type 'darwin) (executable-find "osascript"))
         (let ((quote (lambda (text)
                        (concat "\"" (replace-regexp-in-string "[\"\\]" "\\\\\\&" text) "\""))))
           (call-process "osascript" nil 0 nil "-e"
                         (format "display notification %s with title %s"
                                 (funcall quote body) (funcall quote title)))))
        ((and (featurep 'dbusbind) (require 'notifications nil t))
         (ignore-errors (notifications-notify :title title :body body)))))

(defun lazyemacs-agent--message (buffer)
  "Return the message of BUFFER's most urgent status record, or nil.
Claude Code says what it waits for, as in \"approve Write: notes.md\"."
  (and (boundp 'ghostel-program-status)
       (plist-get (cdr (car (lazyemacs-agent--sorted-records buffer))) :msg)))

(defun lazyemacs-agent--sorted-records (buffer)
  "Return BUFFER's status records, most urgent first."
  (seq-sort-by (lambda (entry)
                 (or (seq-position lazyemacs-agent--urgency (plist-get (cdr entry) :state)) 99))
               #'< (buffer-local-value 'ghostel-program-status buffer)))

(defun lazyemacs-agent--notify (buffer state)
  "Tell the user that BUFFER's agent entered STATE."
  (when lazyemacs-agent-notify
    (let ((text (concat (format "%s %s" (lazyemacs-agent--title buffer)
                                (lazyemacs-agent--describe buffer state))
                        (when-let* ((message (lazyemacs-agent--message buffer)))
                          (format " (%s)" message)))))
      (message "Agent %s %s (SPC a j to go there)" (lazyemacs-agent--glyph state) text)
      (when (and (eq lazyemacs-agent-notify t) (not (lazyemacs-agent--emacs-focused-p)))
        (lazyemacs-agent--desktop-notify "Emacs agent" text)))))

(defun lazyemacs-agent--status-changed (_id old new)
  "Note an agent's status change from OLD to NEW; in the terminal buffer.
A member of `ghostel-program-status-functions'."
  (when (lazyemacs-agent-p (current-buffer))
    (setq lazyemacs-agent--changed (float-time))
    (let ((state (plist-get new :state)))
      (when (and lazyemacs-agent
                 (memq state lazyemacs-agent--attention)
                 (not (eq state (plist-get old :state)))
                 (not (ghostel--buffer-focused-p (current-buffer))))
        (lazyemacs-agent--notify (current-buffer) state)))
    (lazyemacs-agent--schedule-refresh)))

(defun lazyemacs-agent--exited (buffer _event)
  "Note that BUFFER's terminal process exited."
  (when (lazyemacs-agent-p buffer)
    (with-current-buffer buffer (setq lazyemacs-agent--changed (float-time)))
    (lazyemacs-agent--schedule-refresh)))

;;; Mode line and tab bar

(defvar lazyemacs-agent--snapshot nil
  "Agents at the last refresh, as (BUFFER STATE SESSION), most urgent first.")

(defvar lazyemacs-agent--mode-line-text nil
  "The mode line's agent counts, or nil when nothing counts.")

(defvar lazyemacs-agent--refresh-timer nil)

(defun lazyemacs-agent--schedule-refresh (&rest _)
  "Refresh the agent indicators soon, once for a burst of changes."
  (unless lazyemacs-agent--refresh-timer
    (setq lazyemacs-agent--refresh-timer
          (run-with-timer 0.05 nil #'lazyemacs-agent--refresh))))

(defun lazyemacs-agent--counts (entries states)
  "Return \"◆1 ●2\" counting ENTRIES in each of STATES, or nil."
  (let ((parts (delq nil (mapcar (lambda (state)
                                   (let ((count (seq-count (lambda (entry) (eq (nth 1 entry) state))
                                                           entries)))
                                     (and (> count 0)
                                          (propertize (format "%s%d" (alist-get state lazyemacs-agent-glyphs) count)
                                                      'face (intern (format "lazyemacs-agent-%s" state))))))
                                 states))))
    (and parts (string-join parts " "))))

(defvar-keymap lazyemacs-agent--mode-line-map
  :doc "Clicks on the agent counts."
  "<mode-line> <mouse-1>" #'lazyemacs-agent-select)

(defun lazyemacs-agent--refresh ()
  "Recompute the agent snapshot and the views showing it."
  (when (timerp lazyemacs-agent--refresh-timer)
    (cancel-timer lazyemacs-agent--refresh-timer))
  (setq lazyemacs-agent--refresh-timer nil)
  (setq lazyemacs-agent--snapshot
        (mapcar (lambda (buffer)
                  (list buffer (lazyemacs-agent-state buffer) (lazyemacs-agent--session buffer)))
                (lazyemacs-agent--sorted (lazyemacs-agent-buffers))))
  (setq lazyemacs-agent--mode-line-text
        (when-let* ((text (lazyemacs-agent--counts lazyemacs-agent--snapshot
                                                   '(blocked error done working))))
          (propertize (concat " " text " ")
                      'mouse-face 'mode-line-highlight
                      'local-map lazyemacs-agent--mode-line-map
                      'help-echo (mapconcat (pcase-lambda (`(,buffer ,state ,session))
                                              (format "%s %s — %s (%s)"
                                                      (alist-get state lazyemacs-agent-glyphs)
                                                      (lazyemacs-agent--title buffer)
                                                      (lazyemacs-agent--describe buffer state)
                                                      (or session "no session")))
                                            lazyemacs-agent--snapshot "\n"))))
  (force-mode-line-update t)
  (lazyemacs-agents--sidebar-refresh))

(defun lazyemacs-agent-mode-line-string ()
  "Return the agent counts for the mode line."
  (and lazyemacs-agent-mode-line lazyemacs-agent--mode-line-text))

(defvar lazyemacs-agent-mode-line-construct '(:eval (lazyemacs-agent-mode-line-string))
  "Mode line construct counting agents by state.")
(put 'lazyemacs-agent-mode-line-construct 'risky-local-variable t)

(defun lazyemacs-agent-tab-bar-item ()
  "Tab bar items for other sessions with agents that need you."
  (let ((current (lazyemacs-sesh--current))
        sessions)
    (pcase-dolist (`(,buffer ,state ,session) lazyemacs-agent--snapshot)
      (when (and session (not (equal session current))
                 (memq state lazyemacs-agent--attention)
                 (not (assoc session sessions)))
        (push (list session buffer state) sessions)))
    (mapcar (pcase-lambda (`(,session ,buffer ,state))
              `(,(intern (format "lazyemacs-agent-session-%s" session))
                menu-item
                ,(concat " " (propertize session 'face 'shadow) (lazyemacs-agent--glyph state) " ")
                ,(lambda () (interactive) (lazyemacs-agent-show buffer))
                :help ,(format "%s: %s %s" session (lazyemacs-agent--title buffer)
                               (lazyemacs-agent--describe buffer state))))
            (nreverse sessions))))

(defvar lazyemacs-agent--tab-name-format nil
  "The tab name format function that agents' tab names extend.")

(defun lazyemacs-agent-tab-name-format (tab index)
  "Format TAB at INDEX, followed by the state of the agent it holds."
  (let ((name (funcall (or lazyemacs-agent--tab-name-format #'tab-bar-tab-name-format-default)
                       tab index))
        (buffer (alist-get 'lazyemacs-agent (cdr tab))))
    (if (and (bufferp buffer) (buffer-live-p buffer))
        (concat name (lazyemacs-agent--glyph (lazyemacs-agent-state buffer)) " ")
      name)))

;;; Sidebar

(defvar lazyemacs-agents-buffer-name "*Agents*"
  "Name of the agents sidebar buffer.")

(defvar lazyemacs-agents--sidebar-timer nil
  "Timer that keeps the sidebar's ages current while it is shown.")

(defun lazyemacs-agents--at-point ()
  "Return the agent on the sidebar line at point."
  (or (get-text-property (point) 'lazyemacs-agent)
      (user-error "No agent on this line")))

(defun lazyemacs-agents-show-at-point ()
  "Show the agent on this line, keeping the sidebar."
  (interactive)
  (let ((buffer (lazyemacs-agents--at-point)))
    (select-window (or (window-main-window) (selected-window)))
    (lazyemacs-agent-show buffer)))

(defmacro lazyemacs-agents--at-point-command (command)
  "Return a command running COMMAND on the sidebar line's agent."
  `(lambda () ,(format "Run `%s' on the agent at point." command)
     (interactive)
     (,command (lazyemacs-agents--at-point))))

(defconst lazyemacs-agents-keys
  '(("RET" . "show") ("n" . "new task") ("r" . "review") ("c" . "pull request")
    ("s" . "stop") ("R" . "resume") ("x" . "close") ("g" . "refresh")
    ("j" . "down") ("k" . "up") ("q" . "hide"))
  "The sidebar's keys and what they do, as `lazyemacs-agents-help' lists them.")

(defun lazyemacs-agents-refresh ()
  "Redraw the sidebar and the agent indicators now."
  (interactive)
  (lazyemacs-agent--refresh))

(defun lazyemacs-agents-help ()
  "List the sidebar's keys in the echo area."
  (interactive)
  (message "%s" (mapconcat (pcase-lambda (`(,key . ,label))
                             (concat (propertize key 'face 'help-key-binding) " " label))
                           lazyemacs-agents-keys "  ")))

(defvar-keymap lazyemacs-agents-mode-map
  :doc "Keys of the agents sidebar."
  :parent special-mode-map
  "?" #'lazyemacs-agents-help
  "RET" #'lazyemacs-agents-show-at-point
  "j" #'next-line
  "k" #'previous-line
  "n" #'lazyemacs-agent-new
  "g" #'lazyemacs-agents-refresh
  "r" (lazyemacs-agents--at-point-command lazyemacs-agent-review)
  "c" (lazyemacs-agents--at-point-command lazyemacs-agent-pull-request)
  "s" (lazyemacs-agents--at-point-command lazyemacs-agent-stop)
  "R" (lazyemacs-agents--at-point-command lazyemacs-agent-resume)
  "x" (lazyemacs-agents--at-point-command lazyemacs-agent-close))

(define-derived-mode lazyemacs-agents-mode special-mode "Agents"
  "The agents of every session, most urgent first.
\\{lazyemacs-agents-mode-map}"
  (setq-local truncate-lines t
              cursor-type nil
              display-line-numbers nil))

(defun lazyemacs-agents--render ()
  "Draw the sidebar in the current buffer."
  (let* ((inhibit-read-only t)
         (line (line-number-at-pos))
         (window (get-buffer-window (current-buffer)))
         (width (if window (window-width window) lazyemacs-agent-sidebar-width))
         (groups nil))
    (pcase-dolist (`(,buffer ,state ,session) lazyemacs-agent--snapshot)
      (let ((group (or session "No session")))
        (if-let* ((entry (assoc group groups)))
            (setcdr entry (append (cdr entry) (list (cons buffer state))))
          (setq groups (append groups (list (list group (cons buffer state))))))))
    (erase-buffer)
    (insert (propertize " Agents" 'face 'bold)
            (propertize "  n new · RET show · ? keys" 'face 'shadow) "\n")
    (unless groups
      (insert "\n " (propertize "No agents.  n starts one." 'face 'shadow) "\n"))
    (pcase-dolist (`(,group . ,entries) groups)
      (insert "\n " (propertize group 'face (if (equal group (lazyemacs-sesh--current))
                                              'font-lock-keyword-face 'font-lock-function-name-face))
              "\n")
      (pcase-dolist (`(,buffer . ,state) entries)
        (let* ((age (lazyemacs-agent--age buffer))
               (title (truncate-string-to-width (lazyemacs-agent--title buffer)
                                                (max 8 (- width (length age) 7)) nil nil "…")))
          (insert (propertize
                   (concat "  " (lazyemacs-agent--glyph state) " " title
                           (make-string (max 1 (- width (string-width title) (length age) 6)) ?\s)
                           (propertize age 'face 'shadow) "\n")
                   'lazyemacs-agent buffer
                   'help-echo (format "%s — %s%s" (plist-get (lazyemacs-agent--data buffer) :agent)
                                      (lazyemacs-agent--describe buffer state)
                                      (if-let* ((message (lazyemacs-agent--message buffer)))
                                          (concat ": " message) "")))))))
    (goto-char (point-min))
    (forward-line (1- line))))

(defun lazyemacs-agents--sidebar-refresh ()
  "Redraw the sidebar when it is shown; stop its timer when it is not."
  (if-let* ((buffer (get-buffer lazyemacs-agents-buffer-name))
            ((get-buffer-window buffer t)))
      (with-current-buffer buffer (lazyemacs-agents--render))
    (when (timerp lazyemacs-agents--sidebar-timer)
      (cancel-timer lazyemacs-agents--sidebar-timer)
      (setq lazyemacs-agents--sidebar-timer nil))))

(defun lazyemacs-agents-sidebar ()
  "Show or hide the sidebar listing every session's agents."
  (interactive)
  (let ((buffer (get-buffer-create lazyemacs-agents-buffer-name)))
    (if-let* ((window (get-buffer-window buffer)))
        (delete-window window)
      (with-current-buffer buffer
        (unless (derived-mode-p 'lazyemacs-agents-mode) (lazyemacs-agents-mode)))
      (display-buffer-in-side-window
       buffer `((side . right) (slot . 1) (window-width . ,lazyemacs-agent-sidebar-width)
                (preserve-size . (t . nil))
                (window-parameters (no-delete-other-windows . t))))
      (lazyemacs-agent--refresh)
      (unless (timerp lazyemacs-agents--sidebar-timer)
        (setq lazyemacs-agents--sidebar-timer
              (run-with-timer 30 30 #'lazyemacs-agents--sidebar-refresh))))))

;;; Dashboard and doctor

(defun lazyemacs-agent-dashboard-insert (indent width)
  "Insert up to five agents into the dashboard at INDENT, WIDTH wide."
  (when-let* ((entries (seq-take (or lazyemacs-agent--snapshot
                                     (progn (lazyemacs-agent--refresh) lazyemacs-agent--snapshot))
                                 5)))
    (insert "\n" (make-string indent ?\s)
            (propertize "Agents" 'face 'lazyemacs-dashboard-heading) "\n")
    (pcase-dolist (`(,buffer ,state ,session) entries)
      (let* ((where (or session ""))
             (label (truncate-string-to-width (lazyemacs-agent--title buffer)
                                              (max 10 (- width (length where) 4)) nil nil "…")))
        (insert (make-string indent ?\s) (lazyemacs-agent--glyph state) " ")
        (insert-text-button label 'action (lambda (_) (lazyemacs-agent-show buffer))
                            'follow-link t)
        (insert (make-string (max 1 (- width (string-width label) (length where) 2)) ?\s)
                (propertize where 'face 'shadow) "\n")))))

(defun lazyemacs-agent-doctor-section ()
  "Print which agents are installed."
  (princ "\nCoding agents (optional; SPC a)\n")
  (pcase-dolist (`(,name . ,definition) lazyemacs-agents)
    (let ((program (plist-get definition :program)))
      (princ (format "%-26s %s %s\n" name program (if (executable-find program) "ok" "not installed"))))))

;;; Embark actions

(defun lazyemacs-agent--candidate-buffer (candidate)
  "Return the agent buffer of picker CANDIDATE."
  (or (cdr (assoc candidate lazyemacs-agent--candidates))
      (user-error "No agent called %s" candidate)))

(defun lazyemacs-agent-act-show (candidate)
  "Show the agent CANDIDATE."
  (lazyemacs-agent-show (lazyemacs-agent--candidate-buffer candidate)))

(defun lazyemacs-agent-act-review (candidate)
  "Review the changes of agent CANDIDATE."
  (lazyemacs-agent-review (lazyemacs-agent--candidate-buffer candidate)))

(defun lazyemacs-agent-act-pull-request (candidate)
  "Open a pull request for agent CANDIDATE."
  (lazyemacs-agent-pull-request (lazyemacs-agent--candidate-buffer candidate)))

(defun lazyemacs-agent-act-stop (candidate)
  "Stop agent CANDIDATE."
  (let ((buffer (lazyemacs-agent--candidate-buffer candidate)))
    (when (y-or-n-p (format "Stop %s? " (lazyemacs-agent--title buffer)))
      (lazyemacs-agent-stop buffer))))

(defun lazyemacs-agent-act-resume (candidate)
  "Resume agent CANDIDATE."
  (lazyemacs-agent-resume (lazyemacs-agent--candidate-buffer candidate)))

(defun lazyemacs-agent-act-close (candidate)
  "Close the task of agent CANDIDATE."
  (lazyemacs-agent-close (lazyemacs-agent--candidate-buffer candidate)))

(defvar lazyemacs-agent-embark-map
  (let ((map (make-sparse-keymap)))
    (dolist (binding '(("RET" . lazyemacs-agent-act-show)
                       ("r" . lazyemacs-agent-act-review)
                       ("c" . lazyemacs-agent-act-pull-request)
                       ("s" . lazyemacs-agent-act-stop)
                       ("R" . lazyemacs-agent-act-resume)
                       ("x" . lazyemacs-agent-act-close)))
      (keymap-set map (car binding) (cdr binding)))
    map)
  "Embark actions on agents in `lazyemacs-agent-select'.")

(with-eval-after-load 'embark
  (set-keymap-parent lazyemacs-agent-embark-map embark-general-map)
  (add-to-list 'embark-keymap-alist '(lazyemacs-agent . lazyemacs-agent-embark-map)))

;;; Activation

(with-eval-after-load 'ghostel
  (add-hook 'ghostel-program-status-functions #'lazyemacs-agent--status-changed)
  (add-hook 'ghostel-exit-functions #'lazyemacs-agent--exited)
  ;; Claude Code shows its conversation's name as the terminal title.
  (when (fboundp 'ghostel--update-title)
    (advice-add 'ghostel--update-title :after #'lazyemacs-agent--title-changed)))

(add-hook 'lazyemacs-sesh-buffer-spec-functions #'lazyemacs-agent--buffer-spec)
(add-hook 'lazyemacs-sesh-restore-buffer-functions #'lazyemacs-agent--restore-buffer)
(add-hook 'lazyemacs-sesh-save-functions #'lazyemacs-agent--session-data)
(add-hook 'lazyemacs-sesh-restore-functions #'lazyemacs-agent--restore-session)
(add-hook 'tab-bar-tab-post-select-functions #'lazyemacs-agent--schedule-refresh)
(add-hook 'lazyemacs-doctor-sections #'lazyemacs-agent-doctor-section 40)

(unless (eq tab-bar-tab-name-format-function #'lazyemacs-agent-tab-name-format)
  (setq lazyemacs-agent--tab-name-format tab-bar-tab-name-format-function
        tab-bar-tab-name-format-function #'lazyemacs-agent-tab-name-format))
(unless (memq #'lazyemacs-agent-tab-bar-item tab-bar-format)
  (setq tab-bar-format (append tab-bar-format '(lazyemacs-agent-tab-bar-item))))
(unless (member 'lazyemacs-agent-mode-line-construct (ensure-list global-mode-string))
  ;; A mode-line list starting with a symbol is a conditional, so lead with "".
  (setq global-mode-string
        (append (if (and (consp global-mode-string) (stringp (car global-mode-string)))
                    global-mode-string
                  (cons "" (ensure-list global-mode-string)))
                '(lazyemacs-agent-mode-line-construct))))

(with-eval-after-load 'init-keymaps
  (dolist (map (list lazyemacs-agents-mode-map lazyemacs-agent-placeholder-mode-map))
    (keymap-set map "SPC" my/leader-map)))
(with-eval-after-load 'evil
  ;; Emacs state, like the dashboard, so single-letter keys are not motions.
  (evil-set-initial-state 'lazyemacs-agents-mode 'emacs)
  (evil-set-initial-state 'lazyemacs-agent-placeholder-mode 'emacs))

(provide 'init-agents)
;;; init-agents.el ends here
