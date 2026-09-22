<div align="center">

# 💤 LazyEmacs

### Evil Emacs, the LazyVim way.

LazyVim's keymaps, pickers, and batteries-included workflow,<br>
running on the most extensible editor ever made.

[![Emacs 31.1+](https://img.shields.io/badge/Emacs-31.1%2B-7F5AB6?logo=gnuemacs&logoColor=white)](https://www.gnu.org/software/emacs/)
[![macOS · Linux · Windows](https://img.shields.io/badge/platforms-macOS%20·%20Linux%20·%20Windows-89b4fa)](docs/installation.md)
[![CI](https://github.com/xheisenbugx/LazyEmacs/actions/workflows/ci.yml/badge.svg)](https://github.com/xheisenbugx/LazyEmacs/actions/workflows/ci.yml)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-a6e3a1)](CONTRIBUTING.md)

[**Install**](#-quick-start) · [**Keymaps**](docs/keymaps.md) · [**Workflows**](docs/workflows.md) · [**Configure**](docs/configuration.md)

</div>

```text
██╗      █████╗ ███████╗██╗   ██╗███████╗███╗   ███╗ █████╗  ██████╗███████╗
██║     ██╔══██╗╚══███╔╝╚██╗ ██╔╝██╔════╝████╗ ████║██╔══██╗██╔════╝██╔════╝
██║     ███████║  ███╔╝  ╚████╔╝ █████╗  ██╔████╔██║███████║██║     ███████╗
██║     ██╔══██║ ███╔╝    ╚██╔╝  ██╔══╝  ██║╚██╔╝██║██╔══██║██║     ╚════██║
███████╗██║  ██║███████╗   ██║   ███████╗██║ ╚═╝ ██║██║  ██║╚██████╗███████║
╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝

                         Evil Emacs, the LazyVim way

                         f   Find file
                         n   New file
                         p   Projects
                         g   Find text
                         r   Recent files
                         c   Config
                         s   Restore session
                         l   Packages
                         q   Quit
```

## ✨ Why LazyEmacs?

- **Your LazyVim muscle memory works on day one.** <kbd>SPC SPC</kbd>,
  <kbd>SPC /</kbd>, <kbd>SPC e</kbd>, <kbd>gd</kbd>, <kbd>gr</kbd>,
  <kbd>]d</kbd>, <kbd>SPC c a</kbd>, <kbd>SPC g g</kbd>, <kbd>SPC d b</kbd>,
  <kbd>s</kbd> to Flash-jump: the leader follows the
  [LazyVim keymap reference](https://www.lazyvim.org/keymaps), and the test
  suite checks the keys against it.
- **Discoverable.** Press <kbd>SPC</kbd> and pause. Which Key shows every group
  with LazyVim's labels, all the way down.
- **Batteries included.** Language servers, completion, diagnostics, formatting,
  debugging, Git, a file explorer, terminals, tasks, tests, sessions, and a
  dashboard, configured to work together from the first launch.
- **Emacs superpowers, no Vimscript required.** Magit, Org mode, editable grep
  results, Dired, TRAMP, Embark actions on anything, and every Emacs package
  ever written.
- **Plain, readable Emacs Lisp.** No framework and no macros to learn: small
  `use-package` modules you can read in an afternoon, built on Emacs's own
  package manager.
- **Your config stays yours.** Personal settings live in `user/`, ignored by Git,
  so `git pull` updates the distribution without conflicts.
- **Responsive by design.** Features load when first used, grammars are probed
  once instead of on every file, local language servers can use
  `emacs-lsp-booster`, and nothing native-compiles in the background.

## 🚀 Quick start

You need **Emacs 31.1+** and **Git**; [ripgrep](https://github.com/BurntSushi/ripgrep),
[fd](https://github.com/sharkdp/fd), and a [Nerd Font](https://www.nerdfonts.com/)
are recommended. Try it without touching your current setup:

```sh
git clone https://github.com/xheisenbugx/LazyEmacs.git ~/.config/lazyemacs
emacs --init-directory ~/.config/lazyemacs
```

The first launch installs packages (a minute or two, once). Then press
<kbd>SPC h D</kbd> to see which optional tools were found, and
<kbd>SPC h T</kbd> to compile tree-sitter grammars.

Platform-specific commands for macOS, Linux, and Windows, making it your
default configuration, and a headless installer are in the
**[installation guide](docs/installation.md)**.

## ⌨️ The keys you already know

| Keys | Action | | Keys | Action |
|---|---|---|---|---|
| <kbd>SPC SPC</kbd> | Find files | | <kbd>gd</kbd> / <kbd>gr</kbd> | Definition / references |
| <kbd>SPC /</kbd> | Grep project | | <kbd>K</kbd> | Hover documentation |
| <kbd>SPC ,</kbd> | Switch buffer | | <kbd>SPC c a</kbd> | Code action |
| <kbd>SPC e</kbd> | File explorer | | <kbd>SPC c r</kbd> | Rename symbol |
| <kbd>SPC f r</kbd> | Recent files | | <kbd>SPC c f</kbd> | Format |
| <kbd>SPC s r</kbd> | Search and replace | | <kbd>]d</kbd> / <kbd>[d</kbd> | Next / previous diagnostic |
| <kbd>SPC s t</kbd> | Find TODOs | | <kbd>SPC x x</kbd> | Diagnostics list |
| <kbd>SPC g g</kbd> | Git (Magit) | | <kbd>SPC d b</kbd> / <kbd>SPC d c</kbd> | Breakpoint / debug |
| <kbd>C-/</kbd> | Terminal | | <kbd>SPC t r</kbd> | Run nearest test |
| <kbd>s</kbd> | Flash jump | | <kbd>gsa</kbd> / <kbd>gsd</kbd> | Add / delete surrounding |
| <kbd>H</kbd> / <kbd>L</kbd> | Previous / next buffer | | <kbd>C-h/j/k/l</kbd> | Move between windows |
| <kbd>SPC q s</kbd> | Restore session | | <kbd>SPC u C</kbd> | Pick a colorscheme |

Every leader group also works as <kbd>C-c</kbd> plus the same letter, so the
whole menu is reachable from Insert state. The complete, auto-generated list is
in **[docs/keymaps.md](docs/keymaps.md)**.

## 🧩 What's inside

| LazyVim | LazyEmacs | |
|---|---|---|
| lazy.nvim | package.el + use-package | built in |
| which-key.nvim | Which Key | built in |
| snacks.picker / telescope | [Vertico](https://github.com/minad/vertico), [Consult](https://github.com/minad/consult), [Orderless](https://github.com/oantolin/orderless), [Embark](https://github.com/oantolin/embark) | |
| blink.cmp | [Corfu](https://github.com/minad/corfu) + [Cape](https://github.com/minad/cape) | |
| nvim-lspconfig + mason.nvim | [lsp-mode](https://github.com/emacs-lsp/lsp-mode) (+ `lsp-install-server`) | |
| nvim-treesitter | Native tree-sitter modes | built in |
| mini.ai | [evil-textobj-plus](https://github.com/xheisenbugx/evil-textobj-plus) | |
| mini.surround | [evil-surround](https://github.com/emacs-evil/evil-surround) (`gs*` and `ys/ds/cs`) | |
| flash.nvim | [flash](https://github.com/Prgebish/flash) | |
| conform.nvim | [Apheleia](https://github.com/radian-software/apheleia) | |
| nvim-lint + trouble.nvim | [Flycheck](https://www.flycheck.org/) + diagnostic pickers | |
| gitsigns.nvim | [diff-hl](https://github.com/dgutov/diff-hl) | |
| lazygit | [Magit](https://magit.vc/) | |
| nvim-dap | [Dape](https://github.com/svaante/dape) | |
| neotest | Focused test runner (pytest, Vitest, Jest, Go) | built in |
| grug-far.nvim | Editable grep results | built in |
| todo-comments.nvim | [hl-todo](https://github.com/tarsius/hl-todo) + project search | |
| snacks.indent | [indent-bars](https://github.com/jdtsmith/indent-bars) | |
| snacks.explorer / neo-tree | [Dirvish](https://github.com/alexluigit/dirvish) | |
| snacks.terminal | [Ghostel](https://github.com/dakra/ghostel) (libghostty) | |
| snacks.dashboard | LazyEmacs dashboard | built in |
| persistence.nvim | Desktop + [project-tab-sessions](https://github.com/xheisenbugx/project-tab-sessions) | |
| lualine | [doom-modeline](https://github.com/seagle0128/doom-modeline) | |
| tokyonight | [Catppuccin](https://github.com/catppuccin/emacs) / Modus | |
| — | [Org mode](https://orgmode.org/), TRAMP, [Helpful](https://github.com/Wilfred/helpful), multiple cursors, snippets, project tasks | Emacs extras |

## 🌍 Platforms

| | macOS | Linux | Windows |
|---|---|---|---|
| Editor, pickers, LSP, Git, debugging | ✅ | ✅ | ✅ |
| Terminals (Ghostel) | ✅ | ✅ | ✅ (Eshell without module support) |
| Shell `PATH` in GUI Emacs | ✅ | ✅ | system `PATH` |
| Clipboard in terminal Emacs | `pbcopy` | `wl-copy`, `xclip`, `xsel` | native |

Development happens on macOS. The CI workflow runs the test suite on macOS,
Linux, and Windows for every push, but Linux and Windows see less daily use:
[reports are very welcome](https://github.com/xheisenbugx/LazyEmacs/issues).

## ⚙️ Make it yours

Personal settings go in `user/` (copy the templates from `examples/`):

```elisp
;; user/early.el: options read at startup
(setq lazyemacs-dark-theme 'modus-vivendi
      lazyemacs-font-height 150)

;; user/config.el: packages and keys, loaded last
(use-package gptel :commands gptel)
(keymap-set my/leader-map "a" '("AI chat" . gptel))
```

See **[configuration](docs/configuration.md)** for every option and more recipes.

## 📚 Documentation

| Guide | What it covers |
|---|---|
| [Installation](docs/installation.md) | Emacs 31 and tools on macOS, Linux, Windows; first launch; updating |
| [Keymaps](docs/keymaps.md) | Every key, generated from the source, and differences from LazyVim |
| [Workflows](docs/workflows.md) | Search and replace, LSP, debugging, terminals, tasks, tests, sessions, Git |
| [Configuration](docs/configuration.md) | Options, recipes, mail, startup order, where state lives |
| [Troubleshooting](docs/troubleshooting.md) | The doctor, common problems, recovery |
| [Changelog](CHANGELOG.md) | What changed in each release |

## 🧪 Contributing

Contributions of all sizes are welcome: bug reports, platform testing, docs,
and features. The test suite runs without network access:

```sh
python3 scripts/test.py                  # everything (needs installed packages)
python3 scripts/test.py --offline-only   # syntax and startup checks only
```

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## 🙏 Acknowledgements

LazyEmacs is inspired by [LazyVim](https://www.lazyvim.org/) by
[@folke](https://github.com/folke) and stands on the shoulders of
[Evil](https://github.com/emacs-evil/evil) and the package authors linked above.
It is an independent project, not affiliated with LazyVim.

> **License:** a license has not been chosen yet. Until one is added, the code
> is not licensed for redistribution. Dependencies keep their own licenses.
