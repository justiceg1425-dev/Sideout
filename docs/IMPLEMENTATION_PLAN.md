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
(Series 9+), always-on display legibility wrist-down, and whether
`HKWorkoutSession` actually keeps the app frontmost through a wrist-drop.
Tune the digit roll/punch animation here too — the handoff deliberately
left exact spring values to this pass.

**Exit:** a full game plays with the watch never needing a wake-tap, and
the AOD state stays readable.

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
