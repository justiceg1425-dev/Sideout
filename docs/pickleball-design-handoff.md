# Handoff: Pickleball scorekeeper — Apple Watch + iPhone

## Overview

A personal-use pickleball scorekeeper split across two devices. The **Apple Watch is the input device**: the player taps it after every rally to record who won, and gets an immediate haptic. The **iPhone is the scoreboard and the voice**: it sits courtside on a bench, holds authoritative game state, displays the score at a size readable from the far baseline, and speaks the callout aloud through a Bluetooth speaker.

One user. No App Store, no accounts, no server, no sync. Correctness and speed of input beat breadth of features.

The scoring engine already exists and is tested. This design **reads** from it:

```swift
state.points               // [Int], indexed by team
state.servingTeam          // .a or .b
state.serverNumber         // 1 or 2 — always 1 in singles and rally scoring
state.serverCourtSide      // .right when serving side's score is even, .left when odd
state.lastRallyWasSideOut  // true when the rally just recorded passed the serve over
state.winner               // Team? — nil while live
```

Input is `recordRally(wonBy:)` and `undo()`. Speech text comes from `spokenCallout()`. Do not reimplement or modify the scoring rules.

## About the design files

`Pickleball Scorekeeper.dc.html` in this bundle is a **design reference created in HTML** — a drawing of the intended look, at true point scale, not production code to port. The task is to recreate these screens in **SwiftUI on watchOS and iOS**, using native components, system typography (SF Pro / SF Pro Rounded), and Dynamic Type. No custom typefaces. No fixed-pixel layouts on the watch — design to 41 mm and let it scale to Ultra.

Every dimension in the HTML is a point value: watch screens are drawn 176 × 215, phone landscape 852 × 393, phone portrait 393 × 852. Where the file says "½ scale", double the numbers.

## Fidelity

**High-fidelity.** Colours, type scale, spacing, motion durations and haptic identifiers are final. Recreate them exactly. The one thing intentionally left to implementation is exact spring parameters — the durations given are targets.

---

## The central design problem and how it is solved

Under side-out scoring roughly half of all taps do not change the score. Without an immediate non-verbal explanation the player reads that as a bug.

A recorded rally has exactly three outcomes, and each gets an unmistakable signature in four channels. **No two outcomes share a signature in any channel.**

| Channel | Point scored | Serve advances 1 → 2 | Side out |
|---|---|---|---|
| **Watch visual** | Digit swaps with 140 ms vertical roll + 1.0 → 1.08 → 1.0 scale punch. Serve bar hops to the other edge of its own half (180 ms spring). Nothing else moves. | Digits do not move at all. The single bar splits into two segments in place, 200 ms, gap opening from the centre. Only screen event. | Serve bar travels the full screen width, across the gutter, into the other side's half, 320 ms ease-out — largest motion in the app. Digit brightness swaps with it. Arriving bar is always one segment. |
| **Phone visual** | Same roll + punch at scoreboard scale, 160 ms. Bar hops edges within its panel. | Bar splits into two segments. 17 pt `SECOND SERVER` label fades in under the footer for 1.4 s. | Bar crosses the divider into the other panel, 380 ms. Amber `SIDE OUT` band rises from the bottom edge, holds 1.4 s, retracts. |
| **Haptic (watch)** | `.success` — one crisp rising tap | `.directionUp` — two light taps, 70 ms apart | `.retry` — three firm, heavier taps |
| **Spoken** | "Five, three, two." | "Five, three, two." (only the third number differs from the previous callout — which is why the haptic and the bar carry this outcome) | "Side out. Three, five, one." |
| **Fires when** | Serving side won the rally | Receiving side won, doubles side-out, server was 1 | Receiving side won and server was 2 — or singles, or the opening 0-0-2 server |

Haptics fire on the watch the instant the tap commits, from the watch's own copy of the engine. **They never await the phone.** If the phone is unreachable the felt experience is identical and only the voice is missing.

---

## The serve bar

The single novel component. It carries all three dimensions of serve state with no legend and no reliance on hue.

