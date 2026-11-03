{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false),
     severity = 'error',
     tags = ['normalized_layer', 'medical_claim_diagnosis_contract']
   )
}}

{#
  Claim type classifies a claim for downstream algorithms; it does not decide
  whether a populated diagnosis is usable. Reconcile the canonical diagnosis
  relation to all 25 source positions at the normalized claim-line grain so a
  future classification predicate cannot silently delete diagnosis facts.

  claim_line_number is nullable and a null line must match a null line. That
  null-safe match is spelled as two plain equalities on derived keys
  (claim_line_number_key, claim_line_number_is_null) rather than
  `a = b or (a is null and b is null)`. An OR in the join condition is not an
  equi-join, so engines such as DuckDB fall back to a nested-loop join that is
  quadratic in the number of diagnosis rows.
#}

{% set diagnosis_cols = range(1, 26) %}

with expected_slots as (
    {% for i in diagnosis_cols %}
    select
          medical_claim_id
        , claim_id
        , claim_line_number
        , data_source
        , {{ i }} as condition_rank
        , 'diagnosis_code_{{ i }}' as diagnosis_column
        , replace(diagnosis_code_{{ i }}, '.', '') as source_code
        , coalesce(claim_line_number, 0) as claim_line_number_key
        , case when claim_line_number is null then 1 else 0 end as claim_line_number_is_null
    from {{ ref('normalized__medical_claim') }}
    where diagnosis_code_{{ i }} is not null
    {% if not loop.last %}union all{% endif %}
    {% endfor %}
)

, actual_slots as (
    select distinct
          medical_claim_id
        , claim_id
        , claim_line_number
        , data_source
        , condition_rank
        , diagnosis_column
        , source_code
        , coalesce(claim_line_number, 0) as claim_line_number_key
        , case when claim_line_number is null then 1 else 0 end as claim_line_number_is_null
    from {{ ref('normalized__medical_claim_diagnoses') }}
)

, missing_slots as (
    select
          'missing_normalized_diagnosis' as failure_type
        , expected.medical_claim_id
        , expected.claim_id
        , expected.claim_line_number
        , expected.data_source
        , expected.condition_rank
        , expected.diagnosis_column
        , expected.source_code
    from expected_slots as expected
    left join actual_slots as actual
        on expected.medical_claim_id = actual.medical_claim_id
        and expected.claim_id = actual.claim_id
        and expected.claim_line_number_key = actual.claim_line_number_key
        and expected.claim_line_number_is_null = actual.claim_line_number_is_null
        and expected.data_source = actual.data_source
        and expected.condition_rank = actual.condition_rank
        and expected.diagnosis_column = actual.diagnosis_column
        and expected.source_code = actual.source_code
    where actual.medical_claim_id is null
)

, unexpected_slots as (
    select
          'unexpected_normalized_diagnosis' as failure_type
        , actual.medical_claim_id
        , actual.claim_id
        , actual.claim_line_number
        , actual.data_source
        , actual.condition_rank
        , actual.diagnosis_column
        , actual.source_code
    from actual_slots as actual
    left join expected_slots as expected
        on actual.medical_claim_id = expected.medical_claim_id
        and actual.claim_id = expected.claim_id
        and actual.claim_line_number_key = expected.claim_line_number_key
        and actual.claim_line_number_is_null = expected.claim_line_number_is_null
        and actual.data_source = expected.data_source
        and actual.condition_rank = expected.condition_rank
        and actual.diagnosis_column = expected.diagnosis_column
        and actual.source_code = expected.source_code
    where expected.medical_claim_id is null
)

select *
from missing_slots

union all

select *
from unexpected_slots
