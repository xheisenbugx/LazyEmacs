# Contributing to LazyEmacs

Keep shared defaults independent of a username, operating-system-specific home
path, mail account, credentials, and locally installed packages. Use the private
configuration examples to show customization; never commit your `user/`, `var/`,
`etc/`, or package directories.

Before changing a workflow, follow the commands from the leader map through the
relevant module and package. Preserve Evil state behavior, the C-c aliases,
project identity, and tab-owned terminal behavior. Add focused behavioral tests
for startup or workflow changes. Document new external dependencies and user
options in README.md and update examples when appropriate.

Run `python3 scripts/test.py` for all suites, or pass `--offline-only` for the
package-free checks. Tests refuse package downloads and upgrades. Report the actual Emacs
version, OS, package/grammar prerequisites, checks performed, skipped checks,
and whether first installation or only existing packages were tested. A local
batch pass does not establish graphical, cross-platform, or network-bootstrap
compatibility.

For a pull request, describe the user-visible problem, resulting behavior,
configuration/migration effects, and verification. Avoid unrelated formatting
or generated-file updates. Keep documentation commands copyable from the
repository root. Changes to archive sources, install behavior, native modules,
or executable task handling deserve explicit review.

This initial preparation has no chosen project license. Agree on licensing
with the repository owner before adding third-party source or redistributing
modified code under an assumed license.
