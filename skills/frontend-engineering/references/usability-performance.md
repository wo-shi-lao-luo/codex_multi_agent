# Frontend usability and performance checks

Apply only the checks that match the changed interaction or a supported performance requirement. The [UI delivery contract](../../team-core/references/ui-quality.md) remains authoritative for the UI brief, page ownership, rendered inspection, and evidence status.

## Interaction and accessibility

For the affected flow, check that controls communicate their purpose and state; keyboard operation and focus remain usable where relevant; errors and completion feedback are perceivable; and the interface behaves at the project's supported viewport sizes. For dialogs or other complex widgets, follow the established design-system pattern rather than inventing behavior. Use semantic HTML and accessible names before adding custom interaction code.

For an affected form or dialog, useful focused cases may include preserving entered values after a recoverable error, preventing accidental duplicate submission while an action is pending, and moving/restoring focus appropriately when a dialog opens or closes. Select only cases relevant to the changed behavior.

Do not turn this into a full accessibility audit for an unrelated small change. Expand when the changed control, user group, product requirement, or observed defect makes a broader check necessary. Keep user acceptance distinct from agent inspection.

## Performance

Treat performance as a measured behavior, not a presumed benefit. Start from a concrete symptom, user-visible acceptance requirement, or known hot path. For request-driven flows, inspect the relevant network waterfall, duplicate requests, and unnecessarily large payloads before reaching for memoization. Use available project measurements to compare the affected operation; do not add telemetry, a benchmark dependency, caching, memoization, or an arbitrary numerical target without a reason. Preserve correctness and accessible feedback when optimizing.

## Primary references

- [W3C ARIA Authoring Practices: modal dialog](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/) for dialog-specific keyboard and focus behavior.
- [web.dev: Web Vitals](https://web.dev/articles/vitals) when user-centric loading or interaction performance is actually being measured.
- [Vercel Web Interface Guidelines](https://vercel.com/design/guidelines) as optional implementation review prompts; the project's design system and approved brief take precedence.
