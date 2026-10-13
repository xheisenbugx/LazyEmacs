# Changelog

All notable changes to LazyEmacs. Dates are release dates (YYYY-MM-DD).

## Unreleased

### Sessions, the sesh way

- **One picker for everything** (`s-p`, `SPC TAB g`, `SPC p p`, `SPC f p`):
  open, saved and declared sessions, known projects, zoxide directories and
  Git worktrees, with narrowing keys `s d c p z w`. Connecting switches,
  restores, builds or creates as needed; typing a new name creates a session.
- **Each session is saved to its own file** in `var/sessions/` and loads only
  when you connect. The sessions open at exit reopen at startup
  (`--no-desktop` skips this). This replaces the single desktop; run
  `SPC q i` once to import an old one.
- **Per-session lock files** let two Emacs processes work on different sessions.
- `SPC TAB d` detaches a session (saved, buffers kept), `SPC TAB D` kills it
  and its buffers, and `SPC TAB x` closes a single tab. `SPC TAB '` / `s-'`
  toggle the last session.
- `lazyemacs-define-session` declares sessions with file, Dired and terminal
  layouts. A project's `.lazyemacs-session.el` is read as data, and its
  commands run only after you trust it once.
- `SPC ,` and `H`/`L` stay within the current session's buffers (`a SPC` in the
  picker shows all).
- New worktree-as-session (`SPC TAB w`) and clone-and-connect (`SPC TAB c`).
- `bin/lazyemacs-connect` opens a directory or session from the shell, tmux,
  sesh or zoxide.
- The tab bar shows a `+N` count of other sessions, the mode line shows the
  session name, and the dashboard lists recent sessions.

### Packages, extras, and the doctor

- **Package lockfile:** `lazyemacs-lock.eld` records every package's version
  and archive, or the Git commit for packages installed from Git. `SPC l u`
  updates and offers to record the result, `SPC l s` shows differences, and
  `SPC l r` restores Git packages to their locked commits; archive packages are
  never silently downgraded.
- **Extras:** `M-x lazyemacs-extras` (`SPC l x`, dashboard `x`) lists optional
  bundles and toggles them, like LazyVim's LazyExtras: format on save,
  camelCase word motions, relative numbers, zen mode, and C/C++ with clangd.
- **Doctor:** reports modules that failed to load, formatter and
  language-server executables per language, lockfile status, enabled extras,
  and stale session locks.
- **Keys:** `SPC l` is now the Packages group; the package list moved to
  `SPC l l`.

### Keys that behave

- Magit, Dired and other modes keep their own keys (`s`, `f`, `t`, `gr`, `K`,
  `C-j`/`C-k`); Flash and code-navigation keys are now ordinary global Evil
  bindings instead of overriding every mode.
- `C-h/j/k/l` move between windows from Normal state only, as in LazyVim;
  `C-h` is the help prefix again while typing, and terminals keep these keys.
- Enter inserts a newline when no completion candidate is selected.
- `K` shows fresh documentation for the symbol at point (LSP hover, Helpful, or
  ElDoc).
- `M-SPC` opens the leader in special buffers that use Emacs state.
- `w`/`b`/`e` treat camelCase as one word, as in Vim (the `editor-subword`
  extra restores the old behaviour).
- Folding works with `za zo zc zR zM` in tree-sitter, Hideshow and Org
  buffers; `]m`/`[m` work without a grammar.
- `SPC f t` toggles the project terminal (`C-u SPC f t` starts a fresh one).
- vim-surround's `ys`/`ds`/`cs` are documented as unavailable; use
  `gsa`/`gsd`/`gsr`, as LazyVim does.

### Reliability

- A module that fails to load is reported on the dashboard and in `SPC h D`
  instead of stopping startup; batch runs stay strict.
- Settings saved with Customize now override LazyEmacs defaults.
- 31.1 pretests (31.0.90+) are accepted.
- In monorepos the repository root is the project; tasks and tests use the
  nearest package manifest.
- `SPC c f` falls back to the language server or reindenting when the
  formatter isn't installed.
- JSON LSP starts without a JSON grammar; Emacs Lisp files and shell scripts
  (with ShellCheck) get diagnostics without a language server.
- The dashboard no longer contacts remote hosts for recent files, redraws only
  on width changes, and its `q` closes an emacsclient frame instead of killing
  the daemon.
