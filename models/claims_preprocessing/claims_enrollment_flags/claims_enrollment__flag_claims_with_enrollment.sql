{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}


with claim_dates as (
    select
        claim_id
        , claim_line_number
        , person_id
        , member_id
        , payer
        , {{ quote_column('plan') }}
        , data_source
        , {{ selected_claim_date('claim_line_start_date', 'claim_start_date', 'admission_date', 'claim_end_date') }} as inferred_claim_start_date
        , case
            when claim_line_start_date is not null then 'claim_line_start_date'
            when claim_line_start_date is null and claim_start_date is not null then 'claim_start_date'
            when claim_line_start_date is null and claim_start_date is null and admission_date is not null then 'admission_date'
            when claim_line_start_date is null and claim_start_date is null and admission_date is null and claim_end_date is not null then 'claim_end_date'
        end as inferred_claim_start_column_used
    from {{ ref('normalized__medical_claim') }}
)

, claim_year_month as (
    select
          claim_id
        , claim_line_number
        , person_id
        , member_id
        , payer
        , {{ quote_column('plan') }}
        , data_source
        , inferred_claim_start_date
        , inferred_claim_start_column_used
        , {{ concat_custom([
            date_part('year', 'inferred_claim_start_date'),
            dbt.right(
                concat_custom([
                    "'0'",
                    date_part('month', 'inferred_claim_start_date'),
                ]),
                2
            )
        ]) }} as inferred_claim_start_year_month
from claim_dates
)

select distinct
     claim.claim_id
    , claim.claim_line_number
    , claim.person_id
    , claim.member_id
    , claim.payer
    , claim.{{ quote_column('plan') }}
    , claim.data_source
    , mm.member_month_id
    , claim.inferred_claim_start_year_month
    , claim.inferred_claim_start_column_used
    , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
from claim_year_month as claim
inner join {{ ref('member_month__member_month') }} as mm
    on mm.person_id = claim.person_id
    and mm.member_id = claim.member_id
    and mm.payer = claim.payer
    and mm.{{ quote_column('plan') }} = claim.{{ quote_column('plan') }}
    and mm.year_month = claim.inferred_claim_start_year_month
    and mm.data_source = claim.data_source
