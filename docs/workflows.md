# Workflows

How the pieces fit together for everyday work. Every key is listed in
[keymaps.md](keymaps.md); this page explains what happens when you press them.

- [Finding things](#finding-things)
- [Search and replace across a project](#search-and-replace-across-a-project)
- [Language servers, formatting, and diagnostics](#language-servers-formatting-and-diagnostics)
- [Debugging](#debugging)
- [Terminals](#terminals)
- [Tasks and tests](#tasks-and-tests)
- [Projects, sessions, and layouts](#projects-sessions-and-layouts)
- [Git](#git)
- [Structural editing](#structural-editing)
- [Notes and mail](#notes-and-mail)
- [Performance choices](#performance-choices)

## Finding things

Every picker is Vertico + Orderless + Consult: type space-separated words in
any order, move with the arrows or <kbd>C-n</kbd>/<kbd>C-p</kbd>, and watch the
preview update. Type <kbd>&lt;</kbd> and a letter to narrow mixed lists (for
example `<f` shows only files in <kbd>C-x b</kbd>). Two keys work in every picker:

- <kbd>C-.</kbd> opens Embark actions for the highlighted candidate (open in
  another window, delete the file, copy its path, export all results, …).
- <kbd>M-R</kbd> or <kbd>SPC s R</kbd> reopens the last picker where you left it.

"Root" means the current project (the nearest Git repository or a directory
with `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, or
`.projectile`). "cwd" means the directory of the current buffer.

## Search and replace across a project

1. <kbd>SPC s r</kbd> and type the search. Results stream in from ripgrep.
2. Press <kbd>RET</kbd>. The results become an editable grep buffer.
3. Edit the lines with any Vim command, including <kbd>:s</kbd> and macros.
4. <kbd>\\ c</kbd> writes the edits into the source buffers. Save them with
   <kbd>SPC f s</kbd> or `M-x save-some-buffers`.

Edits apply to the source buffers immediately; there is no rollback other than
undo in each buffer. The same <kbd>\\ e</kbd> edit mode works in Occur and in
Dired, where it renames files.

<kbd>SPC s w</kbd> searches literally for the word under point or the selected
text. <kbd>SPC s t</kbd> finds `TODO:`, `FIXME:`, `HACK:` and similar comments.

## Language servers, formatting, and diagnostics

lsp-mode starts automatically, a quarter second after a file opens, **when its
language server is on your `PATH`**. Nothing is installed for you unless you ask:

- <kbd>SPC c m</kbd> installs a server that lsp-mode knows how to download
  (most npm-based servers). It lands in `var/lsp/servers/` and is detected the
  next time you open a file.
- Otherwise use your package manager: `brew install`, `apt install`,
  `npm install -g`, `pipx install`, `go install`, `rustup component add`, …

`SPC c l` shows what is attached. `M-x my/lsp-start`, `my/lsp-restart`, and
`my/lsp-shutdown` control the lifecycle, and <kbd>C-c L</kbd> is lsp-mode's full
command map.

Without a server, <kbd>gd</kbd>/<kbd>gr</kbd> fall back to xref (tags, Elisp,
grep) and <kbd>SPC c s</kbd> falls back to Imenu, so navigation still works.

**Formatting** (<kbd>SPC c f</kbd>) prefers the project's formatter through
Apheleia (Prettier, Biome, Black, Ruff, gofmt, rustfmt, …), then the language
server, then indentation. A `biome.json` selects Biome automatically, and a
directory-local `apheleia-formatter` overrides everything. In Visual state it
formats only the selection, which requires server range-formatting support.
Format-on-save is off until you toggle it: <kbd>SPC u f</kbd> globally or
<kbd>SPC u F</kbd> for one buffer.

**Diagnostics** are underlined as you type. Errors are not echoed while you
move around; <kbd>SPC c d</kbd> shows the message at point, <kbd>]d</kbd>
walks through them, and <kbd>SPC x x</kbd> opens a searchable list.

Optional visual extras (reference highlighting, breadcrumbs, inlay hints, code
lenses) are off by default because they request data on every cursor move.
Enable them together with `(setq my/lsp-visual-extras t)` in `user/early.el`,
or inlay hints alone with <kbd>SPC u h</kbd>.

## Debugging

LazyEmacs uses [Dape](https://github.com/svaante/dape), a Debug Adapter Protocol
client like nvim-dap. Install the adapter for your language first:

| Language | Adapter | Install |
|---|---|---|
| Python | debugpy | `pip install debugpy` in the project environment |
| Go | Delve | `go install github.com/go-delve/delve/cmd/dlv@latest` |
| Rust, C, C++ | CodeLLDB | Download the VS Code extension; see Dape's README |
| JavaScript, TypeScript | js-debug | See Dape's README for `js-debug` |

Then:

1. <kbd>SPC d b</kbd> sets a breakpoint (<kbd>SPC d B</kbd> for a condition).
2. <kbd>SPC d c</kbd> starts. Dape proposes configurations for the current
   file; complete the prompt or edit the arguments before <kbd>RET</kbd>.
3. Step with <kbd>SPC d O</kbd> (over), <kbd>SPC d i</kbd> (into),
   <kbd>SPC d o</kbd> (out), and <kbd>SPC d c</kbd> (continue).
4. Scopes, the call stack, and breakpoints open on the left; the REPL opens at
   the bottom. Variable values appear inline next to the code.
5. <kbd>SPC d t</kbd> terminates the session.

Profiling Emacs itself is on <kbd>SPC d p p</kbd>: press it once to start and
again to stop and open the report.

## Terminals

[Ghostel](https://github.com/dakra/ghostel) embeds libghostty, the terminal
engine from Ghostty. It is fast, handles full-screen programs, and runs on
macOS, Linux, and Windows. On first use it downloads a prebuilt native module
for your platform (or you can build one with `M-x ghostel-module-compile`).
Emacs builds without dynamic-module support open Eshell instead.

- <kbd>C-/</kbd> shows or hides this tab's project terminal at the bottom. The
  shell keeps running while hidden.
- <kbd>SPC f t</kbd> does the same as <kbd>C-/</kbd>; <kbd>4 SPC f t</kbd>
  starts a new shell at the project root.
- <kbd>SPC f T</kbd> shows the terminal for the current directory;
  <kbd>4 SPC f T</kbd> forces a new one.
- <kbd>Esc</kbd> then <kbd>C-h/j/k/l</kbd> leaves the terminal for the
  neighbouring window.
  <kbd>C-q</kbd> sends the next key straight to the shell when a program needs
  a key that Emacs would otherwise handle.

Terminals belong to the tab that opened them, so each layout keeps its own.

## Tasks and tests

**Tasks** (<kbd>SPC r r</kbd>) are discovered from the project:
`package.json` scripts (with the right npm/pnpm/yarn/bun), pytest,
`go test`/`go build`, `cargo test`/`cargo build`, and `make`. Pick one or type
a custom command. It runs in a compilation buffer where errors are clickable
and <kbd>]q</kbd>/<kbd>[q</kbd> step through them. <kbd>SPC r R</kbd> reruns the
last task and <kbd>SPC r T</kbd> runs one in a terminal instead. Add your own
with a reviewed `.dir-locals.el`:

```elisp
((nil . ((my/project-tasks . (("e2e" . "npm run test:e2e")
                               ("migrate" . "make migrate"))))))
```

**Tests** (<kbd>SPC t</kbd>) understand pytest, Vitest, Jest, and Go:

| Keys | Runs |
|---|---|
| <kbd>SPC t t</kbd> | The current file |
| <kbd>SPC t r</kbd> | The test around point (JS/TS needs the tree-sitter grammar) |
| <kbd>SPC t T</kbd> | The whole suite |
| <kbd>SPC t l</kbd> | The last test command, even after running other tasks |

Python uses the project's `.venv` when present, then `uv run` for uv projects
(without syncing), then `python` on `PATH`. JavaScript runners must already be
installed in the project. Test history and output are kept per project and
separately from other tasks.

Opening a project never runs anything; commands only run when you choose them.

## Projects, sessions, and layouts

LazyEmacs organizes work in three levels, all using Emacs's native tab bar:

- A **session** is a tab group, usually one per project, like a tmux session.
- A **layout** is a tab inside a session, holding an arrangement of windows.
  <kbd>SPC TAB TAB</kbd> creates one, <kbd>s-1</kbd>…<kbd>s-9</kbd> select them,
  <kbd>SPC TAB x</kbd> closes one, and <kbd>SPC TAB o</kbd> closes the others in
  this session only.
- **Buffers** are shared, so closing a layout never kills your files or shells.

The tab bar shows the current session, its layouts, and a dim `+N` for the
other open sessions; the mode line shows the session name.

### Connecting

<kbd>s-p</kbd>, <kbd>SPC TAB g</kbd>, and <kbd>SPC p p</kbd> (also
<kbd>SPC f p</kbd> and <kbd>p</kbd> on the start screen) open one picker, in
the spirit of [sesh](https://github.com/joshmedeski/sesh). Narrow it by typing
a key and a space:

| Key | Shows |
|---|---|
| <kbd>s</kbd> | ● open sessions, the current one first |
| <kbd>d</kbd> | ◌ saved sessions that are closed |
| <kbd>c</kbd> | ⚙ sessions declared in your configuration |
| <kbd>w</kbd> | Git worktrees of the current repository |
| <kbd>p</kbd> | known projects |
| <kbd>z</kbd> | [zoxide](https://github.com/ajeetdsouza/zoxide) directories, when `zoxide` is installed |

Each entry shows its directory, Git branch, layout count, and when you last
used it. A directory that already has a session appears only once, as that
session. Choosing an entry switches to an open session, restores a saved one,
builds a declared one, or creates a session for a directory's project. Typing
a new name creates an empty session.

<kbd>SPC TAB '</kbd> (or <kbd>s-'</kbd>) returns to the previous session,
reopening it if it was closed.

### Detach, kill, and the picker's actions

- <kbd>SPC TAB d</kbd> **detaches**: it saves the session and closes its
  layouts, but keeps its buffers and shells running. Connect again to get the
  layouts back.
- <kbd>SPC TAB D</kbd> **kills**, after asking: it closes the layouts and kills
  the session's buffers (files, Dired, terminals and their processes under the
  session's directory), except buffers that another open session also shows.
  The saved layout stays until you forget it.

At least one session stays open; closing the last one opens "Main".

In the picker, <kbd>C-.</kbd> acts on the highlighted entry: <kbd>d</kbd>
detach, <kbd>D</kbd> kill, <kbd>r</kbd> rename, <kbd>x</kbd> forget the saved
file, <kbd>o</kbd> Dired, <kbd>g</kbd> Magit, <kbd>t</kbd> terminal,
<kbd>f</kbd> find file, <kbd>/</kbd> search, <kbd>w</kbd> new Git worktree as a
session (asks for a branch and creates `../REPO-BRANCH`), <kbd>b</kbd> rebuild
from its declaration, and <kbd>s</kbd> save. <kbd>SPC TAB w</kbd> also creates
a worktree session, and <kbd>SPC TAB c</kbd> clones a repository into
`lazyemacs-sesh-clone-directory` (`~/Workspace/` if it exists, otherwise `~/`)
in the background and connects to it.

### Session buffers

Buffers remember the sessions that showed them. <kbd>SPC ,</kbd> (and
<kbd>SPC f b</kbd>) list this session's buffers; type <kbd>a</kbd>
<kbd>SPC</kbd> for every buffer or <kbd>f</kbd> <kbd>SPC</kbd> for recent
files. <kbd>H</kbd>/<kbd>L</kbd> cycle through this session's buffers only.
Nothing is hidden for good: <kbd>SPC f B</kbd> is the plain buffer list. Set
`lazyemacs-sesh-scope-buffers` to nil to turn the scoping off.

### Saving and restoring

Each session is saved to its own file in `var/sessions/`: its layouts, the
files, Dired directories, and terminal directories they show, its project
directory, and when you last used it. Sessions are saved when you switch away,
detach, after a minute of idle time, and on exit, and they load only when you
connect. Missing files and directories are skipped.

When Emacs starts, it reopens the sessions that were open when it exited, with
the same one selected. Start with `--no-desktop` to skip that once, or set
`lazyemacs-sesh-restore-on-startup` to nil.

| Keys | Action |
|---|---|
| <kbd>SPC q s</kbd> | Reopen the sessions open at the last exit |
| <kbd>SPC q l</kbd> | Reopen the most recently used closed session |
| <kbd>SPC q S</kbd> | Save every open session now |
| <kbd>SPC q d</kbd> | Don't save sessions for the rest of this run |
| <kbd>SPC q i</kbd> | Import the desktop saved by earlier LazyEmacs versions |

Processes are never restored: a saved terminal comes back as a placeholder
where <kbd>RET</kbd> starts a fresh shell.

Each session has a lock file, so two Emacs processes can work on different
sessions. Connecting to a session that another running Emacs owns stops with
a message naming that process; a lock left by an Emacs that crashed is
ignored.

**Upgrading:** earlier versions saved one desktop for everything. It is not
read automatically; run <kbd>SPC q i</kbd> (`lazyemacs-sesh-import-desktop`)
once to turn it into session files.

### Declaring sessions

Declare sessions you return to often in `user/config.el`. They appear under
<kbd>c</kbd> in the picker and are built the first time you connect; after
that they restore from their saved file (<kbd>C-.</kbd> <kbd>b</kbd> rebuilds
them):

```elisp
(lazyemacs-define-session "api"
  :root "~/Workspace/api"
  :layouts '(("code" :file "README.md")
             ("server" :file "src/main.go" :terminal "go run .")
             ("files" :dired "."))
  :startup (lambda () (message "Ready")))
```

A layout can `:file` (visit a file), `:dired` (show a directory), `:terminal`
(open a shell in the root and run a command, or `""` for just a shell), and
`:command` (call a command). Several keys split the layout's windows.

A project can also carry a `.lazyemacs-session.el` file with the same property
list (`:name`, `:layouts`, `:startup`), used when you connect to that project
the first time. It is read as data, never loaded. Files and directories open
right away; terminal commands and `:command`/`:startup` functions run only
after you agree once, and editing the file asks again. Opening a project still
never runs anything without your consent.

### From the shell

`bin/lazyemacs-connect` connects a running LazyEmacs (it uses `emacsclient`,
so start the server with `M-x server-start` or `emacs --daemon`):

```sh
lazyemacs-connect                    # the session for this directory
lazyemacs-connect ~/Workspace/api    # a project
lazyemacs-connect api                # a session by name
lazyemacs-connect -c .               # also open a frame if none is visible
lazyemacs-connect -s work api        # a server started with another name
```

It fits the usual terminal tools:

```sh
lazyemacs-connect "$(zoxide query api)"             # zoxide
sesh list | fzf | xargs lazyemacs-connect           # sesh's list
# tmux: open the current pane's directory in Emacs with prefix + e
bind-key e run-shell 'lazyemacs-connect "#{pane_current_path}"'
```

On Windows, call `emacsclient -n -e "(lazyemacs-sesh-cli-connect \"C:/path\")"`
directly; there is no wrapper script yet.

Session grouping comes from
[project-tab-sessions](https://github.com/xheisenbugx/project-tab-sessions).

## Git

<kbd>SPC g g</kbd> opens Magit, which covers staging, committing, rebasing,
stashing (<kbd>SPC g S</kbd>), and history. The gutter shows changed lines;
<kbd>]h</kbd>/<kbd>[h</kbd> move between hunks, and <kbd>SPC g h</kbd> previews,
stages, or resets the hunk under point. <kbd>SPC g B</kbd> opens the file or
selected lines on GitHub, GitLab, or similar, and <kbd>SPC g Y</kbd> copies
that link.

Gutter signs refresh on save and after Magit operations. For live signs while
typing, enable `M-x diff-hl-flydiff-mode`.

## Structural editing

With a tree-sitter grammar installed (<kbd>SPC h T</kbd>), the function text
object (<kbd>vaf</kbd>, <kbd>cif</kbd>), <kbd>]m</kbd>/<kbd>[m</kbd>, folding
(<kbd>za</kbd>), and <kbd>S</kbd> (select a syntax node with Flash) understand
the real syntax tree. Quote, bracket, argument, call, and tag objects work in
every buffer through syntax tables; they search the current line first and
then up to 500 lines around point. Counts and <kbd>.</kbd> repeat work as in
Vim. See [evil-textobj-plus](https://github.com/xheisenbugx/evil-textobj-plus)
for custom objects.

## Notes and mail

Org files live in `lazyemacs-org-directory` (default `~/org/`).
<kbd>SPC o c</kbd> captures a task, note, or journal entry; <kbd>SPC o a</kbd>
opens the agenda; <kbd>SPC o d</kbd> opens a daily dashboard of important
undated tasks, today's agenda, the next three days, and upcoming deadlines.
Python, shell, and Emacs Lisp source blocks can be executed after confirmation.

Mail through mu4e is optional; see [configuration.md](configuration.md#mail).

## Performance choices

These defaults keep typing and pickers responsive on large projects:

- Previews wait for a short pause (0.2 s in the same buffer, 0.4 s for files and
  LSP results). Project-wide grep previews on demand with <kbd>M-.</kbd>.
- Native tree-sitter modes are selected once at startup from installed grammars,
  instead of probing on every file visit.
- lsp-mode uses plist messages, disables its own file watchers, and pipes local
  servers through [emacs-lsp-booster](https://github.com/blahgeek/emacs-lsp-booster)
  when it is installed. Set `my/lsp-booster-enabled` to nil to opt out.
- Garbage collection waits for idle time (gcmh), and nothing is native-compiled
  in the background while you work.
