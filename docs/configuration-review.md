# LazyEmacs configuration review — 2026-09-21

LazyEmacs already has a coherent editor stack: Evil owns modal editing,
Consult/Embark owns selection and result actions, native tab groups own project
layouts, Ghostel owns terminals, and LSP integrates with Corfu and Flycheck.
This review retains those choices and improves the distribution's failure
handling, setup behavior, and consistency across languages.

## Findings addressed

| Priority | Finding | Result |
|---|---|---|
| High | The booster advised `json-parse-buffer` globally and executed bytecode from any input beginning with `#`, including unrelated JSON consumers. | Use `--disable-bytecode` and ordinary JSON. Keep the booster's buffered transport, remove the global decoder, and protect the module from live reload. |
| High | Startup temporarily disabled all file-name handlers and raised the GC threshold without cleanup around a failing private init file. | Keep compressed/remote file handlers active. An `unwind-protect` restores GC on success and failure; `after-init-hook` also restores it before command-line file handling. |
| Medium | Validation could download packages into the shared installation. Startup refreshed missing archive metadata even if all packages were installed. | Add explicit offline package policy, prerequisite errors naming missing ELPA/VC packages, and disposable test state. Refresh only when installation needs metadata. |
| Medium | `.ts` could fall into Fundamental mode without its grammar; most installed native grammars were not selected automatically. | Install a regular TypeScript fallback for TS/MTS/CTS/TSX, select supported native modes when their grammars exist, and provide an explicit refresh command. TSX fallback does not incorrectly use the plain TS parser. |
| Medium | Emacs 31's native TypeScript ancestry and deferred fallback metadata could conflict when Yasnippet merged JS/TS tables. | Load fallback ancestry when the native TypeScript library loads. A regression test exercises actual native-mode snippet lookup. |
| Medium | `gr` and file-symbol pickers required LSP even though equivalent native navigation was available. | References fall back to xref; file symbols fall back to Imenu. Diagnostics toggling gives a clear error outside managed buffers. |
| Medium | Python tests always used `python` from PATH, and focused tests accepted files outside the selected project. | Prefer the project's `.venv`, then an existing uv environment without synchronization, then PATH. Reject unrelated files and protect leading-dash filenames from option interpretation. |
| Medium | An explicit session save could target a desktop locked by another process. | Refuse manual saves under a foreign lock. This does not add support for concurrently sharing a desktop between processes. |
| Low | macOS daemons skipped shell PATH import. | Import the environment for daemon startup as well as GUI startup. |
| Low | File search ignored Debian/Ubuntu's `fdfind`; formatter selection could probe remote directory ancestry. | Recognize both fd executable names; skip local Biome discovery in remote directories. |
| Low | Doctor output listed executables but did not explain the current language/package setup. | Include current mode/LSP attachment, grammar readiness, package versions, source/state locations, and feature-specific tool descriptions. |
| Low | Module reload used the state directory as the source path; Customize was loaded after package setup. | Reload from the distribution source and load private Customize settings before bootstrap so startup options take effect in time. |

## Validation

Run `python3 scripts/test.py` from the repository root. It discovers every
integration suite, runs syntax/startup checks first, and refuses package
downloads. `--offline-only` requires no installed third-party packages.

The final suite passes **68 ERT tests** on macOS with **Emacs 31.1**, including
the existing keymap, Flash operator, result-editing, session round-trip, and
task tests. New tests cover startup failure, package network policy, malformed
JSON, missing grammars, fallback navigation, Python environments, and session
lock conflicts. Targeted byte compilation of the distribution options,
package policy, and booster modules passes with warnings treated as errors.

An isolated daemon using disposable state completed actual startup with no
init error or `*Warnings*` buffer. It imported the shell environment, kept
file-name handlers active, and used offline package policy. Its first observed
startup took approximately 2.9 seconds on this machine; this is a smoke-test
observation, not a before/after benchmark. Shell PATH import reported taking
about 1.5 seconds.

A disposable TypeScript project attached to a real language server through
`emacs-lsp-booster --disable-bytecode -- ...`. The server returned diagnostic
2322 for assigning a number to a string and a correct definition location.
Flycheck displayed the diagnostic after an explicit refresh. This verifies
the JSON transport and client integration, not every language-server feature.

The TypeScript fallback package was installed from NonGNU ELPA. The broader
package set and the TypeScript grammar were already installed. Full bootstrap
from an empty package directory, graphical frame behavior, live Ghostel
creation, mail delivery, and Linux/Windows execution were not validated.

## Applying the changes

The updated doctor and safe navigation, task, search, reload, and manual
session-save commands were activated in the existing Emacs process. Restart
Emacs once to apply package/startup policy, native-mode selection, and the
new LSP transport. Existing language servers were left running with their
matching decoder until that restart.

Useful commands:

- `SPC h D`: environment, grammar, and package report.
- `M-x lazyemacs-refresh-language-modes`: reconsider installed grammars, then
  reopen the file.
- `LAZYEMACS_OFFLINE=1 emacs --init-directory /path/to/LazyEmacs`: start using
  installed packages only.
- `python3 scripts/test.py`: run all regression suites without downloads.

## Release work that remains

- Package declarations still track archive versions and newest VC revisions.
  A reviewed lock/snapshot and restore mechanism is needed for reproducible
  releases; source rollback alone does not restore packages.
- A clean-machine CI matrix should exercise bootstrap, grammar installation,
  GUI/terminal startup, and native Ghostel modules on supported platforms.
- Emacs 31.1 remains the minimum because result editing uses its native APIs.
  Supporting stable older Emacs releases would require an explicit compatibility
  design and separate tests.
- The repository still needs its owner's distribution-license decision before
  it can be presented as an openly licensed release.

## Upstream references

- [GNU Emacs startup ordering](https://www.gnu.org/software/emacs/manual/html_node/elisp/Startup-Summary.html)
  explains why runtime settings must be restored before command-line file visits.
- [GNU Emacs major-mode selection](https://www.gnu.org/software/emacs/manual/html_node/emacs/Choosing-Modes.html)
  describes `major-mode-remap-alist`.
- [emacs-lsp-booster](https://github.com/blahgeek/emacs-lsp-booster)
  documents its separate buffering and bytecode mechanisms. The installed
  executable's `--help` confirms `--disable-bytecode` forwards ordinary JSON.
