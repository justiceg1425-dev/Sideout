#!/bin/bash
# Generates the full spoken-callout vocabulary as pre-rendered .caf clips
# using macOS's built-in text-to-speech (`say`), instead of recording a
# human voice. This is Phase 4 of docs/IMPLEMENTATION_PLAN.md.
#
# The design brief's "pre-rendered clips, not text-to-speech" constraint
# is about playback (static files stitched together at runtime, not a
# live synthesizer called mid-game) — a TTS voice pre-rendered to files
# satisfies that just as well as a human recording. Swap the output for
# real recordings later if you want a different voice; AudioAnnouncer
# doesn't care where the .caf files came from.
#
# Requires macOS (uses the `say` command) — this cannot be run in a
# Linux CI/sandbox environment.
#
# Usage:
#   ./Scripts/generate_audio_clips.sh <male|female> [voice] [rate]
#
# `kind` (male/female) picks which of the app's two switchable voices
# you're generating — it controls the output folder
# (AudioClips/Male/ or AudioClips/Female/), which is what
# AnnouncerVoice.folderName looks up at runtime (see AppSettings.swift).
# Run this once per kind to populate both, e.g.:
#   ./Scripts/generate_audio_clips.sh male
#   ./Scripts/generate_audio_clips.sh female
#
# `voice` is the actual macOS TTS voice and defaults to "Daniel" for
# male, "Samantha" for female. Run `say -v '?'` to list every voice
# installed on your Mac. A few worth trying:
#   Male: Daniel, Aaron, Nathan, Evan
#   Female: Samantha, Ava, Allison, Susan, Zoe
# The higher-quality "Enhanced"/"Premium" variants of these need
# downloading first via System Settings > Accessibility > Spoken
# Content > System Voice.
#
# `rate` is words-per-minute, defaulting to 160 (a bit slower than
# `say`'s own default of ~175-200 depending on voice) so callouts read
# less rushed mid-rally. Drop it lower (say, 145) for an even more
# deliberate pace, or back up to ~180 for something snappier.
#
# Optional: install sox (`brew install sox`) to trim silence down to the
# brief's ~180-320ms target. Without it, clips keep `say`'s default
# padding, which is looser than the spec but still functionally correct —
# just less tight/staccato.

set -euo pipefail

if ! command -v say >/dev/null 2>&1; then
  echo "error: 'say' is a macOS-only command. Run this script on a Mac." >&2
  exit 1
fi

KIND="${1:-}"
case "$KIND" in
  male)   FOLDER="Male";   DEFAULT_VOICE="Daniel" ;;
  female) FOLDER="Female"; DEFAULT_VOICE="Samantha" ;;
  *)
    echo "usage: $0 <male|female> [voice] [rate]" >&2
    exit 1
    ;;
esac

VOICE="${2:-$DEFAULT_VOICE}"
RATE="${3:-160}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/../Sideout/AudioClips/$FOLDER"
mkdir -p "$OUT_DIR"

has_sox=false
if command -v sox >/dev/null 2>&1; then
  has_sox=true
else
  echo "note: sox not found — clips won't be silence-trimmed. 'brew install sox' for tighter clips." >&2
fi

# filename (no extension) : spoken text
clips=(
  "zero:zero" "one:one" "two:two" "three:three" "four:four" "five:five"
  "six:six" "seven:seven" "eight:eight" "nine:nine" "ten:ten"
  "eleven:eleven" "twelve:twelve" "thirteen:thirteen" "fourteen:fourteen"
  "fifteen:fifteen" "sixteen:sixteen" "seventeen:seventeen"
  "eighteen:eighteen" "nineteen:nineteen" "twenty:twenty"
  "twenty-one:twenty one" "twenty-two:twenty two" "twenty-three:twenty three"
  "twenty-four:twenty four" "twenty-five:twenty five"
  "side_out:side out" "game:game" "us:us" "them:them"
  "game_point:game point" "zero_zero_two:zero zero two"
)

echo "Generating ${#clips[@]} clips ($KIND) with voice '$VOICE' at ${RATE}wpm into $OUT_DIR ..."

for entry in "${clips[@]}"; do
  name="${entry%%:*}"
  text="${entry#*:}"
  out="$OUT_DIR/$name.caf"

  say -v "$VOICE" -r "$RATE" --file-format=caff --data-format=LEI16@22050 -o "$out" "$text"

  if $has_sox; then
    tmp="$OUT_DIR/$name.trimmed.caf"
    sox "$out" "$tmp" silence 1 0.05 0.5% reverse silence 1 0.05 0.5% reverse
    mv "$tmp" "$out"
  fi

  echo "  $FOLDER/$name.caf"
done

echo "Done. AudioClips/ is already a durable Xcode folder reference (see"
echo "project.yml) so this needs no manual Add Files step in Xcode — just"
echo "rebuild."
