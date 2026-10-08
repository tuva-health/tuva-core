{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}

{% set procedure_cols = var('_medical_claim_procedure_cols_override', range(1, 26)) %}

with hcpcs_procedures as (
    select
        med.claim_id
        , med.claim_line_number
        , med.claim_line_number as procedure_sequence_id
        , med.person_id
        , med.member_id
        , coalesce(
              med.claim_line_start_date
            , med.claim_start_date
            , med.admission_date
            , med.discharge_date
            , med.claim_end_date
          ) as procedure_date
        , 'hcpcs' as raw_code_system
        , med.hcpcs_code as source_code
        , med.rendering_npi as practitioner_id
        , med.hcpcs_modifier_1 as modifier_1
        , med.hcpcs_modifier_2 as modifier_2
        , med.hcpcs_modifier_3 as modifier_3
        , med.hcpcs_modifier_4 as modifier_4
        , med.hcpcs_modifier_5 as modifier_5
        , med.ingest_datetime
        , med.data_source
    from {{ ref('normalized__medical_claim') }} as med
    where med.hcpcs_code is not null
)

, claim_header_procedures as (
    {% for i in procedure_cols %}
    select distinct
        med.claim_id
        , cast(null as {{ dbt.type_int() }}) as claim_line_number
        , {{ i }} as procedure_sequence_id
        , med.person_id
        , med.member_id
        , med.procedure_date_{{ i }} as procedure_date
        , med.procedure_code_type as raw_code_system
        , med.procedure_code_{{ i }} as source_code
        , med.rendering_npi as practitioner_id
        , cast(null as {{ dbt.type_string() }}) as modifier_1
        , cast(null as {{ dbt.type_string() }}) as modifier_2
        , cast(null as {{ dbt.type_string() }}) as modifier_3
        , cast(null as {{ dbt.type_string() }}) as modifier_4
        , cast(null as {{ dbt.type_string() }}) as modifier_5
        , cast(null as {{ dbt.type_timestamp() }}) as ingest_datetime
        , med.data_source
    from {{ ref('normalized__medical_claim') }} as med
    where med.procedure_code_{{ i }} is not null
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
)

, all_claim_procedures as (
    select * from hcpcs_procedures
    union all
    select * from claim_header_procedures
)

, normalized_procedures as (
    select
        procedure_source.claim_id
        , procedure_source.claim_line_number
        , procedure_source.procedure_sequence_id
        , procedure_source.person_id
        , procedure_source.member_id
        , procedure_source.procedure_date
        , procedure_source.raw_code_system
        , procedure_source.source_code
        , procedure_source.practitioner_id
        , procedure_source.modifier_1
        , procedure_source.modifier_2
        , procedure_source.modifier_3
        , procedure_source.modifier_4
        , procedure_source.modifier_5
        , procedure_source.ingest_datetime
        , case
            when icd10.icd_10_pcs is not null then 'icd-10-pcs'
            when icd9.icd_9_pcs is not null then 'icd-9-pcs'
            when hcpcs.hcpcs is not null then 'hcpcs'
            when snomed_ct.snomed_ct is not null then 'snomed-ct'
            else lower(procedure_source.raw_code_system)
          end as code_system
        , coalesce(
              icd10.icd_10_pcs
            , icd9.icd_9_pcs
            , hcpcs.hcpcs
            , snomed_ct.snomed_ct
          ) as normalized_code
        , coalesce(
              icd10.description
            , icd9.short_description
            , hcpcs.short_description
            , snomed_ct.description
          ) as normalized_description
        , procedure_source.data_source
    from all_claim_procedures as procedure_source
    left join {{ ref('terminology__icd_10_pcs') }} as icd10
        on lower(procedure_source.raw_code_system) = 'icd-10-pcs'
        and {{ the_tuva_project.clean_terminology_code('procedure_source.source_code') }} = icd10.icd_10_pcs
    left join {{ ref('terminology__icd_9_pcs') }} as icd9
        on lower(procedure_source.raw_code_system) = 'icd-9-pcs'
        and {{ the_tuva_project.clean_terminology_code('procedure_source.source_code') }} = icd9.icd_9_pcs
    left join {{ ref('terminology__hcpcs_level_2') }} as hcpcs
        on lower(procedure_source.raw_code_system) = 'hcpcs'
        and {{ the_tuva_project.clean_terminology_code('procedure_source.source_code') }} = hcpcs.hcpcs
    left join {{ ref('terminology__snomed_ct') }} as snomed_ct
        on lower(procedure_source.raw_code_system) = 'snomed-ct'
        and procedure_source.source_code = snomed_ct.snomed_ct
)

select distinct
    cast(person_id as {{ dbt.type_string() }}) as person_id
    , cast(member_id as {{ dbt.type_string() }}) as member_id
    , cast(claim_id as {{ dbt.type_string() }}) as claim_id
    , cast(claim_line_number as {{ dbt.type_int() }}) as claim_line_number
    , cast(procedure_sequence_id as {{ dbt.type_int() }}) as procedure_sequence_id
    , {{ try_to_cast_date('procedure_date', 'YYYY-MM-DD') }} as procedure_date
    , cast(practitioner_id as {{ dbt.type_string() }}) as practitioner_id
    , cast(code_system as {{ dbt.type_string() }}) as code_system
    , cast(source_code as {{ dbt.type_string() }}) as source_code
    , cast(null as {{ dbt.type_string() }}) as source_description
    , cast(normalized_code as {{ dbt.type_string() }}) as normalized_code
    , cast(normalized_description as {{ dbt.type_string() }}) as normalized_description
    , cast(modifier_1 as {{ dbt.type_string() }}) as modifier_1
    , cast(modifier_2 as {{ dbt.type_string() }}) as modifier_2
    , cast(modifier_3 as {{ dbt.type_string() }}) as modifier_3
    , cast(modifier_4 as {{ dbt.type_string() }}) as modifier_4
    , cast(modifier_5 as {{ dbt.type_string() }}) as modifier_5
    , cast(ingest_datetime as {{ dbt.type_timestamp() }}) as ingest_datetime
    , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
    , cast(data_source as {{ dbt.type_string() }}) as data_source
from normalized_procedures
