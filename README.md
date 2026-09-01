# Sideout

A personal-use pickleball scorekeeper split across two devices: the **Apple
Watch** is the input device (tap to record who won the rally), the
**iPhone** is the scoreboard and the voice (courtside display + spoken
callouts through a Bluetooth speaker). No accounts, no server, no sync
beyond the two devices in the room.

Built from `docs/pickleball-design-brief.md` and
`docs/pickleball-design-handoff.md` — the original design brief and the
high-fidelity handoff this app implements. Read the handoff before
touching the UI; it pins down colors, type, spacing, motion, and haptics
as exact values.

## This was written without Xcode

This scaffold was generated in an environment with no Swift toolchain or
Xcode — none of it has been compiled, run, or visually verified. Treat
your first build in Xcode as the real test, and expect to fix compiler
errors. The scoring engine (`Packages/SideoutEngine`) is the piece most
likely to be exactly right, since it's a plain Swift package with unit
tests describing its exact behavior. The SwiftUI views are the piece most
likely to need adjustment — gesture composition, animation timing, and
orientation locking in particular (see "Known gaps" below).

## Build

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you don't
   have it: `brew install xcodegen`.
2. From the repo root: `xcodegen generate`. This produces `Sideout.xcodeproj`
   (gitignored — regenerate it any time `project.yml` or the file layout
   changes, rather than editing the `.xcodeproj` by hand).
3. Open `Sideout.xcodeproj`, select a development team on both targets
   (Signing & Capabilities), and run the **Sideout Watch App** scheme on a
   watchOS simulator or device, and **Sideout** on an iOS simulator or
   device.
4. To run the engine's unit tests: open `Packages/SideoutEngine` in Xcode
   directly (or `cd Packages/SideoutEngine && swift test` on a Mac with
   the Swift toolchain), or run the `SideoutEngineTests` scheme from
   inside the generated workspace.

Watch and phone talk over `WCSession`. To see them sync, run both targets
at once (Xcode lets you select two run destinations) with a paired
watch+phone simulator, or on real hardware.

## Project layout

```
Packages/SideoutEngine/   Pure-Swift scoring engine + XCTest suite. The
                           only place the scoring rules live.
Shared/                    Code used by both app targets: the
                           WatchConnectivity payload, settings
                           persistence, the serve bar component, a
                           Color(hex:) helper.
Sideout Watch App/         watchOS app: new game, scoring (incl. crown
                           scrubbing and always-on dimmed state), game
                           over.
Sideout/                   iOS app: scoreboard, setup, settings, game
                           over overlay.
docs/                      The design brief and handoff this was built
                           from.
```

## What's NOT included — audio clips

The phone speaks from **pre-rendered audio clips**, not a live
text-to-speech call mid-game (the handoff is explicit about this — it
keeps callouts short and staccato rather than full sentences).
`AudioAnnouncer` looks for files at `Sideout/AudioClips/<clip>.caf` in the
app bundle; if a clip is missing it stays silent rather than guessing.

Run `Scripts/generate_audio_clips.sh` on a Mac to generate the full
vocabulary via the built-in `say` command — see that file's header for
voice choice and usage. That satisfies the "pre-rendered" requirement
just as well as a human recording; swap in real recordings later if you
want a different voice, `AudioAnnouncer` doesn't care where the `.caf`
files came from. The full clip list is in `SpokenClip.swift` and mirrored
in the handoff's copy deck:

- Numbers: `zero` through `twenty-five` (one clip each)
- Words: `side_out`, `game`, `us`, `them`, `game_point`, `zero_zero_two`

Keep each clip trimmed tight (~180–320 ms) with a consistent voice and
level; the app inserts ~90 ms of silence between clips in a sequence
(the generation script does this automatically if `sox` is installed).
Add the output folder to Xcode as a folder reference (not a group) —
"Create folder references" — so the `subdirectory:` lookup in
`AudioAnnouncer` resolves.

## Known gaps to verify on-device

The handoff calls out that exact spring parameters are the one thing left
to implementation — durations are targets, not final tuning. Beyond that,
these specific things could not be verified without a Mac and are worth a
deliberate pass:

- **Digit roll + punch animation.** Implemented as an asymmetric
  move+opacity transition keyed to score changes. The handoff also wants
  a 1.0 → 1.08 → 1.0 scale punch, which isn't wired up — that needs a
  proper two-stage spring, tuned live.
- **Digital Crown scrub direction and sensitivity.** `ScoringView` uses
  the plain `digitalCrownRotation($binding)` form (the parameterized
  `from:through:by:sensitivity:` overload needs a newer watchOS than this
  app's floor) and does its own clamping/rounding in
  `onChange(of: crownPosition)`. Whether raw rotation-to-rally-step feels
  right — "one detent back undoes a rally" — needs a real Watch, probably
  more than one generation of Watch given how differently the plain
  binding can feel across crown hardware revisions.
- **Double Tap gesture.** Implemented as a hidden, non-hit-testable
  `Button` with `.handGestureShortcut(.primaryAction)` layered under the
  real touch-up tap regions, so it doesn't compete with them for on-screen
  touches. This composition (a shortcut on a control nobody can actually
  touch) is plausible but unverified — confirm Double Tap still fires
  "our side won" on a Series 9+.
- **Phone orientation locking.** `SideoutApp`/`PhoneRootView` flips
  `AppDelegate.orientationLock` and calls `requestGeometryUpdate` when
  switching between the landscape-only Scoreboard and the portrait Setup
  and Settings screens. Orientation-lock-per-screen is one of the fussier
  corners of UIKit/SwiftUI interop; verify it actually rotates on a
  device.
- **HealthKit workout type.** Uses `HKWorkoutActivityType.pickleball` when
  available (watchOS 9+), falling back to `.racquetSports` on watchOS 8.
- **watchOS 8 / Apple Watch Series 3 support.** The watch target's
  deployment target is 8.0 specifically so this can install on a Series 3
  (watchOS 9 dropped Series 3 entirely, so this is as low as it can go).
  All watchOS-10-only APIs in the watch code (Double Tap's
  `handGestureShortcut`, `HKWorkoutActivityType.pickleball`) are
  `#available`-gated. What's *not* verified: whether Xcode 16 still ships
  the device-support files needed to install/debug on a real watchOS
  8.8.2 device at all — that's independent of the deployment target
  setting and is worth checking early in Phase 5, not assuming.

## What was deliberately decided, not specified

The brief left a few interaction details open on purpose. Where this
scaffold made a call, it's documented as a comment at the point of
decision — search for "Design note" / "Resolution" in:

- `NewGameView.swift` — how a *customized* (not "same as last time") game
  actually starts, on a screen too tight for a second button.
- `GameOverOverlay.swift` — why "Rematch"/"Done" render as inert labels on
  the phone rather than buttons (the phone never originates a rally; the
  watch is the only thing that can start a new game).
- `PhoneConnectivityManager.swift` / `PhoneAppModel.swift` — how a
  multi-rally reconnection burst is classified and spoken (one callout,
  latest state only, side-out prefix dropped for a burst).

## What not to build

No accounts, no cloud sync, no match history sync, no leaderboards, no
server of any kind. One phone, one watch, one speaker, one player. Don't
modify the scoring rules in `SideoutEngine` — reread
`docs/pickleball-design-handoff.md`'s "state management" section before
changing anything about how rallies are recorded or replayed.
