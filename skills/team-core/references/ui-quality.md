# UI delivery contract

## Activation and ownership

Apply to new pages and changes to visible UI or user interaction. Backend-only work is not applicable. For frontend logic-only changes, assess observable impact and record the reason if visual inspection is not applicable. Do not turn a small fix into a redesign.

### Conditional Designer role

Route to the exact `team-designer` role when an actual UI task needs a page that does not yet exist, when the user explicitly asks to design or adjust a page (including a small adjustment), or when the user asks for design consultation. An empty repository alone is not a UI task. Do not add Designer for an ordinary bug report or incidental style cleanup without explicit design intent, backend-only work, or frontend logic-only work without a design request.

For design-only consultation, `team-designer` can return the recommendation directly without starting an implementation workflow. For page implementation, Designer provides a concrete design brief and may produce an isolated prototype when useful and assigned; one `team-frontend-engineer` remains the sole production page/flow owner. Never let both roles edit production page files concurrently. Reuse accepted design decisions instead of repeating discovery. A bounded rendered check by Designer may compare the integrated page with the chosen design when assigned; it does not replace the engineer's required rendered verification, user acceptance, or other applicable review.

The Lead checks the active role catalog and selects `team-designer` explicitly when the trigger applies. A source profile or installed file does not prove the role is available in the current session. If the required role is unavailable, follow [named-role preflight](role-routing.md#named-role-preflight-and-invocation); do not silently substitute the Lead or frontend engineer.

The Lead retains the user's product goal when delegating. Give one frontend owner responsibility for the coherent page or user flow, not merely a list of isolated components. A small demo normally has one production implementer; parallelize only independent work that benefits from it. Modular code is still required. File ownership limits edits, not the context the owner may read.

## UI brief in the work contract

Use the UI brief in [execution templates](execution-templates.md), not a separate mandatory design document. For a design proposal, pass audience, primary user task, page/flow context, stage scope within the whole product, content/action priorities, existing visual baseline and resource paths, relevant constraints, and unresolved decisions. For implementation, also assign the authorized page/shared-style files and target viewports/states/flows to the frontend engineer. Preserve explicit user design requests. Link available references and explain which aspects matter; do not assume a child inherited screenshots or the original conversation.

Use the [frontend-design Skill](../../frontend-design/SKILL.md) for concrete design decisions and refinement. When implementing, the frontend engineer also uses [frontend-engineering](../../frontend-engineering/SKILL.md) for maintainable implementation. Apply [the optional Impeccable adapter](impeccable-integration.md) only when that capability and its instructions are accessible in the active role context. Missing non-material preferences may use a stated, restrained baseline. Ask only for a consequential brand, redesign or scope decision, or when the user requested approval.

Within authorized scope, typography, spacing, responsive layout and component-state polish are normal implementation, not optional extras requiring repeated approval. If coherent delivery requires an unassigned shared style or layout file, request a bounded ownership adjustment from the Lead. Do not patch around it with local overrides or cross another writer's ownership. New dependencies, design-system replacement, unrelated changes and structural refactoring retain their existing approval requirements.

## Build and integrate

For a new interface, implement and inspect one representative page or core flow before propagating its baseline. Record reusable decisions in existing project conventions and shared tokens/components, not a new document per page. Existing products inherit their established visual language. A representative page is an internal quality checkpoint, not an automatic user-approval gate.

The owner delivers the complete assigned experience, including loading, empty, failure and success behavior as applicable. Future-stage functionality may remain out of scope, but current-stage UI must be coherent and clearly identify unavailable behavior; never use stage boundaries to justify a visibly unfinished assembled page.

## Separate functional and visual verification

Functional tests and builds do not establish visual quality. For applicable changes, use available browser tools to inspect the actual rendered, integrated page, including below the fold and important interaction states. Cover declared desktop and narrow-screen sizes unless the supported environment has a justified narrower scope. Use representative content, long labels/text and realistic data density. Do not expose sensitive production data or perform unapproved external actions to obtain evidence.

Check purpose and primary action clarity; hierarchy, alignment, spacing, typography and component consistency; overflow and responsive behavior; loading/empty/error recovery; keyboard focus, readable contrast and feedback for core actions. Apply these against the brief rather than personal taste. Capture screenshots when supported, actually inspect them, and record page/route, viewport, state and concrete observations. Screenshots without inspection, self-awarded scores and screenshot-diff tests alone are not acceptance evidence.

Fix observed in-scope defects and re-inspect affected results. Do not require an arbitrary number of polish loops or repeatedly redesign an adequate page. If remaining repairs exceed authorization, report the specific gap and needed decision.

For task inputs, bounded adjacent user-perspective observations, finding classification and retest handoff, follow [QA inputs and user-perspective verification](test-acceptance-contract.md#qa-inputs-and-user-perspective-verification); visual observations do not by themselves establish user acceptance or authorize expanded scope.

Record functional results separately from visual status: `verified`, `issues remain`, `not verified`, or `not applicable` with a reason. If the app cannot run, credentials are missing or no visual tool is available, continue safe work and report `not verified`; code review cannot silently substitute for rendered inspection. Never claim external-release visual readiness in that state.

At integration, the Lead checks that evidence covers the final assembled revision. Recheck affected pages after integration changes that invalidate prior evidence. An assigned reviewer inspects available rendered evidence against the brief and names uncovered states; code-only review remains code-only. Do not add reviewers solely because the workflow has roles.

## Handoff and stage compatibility

Use existing Verification/Handoff records for the brief/baseline reference, functional evidence, visual status, inspected routes/viewports/states, fixes and remaining gaps. For team development, include applicable visual checks in the existing stage packet; no second report is required. Agent visual inspection is not user approval and must not change `Final manual status` or bypass manual-verification archival rules.

Package validators check routing and packaged resources only. They cannot establish that a page is attractive, usable or that this harness improves model output. Validate improvement separately on a matched task with fixed model/settings, brief, starting code and tools, using actual pages and user judgment; report an unrun comparison as unrun.
