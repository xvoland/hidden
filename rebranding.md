# Rebranding to "Hideout" — legal notes & plan

This file records **why** renaming the fork to "Hideout" is legal, **what must
be kept** so the MIT license stays honored, and **how** the rename is executed.
Written for the maintainer (Vitalii Tereshchuk, xVoLAnD); agents should re-read
it before any branding-related change.

---

## 1. Legal basis — why a rebrand is allowed

The project is licensed under the **MIT License** (`LICENSE`). The grant
permits — without restriction and including for commercial use:

> use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
> of the Software (LICENSE lines 8-10)

Nothing in MIT limits naming. Renaming the app, the `.xcodeproj`, the target,
the bundle identifier, and the GitHub repository is therefore **allowed**.

The **only** hard condition (LICENSE lines 13-14):

> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.

Translations:
- Keep **both** copyright lines in `LICENSE`:
  `Copyright (c) 2019 Dwarves Foundation` and
  `Copyright (c) 2026 Vitalii Tereshchuk (https://dotoca.net)`.
- Keep the entire MIT permission notice text verbatim.
- Keep `Copyright © Dwarves Foundation` in per-file headers. These are the
  required attribution notices, not a brand to remove.

## 2. Can money be charged?

**Yes.** MIT explicitly permits selling copies and distributing for a fee.
Practical caveats:

- **"As is"**: the software is provided without warranty; do not claim
  warranties you cannot back.
- **Brand**: do not imply endorsement by Dwarves Foundation; after rebranding,
  do not market it as the official "Hidden Bar".
- **App Store**: the direct macOS 27 build uses the **private framework
  `MenuBarClientCore`** (via `HBNativeVisibilityShim.m`). Private API usage is
  very likely to get the app **rejected from the App Store**. Selling outside
  the App Store is realistic; a paid App Store version is not.
- **Community expectations**: upstream is free; this is a reputation concern,
  not a legal one.

## 3. Untouchable items (attribution / migration)

These are **not branding** and must not be renamed away:

- `dwarvesf/hidden` (upstream), Dwarves Foundation copyright.
- The macOS 27 hide-mechanism fix, authored by **Skyler (skuthus)** in upstream
  [PR #396](https://github.com/dwarvesf/hidden/pull/396). Do not claim it was
  written here.
- `SMLoginItemSetEnabled("com.dwarvesv.LauncherApplication", false)` in
  `hidden/AppDelegate.swift` — one-time migration that deauthorizes the legacy
  login item (TN3111). It must keep the `com.dwarvesv.LauncherApplication`
  identifier to find and remove that record.

## 4. Rebrand checklist

1. **Repository rename**: GitHub → Settings → change name to `hideout`. Old
   URLs redirect automatically. Locally: `git remote set-url origin
   git@github.com:xvoland/hideout.git`.
2. **Project/scheme**: rename `Hidden Bar.xcodeproj` → `Hideout.xcodeproj`,
   scheme `Hidden Bar.xcscheme` → `Hideout.xcscheme`.
3. **Xcode target settings**: target/`PRODUCT_NAME` → `Hideout`;
   `PRODUCT_BUNDLE_IDENTIFIER` → decidable id (e.g. `com.xvoland.hideout`).
4. **Strings/code**: replace `Hidden Bar` / `hiddenbar` in code, storyboard,
   `Info.plist`, localizations (`*.lproj/*.strings`), `Casks/*.rb`, CI,
   `bump-version.sh`, and `docs/`.
   - Keep `autosaveName` prefixes (`hiddenbar_spacer*`, `hiddenbar_ahspacer*`,
     `hiddenbar_*`) — changing them would reset the user's menu-bar layout.
5. **CI**: `.github/workflows/build.yml` — project/scheme/artifact names;
   `bump-version.sh` — project path.
6. **Artifacts**: packaged `.app` becomes `Hideout.app`; `xattr` instructions
   in docs updated accordingly.
7. **Docs/license**: README/CHANGELOG/CONTRIBUTING/AGENTS updated to "Hideout",
   attribution kept per §3. `LICENSE` keeps both copyright lines verbatim.

## 5. Known risks / trade-offs

- **Cask rename** breaks existing installs. Either keep
  `Casks/hiddenbar-goldengate.rb` as a deprecated alias to the new cask, or
  accept one manual reinstall for users.
- **Historical links** to `xvoland/hidden` redirect after the repo rename.
- **bundle id change** means a user upgrading from the old app ends up with two
  copies until the old one is quit/deleted.
- App Store path is blocked by the private framework (see §2).

## 6. Open decisions (TBD)

- Bundle identifier: `com.xvoland.hideout` vs `net.dotoca.hideout`.
- Cask: rename `hiddenbar-goldengate` → `hideout` (breaking) or keep an alias.
- Target/scheme name: plain `Hideout`.