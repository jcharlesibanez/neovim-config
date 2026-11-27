# Versioning

Every commit to the Neovim config gets a version tag, `vX.Y.Z`. `:Update` (or `:update`)
reads that tag to show which version you're on, so read this before you commit.

## Which number to bump

| Change | Bump | Example |
|---|---|---|
| Fix, tweak, or small addition (a new alias command, a color change, a bug fix) | **patch** (third number) | v2.3.1 → v2.3.2 |
| New feature (a new mode, a new plugin, a new color scheme) | **minor** (second number) | v2.3.1 → v2.4.0 |
| Big overhaul that changes how the config feels to use | **major** (first number) | v2.3.1 → v3.0.0 |

If you're not sure between patch and minor, pick patch. Bumping minor or major resets the numbers after it to 0.

## Major versions have names

Each major version has a name. `:Update` shows it after the number, e.g. `v2.3.1 Delta`.

| Major | Name |
|---|---|
| v2 | Delta |

To start a new major:
1. Pick a name.
2. Add it to `M.codenames` in [nvim/lua/dreamcore/workbench.lua](nvim/lua/dreamcore/workbench.lua). For example, `{ [2] = 'Delta', [3] = 'YourName' }`.
3. Add it to the table above.

In git, only the **first** tag of a major carries the name (`v2.0.0 Delta: …`). Later tags in that major are plain (`v2.3.1: …`).

## How to commit

Tags are annotated, and their message is `vX.Y.Z: short summary`.

```bash
git commit -m "Short summary" -m "What changed and why."
git tag -a v2.3.2 -m "v2.3.2: short summary"
git push
git push origin v2.3.2
```

`git push` doesn't send tags, so push the tag on its own as well. Check the latest tag first with:

```bash
git describe --tags --abbrev=0
```

Try not to move a tag after it's pushed: anyone who already pulled keeps the old one. If you have to fix one, delete it locally and on GitHub (`git tag -d vX.Y.Z` and `git push origin :refs/tags/vX.Y.Z`), then tag again.
