# Keymaps

LazyEmacs follows the [LazyVim keymap reference](https://www.lazyvim.org/keymaps).
If a key does something in LazyVim, it should do the same thing here. Where
Emacs has no direct equivalent, the closest Emacs feature is used and listed
under [Intentional differences](#intentional-differences).

- <kbd>SPC</kbd> is the leader in Evil's Normal, Visual, and Motion states.
  Pause after any prefix and Which Key lists what comes next.
- Every leader group also works as <kbd>C-c</kbd> plus the same letter, from any
  state. For example, <kbd>C-c f f</kbd> is <kbd>SPC f f</kbd> while you type in
  Insert state.
- <kbd>SPC ?</kbd> lists the keys of the current major mode. <kbd>SPC s k</kbd>
  searches every active binding.

**Notation:** `SPC` is Space, `RET` is Return, `TAB` is Tab, `C-` is Control,
`M-` is Meta (Option on macOS, Alt elsewhere), `S-` is Shift, and `s-` is Super
(Command on macOS, the Windows key elsewhere).

## Contents

- [Everyday keys](#everyday-keys)
- [Code navigation and diagnostics](#code-navigation-and-diagnostics)
- [Motions, text objects, and surround](#motions-text-objects-and-surround)
- [Leader reference](#leader-reference)
- [Result buffers (backslash)](#result-buffers-backslash)
- [Emacs keys that were upgraded](#emacs-keys-that-were-upgraded)
- [Intentional differences](#intentional-differences)
- [Adding your own keys](#adding-your-own-keys)

## Everyday keys

| Keys | Action |
|---|---|
| <kbd>C-h</kbd> <kbd>C-j</kbd> <kbd>C-k</kbd> <kbd>C-l</kbd> | Go to the left/lower/upper/right window, also from Insert state and terminals |
| <kbd>C-Up</kbd> <kbd>C-Down</kbd> <kbd>C-Left</kbd> <kbd>C-Right</kbd> | Resize the window |
| <kbd>H</kbd> / <kbd>L</kbd>, <kbd>[b</kbd> / <kbd>]b</kbd> | Previous/next buffer |
| <kbd>M-j</kbd> / <kbd>M-k</kbd> | Move the line or selection down/up |
| <kbd>C-s</kbd> | Save the file (in editing buffers) |
| <kbd>&lt;</kbd> / <kbd>&gt;</kbd> in Visual state | Indent and keep the selection |
| <kbd>C-/</kbd> | Toggle the project terminal |
| <kbd>gc</kbd> + motion, <kbd>gcc</kbd> | Comment operator, comment line |
| <kbd>u</kbd> / <kbd>C-r</kbd> | Undo/redo (<kbd>SPC s u</kbd> shows the undo tree) |

## Code navigation and diagnostics

| Keys | Action |
|---|---|
| <kbd>gd</kbd> | Go to definition (falls back to xref without a language server) |
| <kbd>gr</kbd> | References |
| <kbd>gI</kbd> | Implementations |
| <kbd>gy</kbd> | Type definition |
| <kbd>gD</kbd> | Declaration |
| <kbd>K</kbd> | Documentation |
| <kbd>gK</kbd> | Signature help |
| <kbd>gai</kbd> / <kbd>gao</kbd> | Incoming/outgoing calls |
| <kbd>]d</kbd> / <kbd>[d</kbd> | Next/previous diagnostic |
| <kbd>]e</kbd> / <kbd>[e</kbd> | Next/previous error |
| <kbd>]w</kbd> / <kbd>[w</kbd> | Next/previous warning |
| <kbd>]q</kbd> / <kbd>[q</kbd> | Next/previous search, compilation, or quickfix result |
| <kbd>]h</kbd> / <kbd>[h</kbd> | Next/previous Git hunk |
| <kbd>]t</kbd> / <kbd>[t</kbd> | Next/previous TODO comment |
| <kbd>]m</kbd> / <kbd>[m</kbd> | Next/previous function start (tree-sitter) |
| <kbd>za</kbd> | Toggle the fold around point |
| <kbd>C-o</kbd> / <kbd>C-i</kbd> | Jump back/forward, including across LSP jumps |

## Motions, text objects, and surround

| Keys | Action |
|---|---|
| <kbd>s</kbd> | Flash jump: type characters, then press the label |
| <kbd>S</kbd> | Flash tree-sitter selection (returns a range after an operator) |
| <kbd>f</kbd> <kbd>t</kbd> <kbd>F</kbd> <kbd>T</kbd>, <kbd>;</kbd> <kbd>,</kbd> | Flash-enhanced character motions |
| <kbd>gsa</kbd> + motion + char | Add surrounding (mini.surround style) |
| <kbd>gsd</kbd> + char | Delete surrounding |
| <kbd>gsr</kbd> + old + new | Replace surrounding |
| <kbd>ys</kbd> / <kbd>ds</kbd> / <kbd>cs</kbd> | The same, with vim-surround keys |
| <kbd>gz</kbd> | Multiple cursors prefix (also <kbd>SPC m</kbd>) |

Text objects work after operators (<kbd>d</kbd>, <kbd>c</kbd>, <kbd>y</kbd>) and in
Visual state. They behave like mini.ai: they find the nearest match on the line
when point is not inside one.

| Object | Selects |
|---|---|
| <kbd>q</kbd> | Any quote pair (`ciq` changes inside the nearest string) |
| <kbd>b</kbd> | Any bracket pair; repeat `ab` to expand outward |
| <kbd>(</kbd> <kbd>[</kbd> <kbd>{</kbd> <kbd>&lt;</kbd> | That bracket, trimming inner whitespace (closing form keeps it) |
| <kbd>f</kbd> | Function definition (`af`) or body (`if`); needs a tree-sitter mode |
| <kbd>F</kbd> | Function call (`iF` selects the arguments) |
| <kbd>a</kbd> | Argument; `daa` also removes the adjacent comma |
| <kbd>t</kbd> | HTML/XML tag |
| <kbd>n</kbd> / <kbd>l</kbd> modifier | Next/last object, for example `din)` |

## Leader reference

This section is generated from `lisp/init-keymaps.el` and checked by the test
suite, so it always matches the running configuration. <kbd>SPC M</kbd> (mail)
appears only when `lazyemacs-enable-mail` is set.

<!-- BEGIN GENERATED LEADER: run the keymap tests with LAZYEMACS_UPDATE_DOCS=1 -->
### Top level

| Keys | Action |
|---|---|
| <kbd>SPC SPC</kbd> | Find files (root) |
| <kbd>SPC ,</kbd> | Buffers |
| <kbd>SPC /</kbd> | Grep (root) |
| <kbd>SPC :</kbd> | Command history |
| <kbd>SPC .</kbd> | Toggle scratch |
| <kbd>SPC `</kbd> | Other buffer |
| <kbd>SPC -</kbd> | Split below |
| <kbd>SPC &#124;</kbd> | Split right |
| <kbd>SPC ?</kbd> | Buffer keymaps |
| <kbd>SPC e</kbd> | Explorer (root) |
| <kbd>SPC E</kbd> | Explorer (cwd) |
| <kbd>SPC l</kbd> | Packages |
| <kbd>SPC L</kbd> | LazyEmacs changelog |
| <kbd>SPC n</kbd> | Notification history |

### <kbd>SPC b</kbd> Buffers (also <kbd>C-c b</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC b b</kbd> | Switch to other buffer |
| <kbd>SPC b d</kbd> | Delete buffer |
| <kbd>SPC b D</kbd> | Delete buffer and window |
| <kbd>SPC b o</kbd> | Delete other buffers |
| <kbd>SPC b i</kbd> | Delete invisible buffers |
| <kbd>SPC b j</kbd> | Pick buffer |
| <kbd>SPC b K</kbd> | Kill buffer… |

### <kbd>SPC c</kbd> Code (also <kbd>C-c c</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC c a</kbd> | Code action |
| <kbd>SPC c A</kbd> | Source action |
| <kbd>SPC c c</kbd> | Run codelens |
| <kbd>SPC c C</kbd> | Refresh codelens |
| <kbd>SPC c d</kbd> | Line diagnostics |
| <kbd>SPC c f</kbd> | Format |
| <kbd>SPC c l</kbd> | LSP info |
| <kbd>SPC c m</kbd> | Install language server |
| <kbd>SPC c o</kbd> | Organize imports |
| <kbd>SPC c r</kbd> | Rename symbol |
| <kbd>SPC c R</kbd> | Rename file |
| <kbd>SPC c s</kbd> | Symbols |

### <kbd>SPC d</kbd> Debug (also <kbd>C-c d</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC d a</kbd> | Run with arguments |
| <kbd>SPC d b</kbd> | Toggle breakpoint |
| <kbd>SPC d B</kbd> | Conditional breakpoint |
| <kbd>SPC d c</kbd> | Run/Continue |
| <kbd>SPC d C</kbd> | Run to cursor |
| <kbd>SPC d e</kbd> | Eval expression |
| <kbd>SPC d i</kbd> | Step into |
| <kbd>SPC d j</kbd> | Down stack frame |
| <kbd>SPC d k</kbd> | Up stack frame |
| <kbd>SPC d l</kbd> | Restart |
| <kbd>SPC d L</kbd> | Log point |
| <kbd>SPC d o</kbd> | Step out |
| <kbd>SPC d O</kbd> | Step over |
| <kbd>SPC d P</kbd> | Pause |
| <kbd>SPC d r</kbd> | Toggle REPL |
| <kbd>SPC d s</kbd> | Session |
| <kbd>SPC d t</kbd> | Terminate |
| <kbd>SPC d u</kbd> | Debugger UI |
| <kbd>SPC d w</kbd> | Watch expression |
| <kbd>SPC d X</kbd> | Remove all breakpoints |
| <kbd>SPC d p p</kbd> | Toggle profiler |
| <kbd>SPC d p h</kbd> | Profiler report |

### <kbd>SPC f</kbd> Files (also <kbd>C-c f</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC f b</kbd> | Buffers |
| <kbd>SPC f B</kbd> | Buffers (all) |
| <kbd>SPC f c</kbd> | Private config |
| <kbd>SPC f d</kbd> | Recent directories |
| <kbd>SPC f D</kbd> | Delete file |
| <kbd>SPC f e</kbd> | Explorer (root) |
| <kbd>SPC f E</kbd> | Explorer (cwd) |
| <kbd>SPC f f</kbd> | Find files (root) |
| <kbd>SPC f F</kbd> | Find files (cwd) |
| <kbd>SPC f g</kbd> | Find files (git) |
| <kbd>SPC f j</kbd> | Dired here |
| <kbd>SPC f n</kbd> | New file |
| <kbd>SPC f o</kbd> | Open externally |
| <kbd>SPC f p</kbd> | Projects |
| <kbd>SPC f r</kbd> | Recent |
| <kbd>SPC f R</kbd> | Recent (cwd) |
| <kbd>SPC f s</kbd> | Save |
| <kbd>SPC f S</kbd> | Save as |
| <kbd>SPC f t</kbd> | Terminal (root) |
| <kbd>SPC f T</kbd> | Terminal (cwd) |
| <kbd>SPC f u</kbd> | Sudo edit |
| <kbd>SPC f y</kbd> | Copy path |

### <kbd>SPC g</kbd> Git (also <kbd>C-c g</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC g b</kbd> | Blame |
| <kbd>SPC g B</kbd> | Browse (open) |
| <kbd>SPC g c</kbd> | Commits |
| <kbd>SPC g d</kbd> | Diff (file) |
| <kbd>SPC g D</kbd> | Diff (upstream) |
| <kbd>SPC g f</kbd> | File history |
| <kbd>SPC g g</kbd> | Magit (root) |
| <kbd>SPC g G</kbd> | Magit (cwd) |
| <kbd>SPC g l</kbd> | Log |
| <kbd>SPC g L</kbd> | Log (cwd) |
| <kbd>SPC g s</kbd> | Status |
| <kbd>SPC g S</kbd> | Stash |
| <kbd>SPC g Y</kbd> | Copy link |
| <kbd>SPC g h b</kbd> | Blame line |
| <kbd>SPC g h d</kbd> | Diff this |
| <kbd>SPC g h p</kbd> | Preview hunk |
| <kbd>SPC g h r</kbd> | Reset hunk |
| <kbd>SPC g h R</kbd> | Reset buffer |
| <kbd>SPC g h s</kbd> | Stage hunk |
| <kbd>SPC g h u</kbd> | Unstage file |

### <kbd>SPC h</kbd> Help (also <kbd>C-c h</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC h c</kbd> | Command |
| <kbd>SPC h D</kbd> | LazyEmacs doctor |
| <kbd>SPC h f</kbd> | Function |
| <kbd>SPC h i</kbd> | Info manuals |
| <kbd>SPC h k</kbd> | Key |
| <kbd>SPC h K</kbd> | Keymap |
| <kbd>SPC h l</kbd> | Search manuals |
| <kbd>SPC h m</kbd> | Major mode |
| <kbd>SPC h p</kbd> | Package |
| <kbd>SPC h T</kbd> | Install tree-sitter grammars |
| <kbd>SPC h v</kbd> | Variable |

### <kbd>SPC j</kbd> Jump (also <kbd>C-c j</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC j b</kbd> | Back |
| <kbd>SPC j c</kbd> | Char (avy) |
| <kbd>SPC j f</kbd> | Forward |
| <kbd>SPC j l</kbd> | Line |
| <kbd>SPC j o</kbd> | Outline |
| <kbd>SPC j w</kbd> | Word (avy) |

### <kbd>SPC m</kbd> Multiple cursors (also <kbd>C-c m</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC m a</kbd> | All matches |
| <kbd>SPC m l</kbd> | Cursor per selected line |
| <kbd>SPC m n</kbd> | Next match |
| <kbd>SPC m p</kbd> | Previous match |
| <kbd>SPC m s</kbd> | Skip match |
| <kbd>SPC m u</kbd> | Undo last cursor |
| <kbd>SPC m q</kbd> | Remove all cursors |

### <kbd>SPC o</kbd> Org (also <kbd>C-c o</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC o a</kbd> | Agenda |
| <kbd>SPC o c</kbd> | Capture |
| <kbd>SPC o d</kbd> | Daily dashboard |
| <kbd>SPC o l</kbd> | Store link |

### <kbd>SPC p</kbd> Projects (also <kbd>C-c p</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC p b</kbd> | Buffers |
| <kbd>SPC p c</kbd> | Compile |
| <kbd>SPC p d</kbd> | Dired |
| <kbd>SPC p f</kbd> | Find file |
| <kbd>SPC p k</kbd> | Kill buffers |
| <kbd>SPC p p</kbd> | Switch project |
| <kbd>SPC p s</kbd> | Search |

### <kbd>SPC q</kbd> Quit/Session (also <kbd>C-c q</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC q d</kbd> | Don't save current session |
| <kbd>SPC q f</kbd> | Private config |
| <kbd>SPC q l</kbd> | Restore last session |
| <kbd>SPC q p</kbd> | Upgrade packages |
| <kbd>SPC q q</kbd> | Quit all |
| <kbd>SPC q r</kbd> | Reload module |
| <kbd>SPC q s</kbd> | Restore session |
| <kbd>SPC q S</kbd> | Save session |

### <kbd>SPC r</kbd> Run tasks (also <kbd>C-c r</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC r n</kbd> | Next task failure |
| <kbd>SPC r o</kbd> | Task output |
| <kbd>SPC r r</kbd> | Run task |
| <kbd>SPC r R</kbd> | Rerun task |
| <kbd>SPC r T</kbd> | Run task in terminal |

### <kbd>SPC s</kbd> Search (also <kbd>C-c s</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC s "</kbd> | Registers |
| <kbd>SPC s /</kbd> | Search history |
| <kbd>SPC s b</kbd> | Buffer lines |
| <kbd>SPC s B</kbd> | Grep open buffers |
| <kbd>SPC s c</kbd> | Command history |
| <kbd>SPC s C</kbd> | Commands |
| <kbd>SPC s d</kbd> | Diagnostics |
| <kbd>SPC s D</kbd> | Buffer diagnostics |
| <kbd>SPC s f</kbd> | Find files (fd) |
| <kbd>SPC s g</kbd> | Grep (root) |
| <kbd>SPC s G</kbd> | Grep (cwd) |
| <kbd>SPC s h</kbd> | Help pages |
| <kbd>SPC s H</kbd> | Highlights (faces) |
| <kbd>SPC s i</kbd> | Imenu |
| <kbd>SPC s j</kbd> | Jumps |
| <kbd>SPC s k</kbd> | Keymaps |
| <kbd>SPC s l</kbd> | Location list |
| <kbd>SPC s m</kbd> | Marks |
| <kbd>SPC s M</kbd> | Man pages |
| <kbd>SPC s q</kbd> | Quickfix list |
| <kbd>SPC s r</kbd> | Search and replace |
| <kbd>SPC s R</kbd> | Resume |
| <kbd>SPC s s</kbd> | Symbols |
| <kbd>SPC s S</kbd> | Symbols (workspace) |
| <kbd>SPC s t</kbd> | Todo |
| <kbd>SPC s T</kbd> | Todo/Fix/Fixme |
| <kbd>SPC s u</kbd> | Undo tree |
| <kbd>SPC s w</kbd> | Word (root) |
| <kbd>SPC s W</kbd> | Word (cwd) |

### <kbd>SPC t</kbd> Tests (also <kbd>C-c t</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC t l</kbd> | Run last |
| <kbd>SPC t o</kbd> | Show output |
| <kbd>SPC t r</kbd> | Run nearest |
| <kbd>SPC t S</kbd> | Stop |
| <kbd>SPC t t</kbd> | Run file |
| <kbd>SPC t T</kbd> | Run all test files |

### <kbd>SPC u</kbd> UI toggles (also <kbd>C-c u</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC u A</kbd> | Tabline |
| <kbd>SPC u b</kbd> | Dark background |
| <kbd>SPC u C</kbd> | Colorscheme |
| <kbd>SPC u d</kbd> | Diagnostics |
| <kbd>SPC u f</kbd> | Auto format (global) |
| <kbd>SPC u F</kbd> | Auto format (buffer) |
| <kbd>SPC u g</kbd> | Indent guides |
| <kbd>SPC u h</kbd> | Inlay hints |
| <kbd>SPC u i</kbd> | Inspect position |
| <kbd>SPC u I</kbd> | Inspect tree |
| <kbd>SPC u l</kbd> | Line numbers |
| <kbd>SPC u L</kbd> | Relative numbers |
| <kbd>SPC u p</kbd> | Auto pairs |
| <kbd>SPC u r</kbd> | Redraw / clear highlight |
| <kbd>SPC u s</kbd> | Spelling |
| <kbd>SPC u w</kbd> | Wrap |
| <kbd>SPC u Z</kbd> | Zoom window |

### <kbd>SPC w</kbd> Windows (also <kbd>C-c w</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC w 1</kbd> | Only this window |
| <kbd>SPC w a</kbd> | Ace window |
| <kbd>SPC w d</kbd> | Delete window |
| <kbd>SPC w h</kbd> | Go left |
| <kbd>SPC w j</kbd> | Go down |
| <kbd>SPC w k</kbd> | Go up |
| <kbd>SPC w l</kbd> | Go right |
| <kbd>SPC w m</kbd> | Zoom (maximize) |
| <kbd>SPC w u</kbd> | Undo layout |
| <kbd>SPC w U</kbd> | Redo layout |

### <kbd>SPC x</kbd> Diagnostics/quickfix (also <kbd>C-c x</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC x x</kbd> | Diagnostics (workspace) |
| <kbd>SPC x X</kbd> | Buffer diagnostics |
| <kbd>SPC x f</kbd> | Flycheck picker |
| <kbd>SPC x l</kbd> | Location list |
| <kbd>SPC x L</kbd> | Location list |
| <kbd>SPC x q</kbd> | Quickfix list |
| <kbd>SPC x Q</kbd> | Quickfix list |
| <kbd>SPC x t</kbd> | Todo |
| <kbd>SPC x T</kbd> | Todo/Fix/Fixme |

### <kbd>SPC y</kbd> Snippets (also <kbd>C-c y</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC y i</kbd> | Insert snippet |
| <kbd>SPC y n</kbd> | New snippet |
| <kbd>SPC y v</kbd> | Visit snippet file |

### <kbd>SPC TAB</kbd> Tabs (also <kbd>C-c z</kbd>)

| Keys | Action |
|---|---|
| <kbd>SPC TAB TAB</kbd> | New tab |
| <kbd>SPC TAB [</kbd> | Previous tab |
| <kbd>SPC TAB ]</kbd> | Next tab |
| <kbd>SPC TAB b</kbd> | Pick tab |
| <kbd>SPC TAB d</kbd> | Close tab |
| <kbd>SPC TAB f</kbd> | First tab |
| <kbd>SPC TAB g</kbd> | Sessions |
| <kbd>SPC TAB G</kbd> | Move tab to session |
| <kbd>SPC TAB l</kbd> | Last tab |
| <kbd>SPC TAB N</kbd> | New named layout |
| <kbd>SPC TAB o</kbd> | Close other tabs |
| <kbd>SPC TAB r</kbd> | Rename tab |
| <kbd>SPC TAB R</kbd> | Layout history forward |
| <kbd>SPC TAB u</kbd> | Layout history back |
<!-- END GENERATED LEADER -->

<kbd>SPC w</kbd> inherits every key of Vim's <kbd>CTRL-W</kbd> map, as LazyVim
does: <kbd>s</kbd> <kbd>v</kbd> split, <kbd>w</kbd> <kbd>W</kbd> cycle,
<kbd>q</kbd> <kbd>c</kbd> close, <kbd>o</kbd> keep only this window,
<kbd>x</kbd> <kbd>r</kbd> <kbd>R</kbd> exchange/rotate, <kbd>H</kbd>
<kbd>J</kbd> <kbd>K</kbd> <kbd>L</kbd> move, and <kbd>+</kbd> <kbd>-</kbd>
<kbd>&lt;</kbd> <kbd>&gt;</kbd> <kbd>=</kbd> <kbd>_</kbd> <kbd>&#124;</kbd> resize.

## Result buffers (backslash)

Grep, Occur, Dired, compilation, and Embark collection buffers have a small
local leader on <kbd>\\</kbd> in Normal state. This is how project-wide search and
replace works (the equivalent of LazyVim's grug-far):

1. <kbd>SPC s r</kbd>, type a search, and press <kbd>RET</kbd> to export the results.
2. The results buffer opens in edit mode. Change the text with any Vim command.
3. Press <kbd>\\ c</kbd> to apply the changes, then save the affected files.

| Keys | Action |
|---|---|
| <kbd>\\ e</kbd> | Edit grep/Occur results or Dired file names |
| <kbd>\\ c</kbd> | Apply the edits and return to browsing |
| <kbd>\\ r</kbd> | Refresh the results |
| <kbd>\\ f</kbd> | Follow the result under point in another window |
| <kbd>\\ a</kbd> | Embark actions for the item under point |
| <kbd>\\ q</kbd> | Close the window |

## Emacs keys that were upgraded

Standard Emacs keys keep working and use the richer pickers:

| Keys | Action |
|---|---|
| <kbd>C-x b</kbd> | Buffer picker with previews |
| <kbd>M-y</kbd> | Kill-ring (clipboard history) picker |
| <kbd>C-.</kbd> / <kbd>C-;</kbd> | Embark actions / default action for the thing at point |
| <kbd>C-=</kbd> | Expand the selection |
| <kbd>M-R</kbd> | Resume the last picker |
| <kbd>C-`</kbd> / <kbd>M-`</kbd> | Toggle/cycle popups (help, compilation, warnings) |
| <kbd>C-x u</kbd> | Undo tree |
| <kbd>C-h f</kbd> <kbd>C-h v</kbd> <kbd>C-h k</kbd> | Helpful documentation |
| <kbd>s-p</kbd>, <kbd>s-1</kbd> … <kbd>s-0</kbd> | Session picker, select layout tab |
| <kbd>s-t</kbd> / <kbd>s-r</kbd> / <kbd>s-w</kbd> | New/rename/close layout tab |
| <kbd>C-TAB</kbd> / <kbd>C-S-TAB</kbd> | Next/previous layout tab |

## Intentional differences

These are deliberate, usually because Emacs already owns the key or has a
better native tool:

- **<kbd>C-h/j/k/l</kbd> always move between windows**, even in Insert state
  and terminals. LazyVim's Insert-state <kbd>C-k</kbd> signature help is on
  <kbd>gK</kbd>.
- **Sessions persist automatically.** Emacs saves the desktop (files, cursor
  positions, tab groups, layouts) on exit. <kbd>SPC q s</kbd>/<kbd>SPC q l</kbd>
  restore it, <kbd>SPC q d</kbd> stops saving, and <kbd>SPC q S</kbd> saves
  immediately. Running processes are never restored; saved terminals come
  back as placeholders where <kbd>RET</kbd> starts a fresh shell.
- **Diagnostics use pickers instead of a Trouble panel.** <kbd>SPC x x</kbd> and
  <kbd>SPC x X</kbd> open searchable, previewing lists.
- **Git uses Magit** where LazyVim uses lazygit. <kbd>SPC g g</kbd> opens it.
- **Tests run in compilation buffers** (<kbd>SPC t</kbd>): errors are clickable
  and <kbd>]q</kbd> walks through failures. There is no neotest summary tree.
- **Mason is lsp-mode's installer.** <kbd>SPC c m</kbd> installs servers that
  lsp-mode knows how to download; other servers come from your package manager.
- **`gco`/`gcO` do not exist**, because <kbd>gc</kbd> is a complete Evil operator
  here. Use <kbd>o</kbd> then <kbd>M-;</kbd>.
- **Emacs extensions** with no LazyVim counterpart: <kbd>SPC r</kbd> (project
  tasks), <kbd>SPC o</kbd> (Org), <kbd>SPC m</kbd> (multiple cursors),
  <kbd>SPC y</kbd> (snippets), <kbd>SPC j</kbd> (Avy/xref jumps),
  <kbd>SPC p</kbd> (project.el), and the <kbd>\\</kbd> local actions.

## Adding your own keys

The whole leader is an ordinary keymap, `my/leader-map`, and each group has its
own map (`my/leader-file-map`, `my/leader-code-map`, and so on). Bindings use
`("Description" . command)` so Which Key shows your label. In `user/config.el`:

```elisp
;; A new top-level key and a key inside an existing group.
(keymap-set my/leader-map "z" '("Zen mode" . olivetti-mode))
(keymap-set my/leader-git-map "t" '("Time machine" . git-timemachine))

;; A whole new group, available as SPC a and C-c a.
(defvar-keymap my/leader-ai-map
  "c" '("Chat" . gptel)
  "r" '("Rewrite region" . gptel-rewrite))
(keymap-set my/leader-map "a" (cons "AI" my/leader-ai-map))
(keymap-global-set "C-c a" (cons "AI" my/leader-ai-map))
```
