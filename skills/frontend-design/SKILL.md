---
name: frontend-design
description: Design, implement and refine coherent first-version web interfaces with clear hierarchy, consistent styling and usable interactions. Use for new pages or visible UI changes alongside frontend-engineering, not backend-only work or automatic brand redesigns.
---

# Frontend design

Apply the shared [execution contract](../team-core/references/execution-contract.md) and [UI delivery contract](../team-core/references/ui-quality.md). This Skill guides actual interface code and rendered refinement, not just design documents. Pair it with [frontend-engineering](../frontend-engineering/SKILL.md); preserve its architecture, comment and test requirements.

## When to activate

Use when creating a page, assembling a user flow or changing visible layout, content hierarchy, styling or interaction. For a small change, reuse the existing baseline and inspect the affected result; do not restart design discovery. Pure backend work and logic-only changes without UI impact do not need this design process.

## Establish a lightweight baseline

Read the UI brief and inspect available existing pages, components and style definitions before designing. Identify the audience, primary task, content priorities and supported screens. Preserve explicit user choices and established brand language. References guide relevant qualities, not wholesale copying of content or assets.

Without an established system, state a concise baseline and implement it in reusable tokens/components: type hierarchy, spacing rhythm, content width/grid, density, neutral and accent colors, status colors, borders/radii and component states. Prefer familiar, clear interaction patterns and a restrained, coherent appearance. Choose density for the task: an operations table is not a marketing hero. Do not impose gradients, giant headlines, identical cards or decorative animation on every brief.

Reuse existing libraries/assets first; introducing a dependency, changing the design system or fetching paid/licensed assets requires the relevant authority. Use available fonts/icons consistently with fallbacks; do not make basic readability depend on remote fonts. This baseline fits the existing work contract/project conventions; no mandatory lengthy proposal or per-page design document.

## Implement the complete page

- Establish reading order and one clear primary action per context; visually distinguish secondary/destructive actions. Group related controls and place labels/errors near their fields.
- Use deliberate alignment, a consistent spacing scale and a readable type hierarchy. Keep line lengths and contrast usable; avoid treating every heading, button and panel as equally prominent.
- Use task-appropriate page width and density. Adapt navigation, tables and forms to narrow screens; use intentional scrolling where necessary instead of shrinking text or clipping controls.
- Give loading, empty, error, success, disabled and focus states intentional treatment when applicable. Explain recovery actions, preserve input after errors where appropriate, and prevent duplicate submissions. Do not rely only on color or hover.
- Use domain-relevant content and representative data lengths. Label demo data honestly; do not invent customer endorsements, metrics or production claims to decorate the page. A polished empty state is better than filler.
- Keep icons, controls and copy consistent across the flow. Motion should clarify state changes, respect reduced-motion preferences and never be required to understand the interface.

Start a new UI with one representative page/core flow, inspect it, then reuse its baseline. Own the overall experience while keeping implementation modular and respecting file ownership. Routine polish in scope is part of delivery, not an optional future stage; request scope adjustment for shared files when needed.

## Inspect and refine

Follow the UI delivery contract's rendered-page checks. Inspect the assembled page and core interactions at declared viewports with realistic content and relevant states. Fix specific problems and re-inspect; passing component tests or taking an unexamined screenshot is insufficient. Keep functional evidence and visual status separate. If browser inspection is unavailable, report `not verified` without blocking unrelated safe implementation or claiming visual readiness.

## Return paths

- Missing consequential brand/scope decision → ask the Lead/user for that decision; do not gate routine stylistic choices.
- Necessary shared layout or style outside ownership → request a bounded adjustment before editing it.
- Rendered defect → fix within scope and inspect the affected result again.
- Missing runtime/browser access → record the unavailable visual check and required next step.

## Output contract

Return implemented pages/flows, baseline/resource references, changed files, functional results, visual status and actual route/viewport/state evidence, fixes and remaining gaps. Do not self-score a page as proof of quality or create a separate design report unless requested.