- `SPC q p` no longer upgrades built-in packages in the running session.
- The kill ring is no longer saved to disk.
- Terminal clipboard and indent guides work in daemon and client frames.
- Org's disputed-key remapping (Shift+arrows) now actually takes effect.
- The full test run byte-compiles every module and fails on warnings, and a
  new suite checks that mode keys survive LazyEmacs's global bindings.

### LazyVim parity

- **Leader rewritten from a single table** with LazyVim's labels in Which Key
  for every key, and `my/leader-map` exposed for private keys.
- **New groups:** `SPC d` debugging with [Dape](https://github.com/svaante/dape)
  (breakpoints, stepping, REPL, watches) and `SPC d p` for the Emacs profiler.
- **New top-level keys:** `SPC E` (explorer at cwd), `SPC l` (packages),
  `SPC L` (changelog), `SPC n` (message history); `SPC :` now reruns commands.
- **Code:** `SPC c A` source actions, `SPC c c`/`C` code lenses, `SPC c m`
  installs language servers (the Mason equivalent).
- **Git:** `SPC g G`/`L` status and log for the current directory, `SPC g S`
  stash, `SPC g D` diff against upstream, `SPC g c` commits, and
  `SPC g h b/d/R/u` hunk extras.
- **Search:** `SPC s "` registers, `SPC s /` search history, `SPC s h`/`H` help
  and faces, `SPC s j` jumps, `SPC s q` quickfix, `SPC s l` location list,
  `SPC s t`/`T` TODO comments (also `SPC x t`/`T`).
- **UI toggles:** `SPC u C` colorscheme, `SPC u g` indent guides, `SPC u s`
  spelling, `SPC u p` auto pairs, `SPC u r` redraw, `SPC u i`/`I` inspect
  position and syntax tree, `SPC u A` tab line, `SPC u Z` zoom.
- **Windows:** `SPC w` is now Vim's `CTRL-W` map, as in LazyVim, so `SPC w o`
  keeps only this window and `SPC w w`/`s`/`v`/`x`/`r` behave like Vim.
  Ace-window moved to `SPC w a`; layout redo moved to `SPC w U`.
- **Sessions:** `SPC q s` and `SPC q l` restore, `SPC q d` stops saving,
  `SPC q S` saves now (previously `SPC q s` saved).
- **Tests:** `SPC t T` runs the whole suite.
- **Editing:** `gsa`/`gsd`/`gsr` surround keys, `]t`/`[t` TODO navigation,
  `C-Up/Down/Left/Right` window resizing, and `<`/`>` keep the Visual selection.
- **Dashboard** on startup and in new client frames, with LazyVim's one-key
  actions, recent files, and projects.
- **TODO highlighting** (hl-todo) and **indent guides** (indent-bars).

### Platforms

- Terminals fall back to Eshell on Emacs builds without dynamic modules.
- Terminal Emacs shares the clipboard through `wl-copy`, `xclip`, or `xsel` on
  Linux as well as `pbcopy` on macOS.
- GUI Emacs imports the login shell `PATH` on Linux and BSD, not only macOS.
- Dired uses portable listing switches without GNU `ls`, and Emacs's own
  listing on Windows.
- Windows fonts (Cascadia Mono, Consolas) join the default font list.
- CI runs on macOS, Linux, and Windows.

### Languages

- `SPC h T` (`lazyemacs-install-grammars`) compiles missing tree-sitter
  grammars using the sources that ship with Emacs 31.
- Native modes for Lua, Dockerfile, and TOML; automatic LSP for Lua and Bash.

### Tooling and docs

- `scripts/bootstrap.el` installs packages (and grammars) headlessly.
- `docs/keymaps.md` is generated from the keymap tables and checked by tests.
- New installation, configuration, workflow, and troubleshooting guides.
- Issue and pull request templates.

### Fixes

- Visual `<`/`>` shifted only the first line of a line selection.
- `SPC :` used `consult-history`, which fails outside the minibuffer.
- `SPC s q` and `SPC d p h` referred to commands that were not autoloaded.

## 2026-09-21

See [the configuration review](docs/configuration-review.md) for the
reliability release: offline package policy, safer LSP booster transport,
tree-sitter fallbacks, and startup recovery.
