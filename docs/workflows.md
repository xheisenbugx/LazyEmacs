# LazyEmacs workflow reference

This configuration brings the discoverability and integrated workflow of
LazyVim to Emacs with Evil as its only modal editing layer. Modern packages
improve selection, completion, search, LSP, formatting, Git, terminals, file
management, email, and visual feedback while Evil supplies Vim motions,
operators, text objects, registers, and repeatable edits.

Packages are installed automatically with `package.el` and `use-package` on the
first startup. Generated data lives under `var/`, package configuration under
`etc/`, and neither directory is committed.

Packages use normal byte compilation instead of automatic native compilation.
This prevents background compiler workers from consuming the UI, CPU, and RAM
during file previews or package refreshes. Emacs's bundled native code and the
external LSP booster remain enabled.

## Evil and the leader hierarchy

Press `SPC` in Normal, Visual, or Motion state to open the LazyVim-style leader
hierarchy, then pause briefly for Which Key. The same hierarchy remains
available under Emacs's user-reserved `C-c` namespace, which is useful from
Insert or Emacs state. Ordinary Emacs control and Meta bindings remain
available in Insert state, except `C-h/j/k/l`, which navigate windows.
Use `SPC h` or `C-c h` for help.

| Prefix            | Area             | Examples                                           |
|-------------------|------------------|----------------------------------------------------|
| `SPC b` / `C-c b` | Buffers          | switch, kill, revert, ibuffer                      |
| `SPC c` / `C-c c` | Code             | actions, rename, format, file/workspace symbols    |
| `SPC e` / `C-c e` | Explorer         | toggle project Dirvish sidebar                     |
| `SPC x` / `C-c x` | Errors           | file/workspace diagnostics, inspect, next/previous |
| `SPC r` / `C-c r` | Run              | task picker, rerun, focused tests, output          |
| `SPC f` / `C-c f` | Files            | find, recent, save, explorer, copy path            |
| `SPC g` / `C-c g` | Git              | status, blame, diff, hunks, links                  |
| `SPC h` / `C-c h` | Help             | commands, functions, variables, keys, Info         |
| `SPC j` / `C-c j` | Jump             | Avy, Imenu, line, definition, references           |
| `SPC m` / `C-c m` | Multiple cursors | next/previous/all/edit lines                       |
| `SPC M` / `C-c M` | Mail (opt-in)             | open, compose, update, search, initialize          |
| `SPC o` / `C-c o` | Org              | agenda, capture, links                             |
| `SPC p` / `C-c p` | Projects         | switch, files, search, compile, terminal           |
| `SPC q` / `C-c q` | Session          | edit/reload config, upgrade packages, quit         |
| `SPC s` / `C-c s` | Search           | line, project text, files, outline                 |
| `SPC t` / `C-c t` | Terminals        | Ghostel, project terminal, fresh project terminal  |
| `SPC u` / `C-c u` | UI toggles       | theme, line numbers, wrapping, formatting          |
| `SPC w` / `C-c w` | Windows          | select, split, move, undo layout                   |
| `SPC y` / `C-c y` | Snippets         | insert, create, visit snippet files                |
| `SPC z` / `C-c z` | Workspaces       | tab-bar create, switch, rename, history            |

Common Emacs bindings remain available in Insert/Emacs state: `C-s` uses
`consult-line`, `C-x b` uses `consult-buffer`, `C-x g` opens Magit, `M-.` and
`M-?` retain xref commands, and `C-x u` visualizes the built-in undo history
that Evil uses for `u` and `C-r`.

The Evil companion stack is deliberately focused: Evil Collection covers
Emacs applications such as Dired, Magit, Org Agenda, and Help; Evil Surround
adds `ys`, `cs`, and `ds`; Evil Nerd Commenter adds the `gc` operator; Evil MC
provides Vim-aware multiple cursors; and General defines the `SPC` leader.

## LazyVim-like feature map

