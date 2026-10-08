{{ config(
     enabled = the_tuva_project.tuva_boolean_var('clinical_enabled', false)
   )
}}

{%- set tuva_core_columns -%}
      cast(observation_id as {{ dbt.type_string() }}) as observation_id
    , cast(person_id as {{ dbt.type_string() }}) as person_id
    , cast(patient_id as {{ dbt.type_string() }}) as patient_id
    , cast(encounter_id as {{ dbt.type_string() }}) as encounter_id
    , cast(panel_id as {{ dbt.type_string() }}) as panel_id
    , {{ try_to_cast_date('observation_date', 'YYYY-MM-DD') }} as observation_date
    , cast(observation_type as {{ dbt.type_string() }}) as observation_type
    , cast(source_code_type as {{ dbt.type_string() }}) as source_code_type
    , cast(source_code as {{ dbt.type_string() }}) as source_code
    , cast(source_description as {{ dbt.type_string() }}) as source_description
    , cast(result as {{ dbt.type_string() }}) as result
    , cast(source_units as {{ dbt.type_string() }}) as source_units
    , cast(normalized_units as {{ dbt.type_string() }}) as normalized_units
    , cast(source_reference_range_low as {{ dbt.type_string() }}) as source_reference_range_low
    , cast(source_reference_range_high as {{ dbt.type_string() }}) as source_reference_range_high
    , cast(normalized_reference_range_low as {{ dbt.type_string() }}) as normalized_reference_range_low
    , cast(normalized_reference_range_high as {{ dbt.type_string() }}) as normalized_reference_range_high
{%- endset -%}

{%- set tuva_metadata_columns -%}
    , cast(ingest_datetime as {{ dbt.type_timestamp() }}) as ingest_datetime
    , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
    , cast(data_source as {{ dbt.type_string() }}) as data_source
{%- endset %}

{%- set tuva_extension_columns -%}
    {{ select_extension_columns(ref('input_layer__observation'), strip_prefix=false) }}
{%- endset %}

with obs as (

    select
        {{ tuva_core_columns }}
        {{ tuva_extension_columns }}
        {{ tuva_metadata_columns }}
    from {{ ref('input_layer__observation') }}

)

select
      obs.observation_id
    , obs.person_id
    , obs.patient_id
    , obs.encounter_id
    , obs.panel_id
    , obs.observation_date
    , case
        when ot.observation_type is not null then ot.observation_type
        else obs.observation_type
      end as observation_type
    , obs.source_code_type
    , obs.source_code
    , obs.source_description
    , case
        when icd10cm.icd_10_cm is not null then 'icd-10-cm'
        when icd9cm.icd_9_cm is not null then 'icd-9-cm'
        when icd10pcs.icd_10_pcs is not null then 'icd-10-pcs'
        when icd9pcs.icd_9_pcs is not null then 'icd-9-pcs'
        when hcpcs.hcpcs is not null then 'hcpcs'
        when snomed_ct.snomed_ct is not null then 'snomed-ct'
        when loinc.loinc is not null then 'loinc'
        end as normalized_code_type
    , coalesce(
          icd10cm.icd_10_cm
        , icd9cm.icd_9_cm
        , icd10pcs.icd_10_pcs
        , icd9pcs.icd_9_pcs
        , hcpcs.hcpcs
        , snomed_ct.snomed_ct
        , loinc.loinc
      ) as normalized_code
    , coalesce(
          icd10cm.short_description
        , icd9cm.short_description
        , icd10pcs.description
        , icd9pcs.short_description
        , hcpcs.short_description
        , snomed_ct.description
        , loinc.long_common_name
      ) as normalized_description
    , obs.result
    , obs.source_units
    , obs.normalized_units
    , obs.source_reference_range_low
    , obs.source_reference_range_high
    , obs.normalized_reference_range_low
    , obs.normalized_reference_range_high
    {{ select_extension_columns(ref('input_layer__observation'), alias='obs', strip_prefix=false) }}
    , obs.ingest_datetime
    , obs.tuva_last_run
    , obs.data_source
from obs
left join {{ ref('terminology__icd_10_cm') }} as icd10cm
    on lower(obs.source_code_type) = 'icd-10-cm'
        and {{ the_tuva_project.clean_terminology_code('obs.source_code') }} = icd10cm.icd_10_cm
left join {{ ref('terminology__icd_9_cm') }} as icd9cm
    on lower(obs.source_code_type) = 'icd-9-cm'
        and {{ the_tuva_project.clean_terminology_code('obs.source_code') }} = icd9cm.icd_9_cm
left join {{ ref('terminology__icd_10_pcs') }} as icd10pcs
    on lower(obs.source_code_type) = 'icd-10-pcs'
        and {{ the_tuva_project.clean_terminology_code('obs.source_code') }} = icd10pcs.icd_10_pcs
left join {{ ref('terminology__icd_9_pcs') }} as icd9pcs
    on lower(obs.source_code_type) = 'icd-9-pcs'
        and {{ the_tuva_project.clean_terminology_code('obs.source_code') }} = icd9pcs.icd_9_pcs
left join {{ ref('terminology__hcpcs_level_2') }} as hcpcs
    on lower(obs.source_code_type) = 'hcpcs'
        and {{ the_tuva_project.clean_terminology_code('obs.source_code') }} = hcpcs.hcpcs
left join {{ ref('terminology__snomed_ct') }} as snomed_ct
    on lower(obs.source_code_type) = 'snomed-ct'
        and obs.source_code = snomed_ct.snomed_ct
left join {{ ref('terminology__loinc') }} as loinc
    on lower(obs.source_code_type) = 'loinc'
        and obs.source_code = loinc.loinc
left join {{ ref('terminology__observation_type') }} as ot
    on lower(obs.observation_type) = ot.observation_type
