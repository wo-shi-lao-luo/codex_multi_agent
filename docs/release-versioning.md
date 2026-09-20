# Release versioning

This kit uses semantic version syntax, but release-number decisions follow the product policy below.

## Third number: focused extensions and fixes

Increment the third number for fixes, documentation, tooling, and additions that extend an existing feature without introducing a major new capability. Example: `0.3.0` to `0.3.1` for adding stage-level test and acceptance support to the existing workflow harness.

## Second number: major capability or broad workflow change

Increment the second number for a large new feature or a substantial restructuring of existing behavior. Examples include a new durable workflow family, a materially different execution model, or an extensive compatibility-affecting redesign.

## First number: explicit product-release decision

Increment the first number only when the maintainer explicitly declares a formal stable release or intentionally begins a new major product line. Do not promote the first number merely because several small changes have accumulated. Planned prerelease work uses the intended line with a suffix such as `1.1.0-alpha.1` or `1.1.0-beta.1` after that decision.

## Before releasing

1. State the intended version and why its number changes at that level.
2. Update `VERSION`, `CHANGELOG.md`, and the current-release reference in `README.md` together.
3. Run validation and the relevant isolated tests.
4. Update the local installed kit only after the source checks pass.
5. Commit and push only the verified source state.
