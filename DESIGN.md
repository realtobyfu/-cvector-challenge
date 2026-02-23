# CVector Plant Monitor — Design Specification

## Aesthetic Direction: Terminal Light

Brutalist, monospace, engineering-tool aesthetic in a legible light-mode execution.
Inspired by industrial control systems and terminal UIs, but designed for 8-hour readability.

**Key identity markers:**
- `> ` prefix on section labels (green accent)
- `//` separators in detail text (e.g., "3 assets // avg 437.3")
- `cv::plant_monitor` branding in header
- Full monospace typography throughout
- Hard borders on containers, no gratuitous border-radius
- White background — clean, professional, not dark-mode

## Color Palette

```css
:root {
  /* Backgrounds */
  --bg:           #ffffff;     /* page background */
  --bg-subtle:    #f7f6f4;     /* table headers, chart footer, hover states */
  --bg-inset:     #f0eeea;     /* chart grid lines */

  /* Borders */
  --border:        #e2dfda;    /* card borders, table dividers */
  --border-strong: #1a1a1a;    /* section boundaries (header, table header, status bar) */

  /* Text hierarchy */
  --text:    #1a1a1a;          /* primary — headings, values, asset names */
  --text-2:  #5c5752;          /* secondary — body text, chart labels */
  --text-3:  #908a82;          /* tertiary — section labels, type tags, reading labels */
  --text-4:  #b5afa7;          /* quaternary — units, faint details, footer */

  /* Semantic colors */
  --green:     #1a7a4f;        /* primary accent, operational status, section prefixes */
  --green-bg:  #eaf6f0;        /* operational pill background */
  --amber:     #b06e14;        /* warning status */
  --amber-bg:  #fdf3e4;        /* warning pill background */
  --red:       #c43b3b;        /* critical status */
  --red-bg:    #fde8e8;        /* critical pill background */
  --blue:      #3a6ba5;        /* chart secondary line, consumption metrics */
}
```

## Typography

**One family: IBM Plex Mono** — monospace throughout. No sans-serif body text.

| Use | Weight | Size | Color |
|-----|--------|------|-------|
| Metric values | 700 | 34px | `--text` |
| Asset names, headings | 700 | 13–16px | `--text` |
| Body text, reading values | 700 | 12–13px | `--text` |
| Section labels (uppercase) | 700 | 10px | `--text-3` |
| Reading labels | 500 | 12px | `--text-3` |
| Detail text, units | 400 | 11px | `--text-4` |
| System ID in header | 700 | 13px | `--text` + `--green` |

**Letter spacing**: Section labels use `2.5px`. Type tags use `1px`. Body text uses `0`.

## Component Specifications

### Header
- Height: 52px
- Bottom border: 2px solid `--border-strong`
- Left: `cv::plant_monitor` with green `cv` prefix, pipe separator, facility name
- Right: UTC timestamp, live indicator (green dot with pulse animation)
- Background: white (same as page)

### Section Labels
- Prefix: `> ` in `--green`
- Text: 10px, 700 weight, uppercase, 2.5px letter-spacing
- Color: `--text-3`
- Margin below: 10px

### Status Pills
- Individual pills (not a connected bar), flex row with 10px gap
- Border: 1px solid `--border` (default) or semantic color (ok/warn)
- Background: white (default) or tinted (`--green-bg`, `--amber-bg`)
- Content: large number (24px, 700) + small label (10px, uppercase)
- No border-radius (or minimal, 0–2px)

### Metric Cards
- Grid: 4 columns, 14px gap
- Border: 1px solid `--border`
- Top accent line: 3px, colored per metric type (green, blue, amber, neutral)
- Padding: 20px
- Label: 10px uppercase, `--text-3`
- Value: 34px, 700 weight, `--text`
- Unit: 14px, `--text-3`, inline after value
- Detail: 11px, `--text-4`, uses `//` separator. Highlight spans in `--text-2`
- Hover: border darkens to `--text-3`

### Time Series Chart
- Container: 1px solid `--border`
- Header: metric label with green highlight, time range buttons (1H/2H/6H/12H/24H)
- Time buttons: connected strip, active state = black fill white text
- Chart area: 300px height, light grid lines (`--bg-inset`)
- Line styles: solid for primary lines, dashed for secondary. 2px stroke width.
- Gradient fills: very subtle, 8% opacity top fading to 0%
- End dots: 3.5px radius circles at the latest data point
- Footer: `--bg-subtle` background, legend with 20px color bars and current values
- Y-axis labels: `--text-4`, 10px, right-aligned
- X-axis labels: `--text-4`, 10px, centered

### Asset Table (critical — this is the main data density area)
- Container: 1px solid `--border`
- Header row: `--bg-subtle` background, 2px bottom border (`--border-strong`)
- Header text: 9px, 700 weight, uppercase, 2px letter-spacing, `--text-3`
- Body rows: 16px vertical padding, 1px bottom border (`--border`)
- Hover: `--bg-subtle`

**Readings format (Option A — inline pairs, no boxes):**
```
Temperature 542.8°C    Power Output 264.1 MW    RPM 3,608    Vibration 2.4 mm/s
```
- Layout: flex-wrap, 20px horizontal gap, 4px vertical gap
- Label: 12px, 500 weight, `--text-3` — use FULL names (Temperature, not Temp)
- Value: 12px, 700 weight, `--text`, 5px left margin from label
- Unit: 11px, 400 weight, `--text-4`, 1px left margin from value
- Line height: 1.8 for comfortable reading when wrapping

**Status indicator:**
- Dot: 7px circle, colored (green/amber/red)
- Text: 12px, 600 weight, same color as dot
- Operational = `--green`, Warning = `--amber`, Critical = `--red`

### Footer
- Top border: 1px solid `--border`
- Text: 10px, `--text-4`
- Left: system identifier. Right: polling info
- Margin top: 40px

## Interaction Patterns

- **Facility selector**: dropdown in header, triggers full dashboard reload
- **Time range buttons**: segmented control, active state = inverted (black bg, white text)
- **Metric selector**: dropdown above chart, changing metric resets asset selection
- **Asset multi-select**: multi-select dropdown, max 4 assets shown on chart
- **Table rows**: hoverable, expandable on click (show full reading detail)
- **Auto-refresh**: dashboard polls every 15s, chart every 30s. No spinner on refresh — data updates silently.

## Anti-patterns (do NOT do these)

- ❌ Border-radius > 2px on data containers
- ❌ Abbreviated labels (Temp, Pwr, Vibr) — always spell out full names
- ❌ Boxed/chipped reading values in the asset table — use inline pairs
- ❌ Dark mode / dark backgrounds
- ❌ Sans-serif fonts anywhere
- ❌ Colored backgrounds on metric cards (only the 3px top accent line)
- ❌ Loading spinners on refresh (only on initial load)
- ❌ Emojis in the actual app (the design reference uses them as placeholder icons)
