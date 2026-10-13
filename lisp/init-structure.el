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

;; Without a parser (or grammar), ]m and [m use the major mode's notion of a
;; defun, which every programming mode provides.
(evil-define-motion my/next-function (count)
  "Move to the next function start."
  :jump t
  (if (treesit-parser-list)
      (my/treesit-function-motion (or count 1))
    (beginning-of-defun (- (or count 1)))))

(evil-define-motion my/previous-function (count)
  "Move to the previous function start."
  :jump t
  (if (treesit-parser-list)
      (my/treesit-function-motion (- (or count 1)))
    (beginning-of-defun (or count 1))))

;;; Folding

;; Evil's z commands (za zo zc zR zM) consult `evil-fold-list'.  Buffers with
;; a parser use the tree-sitter folds below; other programming buffers use
;; Hideshow, and Org, Outline and Markdown keep Evil's outline folding.

(defconst my/treesit-fold-types
  '("statement_block" "block" "class_body" "switch_body")
  "Node types folded as blocks, in addition to function bodies.")

(defvar hs-minor-mode)

(defvar-local my/structural-folding nil
  "Non-nil when this buffer folds with tree-sitter (see `evil-fold-list').")

(defun my/open-structural-fold (overlay &rest _)
  "Reveal OVERLAY when searching or editing hidden text."
  (delete-overlay overlay))

(defun my/structural-folds (beg end)
  "Return the structural fold overlays between BEG and END."
  (seq-filter (lambda (o) (overlay-get o 'my/structural-fold)) (overlays-in beg end)))

(defun my/structural-fold-on-line ()
  "Return the fold that starts on the current line, if any.
A fold hides the text after its block's first line, so this is the fold
point sits on when the block looks collapsed."
  (seq-find (lambda (o) (<= (line-beginning-position) (overlay-start o) (line-end-position)))
            (my/structural-folds (line-beginning-position) (1+ (line-end-position)))))

(defun my/structural-fold-range (node)
  "Return the (BEG . END) region that folding NODE hides, or nil."
  (let ((beg (save-excursion (goto-char (treesit-node-start node)) (line-end-position)))
        (end (treesit-node-end node)))
    (and (< beg end) (cons beg end))))

(defun my/structural-fold-node ()
  "Return the block or function body around point."
  (or (my/treesit-ancestor (my/treesit-node) my/treesit-fold-types)
      (when-let* ((fn (my/treesit-ancestor (my/treesit-node) my/treesit-function-types)))
        (treesit-node-child-by-field-name fn "body"))
      (user-error "No structural block at point")))

(defun my/structural-fold-make (range)
  "Hide RANGE, a (BEG . END) cons, unless that exact fold already exists."
  (unless (seq-find (lambda (o) (and (= (overlay-start o) (car range))
                                     (= (overlay-end o) (cdr range))))
                    (my/structural-folds (car range) (cdr range)))
    (let ((overlay (make-overlay (car range) (cdr range))))
      (overlay-put overlay 'my/structural-fold t)
      (overlay-put overlay 'invisible t)
      (overlay-put overlay 'after-string " …")
      (overlay-put overlay 'evaporate t)
      (overlay-put overlay 'isearch-open-invisible #'my/open-structural-fold)
      (overlay-put overlay 'modification-hooks '(my/open-structural-fold))
      overlay)))

(defun my/structural-fold-open ()
  "Open the fold on the current line, or else the innermost one around point."
  (when-let* ((fold (or (my/structural-fold-on-line)
                        (car (sort (seq-filter (lambda (o) (<= (overlay-start o) (point) (overlay-end o)))
                                               (my/structural-folds (point) (1+ (point))))
                                   (lambda (a b) (> (overlay-start a) (overlay-start b))))))))
    (delete-overlay fold)
    t))

(defun my/structural-fold-close ()
  "Fold the block around point."
  (let ((range (or (my/structural-fold-range (my/structural-fold-node))
                   (user-error "This block has no lines to fold"))))
    (my/structural-fold-make range)))

(defun my/structural-fold-toggle ()
  "Open the fold on this line, or fold the block around point.
An inner fold is left alone when an enclosing block is folded or opened."
  (if-let* ((fold (my/structural-fold-on-line)))
      (delete-overlay fold)
    (let ((range (or (my/structural-fold-range (my/structural-fold-node))
                     (user-error "This block has no lines to fold"))))
      ;; Match the exact block: an inner fold inside it is not this fold.
      (if-let* ((same (seq-find (lambda (o) (and (= (overlay-start o) (car range))
                                                 (= (overlay-end o) (cdr range))))
                                (my/structural-folds (car range) (cdr range)))))
          (delete-overlay same)
        (my/structural-fold-make range)))))

(defun my/structural-fold-open-all ()
  "Remove every structural fold in this buffer."
  (mapc #'delete-overlay (my/structural-folds (point-min) (point-max))))

(defun my/structural-fold-close-all ()
  "Fold every block and function body in this buffer."
  (my/treesit-node)
  (let ((pending (list (treesit-buffer-root-node))))
    (while pending
      (let ((node (pop pending)))
        (when-let* ((target (cond ((member (treesit-node-type node) my/treesit-fold-types) node)
                                  ((member (treesit-node-type node) my/treesit-function-types)
                                   (treesit-node-child-by-field-name node "body"))))
                    (range (my/structural-fold-range target)))
          (my/structural-fold-make range))
        (setq pending (append (treesit-node-children node t) pending))))))

(defun my/toggle-fold ()
  "Toggle the fold at point: tree-sitter blocks, else Evil's fold providers."
  (interactive)
  (if (treesit-parser-list)
      (my/structural-fold-toggle)
    (my/fold-setup)
    (evil-toggle-fold)))

(defun my/fold-setup ()
  "Choose this buffer's fold provider for Evil's z commands.
Tree-sitter buffers fold syntax blocks; other programming buffers use
Hideshow.  Prose modes are left to Evil's Outline/Org support."
  (cond ((treesit-parser-list) (setq my/structural-folding t))
        ((derived-mode-p 'prog-mode)
         (require 'hideshow)
         (unless hs-minor-mode (hs-minor-mode 1)))))

(add-hook 'prog-mode-hook #'my/fold-setup)

(with-eval-after-load 'evil
  (unless (assoc '(my/structural-folding) evil-fold-list)
    (push '((my/structural-folding)
            :open-all my/structural-fold-open-all
            :close-all my/structural-fold-close-all
            :toggle my/structural-fold-toggle
            :open my/structural-fold-open
            :open-rec my/structural-fold-open
            :close my/structural-fold-close)
          evil-fold-list)))

;; Motion state, so operators and Visual state accept them too.  `za' stays
;; Evil's `evil-toggle-fold', which dispatches through `evil-fold-list'.
(evil-define-key 'motion 'global
  (kbd "]m") #'my/next-function
  (kbd "[m") #'my/previous-function)

(provide 'init-structure)
;;; init-structure.el ends here
