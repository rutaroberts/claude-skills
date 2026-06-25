---
name: open-in-figma
description: Export the current widget, screen, or component to Figma as a pixel-perfect capture + named, layered frame. Defaults to the user's Personal #1 file (rgz747TxSzkfkL1mwNJjIf). Creates a new page named after the component if one doesn't exist. Use when the user says "open in Figma", "send to Figma", "export to Figma", "push to Figma", or "create a Figma screen for this".
---

# Open in Figma

Export whatever the user is currently working on — an HTML widget, a Storybook
component, or any locally-served page — to Figma as:

1. **Pixel-perfect capture** via `generate_figma_design` (exact layout, colors, shadows)
2. **Layered build** via `use_figma` (named groups, auto-layout frames, editable text)

Both land on the same Figma page so the user gets a clean reference + an
editable structure side by side.

---

## Default Figma file

**Personal #1** — file key `rgz747TxSzkfkL1mwNJjIf`
URL: `https://www.figma.com/design/rgz747TxSzkfkL1mwNJjIf/Personal--1`

Use this unless the user:
- Pastes a different Figma URL → extract that file key instead
- Says "new file" or "create a file" → call `create_new_file` first, then use the returned key
- Names a specific existing file → ask for its URL if you don't have the key

---

## Step-by-step execution

### 1. Resolve the target URL

Determine what to capture:

| Situation | Action |
|---|---|
| User is in `tools/slack-digest/` or similar standalone HTML widget | Start `npx serve -l <port>` in that directory |
| User is in the Orbit Storybook repo and names a component/screen | Ensure Storybook is running on `:6006`; use `http://localhost:6006/iframe.html?id=<story-id>` |
| User pastes an explicit localhost URL | Use it directly |
| User pastes an external URL | Use Playwright method (see capture section) |

Check whether the server is already running before starting a new one:
```bash
lsof -ti :<port> | head -1
```
If occupied and serving the right content, reuse it. Otherwise pick the next free port.

### 2. Resolve the Figma file and page

```
fileKey  = rgz747TxSzkfkL1mwNJjIf   (default, unless overridden)
pageName = <ComponentName>           (e.g. "Slack Digest", "Card", "InboxScreen")
```

Call `get_metadata` on `fileKey` (no `nodeId`) to list existing pages.
- If a page with `pageName` already exists → use its `id` as the target
- Otherwise → create it with `use_figma`:

```js
const existing = figma.root.children.find(p => p.name === PAGE_NAME);
if (existing) return { pageId: existing.id, created: false };
const p = figma.createPage();
p.name = PAGE_NAME;
return { pageId: p.id, created: true };
```

### 3. Inject the capture script

Add this line **just before** the closing `</body>` or before the first `<script>` in the HTML file being served:

```html
<script src="https://mcp.figma.com/mcp/html-to-design/capture.js" async></script>
```

For Storybook: inject into `.storybook/preview-head.html` (create it if missing):
```html
<script src="https://mcp.figma.com/mcp/html-to-design/capture.js" async></script>
```

### 4. Run pixel capture + layered build in parallel

**Call both tools at the same time in a single response.**

#### 4a. Pixel capture — `generate_figma_design`

First call (no `captureId`) → get a capture ID back.
Then open the URL:
```bash
open "http://localhost:<port>/<path>#figmacapture=<captureId>&figmaendpoint=https%3A%2F%2Fmcp.figma.com%2Fmcp%2Fcapture%2F<captureId>%2Fsubmit&figmadelay=2000"
```

Then poll every 5 seconds until `status: completed`:
```
generate_figma_design(fileKey, captureId: "<id>")
```
Keep polling — do not give up before 10 attempts.

Place the capture frame at `x: 640` on the Figma page (right of the layered build).

#### 4b. Layered build — `use_figma`

Read the component's HTML + CSS before writing any Figma code. Understand:
- Exact dimensions (widths, heights, border-radii)
- Color values (map to token names if tokens.css is present)
- Font sizes, weights, line-heights
- Layer hierarchy (which elements are children of which)

Build a properly named frame hierarchy using the Figma Plugin API:
- Top-level: one `Frame` named after the component, positioned at `x: 0, y: 0`
- Use `layoutMode = 'VERTICAL'` / `'HORIZONTAL'` + auto-layout for any flex/stack containers
- Name every layer descriptively: `Header`, `Logo`, `Tab / Today`, `Card / <subject>`, etc.
- Set colors using exact hex values from the source (or token values if available)
- Set `cornerRadius`, `strokeWeight`, `effects` (shadows) to match the source
- **Critical ordering rule**: set `layoutSizingHorizontal`, `layoutGrow`, and `layoutSizingVertical` **after** `appendChild` — not before

