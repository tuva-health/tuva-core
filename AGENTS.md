# Tuva Core Agent Operating Manual

Read and follow this file before changing Tuva Core, including from a linked
worktree. It is the repository-local source of truth for ownership, safety,
validation, CI, and release rules.

## Tuva Core 1.0 Contract

- The repository is `tuva-health/tuva-core`.
- The dbt project name remains `the_tuva_project` for package compatibility.
- `dbt_project.yml` declares version `1.0.0` and requires dbt 1.10.5 through
  2.x. The complete 1.0 package ecosystem is validated against dbt Core 2.0
  and dbt Fusion on DuckDB.
- Repository `main` is the active integration line. A version on `main` is not
  a formal release by itself. A release also requires an immutable `v<version>`
  tag and a GitHub release.
- Treat published model schemas, grains, identifiers, variables, selectors,
  and stable Data Quality interfaces as public contracts. Assume a change is
  breaking unless compatibility is demonstrated.
- Use `v0.18.0` only as the frozen pre-1.0 parity baseline. Never use a mutable
  branch as a release comparison baseline.

## Repository Boundaries

Tuva Core owns the common transformation path:

- Input Layer contracts in `models/input_layer`.
- Standardization and terminology normalization in `models/normalized_layer`.
- Service categories, encounters, member months, claims enrollment, and
  provider attribution in `models/claims_preprocessing`.
- Public common-model outputs in `models/core`.
- Opt-in Structural Data Quality and Logical Data Quality models in
  `models/data_quality`.
- Package metadata in `models/metadata`.
- The opt-in parity metric producer in `models/parity`.
- Core-owned seed headers and loader macros in `seeds` and `macros`.

Tuva Core does not own optional marts or extensions. The accepted 1.0
standalone packages are:

- `ahrq_quality_indicators`
- `ccsr`
- `cms_chronic_conditions`
- `cms_hcc`
- `fhir_preprocessing`
- `nyu_ed_classification`
- `quality_measures`
- `semantic_layer` in repository `semantic-layer`

Installing a standalone package is its package-level enablement. Each package
owns its models, tests, data assets, documentation, compatibility, and release
lifecycle. Do not move optional-package code back into Core.

Related repositories have distinct ownership:

- `docs` owns the public documentation site, data dictionaries, and migration
  guidance. During local development it reads this checkout through
  `TUVA_CORE_PATH`.
- `dag-viewer` owns the lineage application and also reads the selected Core
  checkout through `TUVA_CORE_PATH`.
- `tuva-maintenance` owns data-asset source recipes, deterministic staging,
  publication, mirroring, verification, synthetic-data generation, and other
  maintainer-only utilities.
- Each connector owns its source-to-Input-Layer mappings.

Core still owns checked-in seed headers, runtime loader macros, and changes to
those package contracts. Cloud manifests own payload inventory and source
provenance. Route publisher, recipe, mirror, and maintenance-tool changes to
the maintenance tooling; do not put those concerns in the dbt package.

## Architecture And Public-Contract Rules

- Input Layer models are refs supplied by the parent connector project. The
  package-owned wrappers carry the Tuva contract metadata.
- The Normalized Layer is the standardization boundary before Claims
  Preprocessing and Core. Do not duplicate normalization downstream without a
  demonstrated need.
- Claims are source-scoped. Preserve `data_source` in claim-line identities,
  joins, partitions, grouping, attribution, and deduplication.
- Retain populated medical-claim diagnoses independently of claim
  classification. Put classification-dependent filters at the grouping
  algorithm that requires them, not in the canonical diagnosis relation.
- Claims-derived encounter IDs and public condition IDs use the established
  deterministic, collision-safe 32-character lowercase hash contracts. Do not
  reintroduce dataset-relative, delimiter-ambiguous, or literal-null-ambiguous
  identifiers.
- Clinical encounter groups come from the canonical encounter-type
  terminology. Do not restore a separate hard-coded `clinical` group.
- Open eligibility spans use a nullable `enrollment_end_date`; do not cap them
  at `tuva_last_run`.
