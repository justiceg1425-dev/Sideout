# Sideout — implementation plan

Phase-wise path from "scaffolded but never compiled" (the state this repo
was generated in — see the README's "This was written without Xcode") to
a working app you actually play with. Each phase has a concrete exit
condition; don't move on until it's met.

## Phase 0 — Unblock repo access

`git push` needs the Claude GitHub App installed on this account/org — a
separate credential path from the OAuth connection used for read access,
which is already working.

- Install the app: https://github.com/apps/claude/installations/select_target
- Or reconnect GitHub under claude.ai → Settings → Connectors:
  https://claude.ai/customize/connectors?auth_start=github&auth_start_force=1

**Exit:** `git push` succeeds from a normal clone.

## Phase 1 — First compile

`xcodegen generate`, open in Xcode, fix whatever doesn't build. Go in this
order:

1. `Packages/SideoutEngine` in isolation (`swift test`) — plain Swift, no
   UIKit/WatchKit surface, so it's the fastest signal.
2. The watch target.
3. The phone target.

Expect real errors — this was written without a compiler available, so
some API surface is unverified: `digitalCrownRotation`,
`handGestureShortcut(.primaryAction)`, `HKWorkoutActivityType.pickleball`,
`requestGeometryUpdate`. Also needs your Apple Developer team selected on
both targets' Signing & Capabilities before it'll run on a device.

**Exit:** both targets build and launch in Simulator without crashing.

## Phase 2 — Each device working standalone

No watch↔phone sync yet — just: does the watch app's own loop work (new
game → tap-to-score → game over → rematch), and does the phone's
Setup/Settings render and navigate correctly. This is where layout bugs
surface — the 215 pt watch screen is genuinely tight, and none of it has
been seen rendered.

**Exit:** a full game plays cleanly on the watch alone; phone Setup/
Settings navigate without visual breakage.

## Phase 3 — Watch ↔ phone connectivity

Run both at once (two Simulator windows with a paired watch+phone
runtime, or real devices). Verify score syncs over `WCSession`, the link
dot reflects reachability, and reconnection after backgrounding the phone
catches up correctly — one callout for a burst of rallies, not a queue of
stale ones.

**Exit:** score a game on the watch with the phone visibly tracking it
live, including a deliberate "kill and relaunch the phone app mid-game"
test.

## Phase 4 — Audio clips

The one real content gap, not a bug: no audio ships with the scaffold.
`Scripts/generate_audio_clips.sh` generates the full vocabulary via
macOS's built-in `say` (see that file's header for usage and voice
choice) — run it once on a Mac, drop the output into
`Sideout/AudioClips/` as a folder reference in Xcode. Swap in real human
recordings later if the synthesized voice doesn't feel right; the app
doesn't care where the `.caf` files came from.

**Exit:** a full game is audibly called out correctly, including a
side-out and a game-point callout, at a volume and pace that doesn't feel
robotic mid-rally.

## Phase 5 — Real hardware and sensory polish

Simulator can't tell you if this actually works: Digital Crown scrub
direction/feel, the three distinct haptic patterns, Double Tap gesture
(Series 9+ only — inert on older hardware, not broken), always-on display
legibility wrist-down (also hardware-dependent — no AOD panel on Series 3
or 4), and whether `HKWorkoutSession` actually keeps the app frontmost
through a wrist-drop. Tune the digit roll/punch animation here too — the
handoff deliberately left exact spring values to this pass.

The watch target's deployment target is 8.0 so the *code* supports an
Apple Watch Series 3 as well as newer models — watchOS 9 dropped Series 3
entirely, so that's the floor. **Getting a real Series 3 unit running,
however, turned out not to be achievable** — worth recording exactly what
was tried, so this doesn't get re-attempted from scratch later:

1. Xcode's device-support cache lacked watchOS 8.8.2 symbols; installing
   an older Xcode to prime it hit its own wall (Xcode 14.x refuses to run
   on modern macOS at all; the priming eventually did succeed, but only
   after restoring the current Xcode overwrote a genuinely different
   problem into existence — see #2).
2. Restoring the current Xcode after an accidental overwrite (installing
   an older Xcode by dragging it into `/Applications` under the same name
   silently replaced the working one) got the Watch showing as a real
   destination, but the wireless debug tunnel to it fails with a mix of
   `NWError`/"connection reset" errors that persisted through every
   standard fix (unlock, same Wi-Fi, reboot all three devices).
3. TestFlight was considered as a way to bypass Xcode's tunnel entirely,
   but has its own confirmed, unresolved Apple bug for exactly this
   combination: Series 3 + watchOS 8 companion-app installs hang
   indefinitely or crash (reported on Apple's developer forums, no fix
   published). Not attempted, given that.
4. The clearest root cause surfaced last: Xcode reported "unsupported
   architecture" outright. Series 3's S3 chip needs `armv7k`; every watch
   since Series 4 uses `arm64_32`, and the default build only produces
   the latter. Adding `armv7k` to `ARCHS`/`VALID_ARCHS` didn't fix it —
   the local `SideoutEngine` package failed to resolve for that
   architecture even after a clean build, which reads as the current
   toolchain no longer fully supporting `armv7k` compilation for a
   package-based project, not a settings mistake.
5. Retested #4 specifically under a second, older Xcode (16.4, installed
   as a separate copy alongside the main install) in case it was an
   Xcode-26-specific regression rather than a general limitation. First
   attempt gave a *different* error — `SideoutEngine.swiftmodule is not
   built for armv7k` — which looked like stale cached build products, so
   it was retried after Product → Clean Build Folder, File → Packages →
   Reset Package Caches, and a manual `rm -rf` of DerivedData. Same error
   persisted through the fully clean rebuild. Conclusion: not an
   Xcode-version quirk — SPM's local-package build path doesn't produce
   an armv7k module slice on either toolchain generation tried.

Five independent failures now, across wireless debugging, TestFlight, and
two separate Xcode versions hitting the same build wall — old hardware
hitting the edges of current tooling support from multiple directions at
once, confirmed rather than assumed. **The physical Series 3 is
Simulator-verified only, and that's the accepted end state for this
device**, not a gap to revisit unless Apple ships new tooling that
changes the picture.

**Exit:** a full game plays with the watch never needing a wake-tap, and
the AOD state stays readable — tested on whichever generations of Watch
you actually have, since features (Double Tap, AOD) are genuinely absent
on older hardware rather than bugs to chase.

## Phase 6 — Outdoor validation and edge cases

Take it outside at 2pm. Confirm contrast survives glare, then hit the
edge cases on purpose:

- Phone out of range for a few rallies, then back in range
- Scrubbing all the way to the start of the game
- A hard-cap game running into the high teens / twenties
- Singles vs. doubles switch between games
- Long team names on the scoreboard

**Exit:** a real game, outdoors, start to finish, with nothing surprising
you.

---

Don't reorder these — Phase 4 (audio) and Phase 5 (hardware feel) both
assume the app already builds and syncs cleanly, and debugging connectivity
issues is much harder once haptics/audio are also in the mix as possible
culprits.