| Experience              | Emacs implementation                                                           |
|-------------------------|--------------------------------------------------------------------------------|
| Picker and fuzzy search | Vertico, Orderless, Marginalia, Consult                                        |
| Context actions         | Embark and Embark Consult                                                      |
| Completion and docs     | Corfu, Cape, nerd-icons-corfu                                                  |
| LSP                     | lsp-mode                                                                       |
| LSP acceleration        | emacs-lsp-booster for local stdio servers                                      |
| Diagnostics             | Flycheck with lsp-mode and Consult integration                                 |
| LSP pickers             | consult-lsp symbols and diagnostics                                            |
| Formatting              | project-aware Apheleia on demand, LSP/indent fallback; optional format-on-save |
| Syntax trees            | built-in tree-sitter modes for installed grammars                              |
| Git UI and gutter signs | Magit, diff-hl, git-link                                                       |
| File explorer           | Dirvish on top of native Dired                                                 |
| Popup management        | Popper (`C-backtick` toggles the latest popup)                                 |
| Workspaces              | project-tab-sessions, desktop persistence, and winner-mode                     |
| Undo visualization      | Vundo over Emacs's native undo history                                         |
| Email                   | mu4e with mbsync synchronization and msmtp delivery                            |

## LSP and diagnostics

lsp-mode is the sole language-server client.  It starts automatically only
when the matching server executable is installed, uses Corfu for completion,
and publishes diagnostics through Flycheck.  Automatic startup waits for a
short idle pause so the file appears before lsp-mode's one-time package load;
`C-c c l` starts it immediately when desired.  The leader commands include:

| Key       | Command                                  |
|-----------|------------------------------------------|
| `C-c c a` | code actions                             |
| `C-c c r` | rename symbol                            |
| `C-c c i` | current-file symbols                     |
| `C-c c s` | workspace symbols                        |
| `C-c c R` | restart/reconnect workspace              |
| `C-c x b` | current-file diagnostics                 |
| `C-c x l` | workspace diagnostics                    |
| `C-c x f` | Flycheck diagnostics picker              |
| `C-c x L` | Flycheck error list                      |
| `C-c j d` | definition via lsp-mode                  |
| `C-c j i` | implementation via lsp-mode              |
| `C-c j r` | references via lsp-mode                  |
| `C-c u d` | toggle diagnostics in the current buffer |

When lsp-mode is active, `C-c L` opens its complete built-in command map.

## Responsiveness defaults

Consult previews candidates automatically.  Cheap same-buffer previews use a
0.2-second debounce; buffer, file, xref, and LSP-backed previews use 0.4 seconds
so rapid candidate movement stays responsive.  The original exception remains
the recursive grep commands, where `M-.` requests a preview explicitly.

Tree-sitter mode selection uses fixed built-in associations instead of
treesit-auto.  The latter advised every major-mode lookup and repeatedly
scanned all grammar recipes, which added about 1.5 seconds to every file visit
on macOS—including files opened temporarily by Consult previews.

lsp-mode uses its lower-allocation plist protocol representation and keeps
local stdio servers behind `emacs-lsp-booster` when the executable is present.
The booster moves JSON parsing and transport buffering outside Emacs; remote or
network-based servers automatically use the normal lsp-mode transport.  Set
`my/lsp-booster-enabled` to nil and restart the workspace to disable it.

lsp-mode also keeps continuously updated visual extras off by default.
Diagnostics, completion,
Eldoc, xref, and code actions remain enabled.  To restore reference highlights,
breadcrumbs, inlay hints, and the modeline code-action indicator together, use:

```text
M-x customize-option RET my/lsp-visual-extras RET
```

Diagnostics start enabled by default.  `C-c u d` toggles them in the current
buffer and sets the default for later buffers in that session.  To save the
startup preference, customize `my/lsp-diagnostics-enabled`.

Git gutter signs update on save and after Magit refreshes.  Live unsaved signs
can be toggled temporarily with `M-x diff-hl-flydiff-mode`; leaving that mode
off avoids a repository diff competing with minibuffer and LSP idle timers.

## Modules

`init.el` only bootstraps the module directory. The configuration is split into:

- `init-packages.el`: archives, package bootstrap, and updates
- `init-core.el`: safety, persistence, PATH, and macOS behavior
- `init-ui.el`: theme, fonts, modeline, and visual feedback
- `init-completion.el`: minibuffer pickers, actions, and in-buffer completion
- `init-editing.el`: editing helpers and undo visualization
- `init-evil.el`: Evil, companion packages, modal defaults, and leader support
- `init-navigation.el`: windows, projects, Dirvish, and popup handling
- `init-vcs.el`: Magit, Git signs, and repository links
- `init-development.el`: languages, tree-sitter, lsp-mode, Flycheck, formatting
- `init-tools.el`: Ghostel and TRAMP
- `init-tasks.el`: project tasks and focused Python/JS/TS/Go tests
- `init-structure.el`: native tree-sitter text objects, motions, and folding
- `init-session.el`: desktop persistence, terminal placeholders, and window zoom
- `init-org.el`: agenda, capture, and Org presentation
- `init-mail.el`: optional mu4e, generic Maildir, mbsync, and msmtp
- `init-keymaps.el`: all global bindings and the discoverable `C-c` hierarchy

