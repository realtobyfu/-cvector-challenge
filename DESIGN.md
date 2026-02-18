# Grove Design System

Grove uses a monochromatic, typographically-driven design with two modes. The aesthetic is "research terminal meets literary journal" — information-dense but elegant. Think Linear, not Notion.

## Color Tokens

### Light Mode (default)
```
background.primary:    #FAFAFA
background.sidebar:    #F5F5F5
background.inspector:  #F7F7F7
background.card:       #FFFFFF
background.cardHover:  #FFFFFF (with shadow lift)
background.input:      #FFFFFF
background.tagActive:  #1A1A1A

text.primary:          #1A1A1A
text.secondary:        #777777
text.tertiary:         #AAAAAA
text.muted:            #BBBBBB
text.inverse:          #FFFFFF

border.primary:        #EBEBEB
border.input:          #E5E5E5
border.tag:            #E5E5E5
border.tagDashed:      #E0E0E0

accent.selection:      #1A1A1A  (left border on selected items)
accent.badge:          #E8E8E8
accent.barFill.high:   #1A1A1A
accent.barFill.mid:    #999999
accent.barFill.low:    #CCCCCC
accent.bar.track:      #EBEBEB
```

### Dark Mode
```
background.primary:    #111111
background.sidebar:    #0D0D0D
background.inspector:  #141414
background.card:       #1A1A1A
background.cardHover:  #1E1E1E
background.input:      #1A1A1A
background.tagActive:  #FFFFFF

text.primary:          #E8E8E8
text.secondary:        #888888
text.tertiary:         #555555
text.muted:            #444444
text.inverse:          #111111

border.primary:        #222222
border.input:          #2A2A2A
border.tag:            #2A2A2A
border.tagDashed:      #333333

accent.selection:      #E8E8E8  (left border on selected items)
accent.badge:          #2A2A2A
accent.barFill.high:   #E8E8E8
accent.barFill.mid:    #666666
accent.barFill.low:    #333333
accent.bar.track:      #222222
```

## Typography

Three font families, each with a specific role:

| Role | Font | Usage |
|------|------|-------|
| **Titles & headings** | Newsreader (serif) | Board names, item titles in inspector, section headers. Weight 400-600. |
| **Body & UI** | IBM Plex Sans | Button labels, descriptions, block content, most UI text. Weight 300-500. |
| **Data & metadata** | IBM Plex Mono | Tags, timestamps, source URLs, counts, keyboard shortcuts, section labels. Weight 400-500. |

### Type Scale
```
title.board:     Newsreader 28pt, weight 500, tracking -0.03em
title.item:      Newsreader 18pt, weight 500, tracking -0.02em
title.section:   IBM Plex Mono 10pt, weight 500, tracking 0.12em, uppercase
body.primary:    IBM Plex Sans 13pt, weight 400
body.secondary:  IBM Plex Sans 12pt, weight 400
body.small:      IBM Plex Sans 11pt, weight 400
data.tag:        IBM Plex Mono 11pt, weight 400
data.meta:       IBM Plex Mono 11pt, weight 400
data.badge:      IBM Plex Mono 10pt, weight 600
data.shortcut:   IBM Plex Mono 12pt, weight 400
```

### Font Loading (SwiftUI)
```swift
// Register custom fonts in Info.plist or use .custom()
Font.custom("Newsreader", size: 28).weight(.medium)
Font.custom("IBMPlexSans-Regular", size: 13)
Font.custom("IBMPlexMono", size: 11)
```

Bundle Newsreader, IBM Plex Sans, and IBM Plex Mono in the app resources. Do NOT use system fonts as fallback for any visible text — the typography is the identity.

## Spacing

4px base unit. Use multiples.

```
spacing.xs:   4px
spacing.sm:   8px
spacing.md:   12px
spacing.lg:   16px
spacing.xl:   20px
spacing.xxl:  24px
spacing.xxxl: 28px
```

### Layout Dimensions
```
sidebar.width:     220px
inspector.width:   280px
sidebar.padding:   20px horizontal, 28px top
content.padding:   28px horizontal, 24px top
inspector.padding: 16px horizontal, 24px top
```

## Components

### Selected Item / Selected Board
- Background: card color with subtle shadow
- Left border: 2px solid accent.selection
- Transition: all 0.15s ease

```swift
// SwiftUI pattern
.background(isSelected ? Color.card : Color.clear)
.overlay(alignment: .leading) {
    if isSelected {
        Rectangle()
            .fill(Color.accentSelection)
            .frame(width: 2)
    }
}
.shadow(color: isSelected ? .black.opacity(0.04) : .clear, radius: 2, y: 1)
```

