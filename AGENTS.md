# AGENTS.md — Hidden Bar (macOS 27 Golden Gate fork)

This is a **community fork** of [Hidden Bar](https://github.com/dwarvesf/hidden)
maintained by **Vitalii Tereshchuk (xVoLAnD)** — https://dotoca.net.
It adds support for the **macOS 27 Golden Gate** menu bar. It is **not** the
official Dwarves Foundation release.

## Credits (accurate attribution)

- Upstream project: `dwarvesf/hidden` © Dwarves Foundation.
- The macOS 27 hide-mechanism fix originates from upstream
  [PR #396](https://github.com/dwarvesf/hidden/pull/396) by **Skyler (skuthus)**.
  This fork builds, verifies, and ships that fix for macOS 27. Do not claim the
  fix was authored here.
- Fork maintainer / build / verification / macOS 27 documentation: **Vitalii
  Tereshchuk (xVoLAnD)**.

## What the app does

Hides menu-bar icons by inflating a separator `NSStatusItem` so other icons slide
away. There is no public API to hide other apps' icons — this is a geometry hack.

### macOS 27 mechanism (read before touching hiding code)

macOS 27 re-architected the menu bar into one window with a native overflow (`«`)
and **drops** any status item whose length reaches half the display width (it
clamped before). So the old `widestScreen * 2` inflation was discarded outright.

- Collapse unit: `StatusBarController.collapseUnit` = `floor(narrowestScreen/2 - 64)`,
  sized under the **narrowest** attached display (the only cliff every bar's copy
  can clear).
- A single item can't span wide/mixed-width displays, so **spacer items**
  (`hiddenbar_spacer0..5`) sit between the arrow and the separator and inflate
  with it. macOS overflows from the left, so real icons go first and surplus
  spacers overflow harmlessly.
- Displaced icons land in the system `«` overflow, not off-screen.
- Items register under `_v27` autosave names (see `autosaveSuffix`) so spacers
  land in the right order; on macOS ≤26 the suffix is empty and the old
  `max(500, min(widest*2, 10000))` rule applies. Everything is `#available(macOS 27.0, *)`.

## Key files

- `hidden/Features/StatusBar/StatusBarController.swift` — all hiding logic,
  collapse/expand, spacers, always-hidden section, layout migration.
- `hidden/Base.lproj/Main.storyboard` — About window (fixed-frame layout; prefer
  code changes over storyboard edits).
- `hidden/Features/About/AboutViewController.swift` — About window; fork
  maintainer credit + link to https://dotoca.net.
- `LICENSE`, `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md` — attribution.
- `docs/ARCHITECTURE.md`, `docs/MANUAL.md`, `docs/RUNBOOK.md`, `docs/BACKLOG.md`.

## Build & release

- Local (needs full Xcode):
  `xcodebuild -project 'Hidden Bar.xcodeproj' -scheme 'Hidden Bar' -configuration Debug build`
- CI: `.github/workflows/build.yml` builds on `macos-latest`, packages the `.app`
  with `ditto`, and **auto-publishes a (pre)release when a `v*` tag is pushed**
  via `softprops/action-gh-release`. Branch pushes only upload an artifact.
- To ship a release: bump the version, `git tag vX.Y.Z-goldengate-test`, `git push --tags`.
- Builds are **ad-hoc / unsigned** (`CODE_SIGNING_ALLOWED=NO`); users must run
  `xattr -dr com.apple.quarantine "Hidden Bar.app"`. Notarization is not wired up
  (would need Developer ID cert + secrets).

## Known limitations

- **Always-hidden section on very wide displays** is mitigated with its own spacer
  block (`hiddenbar_ahspacer0..5`, see #4) but can still leak on extreme widths.
- After upgrading from a pre-27 build, **other apps' menu-bar icons** may need a
  one-time ⌘-drag past the separator — macOS won't let one app reposition another
  app's items. Hidden Bar's own controls self-migrate via `performLayoutMigrationIfNeeded`.
- No test target; behavior is verified manually against the real menu bar
  (see `docs/RUNBOOK.md`).

## Notes for agents

- Keep attribution accurate; don't overwrite Dwarves Foundation / skuthus credit.
- When changing hiding behavior, respect the half-width cliff and the spacer
  approach; a single inflated item past half the narrowest screen is dropped.
- Prefer editing Swift over the storyboard where possible.
- Verify compilation via the GitHub Actions build (no local macOS 27 SDK here).
