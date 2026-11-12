{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}

/*
  Orphan encounter dates must come only from the source-specific claim lines
  assigned to that encounter. Reused claim IDs in another source must not
  widen the encounter date range.
*/

with expected as (
  select
      orphan.encounter_id
    , min(claim.start_date) as encounter_start_date
    , max(
        case
          when claim.end_date >= claim.start_date then claim.end_date
          else claim.start_date
        end
      ) as encounter_end_date
  from {{ ref('encounters__stg_medical_claim') }} as claim
  inner join {{ ref('encounters__orphaned_claims') }} as orphan
    on claim.claim_id = orphan.claim_id
    and claim.claim_line_number = orphan.claim_line_number
    and claim.data_source = orphan.data_source
  group by orphan.encounter_id
)

, actual as (
  select
      encounter_id
    , encounter_start_date
    , encounter_end_date
  from {{ ref('orphaned_claim__encounter_grain') }}
)

select
    coalesce(expected.encounter_id, actual.encounter_id) as encounter_id
  , expected.encounter_start_date as expected_start_date
  , actual.encounter_start_date as actual_start_date
  , expected.encounter_end_date as expected_end_date
  , actual.encounter_end_date as actual_end_date
from expected
full outer join actual
  on expected.encounter_id = actual.encounter_id
where expected.encounter_id is null
   or actual.encounter_id is null
   or (expected.encounter_start_date is null and actual.encounter_start_date is not null)
   or (expected.encounter_start_date is not null and actual.encounter_start_date is null)
   or expected.encounter_start_date <> actual.encounter_start_date
   or (expected.encounter_end_date is null and actual.encounter_end_date is not null)
   or (expected.encounter_end_date is not null and actual.encounter_end_date is null)
   or expected.encounter_end_date <> actual.encounter_end_date
