# Claude Code — an Obsidian theme

A faithful recreation of the look and feel of **Claude Code in the Claude mobile app**, for [Obsidian](https://obsidian.md). Warm cream / charcoal surfaces, the signature Claude coral accent, a Styrene-style grotesque typeface, and a calm reading rhythm — in both **light** and **dark**.

| Light | Dark |
| --- | --- |
| Warm paper cream `#f9f3e7` | Warm charcoal `#262624` |
| Coral links `#b0532f` | Coral links `#e8916f` |

## What it recreates

- **Color** — Claude's warm neutral backgrounds (no cold grays), the coral accent (`#d97757` / Crail `#c15f3c`) driving links, the active note marker, tags, checkboxes and highlights.
- **Type** — a grotesque sans for the interface and body (like Claude's *Styrene B*), with an optional serif reading mode (like *Tiempos Text*) and a clean monospace for code.
- **Bold** — strong text uses a heavier weight *and* the high-contrast heading color, the way emphasis reads in Claude.
- **Links** — coral, underlined with a soft offset; brighten on hover.
- **Code** — framed code cards with soft corners, pill-shaped inline code, and a restrained, warm syntax palette tuned to the Claude aesthetic.
- **Everything else** — callouts, tables, blockquotes, task lists, the file explorer, command palette, inputs and graph view all follow the same language.

## Task states

Beyond the standard empty and done checkboxes, the theme styles three extra task markers so a list shows real progress at a glance. Type the character between the brackets — e.g. `- [/] Draft the intro`:

| Marker | Looks like | Meaning |
| --- | --- | --- |
| `- [ ]` | empty outlined box | to do |
| `- [/]` | half-filled coral box, split on the diagonal | in progress |
| `- [>]` | coral right-chevron | forwarded / scheduled for another day |
| `- [x]` | filled coral box with a white tick | done — text struck through |
| `- [-]` | muted box with a dash | cancelled — text struck through and faded |

Works in both reading view and Live Preview, on desktop and mobile.

## Fonts

Claude's real typefaces (**Styrene B**, **Tiempos Text**, **Galaxie Copernicus**) are commercial and can't be bundled, so the theme loads close, free Google Fonts automatically:

| Claude font | Free lookalike used | Role |
| --- | --- | --- |
| Styrene B | **Hanken Grotesk** | interface + body |
| Tiempos Text | **Source Serif 4** | serif reading mode |
| code face | **JetBrains Mono** | code blocks / inline |

If you own the real fonts and install them on your system, they sit at the front of every font stack and will be used automatically — no config needed. The Google Fonts `@import` requires an internet connection on first load (Obsidian then caches them).

## Install

### Manually (works today)

1. Download `manifest.json` and `theme.css` from this repo.
2. In your vault, put them in a folder named exactly **`Claude Code`** inside `.obsidian/themes/`:
   ```
   <your-vault>/.obsidian/themes/Claude Code/manifest.json
   <your-vault>/.obsidian/themes/Claude Code/theme.css
   ```
3. In Obsidian: **Settings → Appearance → Themes → Manage → select "Claude Code"**.
4. Pick a color scheme under **Settings → Appearance → Base color scheme**. Both *Light* and *Dark* are individually tuned.

### Automatic light/dark switching

Both schemes ship in the theme, so Obsidian can follow your device. Set **Settings → Appearance → Base color scheme → "Adapt to system"** and Obsidian will switch between the Claude Code light and dark palettes automatically with your OS / device light–dark setting — no extra configuration needed.

## Options (Style Settings)

Install the community plugin **[Style Settings](https://github.com/mgmeyers/obsidian-style-settings)** to unlock toggles under *Settings → Style Settings → Claude Code*:

- **Serif reading mode** — switch note body text to the Tiempos-style serif.
- **Serif headings** / **Monospace headings** — restyle headings.
- **Body font size**, **line height**, **readable line length** sliders.
- **Accent color** pickers for light and dark mode.
- **Loud code blocks** — on (default) gives code blocks a blue frame so they stand out; off keeps them warm, in line with the coral theme.
- **Highlight active line** — a very light tint behind the editor row your cursor is on (on by default).

All defaults match the Claude Code look, so the theme looks right with the plugin not installed too.

## License

MIT. Not affiliated with or endorsed by Anthropic. "Claude" and "Claude Code" are trademarks of Anthropic; this is a community theme that imitates the aesthetic using free, redistributable fonts.

## Preview

### Light

<p align="center">
  <img height="330" src="https://github.com/user-attachments/assets/a1802f4c-2377-4f4c-91f1-b1a2f1eb215f" />
  <img height="330" src="https://github.com/user-attachments/assets/92004a39-6e18-4ef1-a232-0d8402d773ff" />
</p>

<p align="center">
  <img height="320" src="https://github.com/user-attachments/assets/b82b6fe3-3e67-414c-96db-0db71b64d471" />
  <img height="320" src="https://github.com/user-attachments/assets/38e36cd0-8893-45f5-b84a-f8b9104bd9ea" />
</p>

<p align="center">
  <img height="120" src="https://github.com/user-attachments/assets/55326529-c37d-40e5-8550-24cc757ff865" />
  <img height="120" src="https://github.com/user-attachments/assets/5daeeff2-4232-483a-8963-1b4bbe7f6935" />
</p>

### Dark

<p align="center">
  <img width="100%" src="https://github.com/user-attachments/assets/9f6c707f-6fc1-4b8b-b4eb-3ac8835a8d81" />
</p>

<p align="center">
  <img height="330" src="https://github.com/user-attachments/assets/d00fa038-520e-4a78-98cf-eeb1a9330ebe" />
  <img height="330" src="https://github.com/user-attachments/assets/d5909380-e4c4-4bdf-9e08-03fbb449fcf4" />
</p>

<p align="center">
  <img height="140" src="https://github.com/user-attachments/assets/28bbe00f-992c-4029-8c52-4ac46e7cc517" />
  <img height="140" src="https://github.com/user-attachments/assets/749649ad-b10e-4043-8b14-dce6241bf2b9" />
</p>


MIT. Not affiliated with or endorsed by Anthropic. "Claude" and "Claude Code" are trademarks of Anthropic; this is a community theme that imitates the aesthetic using free, redistributable fonts.
