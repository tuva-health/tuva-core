{{ config(
     enabled = the_tuva_project.tuva_boolean_var('clinical_enabled', false)
   )
}}

{%- set tuva_core_columns -%}
      {{ the_tuva_project.stable_id_hash([
          "'clinical procedure'",
          'procedure_source.data_source',
          'procedure_source.source_procedure_id'
      ]) }} as procedure_id
    , cast(procedure_source.person_id as {{ dbt.type_string() }}) as person_id
    , cast(null as {{ dbt.type_string() }}) as member_id
    , cast(procedure_source.patient_id as {{ dbt.type_string() }}) as patient_id
    , cast(procedure_source.encounter_id as {{ dbt.type_string() }}) as encounter_id
    , cast(null as {{ dbt.type_string() }}) as claim_id
    , {{ try_to_cast_date('procedure_source.procedure_date', 'YYYY-MM-DD') }} as procedure_date
    , cast(
        case
            when icd10.icd_10_pcs is not null then 'icd-10-pcs'
            when icd9.icd_9_pcs is not null then 'icd-9-pcs'
            when hcpcs.hcpcs is not null then 'hcpcs'
            when snomed_ct.snomed_ct is not null then 'snomed-ct'
            else lower(procedure_source.code_system)
        end as {{ dbt.type_string() }}
      ) as code_system
    , cast(procedure_source.source_code as {{ dbt.type_string() }}) as source_code
    , cast(procedure_source.source_description as {{ dbt.type_string() }}) as source_description
    , cast(coalesce(
          icd10.icd_10_pcs
        , icd9.icd_9_pcs
        , hcpcs.hcpcs
        , snomed_ct.snomed_ct
      ) as {{ dbt.type_string() }}) as normalized_code
    , cast(coalesce(
          icd10.description
        , icd9.short_description
        , hcpcs.short_description
        , snomed_ct.description
      ) as {{ dbt.type_string() }}) as normalized_description
    , cast(procedure_source.modifier_1 as {{ dbt.type_string() }}) as modifier_1
    , cast(procedure_source.modifier_2 as {{ dbt.type_string() }}) as modifier_2
    , cast(procedure_source.modifier_3 as {{ dbt.type_string() }}) as modifier_3
    , cast(procedure_source.modifier_4 as {{ dbt.type_string() }}) as modifier_4
    , cast(procedure_source.modifier_5 as {{ dbt.type_string() }}) as modifier_5
    , cast(procedure_source.practitioner_id as {{ dbt.type_string() }}) as practitioner_id
{%- endset -%}

{%- set tuva_metadata_columns -%}
    , cast(procedure_source.ingest_datetime as {{ dbt.type_timestamp() }}) as ingest_datetime
    , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
    , cast(procedure_source.data_source as {{ dbt.type_string() }}) as data_source
{%- endset %}

{%- set tuva_extension_columns -%}
    {{ select_extension_columns(ref('input_layer__procedure'), alias='procedure_source', strip_prefix=false) }}
{%- endset %}

select
    {{ tuva_core_columns }}
    {{ tuva_extension_columns }}
    {{ tuva_metadata_columns }}
from {{ ref('input_layer__procedure') }} as procedure_source
left join {{ ref('terminology__icd_10_pcs') }} as icd10
    on lower(procedure_source.code_system) = 'icd-10-pcs'
        and {{ the_tuva_project.clean_terminology_code('procedure_source.source_code') }} = icd10.icd_10_pcs
left join {{ ref('terminology__icd_9_pcs') }} as icd9
    on lower(procedure_source.code_system) = 'icd-9-pcs'
        and {{ the_tuva_project.clean_terminology_code('procedure_source.source_code') }} = icd9.icd_9_pcs
left join {{ ref('terminology__hcpcs_level_2') }} as hcpcs
    on lower(procedure_source.code_system) = 'hcpcs'
        and {{ the_tuva_project.clean_terminology_code('procedure_source.source_code') }} = hcpcs.hcpcs
left join {{ ref('terminology__snomed_ct') }} as snomed_ct
    on lower(procedure_source.code_system) = 'snomed-ct'
        and procedure_source.source_code = snomed_ct.snomed_ct
