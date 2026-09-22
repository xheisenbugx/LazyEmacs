# Configuration

LazyEmacs keeps your settings apart from the distribution, like LazyVim's
`lua/config/` and `lua/plugins/`. You never edit files under `lisp/`, so
`git pull` updates cleanly.

- [Your files](#your-files)
- [Options](#options)
- [Recipes](#recipes)
- [Mail](#mail)
- [How startup works](#how-startup-works)
- [State, backups, and privacy](#state-backups-and-privacy)

## Your files

Create them from the examples (all are optional):

```sh
mkdir -p user
cp -n examples/early.el user/early.el
cp -n examples/config.el user/config.el
```

| File | Loaded | Put here |
|---|---|---|
| `user/early.el` | Before packages and modules | `lazyemacs-*` options, fonts, theme, feature switches |
| `user/custom.el` | Right after `early.el` | Settings saved through `M-x customize` |
| `user/config.el` | Last | Keys, hooks, extra packages, overrides |

<kbd>SPC f c</kbd> opens `config.el`. Everything under `user/` is ignored by Git.
To keep these files elsewhere (for example in a dotfiles repository), set
`LAZYEMACS_USER_DIR=/path/to/dir` before Emacs starts.

## Options

Set these in `user/early.el` and restart:

| Option | Default | Effect |
|---|---|---|
| `lazyemacs-dark-theme` | `catppuccin` | Theme at startup; <kbd>SPC u b</kbd> toggles light/dark |
| `lazyemacs-light-theme` | `modus-operandi-tinted` | Light theme for the toggle |
| `lazyemacs-fonts` | Nerd Fonts, then Menlo, DejaVu Sans Mono, Cascadia Mono, Consolas | The first installed family wins |
| `lazyemacs-font-height` | `140` | Font size in tenths of a point |
| `lazyemacs-dashboard` | `t` | Show the start screen |
| `lazyemacs-prefer-tree-sitter` | `t` | Use native modes when grammars exist |
| `lazyemacs-grammars` | 15 common languages | Grammars installed by <kbd>SPC h T</kbd> |
| `lazyemacs-enable-recovery` | `t` | Backups and auto-save files under `var/` |
| `lazyemacs-enable-mail` | `nil` | Load mu4e and the <kbd>SPC M</kbd> menu |
| `lazyemacs-org-directory` | `~/org/` | Agenda and capture files |
| `lazyemacs-offline` | `nil` (`t` with `LAZYEMACS_OFFLINE=1`) | Never download or update packages |
| `my/lsp-visual-extras` | `nil` | Breadcrumbs, highlights, inlay hints, code lenses |
| `my/lsp-diagnostics-enabled` | `t` | Diagnostics when a server attaches |
| `my/lsp-auto-start-delay` | `0.25` | Idle seconds before a server starts |
| `my/lsp-booster-enabled` | `t` | Use `emacs-lsp-booster` when installed |

Any installed theme works (`SPC u C` previews them). Themes from other packages
need a `use-package` declaration in `config.el`.

## Recipes

All of these go in `user/config.el`.

**Add a package** (LazyVim's `lua/plugins/*.lua`):

```elisp
(use-package olivetti
  :commands olivetti-mode
  :init (keymap-set my/leader-ui-map "z" '("Zen mode" . olivetti-mode)))
```

**Add or change keys:** see [keymaps.md](keymaps.md#adding-your-own-keys).

**Change a package setting** after the package loads:

```elisp
(with-eval-after-load 'corfu
  (setq corfu-auto-delay 0.3))
(with-eval-after-load 'apheleia
  (setf (alist-get 'python-ts-mode apheleia-mode-alist) 'ruff))
```

**Start a server for another language automatically:**

```elisp
(add-hook 'java-ts-mode-hook #'my/lsp-start)
```

**Format on save everywhere from startup:**

```elisp
(apheleia-global-mode 1)
```

**Disable something you do not want:**

```elisp
(remove-hook 'prog-mode-hook #'indent-bars-mode)   ; indent guides
(global-diff-hl-mode -1)                           ; Git gutter
(setq lazyemacs-dashboard nil)                     ; in user/early.el
```

**Different settings per project:** use `.dir-locals.el` in the project, for
example to choose a formatter or add tasks:

```elisp
((nil . ((apheleia-formatter . prettier)
         (my/project-tasks . (("dev" . "npm run dev"))))))
```

## Mail

Mail is off by default. To use mu4e:

1. Install `mu`/mu4e, `mbsync` (isync), and `msmtp`, and configure them with
   your account and credentials (outside this repository).
2. Synchronize a Maildir once with `mbsync`.
3. In `user/early.el`:

   ```elisp
   (setq lazyemacs-enable-mail t
         my/mu4e-user-full-name "Your Name"
         my/mu4e-user-mail-address "you@example.com"
         my/mu4e-mbsync-channel "default")
   ```

4. If your folder names differ, set them in `user/config.el`:

   ```elisp
   (with-eval-after-load 'mu4e
     (setq mu4e-sent-folder "/Sent" mu4e-drafts-folder "/Drafts"
           mu4e-trash-folder "/Trash" mu4e-refile-folder "/Archive"))
   ```

5. Restart, run <kbd>SPC M i</kbd> once to build the index, then <kbd>SPC M m</kbd>.

Homebrew installations of mu4e are found automatically; elsewhere add its
directory to `load-path` in `early.el`.

## How startup works

```text
early-init.el            GC, frame, and package settings before any frame exists
init.el                  checks Emacs ≥ 31.1, then loads in order:
  init-distribution      public options and the doctor
  user/early.el          your options
  user/custom.el         Customize settings
  init-packages          package.el + use-package (GNU, NonGNU, MELPA)
  init-core … init-org   one module per feature area (see lisp/)
  init-keymaps           the leader, Evil keys, C-c aliases
  init-dashboard         start screen
  init-mail              only with lazyemacs-enable-mail
  user/config.el         your overrides
```

| Module | Provides |
|---|---|
| `init-core` | Defaults, UTF-8, history, recent files, backups, server, PATH import |
| `init-ui` | Theme, fonts, mode line, TODO highlighting, indent guides |
| `init-completion` | Vertico, Orderless, Marginalia, Consult, Embark, Corfu, Cape, Which Key |
| `init-editing` | Editing defaults, terminal clipboard, undo tree |
| `init-evil` | Evil, Evil Collection, Flash, surround, commenting, multiple cursors |
| `init-navigation` | Windows, popups, projects, Dired/Dirvish explorer |
| `init-workspaces` | Sessions and layouts on tab groups |
| `init-vcs` | Magit, diff-hl, git-link |
| `init-structure` | Tree-sitter text objects, motions, folding |
| `init-languages` | Native mode selection, grammar installation |
| `init-development` | lsp-mode, Flycheck, Apheleia, snippets, language modes |
| `init-lsp-booster` | Optional faster LSP transport |
| `init-debug` | Dape debugger |
| `init-tools` | Ghostel terminals, TRAMP |
| `init-tasks` | Project tasks and focused tests |
| `init-session` | Desktop save/restore, zoom |
| `init-org` | Org, agenda, capture |
| `init-local-actions` | Backslash actions in result buffers |

Packages are byte-compiled but never native-compiled in the background, which
keeps the editor responsive while packages install or update.

## State, backups, and privacy

| Path | Contains |
|---|---|
| `elpa/` | Downloaded packages |
| `var/` | History, recent files, sessions, backups, caches, grammars, LSP servers |
| `etc/` | Generated package configuration and your snippets |
| `user/` | Your configuration |

All four are ignored by Git. `var/` contains file names, command history, and
the kill ring, so treat it as private. Backups and auto-saves go to
`var/backups/` and `var/auto-save/`; recover with `M-x recover-file` or
`M-x recover-session`.
