{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}


with normalize_cte as (
    select
        med.claim_id
        , med.data_source
        , disch.discharge_disposition_code
        , disch.discharge_disposition_description
    from {{ ref('normalized_input__stg_medical_claim') }} as med
    inner join {{ ref('terminology__discharge_disposition') }} as disch
        on {{ the_tuva_project.zero_pad_code('med.discharge_disposition_code', 2) }} = disch.discharge_disposition_code
    where claim_type = 'institutional'
)

, distinct_counts as (
    select
        claim_id
        , data_source
        , discharge_disposition_code
        , discharge_disposition_description
        , count(*) as discharge_disposition_occurrence_count
    from normalize_cte
    where discharge_disposition_code is not null
    group by
        claim_id
        , data_source
        , discharge_disposition_code
        , discharge_disposition_description
)

, occurence_comparison as (
    select
        claim_id
        , data_source
        , 'discharge_disposition_code' as column_name
        , discharge_disposition_code as normalized_code
        , discharge_disposition_description as normalized_description
        , discharge_disposition_occurrence_count as occurrence_count
        , coalesce(lead(discharge_disposition_occurrence_count)
            over (partition by claim_id, data_source
order by discharge_disposition_occurrence_count desc), 0) as next_occurrence_count
        , row_number() over (partition by claim_id, data_source
order by discharge_disposition_occurrence_count desc) as occurrence_row_count
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
