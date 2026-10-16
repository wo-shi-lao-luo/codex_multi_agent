---
name: frontend-design
description: Provide concrete design guidance and refine web interfaces with clear hierarchy, consistent styling and usable interactions. Use for page design requests and visible UI implementation; pair with frontend-engineering when implementing, not for backend-only work or inferred redesigns.
---

# Frontend design

Apply the shared [execution contract](../team-core/references/execution-contract.md) and [UI delivery contract](../team-core/references/ui-quality.md), including its conditional Designer triggers and page ownership. For optional Impeccable use, read [the integration adapter](../team-core/references/impeccable-integration.md). This Skill supports concrete design proposals as well as interface implementation. During implementation, pair it with [frontend-engineering](../frontend-engineering/SKILL.md) and preserve its architecture, comment and test requirements; design-only consultation does not require production edits.

## When to activate

Use for design proposals when the user asks to design or adjust a page, for a missing page in an actual UI task, or for general design consultation. For implementation work, use the established visual baseline while creating or changing visible layout, content hierarchy, styling or interaction. A routine bug fix or incidental cleanup without explicit design intent does not trigger a separate Designer. For small work, reuse the existing baseline and inspect only the affected result; do not restart design discovery. Pure backend work and logic-only changes without UI impact do not need this design process.

## Establish a lightweight baseline

Read the UI brief and inspect available existing pages, components and style definitions before designing. Identify the audience, primary task, content priorities and supported screens. Preserve explicit user choices and established brand language. References guide relevant qualities, not wholesale copying of content or assets.

Without an established system, describe a concise baseline for the brief: type hierarchy, spacing rhythm, content width/grid, density, neutral and accent colors, status colors, borders/radii and component states. Implement reusable tokens/components only when implementation is assigned. Prefer familiar, clear interaction patterns and a restrained, coherent appearance. Choose density for the task: an operations table is not a marketing hero. Do not impose gradients, giant headlines, identical cards or decorative animation on every brief.

Prefer suitable existing libraries and assets. For third-party code/assets, apply [reuse and third-party guidance](../team-core/references/reuse-and-third-party.md); introducing a dependency, changing the design system or fetching paid/licensed assets still requires the relevant authority. Use available fonts/icons consistently with fallbacks; do not make basic readability depend on remote fonts. This baseline fits the existing work contract/project conventions; no mandatory lengthy proposal or per-page design document.

## Implement the complete page

- Establish reading order and one clear primary action per context; visually distinguish secondary/destructive actions. Group related controls and place labels/errors near their fields.
- Use deliberate alignment, a consistent spacing scale and a readable type hierarchy. Keep line lengths and contrast usable; avoid treating every heading, button and panel as equally prominent.
- Use task-appropriate page width and density. Adapt navigation, tables and forms to narrow screens; use intentional scrolling where necessary instead of shrinking text or clipping controls.
- Give loading, empty, error, success, disabled and focus states intentional treatment when applicable. Explain recovery actions, preserve input after errors where appropriate, and prevent duplicate submissions. Do not rely only on color or hover.
- Use domain-relevant content and representative data lengths. Label demo data honestly; do not invent customer endorsements, metrics or production claims to decorate the page. A polished empty state is better than filler.
- Keep icons, controls and copy consistent across the flow. Motion should clarify state changes, respect reduced-motion preferences and never be required to understand the interface.

For an assigned design-only proposal, make the brief concrete enough for an engineer to implement; use a separate prototype only when it adds useful clarity and is within assigned file ownership. For implementation, start a new UI with one representative page/core flow, inspect it, then reuse its baseline. The frontend engineer owns the integrated production experience while keeping implementation modular and respecting file ownership. Routine polish in scope is part of delivery, not an optional future stage; request scope adjustment for shared files when needed.

## Inspect and refine

Follow the UI delivery contract's rendered-page checks for implementation. The engineer remains responsible for required rendered verification. When assigned, Designer may provide a bounded visual check against the selected design at handoff; this is a design comparison, not another functional test or user-acceptance gate. Inspect the assembled page and core interactions at declared viewports with realistic content and relevant states. Fix specific problems and re-inspect; passing component tests or taking an unexamined screenshot is insufficient. Keep functional evidence and visual status separate. If browser inspection is unavailable, report `not verified` without blocking unrelated safe implementation or claiming visual readiness.

## Return paths

- Missing consequential brand/scope decision → ask the Lead/user for that decision; do not gate routine stylistic choices.
- Necessary shared layout or style outside ownership → request a bounded adjustment before editing it.
- Rendered defect → fix within scope and inspect the affected result again.
- Missing runtime/browser access → record the unavailable visual check and required next step.

## Output contract

For design-only work, return the recommendation, relevant baseline/resources, optional prototype path, assumptions and unresolved decisions; do not claim implementation or acceptance. For implementation work, return pages/flows, baseline/resource references, changed files, functional results, visual status and actual route/viewport/state evidence, fixes and remaining gaps. Do not self-score a page as proof of quality or create a separate design report unless requested.
