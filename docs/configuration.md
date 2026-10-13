# Configuration

LazyEmacs keeps your settings apart from the distribution, like LazyVim's
`lua/config/` and `lua/plugins/`. You never edit files under `lisp/`, so
`git pull` updates cleanly.

- [Your files](#your-files)
- [Options](#options)
- [Recipes](#recipes)
- [Extras](#extras)
- [Package lockfile](#package-lockfile)
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
| `user/extras.eld` | Written by `M-x lazyemacs-extras` | The [extras](#extras) you enabled (data, not code) |

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
| `lazyemacs-extras` | `nil` | [Extras](#extras) to load, in addition to `user/extras.eld` |
| `lazyemacs-lock-file` | `lazyemacs-lock.eld` in the distribution | The [package lockfile](#package-lockfile) |
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

**Format on save everywhere from startup:** enable the `coding-format-on-save`
[extra](#extras), or:

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

## Extras

Extras are optional bundles that LazyEmacs ships but does not turn on, like
LazyVim's LazyExtras. Run `M-x lazyemacs-extras` (also <kbd>SPC l x</kbd>, or
<kbd>x</kbd> on the dashboard): it lists every extra with its description and
state. Press <kbd>x</kbd> or <kbd>RET</kbd> to toggle the extra on that line and
<kbd>o</kbd> to read its source.

| Extra | Effect |
|---|---|
| `coding-format-on-save` | Format every file on save with Apheleia (<kbd>SPC u f</kbd>/<kbd>SPC u F</kbd> still toggle it) |
| `editor-subword` | CamelCase-aware word motions: `w`, `b`, `e`, and `M-f` stop inside `fooBarBaz` |
| `ui-relative-numbers` | Relative line numbers, as in LazyVim |
| `ui-zen` | Zen mode on <kbd>SPC u z</kbd>: centered text without line numbers or mode line |
| `lang-clangd` | C and C++: native modes, `c`/`cpp` grammars for <kbd>SPC h T</kbd>, clangd when installed |

Enabling an extra loads it immediately; disabling one takes effect after a
restart. Your selection is saved as data in `user/extras.eld`. To keep it with
the rest of your configuration instead, list extras in `user/early.el`:

```elisp
(setq lazyemacs-extras '(editor-subword ui-relative-numbers))
```

Both sources are combined; extras named in `early.el` can only be removed
there. Extras load after every LazyEmacs module and before `user/config.el`,
so `config.el` can still override them. An extra that fails to load is
reported in `*Warnings*` and the doctor (<kbd>SPC h D</kbd>) without stopping
startup. Each extra is one small file in `lisp/extras/`; its first line is the
description shown in the list.

## Package lockfile

`lazyemacs-lock.eld` at the root of the distribution plays the role of
lazy.nvim's `lazy-lock.json`. It is readable Lisp data, one package per line,
sorted by name: the version and archive of each package, and for packages
installed from Git the repository and exact commit. Commit it to make an
installation reproducible.

| Key | Command | Does |
|---|---|---|
| <kbd>SPC l l</kbd> | `list-packages` | Browse, install, and delete packages |
| <kbd>SPC l u</kbd> | `lazyemacs-update-packages` | Upgrade every package, show the differences, and offer to update the lockfile |
| <kbd>SPC l s</kbd> | `lazyemacs-lock-status` | Compare installed packages with the lockfile (`w` records, `r` restores, `g` refreshes) |
| <kbd>SPC l r</kbd> | `lazyemacs-lock-restore` | Return Git packages to their locked commits and install missing ones |
| — | `lazyemacs-lock-write` | Record the installed packages now |

Nothing is written without your confirmation. Restore shows its plan and asks
first. Archives keep only their newest release, so archive packages that
differ from the lockfile are listed and kept as installed rather than silently
downgraded or replaced. Restore needs the network and refuses to run with
`LAZYEMACS_OFFLINE=1`. Packages installed from your own checkout
(`package-vc-install-from-checkout`) are never moved; check the commit out
there yourself.

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
  init-lock, init-doctor package lockfile, extra doctor sections
  init-extras            enabled extras from lisp/extras/
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
| `init-lock` | Package lockfile: status, update, restore |
| `init-doctor` | Doctor sections: failed modules, language tooling, session locks |
| `init-extras` | The extras list and loader |

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
