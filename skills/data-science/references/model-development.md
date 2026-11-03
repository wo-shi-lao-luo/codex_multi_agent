# Model development and evaluation

Use when designing, training, comparing, exporting or serving a research prototype. Adapt to the actual framework and target use; no framework is required by this Skill.

## Build comparable evidence

Define the target, prediction unit, metric and useful baseline before tuning. Choose metrics that reflect class imbalance, decision costs and uncertainty; include a simple baseline and, where useful, calibration or subgroup/error analysis. Distinguish descriptive association from predictive performance, causal claims and business effectiveness: observational correlation or a favorable backtest alone establishes neither causation nor future effectiveness. When many features, variants, seeds or periods were tried, report selection and multiple-comparison uncertainty when material. Record data version, split IDs/rules, preprocessing, features, model/configuration, seeds, library/hardware versions, compute bounds and every attempted result, including failed and negative runs.

Separate train, validation and final holdout before fitting or selecting. Fit all learned transforms and feature selection inside the training fold; tune only with training/validation evidence. Keep the holdout untouched until the final evaluation and do not use it to choose architecture, threshold, features, checkpoint, seed or report wording. If the holdout has been repeatedly inspected or influenced decisions, disclose that and treat it as validation evidence; obtain a fresh holdout for an unbiased final estimate when feasible. Scikit-learn's [common pitfalls guide](https://scikit-learn.org/stable/common_pitfalls.html) explains preprocessing leakage and why test data must not guide model selection; use equivalent safeguards in other frameworks.

Choose splits to match the intended deployment population and prediction task. Hold entities out when the evaluation is meant to estimate generalization to new people, devices, sites or sources. For per-entity future forecasting, the same entity may correctly occur in past training and future evaluation periods. Use chronological splits when prediction is forward in time. Account for label horizons and unavailable information; add purge/embargo gaps only where the target horizon, label construction or data availability creates leakage. Historical feature windows may legitimately overlap when every value was available at the prediction time. A split function alone cannot establish causal validity. Read [time-series guidance](time-series.md) for ordered data.

## Traditional ML and deep learning

For traditional ML, establish a simple rule or statistical baseline and a simple interpretable model before adding complexity. Track the exact preprocessing/model pipeline and compare like-for-like splits and metrics.

For deep learning, first verify a small deterministic data path and a small model/training run. Specify the architecture, initialization, optimizer, schedule, batch size, loss, stopping rule and checkpoint selection. Set seeds and control relevant nondeterminism, but do not claim exact reproducibility across library versions, hardware or platforms based on a seed alone. PyTorch documents these limits in its [reproducibility note](https://docs.pytorch.org/docs/stable/notes/randomness.html); consult the installed-version documentation when using PyTorch. Benchmark resource needs before scaling.

When using a tensor framework, verify input/target shapes, dtypes, device, label encoding and loss semantics before scaling; check that loss and key metrics remain finite and stop to diagnose non-finite values. Keep optimizer updates in training mode and validation/inference in the appropriate evaluation mode without gradient updates or learned-state mutation. Follow the [official PyTorch optimization walkthrough](https://docs.pytorch.org/tutorials/beginner/basics/optimization_tutorial.html) only when PyTorch is the chosen framework, and check it against the installed version.

For resumable runs, checkpoint at a declared cadence and include the model state plus relevant optimizer/scheduler state, epoch/step, configuration, data/split identity and random-number-generator state where the framework supports it. Record limitations when exact resume cannot be reproduced. PyTorch's [saving and loading models guide](https://docs.pytorch.org/tutorials/beginner/saving_loading_models.html) describes its state-dictionary approach; it is not a mandate to use PyTorch or to load untrusted artifacts.

## Export and inference prototype

Treat the model and every fitted preprocessing step as one versioned artifact. Record format, framework/runtime version, input schema, units/order, missing-value policy, output meaning, thresholds and known limits. Test deterministic transforms, split construction, serialization round-trip and inference input/output contracts with small fixtures. Never load an untrusted serialized model artifact; use an approved source and format, inspect provenance and follow the framework's security guidance. A successful local inference prototype does not establish production reliability, business acceptance or deployment readiness.

Compare exported inference with the evaluated model through the same preprocessing and representative inputs. Declare a task-appropriate numeric tolerance and check output shape, ordering and finite values; an export-format round trip is useful evidence, not proof of production parity.

## Resource and artifact boundary

Before long or accelerated training, agree CPU/GPU, memory, runtime, storage and cost limits; cancellation conditions; checkpoint cadence/resume rules; and where approved artifacts belong. Do not automatically purchase cloud compute, download weights/data, or start long training. Save only agreed outputs, retain enough metadata to reproduce the result, and clean up only within explicitly assigned scope.
