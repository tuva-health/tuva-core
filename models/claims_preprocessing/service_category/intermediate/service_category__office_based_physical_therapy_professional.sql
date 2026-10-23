{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}

select distinct
    med.claim_id
    , med.claim_line_number
    , med.data_source
    , med.claim_line_id
    , 'office-based' as service_category_1
    , 'office-based pt/ot/st' as service_category_2
    , case
        when med.ccs_category = '213' then 'office-based physical therapy'
        when med.ccs_category = '212' then 'office-based occupational therapy'
        when med.ccs_category = '215' then 'office-based speech therapy'
        when med.rend_primary_specialty_description in (
            'Physical Therapist'
            , 'Physical Therapist in Private Practice'
            , 'Physical Therapy Assistant'
        ) then 'office-based physical therapy'
        when med.rend_primary_specialty_description in (
            'Occupational Health'
            , 'Occupational Medicine'
            , 'Occupational Therapist in Private Practice'
            , 'Occupational Therapy Assistant'
        ) then 'office-based occupational therapy'
        when med.rend_primary_specialty_description in (
            'Speech Language Pathologist'
            , 'Speech-Language Assistant'
        ) then 'office-based speech therapy'
        else 'office-based pt/ot/st'
      end as service_category_3
    , '{{ this.name }}' as source_model_name
    , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
from {{ ref('service_category__stg_medical_claim') }} as med
inner join {{ ref('service_category__stg_office_based') }} as prof
    on med.claim_id = prof.claim_id
    and med.claim_line_number = prof.claim_line_number
    and med.data_source = prof.data_source
where (
    med.ccs_category in ('213', '212', '215')
    or med.rend_primary_specialty_description in (
        'Occupational Health'
        , 'Occupational Medicine'
        , 'Occupational Therapist in Private Practice'
        , 'Occupational Therapy Assistant'
        , 'Physical Therapist'
        , 'Physical Therapist in Private Practice'
        , 'Physical Therapy Assistant'
        , 'Speech Language Pathologist'
        , 'Speech-Language Assistant'
        ))
    and med.place_of_service_code = '11'
