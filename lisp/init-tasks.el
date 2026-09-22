;;; init-tasks.el --- Project tasks and focused tests -*- lexical-binding: t; -*-

;;; Commentary:
;; Finite jobs run in compilation-mode.  Interactive jobs run in a terminal.
;; Commands are selected explicitly; opening a project never executes them.

;;; Code:
(require 'project)
(require 'compile)
(require 'json)
(require 'seq)
(require 'subr-x)

(defvar-local my/project-tasks nil
  "Extra (NAME . SHELL-COMMAND) tasks, suitable for reviewed directory locals.")
(defvar my/project-last-tasks nil "Alist of project roots and last commands.")
(defvar my/project-task-history nil "History of manually entered task commands.")
(defvar my/project-task-buffers (make-hash-table :test #'equal)
  "Compilation buffers indexed by canonical project root.")
(defvar my/project-last-tests nil
  "Last focused test command for each canonical project root.")
(defvar my/project-test-buffers (make-hash-table :test #'equal)
  "Focused test output buffers, separate from general task output.")
(with-eval-after-load 'savehist
  (add-to-list 'savehist-additional-variables 'my/project-last-tasks)
  (add-to-list 'savehist-additional-variables 'my/project-last-tests)
  (add-to-list 'savehist-additional-variables 'my/project-task-history))

(defun my/task-root ()
  "Return the current canonical project root."
  (file-name-as-directory (file-truename (project-root (project-current t)))))

(defun my/task-package (root)
  "Read ROOT's package.json, or return nil when absent."
  (let ((file (expand-file-name "package.json" root)))
    (when (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (json-parse-buffer :object-type 'alist :array-type 'list)))))

(defun my/task-package-manager (root)
  "Determine ROOT's package manager from its lockfile."
  (cond ((file-exists-p (expand-file-name "pnpm-lock.yaml" root)) "pnpm")
        ((or (file-exists-p (expand-file-name "bun.lock" root))
             (file-exists-p (expand-file-name "bun.lockb" root))) "bun")
        ((file-exists-p (expand-file-name "yarn.lock" root)) "yarn")
        (t "npm")))

(defun my/task-python-command (root)
  "Return a pytest command using ROOT's environment without installing tools."
  (let ((python (seq-find #'file-executable-p
                         (mapcar (lambda (path) (expand-file-name path root))
                                 '(".venv/bin/python" ".venv/Scripts/python.exe")))))
    (cond (python (concat (shell-quote-argument python) " -m pytest"))
          ((and (file-exists-p (expand-file-name "uv.lock" root))
                (executable-find "uv"))
           "uv run --frozen --no-sync --no-python-downloads python -m pytest")
          (t "python -m pytest"))))

(defun my/task-choices (root)
  "Discover package scripts and common test/build commands in ROOT."
  (append
   my/project-tasks
   (mapcar (lambda (script)
             (let ((name (symbol-name (car script))))
               (cons (concat "script: " name)
                     (format "%s run %s" (my/task-package-manager root)
                             (shell-quote-argument name)))))
           (alist-get 'scripts (my/task-package root)))
   (when (file-exists-p (expand-file-name "pyproject.toml" root))
     (list (cons "test: pytest" (my/task-python-command root))))
   (when (file-exists-p (expand-file-name "go.mod" root))
     '(("test: Go" . "go test ./...") ("build: Go" . "go build ./...")))
   (when (file-exists-p (expand-file-name "Cargo.toml" root))
     '(("test: Rust" . "cargo test") ("build: Rust" . "cargo build")))
   (when (file-exists-p (expand-file-name "Makefile" root))
     '(("build: make" . "make")))))

(defun my/task-read-command (root)
  "Pick a ROOT task, or enter a custom command."
  (let* ((choices (append (my/task-choices root) '(("Custom command…"))))
         (choice (completing-read "Project task: " choices nil t)))
    (or (cdr (assoc choice choices))
        (read-shell-command "Command: " nil 'my/project-task-history))))

(defun my/task-run (root command &optional test)
  "Run COMMAND in ROOT; keep TEST history and output separate from other tasks."
  (when (string-empty-p (string-trim command)) (user-error "Empty task command"))
  (let ((default-directory root)
        (name (format "*%s:%s:%s*"
                      (if test "test" "task")
                      (file-name-nondirectory (directory-file-name root))
                      (substring (secure-hash 'sha1 root) 0 8))))
    (save-some-buffers nil
                       (lambda () (and buffer-file-name
                                       (file-in-directory-p buffer-file-name root))))
    (let ((buffer (compilation-start command 'compilation-mode (lambda (_) name))))
      (if test
          (setf (alist-get root my/project-last-tests nil nil #'equal) command)
        (setf (alist-get root my/project-last-tasks nil nil #'equal) command))
      (puthash root buffer (if test my/project-test-buffers my/project-task-buffers))
      buffer)))

(defun my/project-run-task ()
  "Choose and run a task in the current project."
  (interactive)
  (let ((root (my/task-root))) (my/task-run root (my/task-read-command root))))

(defun my/project-rerun-task ()
  "Rerun this project's last finite task."
  (interactive)
  (let* ((root (my/task-root))
         (command (alist-get root my/project-last-tasks nil nil #'equal)))
    (unless command (user-error "No previous task in this project; use SPC r r"))
    (my/task-run root command)))

(defun my/project-task-output ()
  "Show this project's latest compilation buffer."
  (interactive)
  (let ((buffer (gethash (my/task-root) my/project-task-buffers)))
    (unless (buffer-live-p buffer) (user-error "No task output for this project"))
    (pop-to-buffer buffer)))

(defun my/project-task-next-error ()
  "Jump to the next failure in this project's task output."
  (interactive)
  (let ((buffer (gethash (my/task-root) my/project-task-buffers)))
    (unless (buffer-live-p buffer) (user-error "No task output for this project"))
    (with-current-buffer buffer (next-error))))

(defun my/project-task-terminal ()
  "Select a task and run it in a fresh project Ghostel shell."
  (interactive)
  (let* ((root (my/task-root))
         (command (my/task-read-command root))
         (default-directory root))
    (when (string-empty-p (string-trim command)) (user-error "Empty task command"))
    (my/terminal-send (my/project-ghostel-new) command)))

(defun my/task-js-runner (root)
  "Return the installed test runner declared by ROOT's package manifest."
  (let* ((package (my/task-package root))
         (dependencies (append (alist-get 'devDependencies package)
                               (alist-get 'dependencies package))))
    (cond ((assq 'vitest dependencies) "vitest")
          ((assq 'jest dependencies) "jest")
          (t (user-error "No Vitest/Jest dependency here; use SPC r r for a custom task")))))

(defun my/task-js-exec (root)
  "Return the command prefix that runs ROOT's installed binaries, never installing."
  (pcase (my/task-package-manager root)
    ("npm" "npm exec --no --")
    ("yarn" "yarn exec")
    ("pnpm" "pnpm exec")
    (manager (concat manager " x --no-install"))))

(defun my/task-nearest-js-test ()
  "Return the enclosing test's full literal title, including describe blocks."
  (let ((node (my/treesit-node)) titles found)
    (while node
      (when (equal (treesit-node-type node) "call_expression")
        (let* ((fn (treesit-node-child-by-field-name node "function"))
               (args (treesit-node-child-by-field-name node "arguments"))
               (first (and args (car (treesit-node-children args t))))
               (name (and fn (treesit-node-text fn t))))
          (when (and name first (equal (treesit-node-type first) "string")
                     (or (and (not found)
                              (string-match-p
                               "\\`\\(?:it\\|test\\)\\(?:\\.\\(?:only\\|skip\\)\\)?\\'" name))
                         (and found (string-match-p "\\`describe\\(?:\\.only\\)?\\'" name))))
            (let ((raw (treesit-node-text first t)))
              (when (string-match-p "\\\\" raw)
                (user-error "Escaped test titles need a custom task"))
              (push (substring raw 1 -1) titles)
              (setq found t)))))
      (setq node (treesit-node-parent node)))
    (unless found (user-error "Place point inside an it/test block with a literal title"))
    (string-join titles " ")))

(defun my/task-js-test-regexp (title)
  "Escape TITLE for a JavaScript regular expression and match it exactly."
  (concat "^"
          (mapconcat (lambda (character)
                       (concat (when (memq character
                                           '(?\\ ?. ?+ ?* ?? ?^ ?$ ?{ ?} ?\( ?\) ?| ?\[ ?\]))
                                 "\\")
                               (char-to-string character))) title "")
          "$"))

(defun my/task-test-command (root nearest)
  "Build a focused test command for the current file in ROOT.
With NEAREST, narrow to the surrounding supported test."
  (unless buffer-file-name (user-error "This buffer has no file"))
  (unless (file-in-directory-p buffer-file-name root)
    (user-error "The current file is outside the selected project"))
  (let ((file (file-relative-name buffer-file-name root)))
    (when (string-prefix-p "-" file) (setq file (concat "./" file)))
    (cond
     ((derived-mode-p 'python-mode 'python-ts-mode)
      (concat (my/task-python-command root) " "
              (shell-quote-argument
               (concat file
                       (when nearest
                         (require 'python)
                         (let ((name (python-info-current-defun)))
                           (unless (and name (string-match-p "\\(?:\\`\\|\\.\\)test_" name))
                             (user-error "Place point inside a pytest test"))
                           (concat "::" (replace-regexp-in-string "\\." "::" name))))))))
     ((derived-mode-p 'js-mode 'js-ts-mode 'typescript-mode 'typescript-ts-mode 'tsx-ts-mode)
      (let ((runner (my/task-js-runner root)))
        (concat (my/task-js-exec root) " " runner (if (equal runner "vitest") " run " " --runInBand ")
                (when (equal runner "jest") "--runTestsByPath ")
                (shell-quote-argument file)
                (when nearest
                  (concat " -t " (shell-quote-argument
                                  (my/task-js-test-regexp (my/task-nearest-js-test))))))))
     ((derived-mode-p 'go-mode 'go-ts-mode)
      (unless (string-suffix-p "_test.go" file) (user-error "Open a Go _test.go file"))
      (let ((names (save-excursion
                     (goto-char (if nearest (point) (point-min)))
                     (if nearest
                         (when (re-search-backward "^func \\(Test[A-Za-z0-9_]+\\)(" nil t)
                           (list (match-string-no-properties 1)))
                       (let (found)
                         (while (re-search-forward "^func \\(Test[A-Za-z0-9_]+\\)(" nil t)
                           (push (match-string-no-properties 1) found))
                         found)))))
        (unless names (user-error "No Go tests found"))
        (format "go test %s -run %s"
                (shell-quote-argument (concat "./" (or (file-name-directory file) "")))
                (shell-quote-argument (concat "^(" (string-join names "|") ")$")))))
     (t (user-error "Focused tests support Python, JS/TS, and Go; use SPC r r here")))))

(defun my/project-test-file ()
  "Run tests in the current file."
  (interactive)
  (let ((root (my/task-root))) (my/task-run root (my/task-test-command root nil) t)))
(defun my/project-test-nearest ()
  "Run the nearest supported test."
  (interactive)
  (let ((root (my/task-root))) (my/task-run root (my/task-test-command root t) t)))

(defun my/task-test-all-command (root)
  "Return the command that runs every test in ROOT."
  (cond
   ((seq-some (lambda (file) (file-exists-p (expand-file-name file root)))
              '("pyproject.toml" "pytest.ini" "setup.cfg" "tox.ini"))
    (my/task-python-command root))
   ((file-exists-p (expand-file-name "package.json" root))
    (let ((runner (my/task-js-runner root)))
      (concat (my/task-js-exec root) " " runner (when (equal runner "vitest") " run"))))
   ((file-exists-p (expand-file-name "go.mod" root)) "go test ./...")
   ((file-exists-p (expand-file-name "Cargo.toml" root)) "cargo test")
   (t (user-error "No known test runner here; use SPC r r for a custom task"))))

(defun my/project-test-all ()
  "Run every test in the current project."
  (interactive)
  (let ((root (my/task-root)))
    (my/task-run root (my/task-test-all-command root) t)))

(defun my/project-test-last ()
  "Repeat this project's last focused test, even after running other tasks."
  (interactive)
  (let* ((root (my/task-root))
         (command (alist-get root my/project-last-tests nil nil #'equal)))
    (unless command (user-error "No previous focused test; use SPC tt or SPC tr"))
    (my/task-run root command t)))

(defun my/project-test-output ()
  "Show this project's focused test output."
  (interactive)
  (let ((buffer (gethash (my/task-root) my/project-test-buffers)))
    (unless (buffer-live-p buffer) (user-error "No test output for this project"))
    (pop-to-buffer buffer)))

(defun my/project-test-stop ()
  "Stop only this project's running focused test."
  (interactive)
  (let* ((buffer (gethash (my/task-root) my/project-test-buffers))
         (process (and (buffer-live-p buffer) (get-buffer-process buffer))))
    (unless (and process (process-live-p process))
      (user-error "No focused test is running in this project"))
    (with-current-buffer buffer (kill-compilation))))

(provide 'init-tasks)
;;; init-tasks.el ends here
