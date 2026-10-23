{% set synthetic_size = the_tuva_project.get_synthetic_data_size() %}
{% set asset_version = var('tuva_core_data_asset_version', '1.1.0') %}
{% set default_bucket = var('custom_bucket_name', 'tuva-public-resources') %}
{% set normalized_bucket = default_bucket | string | trim %}
{% if normalized_bucket.startswith('s3://') %}
  {% set normalized_bucket = normalized_bucket[5:] %}
{% endif %}
{% set normalized_bucket = normalized_bucket | trim('/') %}

with resolved_paths as (
  select
    '{{ the_tuva_project.get_versioned_seed_uri("terminology") }}' as terminology_uri
    , '{{ the_tuva_project.get_versioned_seed_uri("provider_data") }}' as provider_data_uri
    , '{{ the_tuva_project.get_versioned_seed_uri("value_sets") }}' as value_sets_uri
    , '{{ the_tuva_project.get_synthetic_seed_object_path("synthetic_data__appointment") }}' as synthetic_object_path
    , '{{ the_tuva_project.get_package_seed_uri("data-marts/cms-hcc", "v1.0.0", "cms_hcc__sample.csv.gz", "s3://custom-assets/") }}' as generic_package_uri
    , '{{ the_tuva_project.get_package_seed_uri("data-marts/cms-hcc", "1.0.0", "cms_hcc__sample.csv.gz") }}' as default_package_uri
)

select *
from resolved_paths
where terminology_uri <> '{{ normalized_bucket }}/tuva-core/{{ asset_version }}/terminology'
  or provider_data_uri <> '{{ normalized_bucket }}/tuva-core/{{ asset_version }}/provider-data'
  or value_sets_uri <> '{{ normalized_bucket }}/tuva-core/{{ asset_version }}/value-sets'
  or synthetic_object_path <> 'synthetic-data/{{ synthetic_size }}/synthetic_data__appointment.csv.gz'
  or generic_package_uri <> 'custom-assets/data-marts/cms-hcc/1.0.0/cms_hcc__sample.csv.gz'
  or default_package_uri <> '{{ normalized_bucket }}/data-marts/cms-hcc/1.0.0/cms_hcc__sample.csv.gz'
