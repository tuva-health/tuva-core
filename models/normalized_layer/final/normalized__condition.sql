{{ config(
     enabled = the_tuva_project.tuva_boolean_var('clinical_enabled', false)
   )
}}

{%- set tuva_core_columns -%}
      {{ the_tuva_project.stable_id_hash([
          "'clinical condition'",
          'cond.data_source',
          'cond.source_condition_id'
      ]) }} as condition_id
    , cast(cond.source_condition_id as {{ dbt.type_string() }}) as source_condition_id
    , cast(null as {{ dbt.type_string() }}) as payer
    , cast(cond.person_id as {{ dbt.type_string() }}) as person_id
    , cast(null as {{ dbt.type_string() }}) as member_id
    , cast(cond.patient_id as {{ dbt.type_string() }}) as patient_id
    , cast(cond.encounter_id as {{ dbt.type_string() }}) as encounter_id
    , cast(null as {{ dbt.type_string() }}) as claim_id
    , {{ try_to_cast_date('cond.recorded_date', 'YYYY-MM-DD') }} as recorded_date
    , {{ try_to_cast_date('cond.onset_date', 'YYYY-MM-DD') }} as onset_date
    , {{ try_to_cast_date('cond.resolved_date', 'YYYY-MM-DD') }} as resolved_date
    , cast(cond.status as {{ dbt.type_string() }}) as status
    , cast(cond.condition_type as {{ dbt.type_string() }}) as condition_type
    , cast(
        case
            when icd10.icd_10_cm is not null then 'icd-10-cm'
            when icd9.icd_9_cm is not null then 'icd-9-cm'
            when snomed_ct.snomed_ct is not null then 'snomed-ct'
            else lower(cond.code_system)
        end as {{ dbt.type_string() }}
      ) as code_system
    , cast(cond.source_code as {{ dbt.type_string() }}) as source_code
    , cast(cond.source_description as {{ dbt.type_string() }}) as source_description
    , cast(coalesce(
          icd10.icd_10_cm
        , icd9.icd_9_cm
        , snomed_ct.snomed_ct
      ) as {{ dbt.type_string() }}) as normalized_code
    , cast(coalesce(
          icd10.long_description
        , icd9.long_description
        , snomed_ct.description
      ) as {{ dbt.type_string() }}) as normalized_description
    , cast(cond.condition_rank as {{ dbt.type_int() }}) as condition_rank
    , cast(cond.present_on_admit_code as {{ dbt.type_string() }}) as present_on_admit_code
    , cast(poa.present_on_admit_description as {{ dbt.type_string() }}) as present_on_admit_description
{%- endset -%}

{%- set tuva_metadata_columns -%}
    , cast(cond.ingest_datetime as {{ dbt.type_timestamp() }}) as ingest_datetime
    , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
    , cast(cond.data_source as {{ dbt.type_string() }}) as data_source
{%- endset %}

{%- set tuva_extension_columns -%}
    {{ select_extension_columns(ref('input_layer__condition'), alias='cond', strip_prefix=false) }}
{%- endset %}

select
    {{ tuva_core_columns }}
    {{ tuva_extension_columns }}
    {{ tuva_metadata_columns }}
from {{ ref('input_layer__condition') }} as cond
left join {{ ref('terminology__icd_10_cm') }} as icd10
    on lower(cond.code_system) = 'icd-10-cm'
        and {{ the_tuva_project.clean_terminology_code('cond.source_code') }} = icd10.icd_10_cm
left join {{ ref('terminology__icd_9_cm') }} as icd9
    on lower(cond.code_system) = 'icd-9-cm'
        and {{ the_tuva_project.clean_terminology_code('cond.source_code') }} = icd9.icd_9_cm
left join {{ ref('terminology__snomed_ct') }} as snomed_ct
    on lower(cond.code_system) = 'snomed-ct'
        and cond.source_code = snomed_ct.snomed_ct
left outer join {{ ref('terminology__present_on_admission') }} as poa
    on cond.present_on_admit_code = poa.present_on_admit_code
