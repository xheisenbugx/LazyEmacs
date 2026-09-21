# LazyEmacs workflow and keybinding reference

The configuration follows [LazyVim's keymap layout](https://www.lazyvim.org/keymaps)
using Evil, Consult/Embark, lsp-mode, Magit, and Ghostel. `SPC` is the leader in
Normal, Visual, and Motion states. `C-c` plus the same letter prefix works from
Insert/Emacs state. Pause after a prefix for Which Key. `SPC ?` lists the current
major mode's keys; `SPC sk` describes the available bindings.

## Intentional differences

- `C-h/j/k/l` always navigate windows, including Insert state and Ghostel.
  Use `gK` for signature help; Ctrl-K keeps its navigation behavior.
- `Super+p` manages session groups; native tabs are layouts within those groups.
- `SPC qs` saves the complete desktop and `SPC ql` restores it. There are no
  project-specific snapshots or automatic process restoration.
- `SPC r` is the general task menu. `SPC o` is Org, `SPC m` is Evil MC, and
  `SPC y` is snippets. These are Emacs extensions.
- `SPC xx`/`xX` use diagnostic pickers rather than a Trouble panel. `SPC gg`/`gs`
  open Magit. Buffer cleanup protects special/process buffers.
- `SPC t` runs focused tests, without a discovery tree, watcher, or debugger.
- `C-s` saves only in ordinary editing buffers. Minibuffers, terminals, and
  special modes retain their own input behavior. `C-u` retains Evil scrolling;
  use a numeric prefix (`4 SPC ft`) to request a fresh terminal.

## Everyday editing

| Keys | Action |
|---|---|
| `SPC SPC`, `SPC ff` | Project files |
| `SPC fF` | Files below the current directory |
| `SPC ,`, `SPC fb` | Project buffers |
| `SPC fB`, `SPC bj`, `C-x b` | All buffers |
| `SPC bb`, ``SPC ` `` | Previous buffer |
| `H` / `L`, `[b` / `]b` | Previous/next buffer (`H/L` in editing buffers) |
| `C-s`, `SPC fs` | Save file |
| `M-j` / `M-k` | Move line/selection down/up in editing buffers |
| `SPC fn` | New unnamed file buffer |
| `SPC .` | Toggle scratch |
| `SPC bd` | Kill current buffer, respecting modified-file prompts |
| `SPC bD` | Kill buffer and close its window |
| `SPC bo` / `SPC bi` | Kill other/invisible file buffers; preserve process buffers |
| `SPC fp` | Switch project |
| `SPC fr` / `SPC fR` | Recent files / recent files below current directory |
| `SPC fy` | Copy file/directory path |
| `SPC fc` | Private config |
| `SPC e`, `SPC fe` / `SPC fE` | Explorer at project root / current directory |
| `SPC fj` | Dired at current file |
| `SPC fD`, `SPC fo`, `SPC fS`, `SPC fu` | Delete file, external opener, save as, sudo edit |

Buffer cleanup operates on live file buffers shared by sessions; it does not
isolate buffers by tab group. Cancellation and unsaved-file prompts are retained.
`SPC h` provides Helpful, Info, and `SPC hD` environment diagnostics. `SPC j`
retains xref back/forward, line/outline selection, and one Avy character/word
shortcut (`jc`/`jw`). Flash remains the primary labeled jump system.

## Code and diagnostics

| Keys | Action |
|---|---|
| `gd`, `gr`, `gI` | Definition, references, implementation |
| `gy`, `gD` | Type definition, declaration |
| `K`, `gK` | Documentation, signature help |
| `gai`, `gao` | Incoming/outgoing calls through an xref picker |
| `gi` | Evil: return to last insertion position |
| `SPC ca`, `SPC cr`, `SPC co` | Code action, symbol rename, organize imports |
| `SPC cR` | Rename file (lsp-mode's rename-file integration remains active) |
| `SPC cl` | LSP session information |
| `SPC cs`, `SPC ss` / `SPC sS` | File/workspace symbols |
| `SPC cd` | Diagnostic at point |
| `SPC sd`, `SPC xx` / `SPC sD`, `SPC xX` | Workspace/file diagnostics |
| `SPC xf` / `SPC xL` | Current Flycheck picker/list |
| `[d` / `]d` | Previous/next diagnostic |
| `[e` / `]e` | Previous/next error only |
| `[w` / `]w` | Previous/next warning only |
| `[q` / `]q` | Previous/next grep, Occur, or compilation result |
| `SPC xq` | Show the current result buffer |
| `SPC cf` | Format buffer, or selected region when LSP supports range formatting |
| `SPC uf` / `SPC uF` | Global/buffer format-on-save |
| `SPC ud`, `SPC uh` | Toggle diagnostics/inlay hints |

Errors do not automatically appear in Eldoc when point moves over them.
Underlines and diagnostic lists remain active; `SPC cd` explicitly shows the
message in the echo area. `K` continues to show symbol documentation.

New LSP navigation checks server capabilities. `gd` still falls back to xref in
unmanaged buffers. Code navigation records Evil jumps for `C-o`/`C-i`.
`C-c L` is lsp-mode's full command map; manual start/restart/shutdown are also
available as `M-x my/lsp-start`, `my/lsp-restart`, and `my/lsp-shutdown`.

Whole-buffer formatting prefers project-aware Apheleia, then LSP, then indentation.
Visual formatting requires a contiguous selection and LSP range-formatting
support: it does not silently format the whole file or slice a file for an
external formatter. Use `=` to indent when range formatting is unavailable.
Biome config and explicit directory-local formatter choices retain priority.
Format-on-save stays off by default. Global and buffer toggles apply for the
running session; changing major modes can reapply the global default.

## Search and replacement

| Keys | Action |
|---|---|
| `SPC /`, `SPC sg` / `SPC sG` | Project/current-directory text search |
| `SPC sb` / `SPC sB` | Current/all-open-buffer line search |
| `SPC sw` / `SPC sW` | Literal symbol/selection search in project/current directory |
| `SPC sr` | Search, then `RET` exports results into native grep-edit |
| `SPC sR`, `M-R` | Resume last picker |
| `SPC su`, `C-x u` | Vundo undo tree |
| `SPC :`, `SPC sc` | Command history |
| `SPC sC` | Command picker |
| `SPC si`, `SPC sm`, `SPC sM` | Imenu, marks, manual pages |
| `C-.`, `C-;` | Embark actions/default action |
| `M-y` | Kill-ring picker |

For replacement: `SPC sr`, enter a search, wait for results, then press `RET`.
Edit result text, finish with `\ c`, and save affected source buffers explicitly.
Grep/Occur edits update source buffers immediately; finishing is not a rollback
or automatic disk save. `C-g` cancels the picker without applying replacement.
Multiline selections are not supported by the word/selection search shortcuts.

## Git

| Keys | Action |
|---|---|
| `SPC gg`, `SPC gs`, `C-x g` | Magit status |
| `SPC gf` / `SPC gl` | Current-file/repository history |
| `SPC gb` / `SPC gd` | Blame/file diff |
| `[h` / `]h` | Previous/next hunk |
| `SPC ghp`, `SPC ghs`, `SPC ghr` | Preview, stage, revert hunk |
| `SPC gB` / `SPC gY` | Open/copy file or selection link |

## Terminals

| Keys | Action |
|---|---|
| `C-/`, `C-_` | Toggle this tab's project terminal pane |
| `SPC ft` | Show that same pane |
| `SPC fT` | Show a terminal for the current directory, owned by this tab |
| `4 SPC ft` / `4 SPC fT` | Fresh shell; previous shells remain alive |
| `C-h/j/k/l` | Navigate windows while typing in the shell |
| `C-q` | Quote the next terminal input key |

There is one root-terminal slot per tab, plus current-directory slots per tab.
The `ft` and Ctrl-slash paths reuse the same root slot. Interactive tasks start
independent shells. Removed duplicate terminal keys include `SPC te/ts/tt/tp/tn`,
`SPC pe/pt/pT`, and `C-x p e/s`; `SPC t` is now exclusively tests.

Ghostel is the only shell frontend. Popper (``C-` ``, ``M-` ``, ``C-M-` ``) manages
help, warnings, and compilation popups, not a second terminal system. Output
popups enter Evil Normal state on first display and when reopened, so motions
like `h/j/k/l`, `w/b`, `gg/G`, and `/` work immediately. Interactive shell and
minibuffer input retain their own controls.

