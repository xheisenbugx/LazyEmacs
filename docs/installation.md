# Installation

LazyEmacs needs **Emacs 31.1 or newer** and **Git**. Everything else is
optional and only affects the feature that uses it.

- [1. Install Emacs and the tools](#1-install-emacs-and-the-tools)
- [2. Install LazyEmacs](#2-install-lazyemacs)
- [3. First launch](#3-first-launch)
- [4. Language support](#4-language-support)
- [Daemon and client](#daemon-and-client)
- [Updating](#updating)
- [Uninstalling](#uninstalling)

## 1. Install Emacs and the tools

| Tool | Used for | Required |
|---|---|---|
| Emacs 31.1+ | Everything | Yes |
| Git | Package installation, projects, Magit | Yes |
| [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`) | Project search, replace, TODO search | Strongly recommended |
| [fd](https://github.com/sharkdp/fd) | Fast file search (`find` is the fallback) | Recommended |
| A [Nerd Font](https://www.nerdfonts.com/) | Icons in the explorer and mode line | Recommended |
| C compiler | Tree-sitter grammars | For native syntax modes |
| Language servers, formatters, debuggers | Per language | As needed |
| aspell or hunspell | <kbd>SPC u s</kbd> spell checking | Optional |

Check the version you will actually launch with `emacs --version`; package
repositories often ship older releases.

### macOS

```sh
brew install --cask emacs          # or any Emacs 31 build, such as emacs-plus
brew install git ripgrep fd
brew install --cask font-jetbrains-mono-nerd-font
```

Command is Super (<kbd>s-</kbd>), Option is Meta (<kbd>M-</kbd>), and right
Option still types accented characters. GUI Emacs imports `PATH` from your
login shell, so tools installed by Homebrew, mise, nvm, or pyenv are found.
macOS reserves <kbd>C-Up</kbd>/<kbd>C-Down</kbd> for Mission Control; disable
those shortcuts in System Settings → Keyboard if you want window resizing on
them.

### Linux

Use your distribution's Emacs if it is 31.1 or newer (rolling releases such as
Arch usually are). Otherwise build from source or use a newer channel such as
Flatpak, Nix, Guix, or a PPA.

```sh
# Debian / Ubuntu
sudo apt install git ripgrep fd-find build-essential
# Fedora
sudo dnf install git ripgrep fd-find gcc
# Arch
sudo pacman -S emacs git ripgrep fd base-devel
```

Debian and Ubuntu name the fd binary `fdfind`; LazyEmacs recognizes both
names. GUI Emacs launched from a desktop menu imports `PATH` from your login
shell. In a terminal Emacs, copying reaches the system clipboard through
`wl-copy` (Wayland) or `xclip`/`xsel` (X11) when installed. Window managers
often reserve Super keys; every Super shortcut has a leader equivalent.

### Windows

```powershell
winget install GNU.Emacs Git.Git BurntSushi.ripgrep.MSVC sharkdp.fd
```

Scoop (`scoop install emacs git ripgrep fd`) works too. Emacs looks for its
configuration in `%APPDATA%\.emacs.d` unless `HOME` is set, so the simplest
option is the `--init-directory` launch shown below. Compiling tree-sitter
grammars needs `gcc` on `PATH`, for example from
[MSYS2](https://www.msys2.org/) (`pacman -S mingw-w64-ucrt-x86_64-gcc`).
Ghostel downloads a Windows terminal module on first use; builds without
dynamic-module support use Eshell for terminals.

## 2. Install LazyEmacs

### Try it next to your current configuration (recommended)

```sh
git clone https://github.com/xheisenbugx/LazyEmacs.git ~/.config/lazyemacs
emacs --init-directory ~/.config/lazyemacs
```

`--init-directory` keeps packages, history, and sessions inside that folder, so
your existing Emacs setup is untouched. Create a shell alias or desktop
shortcut for the command if you like it.

### Make it your default

Close Emacs and move your current configuration out of the way first:

```sh
mv ~/.emacs.d ~/.emacs.d.backup-$(date +%Y%m%d)   # skip if it does not exist
git clone https://github.com/xheisenbugx/LazyEmacs.git ~/.emacs.d
```

Also check for `~/.emacs`, `~/.emacs.el`, and `~/.config/emacs`: Emacs loads
the first one it finds, which may not be LazyEmacs.

### Optional: install packages from the terminal

The first launch downloads about 80 packages. To do it up front, with progress
in your terminal, run this inside the checkout:

```sh
emacs --batch --load scripts/bootstrap.el --grammars
```

Drop `--grammars` to skip compiling tree-sitter grammars.

## 3. First launch

1. Start Emacs with the network available. Packages install automatically;
   this takes a minute or two once and never again.
2. The dashboard appears. Press <kbd>SPC</kbd> and wait: Which Key shows every
   group. Press <kbd>SPC h D</kbd> for the **doctor**, which lists the tools and
   grammars it found and what each missing one affects.
3. If icons appear as boxes, run `M-x nerd-icons-install-fonts` (macOS and
   Linux; on Windows install a Nerd Font manually).
4. Open a project with <kbd>SPC f p</kbd> or <kbd>p</kbd> on the dashboard, then
   try <kbd>SPC SPC</kbd>, <kbd>SPC /</kbd>, <kbd>SPC e</kbd>, and <kbd>SPC g g</kbd>.

If something fails, read `*Warnings*` and `*Messages*` (<kbd>SPC n</kbd>) and see
[troubleshooting](troubleshooting.md).

## 4. Language support

LazyEmacs configures editors, not toolchains. For each language you use:

1. **Grammar:** <kbd>SPC h T</kbd> (`M-x lazyemacs-install-grammars`) compiles
   every missing grammar and switches to the native tree-sitter modes.
2. **Language server:** install it so it is on `PATH`, or try <kbd>SPC c m</kbd>.
3. **Formatter and debugger:** install what your project uses.

| Language | Server started automatically | Formatter | Debugger |
|---|---|---|---|
| TypeScript, JavaScript | `typescript-language-server` | Prettier or Biome | js-debug |
| Python | `basedpyright-langserver`, `pyright-langserver`, or `pylsp` | Ruff or Black | debugpy |
| Go | `gopls` | gofmt | Delve |
| Rust | `rust-analyzer` | rustfmt | CodeLLDB |
| Lua | `lua-language-server` | StyLua | — |
| Bash | `bash-language-server` | shfmt | — |
| JSON, CSS, HTML | `vscode-json/css/html-language-server` | Prettier or Biome | — |
| YAML | `yaml-language-server` | Prettier | — |
| Dockerfile | `docker-langserver` | — | — |

Markdown, Terraform, GraphQL, `.env`, `.http` (restclient), and Org have
editing modes without an automatic server. Any other language supported by
lsp-mode starts with `M-x my/lsp-start`.

## Daemon and client

```sh
emacs --init-directory ~/.config/lazyemacs --daemon=lazyemacs
emacsclient --socket-name=lazyemacs --create-frame
```

New client frames open the dashboard. An ordinary graphical launch also starts
a server, so `emacsclient` works from terminals and Git.

## Updating

```sh
cd ~/.config/lazyemacs   # or ~/.emacs.d
git pull --ff-only
```

Restart Emacs afterwards. Your `user/` directory, packages, and sessions are
ignored by Git and stay in place. Packages update separately with
<kbd>SPC q p</kbd>; <kbd>SPC l</kbd> shows installed versions. Package updates
can change behavior, so back up `elpa/` first if you need to roll back.

To start with installed packages only (no network), set `LAZYEMACS_OFFLINE=1`.

## Uninstalling

Quit Emacs and delete (or move) the LazyEmacs directory. Restore your previous
configuration if you moved it. External tools, fonts, and Org files live
elsewhere and are not affected.
