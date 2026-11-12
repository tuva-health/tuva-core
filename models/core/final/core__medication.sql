{{ config(
     enabled = (the_tuva_project.tuva_boolean_var('claims_enabled', false))
            or (the_tuva_project.tuva_boolean_var('clinical_enabled', false))
   )
}}

{%- set tuva_extension_columns_from_all_medications -%}
{% if the_tuva_project.tuva_boolean_var('clinical_enabled', false) %}
    {{ select_extension_columns(ref('normalized__medication'), alias='meds', strip_prefix=false) }}
{% endif %}
{%- endset -%}

{%- set tuva_extension_columns_from_source_mapping -%}
{% if the_tuva_project.tuva_boolean_var('clinical_enabled', false) %}
    {{ select_extension_columns(ref('normalized__medication'), alias='sm') }}
{% endif %}
{%- endset -%}

{%- set tuva_metadata_columns -%}
   , ingest_datetime
   , tuva_last_run
   , data_source
{%- endset -%}

{%- set use_coderx_enterprise = the_tuva_project.tuva_boolean_var('use_coderx_enterprise', false) -%}

with coderx_package_key_candidates as (
    select
          ndc11 as ndc_lookup_code
        , ndc11
        , drug_id
        , drug_name
    from {{ ref('core__stg_coderx_packages') }}

    union all

    select
          replace(ndc, '-', '') as ndc_lookup_code
        , ndc11
        , drug_id
        , drug_name
    from {{ ref('core__stg_coderx_packages') }}
    -- Only ten-digit aliases are eligible; malformed aliases cannot shadow an NDC11.
    where {{ the_tuva_project.length("replace(ndc, '-', '')") }} = 10
),

coderx_package_keys as (
    select
          ndc_lookup_code
        , min(ndc11) as ndc11
        , min(drug_id) as drug_id
        , min(drug_name) as drug_name
    from (
        select distinct ndc_lookup_code, ndc11, drug_id, drug_name
        from coderx_package_key_candidates
    ) as distinct_package_keys
    group by ndc_lookup_code
    -- An unsegmented ten-digit code can identify different packages, even for one drug.
    having count(*) = 1
),

all_medications as (
{% if the_tuva_project.tuva_boolean_var('clinical_enabled', false)
    and the_tuva_project.tuva_boolean_var('claims_enabled', false) -%}

    {{ smart_union([ref('core__stg_claims_medication'), ref('normalized__medication')]) }}

{% elif the_tuva_project.tuva_boolean_var('clinical_enabled', false) -%}

    select *
    from {{ ref('normalized__medication') }}

{% elif the_tuva_project.tuva_boolean_var('claims_enabled', false) -%}

    select *
    from {{ ref('core__stg_claims_medication') }}

{%- endif %}
),

source_mapping as (
    select
          meds.medication_id
        , meds.source_type
        , meds.person_id
        , meds.member_id
        , meds.patient_id
        , meds.encounter_id
        , meds.claim_id
        , meds.claim_line_number
        , meds.payer
        , meds.{{ quote_column('plan') }}
        , meds.dispensing_date
        , meds.prescribing_date
        , meds.source_code_type
        , meds.source_code
        , case
            when lower(cast(meds.source_type as {{ dbt.type_string() }})) = 'claims'
              then source_package.drug_name
            else meds.source_description
          end as source_description
        , coalesce(meds.ndc_code, source_package.ndc11) as ndc_code
        , meds.ndc_description
        , coalesce(meds.rxnorm_code, source_drug.drug_id) as rxnorm_code
        , meds.atc_code
        , meds.route
        , meds.strength
        , meds.quantity
        , meds.quantity_unit
        , meds.days_supply
        , meds.practitioner_id
        , meds.data_source
        , meds.ingest_datetime
        , meds.tuva_last_run
        {{ tuva_extension_columns_from_all_medications }}
    from all_medications as meds
    left join coderx_package_keys as source_package
        on lower(cast(meds.source_code_type as {{ dbt.type_string() }})) = 'ndc'
       and {{ the_tuva_project.normalize_ndc_lookup_code('meds.source_code') }}
           = source_package.ndc_lookup_code
    left join {{ ref('core__stg_coderx_drugs') }} as source_drug
        on lower(cast(meds.source_code_type as {{ dbt.type_string() }})) = 'rxnorm'
       and cast(meds.source_code as {{ dbt.type_string() }}) = source_drug.drug_id
)

select
      sm.medication_id
    , sm.source_type
    , sm.person_id
    , sm.member_id
    , sm.patient_id
    , sm.encounter_id
    , sm.claim_id
    , sm.claim_line_number
    , sm.payer
    , sm.{{ quote_column('plan') }}
    , sm.dispensing_date
    , sm.prescribing_date
    , sm.source_code_type
    , sm.source_code
    , sm.source_description
    , sm.ndc_code
    , coalesce(
          case
            when coalesce(lower(sm.source_type), '') <> 'claims' then sm.ndc_description
          end
        , ndc_package.drug_name
        {% if not use_coderx_enterprise %}
        , sm.ndc_description
        {% endif %}
      ) as ndc_description
    , coalesce(sm.rxnorm_code, ndc_package.drug_id) as rxnorm_code
    , case
        when sm.rxnorm_code is not null then rxnorm_drug.drug_name
        else coalesce(rxnorm_drug.drug_name, ndc_package.drug_name)
      end as rxnorm_description
    , coalesce(sm.atc_code, drug_class.atc_3_code) as atc_code
    , case
        when sm.atc_code is null then drug_class.atc_3_name
        when sm.atc_code = drug_class.atc_1_code then drug_class.atc_1_name
        when sm.atc_code = drug_class.atc_2_code then drug_class.atc_2_name
        when sm.atc_code = drug_class.atc_3_code then drug_class.atc_3_name
        when sm.atc_code = drug_class.atc_4_code then drug_class.atc_4_name
      end as atc_description
    , sm.route
    , sm.strength
    , sm.quantity
    , sm.quantity_unit
    , sm.days_supply
    , sm.practitioner_id
    {{ tuva_extension_columns_from_source_mapping }}
    {{ tuva_metadata_columns }}
from source_mapping as sm
left join coderx_package_keys as ndc_package
    on {{ the_tuva_project.normalize_ndc_lookup_code('sm.ndc_code') }}
       = ndc_package.ndc_lookup_code
left join {{ ref('core__stg_coderx_drugs') }} as rxnorm_drug
    on coalesce(sm.rxnorm_code, ndc_package.drug_id) = rxnorm_drug.drug_id
left join {{ ref('core__stg_coderx_classes') }} as drug_class
    on coalesce(sm.rxnorm_code, ndc_package.drug_id) = drug_class.drug_id
