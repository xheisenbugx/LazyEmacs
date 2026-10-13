# Agent guidelines

Read [CONTRIBUTING.md](CONTRIBUTING.md) first: its ground rules, module style,
keymap workflow, and test commands apply to agents as well as people.

## Before you open a pull request

- Run `python3 scripts/test.py` and report the result, including anything
  skipped. Say what a batch run cannot prove (graphical frames, other
  platforms, first install) and what you checked by hand.
- Regenerate `docs/keymaps.md` when keys change, and update `CHANGELOG.md`
  under "Unreleased".

## Pull request descriptions

Every PR description has an "In plain words" section: a few sentences for a
reader who doesn't code, saying what was wrong or missing, what changes for
them, and what they need to do (often nothing). No code, file names or jargon
there; the technical detail goes in the other sections.
