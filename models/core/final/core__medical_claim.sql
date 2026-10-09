{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}

{%- set tuva_core_columns -%}
      med.medical_claim_id
    , med.claim_id
    , med.claim_line_number
    , cast(x.encounter_id as {{ dbt.type_string() }}) as encounter_id
    , cast(x.encounter_type as {{ dbt.type_string() }}) as encounter_type
    , cast(x.encounter_group as {{ dbt.type_string() }}) as encounter_group
    , med.claim_type
    , med.person_id
    , med.member_id
    , med.payer
    , med.{{ quote_column('plan') }}
    , med.claim_start_date
    , med.claim_end_date
    , med.claim_line_start_date
    , med.claim_line_end_date
    , med.admission_date
    , med.discharge_date
    , cast(srv_group.service_category_1 as {{ dbt.type_string() }}) as service_category_1
    , cast(srv_group.service_category_2 as {{ dbt.type_string() }}) as service_category_2
    , cast(srv_group.service_category_3 as {{ dbt.type_string() }}) as service_category_3
    , med.admit_source_code
    , med.admit_source_description
    , med.admit_type_code
    , med.admit_type_description
    , med.discharge_disposition_code
    , med.discharge_disposition_description
    , med.place_of_service_code
    , med.place_of_service_description
    , med.bill_type_code
    , med.bill_type_description
    , med.drg_code_type
    , med.drg_code
    , med.drg_description
    , med.revenue_center_code
    , med.revenue_center_description
    , med.service_unit_quantity
    , med.hcpcs_code
    , med.hcpcs_modifier_1
    , med.hcpcs_modifier_2
    , med.hcpcs_modifier_3
    , med.hcpcs_modifier_4
    , med.hcpcs_modifier_5
    , med.rendering_npi
    , med.rendering_tin
    , med.rendering_name
    , med.billing_npi
    , med.billing_tin
    , med.billing_name
    , med.facility_npi
    , med.facility_name
    , med.paid_date
    , med.paid_amount
    , med.allowed_amount
    , med.charge_amount
    , med.coinsurance_amount
    , med.copayment_amount
    , med.deductible_amount
    , med.total_cost_amount
    , med.paid_reduced_by
    , med.in_network_flag
    , cast(
        case
            when enroll.claim_id is not null then 1
            else 0
        end as {{ dbt.type_int() }}
      ) as enrollment_flag
    , cast(enroll.member_month_id as {{ dbt.type_string() }}) as member_month_id
{%- endset -%}

{%- set tuva_extension_columns -%}
    {{ select_extension_columns(ref('normalized__medical_claim'), alias='med') }}
{%- endset -%}

{%- set tuva_metadata_columns -%}
    , med.file_date
    , med.ingest_datetime
    , med.file_name
    , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
    , med.data_source
{%- endset %}

with all_encounters as (
    select
        claim_id
        , claim_line_number
        , data_source
        , encounter_id
        , encounter_type
        , encounter_group
    from {{ ref('encounters__combined_claim_line_crosswalk') }}
    where claim_line_attribution_number = 1

    union all

    select
        claim_id
        , claim_line_number
        , data_source
        , encounter_id
        , encounter_type
        , encounter_group
    from {{ ref('encounters__orphaned_claims') }}
)

select
    {{ tuva_core_columns }}
    {{ tuva_extension_columns }}
    {{ tuva_metadata_columns }}
from {{ ref('normalized__medical_claim') }} as med
inner join {{ ref('service_category__service_category_grouper') }} as srv_group
    on med.claim_id = srv_group.claim_id
    and med.claim_line_number = srv_group.claim_line_number
    and med.data_source = srv_group.data_source
    and srv_group.duplicate_row_number = 1
inner join all_encounters as x
    on med.claim_id = x.claim_id
    and med.claim_line_number = x.claim_line_number
    and med.data_source = x.data_source
left outer join {{ ref('claims_enrollment__flag_claims_with_enrollment') }} as enroll
    on med.claim_id = enroll.claim_id
    and med.claim_line_number = enroll.claim_line_number
    and med.person_id = enroll.person_id
    and med.payer = enroll.payer
    and med.{{ quote_column('plan') }} = enroll.{{ quote_column('plan') }}
    and med.data_source = enroll.data_source
