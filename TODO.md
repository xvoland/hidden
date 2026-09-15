# TODO — Hidden Bar (Golden Gate fork)

Prioritized backlog for the `xvoland/hidden` fork. Items marked with a source
reference come from the app's own known limitations or documented user behavior.

Legend: **P0** = must fix before next release · **P1** = should do · **P2** = nice to have

## P0 — Blocking / known regressions

- [ ] **Always-hidden section leaks on very wide displays.** Mitigated with its
      own spacer block (`hiddenbar_ahspacer0..5`) but still not fully reliable on
      extreme widths. See AGENTS.md "Known limitations" and #4.
- [ ] **Other apps' icons don't auto-migrate after upgrading from a pre-27
      build.** macOS won't let one app reposition another app's items, so users
      must ⌘-drag once. Consider a first-run helper that nudges displaced items
      into place. See AGENTS.md "Known limitations".
- [ ] **No test target.** All behavior is verified manually (docs/RUNBOOK.md).
      Add a unit-test target for `StatusBarController` collapse/expand math and
      autosave-name migration, so the macOS 27 half-width cliff can't regress
      silently.

## P1 — High value

- [ ] **Pinned icons.** A built-in way to keep chosen icons to the right of the
      separator so they survive collapses. Currently only doable by manual
      ⌘-drag; macOS remembers placement per app but there is no UI for it.
      See docs/MANUAL.md "Why new icons start hidden".
- [ ] **Per-app icon rules.** Let users hide/show icons based on which app is
      frontmost (e.g. keep a chat app visible only while it is active).
- [ ] **Auto-collapse schedule.** Hide the bar on a timer or during specific
      hours (e.g. only during meetings), beyond the existing fixed delay.
- [ ] **Signed & notarized builds.** Current builds are ad-hoc / unsigned;
      users must run `xattr -dr com.apple.quarantine`. Wire up a Developer ID
      cert so the fork ships without the manual step. See AGENTS.md.
- [ ] **Deterministic Homebrew cask.** The `hiddenbar-goldengate` cask uses
      `version :latest` / `sha256 :no_check`. Add a real version + sha256 bump
      process so `brew upgrade` is reproducible.

## P2 — Nice to have

- [ ] **Setup wizard for new users.** One-time guided flow: show how to ⌘-drag
      the arrow, enable the always-hidden section, and pick pinned icons.
- [ ] **Icon search in Preferences.** Filter the menu-bar icon list by name when
      the always-hidden section grows large.
- [ ] **Always-hidden zone customization.** Let users assign icons to the
      always-hidden zone directly, instead of relying on ⌘-drag.
- [ ] **Accessibility polish.** The arrow's `AXPress` is a no-op under assistive
      synthesis (known defect). Improve VoiceOver labels for the spacer items
      and the separator.
- [ ] **Localization completeness.** Some `.lproj` files lag the English source;
      bring all supported languages up to date with the About-window labels.
- [ ] **Future macOS readiness.** When the next macOS re-architects the menu bar
      again, the `collapseUnit` / spacer approach needs re-evaluation. Add a
      detection hook so the app degrades gracefully instead of dropping items.

## Housekeeping

- [ ] Add a CHANGELOG entry for each release (currently only v1.11.4 is logged).
- [ ] Decide whether the fork should ship pre-Ventura builds (currently it does
      not; v1.10 is upstream-only).
- [ ] Document the release asset naming contract (`Hidden Bar.app.zip`) so the
      cask URL and CI stay in sync.

See docs/ARCHITECTURE.md for the hiding-mechanism details and
docs/RUNBOOK.md for the verification methodology.