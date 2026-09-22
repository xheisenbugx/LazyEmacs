# Troubleshooting

Start with the doctor: <kbd>SPC h D</kbd> (`M-x lazyemacs-doctor`). It reports
the Emacs version, platform, tools found on `PATH`, installed grammars, and
package versions, without running or installing anything. Include its output
when you [open an issue](https://github.com/xheisenbugx/LazyEmacs/issues).

## Common problems

| Symptom | What to do |
|---|---|
| "LazyEmacs requires Emacs 31.1 or newer" | Run `emacs --version`. Your launcher may start a different Emacs than your terminal. |
| Your old configuration starts instead | Launch with `--init-directory`, and check for `~/.emacs`, `~/.emacs.el`, and `~/.config/emacs`. |
| A package fails to install | Read `*Warnings*`, check HTTPS and Git access, run `M-x my/package-refresh`, and restart. `emacs --batch --load scripts/bootstrap.el` shows the full error in the terminal. |
| Icons are boxes | `M-x nerd-icons-install-fonts`, then restart (Windows: install a Nerd Font manually). |
| The font does not change | Check the exact family name with `M-: (font-family-list)`. Fonts apply to graphical frames only. |
| <kbd>SPC /</kbd> finds nothing | Make sure `rg` is listed by the doctor and that you are inside a project. |
| No language server starts | The doctor lists the servers it looked for. The server must be on Emacs's `PATH` (restart after installing), or try <kbd>SPC c m</kbd>. `M-x my/lsp-start` starts one manually and shows errors. |
| Text objects like `vaf` fail | Install the grammar with <kbd>SPC h T</kbd> and reopen the file; a language server is not enough. |
| Grammar installation fails | A C compiler must be on `PATH` (Xcode Command Line Tools, `build-essential`, or MSYS2 `gcc`). |
| The terminal does not open | Ghostel needs dynamic-module support and downloads its native module on first use. Try `M-x ghostel-download-module`. Without module support, Eshell is used. |
| <kbd>C-Up</kbd>/<kbd>C-Down</kbd> do nothing on macOS | Mission Control uses them; disable those shortcuts or use <kbd>SPC w +</kbd>/<kbd>-</kbd>. |
| Super (<kbd>s-</kbd>) keys do nothing | The window manager takes them. Use the leader equivalents (<kbd>SPC TAB</kbd>). |
| Old tabs come back unexpectedly | Start once with `--no-desktop`, or press <kbd>SPC q d</kbd> before quitting. |
| A Customize change is ignored | Startup options belong in `user/early.el`; package settings in `user/config.el` inside `with-eval-after-load`. |
| Reloading a module did not undo a change | Restart Emacs. Evaluating Lisp adds settings but cannot remove earlier ones. |
| `void-variable evil-mode-buffers` | Update LazyEmacs and restart. The included compatibility shim fixes Evil 1.15 on Emacs 31. |
| Mail menu is missing | Set `lazyemacs-enable-mail` in `user/early.el` and restart. |

## Getting a backtrace

```sh
emacs --init-directory ~/.config/lazyemacs --debug-init
```

## Starting clean without losing anything

- Skip the saved session once: `--no-desktop`.
- Use installed packages only: `LAZYEMACS_OFFLINE=1 emacs …`.
- Rescue session with no configuration at all: `emacs -Q`.

Do not delete `user/` or `var/` as a first step: they hold your configuration,
history, and sessions. If you suspect a broken package, move `elpa/` aside and
start once with the network available to reinstall everything.

## Security notes

Opening a project never runs its commands. Tasks from `.dir-locals.el` still
need Emacs's safe-variable approval, and Org Babel asks before executing code.
Review tasks and source blocks from projects you do not trust.
