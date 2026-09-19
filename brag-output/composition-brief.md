# Hyperframes Composition Brief: Boston 311 Analytics

## Objective

Create a short launch-style brag video for Boston 311 Analytics that demonstrates the real city-to-ZIP analysis flow and the engineering system behind it.

## Output

- Composition directory: `brag-output/composition/`
- Rendered video: `brag-output/brag.mp4`
- Format: landscape — 1920x1080
- Duration: 21.84 seconds

## Source Material

- Project root: `/Users/gauravbohra/Documents/resume-projects/boston311`
- Primary files read: `README.md`, `app/app.py`, `ARCHITECTURE.md`, `SEMANTIC_MODEL.md`, `sql/views/*.sql`
- Product name: Boston 311 Analytics
- Strongest claim: citywide performance becomes ZIP-level context and actionable recurring-issue intelligence
- Key UI moment: select ZIP 02108, see `-3.1%` vs city and `Underperforming vs City`, then identify Parking Enforcement as the leading recurring issue
- Required real assets:
  - `docs/assets/city_overview_1.png`
  - `docs/assets/find_my_area_1.png`
  - `docs/assets/find_my_area_2.png`
  - `docs/assets/powerbi_semantic_model.png`
- Copy that must appear verbatim:
  - `Boston 311 Analytics`
  - `84.1% CITYWIDE SLA`
  - `ZIP 02108`
  - `-3.1% VS CITY`
  - `Underperforming vs City`
  - `Python -> PostgreSQL -> Power BI -> Streamlit`

## Creative Direction

- Tone preset: polished
- Creative direction: civic intelligence, presented like a restrained data-product launch
- Interpretation: exact numbers, clear hierarchy, native UI proportions, and confident motion with no generic SaaS decoration
- Angle: start at the city average, then use the product to reveal the neighborhood context hidden inside it
- Hook: `84.1% CITYWIDE SLA. The average is only the beginning.`
- Outro: `Boston 311 Analytics. From raw service requests to neighborhood intelligence.`
- Avoid:
  - Generic SaaS language
  - Abstract filler visuals
  - Grid-only backgrounds disconnected from the product
  - Perspective tilts, stretched screenshots, or unreadably small whole-page thumbnails
  - Unverified record counts

## Visual Identity

- Background: `#F0F2F6`
- Surface: `#FFFFFF`
- Text: `#31333F`
- Accent: `#0068C9`
- Alert accent: `#FF4B4B`
- Display font: system sans-serif
- Body font: system sans-serif
- Visual references: Streamlit sidebar, blue Altair lines, red selected controls, pale-blue status panel, Power BI semantic-model canvas
- Screenshot treatment: full-resolution source, uniform scale only, object-fit cover/contain as appropriate, and authored camera crops on nested wrappers

## Storyboard

Use `brag-output/brag-plan.md` as the creative contract.

Scene summary:

1. The average — 3.27s — `84.1% CITYWIDE SLA` over the real city UI
2. City pulse — 5.47s — undistorted city dashboard with KPI-to-chart camera move
3. ZIP 02108 — 6.55s — selection, underperformance result, recurring issues
4. Built end to end — 6.55s — semantic model, engineering lineage, final product lockup

## Audio

- Audio role: polished support with sparse professional accents
- Audio arc: steady bed from frame 0, slight lift into the ZIP result, then a clean fade beneath the final hold
- Music: `assets/music/happy-beats-business-moves-vol-12-by-ende-dot-app.mp3`
- Music treatment: volume envelope 0 -> 0.28 by 0.75s, hold, then 0.28 -> 0 from 20.80s to 21.84s
- Music cue guidance: bundled cue JSON at `assets/music/cues/happy-beats-business-moves-vol-12-by-ende-dot-app.music-cues.json`; strong cues at 9.29s, 13.11s, and 17.47s
- Audio-reactive treatment: unavailable because the installed extraction helper cannot import NumPy; skip without blocking render
- Audio-coupled moments:
  - 9.29s — simulated ZIP selection with low-risk click
  - 13.11s — underperforming result with soft reveal
  - 17.47s — final lockup with restrained bell
- SFX selection guidance: use low-HF-risk selections from the bundled analysis; keep only three audible accents
- SFX analysis guidance: `/Users/gauravbohra/.codex/skills/brag/assets/sfx/sfx-analysis.md`
- Exact SFX choice: `interface/click_003.ogg`, `impact/impactSoft_medium_001.ogg`, `impact/impactBell_heavy_000.ogg`
- Audio files: copied locally under `brag-output/composition/assets/`
- Voiceover: disabled because the invocation did not include `--voice`

## Hyperframes Instructions

- Follow `hyperframes-core`, `hyperframes-animation`, `hyperframes-creative`, `hyperframes-keyframes`, and `hyperframes-cli`.
- This is a `/brag` workflow. Do not route into the generic Hyperframes product-launch workflow.
- Show real UI at native aspect ratio and legible scale.
- Use nested image wrappers for camera moves; preserve source geometry.
- Keep total duration at 21.84 seconds.
- Include the planned music and three SFX clips.
- Mark beat locks in source comments at 9.29s, 13.11s, and 17.47s.
- Run `npx hyperframes check` as the single browser gate before render.