- Appointment `type`, `status`, `reason`, and `cancellation_reason` remain
  source-native descriptive fields. Do not recreate unsupported normalized
  appointment vocabularies.
- Core `location` has public grain `(location_id, data_source)`, and Core
  `practitioner` has public grain `(practitioner_id, data_source)`. Claims rows
  retain their source. Clinical rows win only when the exact composite key
  matches; never collapse provider identifiers globally across sources.

Public Input Layer, Normalized Layer, Claims Preprocessing, Core, and
standalone-package fields ending in `_flag` are nullable binary integers:

- `1` means true or present.
- `0` means false or absent.
- null means unknown or not applicable according to the field description.

Reserve `_flag` for binary fields and use `_code` or `_status` for categorical
values. Cast public flags with `{{ dbt.type_int() }}`. Internal working flags,
Logical Data Quality result flags, and data-asset attributes are outside this
public-model contract.

## Extension Columns

Use **extension column** as the public term. Extension columns flow only
between these same-named Input Layer and Core table pairs:

- appointment
- condition
- eligibility
- encounter
- immunization
- lab_result
- location
- medical_claim
- medication
- observation
- patient
- pharmacy_claim
- practitioner
- procedure

For Core tables that combine clinical and claims-derived rows, only matching
clinical Input Layer extensions flow through. Those columns are null on
claims-derived rows. Core patient receives extensions only from
`input_layer__patient`; never copy eligibility extensions into patient.

Do not propagate extension columns into derived outputs without a same-named
Input Layer table. This excludes `cost`, `member_month`,
`person_id_crosswalk`, and `utilization`. Input Layer
`provider_attribution` is also outside the contract because it has no
same-named Core output.

Preserve the configured `passthrough.prefix` through intermediate and
Normalized relations. The final supported Core output strips it exactly once
when `passthrough.strip: true` and preserves it when false. Invalid
configuration, empty output names, and output-name collisions must fail
clearly.

## Feature Variables And CodeRx

The boolean variables below must be native, unquoted YAML booleans:

- `claims_enabled`
- `clinical_enabled`
- `provider_attribution_enabled`
- `parity_enabled`
- `data_quality_enabled`
- `enable_data_quality_failure_keys`
- `use_coderx_enterprise`

Quoted `"true"` and `"false"` values are strings and are rejected. Direct
`env_var()` expressions also return strings. Environment-driven workflows must
generate typed YAML or JSON before invoking dbt. In model configuration and
SQL, use the existing `tuva_boolean_var` package macro rather than ad hoc
coercion.

Keep `integration_tests/dbt_project.yml` as the canonical commented inventory
of every public, integration-only, warehouse-specific, and internal Core dbt
variable. Keep standalone-package variables in their separate section. The
CI-wired `tests/unit/test_dbt_var_inventory.py` contract must stay aligned with
new, renamed, or removed Core variable lookups.

CodeRx Open is the default medication terminology. When
`use_coderx_enterprise: true`, every CodeRx consumer reads user-managed
`packages`, `drugs`, and `classes` relations from the target database's
`coderx` schema. Keep that switch consistent across claims and clinical paths.

## Data Quality

- Data Quality is disabled by default.
- Organize the framework around **Structural Data Quality** and **Logical Data
  Quality**. Do not group these check families beneath another public layer or
  add downstream output rollups without a separately accepted design. Do not
  use `DQI` branding in this package; DQI is a Tuva Enterprise product.
- Logical row-level flags are tri-state: failure, pass, or not applicable.
  Preserve applicability rather than coercing unknown checks to pass.
- The stable Structural Data Quality relations are:
  - `data_quality.structural`
  - `data_quality.structural_test_results`
  - `data_quality.structural_missing_columns`
  - `data_quality.structural_data_type_mismatches`
  - `data_quality.structural_primary_key_failure_counts`
- The stable Logical Data Quality relations are:
  - `data_quality.logical_test_catalog`
  - `data_quality.logical_test_input_columns`
  - `data_quality.logical_test_results`
  - `data_quality.logical_failure_keys` when explicitly enabled