## Tasks and focused tests

| Keys | Action |
|---|---|
| `SPC rr`, `SPC rR` | Run a general task / rerun it |
| `SPC ro`, `SPC rn` | General task output / next failure |
| `SPC rT` | Run a task in a fresh independent Ghostel shell |
| `SPC tt`, `SPC tr` | Test current file / nearest test |
| `SPC tl` | Repeat last focused test |
| `SPC to`, `SPC tS` | Test output / stop running test |

Test commands and buffers are tracked separately from general tasks, keyed by
canonical project root. Running a build does not overwrite the last focused
test or its output. Tests retain Python/pytest, JS/TS Vitest/Jest, and Go support.
Nearest JS/TS tests require a native parser and literal test names. Runners must
already be installed. Other frameworks and monorepo package-specific commands
can use the general task picker, which recognizes package scripts and common
Python, Go, Rust, and Make tasks.

Commands from `.dir-locals.el` still require Emacs's safe-variable approval;
opening a project never executes a task. Finite tasks prompt to save modified
project files before starting compilation-mode. Last command strings persist
through Savehist; running jobs and output buffers do not survive a restart.

## Project sessions

The `Super+p` session picker shows the current session first, followed by the
most recently used sessions. Each row shows a current-session marker, layout
tab count, and abbreviated project path (or `no project`). Type a new name to
create a session.

