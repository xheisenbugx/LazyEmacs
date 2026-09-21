# LazyEmacs

**An Evil-first Emacs distribution inspired by the discoverability of LazyVim.**

LazyEmacs combines Vim editing, searchable leader menus, project workspaces,
modern completion, Git, language tools, and Ghostel terminals. It uses Emacs's
built-in package manager and small, readable Lisp modules. Your preferences
live separately from the distribution so updating the editor does not require
rewriting your configuration.

This is an early distribution built from a working configuration. The current
baseline is **Emacs 31.1**, including development builds: the result-editing
workflow uses Emacs 31 native grep editing. It is not compatible with Emacs 29
or 30 as shipped. Local validation currently covers macOS with Emacs 31.1;
Linux and Windows have not been validated end to end. There is no package
lockfile or promise of reproducible package versions yet.

Repository: [xheisenbugx/LazyEmacs](https://github.com/xheisenbugx/LazyEmacs).
LazyEmacs is independently maintained and is not affiliated with LazyVim.

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [First launch](#first-launch)
- [Private configuration](#private-configuration)
- [Configuration options](#configuration-options)
- [Repository layout and startup order](#repository-layout-and-startup-order)
- [Packages and updates](#packages-and-updates)
- [Language setup](#language-setup)
- [Terminals](#terminals)
- [Notes and optional mail](#notes-and-optional-mail)
- [State, recovery, and privacy](#state-recovery-and-privacy)
- [Troubleshooting](#troubleshooting)
- [Validation and contributing](#validation-and-contributing)
- [Publishing this distribution](#publishing-this-distribution)
- [Removing LazyEmacs](#removing-lazyemacs)
- [Workflow and keybinding reference](#workflow-and-keybinding-reference)

## Requirements

| Dependency | Purpose | Required? |
|---|---|---|
| Emacs 31.1+ | Native grep-edit, modern keymaps, package-vc, built-in use-package | Yes |
| Git | GitHub package installation, project detection, Magit | Yes |
| HTTPS access | GNU ELPA, NonGNU ELPA, MELPA, and GitHub packages | First installation and updates |
| Dynamic module support | Ghostel's native terminal module | For terminals |
| Tree-sitter-enabled Emacs and language grammars | Structural objects, TS/TSX modes, nearest JS/TS tests | For those features |
| `rg` (ripgrep) | Project text search | For project search |
| `fd` | Fast file discovery | Recommended; platform executable naming may vary |
| Nerd Font | Icons and preferred programming typography | Optional |
| Language servers, formatters, test runners | Language-specific tools | Per project/language |
| Python 3 | Source release exporter | Maintainers only |

Install Emacs through your preferred platform's packaging or build process.
Check the actual binary with `emacs --version`; many stable package repositories
may supply an older version than this distribution requires. A GUI launcher
and your terminal may use different Emacs installations.

On macOS, Command maps to Super, Option to Meta, and right Option remains
available for international characters. PATH is imported from your shell for
GUI sessions. Other systems keep their usual modifiers. Window-manager
shortcuts can intercept Super keys; use the `SPC TAB` alternatives instead.

## Installation

### Try it alongside an existing setup

Clone into a separate directory and explicitly select it. `--init-directory`
loads both initialization files and keeps package/state paths in that directory.

```sh
git clone https://github.com/xheisenbugx/LazyEmacs.git ~/.config/lazyemacs
emacs --init-directory ~/.config/lazyemacs
```

Do not add `-Q` to normal launch commands: it suppresses initialization. Do not
only load `init.el` from another config: `early-init.el` sets package and LSP
startup behavior, and state is rooted in `user-emacs-directory`.

### Make it your default configuration

Close Emacs first and back up your existing configuration. The following is an
example for an existing `~/.emacs.d`; the timestamp makes the backup distinct.

```sh
mv ~/.emacs.d ~/.emacs.d.backup-$(date +%Y%m%d-%H%M%S)
git clone https://github.com/xheisenbugx/LazyEmacs.git ~/.emacs.d
emacs
```

Skip the move if that directory does not exist. Also check for `~/.emacs`,
`~/.emacs.el`, and `~/.config/emacs`: competing startup locations can cause
Emacs to load a different configuration. Preserve any existing files before
changing them. The side-by-side command is the least ambiguous way to test.

### Daemon and client

Use a named daemon when another Emacs server may already be running:

```sh
emacs --init-directory ~/.config/lazyemacs --daemon=lazyemacs
emacsclient --socket-name=lazyemacs --create-frame
```

Ordinary interactive startup also starts Emacs's server when no server is
already running. A named client must use the matching socket name. Separate
processes sharing one init directory also share state; do not expect concurrent
desktop/session writes to merge.

## First launch

1. Keep the network available. Package metadata is refreshed if absent, and
   `use-package` installs missing packages. GitHub packages are cloned via Git.
   Installation and byte compilation can take time; this is not a download-free
   first start.
2. Read `*Messages*` and `*Warnings*` if a dependency fails. Package errors must
   be resolved before treating the installation as complete.
3. Run `M-x lazyemacs-doctor`, or `SPC h D`, to inspect executable paths,
   tree-sitter support, dynamic modules, private configuration, and recovery.
   Missing optional executables are informational, not an installation failure.
4. Run `M-x nerd-icons-install-fonts` if icons show as boxes. Installing icon
   fonts does not also install every programming font in the preference list.
5. Press `SPC` in Normal state and pause for Which Key. In Insert state use
   `C-c` followed by the same group and command keys.
6. Open a file inside a Git repository and try `SPC SPC` for files, `SPC /` for
   search, `SPC g g` for Magit, and `SPC e` for the explorer.
7. Install only the language tools you need, then reopen the file or start LSP
   explicitly with `M-x my/lsp-start`.

Notation: `SPC` is Space, `RET` is Return, `C-` is Control, `M-` is Meta/Option,
`S-` is Shift, and `s-` is Super/Command. `M-x` opens the command picker.
`ESC` returns to Evil Normal state. `C-g` cancels an Emacs command or prompt.

## Private configuration

From the repository root:

```sh
mkdir -p user
cp -n examples/early.el user/early.el
cp -n examples/config.el user/config.el
```

The copies are optional. LazyEmacs works with no private files. `cp -n` avoids
overwriting an existing configuration. Everything under `user/` is ignored by
Git and excluded from the source exporter.

- **`user/early.el`** loads before package setup and feature modules. Put
  `lazyemacs-*` startup settings, mail identity, and package-specific `defcustom`
  defaults here. This file runs after Emacs's real `early-init.el`.
- **`user/custom.el`** holds changes saved through Customize. It loads after
  package bootstrap and before feature modules. Explicit module defaults may
  override ordinary package settings saved here.
- **`user/config.el`** loads last. Put personal bindings, hooks, and overrides
  here. Use `with-eval-after-load` for packages that have not loaded yet.

`SPC f c` and `SPC q f` open your private `config.el`. `SPC q r` evaluates one
shared module for development; it is not a full reload mechanism. Restart after
changing startup options, enabling mail, or removing hooks/settings.

For private files outside the checkout:

```sh
LAZYEMACS_USER_DIR="$HOME/.config/lazyemacs-private" \
  emacs --init-directory ~/.config/lazyemacs
```

Set the environment variable before Emacs starts. It relocates only the three
private configuration files; package and runtime state stay under the init
directory. A relative value resolves against that init directory. Your GUI
launcher must receive the variable too if you use one.

Example `user/config.el`:

```elisp
(keymap-global-set "<f5>" #'recompile)
(with-eval-after-load 'org
  (setq org-agenda-files (list (expand-file-name "~/notes/tasks.org"))))
(with-eval-after-load 'apheleia
  (setf (alist-get 'python-mode apheleia-mode-alist) 'ruff))
```

The `lazyemacs-*` options are the public distribution settings. Existing
workflow commands retain their `my/` prefix for compatibility; they are callable
commands, not evidence that personal identity is required. This release keeps
an integrated editing stack rather than exposing arbitrary module removal:
keymaps and modules have dependencies. Mail is the supported optional module.

## Configuration options

Set startup values in `user/early.el` and restart.

| Option | Default | Effect |
|---|---|---|
| `lazyemacs-enable-mail` | `nil` | Load mu4e integration and expose mail leader menu |
| `lazyemacs-enable-recovery` | `t` | Enable backups and periodic buffer auto-save copies |
| `lazyemacs-dark-theme` | `catppuccin` | Startup/dark toggle theme |
| `lazyemacs-light-theme` | `modus-operandi-tinted` | Light toggle theme |
| `lazyemacs-fonts` | JetBrainsMono, Iosevka, Menlo, DejaVu Sans Mono | First installed family wins |
| `lazyemacs-font-height` | `140` | Font size in tenths of a point |
| `lazyemacs-org-directory` | `~/org/` | Agenda/capture directory |
| `my/lsp-visual-extras` | `nil` | LSP breadcrumbs, highlights, hints, action indicator |
| `my/lsp-diagnostics-enabled` | `t` | Diagnostics preference |
| `my/lsp-auto-start-delay` | `0.25` | Idle seconds before automatic LSP startup |
| `my/lsp-booster-enabled` | `t` | Use installed booster for local stdio servers |

The UI retains Emacs's existing font if none of the preferred families exists.
A custom theme symbol must name an installed theme. Catppuccin is installed by
the distribution; arbitrary theme packages must be installed separately.

## Repository layout and startup order

```text
LazyEmacs/
├── early-init.el          Startup performance, frame, and LSP settings
├── init.el                Version check and ordered module entrypoint
├── lisp/                  Shared feature modules
├── examples/              Copyable private configuration examples
├── tests/                 ERT behavioral and distribution tests
├── scripts/               Offline checks, integration runner, source exporter
├── docs/workflows.md      Detailed workflow reference
├── user/                  Ignored personal configuration
├── elpa/                  Ignored downloaded packages
├── etc/                   Ignored generated package configuration
├── var/                   Ignored history, desktop, backups, caches
└── tree-sitter/            Ignored installed grammar libraries
```

Startup order is: Emacs `early-init.el` → version check → distribution options
→ private `early.el` → package initialization → private Customize file → core,
UI, completion, editing, Evil, navigation/workspaces, Git, structure,
development/booster, terminals, tasks, session, Org, keymaps, local actions →
optional mail → private `config.el`.

Packages are normally byte-compiled. Automatic native compilation is disabled;
Emacs's own bundled native code can still run. Session restoration is disabled
in batch mode. Optional executable discovery does not install external tools.

## Packages and updates

GNU ELPA has priority over NonGNU ELPA, which has priority over MELPA. Flash,
project-tab-sessions, and evil-textobj-plus are fetched from GitHub using
package-vc. The declarations
in `lisp/` define the package set; a personal `package-selected-packages` list
is not required. GitHub dependencies currently follow upstream revisions.

Update shared code from the repository root:

```sh
git status --short
git pull --ff-only
```

Resolve any local source changes first. Private files and runtime state are
ignored and remain in place. Restart after updating shared code.

Package updates are separate: run `M-x my/package-upgrade-all` (`SPC q p`) to
refresh metadata and upgrade eligible packages. `M-x my/package-refresh`
refreshes metadata and the quickstart cache without a package upgrade. Use
`M-x list-packages` to inspect installed versions. Upstream updates can change
behavior; a Git rollback alone does not restore previous package versions.
Back up `elpa/` along with your source revision before a large upgrade if you
need to reproduce the old installation.

For recovery, start `emacs -Q`, inspect the startup error, and restore your
saved source/package snapshot. Do not delete private configuration or session
data as the first troubleshooting step. Package archives and GitHub must be
reachable on a new machine even if an existing machine starts offline.

## Language setup

LazyEmacs configures editor integrations; it does not install language runtimes,
project dependencies, servers, formatters, compilers, or test runners.

| Language/workflow | Server recognized for automatic startup | Other useful tools |
|---|---|---|
| JavaScript/TypeScript | `typescript-language-server` | TypeScript, Biome/Prettier, project's Jest/Vitest |
| Python | `basedpyright-langserver`, `pyright-langserver`, or `pylsp` | Ruff/Black, pytest in project environment |
| Go | `gopls` | Go toolchain, gofmt |
| Rust | `rust-analyzer` | Cargo, rustfmt |
| JSON | `vscode-json-language-server` | Project formatter |
| CSS | `vscode-css-language-server` | Project formatter |
| HTML | `vscode-html-language-server` | Project formatter |
| YAML | `yaml-language-server` | Project formatter |
| Dockerfile | `docker-langserver` | Docker tooling as needed |

Ensure executables are on Emacs's `exec-path`, not merely available in an
unrelated terminal. Activate the appropriate project environment before
starting the server. `SPC c l` shows LSP information. Use `C-c L` for the full LSP command map
or `M-x my/lsp-start`, `my/lsp-restart`, and `my/lsp-shutdown` for lifecycle actions. Definitions use xref when LSP is not attached.

Grammar libraries are separate from language servers. Configure a source in
`treesit-language-source-alist`, run `M-x treesit-install-language-grammar`, and
restart or reselect the major mode. For example:

```elisp
;; user/early.el; compiling a grammar also needs a suitable C/C++ toolchain.
(setq treesit-language-source-alist
      '((typescript "https://github.com/tree-sitter/tree-sitter-typescript"
                    "master" "typescript/src")
        (tsx "https://github.com/tree-sitter/tree-sitter-typescript"
             "master" "tsx/src")))
```

Install both `typescript` and `tsx` when using both file types. This configuration
automatically selects their native modes when grammars are available. Other
languages may need explicit mode remapping in your private config. Grammars
must be compatible with the tree-sitter ABI supported by your Emacs build.

Formatting is explicit with `SPC c f`; `SPC u f` toggles global format-on-save; `SPC u F` toggles it for the
current buffer. Project Biome configuration selects Biome for supported web
modes; directory-local `apheleia-formatter` values override that choice.

## Terminals

Ghostel is the terminal integration throughout this distribution. `C-/` (or
`C-_`) toggles the current tab's project terminal pane; `SPC f t` opens the same
pane and `SPC f T` opens a current-directory terminal. A numeric prefix, such as
`4 SPC f t`, starts a fresh shell. Interactive tasks use independent shells. There is no fallback terminal setup.

Ghostel requires dynamic module support. The installed package can download a
prebuilt native module on first use; source builds require the toolchain
specified by that package version. Inspect its bundled documentation before
building, since the distribution does not pin that dependency. Terminal startup
is a separate check from successfully loading the Emacs configuration.

`C-h/j/k/l` move between windows, including from terminal input. Ghostel's
`C-q` sends the following key literally when the shell needs a key intercepted
by Emacs. `C-c C-c` interrupts a command. Saved terminal layouts restore as
placeholders: `RET` starts a new shell, never the previous process.

## Notes and optional mail

Org uses `tasks.org`, `inbox.org`, and `journal.org` below
`lazyemacs-org-directory`. The directory is created when Org loads. `SPC o c`
captures, `SPC o a` opens the agenda dispatcher, and `SPC o d` opens the daily
dashboard. Python, shell, and Emacs Lisp Babel executors are enabled; execution
asks for confirmation. Notes themselves do not belong in the distribution.

Mail is disabled by default. To enable it:

1. Install mu/mu4e, mbsync, and msmtp using your platform's tools.
2. Configure synchronization, delivery, and credentials outside this repository.
   Synchronize a Maildir before initializing mu. No account is provisioned here.
3. Set `lazyemacs-enable-mail`, `my/mu4e-user-full-name`,
   `my/mu4e-user-mail-address`, `my/mu4e-maildir`, and
   `my/mu4e-mbsync-channel` in `user/early.el` using the example file.
4. Ensure mu4e is on `load-path`. The module discovers common Homebrew layouts;
   other installations may need an explicit `add-to-list` in `user/early.el`.
5. Override Sent/Drafts/Trash/Archive paths in `user/config.el` using
   `with-eval-after-load 'mu4e`. Defaults are generic `/Sent`, `/Drafts`,
   `/Trash`, and `/Archive`, with a `/Inbox` bookmark. Providers differ.
6. Restart. Run `SPC M i` to initialize/index mu, then `SPC M m` to open it.

The configuration targets modern mu4e's database-derived Maildir behavior.
`SPC M i` writes a mu index and is intentionally explicit. Once mu4e is open,
it synchronizes using the configured mbsync channel every five minutes.
Outgoing mail uses msmtp. The default saves a sent copy; providers that save
one themselves may need `mu4e-sent-messages-behavior` set to `delete`. Verify
folder mappings and delivery using your own account before relying on it.

## State, recovery, and privacy

Backups and buffer auto-save copies are enabled by default, stored under
`var/backups/` and `var/auto-save/`. Lockfiles remain enabled to warn about
concurrent edits. These features do not automatically save your real file on
every edit. Use `M-x recover-file` or `M-x recover-session` after a crash.
Setting `lazyemacs-enable-recovery` to nil disables future backups/auto-save
copies; it does not erase existing recovery data or disable lockfiles.

Desktop state records file names, cursor positions, tab groups, and layouts.
Savehist includes command/search histories and the kill ring. Recentf records
visited paths. Treat `var/`, `etc/`, and `user/` as private data even though
Git ignores them. Git ignore rules do not remove already committed history.

The source exporter includes an explicit list of source files and excludes
Git history, credentials, logs, package downloads, and runtime state. It does
not inspect arbitrary source text for secrets; review your own additions before
publishing. Keep mail credentials in your external mail tools' authentication
storage. Never put tokens in the example files.

## Troubleshooting

| Symptom | What to check |
|---|---|
| `void-variable evil-mode-buffers` | Update LazyEmacs and restart. Evil 1.15.0 needs the included Emacs 31 compatibility shim; no package deletion is necessary |
| Version error | Run `emacs --version`; this release requires 31.1 APIs |
| Your old setup starts | Use `--init-directory` explicitly and check competing init files |
| Package installation fails | Read `*Warnings*`, verify HTTPS/Git access, run `my/package-refresh`, restart |
| Missing icons | Run `nerd-icons-install-fonts`, confirm font availability, recreate frame |
| Font does not change | Check exact family name with `font-family-list`; font setup affects GUI frames |
| Project search fails | Confirm `rg` appears in `lazyemacs-doctor` and the project root is correct |
| LSP does not start | Check `exec-path`, major mode, environment, and matching server; try `M-x my/lsp-start` |
| Tree-sitter objects fail | Check active major mode and installed grammar; LSP alone is insufficient |
| Ghostel fails | Check dynamic modules, first-use download, and the installed Ghostel documentation |
| Mail menu absent | Enable mail in `user/early.el`, configure identity, restart |
| Customize change disappears | Use startup options in early.el or delayed overrides in config.el |
| Old tabs restore unexpectedly | Start with `--no-desktop`; back up desktop state before resetting it |
| Module reload does not undo a setting | Restart; evaluating Lisp does not reverse earlier effects |
| Super keys do nothing | Check window-manager interception; use the leader equivalents |

For a startup backtrace:

```sh
emacs --init-directory ~/.config/lazyemacs --debug-init
```

To bypass saved layouts:

```sh
emacs --init-directory ~/.config/lazyemacs --no-desktop
```

Use `emacs -Q` for an independent rescue session. Avoid loading untrusted
project-local commands or executing task/Babel content you have not reviewed.
The optional booster executes its encoded bytecode responses; use only trusted
local booster/server executables, or disable `my/lsp-booster-enabled`.

## Validation and contributing

Run these from the repository root. The offline suite requires no downloaded
packages and checks Lisp syntax and the public configuration helpers:

```sh
emacs -Q --batch --load scripts/check.el
```

After completing package installation and installing the TypeScript grammar:

```sh
emacs -Q --batch --load scripts/integration.el
LAZYEMACS_TEST_SUITE=evil-startup-tests.el \
  emacs -Q --batch --load scripts/integration.el
LAZYEMACS_TEST_SUITE=local-actions-tests.el \
  emacs -Q --batch --load scripts/integration.el
LAZYEMACS_TEST_SUITE=session-actions-tests.el \
  emacs -Q --batch --load scripts/integration.el
LAZYEMACS_TEST_SUITE=lazyvim-keymap-tests.el \
  emacs -Q --batch --load scripts/integration.el
git diff --check
```

The integration runner uses disposable private/runtime directories while
reusing this checkout's installed packages and grammar libraries. Missing
packages can still trigger installation. It does not launch live terminal
processes, deliver mail, or test external project services. Full clean-network
bootstrap and graphical behavior need separate manual checks on each platform.
See [CONTRIBUTING.md](CONTRIBUTING.md) for review expectations.

## Publishing this distribution

For the initial migration from a personal repository, export a clean source
snapshot. This avoids carrying personal data from old Git commits into a public
repository. Existing local Customize data belongs under ignored `user/`.

```sh
python3 scripts/export.py /tmp/LazyEmacs-source.tar.gz
mkdir -p /tmp/lazyemacs-release
tar -xzf /tmp/LazyEmacs-source.tar.gz -C /tmp/lazyemacs-release
cd /tmp/lazyemacs-release/LazyEmacs
git init
git add .
git diff --cached --stat
```

The exporter refuses to overwrite an existing archive. Review staged files,
choose the project's license and add its license file, then create the initial
commit. No distribution license is granted by this README; dependency licenses
remain their authors'. A license decision is needed before advertising this as
an openly licensed distribution.

If the GitHub repository is empty, the remaining publication commands are:

```sh
git commit -m "Prepare LazyEmacs distribution"
git branch -M main
git remote add origin https://github.com/xheisenbugx/LazyEmacs.git
git push -u origin main
```

If the destination already has commits, clone it into a separate directory and
copy the reviewed exported files into that checkout instead. Review the diff
and integrate normally; do not force-push over existing history. These are
maintainer instructions, not actions automatically performed at startup.

## Removing LazyEmacs

Close its Emacs process, back up private configuration, notes, and any runtime
state you need, then move the LazyEmacs init directory aside. Restore your
previous init directory or stop passing `--init-directory`. External tools,
fonts, mail data, and Org files live outside the checkout and must be managed
separately. Keep backups until the restored editor is working.

## Workflow and keybinding reference

[Read the workflow and keybinding reference](docs/workflows.md) for the complete
leader maps, terminal and test workflows, session actions, and intentional
LazyVim differences. That file is the single source for shortcut documentation.
