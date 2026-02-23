# CVector Plant Monitor — Ralph Loop Instructions

You are an autonomous agent in a Ralph loop. Each iteration you get fresh context.
Your memory across iterations comes from: git history, `progress.txt`, `prd.json`, and this file.

Never ask questions. Make your best decision and move forward.

## Source of truth

- `prd.json` — prioritized user stories with `passes` status. This is your task list.
- `DESIGN.md` — the product and UX contract. All visual decisions are documented here.
- `design-reference.html` — the static HTML mockup showing the exact target design. Open this in a browser to see what the final product should look like.
- `progress.txt` — append-only learnings across iterations. Read this FIRST.

## Workflow per iteration

1. Read `progress.txt` (check Codebase Patterns section first)
2. Read `prd.json`
3. Check you're on the correct branch from PRD `branchName`. If not, check it out or create from main.
4. Pick the highest priority user story where `passes: false`
5. Implement ONLY that one story
6. Run quality checks (see below)
7. If checks pass, commit with message: `[ralph] US-XXX: <title>`
8. Update `prd.json` to mark the story as `passes: true`
9. Append learnings to `progress.txt`

## Project structure

```
cvector-plant-monitor/
├── backend/           # FastAPI + SQLAlchemy + SQLite
│   ├── main.py        # API endpoints + background data generator
│   ├── models.py      # ORM models (Facility, Asset, SensorReading)
│   ├── schemas.py     # Pydantic response schemas
│   ├── database.py    # DB session management
│   └── init_db.py     # Migration + seed script
├── frontend/          # React + Ant Design + Recharts
│   ├── src/
│   │   ├── App.jsx           # Main app with facility selector
│   │   ├── app.css           # Global styles
│   │   ├── api.js            # API client functions
│   │   ├── main.jsx          # React entry + Ant Design config
│   │   ├── hooks/
│   │   │   └── usePolling.js # Auto-refresh hook
│   │   └── components/
│   │       ├── StatusOverview.jsx  # Asset status pill counters
│   │       ├── MetricCards.jsx     # Aggregated metric numbers
│   │       ├── TimeSeriesChart.jsx # Recharts area chart
│   │       └── AssetTable.jsx      # Expandable asset table
│   ├── index.html
│   ├── vite.config.js
│   └── package.json
├── CLAUDE.md          # This file
├── DESIGN.md          # UX contract
├── design-reference.html  # Static HTML target mockup
└── prd.json           # Ralph task list
```

## Tech stack

- **Backend**: Python, FastAPI, SQLAlchemy, SQLite
- **Frontend**: React 18, Ant Design 5 (dark algorithm disabled — we use custom light theme), Recharts, Vite
- **Fonts**: IBM Plex Mono (monospace throughout — this is a terminal-inspired design)
- **Design system**: See `DESIGN.md` for the full specification

## Frontend design skill (IMPORTANT — read before any UI work)

Before implementing ANY UI story, **load and read the `frontend-design` skill**. This is a curated set of best practices for creating production-grade frontend interfaces with high design quality. It covers typography, color theory, spatial composition, and how to avoid generic AI-generated aesthetics.

To use it: if you have access to `/mnt/skills/public/frontend-design/SKILL.md` or a similar skill path, read it first. If using Claude Code with skills installed, invoke the frontend-design skill.

After reading the skill, apply its principles through the lens of this project's specific design system:

- **Aesthetic**: "Terminal Light" — brutalist structure, monospace typography, white background, green accent. Industrial but legible.
- **Typography**: IBM Plex Mono only. Weights: 400 (body), 500 (labels), 600 (emphasis), 700 (values/headings).
- **No border-radius** on reading chips or inset elements. Metric cards and pills get minimal radius or none.
- **Layout**: Hard grid borders on major containers, thin 1px dividers on inner elements. 2px borders on section boundaries.
- **Reference**: Always compare your work against `design-reference.html` — open it in the browser to see the exact target.

## UI verification with Playwright MCP

Playwright MCP is connected. Use it for **every UI story** to verify visual correctness:

1. Start backend: `cd backend && uvicorn main:app --port 8000 &`
2. Start frontend: `cd frontend && npm run dev &`
3. Wait for both servers to be ready
4. Use Playwright MCP to:
   - Navigate to `http://localhost:5173` (Vite default port)
   - Take a screenshot of the full page
   - Compare visually against `design-reference.html` (open it in a separate tab)
   - Verify data loads from the API (not empty states)
   - Test interactions: facility selector, chart time-range buttons, table hover
5. If the visual result doesn't match the design reference, fix it before marking the story as passing

A UI story is NOT complete until Playwright verification passes. If Playwright is unavailable, run `npm run build` and note that manual verification is needed.

## Quality checks

Before committing, ALL of these must pass:

```bash
# Backend
cd backend && python -c "from main import app; print('Backend OK')"

# Frontend
cd frontend && npm run build
```

If either fails, fix the issue before committing.

## Patterns and conventions

- **CSS variables**: All colors, fonts, and spacing are defined as CSS custom properties in `:root`. Never hardcode colors.
- **Component structure**: Each component is a single `.jsx` file with no separate CSS file. Styles go in `app.css` using BEM-ish class names.
- **API calls**: All API calls go through `api.js`. Components never call `fetch` directly.
- **Polling**: Use the `usePolling` hook for any data that auto-refreshes. Dashboard polls at 15s, chart at 30s.
- **Metric formatting**: Use `formatMetricName()` to convert `snake_case` to `Title Case`. Use full labels in the UI, not abbreviations.
- **Ant Design**: We use Ant Design components for Select, Segmented, Table, Spin, etc. but override their theme extensively. The dark algorithm is OFF — we're light mode with custom tokens.

## Gotchas

- The Vite dev server proxies `/api` to `localhost:8000`. The backend must be running for the frontend to work.
- SQLite DB is created in `backend/plant_monitor.db`. Delete it to re-seed.
- `init_db.py` seeds 24h of historical data. The background generator in `main.py` adds new readings every 30s.
- Ant Design's `ConfigProvider` theme tokens must be updated when changing the color scheme. See `main.jsx`.
- Recharts `AreaChart` needs `<defs>` for gradient fills — don't forget these when adding new chart lines.

## Completion signal

When every story in `prd.json` has `passes: true`, output exactly:

`<promise>COMPLETE</promise>`
