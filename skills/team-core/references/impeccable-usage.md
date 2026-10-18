# Impeccable usage for assigned UI work

This guide selects a proportionate Impeccable workflow for an assigned web design or UI task. The [integration adapter](impeccable-integration.md) governs when use is required, how availability and failures are handled, and what needs separate permission. Read it first when the provider's availability or authority is in question.

## Start from the requested intent

Use the user's task, approved requirements, and accepted design decisions to choose the work. A visual adjective such as “bold,” “quiet,” or “clean” describes a quality; it does not by itself request a new visual world or select a named workflow. Reuse settled decisions. Ask only when a material unresolved choice could change the result.

| Task intent | Appropriate workflow |
| --- | --- |
| A new surface, brand expansion, or replacement of the established visual world | Follow the active Skill's new-work guidance for the visual direction. Use shape when discovery would resolve material questions; shape returns a confirmed brief and stops before implementation or persistence. |
| A change within an accepted visual world | Preserve its identity and behavior outside the assigned scope. Follow the requested task or named workflow; use distill when the user asks to simplify or remove complexity, not as a default fallback. |
| A focused visual or interaction adjustment | Apply the matching, bounded refinement workflow from the active Skill. Keep the incumbent design and unaffected behavior. |
| A design-only proposal, critique, audit, or preview | Use the matching provider workflow to return the assigned analysis or brief. Do not write production code unless implementation is separately assigned and authorized. |

For a redesign, a rejected visual direction is evidence about what to avoid, not the default starting world. Keep approved product truth, content, required functionality, accessibility, platform constraints, and applicable PRD requirements. Do not use visual ambition as permission to replace them.

Examples: “Design a dashboard, replacing the rejected brochure-like direction” calls for the new-work route; preserve dashboard tasks and product facts while selecting a replacement visual world. “Keep the accepted system and improve this form's type hierarchy” is a local refinement; do not restart the visual world. “Simplify this screen” expresses a distillation intent; keep necessary functions and use distill. A request for a design-only preview of a missing page still uses the applicable design workflow, but the output remains a brief or isolated preview rather than production code.

## Choose only the relevant workflow

The active Impeccable Skill defines its supported shortcuts, references, and stopping points. Read the Skill and the specific reference needed for the assigned work; do not load every command guide. Follow an explicit user request when it names a supported workflow. When the task asks which workflow fits, use the Skill's routing guidance to recommend an option without executing it. When intent is unclear and materially affects the outcome, ask the Lead for the smallest needed decision. Invoke the Skill through the active Codex Skill mechanism; names such as shape describe a Skill workflow, not a shell or engine command.

Do not impose a fixed sequence such as init, shape, new-work, critique, and polish on every task. Shape owns discovery and stops with the confirmed brief. New-work is for choosing a visual world when the task calls for one. Critique, audit, distill, polish, and focused refinements answer different intents; a handoff or role change does not restart them. Do not repeat an accepted decision or brief unless new evidence creates a material question.

For a delegated design phase, pass a compact handoff: the user goal and audience; target page/flow plus current behavior and real content; what to preserve and what the user rejected; the authorized output (brief, prototype, or production page) and owned files; applicable requirements/constraints; and only the material open decisions. Include resource paths or references the role cannot otherwise see.

This guide adapts web-facing guidance from Impeccable Skill 4.6.0. If the active installed Skill is a different version, its instructions govern exact workflow syntax and version-specific behavior. Workflow names in this guide are not shell commands. Do not invent command-line flags or use a package launcher to discover or bootstrap the provider.

## Keep the assignment and record clear

The Lead assigns the design owner and phase and retains Team role-routing authority; do not create an automatic Impeccable subteam or assume an upstream helper role is loaded. The design owner uses the provider for its assigned applicable work. A later frontend implementer may reuse a confirmed provider-backed brief without claiming it personally invoked Impeccable; it uses the provider for additional relevant design work it owns. Do not make every role repeat the complete provider workflow.

For a design-only preview or consultation, return only the assigned brief, critique, comparison, or prototype. Do not write business code or treat a prototype as the integrated product. For implementation, the frontend engineer remains the sole owner of production page and flow files.

In the existing work or stage record, state what actually happened: the Skill version and relevant references/workflow used when known, whether the output was newly produced or an accepted brief was reused, and any access or engine limitation. Do not claim an unrun command or successful provider invocation. An accessible Skill can still inform the work when an engine operation fails and the Skill supports a fallback; record the failure and fallback accurately.

Keep rendered inspection, functional checks, and user acceptance separate. A detector result, package validator, recommendation, or uninspected screenshot does not prove that a page is attractive, usable, or accepted. Report visual status and the inspected page, viewport, and state in the existing task record when that inspection is part of the assignment.

## Source and attribution

This adapted guide is based on the Impeccable Skill and selected web references at [revision 6af45ac9a5eb8792f033d3242f52e99812fd91fa](https://github.com/pbakaus/impeccable/tree/6af45ac9a5eb8792f033d3242f52e99812fd91fa). The adapted source paths are .agents/skills/impeccable/SKILL.md, .agents/skills/impeccable/reference/shape.md, .agents/skills/impeccable/reference/routing.md, and .agents/skills/impeccable/reference/distill.md. This file has been modified for the Kit's task routing, authorization, ownership, and evidence contracts. Copyright 2025 Paul Bakaus. See [the accompanying Apache-2.0 license](licenses/impeccable-LICENSE.txt) and [attribution notice](licenses/impeccable-NOTICE.md). The upstream Skill, runtime, and native-platform references are not bundled.