Select a session and press `C-.` for Embark actions:

| Key | Action |
|---|---|
| `RET` | Switch to the session |
| `k` | Close its layout tabs, keeping buffers and terminal processes alive |
| `r` | Rename the session and all its tabs' group metadata |
| `o` | Switch to the session and open its project directory in Dired |
| `s` | Save the desktop, including all sessions, using the existing desktop save |

Closing and renaming refresh the picker and keep it open for further actions;
saving also keeps it open. The last remaining session cannot be closed. Rename
rejects empty names and names already used by another session. Opening a
directory requires an associated project. Saving records layouts and file
positions, not unsaved buffer contents or running processes; `SPC q l` restores
the saved desktop.

Projects use native tab groups, with regular layout tabs inside each group.
`Super+p` switches groups and resumes the last active tab. `Super+1…9/0`
selects a tab within the active group; `Super+t/r/w` creates, renames, or closes
one.

The [project-tab-sessions package](https://github.com/xheisenbugx/project-tab-sessions)
is installed from GitHub using built-in `package-vc` support (Emacs 30+).
See its [installation and usage guide](https://github.com/xheisenbugx/project-tab-sessions#install)
and [package comparison](https://github.com/xheisenbugx/project-tab-sessions/blob/main/COMPARISON.md)
for the alternatives reviewed. `lisp/init-workspaces.el` configures the
package's presentation and Embark actions. Ghostel terminals remain attached
to their tabs.

## Windows and layout tabs

| Keys | Action |
|---|---|
| `SPC -`, `SPC \|` | Split below/right |
| `SPC wd`, `SPC wm`, `SPC w=` | Close window, zoom/restore, balance |
| `SPC wh/j/k/l` | Window navigation |
| `SPC wu`, `SPC wr` | Undo/redo window layout |
| `SPC TAB TAB`, `SPC TAB d` | New/close layout tab |
| `SPC TAB [` / `]`, `SPC TAB f` / `l` | Previous/next, first/last layout |
| `SPC TAB o` | Close other layouts in this session only |
| `SPC TAB b`, `SPC TAB r`, `SPC TAB N` | Pick, rename, create named layout |
| `SPC TAB g` / `G` | Session picker / move current tab to a group |
| `SPC TAB u` / `R` | Tab layout history back/forward |
| `Super+p`, `Super+1…9/0` | Session picker / select layout in current session |
| `Super+t/r/w`, `C-TAB`, `C-S-TAB` | New/rename/close tab, next/previous tab |

The old `SPC z` tab menu is removed. `C-c z` is the Insert-state tab-menu alias.
Native `C-x t` bindings remain available. Desktop saves retain files, positions,
groups, project roots, and layouts. Saved terminals become placeholders where
`RET` starts a fresh shell. It never recreates previous processes.
`SPC qs` saves and `SPC ql` restores the complete desktop; `SPC qq` quits.
`SPC qr` reloads one module, `SPC qf` opens private config, and `SPC qp` upgrades
packages. Restart after changing startup/package initialization.

## Other retained workflows

`SPC ul/uL` toggle line/relative numbers; `SPC uw` toggles wrapping; `SPC ub`
switches dark/light themes. `SPC m` retains Evil MC (`n/p/s/a/l/u/q`), also
available under `gz`. `SPC y` offers snippet insertion/creation/editing.
`SPC o` retains Org agenda/capture/dashboard/links. Mail remains opt-in under
`SPC M`. `C-c` aliases and standard mode-specific `C-c C-c` actions remain.

Flash retains `s/S/f/t/F/T` and `;/,` in Normal, Visual, and operator states.
Operator-state `S` returns a tree-sitter range. `SPC jc/jw` are the only custom
Avy character/word shortcuts; duplicate Meta/global aliases were removed.
Expansion (`C-=`), Evil Surround (`ys/cs/ds`), and commenting (`gc`) remain.

## Structural editing

Use `]q` / `[q` in Normal state to visit the next/previous result with
`next-error` / `previous-error`, including Embark-exported grep/Occur results
and compilation output.

[evil-textobj-plus](https://github.com/xheisenbugx/evil-textobj-plus) supplies
mini.ai-style nearby objects. Combine `i`/`a` with an object in Visual state or
after `d`, `c`, or `y`; normal-state Flash motions and `C-h/j/k/l` are unchanged.

| Example | Action |
| --- | --- |
| `ciq` | Change inside a nearby quoted string |
| `vab` then `ab` | Select any bracket pair, then expand outward |
| `d2ab` | Delete the second enclosing bracket object |
| `din)` / `dil)` | Delete inside the next / previous parentheses |
| `viF` / `vaF` | Select call arguments / the whole function call |
| `via` / `daa` | Select an argument / delete it and an adjacent comma |
| `vit` / `vat` | Select tag contents / balanced named tag |
| `g[b` / `g]b` | Move to the first / last character of the bracket object |

`(`, `[`, `{`, `<` trim inner whitespace; their closing counterparts preserve
it. `b` groups parentheses/brackets/braces; `q` groups quote types. Native word,
paragraph and other unmodified Evil text objects remain available. Bracket
objects also match in strings/comments, following mini.ai. Counts and
`.` repeat work with the new objects. Search tries the current line first, then at most 500 lines each way;
change `evil-textobj-plus-lines` or provide custom regexp/Tree-sitter objects
through `evil-textobj-plus-custom-objects`. See the package README for details.

With an active native Tree-sitter parser, `vaf` selects a function definition
and `cif` changes its body. This preserves our existing LazyVim mapping; upstream
mini.ai uses `f` for calls, which this config puts on `F`. Arguments use the
parser when available and syntax-based matching otherwise. `]m` / `[m` move
through function starts; `za` folds the surrounding block (Hideshow fallback).

Install the appropriate language grammar and use its `*-ts-mode` for structural
objects. Function definitions require a parser. Syntax-based calls, quotes and
tags are intentionally heuristic; use custom Tree-sitter providers for language
constructs such as template strings or HTML with implicit closing tags.

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

## Validation

See [README validation](../README.md#validation-and-contributing) for the offline
and isolated integration commands. `lazyvim-keymap-tests.el` covers state/key
precedence, terminal ownership, range formatting, diagnostics, call-hierarchy
routing, independent test history, session-scoped tab cleanup, and Git copy.
Graphical terminal startup and LSP-server-specific capabilities require runtime
verification beyond mocked integration checks.
