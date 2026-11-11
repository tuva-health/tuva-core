{% macro get_seed_database_folders() %}
  {{ return({
      'terminology': 'terminology',
      'value_sets': 'value-sets',
      'provider_data': 'provider-data',
      'synthetic_data': 'synthetic-data'
  }) }}
{% endmacro %}


{% macro get_seed_database_folder(database) %}
  {% set folders = the_tuva_project.get_seed_database_folders() %}
  {% set normalized_database = database | string | trim %}
  {% set alternate_database = normalized_database | replace('-', '_') %}

  {% if normalized_database in folders %}
    {{ return(folders[normalized_database]) }}
  {% endif %}

  {% if alternate_database in folders %}
    {{ return(folders[alternate_database]) }}
  {% endif %}

  {% for folder in folders.values() %}
    {% if normalized_database == folder %}
      {{ return(folder) }}
    {% endif %}
  {% endfor %}

  {% do exceptions.raise_compiler_error(
      "Unsupported Tuva seed database '" ~ database ~ "'."
  ) %}
{% endmacro %}


{% macro get_package_seed_uri(asset_root, asset_version, object_path='', bucket=none) %}
  {% set normalized_root = asset_root | string | trim | trim('/') %}
  {% set root_parts = normalized_root.split('/') %}
  {% if normalized_root == '' or '' in root_parts or '.' in root_parts or '..' in root_parts %}
    {% do exceptions.raise_compiler_error(
        "Tuva data asset root must contain only nonempty path segments. Received '" ~ asset_root ~ "'."
    ) %}
  {% endif %}

  {% set normalized_version = asset_version | string | trim %}
  {% if normalized_version.startswith('v') %}
    {% set normalized_version = normalized_version[1:] %}
  {% endif %}
  {% set normalized_version = normalized_version | trim('/') %}
  {% if normalized_version == '' or '/' in normalized_version %}
    {% do exceptions.raise_compiler_error(
        "Tuva data asset version must be a nonempty path segment. Received '" ~ asset_version ~ "'."
    ) %}
  {% endif %}

  {% if bucket is none %}
    {% set normalized_bucket = var('custom_bucket_name', 'tuva-public-resources') | string | trim %}
  {% else %}
    {% set normalized_bucket = bucket | string | trim %}
  {% endif %}
  {% if normalized_bucket.startswith('s3://') %}
    {% set normalized_bucket = normalized_bucket[5:] %}
  {% endif %}
  {% set normalized_bucket = normalized_bucket | trim('/') %}

  {% set normalized_object_path = object_path | string | trim | trim('/') %}
  {% set uri = normalized_bucket ~ '/' ~ normalized_root ~ '/' ~ normalized_version %}
  {% if normalized_object_path != '' %}
    {% set uri = uri ~ '/' ~ normalized_object_path %}
  {% endif %}

  {{ return(uri) }}
{% endmacro %}


{% macro load_package_seed(asset_root, asset_version, object_path, compression=true, headers=true, null_marker=true, bucket=none) %}
  {% set normalized_object_path = object_path | string | trim | trim('/') %}
  {% if normalized_object_path == '' %}
    {% do exceptions.raise_compiler_error("Tuva package seed object_path must not be empty.") %}
  {% endif %}

  {% set object_parts = normalized_object_path.split('/') %}
  {% set pattern = object_parts[-1] %}
  {% set object_folder = object_parts[:-1] | join('/') %}

  {{ return(the_tuva_project.load_seed(
      the_tuva_project.get_package_seed_uri(
          asset_root,
          asset_version,
          object_folder,
          bucket
      ),
      pattern,
      compression,
      headers,
      null_marker
  )) }}
{% endmacro %}


{% macro get_versioned_seed_uri(database) %}
  {{ return(the_tuva_project.get_package_seed_uri(
      'tuva-core',
      var('tuva_core_data_asset_version', '1.1.0'),
      the_tuva_project.get_seed_database_folder(database)
  )) }}
{% endmacro %}


{% macro load_versioned_seed(database, seed_object_name, compression=true, headers=true, null_marker=true) %}
  {% set object_path = the_tuva_project.get_seed_database_folder(database) ~ '/' ~ seed_object_name %}
  {{ return(the_tuva_project.load_package_seed(
      'tuva-core',
      var('tuva_core_data_asset_version', '1.1.0'),
      object_path,
      compression,
      headers,
      null_marker
  )) }}
{% endmacro %}


{% macro get_synthetic_data_size() %}
  {% set synthetic_data_size = var('synthetic_data_size', 'large') | string | trim | lower %}

  {% if synthetic_data_size not in ['small', 'large'] %}
    {% do exceptions.raise_compiler_error(
        "Invalid synthetic_data_size '" ~ synthetic_data_size ~ "'. Expected 'small' or 'large'."
    ) %}
  {% endif %}

  {{ return(synthetic_data_size) }}
{% endmacro %}


{% macro get_synthetic_seed_object_path(seed_name) %}
  {% set synthetic_seeds = [
      'synthetic_data__appointment',
      'synthetic_data__condition',
      'synthetic_data__eligibility',
      'synthetic_data__encounter',
      'synthetic_data__immunization',
      'synthetic_data__lab_result',
      'synthetic_data__location',
      'synthetic_data__medical_claim',
      'synthetic_data__medication',
      'synthetic_data__observation',
      'synthetic_data__patient',
      'synthetic_data__pharmacy_claim',
      'synthetic_data__practitioner',
      'synthetic_data__procedure',
      'synthetic_data__provider_attribution'
  ] %}

  {% if seed_name not in synthetic_seeds %}
    {% do exceptions.raise_compiler_error(
        "Unsupported synthetic seed '" ~ seed_name ~ "'."
    ) %}
  {% endif %}

  {% set synthetic_data_size = the_tuva_project.get_synthetic_data_size() %}
  {{ return('synthetic-data/' ~ synthetic_data_size ~ '/' ~ seed_name ~ '.csv.gz') }}
{% endmacro %}


{% macro load_versioned_synthetic_seed(seed_name, compression=true, headers=true, null_marker=true) %}
  {{ return(the_tuva_project.load_package_seed(
      'tuva-core',
      var('tuva_core_data_asset_version', '1.1.0'),
      the_tuva_project.get_synthetic_seed_object_path(seed_name),
      compression,
      headers,
      null_marker
  )) }}
{% endmacro %}
