#!/usr/bin/env bash
# preview.sh — resolve a named component/screen to its Storybook story and open
# it in a local mobile simulator (iOS Simulator by default, Android emulator if
# requested and available).
#
# Usage:  preview.sh <name> [ios|android] [--frame]
#   <name>     component or screen name, e.g. Card, Inbox, InboxScreen, "Navigation Button"
#   ios        (default) open in the booted iOS Simulator's Safari
#   android    open in a running Android emulator's browser (host = 10.0.2.2)
#   --frame    open the full Storybook UI (?path=) instead of the bare canvas (iframe.html)
#
# Exit codes: 0 ok, 2 story not found, 3 multiple matches (printed), 4 sim/emulator missing.

set -uo pipefail

PORT=6006
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"   # repo root
NAME="${1:-}"
PLATFORM="ios"
USE_FRAME=0

shift || true
for arg in "$@"; do
  case "$arg" in
    ios|android) PLATFORM="$arg" ;;
    --frame) USE_FRAME=1 ;;
    *) echo "warn: ignoring unknown arg '$arg'" >&2 ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "error: missing <name>. Usage: preview.sh <Component|Screen> [ios|android] [--frame]" >&2
  exit 2
fi

# --- kebab-case helper (matches Storybook's title/story id slugging) ----------
kebab() { echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'; }

# --- 1. resolve the .stories.tsx file ----------------------------------------
# Prefer an exact basename match (Name.stories.tsx / NameScreen.stories.tsx),
# fall back to a case-insensitive substring match on the filename.
# (Populated portably for bash 3.2 — macOS default — which lacks `mapfile`.)
MATCHES=()
while IFS= read -r line; do [[ -n "$line" ]] && MATCHES+=("$line"); done < <(
  find "$ROOT/src" -name '*.stories.tsx' \
    \( -iname "${NAME}.stories.tsx" -o -iname "${NAME}Screen.stories.tsx" \) 2>/dev/null
)
if [[ ${#MATCHES[@]} -eq 0 ]]; then
  while IFS= read -r line; do [[ -n "$line" ]] && MATCHES+=("$line"); done < <(
    find "$ROOT/src" -iname "*${NAME}*.stories.tsx" 2>/dev/null
  )
fi

if [[ ${#MATCHES[@]} -eq 0 ]]; then
  echo "error: no story file found matching '$NAME' under src/" >&2
  echo "hint: try the component folder name, e.g. Card, Inbox, InboxScreen" >&2
  exit 2
fi
if [[ ${#MATCHES[@]} -gt 1 ]]; then
  echo "error: '$NAME' is ambiguous — matched ${#MATCHES[@]} stories:" >&2
  printf '  %s\n' "${MATCHES[@]#$ROOT/}" >&2
  echo "re-run with a more specific name." >&2
  exit 3
fi
STORY_FILE="${MATCHES[0]}"

# --- 2. parse title + first story export -> story id -------------------------
TITLE="$(grep -oE 'title:[[:space:]]*"[^"]+"' "$STORY_FILE" | head -1 | sed -E 's/title:[[:space:]]*"([^"]+)"/\1/')"
if [[ -z "$TITLE" ]]; then
  echo "error: could not find a 'title:' in $STORY_FILE" >&2
  exit 2
fi
# First named export is the canonical story; prefer one literally named Default.
if grep -qE '^export const Default\b' "$STORY_FILE"; then
  EXPORT="Default"
else
  EXPORT="$(grep -oE '^export const [A-Za-z0-9_]+' "$STORY_FILE" | head -1 | awk '{print $3}')"
fi
[[ -z "$EXPORT" ]] && EXPORT="Default"

STORY_ID="$(kebab "$TITLE")--$(kebab "$EXPORT")"

if [[ $USE_FRAME -eq 1 ]]; then
  PATH_FRAGMENT="/?path=/story/${STORY_ID}"
else
  PATH_FRAGMENT="/iframe.html?id=${STORY_ID}&viewMode=story"
fi

# --- 3. host the simulator reaches -------------------------------------------
# iOS Simulator shares the host loopback; Android emulator maps host to 10.0.2.2.
if [[ "$PLATFORM" == "android" ]]; then HOST="10.0.2.2"; else HOST="localhost"; fi
URL="http://${HOST}:${PORT}${PATH_FRAGMENT}"

echo "story file : ${STORY_FILE#$ROOT/}"
echo "story id   : ${STORY_ID}"
echo "url        : ${URL}"

# --- 4. ensure the Storybook dev server is up --------------------------------
if curl -fsS -o /dev/null --max-time 2 "http://localhost:${PORT}/iframe.html" 2>/dev/null; then
  echo "storybook  : already running on :${PORT}"
else
  echo "storybook  : not running — starting 'npm run storybook' in background..."
  ( cd "$ROOT" && nohup npm run storybook >/tmp/orbit-storybook.log 2>&1 & )
  printf "storybook  : waiting for :%s " "$PORT"
  for _ in $(seq 1 60); do
    if curl -fsS -o /dev/null --max-time 2 "http://localhost:${PORT}/iframe.html" 2>/dev/null; then
      echo " up"; break
    fi
    printf "."; sleep 1
  done
  if ! curl -fsS -o /dev/null --max-time 2 "http://localhost:${PORT}/iframe.html" 2>/dev/null; then
    echo ""; echo "error: Storybook did not come up in 60s — see /tmp/orbit-storybook.log" >&2
    exit 4
  fi
fi

# --- 5. launch in the simulator ----------------------------------------------
if [[ "$PLATFORM" == "ios" ]]; then
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "error: xcrun not found — install Xcode + command line tools" >&2; exit 4
  fi
  if ! xcrun simctl list devices booted 2>/dev/null | grep -q "Booted"; then
    echo "ios        : no booted simulator — booting the latest iPhone..."
    DEVICE_ID="$(xcrun simctl list devices available 2>/dev/null | grep -oE 'iPhone[^(]*\(([-0-9A-F]+)\)' | grep -oE '[-0-9A-F]{36}' | head -1)"
    [[ -n "$DEVICE_ID" ]] && xcrun simctl boot "$DEVICE_ID" 2>/dev/null
  fi
  open -a Simulator
  # give a freshly-booted sim a moment to be ready for openurl
  xcrun simctl bootstatus booted -b >/dev/null 2>&1 || sleep 3
  xcrun simctl openurl booted "$URL"
  echo "opened in iOS Simulator (Safari)."
else
  if ! command -v adb >/dev/null 2>&1; then
    echo "error: Android tooling (adb/emulator) not installed on this machine." >&2
    echo "       Install Android Studio + SDK platform-tools, start an emulator, then re-run with 'android'." >&2
    exit 4
  fi
  if ! adb devices 2>/dev/null | grep -qE 'emulator-[0-9]+\s+device'; then
    echo "error: no running Android emulator detected (adb devices)." >&2
    echo "       Start one from Android Studio's Device Manager (or 'emulator -avd <name>'), then re-run." >&2
    exit 4
  fi
  adb shell am start -a android.intent.action.VIEW -d "$URL" >/dev/null 2>&1
  echo "opened in Android emulator browser."
fi
