# Grove — V3 Intelligence Layer

## What This Is
Mac-native knowledge management app (macOS 15+). V1-V2 built the core: SwiftData models, three-column layout, boards, items, tags, connections, annotations, capture flow, search. V3 adds the LLM layer and reflection system.

## References
- `prd.json` — V3 user stories (S1-S15). Work through these in order.
- `DESIGN.md` — Complete design system. Follow it exactly for all UI work. Typography (Newsreader, IBM Plex Sans, IBM Plex Mono), color tokens (light + dark mode), component patterns, layout specs.
- `progress.txt` — Append after each story. Read it first to understand project state.

## Tech Stack
- Swift, SwiftUI, SwiftData
- MVVM with @Observable ViewModels
- swift-markdown for rendering, TextKit 2 for editing
- Tuist for project generation
- LLM: Groq API (OpenAI-compatible), model moonshotai/kimi-k2-instruct

## Project Structure
```
Grove/
  Models/       — SwiftData: Item, Board, Tag, Connection, Annotation, Nudge (+ new: ReflectionBlock, LearningPath)
  Views/        — Organized by feature: {Feature}/{Feature}View.swift
  ViewModels/   — @Observable classes, one per major view
  Services/     — Business logic, LLM/ subfolder for AI services
  Utilities/    — WikiLinkResolver, helpers
```

## Rules
1. ONE story per iteration. Do not combine stories.
2. Read `progress.txt` before starting. Append results after.
3. Follow `DESIGN.md` for ALL visual decisions — typography, colors, spacing, component patterns. No system fonts. No accent colors. Monochromatic only.
4. Bundle Newsreader, IBM Plex Sans, IBM Plex Mono as app resources.
5. All LLM calls must be async, non-blocking, failure-tolerant. If Groq is unreachable, feature degrades silently.
6. LLM responses are always JSON. Parse defensively — strip markdown fences, handle malformed responses.
7. Use xclaude MCP tools for builds: `xc-build` to compile, `xc-testing` for tests, `xc-launch` to run.
8. Never ask questions. Make the best decision and move on.
9. Commit after each passing story with message: "v3: S{N} — {title}"

## Quality Checks
After every story:
1. `xc-build` passes with zero errors
2. No force unwraps except in previews
3. New services have a protocol for testability
4. SwiftData models registered in container
5. UI matches DESIGN.md tokens (spot check colors, fonts, spacing)
