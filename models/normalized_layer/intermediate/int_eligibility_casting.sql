{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}

with eligibility_source as (
    select
        elig.*
        , case
            when cast(elig.enrollment_end_date as date) = cast('9999-12-31' as date)
                then cast(null as date)
            else cast(elig.enrollment_end_date as date)
          end as _canonical_enrollment_end_date
    from {{ ref('input_layer__eligibility') }} as elig
)

select
      cast(elig.person_id as {{ dbt.type_string() }}) as person_id
    , {{ the_tuva_project.stable_id_hash([
        "'eligibility person key'",
        'elig.person_id',
        'elig.member_id',
        'elig.data_source',
        'elig.payer',
        'elig.' ~ quote_column('plan'),
        'elig.enrollment_start_date',
        'elig._canonical_enrollment_end_date'
    ]) }} as person_id_key
    , cast(elig.member_id as {{ dbt.type_string() }}) as member_id
    , cast(elig.subscriber_id as {{ dbt.type_string() }}) as subscriber_id
    , cast(elig.subscriber_relation as {{ dbt.type_string() }}) as subscriber_relation
    , cast(elig.enrollment_start_date as date) as enrollment_start_date
    , elig._canonical_enrollment_end_date as enrollment_end_date
    , cast(elig.payer as {{ dbt.type_string() }}) as payer
    , cast(elig.payer_type as {{ dbt.type_string() }}) as payer_type
    , cast(elig.{{ quote_column('plan') }} as {{ dbt.type_string() }}) as {{ quote_column('plan') }}
    , cast(elig.first_name as {{ dbt.type_string() }}) as first_name
    , cast(elig.middle_name as {{ dbt.type_string() }}) as middle_name
    , cast(elig.last_name as {{ dbt.type_string() }}) as last_name
    , cast(elig.name_suffix as {{ dbt.type_string() }}) as name_suffix
    , cast(elig.social_security_number as {{ dbt.type_string() }}) as social_security_number
    , cast(elig.address as {{ dbt.type_string() }}) as address
    , cast(elig.city as {{ dbt.type_string() }}) as city
    , cast(elig.state as {{ dbt.type_string() }}) as state
    , cast(elig.zip_code as {{ dbt.type_string() }}) as zip_code
    , cast(elig.phone as {{ dbt.type_string() }}) as phone
    , cast(elig.email as {{ dbt.type_string() }}) as email
    , cast(elig.ethnicity as {{ dbt.type_string() }}) as ethnicity
    , cast(elig.sex as {{ dbt.type_string() }}) as sex
    , cast(elig.race as {{ dbt.type_string() }}) as race
    , cast(elig.birth_date as date) as birth_date
    , cast(elig.death_date as date) as death_date
    , cast(elig.death_flag as {{ dbt.type_int() }}) as death_flag
    , cast(elig.original_reason_entitlement_code as {{ dbt.type_string() }}) as original_reason_entitlement_code
    , cast(elig.dual_status_code as {{ dbt.type_string() }}) as dual_status_code
    , cast(elig.medicare_status_code as {{ dbt.type_string() }}) as medicare_status_code
    , cast(elig.enrollment_status as {{ dbt.type_string() }}) as enrollment_status
    , cast(elig.hospice_flag as {{ dbt.type_int() }}) as hospice_flag
    , cast(elig.institutional_snp_flag as {{ dbt.type_int() }}) as institutional_snp_flag
    , cast(elig.medicaid_indicator as {{ dbt.type_int() }}) as medicaid_indicator
    , cast(elig.long_term_institutional_flag as {{ dbt.type_int() }}) as long_term_institutional_flag
    , cast(elig.part_d_raf_type as {{ dbt.type_string() }}) as part_d_raf_type
    , cast(elig.low_income_subsidy_indicator as {{ dbt.type_int() }}) as low_income_subsidy_indicator
    , cast(elig.metal_level as {{ dbt.type_string() }}) as metal_level
    , cast(elig.csr_indicator as {{ dbt.type_int() }}) as csr_indicator
    , cast(elig.enrollment_duration_months as {{ dbt.type_int() }}) as enrollment_duration_months
    , cast(elig.esrd_status as {{ dbt.type_int() }}) as esrd_status
    , cast(elig.transplant_duration_months as {{ dbt.type_int() }}) as transplant_duration_months
    , cast(elig.group_id as {{ dbt.type_string() }}) as group_id
    , cast(elig.group_name as {{ dbt.type_string() }}) as group_name
    {{ select_extension_columns(ref('input_layer__eligibility'), alias='elig', strip_prefix=false) }}
    , cast(elig.file_name as {{ dbt.type_string() }}) as file_name
    , cast(elig.file_date as date) as file_date
    , cast(elig.ingest_datetime as {{ dbt.type_timestamp() }}) as ingest_datetime
    , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
    , cast(elig.data_source as {{ dbt.type_string() }}) as data_source
from eligibility_source as elig
