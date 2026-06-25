---
name: preview-design
description: Open a named Orbit component or screen design in a local mobile simulator. Resolves the component/screen name to its Storybook story, ensures the Storybook dev server is running on :6006, and opens the story in the iOS Simulator (default) or a running Android emulator. Use when the user says "run/preview/show <Name> in the simulator", "open <Name> on the iPhone", "let me see <Name> on device", or wants to view a design they just created or updated.
---

# Preview a design in a local simulator

Resolve a component/screen **by name** to its Storybook story and open it in a
mobile simulator so the user can see the design at a true device viewport.

## Usage

The user names the design (component or screen) and, optionally, the platform.
Examples of how this skill is invoked in conversation:

- "preview Card in the simulator" → name `Card`, iOS
- "show me the InboxScreen on the iPhone" → name `InboxScreen` (or `Inbox`), iOS
- "open UnifiedInbox on android" → name `UnifiedInbox`, Android

## How to run it

Run the helper script with the name the user gave. **Always pass the name in
quotes** (story names like `Navigation Button` contain spaces):

```bash
.claude/skills/preview-design/scripts/preview.sh "<Name>" [ios|android] [--frame]
```

- `<Name>` — component folder/screen name, e.g. `Card`, `Inbox`, `InboxScreen`,
  `UnifiedInbox`, `"Navigation Button"`. Matching is exact-first, then a
  case-insensitive filename substring match.
- `ios` (default) — opens in the booted iOS Simulator's Safari. iOS Simulator
  shares the host loopback, so it reaches `http://localhost:6006` directly.
- `android` — opens in a **running** Android emulator's browser (host mapped to
  `10.0.2.2`). Requires Android SDK platform-tools (`adb`) + a started emulator.
- `--frame` — open the full Storybook UI (`?path=/story/...`) instead of the
  bare story canvas (`iframe.html?id=...`). Default is the bare canvas, which
  fills the device screen with just the rendered design (the story's own
  `DeviceFrame` mockup still renders inside it).

The script does everything deterministically:

1. Finds the matching `*.stories.tsx` under `src/` (errors with the candidate
   list if the name is ambiguous, exit code 3; errors if none found, exit 2).
2. Parses its `title:` and first story export and slugifies them into the
   Storybook story id (e.g. title `Molecules/Card` → `molecules-card--default`).
3. Checks `:6006`; if Storybook isn't up it starts `npm run storybook` in the
   background and waits (logs at `/tmp/orbit-storybook.log`).
4. Boots a simulator if needed and opens the story URL in it.

## After running

- Report the resolved story id and URL the script printed.
- If the script exits **3 (ambiguous)**, show the user the candidate list it
  printed and ask which one — then re-run with the precise name.
- If it exits **2 (not found)**, the name didn't match any story; suggest the
  closest folder under `src/components/` or `src/screens/`.
- If it exits **4 (simulator missing)** for Android, relay that Android tooling
  isn't installed on this machine; offer the iOS path instead.

## Notes / constraints

- This is a **web** React + Vite + Storybook project (see CLAUDE.md) — the
  "simulator" runs the Storybook URL in the simulator's mobile **browser**;
  there is no native app build. iOS Simulator is the fast path on this machine.
- Storybook always runs on port **6006** (`storybook dev -p 6006`).
- Don't hand-edit generated files or change story titles just to make a URL
  resolve — fix the name passed to the script instead.
