# Grove — CLAUDE.md

## AUTONOMOUS MODE

You are running in an autonomous Ralph loop. There is NO human operator.

- NEVER ask questions, present options, or request confirmation
- Read `prd.json` → find first story with `passes: false` → implement it → commit → update prd.json
- If ambiguous, make the best decision, document reasoning in `progress.txt`
- If stuck after 3 attempts, log the blocker in `progress.txt` and move to the next story
- Output <promise>COMPLETE</promise> ONLY when ALL stories in prd.json have passes: true
- After completing one story, simply stop. Ralph will spawn a fresh instance for the next story.

## Project

- **What:** Mac-native knowledge companion app (macOS 15+)
- **Full spec:** Read `spec.md` for data model, UI architecture, and feature details
- **Task list:** Read `prd.json` for user stories and build order

## Tech Stack

- Swift, SwiftUI, SwiftData
- swift-markdown for parsing, TextKit 2 for rendering
- MVVM: thin Views → ViewModels → Services
- Tuist for project generation (`tuist generate` to regenerate)

## Conventions

- All models in `Grove/Models/`
- All views in `Grove/Views/{feature}/`
- All view models in `Grove/ViewModels/`
- All services in `Grove/Services/`
- Use SF Symbols for icons, system font only
- Dark mode first, `.sidebar` material, native macOS patterns
- Prefer `NavigationSplitView` for layout
- Use `@Model` for SwiftData entities
- Use `@Observable` for view models (not ObservableObject)

## Quality Checks

Before committing, use the xclaude plugin:
- Use `xc-build` to build the project
- Use `xc-testing` to run tests if they exist
- If xclaude tools fail, fall back to: `tuist generate && xcodebuild -scheme Grove -destination 'platform=macOS' build`

## Skills

Available but use sparingly — only consult when directly relevant:
- `swift-concurrency` — reference when implementing async/await patterns or actor isolation
- `swiftui-expert-skill` — reference when stuck on complex SwiftUI layout or navigation issues

Do NOT read these skills on every iteration. Only load them when a story specifically involves concurrency or tricky SwiftUI patterns.

## Git

- Commit after each completed story
- Commit message format: `[S{id}] {story title}`
- Update `prd.json` to set `passes: true` after successful commit
- Append learnings to `progress.txt`
