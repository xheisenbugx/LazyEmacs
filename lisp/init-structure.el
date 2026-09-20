;;; init-structure.el --- Native tree-sitter objects and folding -*- lexical-binding: t; -*-

;;; Commentary:
;; Evil operators use the same native parsers as syntax highlighting.
;; Function and argument objects are intentionally small and grammar-aware.

;;; Code:
(require 'treesit)
(require 'evil)
(require 'seq)

(defconst my/treesit-function-types
  '("function_declaration" "function_definition" "function_expression"
    "generator_function_declaration" "generator_function" "arrow_function"
    "method_definition" "method_declaration" "function_item"))
(defconst my/treesit-argument-list-types
  '("arguments" "argument_list" "formal_parameters" "parameters"))

(defun my/treesit-node ()
  "Return the syntax node at point, requiring an active native parser."
  (unless (treesit-parser-list)
    (user-error "This buffer needs a native tree-sitter major mode and grammar"))
  (treesit-node-at (point)))

(defun my/treesit-ancestor (node types)
  "Find NODE's nearest ancestor (including itself) with one of TYPES."
  (while (and node (not (member (treesit-node-type node) types)))
    (setq node (treesit-node-parent node)))
  node)

(defun my/treesit-function-bounds (inner)
  "Return function bounds, or body bounds when INNER is non-nil."
  (let* ((node (or (my/treesit-ancestor (my/treesit-node) my/treesit-function-types)
                   (user-error "No function at point")))
         (body (if inner
                   (or (treesit-node-child-by-field-name node "body")
                       (user-error "This function has no body"))
                 node))
         (beg (treesit-node-start body))
         (end (treesit-node-end body)))
    ;; Block bodies contain braces; expression bodies and Python blocks don't.
    (when (and inner (eq (char-after beg) ?{) (eq (char-before end) ?}))
      (setq beg (1+ beg) end (1- end)))
    (cons beg end)))

(defun my/treesit-argument-bounds (outer)
  "Return argument bounds, including one adjacent comma when OUTER."
  (let* ((origin (point))
         (list-node (or (my/treesit-ancestor (my/treesit-node)
                                             my/treesit-argument-list-types)
                        (user-error "No argument or parameter list at point")))
         (children (seq-remove
                    (lambda (node) (equal (treesit-node-type node) "comment"))
                    (treesit-node-children list-node t)))
         (node (or (seq-find (lambda (child)
                               (and (<= (treesit-node-start child) origin)
                                    (< origin (treesit-node-end child)))) children)
                   (seq-find (lambda (child) (>= (treesit-node-start child) origin)) children)
                   (car (last children)))))
    (unless node (user-error "The argument list is empty"))
    (let ((beg (treesit-node-start node)) (end (treesit-node-end node)))
      (when outer
        (save-excursion
          (goto-char end)
          (skip-chars-forward " \t\n")
          (if (eq (char-after) ?,)
              (progn (forward-char) (skip-chars-forward " \t\n") (setq end (point)))
            (goto-char beg)
            (skip-chars-backward " \t\n")
            (when (eq (char-before) ?,) (setq beg (1- (point)))))))
      (cons beg end))))

(evil-define-text-object my/evil-inner-function (_count &optional _beg _end _type)
			 "Select the function body."
			 (let ((bounds (my/treesit-function-bounds t)))
			   (evil-range (car bounds) (cdr bounds) 'exclusive)))
(evil-define-text-object my/evil-a-function (_count &optional _beg _end _type)
			 "Select the whole function."
			 (let ((bounds (my/treesit-function-bounds nil)))
			   (evil-range (car bounds) (cdr bounds) 'exclusive)))
(evil-define-text-object my/evil-inner-argument (_count &optional _beg _end _type)
			 "Select the current argument."
			 (let ((bounds (my/treesit-argument-bounds nil)))
			   (evil-range (car bounds) (cdr bounds) 'exclusive)))
(evil-define-text-object my/evil-an-argument (_count &optional _beg _end _type)
			 "Select an argument and its adjacent comma."
			 (let ((bounds (my/treesit-argument-bounds t)))
			   (evil-range (car bounds) (cdr bounds) 'exclusive)))

(define-key evil-inner-text-objects-map "f" #'my/evil-inner-function)
(define-key evil-outer-text-objects-map "f" #'my/evil-a-function)
(define-key evil-inner-text-objects-map "a" #'my/evil-inner-argument)
(define-key evil-outer-text-objects-map "a" #'my/evil-an-argument)

(defun my/treesit-function-positions (root)
  "Collect nested function start positions below ROOT."
  (let ((pending (list root)) positions)
    (while pending
      (let ((node (pop pending)))
        (when (member (treesit-node-type node) my/treesit-function-types)
          (push (treesit-node-start node) positions))
        (setq pending (append (treesit-node-children node t) pending))))
    positions))

(defun my/treesit-function-motion (count)
  "Move COUNT function starts, including nested functions."
  (my/treesit-node)
  (let* ((root (treesit-parser-root-node (car (treesit-parser-list))))
         (positions (sort (my/treesit-function-positions root) #'<))
         (candidates (if (> count 0)
                         (seq-filter (lambda (p) (> p (point))) positions)
                       (reverse (seq-filter (lambda (p) (< p (point))) positions)))))
    (if-let* ((destination (nth (1- (abs count)) candidates)))
        (goto-char destination)
      (user-error "No more functions in that direction"))))

(evil-define-motion my/next-function (count)
		    "Move to the next function start."
		    :jump t
		    (my/treesit-function-motion (or count 1)))
(evil-define-motion my/previous-function (count)
		    "Move to the previous function start."
		    :jump t
		    (my/treesit-function-motion (- (or count 1))))

(defun my/open-structural-fold (overlay &rest _)
  "Reveal OVERLAY when searching or editing hidden text."
  (delete-overlay overlay))

(defun my/toggle-fold ()
  "Toggle the surrounding tree-sitter block; fall back to Hideshow."
  (interactive)
  (if (not (treesit-parser-list))
      (progn
        (require 'hideshow)
        (unless hs-minor-mode (hs-minor-mode 1))
        (hs-toggle-hiding))
    (let* ((node (or (my/treesit-ancestor
                      (my/treesit-node)
                      '("statement_block" "block" "class_body" "switch_body"))
                     (when-let* ((fn (my/treesit-ancestor
                                      (my/treesit-node) my/treesit-function-types)))
                       (treesit-node-child-by-field-name fn "body"))
                     (user-error "No structural block at point")))
           (beg (treesit-node-start node))
           (end (treesit-node-end node))
           (existing (seq-find (lambda (o) (overlay-get o 'my/structural-fold))
                               (overlays-in beg end))))
      (if existing
          (delete-overlay existing)
        (save-excursion
          (goto-char beg)
          (setq beg (line-end-position)))
        (when (<= end beg) (user-error "This block has no lines to fold"))
        (let ((overlay (make-overlay beg end)))
          (overlay-put overlay 'my/structural-fold t)
          (overlay-put overlay 'invisible t)
          (overlay-put overlay 'after-string " …")
          (overlay-put overlay 'evaporate t)
          (overlay-put overlay 'isearch-open-invisible #'my/open-structural-fold)
          (overlay-put overlay 'modification-hooks '(my/open-structural-fold)))))))

(evil-define-key 'normal 'global
		 (kbd "]m") #'my/next-function
		 (kbd "[m") #'my/previous-function
		 (kbd "za") #'my/toggle-fold)

(provide 'init-structure)
;;; init-structure.el ends here