- Other materialized helpers, flag relations, and macros are implementation
  details rather than stable consumer contracts.
- The supported selectors are `data_quality`, `dq_structural`, and
  `dq_logical`.
- Parity is separate from Data Quality and remains a release comparison tool.

## Data Assets And Seeds

- Every asset-bearing package owns one namespaced data-asset-version variable.
  Package code and data-asset versions are intentionally independent and are
  coordinated manually. Do not add separate terminology, value-set,
  provider-data, or synthetic-data version variables.
- Core uses `tuva_core_data_asset_version`, defaulting to `1.0.0`, directly in
  `tuva-core/<data-asset-version>/`.
- Checked-in package seed CSVs are header-only dbt loader contracts. Published
  object-storage payloads are the released data contents.
- Keep seed relation contracts, column types, tests, aliases, tags, and loader
  hooks in the package. Do not duplicate payload inventory or structured
  source provenance in the package; those belong in the cloud manifest.
- S3 is the public source; GCS and Azure mirror the same versioned paths.
- dbt loaders read only the configured path. They do not read `_manifest.json`,
  `_release.json`, or candidate/released status, and package releases do not
  bind code commits to asset receipts.
- Candidate cloud folders may be edited during release preparation. Released
  folders are normally immutable; cloud maintenance may override that lock
  only when Aaron explicitly authorizes a break-glass change for the exact
  package and asset version and supplies a reason. Record the authorization,
  scope, reason, and resulting file changes in the maintenance audit output.
- Redshift loading uses `IAM_ROLE default`; never reintroduce embedded
  long-lived cloud credentials into package loaders or CI configuration.
- Data asset changes must preserve cross-warehouse loading behavior.
- Do not modify `integration_tests/seeds/*` without explicit user approval.
  The integration project intentionally has no local seed directory in 1.0.
- If a change requires synthetic columns or rows, obtain explicit generation
  requirements before changing synthetic data.
- Top-level `seeds/*` changes are allowed when requested, but validate them
  through `integration_tests` before a PR.

## Testing Framework

Tuva Core uses three dbt-native behavioral test categories:

- Unit tests are YAML files next to the models they protect. Use controlled
  inputs and exact expected rows for deterministic model logic.
- Data tests are generic tests in model YAML or singular SQL tests under
  `tests/`. Use them for built-relation grains, keys, relationships, accepted
  values, and cross-model invariants.
- Parity tests are opt-in metric-producing models under `models/parity`. Use
  them for analytical comparison against an immutable prior version.

“Regression” describes why a unit or data test exists; it is not a fourth test
type. For a confirmed logic bug, add the smallest deterministic dbt test that
fails before the fix and passes after it.

Use `dbt build` for normal validation because it runs unit tests, materializes
models, and then runs data tests in DAG order. `dbt run` does not execute unit
or data tests.

Do not add a parallel Python framework for dbt model behavior. Python contract
tests are appropriate only for repository automation or file-level contracts;
keep them narrowly scoped and deliberately wire or document how they run.

Parity metric IDs are immutable zero-padded strings. Never renumber, reuse, or
redefine an existing ID; append a new ID for a new calculation.

## Mandatory Local Workflow

- Run dbt from the `integration_tests` project through `scripts/dbt-local`.
  This is the one Core-local development helper and remains in this repository.
- Use profiles from `~/.dbt` or `DBT_PROFILES_DIR`. Treat any
  `integration_tests/profiles/*` files and `.github/workflows/*` as CI
  configuration, not local runbooks.
- For routine Core work, use `TUVA_DBT_PROFILE=snowflake-dev` against the
  existing `dev_aaron` database and reuse its loaded data assets.
- Do not run `dbt seed`, select seed nodes, or use an unscoped full-project
  build when seed definitions, versions, schemas, and loading logic are
  unchanged. Reload seeds only when those inputs changed or the user explicitly
  requests it.
- Keep `integration_tests/dbt_project.yml` on `profile: default` before
  pushing.
- Use the integration defaults unless the task requires otherwise:
  - `synthetic_data_size: small`
  - `parity_enabled: false`
  - `data_quality_enabled: false`