Place the layered frame at `x: 0, y: 0` on the Figma page.

### 5. Clean up

After the pixel capture completes:
1. Remove the injected `<script>` tag from the HTML/preview-head file
2. Stop the local server if you started it (it was not running before)
3. Report the Figma URL: `https://www.figma.com/design/<fileKey>?node-id=<pageId>`

---

## Common layer patterns

### Auto-layout frame (flex container)
```js
const frame = figma.createFrame();
frame.layoutMode = 'HORIZONTAL'; // or 'VERTICAL'
frame.primaryAxisSizingMode = 'AUTO';   // hug content
frame.counterAxisSizingMode = 'FIXED';  // or 'AUTO'
frame.itemSpacing = 12;
frame.paddingLeft = frame.paddingRight = 24;
frame.paddingTop = frame.paddingBottom = 16;
frame.cornerRadius = 16;
frame.fills = [{ type: 'SOLID', color: { r, g, b }, opacity: a }];
parent.appendChild(frame);
// ↑ append FIRST, then set child sizing:
child.layoutSizingHorizontal = 'FILL'; // set AFTER appendChild
```

### Text node
```js
await figma.loadFontAsync({ family: 'Inter', style: 'Semi Bold' });
const t = figma.createText();
t.fontName = { family: 'Inter', style: 'Semi Bold' };
t.fontSize = 16;
t.characters = 'Hello';
t.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 }, opacity: 0.9 }];
parent.appendChild(t);
t.layoutSizingHorizontal = 'FILL'; // AFTER appendChild
```

### Drop shadow
```js
frame.effects = [{
  type: 'DROP_SHADOW',
  color: { r: 0, g: 0, b: 0, a: 0.4 },
  offset: { x: 0, y: 4 },
  radius: 24,
  spread: 0,
  visible: true,
  blendMode: 'NORMAL'
}];
```

### Gradient fill
```js
frame.fills = [{
  type: 'GRADIENT_LINEAR',
  gradientTransform: [[1, 0, 0], [0, 1, 0]],
  gradientStops: [
    { position: 0, color: { r: 0.49, g: 0.18, b: 1, a: 0.18 } },
    { position: 1, color: { r: 0.10, g: 0.10, b: 0.10, a: 1 } }
  ]
}];
```

---

## Token mapping (Orbit / Yahoo OS Dark)

When the source uses CSS variables from `src/tokens/tokens.css` or
`Tokens/yahoo.os.dark.tokens.json`, map them to these hex values:

| Token | Dark value |
|---|---|
| `--bg-primary` / `background.primary` | `#2c2c2c` |
| `--bg-secondary` / `background.secondary` | `#121212` |
| `--bg-e0` | `#3a3a3a` |
| `--fg-primary` / `foreground.primary` | `#f5f5f5` |
| `--fg-secondary` / `foreground.secondary` | `#b0b0b0` |
| `--fg-brand` / `foreground.brand` | `#b58cff` |
| `--fg-brand-sec` / `foreground.brand-secondary` | `#d1c9fb` |
| `--accent` / `product.brand-yellow` | `#F8FB4C` |
| `--fg-on-color` / `foreground.on-color` | `#1d1d1f` |
| `--fg-positive-sec` | `#1ac567` |
| `--fg-warning-sec` | `#ffa166` |
| `--line-muted` | `rgba(248,248,248,.08)` |
| `--line-tertiary` | `rgba(248,248,248,.16)` |

---

## Error handling

| Problem | Fix |
|---|---|
| `Setting figma.currentPage is not supported` | Use `await figma.setCurrentPageAsync(page)` |
| `node must be a child of auto-layout frame` (layoutSizing) | Move the property assignment to after `parent.appendChild(node)` |
| Capture stays `pending` after 5+ polls | Verify the script tag is in the HTML and the dev server is running; re-inject if needed |
| Card / frame height stays at 10px | Re-set `primaryAxisSizingMode = 'AUTO'` after all children are appended; toggle `layoutMode = 'NONE'` then back to fix stale layout |
| Font style not found | Use `'Semi Bold'` not `'SemiBold'`; `'Extra Bold'` not `'ExtraBold'` |

---

## Output

Always end with:
```
Figma page: https://www.figma.com/design/<fileKey>?node-id=<pageNodeId>
```
