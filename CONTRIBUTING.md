# Contributing to LazyEmacs

Thank you for helping! Bug reports, platform testing (especially Linux and
Windows), documentation, and features are all welcome.

## Ground rules

- **LazyVim first.** If LazyVim has a key for something, use the same key and
  label. Document any unavoidable difference in `docs/keymaps.md` under
  "Intentional differences".
- **Portable defaults.** Nothing may depend on a username, home-directory
  layout, mail account, credentials, or a locally installed package. Guard
  platform-specific code with `system-type` and explain the fallback.
- **Never commit private state:** `user/`, `var/`, `etc/`, and `elpa/` are ignored
  for a reason.
- **Keep modules readable.** One feature area per `lisp/init-*.el` file, a
  Commentary section explaining why, and comments on non-obvious choices.
  Match the surrounding style: `my/` for commands, `lazyemacs-` for public
  options and functions, `use-package` for every package.

## Development workflow

```sh
emacs --init-directory /path/to/your/checkout    # try your change
python3 scripts/test.py                           # run every suite
python3 scripts/test.py --offline-only            # no packages needed
LAZYEMACS_TEST_SUITE=lazyvim-keymap-tests.el emacs -Q --batch --load scripts/integration.el
```

Tests use disposable state and refuse to download packages. Install packages
once with `emacs --batch --load scripts/bootstrap.el --grammars`.

### Changing keys

1. Edit the tables in `lisp/init-keymaps.el`. Every binding is
   `(KEY DESCRIPTION COMMAND)`.
2. Regenerate the reference:

   ```sh
   LAZYEMACS_UPDATE_DOCS=1 LAZYEMACS_TEST_SUITE=lazyvim-keymap-tests.el \
     emacs -Q --batch --load scripts/integration.el
   ```

3. If the key comes from LazyVim, add it to `my/lazyvim-reference-keys` in
   `tests/lazyvim-keymap-tests.el`.

### Adding a package

Declare it with `use-package` in the module it belongs to, defer it with
`:commands`, `:hook`, or `:defer` unless it must run at startup, and mention
new external tools in `docs/installation.md` and the doctor
(`lazyemacs-doctor` in `lisp/init-distribution.el`).

## Pull requests

Describe the user-visible problem, the new behavior, any migration effect for
existing users, and how you verified it: Emacs version, OS, graphical or
terminal, and which checks you ran or skipped. A passing batch run does not
prove graphical, cross-platform, or first-install behavior, so say what you
checked by hand. Changes to package sources, installation, native modules, or
command execution deserve an explicit note for reviewers.

## License

The project license has not been chosen yet. Please do not add third-party
source code until it is.