- Use local DuckDB for DuckDB-specific portability checks or work that does
  not need the large published data assets.
- Never merge to `main` without Aaron's explicit approval.

Standard commands from the repository root:

```bash
scripts/dbt-local deps
scripts/dbt-local debug
# dbt Core v1
scripts/dbt-local parse --no-partial-parse
# dbt Core v2 or dbt Fusion
scripts/dbt-local parse
TUVA_DBT_PROFILE=snowflake-dev scripts/dbt-local build \
  --select <selector> \
  --exclude resource_type:seed
```

For a broader pre-PR build with unchanged seeds:

```bash
TUVA_DBT_PROFILE=snowflake-dev scripts/dbt-local build --full-refresh \
  --select package:integration_tests package:the_tuva_project \
  --exclude resource_type:seed
```

`dbt seed`, `dbt run`, and `dbt build` may require internet access because
package data assets load from public object storage.

## Validation By Change Type

- Core model, macro, test, or YAML changes:
  - Run `scripts/dbt-local deps` when dependencies may have changed.
  - Run `scripts/dbt-local parse --no-partial-parse` with dbt Core v1, or
    `scripts/dbt-local parse` with dbt Core v2 or dbt Fusion.
  - Run the narrowest useful Snowflake `dbt build`, excluding unchanged seeds.
  - Run the broader full-refresh build before a PR when feasible.
- Core asset manifest, seed header, or loader changes:
  - Validate the Core package contract in this repository.
  - Run an appropriate seed refresh and at least one DuckDB seed smoke test.
  - Preserve cross-warehouse loader behavior.
- Publisher, source-recipe, mirror, or asset-maintenance tooling changes:
  - Work in `tuva-maintenance` and run its Python tests and DuckDB package smoke
    validation.
- Workflow changes:
  - Run `actionlint` and any explicitly wired workflow contract tests.
  - Review permissions, untrusted-code boundaries, immutable refs, and secret
    exposure.
- Documentation-only and repository-hygiene changes:
  - Run `git diff --check` and verify changed local and external links.
  - Do not run dbt solely because prose or empty-path declarations changed.
- Docs site changes:
  - Work in `docs`.
  - Run `npm ci`, then
    `TUVA_CORE_PATH=/absolute/path/to/tuva-core npm run build`.
- DAG Viewer changes:
  - Work in `dag-viewer`.
  - Run `npm ci`, then
    `TUVA_CORE_PATH=/absolute/path/to/tuva-core npm run build`.
  - Use `npm run build:local` only when the Core checkout is literally the
    sibling path `../tuva-core`, because that script sets the path itself.
- Standalone package changes:
  - Work in the owning package repository and validate it against the intended
    immutable or local Core ref.

## Generated And Local Artifacts

Do not commit:

- `target/`
- `dbt_packages/`
- `logs/`
- local DuckDB database files
- docs or DAG Viewer build output
- `node_modules/`
- temporary scratch folders

Preserve unrelated user changes in a dirty worktree. Do not delete generated
or local files outside the task's explicit scope.

## SQL Portability

Tuva Core supports:

- Snowflake
- Databricks
- BigQuery
- Microsoft Fabric
- Redshift
- DuckDB

Write general-purpose SQL, prefer existing Tuva macros and package patterns,
and isolate genuinely warehouse-specific behavior behind dispatched macros. A
passing build on one warehouse is not evidence of portability to the others.

Logical Data Quality depends on case-sensitive string comparison. SQL Server
targets therefore require a case-sensitive database collation such as
`SQL_Latin1_General_CP1_CS_AS`; the engine default
`SQL_Latin1_General_CP1_CI_AS` makes those checks pass silently on values they
should flag. Do not work around this by lowercasing the compared values, which
would erase the case contract the checks exist to enforce.

## GitHub And Pull Requests

- Create Tuva Core issues in `tuva-health/tuva-core`.
- Apply exactly one release-note disposition to each issue and PR:
  - `breaking-change`
  - `enhancement`
  - `bug`
  - `docs`
  - `terminology`
  - `connector`
  - `ignore-for-release`
