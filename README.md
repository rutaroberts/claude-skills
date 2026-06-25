# claude-skills

Personal Claude Code skills for use across projects.

## What are skills?

Skills are slash commands for [Claude Code](https://claude.ai/code). Drop a skill folder into `.claude/skills/<skill-name>/` in any project and it becomes available as `/<skill-name>` in that session.

## Skills

### `/open-in-figma`
Exports the current widget, screen, or component to Figma — pixel-perfect capture + named layered frame, side by side.
- Defaults to Personal #1 Figma file
- Works with standalone HTML widgets, Storybook components, or any localhost URL
- Creates a new page named after the component if one doesn't exist

### `/preview-design`
Opens a named Orbit Storybook component or screen in the iOS Simulator or Android emulator.
- Resolves component name → Storybook story URL
- Starts Storybook if it isn't already running
- Specific to the [ai-pilot-orbit-storybook](https://github.com/yahoo-mailfe/ai-pilot-orbit-storybook) project

## Usage

Copy a skill into your project:

```bash
mkdir -p .claude/skills
cp -r path/to/claude-skills/open-in-figma .claude/skills/
```

Or clone this repo and symlink:

```bash
git clone https://github.com/rroberts01_yahoo/claude-skills ~/claude-skills
ln -s ~/claude-skills/open-in-figma /path/to/your-project/.claude/skills/open-in-figma
```