### Tags
- Default: card background, border.tag border, data.tag font, border-radius 3px, padding 3px 8px
- Active/filter: tagActive background, inverse text, no border
- Auto-generated (AI): dashed border (border.tagDashed), slightly dimmed text
- Add button: dashed border, muted text, "+" label

### Section Headers
- IBM Plex Mono 10pt, uppercase, tracking 0.12em, text.muted color
- Often followed by a thin horizontal rule (border.primary)

### Connection Cards (inspector)
- Card background, border.primary border, border-radius 4px
- Title in body.primary, relationship type in a small badge (accent.badge background, data.badge font)

### Annotation/Reflection Blocks
- Card background, border.primary border, border-radius 4px
- Left border: 2px solid accent.selection (for emphasis)
- Content in Newsreader italic for quotes, IBM Plex Sans for body
- Timestamp in data.meta style below content

### Nudge Bar
- Card background, border.primary border, border-radius 6px
- Horizontal layout: message (body.secondary) with inline emphasis (text.primary)
- Action button: small pill, accent.badge background
- Dismiss: muted "✕"

### Engagement / Growth Indicator (v3)
- Replace percentage bars with plant stages
- seed: SF Symbol `leaf` at 8pt, text.muted color
- sprout: SF Symbol `leaf.fill` at 10pt, text.tertiary color
- sapling: SF Symbol `leaf.fill` at 12pt, text.secondary color
- tree: SF Symbol `tree.fill` at 14pt, text.primary color
- Tooltip shows score breakdown on hover

### Ghost Text / Placeholder Prompts
- Newsreader italic, text.muted color, 13pt
- Fades out on focus / when user starts typing
- Used in empty reflection pane and AI prompt blocks

## Layout Structure

```
┌─────────┬────────────────────────────┬──────────┐
│ Sidebar │       Main Content         │ Inspector│
│  220px  │         flex               │  280px   │
│         │                            │          │
│ Logo    │  [Nudge Bar]               │ Section  │
│ Search  │  Board Title (Newsreader)  │ Headers  │
│ Inbox   │  Tag Filters               │ (mono    │
│ Boards  │  ──────────────            │ upper)   │
│ (list)  │  Cluster Label             │          │
│         │  Table Header (mono)       │ Tags     │
│         │  Item rows                 │ Connects │
│         │  ...                       │ Reflect  │
│         │                            │ blocks   │
│ ─────── │                            │          │
│ Shortcut│                            │          │
└─────────┴────────────────────────────┴──────────┘
```

### List View (default)
- Grid columns: title (flex), source (140px), tags (80px), depth (60px)
- Table header row: section header style (mono, uppercase, muted)
- Item rows: 10px 12px padding, border-radius 6px
- Selected row gets left-border + shadow treatment
- Type indicators: ◇ article, ▷ video, ∎ note, ◈ lecture (mono, muted)

### Reflection Split View (v3)
```
┌────────────────────────┬────────────────────────┐
│   Source Content        │   Reflection Blocks    │
│   (read-only)           │                        │
│                         │   [Type Label]         │
│   Web view or           │   Block content...     │
│   rendered markdown     │                        │
│                         │   [Type Label]         │
│   ██ highlight ██ →     │   Block content...     │
│                         │                        │
│                         │   [+ Add Block]        │
│                         │                        │
│                         │   -- ghost prompts --  │
└────────────────────────┴────────────────────────┘
```

- Left pane: 55% width, right pane: 45% width (adjustable divider)
- Highlighting text in left pane → "Reflect" button appears → creates block linked to highlight

## Animations & Transitions

Keep it minimal and fast. No spring animations, no bouncing.

```
transition.default:  0.15s ease
transition.hover:    0.1s ease
shadow.default:      0 1px 3px rgba(0,0,0,0.04)  [light] / 0 1px 3px rgba(0,0,0,0.2) [dark]
shadow.hover:        0 4px 12px rgba(0,0,0,0.06) [light] / 0 4px 12px rgba(0,0,0,0.3) [dark]
```

## Principles

1. **Monochromatic** — no accent colors. Hierarchy through weight, size, and opacity only.
2. **Typography is the design** — Newsreader for editorial warmth, Plex Mono for precision. These carry the entire visual identity.
3. **Density over whitespace** — this is a power user tool. Show information, don't hide it.
4. **Left-border selection** — the only strong visual affordance. Used consistently for selected items, boards, and emphasis blocks.
5. **Data as ornament** — tag counts, engagement bars, timestamps, keyboard shortcuts are decorative as much as functional. Render them beautifully in monospace.