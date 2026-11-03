# Time-series and point-in-time evaluation

Use for ordered observations, forecasting, temporal classification, event windows or financial research where information availability changes over time.

## Preserve causal order

Define the prediction timestamp, label horizon, feature availability timestamp, publication/ingestion delay and evaluation period. A feature is valid only if it was actually available by the prediction time. Use point-in-time source versions and universe membership where applicable; disclose survivorship, revision, look-ahead and selection risks. For financial data, include corporate actions, delisted assets, fees, slippage and execution timing only when needed for the stated research question. A backtest or score is not trade authorization or a recommendation.

Choose a chronological split that matches the intended prediction and deployment population. For new-entity generalization, hold out the relevant entity groups; for per-entity future forecasting, training may include earlier observations of the same entities. Historical lag/rolling feature windows may legitimately share observations across a cutoff when each value was available at prediction time. Purge overlapping labels or add a gap/embargo only when the target horizon, label construction, delayed availability or other dependency can leak information across the boundary. Fit transforms and select features/models using past training folds only. Reserve a later untouched period for final reporting; repeated inspection makes that period part of model selection.

`TimeSeriesSplit` in scikit-learn uses expanding training windows and has a `gap` option, but its comparable-duration interpretation assumes equally spaced samples. Check that its assumptions fit the observed cadence; irregular times, groups, overlapping labels and point-in-time availability may require a custom splitter and explicit tests. See the [official TimeSeriesSplit reference](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.TimeSeriesSplit.html) and verify the installed version.

## Report the evaluation design

Record cutoffs, periods, gap/embargo, group boundaries, feature vintages, sample counts and excluded windows. Compare a simple baseline using the same split. Report variability across folds or periods and failure/negative results; avoid presenting one favorable window as general evidence. For financial evaluation, distinguish predictive metrics from portfolio/backtest assumptions and report those assumptions separately.