## External tools

The editor degrades gracefully when optional executables are absent. For the
full experience, install:

- `rg`, `fd`, and Git for fast project navigation and search
- language servers such as `typescript-language-server`,
  `basedpyright-langserver`, `gopls`, or `rust-analyzer`
- formatters such as Biome/Prettier, Ruff/Black, `gofmt`, `rustfmt`, and `shfmt`
- GNU coreutils (`gls`) on macOS for rich Dirvish sorting
- `pandoc` for Markdown preview/export

Run `M-x nerd-icons-install-fonts` once if icons display as empty boxes.
After adding a grammar source to `treesit-language-source-alist`, install it
with Emacs's built-in `M-x treesit-install-language-grammar` command, then add
the desired `*-ts-mode` association in `init-development.el`. Run `M-x
my/package-upgrade-all` (`C-c q p`) to refresh and upgrade packages.

## Project sessions

Projects use native tab groups, with regular layout tabs inside each group.
`Super+p` switches groups and resumes the last active tab. `Super+1…9/0`
selects a tab within the active group; `Super+t/r/w` creates, renames, or closes
one.

The [project-tab-sessions package](https://github.com/xheisenbugx/project-tab-sessions)
is installed from GitHub using built-in `package-vc` support (Emacs 30+).
See its [installation and usage guide](https://github.com/xheisenbugx/project-tab-sessions#install)
and [package comparison](https://github.com/xheisenbugx/project-tab-sessions/blob/main/COMPARISON.md)
for the alternatives reviewed. `lisp/init-workspaces.el` only configures the
package's presentation. Ghostel terminals remain attached to their tabs.

## Everyday shortcuts

| Key | Action |
|---|---|
| `SPC SPC` | Find project files |
| `SPC ,` | Pick project buffers |
| `SPC /` | Search project text |
| `SPC e` | Project explorer (diagnostics moved to `SPC x`) |
| `SPC b b` | Previous buffer; `C-x b` still opens the full picker |
| `SPC -`, `SPC \|` | Split below / right |
| `SPC s r` | Project regexp query-replace |
| `SPC s S` | Workspace symbols |
| `SPC u L` | Toggle relative line numbers in this buffer |
| `SPC w m` | Zoom the selected code window / restore its layout |
| `SPC q r` | Pick and explicitly evaluate a config module |
| `s` | Flash: type search text, then a label to jump across visible windows |
| `S` | Flash: select a surrounding Tree-sitter node by label |
| `f` / `F` | Flash: find a character forward / backward, with labels for further matches |
| `t` / `T` | Flash: move just before / after a character forward / backward |
| `;` / `,` | Repeat the last Flash character motion / reverse its direction |

[Flash](https://github.com/Prgebish/flash) is installed from GitHub through
package.el. These keys work in Normal, Visual, and operator-pending states
(for example, `dfx` deletes through `x`). Character motions can cross lines;
labels appear after matches. `S` needs an active Tree-sitter parser in the
current buffer. `s` and `S` replace Evil's substitute commands; use `cl` and
`cc` for character and line changes. Insert-state typing is unchanged.

The core normal-state navigation commands use an override map so mode-specific
Evil Collection bindings cannot replace `gd`, `gr`, or `gI`. `gd` uses
`lsp-find-definition` when LSP manages the buffer and falls back to
`xref-find-definitions` otherwise, including Emacs Lisp's own backend.
`SPC m` now uses Evil MC throughout:
`n/p` add next/previous match, `s` skips, `a` selects all, `l` adds cursors at
visual-selection line beginnings, `u` removes the last cursor, and `q` clears
cursors. Its native prefix is `gz`, leaving `gr` exclusively for references.

Module reload reevaluates the chosen file rather than reloading an init file
whose `require` forms skip already-loaded modules. Keymaps are rebuilt when
evaluated. Removing hooks/settings can still require a restart; changes to
`early-init.el` and package initialization should always be followed by one.
Undo history is retained in live buffers, not persisted across restarts.

## Structural editing

Use `]q` / `[q` in Normal state to visit the next/previous result with
`next-error` / `previous-error`, including Embark-exported grep/Occur results
and compilation output.

In buffers with an active native tree-sitter parser:

- `vaf` selects a function; `cif` changes its body.
- `via` selects an argument; `daa` deletes it with an adjacent comma.
- `]m` / `[m` move through function starts, including nested functions.
- `za` toggles the surrounding structural block. Search or edits reveal it.

These use the native parser directly, with no second tree-sitter package.
Install TypeScript/TSX grammars to enable these workflows. Other languages need
an installed grammar and their corresponding `*-ts-mode`; unsupported buffers
report this requirement. Folding falls back to Hideshow without a parser.

## Project tasks

| Key | Action |
|---|---|
| `SPC r r` | Pick a task or enter a custom shell command |
| `SPC r R` | Rerun this project's last finite task |
| `SPC r f` | Test the current file |
| `SPC r t` | Test the nearest supported test |
| `SPC r o` | Show this project's latest task output |
| `SPC r n` | Jump to its next compilation failure |
| `SPC r T` | Run a selected task in a fresh Ghostel shell |

The picker reads root `package.json` scripts and recognizes Python, Go, Rust,
and Make projects. Package scripts use the detected lockfile's package manager.
Each project has independent command history and output, including projects
with the same directory name. Finite jobs prompt to save modified project files
and use compilation-mode; interactive jobs use Ghostel.

Focused tests support pytest (including class methods), Vitest/Jest with literal
`it`/`test` titles, and Go `Test*` functions. JS/TS nearest-test selection requires
a native parser; dynamic/parameterized titles need a custom command. Go file
runs execute the matching test functions in their package. The test runner must
already be available in the project's environment. Monorepo packages with their
own runner configuration can use explicit tasks. Other runners use the task
picker rather than a guessed command.

Add reviewed directory-local tasks, for example:

```elisp
((nil . ((my/project-tasks . (("lint" . "pnpm lint")
                            ("integration" . "docker compose run --rm tests"))))))
```

Emacs asks before accepting command-bearing directory-local values. Opening a
project never runs a task. Last finite commands persist through Savehist; output
buffers and running processes do not persist across restarts.

## Persistent sessions

Desktop persistence saves file buffers, cursor positions, native tab groups,
project roots, and layouts under `var/desktop/`. It restores them on startup,
saves on clean exit, and updates an existing desktop after idle layout changes.
`SPC q s` saves explicitly; `SPC q l` restores it. A desktop owned by another
Emacs process is not automatically loaded. `emacs --no-desktop` bypasses it.

`SPC z N` creates a named layout tab in the current group, suggesting
`implementation`, `tests`, or `review`. `Super+p` and the existing tab shortcuts
continue to work. Shell processes are never serialized: saved terminal panes
show a placeholder where `RET` starts a fresh Ghostel shell in the saved directory.
Unsaved file contents are not stored by desktop; recovery files are enabled
separately by default under `var/`. Window zoom snapshots last only for the running session.

## Formatter selection

`SPC c f` formats immediately even with format-on-save disabled. `SPC u f`
independently toggles formatting on save for the current buffer. A project
`biome.json`/`biome.jsonc` selects Biome for supported web modes; otherwise
Apheleia keeps its mode defaults. Explicit directory-local `apheleia-formatter`
values take priority, including choosing Ruff, Black, or Prettier. No global
executable-presence rule silently switches every project to Biome or Ruff.

## Validation

Run the isolated behavioral fixtures with:

```sh
emacs -Q --batch --load scripts/integration.el
```

They cover effective Evil bindings, native TypeScript objects/folds, formatting
without save hooks, task selection, and desktop/layout roundtrips. They do not
run project test suites or start terminal processes.

## Local actions in result buffers

In Evil Normal state, backslash opens a local-action menu in grep, Occur,
Dired, compilation, and Embark collection buffers:

| Key | Action |
|---|---|
| `\ e` | Edit grep/Occur results or Dired filenames |
| `\ c` | Finish the current native edit session |
| `\ r` | Refresh results while browsing |
| `\ f` | Toggle following grep/Occur/compilation results |
| `\ a` | Embark actions for the item at point |
| `\ q` | Close the window (does not undo changes) |

Actions that do not apply to the current mode explain that instead of running
an unrelated command. `e` stays an Evil motion; normal editing commands remain
available after entering edit mode. In grep browsing buffers, `i` is also an
alias for entering native grep-edit instead of Wgrep. `]q`/`[q` still navigate
results. Grep and Occur edits update source buffers immediately; finishing
returns to browsing and does not save those source buffers to disk. WDired's
finish command applies filename changes. Refresh is blocked during editing.