1. **Which side serves — presence.** The bar exists only under the serving side; the receiving side's zone is empty. Additionally the serving side's digit is pure white and the receiver's drops to `#5B5B60`. Two redundant contrast-only channels.
2. **Server 1 or 2 — segment count.** One solid bar = first server. Two segments = second server. Singles and rally scoring always draw the solid bar (`serverNumber` is always 1).
3. **Court half — horizontal position.** The bar docks to the **right** edge of its half when `serverCourtSide == .right` (serving score even), the **left** edge when `.left` (odd). The marker sits where the server stands; the display is a diagram of the court, not a symbol for it.

Amber is redundant throughout — strip the colour and every dimension still reads. That is the sunlight requirement.

**Rationale.** A badge with "2" in it has to be read; a bar is seen. Position, count and presence are pre-attentive — the eye resolves them before it resolves a glyph, and all three survive glare, motion blur, and the always-on dimmed state.

### Serve bar geometry

**Watch** (per half; half is 83 pt wide, 6 pt inner inset):
- 1st server: one bar, 34 × 9 pt, corner radius 2
- 2nd server: two bars, 15 × 9 pt each, 4 pt gap
- Colour `#FFB020`; always-on dimmed: `#FFFFFF` at 42% container opacity
- Alignment: `.trailing` for right court, `.leading` for left court

**Phone landscape** (per panel; zone 330 pt wide):
- 1st server: one bar, 132 × 22 pt (drawn as 66 + 66 + 10 gap for 2nd server), radius 5
- 2nd server: two bars, 66 × 22 pt, 10 pt gap
- Same colour and alignment rules

---

## Screens

### 1 — Watch · New game (176 × 215)

**Purpose:** get into a game in under five seconds while the opponent waits.

Layout, top to bottom, 16 pt top padding / 12 pt horizontal / 14 pt bottom:
- `NEW GAME` — 10 pt semibold, tracking 1.2, `#6E6E73`, centred, 8 pt below margin
- **Same as last time** card — background `#FFB020`, radius 14, padding 9 × 12. Title "Same as last time" 15 pt bold `#000`; subtitle "Side-out · doubles · 11 · we serve" 10 pt semibold `#000` at 62% opacity. This is the screen's whole job.
- Divider `#242426`, 1 pt, 8 pt margin
- Four rows, 5 pt spacing, 4 pt horizontal inset. Label 12 pt `#8E8E93` left, value 12 pt semibold `#FFF` right. The whole stack must fit 215 pt on a 41 mm watch — this is the tightest screen in the app.: **Format** → Side-out, **Players** → Doubles, **To** → 11, **First serve** → Us
- Rows **cycle in place** on tap. No pickers, no navigation push, no sheets.

### 2 — Watch · Scoring (176 × 215) — the screen that exists for 95% of the app's life

Layout, 14 pt top / 12 pt bottom padding, no horizontal padding:
- **Header strip:** `US` and `THEM`, 10 pt semibold, tracking 1.4, `#6E6E73`, 18 pt from each edge. Centred between them, the **link dot**: 7 pt filled circle `#FFB020` when the phone is connected.
- **Score row**, vertically centred, fills remaining height. Two equal halves either side of a **10 pt dead gutter** containing a 1 pt × 86 pt hairline `#242426`.
  - Digits: SF Pro Rounded Bold, 96 pt, line height 0.8, tracking −4, tabular figures. Serving side `#FFFFFF`, receiving side `#5B5B60`.
  - 11 pt below each digit, the serve bar zone (83 × 9 pt).
- **Footer:** `TO 11`, 10 pt semibold, tracking 1.2, `#48484A`, centred.

**Tap regions.** Left half and right half, full height, edge to edge, split by the 10 pt gutter which is dead. Commit on **touch-up**, not touch-down, so a paddle graze cannot score. Left = our side won the rally → `recordRally(wonBy: .a)`. Right = theirs. Digital Crown scrubs history. Long press opens the end-game menu. Double Tap (Series 9+) = our side won.

**Game point variant.** The footer string is *replaced* by `GAME POINT` — 10 pt bold, tracking 1.6, `#FFB020`. No new element, no layout shift, no extra haptic. Same for match/cap point.

**Always-on dimmed, wrist down.** Header and footer disappear entirely; gutter hairline disappears. Score block renders at 42% opacity, digit weight steps 700 → 600 to cut lit pixels, serve bar renders `#FFFFFF` instead of amber. Score and serve state both survive.

**Phone unreachable.** The *only* change in the entire app is the link dot: filled `#FFB020` circle becomes a 7 pt hollow ring, 1 pt stroke `#6E6E73`. No banner, no colour change, no alert, no haptic. Scoring is unaffected and the design says so by not reacting.

