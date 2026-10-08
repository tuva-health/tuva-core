{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}

{% set diagnosis_cols = range(1, 26) %}

with line_level_diagnoses as (
    {% for i in diagnosis_cols %}
    select
        medical_claim_id
        , claim_id
        , claim_line_number
        , claim_type
        , person_id
        , member_id
        , payer
        , {{ quote_column('plan') }}
        , claim_start_date
        , claim_end_date
        , claim_line_start_date
        , claim_line_end_date
        , admission_date
        , discharge_date
        , diagnosis_code_type as raw_code_system
        , {{ i }} as condition_rank
        , 'diagnosis_code_{{ i }}' as diagnosis_column
        , diagnosis_code_{{ i }} as source_code
        , diagnosis_poa_{{ i }} as present_on_admit_code
        , data_source
    from {{ ref('normalized__medical_claim') }}
    where diagnosis_code_{{ i }} is not null
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
)

, normalized_diagnoses as (
    select
        diag.medical_claim_id
        , diag.claim_id
        , diag.claim_line_number
        , diag.claim_type
        , diag.person_id
        , diag.member_id
        , diag.payer
        , diag.{{ quote_column('plan') }}
        , coalesce(
              diag.admission_date
            , diag.claim_start_date
            , diag.discharge_date
            , diag.claim_end_date
          ) as recorded_date
        , diag.raw_code_system
        , diag.condition_rank
        , diag.diagnosis_column
        , {{ the_tuva_project.clean_terminology_code('diag.source_code') }} as source_code
        , diag.present_on_admit_code
        , case
            when lower(diag.raw_code_system) = 'icd-9-cm'
                and icd9.icd_9_cm is not null
                then 'icd-9-cm'
            when lower(diag.raw_code_system) = 'icd-10-cm'
                and icd10.icd_10_cm is not null
                then 'icd-10-cm'
            when icd10.icd_10_cm is not null then 'icd-10-cm'
            when icd9.icd_9_cm is not null then 'icd-9-cm'
            else lower(diag.raw_code_system)
          end as code_system
        , case
            when lower(diag.raw_code_system) = 'icd-9-cm'
                and icd9.icd_9_cm is not null
                then icd9.icd_9_cm
            when lower(diag.raw_code_system) = 'icd-10-cm'
                and icd10.icd_10_cm is not null
                then icd10.icd_10_cm
            else coalesce(icd10.icd_10_cm, icd9.icd_9_cm)
          end as normalized_code
        , case
            when lower(diag.raw_code_system) = 'icd-9-cm'
                and icd9.icd_9_cm is not null
                then icd9.long_description
            when lower(diag.raw_code_system) = 'icd-10-cm'
                and icd10.icd_10_cm is not null
                then icd10.long_description
            else coalesce(icd10.long_description, icd9.long_description)
          end as normalized_description
        , poa.present_on_admit_description
        , diag.data_source
    from line_level_diagnoses as diag
    left join {{ ref('terminology__icd_10_cm') }} as icd10
        on {{ the_tuva_project.clean_terminology_code('diag.source_code') }} = icd10.icd_10_cm
    left join {{ ref('terminology__icd_9_cm') }} as icd9
        on {{ the_tuva_project.clean_terminology_code('diag.source_code') }} = icd9.icd_9_cm
    left join {{ ref('terminology__present_on_admission') }} as poa
        on diag.present_on_admit_code = poa.present_on_admit_code
)

select distinct
    cast(medical_claim_id as {{ dbt.type_string() }}) as medical_claim_id
    , cast(claim_id as {{ dbt.type_string() }}) as claim_id
    , cast(claim_line_number as int) as claim_line_number
    , cast(claim_type as {{ dbt.type_string() }}) as claim_type
    , cast(person_id as {{ dbt.type_string() }}) as person_id
    , cast(member_id as {{ dbt.type_string() }}) as member_id
    , cast(payer as {{ dbt.type_string() }}) as payer
    , cast({{ quote_column('plan') }} as {{ dbt.type_string() }}) as {{ quote_column('plan') }}
    , {{ try_to_cast_date('recorded_date', 'YYYY-MM-DD') }} as recorded_date
    , cast(raw_code_system as {{ dbt.type_string() }}) as raw_code_system
    , cast(condition_rank as {{ dbt.type_int() }}) as condition_rank
    , cast(diagnosis_column as {{ dbt.type_string() }}) as diagnosis_column
    , cast(code_system as {{ dbt.type_string() }}) as code_system
    , cast(source_code as {{ dbt.type_string() }}) as source_code
    , cast(normalized_code as {{ dbt.type_string() }}) as normalized_code
    , cast(normalized_description as {{ dbt.type_string() }}) as normalized_description
    , cast(present_on_admit_code as {{ dbt.type_string() }}) as present_on_admit_code
    , cast(present_on_admit_description as {{ dbt.type_string() }}) as present_on_admit_description
    , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
    , cast(data_source as {{ dbt.type_string() }}) as data_source
from normalized_diagnoses
