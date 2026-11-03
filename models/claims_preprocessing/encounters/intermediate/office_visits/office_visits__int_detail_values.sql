{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}
with encounter_date as (
  select distinct old_encounter_id
  , start_date as encounter_start_date
  , 'office visit surgery' as encounter_type
  from {{ ref('office_visits__int_office_visits_surgery') }}

  union all

select distinct old_encounter_id
  , start_date as encounter_start_date
  , 'office visit injections' as encounter_type
  from {{ ref('office_visits__int_office_visits_injections') }}

  union all

select distinct old_encounter_id
  , start_date as encounter_start_date
  , 'office visit radiology' as encounter_type
  from {{ ref('office_visits__int_office_visits_radiology') }}

  union all

select distinct old_encounter_id
  , start_date as encounter_start_date
  , 'office visit - other' as encounter_type
  from {{ ref('office_visits__int_office_visits') }}

  union all

select distinct old_encounter_id
  , start_date as encounter_start_date
  , 'office visit' as encounter_type
  from {{ ref('office_visits__int_office_visits_em') }}

  union all

select distinct old_encounter_id
  , start_date as encounter_start_date
  , 'telehealth' as encounter_type
  from {{ ref('office_visits__int_office_visits_telehealth') }}

  union all

select distinct old_encounter_id
  , start_date as encounter_start_date
  , 'office visit pt/ot/st' as encounter_type
  from {{ ref('office_visits__int_office_visits') }}
)


    {# Avoid a Photon shuffled-hash-join failure when this join feeds row_number. #}
    select {{ the_tuva_project.merge_join_hint('d') }}
      stg.paid_amount
    , stg.allowed_amount
    , stg.charge_amount
    , stg.claim_id
    , stg.claim_type
    , stg.diagnosis_code_1
    , stg.diagnosis_code_type
    , stg.facility_npi
    , stg.billing_npi
    , stg.hcpcs_code
    , stg.ccs_category
    , stg.ccs_category_description
    , stg.claim_line_number
    , stg.patient_data_source_id
    , stg.data_source
    , cli.encounter_id
    , cli.old_encounter_id
    , cli.encounter_type
    , cli.encounter_group
    , d.encounter_start_date
    , row_number() over (partition by cli.encounter_id
order by stg.claim_type, stg.start_date) as encounter_row_number --institutional then professional
    from {{ ref('encounters__stg_medical_claim') }} as stg
    inner join {{ ref('encounters__combined_claim_line_crosswalk') }} as cli on stg.claim_id = cli.claim_id
    and
    stg.claim_line_number = cli.claim_line_number
    and
    stg.data_source = cli.data_source
    and
    cli.encounter_group = 'office based'
    and
    cli.claim_line_attribution_number = 1
    inner join encounter_date as d on cli.old_encounter_id = d.old_encounter_id
    and
    d.encounter_type = cli.encounter_type