### 2b — Watch · Crown scrubbing

Entered by any crown rotation; every channel changes at once so it can never be mistaken for the live screen.

- Screen border: 1 pt `#35C8E8` around the full display bounds
- **Tick ladder** across the top, replacing the header: one 3 pt-wide tick per rally, 3 pt gaps, centred. Past ticks `#1F5C68` height 5; **current position** `#35C8E8` height 12; redo tail (rallies ahead of the current position) `#35C8E8` at 45% opacity, height 5.
- Digits: serving side `#35C8E8`, receiving side `#1F5C68`. Gutter hairline `#1F5C68`.
- Serve bar: **hollow** — 1 pt `#35C8E8` stroke, no fill, same geometry rules.
- Footer: `3 RALLIES BACK`, 10 pt bold, tracking 1.4, `#35C8E8`. At the beginning of the array the string is `START OF GAME` and the crown hits a wall with a soft detent.
- Tap regions **do not accept scoring input** while scrubbing.
- **Commit:** a tap on either half resumes live scoring from the current position, truncating the redo tail. Idle 6 s snaps back to live, untouched.
- Haptic per detent: `.click`. At the array boundary: `.stop`.

**Rationale.** A history view that looks like the live view is worse than none — the player glances mid-argument and reads a past score as current. The tick ladder is the rally array drawn literally; spinning back three and forward two is a physical motion along it.

### 3 — Watch · Game over (176 × 215)

Centred column, 16 pt top / 12 pt horizontal / 14 pt bottom:
- `WE WON` — 12 pt bold, tracking 1.6, `#FFB020` (or `THEY WON`, same styling)
- Final score `11–8` — SF Pro Rounded Bold 56 pt, tracking −2, `#FFF`, 12 pt below
- `22 min · saved to Health` — 11 pt medium `#6E6E73`, 6 pt below
- Spacer
- **Rematch** — full width, `#FFB020`, radius 13, 10 pt vertical padding, 15 pt bold `#000`. Starts a new game with identical settings.
- **Done** — 12 pt semibold `#8E8E93`, 9 pt below, text only

### 4 — Phone · Scoreboard (852 × 393, landscape, locked)

The primary display. No interactive chrome. Screen kept awake. Tapping anywhere does nothing except reveal a settings affordance after a 1.5 s press.

- Background `#0B0B0C`, 26 pt top / 20 pt bottom padding
- Two equal panels split by a 1 pt vertical divider `#1C1C1E` inset 20 pt top and bottom
- Per panel, centred, 18 pt spacing:
  - **Team name** — 26 pt bold, tracking 5, uppercase. Serving `#F2F2F4`, receiving `#5B5B60`
  - **Digit** — SF Pro Rounded Bold **230 pt**, line height 0.78, tracking −10 (tighten to −14 for two digits so the box never reflows), tabular figures. Serving `#FFFFFF`, receiving `#5B5B60`
  - **Serve bar zone** — 330 × 22 pt
- **Footer** — `SIDE-OUT · TO 11 · WIN BY 2`, 17 pt bold, tracking 3, `#3A3A3C`, centred. With a cap: `SIDE-OUT · TO 21 · CAP 25`. Rally format: `RALLY · TO 11 · WIN BY 2`.

**Game point.** The team label becomes `US · GAME POINT` in `#FFB020`. Nothing new appears.

**Side out.** Amber band across the bottom edge: `#FFB020` fill, 24 pt extra-bold `#000`, tracking 5, text `SIDE OUT`, 9 pt vertical padding. Rises as the bar travels, holds 1.4 s, retracts.

**Watch not heard from.** After **45 s** of silence a strip appears at the very top: background `#1C1508`, 11 pt bold tracking 2, `#C98A18`, text `LAST HEARD FROM WATCH 1:12 AGO`, counter live. The score block drops to 45% opacity — visibly not current, still readable. Never blanked, never a spinner, never an alert.

**Reconnection.** The phone replays *state*, not events. The scoreboard jumps straight to current and the voice speaks the **latest callout only** — never a queue of stale scores over a live point. If the gap crossed a side-out, drop the "Side out" prefix; it describes a moment that has passed. Setting default **Latest only**; alternative **Nothing**. There is no "announce all".

