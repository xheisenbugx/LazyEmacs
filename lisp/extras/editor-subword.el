;;; editor-subword.el --- CamelCase-aware word motions and edits -*- lexical-binding: t; -*-

;;; Commentary:
;; With `global-subword-mode', word commands stop inside identifiers such as
;; fooBarBaz: Emacs's M-f/M-b/M-d and Evil's w/b/e treat foo, Bar, and Baz as
;; separate words.  Vim does not, so this is opt-in.

;;; Code:

(global-subword-mode 1)

(provide 'editor-subword)
;;; editor-subword.el ends here
