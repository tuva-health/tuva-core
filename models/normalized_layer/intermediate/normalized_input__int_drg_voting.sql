{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}

with normalize_cte as (
    select
        med.claim_id
        , med.data_source
        , med.drg_code_type
        , coalesce(msdrg.ms_drg_code, aprdrg.apr_drg_code) as drg_code
        , coalesce(msdrg.ms_drg_description, aprdrg.apr_drg_description) as drg_description
    from {{ ref('normalized_input__stg_medical_claim') }} as med
    left outer join {{ ref('terminology__ms_drg') }} as msdrg
        on med.drg_code_type = 'ms-drg'
        and {{ the_tuva_project.zero_pad_code('med.drg_code', 3) }} = msdrg.ms_drg_code
    left outer join {{ ref('terminology__apr_drg') }} as aprdrg
        on med.drg_code_type = 'apr-drg'
        and {{ the_tuva_project.zero_pad_code('med.drg_code', 3) }} = aprdrg.apr_drg_code
    where claim_type = 'institutional'
)

, distinct_counts as (
    select
        claim_id
        , data_source
        , drg_code
        , drg_description
        , count(*) as drg_occurrence_count
    from normalize_cte
    where drg_code is not null
    group by
        claim_id
        , data_source
        , drg_code
        , drg_description
)

, occurence_comparison as (
    select
        claim_id
        , data_source
        , 'drg_code' as column_name
        , drg_code as normalized_code
        , drg_description as normalized_description
        , drg_occurrence_count as occurrence_count
        , coalesce(lead(drg_occurrence_count)
            over (partition by claim_id, data_source
order by drg_occurrence_count desc), 0) as next_occurrence_count
        , row_number() over (partition by claim_id, data_source
order by drg_occurrence_count desc) as occurrence_row_count
    from distinct_counts as dist
)

select
    claim_id
    , data_source
    , column_name
    , normalized_code
    , normalized_description
    , occurrence_count
    , next_occurrence_count
    , occurrence_row_count
    , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
from occurence_comparison