- PR bodies must summarize the change, validation, release-note disposition,
  and linked issue when applicable. Mirror the issue label onto the PR.
- Leave merge to the user.

## CI And Releases

- Same-repository pull requests automatically run `Tuva CI -- Snowflake`: one
  fixed Snowflake `dbt build --full-refresh` against the small synthetic
  dataset. It builds this PR's local Tuva Core, the integration project, and all
  eight standalone packages pinned to Git release tags in
  `integration_tests/packages.yml`. It runs unit and data tests, enables Data
  Quality and its optional failure-key relation, and keeps
  parity disabled. A package-version change does not alter this automatic path.
  The Snowflake status is informational and is not required for merge.
- Snowflake CI uses key-pair authentication. The workflows read
  `DBT_SNOWFLAKE_CI_ACCOUNT`, `DBT_SNOWFLAKE_CI_USER`, `DBT_SNOWFLAKE_CI_ROLE`,
  `DBT_SNOWFLAKE_CI_WAREHOUSE`, `DBT_SNOWFLAKE_CI_DATABASE`,
  `DBT_SNOWFLAKE_CI_SCHEMA`, and `DBT_SNOWFLAKE_CI_PRIVATE_KEY`. The private
  key secret is an unencrypted PKCS8 PEM. The Snowflake job writes that PEM
  to a temporary file and sets `private_key_path` on the CI profile. Do not
  reintroduce `DBT_SNOWFLAKE_CI_PASSWORD`.
- Run `Tuva CI -- All Warehouses` manually for the final release PR. Its only
  input is the pull-request number. It accepts any open, mergeable,
  same-repository PR into `main`; CI does not inspect or compare package
  versions.
- The all-warehouse workflow resolves the PR test merge and all eight
  standalone package `main` branches once to exact commits. It builds that one
  source lock on Snowflake, BigQuery, Databricks, Fabric, and Redshift with the
  small synthetic dataset and complete Data Quality surface.
- Version selection and comparison, data-asset publication, tagging, and
  draft-release creation do not belong to CI.
- There is no individual-warehouse dispatcher. Troubleshoot one warehouse
  locally; validate DuckDB portability locally as needed.
- Pull-request comments do not trigger CI, and CI does not accept arbitrary
  dbt commands, selectors, or flags.
- Automatic secrets-backed CI never executes fork code. After review, a
  maintainer runs `External PR Snowflake CI` and supplies only the PR number.
  That workflow uses the same checked-in package tags and does not choose or
  compare Core release versions or perform release operations.
- Routine Snowflake CI installs and builds all eight standalone packages from
  the checked-in Git release tags. It verifies installed versions and commit
  locks and requires successful model results from every package. The manifest,
  run results, dependency lock, and package evidence are retained as artifacts.
  Manual all-warehouse CI independently snapshots all eight package `main`
  branches before building; it does not use the checked-in release tags.
- Parity comparison is a separate manually initiated Snowflake release
  validation.

For a release, finish ordinary implementation first, then open the small
manual PR that changes the Core package version declarations. Snowflake starts
automatically and may be canceled because it is not a merge gate. Manually run
`Tuva CI -- All Warehouses` for that PR, merge only after the matrix passes,
then create the tag and open the draft release. Data-asset versions and cloud
release status are coordinated independently through their own manifests.

Two similarly named release files have different required jobs:

- `.github/workflows/create-release.yml` is the executable GitHub Actions
  workflow. It validates current `main`, creates the package tag, and opens a
  draft GitHub release. It does not inspect or modify data assets.
- `.github/release.yml` is not a workflow. GitHub reads it to categorize
  automatically generated release notes by label.

Keep both. Do not create another `.github/workflows/release.yml`, and do not
edit release automation unless the task explicitly targets it.

## Task Handoff

For every task, report:

- What changed and why.
- Validation commands and key outcomes.
- Issue and PR URLs when created.
- Branch and worktree path when relevant.
- CI commands or check status when run.
- Blockers, assumptions, and user decisions still required.
