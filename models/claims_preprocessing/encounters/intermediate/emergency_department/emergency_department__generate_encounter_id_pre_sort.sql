{{ config(
     enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false)
   )
}}

with claim_start_end as (
  select
      claim_id
    , patient_data_source_id
    , min(start_date) as start_date
    , max(end_date) as end_date
  from {{ ref('encounters__stg_medical_claim') }}
  group by claim_id, patient_data_source_id
)

, base as (
  select distinct
      enc.claim_id
    , enc.patient_data_source_id
    , c.start_date
    , coalesce(c.end_date, c.start_date) as end_date -- Avoids large length of stay gaps being combined
    , enc.facility_npi
    , enc.discharge_disposition_code
    , enc.claim_type  -- 'institutional' | 'professional'
  from {{ ref('encounters__stg_medical_claim') }} as enc
  inner join claim_start_end as c
    on enc.claim_id = c.claim_id
   and c.patient_data_source_id = enc.patient_data_source_id
  where enc.service_category_2 = 'emergency department' -- both inst and prof
)

, add_row_num as (
  select
      patient_data_source_id
    , claim_id
    , start_date
    , end_date
    , discharge_disposition_code
    , facility_npi
    , claim_type
    , case when claim_type = 'professional' then 1 else 0 end as is_professional
    , rank() over (
        partition by patient_data_source_id
        order by end_date, start_date, claim_id
      ) as row_num
  from base
)

, check_for_merges_with_larger_row_num as (
  select
      aa.patient_data_source_id
    , aa.claim_id as claim_id_a
    , bb.claim_id as claim_id_b
    , aa.row_num as row_num_a
    , bb.row_num as row_num_b
    , case
        -- 1) exact end-date match at the same facility (dups/corrections)
        when aa.end_date = bb.end_date
         and aa.facility_npi = bb.facility_npi then 1

        -- 2) consecutive stay with transfer (end_date + 1 day == next start_date and discharge '30')
        when {{ dbt.dateadd(datepart='day', interval=1, from_date_or_timestamp='aa.end_date') }} = bb.start_date
         and aa.facility_npi = bb.facility_npi
         and aa.discharge_disposition_code = '30' then 1

        -- 3) general overlap at the same facility
        when aa.end_date <> bb.end_date
         and aa.end_date >= bb.start_date
         and aa.facility_npi = bb.facility_npi then 1

        -- 4) liberal rule when at least one is PROFESSIONAL:
        -- overlap OR 1-day gap; ignore facility/discharge as professional doesn't have these fields.
        when (aa.is_professional = 1 or bb.is_professional = 1)
         and {{ dbt.dateadd(datepart='day', interval=1, from_date_or_timestamp='aa.end_date') }} >= bb.start_date then 1

        else 0
      end as merge_flag
  from add_row_num as aa
  inner join add_row_num as bb
    on aa.patient_data_source_id = bb.patient_data_source_id
   and aa.row_num < bb.row_num
   and aa.claim_id <> bb.claim_id
)



, merges_with_larger_row_num as (
  select
      patient_data_source_id
    , claim_id_a
    , claim_id_b
    , row_num_a
    , row_num_b
    , merge_flag
  from check_for_merges_with_larger_row_num
  where merge_flag = 1
)

, claim_ids_that_merge_with_larger_row_num as (
  select distinct
      patient_data_source_id
    , claim_id_a as claim_id
  from merges_with_larger_row_num
)

, claim_ids_having_a_smaller_row_num_merging_with_a_larger_row_num as (
  select distinct
      aa.patient_data_source_id
    , aa.claim_id as claim_id
  from add_row_num as aa
  inner join merges_with_larger_row_num as bb
    on aa.patient_data_source_id = bb.patient_data_source_id
    and bb.row_num_a < aa.row_num
    and bb.row_num_b > aa.row_num
)

, close_flags as (
  select
      aa.patient_data_source_id
    , aa.claim_id
    , aa.start_date
    , aa.end_date
    , aa.discharge_disposition_code
    , aa.facility_npi
    , aa.row_num
    , case
        when bb.claim_id is null
          and cc.claim_id is null then 1
        else 0
      end as close_flag
  from add_row_num as aa
  left outer join claim_ids_that_merge_with_larger_row_num as bb
    on aa.patient_data_source_id = bb.patient_data_source_id
    and aa.claim_id = bb.claim_id
  left outer join claim_ids_having_a_smaller_row_num_merging_with_a_larger_row_num as cc
    on aa.patient_data_source_id = cc.patient_data_source_id
    and aa.claim_id = cc.claim_id
)

, join_every_row_to_later_closes as (
  select
      aa.patient_data_source_id
    , aa.claim_id
    , aa.row_num
    , bb.row_num as row_num_b
  from close_flags as aa
  inner join close_flags as bb
    on aa.patient_data_source_id = bb.patient_data_source_id
    and aa.row_num <= bb.row_num
  where bb.close_flag = 1
)

, find_min_closing_row_num_for_every_claim as (
  select
      patient_data_source_id
    , claim_id
    , min(row_num_b) as min_closing_row
  from join_every_row_to_later_closes
  group by
      patient_data_source_id
    , claim_id
)

, add_min_closing_row_to_every_claim as (
  select
      aa.patient_data_source_id
    , aa.claim_id
    , aa.start_date
    , aa.end_date
    , aa.discharge_disposition_code
    , aa.facility_npi
    , aa.row_num
    , aa.close_flag
    , bb.min_closing_row
  from close_flags as aa
  left outer join find_min_closing_row_num_for_every_claim as bb
    on aa.patient_data_source_id = bb.patient_data_source_id
    and aa.claim_id = bb.claim_id
)


  select
      aa.patient_data_source_id
    , aa.claim_id
    , aa.start_date
    , aa.end_date
    , aa.discharge_disposition_code
    , aa.facility_npi
    , aa.row_num
    , aa.close_flag
    , aa.min_closing_row
    , bb.claim_id as encounter_id
  from add_min_closing_row_to_every_claim as aa
  left outer join add_min_closing_row_to_every_claim as bb
    on aa.patient_data_source_id = bb.patient_data_source_id
    and aa.min_closing_row = bb.row_num