### 5 — Phone · Setup (393 × 852, portrait)

Standard iOS grouped list on `#000`, 58 pt top safe area, 20 pt horizontal margins, group cards `#1C1C1E` radius 14, row separators `#2C2C2E` inset 16 pt left, section headers 13 pt semibold `#8E8E93` tracking 0.6 uppercase with 26 pt top / 8 pt bottom padding. Rows 14 × 16 pt.

- Title **New game** — 34 pt bold `#FFF`, tracking −0.6
- **Start — same as last time** card: `#FFB020`, radius 16, padding 16 × 18. 17 pt bold `#000` + 14 pt semibold `#000` @ 60%
- `FORMAT` group: **Scoring** (Side-out / Rally segmented), **Players** (Singles / Doubles), **Points to win** (11 / 15 / 21), **Hard cap at 15** (toggle), **First serve** (Us / Them). Segmented control: track `#2C2C2E` radius 9 pad 2; selected pill `#FFF` radius 7, label 14 pt semibold `#000`; unselected 14 pt semibold `#8E8E93`. Row label 17 pt `#FFF`, row padding 14 × 16.
- `TEAMS` group: **Our name** → "Us", **Their name** → "Them". Value 17 pt `#8E8E93`.
- **Start game** button — `#1C1C1E`, radius 16, 15 pt padding, 17 pt semibold `#FFF`
- Status line — `Watch connected · JBL Flip 6`, 13 pt medium `#48484A`, centred

### 5b — Phone · Settings (393 × 852, portrait)

Same list styling, tightened so four groups fit 852 pt without scrolling: section headers 18 pt top / 7 pt bottom, rows 11 × 16 pt. Title **Settings**.

- `VOICE`: **Voice** → "Umpire · male"; **Volume** slider (track `#2C2C2E` 4 pt, fill `#FFF`, 22 pt knob) with the percentage as the row value; **Test callout** → `Play` in 17 pt semibold `#FFB020`
- `ANNOUNCE`: exclusive choice with an amber ✓ — **Every rally** (default) / **Score changes and side-outs only**. Plus **Announce game point** toggle, default off.
- `AUDIO OUTPUT`: **Output** → "JBL Flip 6". When absent, an inline note card `#1C1508` radius 12, 15 pt semibold `#C98A18`: "No Bluetooth speaker. Callouts will play through the phone." Stated once, here, as a fact — never mid-game.
- `SCOREBOARD`: **Keep screen awake** (toggle, on, amber track `#FFB020`), **Announce missed rallies on reconnect** → "Latest only"

---

## Copy deck

### On-screen strings

**Watch — new game**
```
NEW GAME
Same as last time
Side-out · doubles · 11 · we serve
Format        Side-out | Rally
Players       Singles | Doubles
To            11 | 15 | 21
First serve   Us | Them
```

**Watch — scoring**
```
US        THEM
TO 11 | TO 15 | TO 21
GAME POINT
MATCH POINT          (only if a cap makes the next point decisive)
```

**Watch — scrubbing**
```
1 RALLY BACK
3 RALLIES BACK
START OF GAME
```

**Watch — game over**
```
WE WON
THEY WON
11–8
22 min · saved to Health
Rematch
Done
```

**Watch — long-press menu** (the only place a sheet is allowed, and never over the live scoring screen)
```
End game
Switch sides
Resume
```

**Phone — scoreboard**
```
US    THEM              (or team names, uppercased)
SIDE-OUT · TO 11 · WIN BY 2
RALLY · TO 11 · WIN BY 2
SIDE-OUT · TO 21 · CAP 25
SIDE OUT
SECOND SERVER
US · GAME POINT
LAST HEARD FROM WATCH 1:12 AGO
```

**Phone — game over overlay**
```
US WIN
11–8
Rematch          Done
```

**Phone — setup / settings**
```
New game
Start — same as last time
FORMAT   Scoring / Players / Points to win / Hard cap at 15 / First serve
TEAMS    Our name / Their name
Start game
Watch connected · JBL Flip 6
Watch not connected

Settings
VOICE    Voice / Volume / Test callout — Play
ANNOUNCE Every rally / Score changes and side-outs only / Announce game point
AUDIO OUTPUT   Output
No Bluetooth speaker. Callouts will play through the phone.
SCOREBOARD     Keep screen awake / Announce missed rallies on reconnect
Latest only | Nothing
```

