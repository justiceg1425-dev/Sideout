# Design brief — pickleball scorekeeper for Apple Watch + iPhone

## What this is

A personal-use pickleball scorekeeping app, split across two devices with clearly different jobs.

**The Apple Watch is the input device.** The player wears it on court and taps it after every rally. It is a remote control with a glanceable score echo — not the main display.

**The iPhone is the brain, the scoreboard, and the voice.** It sits courtside, connected to a Bluetooth speaker, holding the authoritative game state. It displays a large-format score readable from the baseline and speaks the score aloud after every rally.

The player does not carry the phone while playing. Design accordingly: the watch has to be complete enough to play a whole game from, and the phone has to be legible from thirty feet away.

Not going to the App Store. One user. Correctness and speed of input matter far more than breadth of features.

## Who uses it and where

One player, mid-game, outdoors in Dubai.

- **Bright, direct sun.** Contrast is the hardest constraint on both devices. A design that reads beautifully indoors and disappears at 2pm has failed.
- **Two-second glances at the wrist.** The player is holding a paddle and a ball, checking one number between rallies. They are not reading.
- **Often not looking at all.** They tap by feel and listen to the phone. Haptics and audio carry as much of the load as the visuals.
- **Sweat, motion, imprecision.** Tap targets should be enormous.

## The scoring model — read this before designing anything

The interaction is **not** "tap to add a point." It is **"tap to record who won the rally."** The app derives everything else.

Two formats, switchable at setup:

**Side-out (traditional).** Only the serving side can score. Winning a rally while *receiving* gets you the serve, not a point — the score does not move. In doubles each side gets two servers before the serve passes over, and the game opens at "0-0-2," where the first serving side gets one server only.

**Rally.** Every rally scores. The rally winner serves next. One server per side.

Games go to 11 by default, 15 and 21 selectable, win by 2, with an optional hard cap.

### The core design problem

Under side-out scoring, roughly half of all taps will not change the score. The player taps "we won that one" and the big number stays put. Without an immediate, non-verbal explanation this reads as a bug and destroys trust in the app within one game.

**This is the thing to solve.** A recorded rally has exactly three possible outcomes — a point scored, the serve advancing from first server to second, or a side out. Each needs its own unmistakable signature across three channels: what changes on the watch, what changes on the phone, and what the watch's haptic feels like. Solve this and the rest of the app is straightforward.

### Serve state has three dimensions

Both displays must communicate, at a glance:

1. Which side is serving
2. Server 1 or server 2 — doubles under side-out only; meaningless in singles and in rally scoring
3. Which court half the server stands in — right when the serving side's score is even, left when odd

Compressing three dimensions into a two-second glance on a 40mm screen is the second design problem. Resist a legend; nobody reads a key mid-game.

## Input scheme — locked, design around this

| Input | Action |
|---|---|
| Tap left half of watch screen | Our side won the rally |
| Tap right half of watch screen | Their side won the rally |
| Digital Crown rotation | Scrub rally history — one detent back undoes a rally, forward redoes it |
| Long press | End game / menu |
| Pinch Double Tap gesture | Our side won the rally (Series 9 and later) |

Notes that constrain the visuals:

- The two tap regions are full-height with a dead gutter between them, and they commit on **touch-up**, not touch-down, so a graze from a paddle grip doesn't score a point.
- The crown replaces the usual long-press undo deliberately. It is nearly impossible to trigger accidentally, and it lets the player spin back three rallies and forward two while sorting out a dispute. It needs a visual treatment: while scrubbing, the display should make clear that it is showing a *past* state rather than the live one, and where in the history it currently sits.
- Every input fires a haptic on the watch immediately, independent of whether the phone received it. The tap must feel instant even when the phone is out of range.

## Screens

### Watch

**1. New game.** Format, singles or doubles, points to win, who serves first. Must be completable in under five seconds — the opponent is waiting. Offer a one-tap "same as last time" path.

**2. Scoring.** The screen that exists for 95% of the app's life. Both scores, serve state, two tap regions, and a scrubbing state for the crown. Needs an always-on dimmed variant that still shows the score with the wrist down.

**3. Game over.** Final score and a fast rematch with the same settings.

### Phone

**4. Scoreboard.** The primary display. Landscape, propped on a bench or bag, readable from the far baseline by both teams. Numbers should be as large as the glass allows. Serve state must be readable at the same distance as the score. This is a display, not a control — no interactive chrome competing for space.

