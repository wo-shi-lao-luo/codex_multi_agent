# Data preparation and lineage

Use this reference when a task needs dataset profiling, cleaning, joining, feature transforms or derived-data provenance. Choose methods that preserve the meaning of the observations; this is not a pandas-specific workflow.

## Profile before changing data

Record the source/version and permitted use, dataset grain, row and column counts, key uniqueness, types/units, time zone and interval, missingness, duplicate patterns, ranges, category levels and target distribution. For multiple sources, inspect key overlap and unmatched rows. Verify the post-join row count and cardinality against expectations; many-to-many joins can multiply observations and inner joins can drop unmatched rows. pandas documents join-cardinality validation and merge indicators in its [merge guide](https://pandas.pydata.org/docs/user_guide/merging.html). Use equivalent checks in the selected tool.

Do not infer that a missing value means zero, that a repeated key is redundant, or that an extreme value is an error. Preserve the raw source. Present ambiguous cases and plausible interpretations; use an explicit, reversible policy only after the task owner resolves the meaning or authorizes a documented assumption. Report row counts and representative examples before and after every exclusion or deduplication.

## Transform with lineage

Keep transformations deterministic where practical and record code revision, source identifiers or hashes when permitted, parameters, tool/library versions, random seeds, timezone/unit conventions, and row/feature counts. Preserve a mapping from each derived dataset to its source and transformation. Avoid copying sensitive raw data into logs or artifacts; follow the data owner's access and retention rules.

Fit imputers, encoders, scalers, feature selection and other learned transforms on training data only, then apply the fitted transform unchanged to validation, test and inference data. Prefer a pipeline or equivalent shared transform contract. Never use future or held-out information to construct features. For ordered or event data, use the temporal reference before choosing an as-of rule or cutoff.

## Source

- pandas, [Merge, join, concatenate and compare](https://pandas.pydata.org/docs/user_guide/merging.html): cardinality validation and row-origin indicators. Check the installed pandas version; the guide is a library-specific reference, not a dependency requirement.
- scikit-learn, [Common pitfalls and recommended practices](https://scikit-learn.org/stable/common_pitfalls.html): inconsistent preprocessing and leakage controls. Consult when using scikit-learn and verify against the installed version.