Vocabulary rule: the words of the sport, not the words of software. "Serving," never "active player state." No "sync," no "session," no "error."

### Spoken vocabulary — the complete clip list

Audio is **pre-rendered clips played in sequence**, so the vocabulary is closed. Every clip is one word, trimmed tight, ~180–320 ms, with ~90 ms of silence between clips in a sequence.

**Numbers** — one clip each: `zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twenty-one twenty-two twenty-three twenty-four twenty-five`

**Words** — `side out` · `game` · `us` · `them` · `game point` · `zero zero two` (single clip, the opening callout)

That is the entire vocabulary. Nothing else is speakable.

**Assembly rules**
| Situation | Sequence | Example |
|---|---|---|
| Side-out doubles, normal | serving score, receiving score, server number | "Five, three, two." |
| Side-out singles, or rally scoring | serving score, receiving score | "Five, three." |
| Side out just occurred | `side out` + the callout from the **new** serving side's perspective | "Side out. Three, five, one." |
| Game start, side-out doubles | the `zero zero two` clip | "Zero, zero, two." |
| Game point (if enabled) | `game point` + the normal callout | "Game point. Ten, four, two." |
| Game end | `game` + winner + final score, winner's score first | "Game. Us. Eleven, eight." |

Team names are display-only — spoken as `us` / `them`, because arbitrary names cannot be pre-rendered.

Under **Score changes and side-outs only**, serve-advance rallies (1 → 2) produce no speech at all; the watch haptic and the split bar carry them alone.

---

## Design tokens

### Watch

**Colour**
| Token | Value | Use |
|---|---|---|
| `bg` | `#000000` | Screen. OLED, battery, night play. |
| `scoreLive` | `#FFFFFF` | Serving side's digit |
| `scoreIdle` | `#5B5B60` | Receiving side's digit |
| `serve` | `#FFB020` | Serve bar, primary action fill, game point |
| `onServe` | `#000000` | Text on amber |
| `chrome` | `#6E6E73` | Header labels, link dot when connected |
| `chromeDim` | `#48484A` | Footer meta |
| `hairline` | `#242426` | Gutter rule, list dividers |
| `scrub` | `#35C8E8` | Scrub mode: border, live tick, digits, hollow bar |
| `scrubDim` | `#1F5C68` | Scrub mode: past ticks, receiving digit, hairline |
| `aodScore` | `#FFFFFF` @ 42% container opacity | Always-on |

**Type** — SF Pro Rounded for numerals, SF Pro Text for everything else. Dynamic Type respected on non-numeral text; numerals are fixed so the layout cannot break.
| Token | Size / weight / tracking |
|---|---|
| `score` | 96 / Bold / −4 / lh 0.8 / tabular |
| `scoreAOD` | 96 / Semibold / −4 |
| `finalScore` | 56 / Bold / −2 |
| `cardTitle` | 15 / Bold / −0.2 |
| `row` | 12 / Regular (label) · 12 / Semibold (value) |
| `cardSub` | 10 / Semibold |
| `header` | 10 / Semibold / +1.4 / uppercase |
| `footer` | 10 / Semibold / +1.2 · Bold / +1.6 when amber |

**Spacing** — 2 / 4 / 5 / 8 / 9 / 10 / 11 / 12 / 14 / 16. Screen padding 14 top, 12 bottom, 12 horizontal (0 on the scoring screen so tap regions reach the edge). Gutter 10. Radius: screen 34, card 14, button 13, bar 2.

### Phone

**Colour**
| Token | Value | Use |
|---|---|---|
| `bgBoard` | `#0B0B0C` | Scoreboard |
| `bgApp` | `#000000` | Setup / settings |
| `card` | `#1C1C1E` | Grouped list cards |
| `control` | `#2C2C2E` | Segmented track, separators, slider track |
| `scoreLive` | `#FFFFFF` | Serving digit |
| `scoreIdle` | `#5B5B60` | Receiving digit, secondary values |
| `label` | `#F2F2F4` | Serving team name |
| `serve` | `#FFB020` | Serve bar, side-out band, primary fill, game point |
| `meta` | `#3A3A3C` | Scoreboard footer |
| `secondary` | `#8E8E93` | List labels, section headers |
| `warnBg` / `warnFg` | `#1C1508` / `#C98A18` | Stale-watch strip, no-speaker note |