**5. Setup and settings.** Mirrors the watch's new-game options and adds what the watch shouldn't carry: team names, voice selection, volume, and what gets announced (every rally, or only score changes and side-outs).

## Copy

Write the full copy deck — on-screen strings and spoken lines both. The spoken format is fixed by the sport:

- Side-out doubles: three numbers — serving side's score, receiving side's score, server number. "Five, three, two."
- Side-out singles and rally scoring: two numbers. "Five, three."
- Side-out only: prefix "Side out" when the serve changes hands.
- Game end: names the winner and the final score.

Everything else is open. Keep it in the vocabulary of the sport rather than the vocabulary of software — "Serving," not "Active player state."

## States to cover

- **Phone unreachable.** Common and expected, not an error. The watch keeps scoring perfectly; the readout and the scoreboard go stale. How does the watch signal this calmly, and what does the phone scoreboard show when it hasn't heard from the watch in a while?
- Reconnection — the phone catches up several rallies at once. Does it announce all of them, the latest only, or nothing?
- Scrubbing through history with the crown, including scrubbed to the very start
- Game point and match point — worth signalling, or noise?
- Scores in the teens under a hard cap
- Always-on dimmed watch state, wrist down
- Bluetooth speaker not connected

## Runtime realities that shape the design

- **The watch app runs inside a HealthKit workout session** so it stays frontmost through wrist drops. The screen is therefore live for the whole game, which is exactly why the dead gutter and touch-up commit matter.
- **Battery is a real cost.** Workout session plus always-on display is a heavy hour. Favour dark, sparse layouts; avoid continuous animation.
- **Every game logs a workout to Health.** Worth a small acknowledgement on the game-over screen.
- **The phone speaks from pre-rendered audio clips**, played in sequence. Callouts are therefore slightly staccato and cannot be arbitrary sentences — keep spoken copy inside a small fixed vocabulary of numbers plus a handful of words.

## Constraints

- SwiftUI on watchOS and iOS. Native components, system typography, Dynamic Type respected. No custom typefaces.
- No fixed-pixel layouts on the watch. Design to the smallest current watch size and scale up; the same layout must work on a 40mm and on an Ultra.
- No modal alerts, sheets, or navigation stacks on the watch scoring screen. One screen deep, always.
- Dark backgrounds on the watch — OLED, battery, and night play all agree. The interest has to come from typography, hierarchy, and the serve indicator, not from surface colour.
- Colour cannot be the only channel carrying serve state. Sunlight washes out hue long before it washes out contrast and shape.
- The phone scoreboard is viewed at distance, not arm's length. Its type scale should be built for that, not borrowed from the watch.

Where this brief pins something down, follow it. Where it doesn't — the serve indicator's form, the type scale, the feedback choreography, the accent palette, the scrubbing treatment — those are the interesting decisions and they're yours.

## Deliverables

1. Screen-by-screen layouts for all five screens, with every state above drawn rather than described.
2. A feedback matrix: for each of the three possible outcomes of a rally, the watch's visual change, the phone's visual change, the haptic pattern, and the spoken line.
3. Design tokens — colour, type scale, spacing — as concrete values, separately for watch and phone.
4. The full copy deck, including the fixed spoken vocabulary list.
5. Short rationales for the serve indicator and the crown-scrubbing treatment, the two genuinely novel components here.

## Note for the next stop

This goes to Claude Code afterwards, to be built against a scoring engine that already exists and is tested. The design reads from this state rather than inventing its own:

```swift
state.points               // [Int], indexed by team
state.servingTeam          // .a or .b
state.serverNumber         // 1 or 2 — always 1 in singles and in rally scoring
state.serverCourtSide      // .right when the serving side's score is even, .left when odd
state.lastRallyWasSideOut  // true when the rally just recorded passed the serve over
state.winner               // Team? — nil while the game is live
```

Input is `recordRally(wonBy:)` and `undo()`. Speech text comes from `spokenCallout()`. The whole game is an append-only array of rally winners, which is what makes crown scrubbing cheap — any point in history is just a shorter prefix of the same array.

Don't redesign the scoring rules. Don't design accounts, cloud sync, match history sync, or anything implying a server. There is no server. There is one phone, one watch, one speaker, and one player.
