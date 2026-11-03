---
name: data-science
description: Profile, prepare, analyze and model datasets, including reproducible traditional machine-learning and deep-learning prototypes with leakage-aware evaluation.
---

# Data science

## When to activate

Use for analytical data work: profiling and cleaning, transformations and features, statistical analysis, dataset splitting, model architecture/training/evaluation, and prototype export or inference. It is an on-demand research capability, not a required role for ordinary development.

## Work from evidence

- Identify the question, observational unit, target, time semantics, source permissions, intended use and acceptance owner. State unknown meanings as questions; do not silently decide what nulls, duplicates, units, labels, or outliers mean.
- Preserve raw inputs. Make derived datasets and transformations reproducible, versioned or otherwise traceable to their inputs, code, parameters and environment. Record exclusions and failed/negative experiments.
- Profile shape, keys, types, ranges, missingness, duplicates, class balance, time span and cross-source coverage before transforming. Never silently zero-fill missing values or delete outliers. Document an evidence-based, reversible choice and its effect.
- Start with a simple baseline and meaningful metrics. Fit preprocessing, feature selection and tuning only within training folds. Keep validation for selection and an untouched holdout for final reporting; choose group holdout for new-entity generalization and chronological splits for forward prediction. See [model development](references/model-development.md).

## Select relevant detail

- For joins, schema/quality checks, missingness, outliers and lineage, read [data preparation](references/data-preparation.md).
- For baselines, training, metrics, holdout discipline, deep-learning experiments, export and inference prototypes, read [model development](references/model-development.md).
- For ordered observations, overlapping labels/windows, point-in-time finance data, or temporal backtests, read [time series](references/time-series.md).

Use only references relevant to the task and confirm guidance against the installed library/version. Do not add a framework or download datasets/models just because a reference mentions one.

## Boundaries and resources

Use `$team-dev` and its assigned Tester/Reviewer when implementing repository behavior. The scientist may perform approved read-only analysis/querying or data extraction and self-check research code and metrics, but does not own independent project acceptance, business authorization, or trade decisions. Route material production schema, transaction, query-optimization and data-repair work to `team-database-specialist`; route application LLM prompts/context/tools/workflow and product model-call behavior to `team-ai-engineer`. The scientist still owns assigned traditional/deep-learning prototype training and inference evaluation.

Before compute-heavy or externally sourced work, agree a bounded resource plan: data/model source and license, permitted location, expected CPU/GPU, memory, storage, runtime and cost; checkpoint/resume and cancellation conditions; artifact and cleanup policy. Stop at the bound, preserve reproducible artifacts as approved, and report unavailable resources or negative findings. Never automatically incur GPU/cloud spend, download data/models, or start long training. Use project artifact rules; do not add broad ignore rules for research data/checkpoints.

## Output contract

Report the question and intended population, data provenance, assumptions and transformations, split/holdout design, baseline and experiment settings, metrics with uncertainty, negative findings, resource/artifact outcome and generalization limits. Distinguish observed analysis from causality or business effectiveness. Prototype metrics are evidence, not independent acceptance or deployment/trading authorization.

For implementation lifecycle, testing and review responsibilities, follow the shared [execution contract](../team-core/references/execution-contract.md) and the Lead's `$team-dev` Work/stage packet. Model performance experiments complement, but do not replace, software tests of deterministic transformations, splits, serialization and inference contracts.
