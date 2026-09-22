# Changelog

All notable changes to LazyEmacs. Dates are release dates (YYYY-MM-DD).

## Unreleased

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
