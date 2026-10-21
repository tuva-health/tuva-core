#!/usr/bin/env python3

import csv
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
FAMILY_FOLDERS = {
    "terminology": "terminology",
    "provider_data": "provider-data",
    "value_sets": "value-sets",
}

TERMINOLOGY_LIFECYCLE_HEADERS = {
    "terminology__apr_drg.csv": [
        "apr_drg_code", "medical_surgical", "mdc_code",
        "apr_drg_description", "deprecated",
    ],
    "terminology__cvx.csv": [
        "cvx", "short_description", "long_description", "status",
        "last_updated", "deprecated",
    ],
    "terminology__fips_county.csv": [
        "fips_code", "county", "state", "deprecated",
    ],
    "terminology__hcpcs_level_2.csv": [
        "hcpcs", "seqnum", "recid", "long_description",
        "short_description", "deprecated",
    ],
    "terminology__icd10_pcs_cms_ontology.csv": [
        "icd10pcs_code", "section", "body_system", "operation",
        "body_part", "approach", "device", "qualifier", "deprecated",
    ],
    "terminology__icd_10_cm.csv": [
        "icd_10_cm", "billable_code_flag", "short_description",
        "long_description", "deprecated",
    ],
    "terminology__icd_10_pcs.csv": [
        "icd_10_pcs", "description", "deprecated",
    ],
    "terminology__icd_9_cm.csv": [
        "icd_9_cm", "long_description", "short_description", "deprecated",
    ],
    "terminology__icd_9_pcs.csv": [
        "icd_9_pcs", "long_description", "short_description", "deprecated",
    ],
    "terminology__loinc.csv": [
        "loinc", "short_name", "long_common_name", "component", "property",
        "time_aspect", "system", "scale_type", "method_type", "class_code",
        "class_description", "class_type_code", "class_type_description",
        "paneltype", "order_obs", "example_units",
        "external_copyright_notice", "status", "version_first_released",
        "version_last_changed", "deprecated",
    ],
    "terminology__medicare_dual_eligibility.csv": [
        "dual_status_code", "dual_status_description", "deprecated",
    ],
    "terminology__snomed_ct.csv": [
        "snomed_ct", "description", "is_active", "created", "last_updated",
        "deprecated",
    ],
    "terminology__restructured_betos.csv": [
        "hcpcs_cd", "rbcs_id", "rbcs_cat", "rbcs_cat_desc",
        "rbcs_cat_subcat", "rbcs_subcat_desc", "rbcs_famnumb",
        "rbcs_family_desc", "rbcs_major_ind", "hcpcs_cd_add_dt",
        "hcpcs_cd_end_dt", "rbcs_latest_assignment", "first_rbcs_release_year",
        "rbcs_analysis_start_dt", "rbcs_analysis_end_dt",
        "alt_assignment_method", "rbcs_id_ever_reassigned",
    ],
}

SNOMED_RELATIONSHIP_HEADERS = {
    "terminology__snomed_ct_transitive_closures.csv": [
        "parent_snomed_code", "parent_description", "child_snomed_code",
        "child_description",
    ],
    "terminology__snomed_icd_10_map.csv": [
        "id", "effective_time", "active", "module_id", "ref_set_id",
        "referenced_component_id", "referenced_component_name", "map_group",
        "map_priority", "map_rule", "map_advice", "map_target",
        "map_target_name", "correlation_id", "map_category_id",
        "map_category_name",
    ],
}

SSA_FIPS_STATE_COUNTY_CROSSWALK_HEADER = [
    "fipscounty",
    "countyname_fips",
    "state",
    "cbsa_code",
    "cbsa_name",
    "ssa_code",
    "state_name",
    "countyname_rate",
]


def parse_seed_hooks():
    hooks = {}
    for family in (*FAMILY_FOLDERS, "synthetic_data"):
        for yaml_path in sorted((ROOT / "seeds" / family).rglob("*.yml")):
            seed_name = None
            for line in yaml_path.read_text().splitlines():
                name_match = re.match(r"^  - name: (\S+)$", line)
                if name_match:
                    seed_name = name_match.group(1)
                    continue

                regular_match = re.search(
                    r"load_versioned_seed\('([^']+)','([^']+)'\)", line
                )
                if regular_match:
                    hooks[seed_name] = (
                        regular_match.group(1),
                        regular_match.group(2),
                    )

                synthetic_match = re.search(
                    r"load_versioned_synthetic_seed\('([^']+)'\)", line
                )
                if synthetic_match:
                    hooks[seed_name] = ("synthetic_data", synthetic_match.group(1))
    return hooks


