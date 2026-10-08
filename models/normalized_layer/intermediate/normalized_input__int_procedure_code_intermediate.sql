{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}

-- Define the range of procedure columns to pivot (e.g., procedure_code_1 to procedure_code_25)
{% set procedure_cols = range(1, 26) %}

-- Pivot procedure columns into a long format
with pivot_procedure as (
    {% for i in procedure_cols %}
    select
        claim_id
        , claim_type
        , data_source
        , procedure_code_type
        , 'procedure_code_{{ i }}' as column_name
        , procedure_code_{{ i }} as procedure_code
    from {{ ref('normalized_input__stg_medical_claim') }}
    where procedure_code_{{ i }} is not null
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
)

-- Final output: distinct pivoted procedure records
select distinct
    claim_id
    , data_source
    , procedure_code_type
    , column_name
    , {{ the_tuva_project.clean_terminology_code('piv.procedure_code') }} as procedure_code
    , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
from pivot_procedure as piv
where claim_type = 'institutional'
