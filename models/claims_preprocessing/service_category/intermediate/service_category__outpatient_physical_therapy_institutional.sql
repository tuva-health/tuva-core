{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}

select distinct
    med.claim_id
    , med.claim_line_number
    , med.data_source
    , 'outpatient' as service_category_1
    , 'outpatient pt/ot/st' as service_category_2
    , case med.ccs_category
        when '213' then 'outpatient physical therapy'
        when '212' then 'outpatient occupational therapy'
        when '215' then 'outpatient speech therapy'
        else 'outpatient pt/ot/st'
      end as service_category_3
    , '{{ this.name }}' as source_model_name
    , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
from {{ ref('service_category__stg_medical_claim') }} as med
inner join {{ ref('service_category__stg_outpatient_institutional') }} as o
  on med.claim_id = o.claim_id
  and med.data_source = o.data_source
where ccs_category in ('213', '212', '215')
