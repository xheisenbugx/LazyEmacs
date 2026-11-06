;;; agents-tests.el --- Coding agents in sessions -*- lexical-binding: t; -*-
(require 'ert)
(require 'cl-lib)
(require 'ghostel)

(defvar lazyemacs-agent-test-dir nil
  "Disposable directory of the running test.")

(defun lazyemacs-agent-test-script ()
  "Return a fake agent: it records its terminal device, then waits.
Tests write status reports to that device, as a real agent writes them
to its own terminal."
  (format "tty > %s/tty-$$; exec sleep 120"
          (shell-quote-argument (directory-file-name lazyemacs-agent-test-dir))))

(defmacro lazyemacs-agent-test (&rest body)
  "Run BODY with disposable sessions and a fake agent called \"fake\"."
  (declare (indent 0))
  `(let* ((lazyemacs-agent-test-dir
           (file-name-as-directory (file-truename (make-temp-file "lazyemacs-agent-" t))))
          (lazyemacs-sesh-directory (expand-file-name "var/sessions/" lazyemacs-agent-test-dir))
          (lazyemacs-sesh-state-file (expand-file-name "var/state.eld" lazyemacs-agent-test-dir))
          (lazyemacs-sesh-trust-file (expand-file-name "var/trusted.eld" lazyemacs-agent-test-dir))
          (lazyemacs-sesh-sessions nil)
          (lazyemacs-sesh--previous nil)
          (lazyemacs-sesh--inhibit-save nil)
          (lazyemacs-sesh--written (make-hash-table :test #'equal))
          (lazyemacs-sesh-open-root-function #'dired)
          (lazyemacs-dashboard nil)
          (lazyemacs-agent-notify nil)
          (tab-bar-new-tab-choice "*scratch*")
          (lazyemacs-agents `(("fake" :program "sh" :args ("-c" ,(lazyemacs-agent-test-script))))))
     (project-tab-sessions-switch "Main")
     (delete-other-windows)
     (unwind-protect (progn ,@body)
       (dolist (buffer (lazyemacs-agent-buffers)) (lazyemacs-agent--kill buffer))
       (project-tab-sessions-switch "Main")
       (delete-other-windows)
       (my/session-close-other-tabs)
       (dolist (name (lazyemacs-sesh--live-names))
         (unless (equal name "Main") (tab-bar-close-group-tabs name)))
       (dolist (buffer (buffer-list))
         (when-let* ((file (with-current-buffer buffer
                             (or buffer-file-name (and (derived-mode-p 'dired-mode) default-directory)))))
           (when (string-prefix-p lazyemacs-agent-test-dir (expand-file-name file))
             (with-current-buffer buffer (set-buffer-modified-p nil))
             (kill-buffer buffer))))
       (lazyemacs-agent--refresh)
       (ignore-error permission-denied (delete-directory lazyemacs-agent-test-dir t)))))

(defun lazyemacs-agent-test-wait (predicate)
  "Wait up to ten seconds for PREDICATE, then assert it."
  (let ((deadline (+ (float-time) 10)))
    (while (and (not (funcall predicate)) (< (float-time) deadline))
      (accept-process-output nil 0.05)))
  (should (funcall predicate)))

(defun lazyemacs-agent-test-project (name &rest files)
  "Create directory NAME in the test directory holding FILES; return it."
  (let ((root (file-name-as-directory (expand-file-name name lazyemacs-agent-test-dir))))
    (make-directory root t)
    (dolist (file files)
      (with-temp-file (expand-file-name file root) (insert "first\nsecond\nthird\n")))
    root))

(defun lazyemacs-agent-test-tty (buffer)
  "Return the terminal device of the fake agent in BUFFER."
  (lazyemacs-agent-test-wait (lambda () (lazyemacs-agent--running-p buffer)))
  (let ((file (expand-file-name (format "tty-%d" (buffer-local-value 'ghostel--pid buffer))
                                lazyemacs-agent-test-dir)))
    (lazyemacs-agent-test-wait (lambda () (and (file-exists-p file)
                                               (> (file-attribute-size (file-attributes file)) 0))))
    (with-temp-buffer (insert-file-contents file) (string-trim (buffer-string)))))

(defun lazyemacs-agent-test-report (buffer fields state)
  "Report OSC 7501 FIELDS to BUFFER's terminal, as an agent does; await STATE."
  (should (eq 0 (call-process "sh" nil nil nil "-c"
                              (format "printf '\\033]7501;%s\\007' > %s" fields
                                      (shell-quote-argument (lazyemacs-agent-test-tty buffer))))))
  (lazyemacs-agent-test-wait (lambda () (eq state (lazyemacs-agent-state buffer)))))

(defmacro lazyemacs-agent-test-needs-terminal ()
  "Skip the test where the fake agent cannot run.
Loading `ghostel' loads its native module when one is installed; without
one, starting a terminal would ask to download it, which batch Emacs
cannot answer."
  '(skip-unless (and (my/ghostel-available-p) (featurep 'ghostel-module)
                     (executable-find "sh")
                     (not (memq system-type '(windows-nt ms-dos))))))

(ert-deftest lazyemacs-agent/claude-and-codex-commands ()
  (cl-letf (((symbol-function 'executable-find) (lambda (&rest _) "/usr/bin/found")))
    (let* ((default-directory temporary-file-directory)
           (claude (lazyemacs-agent--make "claude" default-directory "Fix the bug"))
           (id (plist-get claude :id))
           (start (lazyemacs-agent--command claude nil "Fix the bug"))
           (resume (lazyemacs-agent--command claude t nil)))
      (should (string-match-p "\\`[0-9a-f]\\{8\\}-[0-9a-f]\\{4\\}-4" id))
      ;; The conversation id is the agent's, so resuming finds it exactly.
      (should (equal start (list "claude" "--session-id" id "--name" "Fix the bug" "Fix the bug")))
      (should (equal resume (list "claude" "--resume" id)))
      ;; A task starting with a dash is not read as an option.
      (should (equal (car (last (lazyemacs-agent--command claude nil "-v is broken"))) " -v is broken"))
      (let ((codex (lazyemacs-agent--make "codex" default-directory "Port it")))
        (should (equal (lazyemacs-agent--command codex nil "Port it") '("codex" "Port it")))
        (should (equal (lazyemacs-agent--command codex t nil) '("codex" "resume" "--last"))))
      ;; Plain argument lists get the prompt last and start afresh to resume.
      (let ((lazyemacs-agents '(("aider" :program "aider" :args ("--no-auto-commits")))))
        (should (equal (lazyemacs-agent--command (lazyemacs-agent--make "aider" "/" "") nil "Go")
                       '("aider" "--no-auto-commits" "Go")))
        (should (equal (lazyemacs-agent--command (lazyemacs-agent--make "aider" "/" "") t "Go")
                       '("aider" "--no-auto-commits"))))))
  (cl-letf (((symbol-function 'executable-find) #'ignore))
    (should-error (lazyemacs-agent--command (lazyemacs-agent--make "claude" "/" "") nil nil)
                  :type 'user-error)))

(ert-deftest lazyemacs-agent/status-reaches-every-view ()
  (lazyemacs-agent-test-needs-terminal)
  (lazyemacs-agent-test
    (let ((root (lazyemacs-agent-test-project "shop" "cart.el"))
          notified buffer)
      (lazyemacs-sesh-connect-to root)
      (setq buffer (lazyemacs-agent-new "Fix the cart" "fake" 'here))
      (should (equal (plist-get (lazyemacs-agent--data buffer) :session) "shop"))
      (should (eq (window-buffer) buffer))
      (should (equal (alist-get 'name (tab-bar--current-tab-find)) "Fix the cart"))
      (lazyemacs-agent-test-wait (lambda () (eq 'idle (lazyemacs-agent-state buffer))))
      (lazyemacs-agent-test-report buffer "state=working:app=fake" 'working)
      ;; Look elsewhere, so a change needs your attention.
      (lazyemacs-sesh-connect-to "Main")
      (cl-letf (((symbol-function 'lazyemacs-agent--notify)
                 (lambda (agent state) (push (cons agent state) notified))))
        (lazyemacs-agent-test-report
         buffer (concat "state=blocked:kind=permission:app=fake:msg="
                        (base64-encode-string "approve Write: cart.el"))
         'blocked))
      (should (equal notified (list (cons buffer 'blocked))))
      (should (equal (lazyemacs-agent--describe buffer 'blocked) "needs approval"))
      (should (equal (lazyemacs-agent--message buffer) "approve Write: cart.el"))
      (lazyemacs-agent--refresh)
      (should (equal (substring-no-properties (lazyemacs-agent-mode-line-string)) " ◆1 "))
      ;; The real tab bar renders them, and the mode line holds the counts.
      ;; (Batch Emacs does not evaluate :eval in `format-mode-line'.)
      (should (string-match-p "shop◆" (format "%S" (tab-bar-make-keymap-1))))
      (should (memq 'lazyemacs-agent-mode-line-construct global-mode-string))
      (should (string-match-p "◆1" (eval (cadr lazyemacs-agent-mode-line-construct) t)))
      ;; The tab bar shows the other session waiting, and clicking goes there.
      (let ((item (car (lazyemacs-agent-tab-bar-item))))
        (should (string-match-p "shop◆" (substring-no-properties (nth 2 item))))
        (funcall (nth 3 item)))
      (should (equal (lazyemacs-sesh--current) "shop"))
      (should (eq (window-buffer) buffer))
      (should (string-suffix-p "◆ " (substring-no-properties
                                     (lazyemacs-agent-tab-name-format (tab-bar--current-tab-find) 2))))
      ;; SPC a j walks agents needing you, from any session.
      (lazyemacs-sesh-connect-to "Main")
      (lazyemacs-agent-next)
      (should (equal (lazyemacs-sesh--current) "shop"))
      (should (eq (current-buffer) buffer))
      (lazyemacs-agent-test-report buffer "state=done:app=fake" 'done)
      (lazyemacs-agent-test-report buffer "state=working:app=fake" 'working)
      (lazyemacs-agent--refresh)
      (should-error (lazyemacs-agent-next) :type 'user-error)
      (should (equal (substring-no-properties (lazyemacs-agent-mode-line-string)) " ●1 ")))))

(ert-deftest lazyemacs-agent/stop-resume-and-session-restore ()
  (lazyemacs-agent-test-needs-terminal)
  (lazyemacs-agent-test
    (let* ((root (lazyemacs-agent-test-project "notes" "todo.txt"))
           (_ (lazyemacs-sesh-connect-to root))
           (buffer (lazyemacs-agent-new "Tidy notes" "fake" 'here))
           (name (buffer-name buffer))
           (id (plist-get (lazyemacs-agent--data buffer) :id))
           placeholder)
      (lazyemacs-agent-test-wait (lambda () (lazyemacs-agent--running-p buffer)))
      (lazyemacs-agent-stop buffer)
      (setq placeholder (get-buffer name))
      (should-not (buffer-live-p buffer))
      (should (eq (window-buffer) placeholder))
      (should (eq (lazyemacs-agent-state placeholder) 'stopped))
      (should (equal (plist-get (lazyemacs-agent--data placeholder) :id) id))
      ;; Detaching saves the agent; reconnecting brings it back stopped.
      (lazyemacs-sesh-detach "notes")
      (let ((saved (lazyemacs-sesh--saved-data "notes")))
        (should (equal (plist-get (car (plist-get saved :agents)) :id) id))
        (should (seq-some (lambda (tab) (seq-some (lambda (entry) (eq (cadr entry) :agent))
                                                  (plist-get tab :buffers)))
                          (plist-get saved :tabs))))
      (lazyemacs-agent--kill placeholder)
      (should-not (lazyemacs-agent--find id))
      (lazyemacs-sesh-connect-to "notes")
      (setq placeholder (lazyemacs-agent--find id))
      (should (eq (window-buffer) placeholder))
      (should (equal (alist-get 'name (tab-bar--current-tab-find)) "Tidy notes"))
      (should (eq (buffer-local-value 'major-mode placeholder) 'lazyemacs-agent-placeholder-mode))
      ;; RET in the placeholder resumes the agent in place, under the same name.
      (with-current-buffer placeholder (call-interactively #'lazyemacs-agent-resume))
      (let ((resumed (lazyemacs-agent--find id)))
        (should-not (eq resumed placeholder))
        (should (equal (buffer-name resumed) (buffer-name (window-buffer))))
        (should (eq (window-buffer) resumed))
        (lazyemacs-agent-test-wait (lambda () (lazyemacs-agent--running-p resumed))))
      ;; A saved agent that no layout shows still comes back.
      (let ((data (list :agent "fake" :id "hidden-1" :task "Hidden" :directory root :session "notes")))
        (lazyemacs-agent--restore-session (list :agents (list data)))
        (should (eq (lazyemacs-agent-state (lazyemacs-agent--find "hidden-1")) 'stopped))))))

(ert-deftest lazyemacs-agent/send-context ()
  (lazyemacs-agent-test-needs-terminal)
  (lazyemacs-agent-test
    (let* ((root (lazyemacs-agent-test-project "lib" "util.txt"))
           sent agent)
      (lazyemacs-sesh-connect-to root)
      (find-file (expand-file-name "util.txt" root))
      (should-error (lazyemacs-agent-send-file) :type 'user-error)
      (setq agent (lazyemacs-agent--start (lazyemacs-agent--make "fake" root "") nil 'side))
      (lazyemacs-agent-test-wait (lambda () (lazyemacs-agent--running-p agent)))
      (cl-letf (((symbol-function 'ghostel-paste-string)
                 (lambda (text) (push (cons (current-buffer) text) sent))))
        (find-file (expand-file-name "util.txt" root))
        (goto-char (point-min))
        (forward-line 1)
        (lazyemacs-agent-send-this)
        (should (equal (pop sent) (cons agent "@util.txt#L2 ")))
        ;; Sending shows and selects the agent.
        (should (eq (window-buffer) agent))
        (find-file (expand-file-name "util.txt" root))
        (lazyemacs-agent-send-file)
        (should (equal (cdr (pop sent)) "@util.txt "))
        (find-file (expand-file-name "util.txt" root))
        (transient-mark-mode 1)
        (goto-char (point-min))
        (set-mark (point))
        (forward-line 2)
        (activate-mark)
        (lazyemacs-agent-send-selection)
        (should (equal (cdr (pop sent)) "@util.txt#L1-2\n```text\nfirst\nsecond\n```\n"))
        (find-file (expand-file-name "util.txt" root))
        (deactivate-mark)
        (goto-char (point-min))
        (lazyemacs-agent-prompt "Explain")
        (should (equal (cdr (pop sent)) "Explain @util.txt#L1.")))
      (find-file (expand-file-name "util.txt" root))
      (should-error (lazyemacs-agent-prompt "Fix diagnostics") :type 'user-error))))

(ert-deftest lazyemacs-agent/worktree-task-from-start-to-close ()
  (lazyemacs-agent-test-needs-terminal)
  (skip-unless (executable-find "git"))
  (lazyemacs-agent-test
    (let* ((root (lazyemacs-agent-test-project "repo" "README.md"))
           (git (lambda (&rest args)
                  (let ((default-directory root))
                    (should (eq 0 (apply #'call-process "git" nil nil nil args))))))
           buffer data)
      (funcall git "init" "-q" "-b" "main")
      (funcall git "add" ".")
      (funcall git "-c" "user.name=T" "-c" "user.email=t@example.invalid"
               "-c" "commit.gpgsign=false" "commit" "-q" "-m" "init")
      (lazyemacs-sesh-connect-to root)
      (setq buffer (lazyemacs-agent-new "Fix the parser!" "fake" 'worktree)
            data (lazyemacs-agent--data buffer))
      (should (equal (plist-get data :branch) "agent/fix-the-parser"))
      (should (equal (plist-get data :base) "main"))
      (should (plist-get data :worktree))
      (should (equal (plist-get data :directory)
                     (expand-file-name "repo-agent-fix-the-parser/" lazyemacs-agent-test-dir)))
      (should (equal (lazyemacs-sesh--current) "repo-agent-fix-the-parser"))
      (should (equal (lazyemacs-agent--session buffer) "repo-agent-fix-the-parser"))
      ;; A second task with the same title gets its own branch.
      (should (equal (lazyemacs-agent--branch-for root "Fix the parser!" "fake")
                     "agent/fix-the-parser-2"))
      (cl-letf (((symbol-function 'y-or-n-p) #'always))
        (lazyemacs-agent-close buffer))
      (should-not (file-directory-p (plist-get data :directory)))
      (should-not (lazyemacs-sesh--live-p "repo-agent-fix-the-parser"))
      (should-not (lazyemacs-sesh--saved-data "repo-agent-fix-the-parser"))
      (let ((default-directory root))
        (should (eq 0 (call-process "git" nil nil nil "show-ref" "--verify" "--quiet"
                                    "refs/heads/agent/fix-the-parser")))))))

(ert-deftest lazyemacs-agent/picker-sidebar-dashboard-and-other-terminals ()
  (lazyemacs-agent-test-needs-terminal)
  (lazyemacs-agent-test
    (let* ((alpha (lazyemacs-agent-test-project "alpha"))
           (beta (lazyemacs-agent-test-project "beta"))
           first second other)
      (lazyemacs-sesh-connect-to alpha)
      (setq first (lazyemacs-agent-new "Write docs" "fake" 'here))
      (lazyemacs-sesh-connect-to beta)
      (setq second (lazyemacs-agent-new "Fix tests" "fake" 'here))
      (lazyemacs-agent-test-report first "state=working:app=fake" 'working)
      (lazyemacs-agent-test-report second "state=blocked:kind=question:app=fake" 'blocked)
      ;; Any terminal whose program reports an app counts as an agent.
      (setq other (generate-new-buffer "*other terminal*"))
      (ghostel-exec other "sh" '("-c" "printf '\\033]7501;state=done:app=aider\\007'; exec sleep 120"))
      (lazyemacs-agent-test-wait (lambda () (eq 'done (lazyemacs-agent-state other))))
      (should (lazyemacs-agent-p other))
      (should-not (lazyemacs-agent--managed-p other))
      (should (equal (plist-get (lazyemacs-agent--data other) :agent) "aider"))
      ;; The picker: most urgent first, each with its state and session.
      (let ((candidates (lazyemacs-agent--candidate-list (list first second other))))
        (should (equal (mapcar #'cdr candidates) (list second other first)))
        (setq lazyemacs-agent--candidates candidates)
        (pcase-let ((`(,candidate ,prefix ,suffix) (car (lazyemacs-agent--affixation '("Fix tests")))))
          (should (equal candidate "Fix tests"))
          (should (equal (substring-no-properties prefix) "◆ "))
          (should (string-match-p "has a question" suffix)))
        (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) "Write docs")))
          (should (eq (lazyemacs-agent--read "Agent: ") first))))
      ;; s-a opens the picker too, even from inside an agent's terminal.
      (should (eq (keymap-lookup global-map "s-a") #'lazyemacs-agent-select))
      (with-current-buffer first
        (should (eq (key-binding (kbd "s-a")) #'lazyemacs-agent-select)))
      (lazyemacs-agent--refresh)
      (should (equal (substring-no-properties (lazyemacs-agent-mode-line-string)) " ◆1 ✓1 ●1 "))
      ;; The sidebar groups agents by session.
      (lazyemacs-agents-sidebar)
      (with-current-buffer lazyemacs-agents-buffer-name
        (let ((text (buffer-string)))
          (should (string-match-p "beta\n  ◆ Fix tests" text))
          (should (string-match-p "alpha\n  ● Write docs" text)))
        (goto-char (point-min))
        (search-forward "Write docs")
        (should (eq (lazyemacs-agents--at-point) first))
        ;; ? lists the keys, and every key it lists works here.
        (should (eq (key-binding "?") #'lazyemacs-agents-help))
        (should (string-match-p "RET show" (lazyemacs-agents-help)))
        (pcase-dolist (`(,key . ,_) lazyemacs-agents-keys)
          (should (commandp (key-binding (kbd key))))))
      (lazyemacs-agents-sidebar)
      (should-not (get-buffer-window lazyemacs-agents-buffer-name))
      ;; The dashboard lists them too.
      (with-temp-buffer
        (lazyemacs-agent-dashboard-insert 2 40)
        (should (string-match-p "Agents\n  ◆ Fix tests" (buffer-string))))
      (lazyemacs-agent--kill other))))

(ert-deftest lazyemacs-agent/shows-the-name-the-agent-gives-its-conversation ()
  (lazyemacs-agent-test-needs-terminal)
  (lazyemacs-agent-test
    (let* ((root (lazyemacs-agent-test-project "app"))
           (_ (lazyemacs-sesh-connect-to root))
           (buffer (lazyemacs-agent-new "" "fake" 'here))
           (name (buffer-name buffer))
           (id (plist-get (lazyemacs-agent--data buffer) :id)))
      (lazyemacs-agent-test-report buffer "state=working:app=fake" 'working)
      (should (equal (lazyemacs-agent--title buffer) "fake"))
      ;; Claude Code puts the conversation's name, after a spinner, in the title.
      (should (eq 0 (call-process "sh" nil nil nil "-c"
                                  (format "printf '\\033]2;%s\\007' > %s" "✳ Fix login bug"
                                          (shell-quote-argument (lazyemacs-agent-test-tty buffer))))))
      (lazyemacs-agent-test-wait (lambda () (equal (lazyemacs-agent--title buffer) "Fix login bug")))
      (should (equal (caar (lazyemacs-agent--candidate-list (list buffer))) "Fix login bug"))
      (lazyemacs-agent--refresh)
      (lazyemacs-agents-sidebar)
      (with-current-buffer lazyemacs-agents-buffer-name
        (should (string-match-p "● Fix login bug" (buffer-string))))
      (lazyemacs-agents-sidebar)
      ;; A stopped agent keeps the name, and its session saves it.
      (lazyemacs-agent-stop buffer)
      (should (equal (lazyemacs-agent--title (get-buffer name)) "Fix login bug"))
      (should (equal (plist-get (car (plist-get (lazyemacs-agent--session-data "app") :agents)) :name)
                     "Fix login bug"))
      (should (equal (lazyemacs-agent--title (lazyemacs-agent--find id)) "Fix login bug")))))

(ert-deftest lazyemacs-agent/stopped-claude-agent-takes-its-name-from-the-transcript ()
  (lazyemacs-agent-test
    (let* ((root (lazyemacs-agent-test-project "app"))
           (id "0b6c3c7e-1111-4222-8333-444455556666")
           (projects (expand-file-name "claude/projects/-app/" lazyemacs-agent-test-dir))
           (process-environment (cons (concat "CLAUDE_CONFIG_DIR="
                                              (expand-file-name "claude" lazyemacs-agent-test-dir))
                                      process-environment)))
      (make-directory projects t)
      (with-temp-file (expand-file-name (concat id ".jsonl") projects)
        (insert (format "{\"type\":\"ai-title\",\"aiTitle\":\"Made up\",\"sessionId\":\"%s\"}\n" id)
                (format "{\"type\":\"custom-title\",\"customTitle\":\"Old name\",\"sessionId\":\"%s\"}\n" id)
                (format "{\"type\":\"custom-title\",\"customTitle\":\"Renamed\",\"sessionId\":\"%s\"}\n" id)))
      (let ((placeholder (lazyemacs-agent--placeholder
                          (list :agent "fake" :id id :task "" :directory root :session "Main"))))
        (should (equal (lazyemacs-agent--title placeholder) "Renamed"))
        (should (equal (plist-get (lazyemacs-agent--data placeholder) :name) "Renamed")))
      ;; Without a name you gave, Claude's own title; without a transcript, the task.
      (with-temp-file (expand-file-name (concat id ".jsonl") projects)
        (insert (format "{\"type\":\"ai-title\",\"aiTitle\":\"Made up\",\"sessionId\":\"%s\"}\n" id)))
      (should (equal (lazyemacs-agent--transcript-name (list :id id)) "Made up"))
      (should-not (lazyemacs-agent--transcript-name (list :id "0b6c3c7e-0000-4000-8000-000000000000")))
      (should (equal (lazyemacs-agent--clean-name "⠐ Claude Code" '(:agent "claude")) nil)))))

(ert-deftest lazyemacs-agent/doctor-lists-agents ()
  (let ((lazyemacs-agents '(("ghost" :program "lazyemacs-no-such-agent"))))
    (should (string-match-p "ghost +lazyemacs-no-such-agent not installed"
                            (with-output-to-string (lazyemacs-agent-doctor-section))))))

(setq kill-emacs-hook nil)
(ert-run-tests-batch-and-exit "lazyemacs-agent/")
