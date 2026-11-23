# Task-driven UI design and evaluation

Use this guide for an assigned interface design, material interaction change, or
UI/UX assessment. Select the relevant depth; a small local adjustment does not need
a whole-product study. The [UI delivery contract](ui-quality.md) owns page scope,
roles and rendered evidence. The [QA contract](test-acceptance-contract.md#qa-inputs-and-user-perspective-verification)
owns findings, acceptance and retesting. Reuse their Work/Verification record;
this guide adds a method, not another workflow, report, role or scoring gate.

## Establish what a good result means

Start with the intended person, task, context and outcome. Identify what the person
already knows, what object or version they are acting on, and what they need next.
Read the current product requirements and accepted design rather than treating the
implementation, an attractive reference, or a model's preference as the oracle.
Keep an existing product's identity and supported platforms unless replacement is
authorized. An operations workspace and a marketing page need different density
and hierarchy.

Use three distinct kinds of authority:

| Basis | What it can establish | What it cannot establish alone |
| --- | --- | --- |
| Approved product behavior | Correct objects, scope, state, results and supported environments | That a person will discover or prefer the interaction |
| Applicable standard or platform pattern | A specific requirement or interaction convention, with its scope and exceptions | Whole-product usability, attractiveness or complete conformance from samples |
| Inspection or research hypothesis | A plausible task obstacle or alternative worth checking | Observed user failure, a universal design law or permission to redesign |

Missing or conflicting authority limits the affected judgment. Preserve the
baseline, identify the decision owner, and continue independent work. If the user
is unavailable, retain the exact decision and consequence rather than inventing
agreement or repeatedly asking.

## Design from the task and its state transitions

Within the existing UI brief, trace a short representative chain:

`starting state -> discover action -> identify object/scope -> act -> understand result -> continue or recover`

For example, a creation tool may need to select a saved source, prepare an edit,
inspect the proposed changes, save a result and find it again. List the important
objects and transitions, not only screens. Distinguish local input, a saved version,
a reference, a proposed action and an applied change when those concepts exist.

Use that chain to decide:

- **Information and action priority:** make the current location, object and useful
  next action recognizable. Separate frequently needed controls from occasional
  management. A context can have a primary next action while the whole workspace
  still has several legitimate navigation options; button count alone is not a
  cognitive-load diagnosis.
- **Composition and reading:** group related information, use consistent labels and
  alignment, and let hierarchy reflect the task. Reuse the existing components and
  tokens. Choose density and prose measure for the actual language/content; a
  Latin-character line-length rule is not automatically a Chinese editor rule.
- **Feedback and recovery:** define what is shown while work is pending, what proves
  completion, what remains unresolved and what the person can actually do after a
  failure. Preserve input where appropriate. An unsupported capability, invalid
  input and an unknown outcome need different next steps.
- **Continuity:** specify what survives a view, object, conversation or project
  switch. Define focus and selection separately. Account for a late response,
  changed source, cancellation or partial result where these risks exist.
- **Adaptation:** decide how secondary areas collapse or become focused views at
  supported widths, zoom and content lengths. Preserve reachable primary actions;
  shrinking text or merely obtaining a screenshot is not proof of adaptation.

Compare alternatives only when a real decision warrants them. Explain the task
benefit, cost and retained constraints; do not manufacture variants or a numerical
beauty score. Implement and inspect a representative complete chain before
propagating its visual baseline to other pages.

## Inspect by doing the work

### Prepare a trustworthy observation

Pin the relevant source/build, route, data and supported viewport. Separate
first-use, returning-use and expert-use assumptions. Use realistic lengths,
language and data density without exposing private material. Prepare owned test
data and authorized side effects; a UI assessment does not authorize model
spending, permission expansion, destructive operations or a new analytics tool.

Wait for the relevant application state to be ready, not an arbitrary delay or
an unrelated global “ready” label. A transitional empty frame must not become a
settled empty-state verdict. Persistent streams may never reach network idle;
observe the actual project, object, loading state or result needed for the case.

### Select a small set of meaningful variations

Start with a complete normal chain, then add distinct risks exposed by that chain.
Use the existing packet to explain required, conditional and unobserved states;
do not require every Cartesian combination.

| Variation | Question to observe |
| --- | --- |
| Empty and populated content | Can the person start useful work and later locate existing work? |
| Long text, labels or many items | Does the hierarchy remain readable and do actions remain reachable? |
| Pending, error, partial or unknown result | Does visible feedback match what actually happened and enable a valid next step? |
| Switching and returning | Do object/version, input, selection and relevant reading position remain correctly attributed? |
| Keyboard and pointer | Can the task be completed, focus understood and overlays exited using the required input method? |
| Supported size/zoom and exploratory size | Do required controls work at the declared target; what happens beyond it? |

Interleave actions when continuity matters. Saving source version 3 while keeping
a fixed version 2 reference, or visiting conversation B before returning to A,
checks more than verifying each component in isolation. Record the actual
objects and states. Do not silently convert an exploratory width into supported
scope, or call an observed off-screen action a pass because other widths work.

### Connect the visible result to the actual consequence

At each important step, inspect whether the action was discoverable, its object
and scope understandable, its effect correct, its feedback truthful and its next
step possible. Confirm relevant persistence or business effects at the narrowest
real boundary; a toast, HTTP success, screenshot or assistant claim alone may be
insufficient. API evidence cannot prove that a button is reachable.

For a failure, follow the cause and recovery meaning through wrappers to the final
rendered message. A correct server error followed by misleading UI advice is still
a user-facing defect. “Try different input” cannot repair a known desktop-only
capability. Do not classify that example as a WCAG input-error violation merely
because its recovery text is bad; the criterion's applicability still matters.
Preserve sanitization and trust boundaries when fixing the chain: map trusted
application recovery, rather than blindly displaying arbitrary provider fields.

For AI-assisted work, inspect what will be read or changed, where permission is
obtained, how to stop or correct, which object receives late results, and how
proposed, applied, partially applied and unknown outcomes differ. Previewing a
reference does not prove the model received it or grant authority to modify it.
UI checks do not replace the actual authorization and data controls.

### Triangulate ambiguous signals

Use rendered pixels, semantic/DOM evidence and actual interaction or result data
as needed for the claim. A screenshot can reveal overlap but cannot establish
keyboard behavior or saved state. A semantic tree can expose names and roles but
may omit visual relationships. Source inspection can explain a failure without
proving that the rendered final revision behaves correctly.

Treat selector failure, an incomplete accessibility dump, a stale frame and a
browser/environment limitation as tool signals first. Cross-check through a
supported, safe interaction before reporting a product defect. Respect browser
security restrictions; do not bypass them to manufacture evidence. If the check
remains unavailable, keep the gap explicit.

## Use technical checks with their actual conditions

Declare the applicable accessibility edition and level when making a conformance
finding. Use the standard's definitions and exceptions, then inspect the affected
task. For example:

- WCAG 2.2 AA target size uses 24 by 24 CSS pixels **or an applicable exception**,
  including spacing and equivalent controls. The 44 by 44 enhanced target is a
  different, AAA criterion. A 32-pixel desktop button is not automatically an AA
  failure, and a smaller target needs its spacing/context checked.
- Text contrast depends on the actual foreground, composited background, text
  size/weight and state. WCAG AA uses 4.5:1 for normal text and 3:1 for qualifying
  large text; compare the unrounded ratio and consider disabled controls and other
  exceptions. Sampled passing ratios do not establish whole-page conformance.
  Treat gradients, images,
  opacity and unmeasured backgrounds as unresolved rather than inventing a ratio.
- Exercise keyboard operation and focus after rerenders, errors, dialogs and
  switches. BODY focus or an unexpected next Tab is an observation to investigate,
  not automatically proof of a keyboard trap or focus-order violation.
- Check reflow, zoom, clipping and intentional scrolling against the applicable
  requirement. A two-dimensional canvas exception does not automatically exempt
  surrounding controls or prose. A product's declared desktop sizes do not waive
  independently applicable accessibility criteria. An emulated viewport does not
  prove physical touch behavior or assistive-technology compatibility.

Automated accessibility findings and design-provider diagnostics are candidates
to verify in context. Follow the provider's actual workflow and authorization
requirements when invoking a named command; reading some principles does not
mean a complete critique, audit, detector run or independent assessment occurred.
Do not import an aggregate provider score or simplified threshold as the
project's acceptance oracle.

## Classify and act without overclaiming

Reuse the existing finding format and the
[review disposition rules](code-review-method.md#disposition-and-human-decisions).
Keep these judgments distinct:

- **Confirmed defect:** observed behavior violates an applicable requirement or
  established operation meaning. Identify the expected result and its authority.
- **Risk or hypothesis:** a plausible obstacle is observed, but its task impact,
  cause or applicability is not established. State the discriminating check.
- **Improvement or preference:** behavior may meet its contract while an
  alternative could help. Explain the goal, trade-off and missing user evidence;
  taste alone does not make it a must-fix.
- **Requirement question:** support, behavior or authority is missing/conflicting.
  Preserve the decision and affected restriction rather than deciding by taste.

For example, a less prominent creation entry is a discoverability hypothesis until
its task implications are established. A fixed old-version preview may be correct.
An unsupported-size observation is neither verified support nor automatically a
violation of the agreed desktop contract. Preserve successful behavior as evidence
too; a report should not maximize its issue count.

Severity describes consequence and recovery cost. Priority also considers actual
reach, frequency evidence, dependencies and cost; certainty describes the support
for the claim. Keep all three separate from authorization. Record observed
attempts, not an invented population failure rate. Label a causal explanation as
a hypothesis until supported. Route confirmed in-scope defects to the owner;
retain human-decision and optional items under their existing restrictions.

Retest the original symptom on the actual repaired revision, then the relevant
adjacent chain. Keep unchanged evidence only while its inputs remain applicable.
A proposed fix, different screenshot or passing unrelated check does not close a
finding. Leave unobserved AI, browser, device and human outcomes explicit.

## Evaluate the method as well as the interface

Separate coverage expansion, repair verification and comparative research:

- Exploring another state can expose a missed risk; it does not prove the old
  product was worse or the new harness better.
- Repeating a task can test a repair. Faster repetition by the same agent can
  reflect familiarity and is not a novice-usability result.
- A controlled harness comparison needs comparable task briefs, starting code/data,
  model/settings, tools and evaluation criteria. Judge grounded actionable
  findings, missed issues and false positives, including correct-behavior controls.
  Record evaluator agreement and disagreements where measured. Keep an unrun
  comparison unrun; do not turn source-routing tests into model-quality evidence.
- Representative-user tests observe real people attempting relevant tasks. Task
  completion, errors, recovery, help and subjective feedback answer different
  questions. Surveys such as SUS are human-reported measures, not scores an agent
  awards from a screenshot. Choose measurements from the product goal rather
  than imposing a universal participant count, satisfaction threshold or UI score.

An agent walkthrough is expert inspection. Neither it nor automated interaction
substitutes for representative users, accessibility conformance evaluation or
user-only acceptance. Use the existing packet for evidence and gaps; do not start
a separate evaluation platform merely to follow this guide.

## Primary evidence and applicability

Sources below were checked on 2026-11-18. They support selected methods and limits,
not a claim that this Kit has improved model output. Reading this whole list is
not required for every UI task; recheck the source relevant to a changed premise.

| Source | Applicable use and limitation |
| --- | --- |
| [WCAG 2.2 Recommendation, 12 December 2024](https://www.w3.org/TR/2024/REC-WCAG22-20241212/) | Testable accessibility criteria with declared level, conditions and exceptions. It does not define total product quality. |
| [W3C target size](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum) and [contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) explanations | Informative interpretation of specific criteria; inspect actual size/spacing, contrast state and exceptions rather than applying blanket thresholds. |
| [WAI-ARIA APG keyboard guidance](https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/) | Informs widget semantics, keyboard conventions and focus management. It is informative guidance; roles alone do not implement behavior. |
| [Nielsen's heuristics, reviewed 2024](https://www.nngroup.com/articles/ten-usability-heuristics/) | Inspection prompts for status, vocabulary, consistency, control and recovery. These are broad heuristics, not a causal diagnosis or a universal scoring rubric. |
| [Amershi et al., CHI 2019](https://www.microsoft.com/en-us/research/wp-content/uploads/2019/01/Guidelines-for-Human-AI-Interaction-camera-ready.pdf) | Human-AI interaction guidance evaluated with design practitioners and AI products. Useful for expectations, control and correction; not proof of a particular modern agent's safety or task success. |
| [Rodden et al., CHI 2010](https://research.google/pubs/measuring-the-user-experience-on-a-large-scale-user-centered-metrics-for-web-applications/) | HEART motivates mapping product goals to suitable UX measurements. Its large-scale web-product context does not prescribe a small-team test or a mandatory metric set. |
| [Duan et al., UICrit, UIST 2024](https://people.eecs.berkeley.edu/~bjoern/papers/duan-uicrit-uist2024.pdf) | Expert-annotated mobile screenshots support grounded critique research. The paper's limitations exclude whole-app flows; participants did not implement critiques, so practical design improvement was not demonstrated by that evaluation. |
| [Lubos et al., FSE 2026 author version](https://arxiv.org/html/2604.25420v1) | Task descriptions and recordings inform suggested improvements. Software-engineering participants assessed selected recommendations; perceived plausibility/helpfulness in two applications is not measured post-repair task success. |
| [Mao et al., UXBench, 2026 preprint](https://arxiv.org/html/2606.13192v1) | Screenshot question-answer tasks study specific UX reasoning with curated labels. Mobile, constrained-choice benchmark accuracy does not certify open-ended diagnosis or an interactive desktop journey. |

The operational synthesis above is this Kit's method. Preserve the distinction
between normative requirements, published study findings, local observations and
inference when applying or revising it.
