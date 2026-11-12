{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}

with encounter_crosswalk as (
    select
        claim_id
        , claim_line_number
        , data_source
        , encounter_id
    from {{ ref('encounters__combined_claim_line_crosswalk') }}
    where claim_line_attribution_number = 1

    union all

    select
        claim_id
        , claim_line_number
        , data_source
        , encounter_id
    from {{ ref('encounters__orphaned_claims') }}
)

, claims_diagnoses as (
    select
        diag.medical_claim_id
        , diag.claim_id
        , diag.claim_line_number
        , enc.encounter_id
        , diag.claim_type
        , diag.person_id
        , diag.member_id
        , diag.payer
        , diag.{{ quote_column('plan') }}
        , diag.recorded_date
        , diag.condition_rank
        , diag.code_system
        , diag.source_code
        , diag.normalized_code
        , diag.normalized_description
        , diag.present_on_admit_code
        , diag.present_on_admit_description
        , diag.tuva_last_run
        , diag.data_source
    from {{ ref('normalized__medical_claim_diagnoses') }} as diag
    left join encounter_crosswalk as enc
        on diag.claim_id = enc.claim_id
        and diag.claim_line_number = enc.claim_line_number
        and diag.data_source = enc.data_source
)

select distinct
    {{ the_tuva_project.stable_id_hash([
        "'claims condition'",
        'data_source',
        'claim_id',
        'encounter_id',
        'condition_rank',
        'code_system',
        'source_code'
    ]) }} as condition_id
    , cast(null as {{ dbt.type_string() }}) as source_condition_id
    , cast(person_id as {{ dbt.type_string() }}) as person_id
    , cast(member_id as {{ dbt.type_string() }}) as member_id
    , cast(null as {{ dbt.type_string() }}) as patient_id
    , cast(encounter_id as {{ dbt.type_string() }}) as encounter_id
    , cast(claim_id as {{ dbt.type_string() }}) as claim_id
    , cast(payer as {{ dbt.type_string() }}) as payer
    , {{ try_to_cast_date('recorded_date', 'YYYY-MM-DD') }} as recorded_date
    , {{ try_to_cast_date('null', 'YYYY-MM-DD') }} as onset_date
    , {{ try_to_cast_date('null', 'YYYY-MM-DD') }} as resolved_date
    , cast(null as {{ dbt.type_string() }}) as status
    , cast('billing_diagnosis' as {{ dbt.type_string() }}) as condition_type
    , cast(code_system as {{ dbt.type_string() }}) as code_system
    , cast(source_code as {{ dbt.type_string() }}) as source_code
    , cast(null as {{ dbt.type_string() }}) as source_description
    , cast(normalized_code as {{ dbt.type_string() }}) as normalized_code
    , cast(normalized_description as {{ dbt.type_string() }}) as normalized_description
    , cast(condition_rank as {{ dbt.type_int() }}) as condition_rank
    , cast(present_on_admit_code as {{ dbt.type_string() }}) as present_on_admit_code
    , cast(present_on_admit_description as {{ dbt.type_string() }}) as present_on_admit_description
    , cast(null as {{ dbt.type_timestamp() }}) as ingest_datetime
    , cast(tuva_last_run as {{ dbt.type_timestamp() }}) as tuva_last_run
    , cast(data_source as {{ dbt.type_string() }}) as data_source
from claims_diagnoses
