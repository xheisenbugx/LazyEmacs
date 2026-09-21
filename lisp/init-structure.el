;;; init-structure.el --- Native tree-sitter objects and folding -*- lexical-binding: t; -*-

;;; Commentary:
;; Evil operators use the same native parsers as syntax highlighting.
;; evil-textobj-plus owns text objects; local code supplies motions and folds.

;;; Code:
(require 'treesit)
(require 'evil)
(require 'seq)

(defconst my/treesit-function-types
  '("function_declaration" "function_definition" "function_expression"
    "generator_function_declaration" "generator_function" "arrow_function"
    "method_definition" "method_declaration" "function_item"))

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

(use-package evil-textobj-plus
  :vc (:url "https://github.com/xheisenbugx/evil-textobj-plus" :rev :newest)
  :demand t
  :custom
  (evil-textobj-plus-lines 500)
  :config
  ;; Preserve LazyVim's definition/body objects; F selects a function call.
  (setq-default evil-textobj-plus-custom-objects
                `((?f . ,(evil-textobj-plus-treesit my/treesit-function-types "body"))
                  (?F . evil-textobj-plus-calls)
                  (?a . evil-textobj-plus-treesit-arguments)))
  (evil-textobj-plus-mode 1))

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