**Type**
| Token | Size / weight / tracking |
|---|---|
| `boardScore` | 230 / Rounded Bold / −10 (−14 two-digit) / lh 0.78 / tabular |
| `boardTeam` | 26 / Bold / +5 / uppercase |
| `boardBand` | 24 / Heavy / +5 / uppercase |
| `boardFooter` | 17 / Bold / +3 / uppercase |
| `boardWarn` | 11 / Bold / +2 / uppercase |
| `largeTitle` | 34 / Bold / −0.6 |
| `rowLabel` | 17 / Regular |
| `rowValue` | 17 / Regular, `secondary` |
| `button` | 17 / Semibold |
| `sectionHeader` | 13 / Semibold / +0.6 / uppercase |
| `segment` | 14 / Semibold |

**Spacing** — 2 / 6 / 7 / 10 / 11 / 12 / 14 / 16 / 18 / 20 / 26 / 34. List margin 20. Row padding 14 × 16 (setup) · 11 × 16 (settings). Radius: card 16, group 14, segment track 9, pill 7, bar 5.

### Motion
| Event | Duration | Curve |
|---|---|---|
| Digit roll + punch (watch) | 140 ms | ease-out, scale 1.0 → 1.08 → 1.0 |
| Digit roll + punch (phone) | 160 ms | ease-out |
| Serve bar hop within half | 180 ms | spring, response 0.18, damping 0.8 |
| Serve bar split | 200 ms | ease-in-out |
| Serve bar traverse (watch) | 320 ms | ease-out |
| Serve bar traverse (phone) | 380 ms | ease-out |
| `SIDE OUT` band | 1.4 s hold | rise 220 ms, retract 180 ms |
| Scrub mode enter / exit | 120 ms | crossfade |

No continuous or idle animation anywhere. Everything is event-driven and short — the workout session plus always-on display is already an expensive hour.

---

## State management

**Watch** owns the live game and is the source of truth for input.
```
game: GameState          // from the existing engine
scrubOffset: Int?        // nil = live; n = n rallies back from the head
lastSyncAck: Date?       // last acknowledgement from the phone
phoneReachable: Bool     // derived: WCSession.isReachable
settings: GameSettings   // format, players, target, cap, first serve — persisted for "same as last time"
```
Transitions: tap left/right (touch-up, only when `scrubOffset == nil`) → `recordRally`; crown detent → adjust `scrubOffset`, clamped to `0...rallies.count`; tap while scrubbing → truncate the rally array to that prefix and return to live; 6 s idle while scrubbing → `scrubOffset = nil`; long press → menu; `game.winner != nil` → game-over screen.

**Phone** is a replica plus the speaker.
```
board: GameState         // replicated, never authored on the phone
lastHeard: Date
stale: Bool              // derived: now - lastHeard > 45 s
speechQueue: [Clip]      // cleared and replaced on every new state, never accumulated
settings: AppSettings    // voice, volume, announce mode, output, reconnect behaviour
```
The phone **never** originates a rally. On receiving a state update it diffs against its own copy to decide which of the three outcomes to animate and speak, then replaces the queue — so a burst of catch-up rallies produces exactly one callout.

**Runtime**
- The watch app runs inside a HealthKit workout session so it stays frontmost through wrist drops. Screen is live for the whole game — which is exactly why the dead gutter and touch-up commit matter.
- Every finished game logs a workout to Health; the game-over screen acknowledges it in one line of tertiary text.
- Watch ↔ phone over `WCSession`; send the whole append-only rally array, not deltas. It is tiny and it makes reconnection idempotent.

## Assets

None. No images, no icons, no custom fonts — SF Symbols only if you need any glyph at all, and the design currently needs none. The one non-code asset set is the **pre-rendered audio clips** listed in the spoken vocabulary above.

## Files

- `Pickleball Scorekeeper.dc.html` — full visual spec: serve-bar anatomy at 2×, all watch screens and states, phone scoreboard states, phone setup and settings, feedback matrix, rationales. Open it in a browser and zoom.
- `pickleball-design-brief.md` — the original brief this design answers.

## What not to build

No accounts, no cloud sync, no match history sync, no leaderboards, no server of any kind. One phone, one watch, one speaker, one player. Do not modify the scoring rules.