def seed_definition(yaml_text, seed_name):
    match = re.search(
        rf"(?ms)^  - name: {re.escape(seed_name)}\n.*?(?=^  - name: |\Z)",
        yaml_text,
    )
    if match is None:
        raise AssertionError(f"Missing seed definition: {seed_name}")
    return match.group(0)


class DataAssetContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.hooks = parse_seed_hooks()

    def test_every_seed_has_one_loader_hook_and_header_only_contract(self):
        self.assertEqual(len(self.hooks), 86)

        for seed_name, (family, object_name) in self.hooks.items():
            if family == "synthetic_data":
                self.assertEqual(object_name, seed_name)
            else:
                self.assertEqual(object_name, f"{seed_name}.csv.gz")

            header_files = list((ROOT / "seeds").rglob(f"{seed_name}.csv"))
            self.assertEqual(len(header_files), 1, seed_name)
            with header_files[0].open(encoding="utf-8-sig", newline="") as handle:
                rows = csv.reader(handle)
                header = next(rows, [])
                self.assertTrue(header, seed_name)
                self.assertTrue(all(header), seed_name)
                self.assertIsNone(next(rows, None), seed_name)

    def test_grouper_primary_keys_reference_existing_columns(self):
        for family in ("condition", "procedure"):
            folder = ROOT / "seeds" / "value_sets" / f"{family}_grouper"
            yaml_text = (folder / f"{family}_grouper_seeds.yml").read_text()
            for suffix in ("", "_code_map"):
                seed_name = f"tuva_{family}_grouper{suffix}"
                with self.subTest(seed=seed_name):
                    definition = seed_definition(yaml_text, seed_name)
                    keys_match = re.search(
                        r"(?m)^        primary_key_columns:\n((?:          - .+\n)+)",
                        definition,
                    )
                    self.assertIsNotNone(keys_match, seed_name)
                    keys = re.findall(r"(?m)^          - (\S+)$", keys_match.group(1))
                    with (folder / f"{seed_name}.csv").open(newline="") as handle:
                        header = next(csv.reader(handle))
                    self.assertTrue(set(keys).issubset(header), (seed_name, keys, header))

    def test_refreshed_terminology_headers_preserve_lifecycle_contract(self):
        seed_root = ROOT / "seeds" / "terminology"
        for filename, expected_header in TERMINOLOGY_LIFECYCLE_HEADERS.items():
            with self.subTest(filename=filename):
                with (seed_root / filename).open(
                    encoding="utf-8-sig", newline=""
                ) as handle:
                    self.assertEqual(next(csv.reader(handle)), expected_header)

    def test_ssa_fips_state_county_crosswalk_documents_header(self):
        seed_root = ROOT / "seeds" / "terminology"
        filename = "terminology__ssa_fips_state_county_crosswalk.csv"
        with (seed_root / filename).open(
            encoding="utf-8-sig", newline=""
        ) as handle:
            header = next(csv.reader(handle))
        self.assertEqual(header, SSA_FIPS_STATE_COUNTY_CROSSWALK_HEADER)

        yaml_text = (seed_root / "terminology_seeds.yml").read_text()
        definition = seed_definition(
            yaml_text, "terminology__ssa_fips_state_county_crosswalk"
        )
        documented = re.findall(
            r"(?m)^      - name: ([a-z0-9_]+)\n        description: .+$",
            definition,
        )
        self.assertEqual(documented, SSA_FIPS_STATE_COUNTY_CROSSWALK_HEADER)

    def test_hcpcs_long_description_supports_full_cms_source_text(self):
        yaml_text = (
            ROOT / "seeds" / "terminology" / "terminology_seeds.yml"
        ).read_text()
        definition = seed_definition(yaml_text, "terminology__hcpcs_level_2")
        self.assertIn("varchar(16777216)", definition)
        self.assertIn("varchar(max)", definition)
        self.assertIn("varchar(65535)", definition)
        self.assertNotIn("varchar(2000)", definition)

    def test_snomed_relationship_headers(self):
        seed_root = ROOT / "seeds" / "terminology"
        for filename, expected_header in SNOMED_RELATIONSHIP_HEADERS.items():
            with self.subTest(filename=filename):
                with (seed_root / filename).open(
                    encoding="utf-8-sig", newline=""
                ) as handle:
                    self.assertEqual(next(csv.reader(handle)), expected_header)

    def test_asset_version_is_explicit_and_independent_from_package_version(self):
        project_text = (ROOT / "dbt_project.yml").read_text()
        version_macro_path = (
            ROOT / "macros" / "system_utils" / "get_tuva_package_version.sql"
        )
        version_macro = version_macro_path.read_text()
        project_version_match = re.search(
            r"(?m)^version: '([1-9][0-9]*\.[0-9]+\.[0-9]+"
            r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)'$",
            project_text,
        )
        macro_version_match = re.search(
            r"return\('([1-9][0-9]*\.[0-9]+\.[0-9]+"
            r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)'\)",
            version_macro,
        )
        self.assertIsNotNone(project_version_match)
        self.assertIsNotNone(macro_version_match)
        self.assertEqual(project_version_match.group(1), macro_version_match.group(1))
        asset_version_match = re.search(
            r"(?m)^  tuva_core_data_asset_version: '([1-9][0-9]*\.[0-9]+\.[0-9]+)'$",
            project_text,
        )
        self.assertIsNotNone(asset_version_match)
        self.assertEqual(asset_version_match.group(1), "1.0.0")
        self.assertIn(
            'require-dbt-version: [">=1.10.5", "<3.0.0"]',
            project_text,
        )
        runtime_config_path = (
            ROOT / "macros" / "system_utils" / ("get_runtime_" + "config.sql")
        )
        self.assertFalse(runtime_config_path.exists())
        macro_text = "\n".join(
            path.read_text() for path in sorted((ROOT / "macros").rglob("*.sql"))
        )
        for forbidden_runtime_access in (
            "builtins." + "ref.config",
            "config." + "dependencies",
            "get_installed_" + "package_version",
        ):
            self.assertNotIn(forbidden_runtime_access, macro_text)

        release_workflow = (
            ROOT / ".github" / "workflows" / "create-release.yml"
        ).read_text()
        contract_command = "run: python3 tests/unit/test_data_asset_contract.py"
        self.assertEqual(release_workflow.count(contract_command), 1)
        self.assertLess(
            release_workflow.index("uses: actions/checkout@"),
            release_workflow.index(contract_command),
        )
        self.assertLess(
            release_workflow.index(contract_command),
            release_workflow.index("- name: Verify release commit is current main"),
        )

        self.assertFalse((ROOT / "data_assets.yml").exists())
        self.assertFalse((ROOT / "data_assets").exists())

        for yaml_path in (ROOT / "seeds").rglob("*.yml"):
            self.assertNotRegex(
                yaml_path.read_text(),
                r"(?m)^\s+data_asset:\s*$",
                str(yaml_path),
            )

    def test_loader_security_and_cross_cloud_contract(self):
        version_macro = (
            ROOT / "macros" / "system_utils" / "get_tuva_package_version.sql"
        ).read_text()
        path_macro = (
            ROOT / "macros" / "cross_database_utils" / "versioned_seed_paths.sql"
        ).read_text()
        load_macro = (
            ROOT / "macros" / "cross_database_utils" / "load_seed.sql"
        ).read_text()
        path_test = (
            ROOT / "tests" / "data_assets" / "test_package_seed_paths.sql"
        ).read_text()

        self.assertIn("macro get_tuva_package_version()", version_macro)
        self.assertNotIn("get_installed_" + "package_version", version_macro)
        self.assertIn(
            "macro load_package_seed(asset_root, asset_version, object_path",
            path_macro,
        )
        self.assertIn(
            "macro get_versioned_seed_uri(database)",
            path_macro,
        )
        self.assertIn(
            "macro load_versioned_seed(database, seed_object_name, compression=true",
            path_macro,
        )
        self.assertIn(
            "macro load_versioned_synthetic_seed(seed_name, compression=true",
            path_macro,
        )
        self.assertIn(
            "'tuva-core',\n      var('tuva_core_data_asset_version', '1.0.0')",
            path_macro,
        )
        self.assertIn("var('custom_bucket_name', 'tuva-public-resources')", path_macro)
        self.assertIn("data-marts/cms-hcc", path_test)
        self.assertIn("var('custom_bucket_name', 'tuva-public-resources')", path_test)
        self.assertNotIn("tuva_seed_buckets", path_macro)
        self.assertNotIn("get_tuva_package_version()", path_macro)

        self.assertIn("iam_role default", load_macro.lower())
        self.assertIn(
            "null as '__tuva_reserved_null_marker_1_0__'",
            load_macro.lower(),
        )
        self.assertIn("COMPRESSION = 'GZIP'", load_macro)
        self.assertIn("ROWTERMINATOR = '0x0A'", load_macro)
        self.assertIn("nullstr = ''", load_macro)
        self.assertNotIn("nullstr = ['',", load_macro)
        self.assertIn("escape_unenclosed_field = NONE", load_macro)
        self.assertIn("null_if = ('__TUVA_RESERVED_NULL_MARKER_1_0__')", load_macro)
        self.assertIn(
            "macro snowflake_seed_rows_loaded(column_names, data, uri, pattern)",
            load_macro,
        )
        self.assertIn(
            "normalized_column_names.index('rows_loaded')",
            load_macro,
        )
        self.assertIn(
            "Snowflake seed load processed no files from s3://",
            load_macro,
        )
        self.assertNotIn("sum(attribute=2)", load_macro)
        self.assertIn("null_markers = ['']", load_macro)
        self.assertNotIn("null_markers = ['', '\\\\N'", load_macro)
        self.assertIn("set null_char = ''", load_macro)
        self.assertIn("'escapeChar' = '\\0'", load_macro)
        self.assertIn("'nullValue' = ''", load_macro)
        self.assertNotIn("macro postgres__load_seed", load_macro)
        self.assertNotIn("null ''\\\\N''", load_macro)

        readme = (ROOT / "README.md").read_text()
        self.assertIn("Redshift loading uses `IAM_ROLE default`", readme)
        self.assertIn("`Content-Encoding: gzip`", readme)
        for forbidden in (
            "access_key_" + "part",
            "secret_key_" + "part",
            "full_access_" + "key",
            "full_secret_" + "key",
            "access_key_" + "id '{{",
            "secret_access_" + "key",
        ):
            self.assertNotIn(forbidden, load_macro)

    def test_bigquery_header_only_seed_materialization_contract(self):
        macro = (
            ROOT / "integration_tests" / "macros" / "bigquery_seed.sql"
        ).read_text()
        integration_project = (
            ROOT / "integration_tests" / "dbt_project.yml"
        ).read_text()

        self.assertIn(
            "macro bigquery_create_seed_relation(model, agate_table, relation)",
            macro,
        )
        self.assertIn("macro bigquery__create_csv_table(model, agate_table)", macro)
        self.assertIn(
            "macro bigquery__reset_csv_table(model, full_refresh, old_relation, agate_table)",
            macro,
        )
        self.assertIn("agate_table.rows | length == 0", macro)
        self.assertIn("for column_name in agate_table.column_names", macro)
        self.assertIn("column_types that exactly match its CSV header", macro)
        self.assertIn("api.Column.translate_type(column_type)", macro)
        self.assertIn("create or replace table {{ relation.render() }}", macro)
        self.assertIn("adapter.drop_relation(old_relation)", macro)
        self.assertNotIn("macro bigquery__load_csv_rows", macro)
        self.assertIn("macro_namespace: 'dbt'", integration_project)
        self.assertIn("search_order: ['integration_tests', 'dbt']", integration_project)

    def test_release_is_not_bound_to_data_asset_storage(self):
        workflow = (ROOT / ".github" / "workflows" / "create-release.yml").read_text()
        tag_step = workflow.index("- name: Create Tag")
        self.assertGreater(tag_step, workflow.index("- name: Check version change"))
        self.assertNotIn("data_assets.yml", workflow)
        self.assertNotIn("_release.json", workflow)
        self.assertNotIn("tuva-public-resources", workflow)
        self.assertNotIn("actions/checkout@v", workflow)
        self.assertNotIn("releases/latest", workflow)
        self.assertNotIn("action-gh-release@v", workflow)
        action_refs = re.findall(r"uses:\s+[^@\s]+@([^\s]+)", workflow)
        self.assertTrue(action_refs)
        for action_ref in action_refs:
            self.assertRegex(action_ref, r"^[0-9a-f]{40}$")

    def test_release_recovery_is_main_only_and_uses_current_main_commit(self):
        workflow = (ROOT / ".github" / "workflows" / "create-release.yml").read_text()
        self.assertIn("workflow_dispatch:", workflow)
        self.assertIn("concurrency:", workflow)
        self.assertIn('git show-ref --verify --quiet "refs/tags/${tag}"', workflow)
        self.assertIn("if: github.ref == 'refs/heads/main'", workflow)
        self.assertIn("git ls-remote origin refs/heads/main", workflow)
        self.assertEqual(
            workflow.count("git ls-remote origin refs/heads/main"), 2
        )
        self.assertIn('test "$actual" = "$GITHUB_SHA"', workflow)
        self.assertIn('test "$actual" = "$main"', workflow)
        self.assertIn(
            'os.environ.get("GITHUB_EVENT_NAME") == "workflow_dispatch"', workflow
        )
        self.assertIn("BEFORE_SHA: ${{ github.event.before }}", workflow)
        self.assertIn('f"{before_sha}:dbt_project.yml"', workflow)
        self.assertNotIn('"HEAD^:dbt_project.yml"', workflow)
        self.assertIn("if not is_recovery and new_version == old_version", workflow)

if __name__ == "__main__":
    unittest.main()
