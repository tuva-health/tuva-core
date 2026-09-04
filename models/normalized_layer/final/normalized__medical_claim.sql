{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}

{% set index_cols = range(1, 26) %}

select
    {{ concat_custom([
        "med.claim_id",
        "'-'",
        "med.claim_line_number",
        "'-'",
        "med.data_source"
    ]) }} as medical_claim_id
    , cast(med.claim_id as {{ dbt.type_string() }}) as claim_id
    , cast(med.claim_line_number as int) as claim_line_number
    , cast(med.claim_type as {{ dbt.type_string() }}) as claim_type
    , cast(med.person_id as {{ dbt.type_string() }}) as person_id
    , cast(med.member_id as {{ dbt.type_string() }}) as member_id
    , cast(med.payer as {{ dbt.type_string() }}) as payer
    , cast(med.{{ quote_column('plan') }} as {{ dbt.type_string() }}) as {{ quote_column('plan') }}
    , cast(coalesce(dates.minimum_claim_start_date, undetermined.claim_start_date) as date) as claim_start_date
    , cast(coalesce(dates.maximum_claim_end_date, undetermined.claim_start_date) as date) as claim_end_date
    , cast(coalesce(claim_line_dates.normalized_claim_line_start_date, undetermined.claim_line_start_date) as date) as claim_line_start_date
    , cast(coalesce(claim_line_dates.normalized_claim_line_end_date, undetermined.claim_line_end_date) as date) as claim_line_end_date
    , cast(coalesce(dates.minimum_admission_date, undetermined.admission_date) as date) as admission_date
    , cast(coalesce(dates.maximum_discharge_date, undetermined.discharge_date) as date) as discharge_date
    , cast(coalesce(ad_source.normalized_code, undetermined.admit_source_code) as {{ dbt.type_string() }}) as admit_source_code
    , cast(coalesce(ad_source.normalized_description, undetermined.admit_source_description) as {{ dbt.type_string() }}) as admit_source_description
    , cast(coalesce(ad_type.normalized_code, undetermined.admit_type_code) as {{ dbt.type_string() }}) as admit_type_code
    , cast(coalesce(ad_type.normalized_description, undetermined.admit_type_description) as {{ dbt.type_string() }}) as admit_type_description
    , cast(coalesce(disch_disp.normalized_code, undetermined.discharge_disposition_code) as {{ dbt.type_string() }}) as discharge_disposition_code
    , cast(coalesce(disch_disp.normalized_description, undetermined.discharge_disposition_description) as {{ dbt.type_string() }}) as discharge_disposition_description
    , cast(coalesce(pos.normalized_code, undetermined.place_of_service_code) as {{ dbt.type_string() }}) as place_of_service_code
    , cast(coalesce(pos.normalized_description, undetermined.place_of_service_description) as {{ dbt.type_string() }}) as place_of_service_description
    , cast(coalesce(bill.normalized_code, undetermined.bill_type_code) as {{ dbt.type_string() }}) as bill_type_code
    , cast(coalesce(bill.normalized_description, undetermined.bill_type_description) as {{ dbt.type_string() }}) as bill_type_description
    , cast(med.drg_code_type as {{ dbt.type_string() }}) as drg_code_type
    , cast(coalesce(drg.normalized_code, undetermined.drg_code) as {{ dbt.type_string() }}) as drg_code
    , cast(coalesce(drg.normalized_description, undetermined.drg_description) as {{ dbt.type_string() }}) as drg_description
    , cast(coalesce(rev.normalized_code, undetermined.revenue_center_code) as {{ dbt.type_string() }}) as revenue_center_code
    , cast(coalesce(rev.normalized_description, undetermined.revenue_center_description) as {{ dbt.type_string() }}) as revenue_center_description
    , cast(med.service_unit_quantity as {{ dbt.type_numeric() }}) as service_unit_quantity
    , cast(med.hcpcs_code as {{ dbt.type_string() }}) as hcpcs_code
    , cast(med.hcpcs_modifier_1 as {{ dbt.type_string() }}) as hcpcs_modifier_1
    , cast(med.hcpcs_modifier_2 as {{ dbt.type_string() }}) as hcpcs_modifier_2
    , cast(med.hcpcs_modifier_3 as {{ dbt.type_string() }}) as hcpcs_modifier_3
    , cast(med.hcpcs_modifier_4 as {{ dbt.type_string() }}) as hcpcs_modifier_4
    , cast(med.hcpcs_modifier_5 as {{ dbt.type_string() }}) as hcpcs_modifier_5
    , cast(coalesce(med_npi.normalized_rendering_npi, undetermined.rendering_npi) as {{ dbt.type_string() }}) as rendering_npi
    , cast(med.rendering_tin as {{ dbt.type_string() }}) as rendering_tin
    , cast(coalesce(med_npi.normalized_rendering_name, undetermined.rendering_name) as {{ dbt.type_string() }}) as rendering_name
    , cast(coalesce(med_npi.normalized_billing_npi, undetermined.billing_npi) as {{ dbt.type_string() }}) as billing_npi
    , cast(med.billing_tin as {{ dbt.type_string() }}) as billing_tin
    , cast(coalesce(med_npi.normalized_billing_name, undetermined.billing_name) as {{ dbt.type_string() }}) as billing_name
    , cast(coalesce(med_npi.normalized_facility_npi, undetermined.facility_npi) as {{ dbt.type_string() }}) as facility_npi
    , cast(coalesce(med_npi.normalized_facility_name, undetermined.facility_name) as {{ dbt.type_string() }}) as facility_name
    , cast(med.paid_date as date) as paid_date
    , cast(med.paid_amount as {{ dbt.type_numeric() }}) as paid_amount
    , cast(med.allowed_amount as {{ dbt.type_numeric() }}) as allowed_amount
    , cast(med.charge_amount as {{ dbt.type_numeric() }}) as charge_amount
    , cast(med.coinsurance_amount as {{ dbt.type_numeric() }}) as coinsurance_amount
    , cast(med.copayment_amount as {{ dbt.type_numeric() }}) as copayment_amount
    , cast(med.deductible_amount as {{ dbt.type_numeric() }}) as deductible_amount
    , cast(med.total_cost_amount as {{ dbt.type_numeric() }}) as total_cost_amount
    , cast(med.paid_reduced_by as {{ dbt.type_numeric() }}) as paid_reduced_by
    , cast(med.diagnosis_code_type as {{ dbt.type_string() }}) as diagnosis_code_type
    {% for i in index_cols %}
    , cast(replace(med.diagnosis_code_{{ i }}, '.', '') as {{ dbt.type_string() }}) as diagnosis_code_{{ i }}
    {% endfor %}
    {% for i in index_cols %}
    , cast(med.diagnosis_poa_{{ i }} as {{ dbt.type_string() }}) as diagnosis_poa_{{ i }}
    {% endfor %}
    , cast(med.procedure_code_type as {{ dbt.type_string() }}) as procedure_code_type
    {% for i in index_cols %}
    , cast(coalesce(px_code.procedure_code_{{ i }}, undetermined.procedure_code_{{ i }}) as {{ dbt.type_string() }}) as procedure_code_{{ i }}
    {% endfor %}
    {% for i in index_cols %}
    , cast(coalesce(px_date.procedure_date_{{ i }}, undetermined.procedure_date_{{ i }}) as date) as procedure_date_{{ i }}
    {% endfor %}
    , cast(med.data_source as {{ dbt.type_string() }}) as data_source
    , cast(med.in_network_flag as {{ dbt.type_int() }}) as in_network_flag
    , cast(med.file_date as date) as file_date
    , cast(med.ingest_datetime as {{ dbt.type_timestamp() }}) as ingest_datetime
    , cast(med.file_name as {{ dbt.type_string() }}) as file_name
    , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
    {# The staging model is ephemeral and forwards this Input relation's extensions. #}
    {{ select_extension_columns(ref('input_layer__medical_claim'), alias='med', strip_prefix=false) }}
from {{ ref('normalized_input__stg_medical_claim') }} as med
left outer join {{ ref('normalized_input__int_admit_source_final') }} as ad_source
    on med.claim_id = ad_source.claim_id
    and med.data_source = ad_source.data_source
left outer join {{ ref('normalized_input__int_admit_type_final') }} as ad_type
    on med.claim_id = ad_type.claim_id
    and med.data_source = ad_type.data_source
left outer join {{ ref('normalized_input__int_bill_type_final') }} as bill
    on med.claim_id = bill.claim_id
    and med.data_source = bill.data_source
left outer join {{ ref('normalized_input__int_medical_claim_date_normalize') }} as claim_line_dates
    on med.claim_id = claim_line_dates.claim_id
    and med.claim_line_number = claim_line_dates.claim_line_number
    and med.data_source = claim_line_dates.data_source
left outer join {{ ref('normalized_input__int_medical_date_aggregation') }} as dates
    on med.claim_id = dates.claim_id
    and med.data_source = dates.data_source
left outer join {{ ref('normalized_input__int_medical_npi_normalize') }} as med_npi
    on med.claim_id = med_npi.claim_id
    and med.claim_line_number = med_npi.claim_line_number
    and med.data_source = med_npi.data_source
left outer join {{ ref('normalized_input__int_discharge_disposition_final') }} as disch_disp
    on med.claim_id = disch_disp.claim_id
    and med.data_source = disch_disp.data_source
left outer join {{ ref('normalized_input__int_drg_final') }} as drg
    on med.claim_id = drg.claim_id
    and med.data_source = drg.data_source
left outer join {{ ref('normalized_input__int_place_of_service_normalize') }} as pos
    on med.claim_id = pos.claim_id
    and med.claim_line_number = pos.claim_line_number
    and med.data_source = pos.data_source
left outer join {{ ref('normalized_input__int_procedure_code_final') }} as px_code
    on med.claim_id = px_code.claim_id
    and med.data_source = px_code.data_source
left outer join {{ ref('normalized_input__int_procedure_date_final') }} as px_date
    on med.claim_id = px_date.claim_id
    and med.data_source = px_date.data_source
left outer join {{ ref('normalized_input__int_revenue_center_normalize') }} as rev
    on med.claim_id = rev.claim_id
    and med.claim_line_number = rev.claim_line_number
    and med.data_source = rev.data_source
left outer join {{ ref('normalized_input__int_undetermined_claim_type') }} as undetermined
    on med.claim_id = undetermined.claim_id
    and med.claim_line_number = undetermined.claim_line_number
    and med.data_source = undetermined.data_source
