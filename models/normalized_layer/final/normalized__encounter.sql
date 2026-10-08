{{ config(
     enabled = the_tuva_project.tuva_boolean_var('clinical_enabled', false)
   )
}}

{%- set tuva_core_columns -%}
      cast(enc.encounter_id as {{ dbt.type_string() }}) as encounter_id
    , cast(enc.person_id as {{ dbt.type_string() }}) as person_id
    , cast(enc.encounter_type as {{ dbt.type_string() }}) as encounter_type
    , cast(encounter_type_lookup.encounter_group as {{ dbt.type_string() }}) as encounter_group
    , enc.normalized_encounter_start_date as encounter_start_date
    , enc.normalized_encounter_end_date as encounter_end_date
    , cast(
        case
            when enc.normalized_encounter_start_date is null
              or enc.normalized_encounter_end_date is null
                then null
            when {{ dbt.datediff("enc.normalized_encounter_start_date", "enc.normalized_encounter_end_date", "day") }} = 0
                then 1
            else {{ dbt.datediff("enc.normalized_encounter_start_date", "enc.normalized_encounter_end_date", "day") }}
        end as {{ dbt.type_int() }}
      ) as length_of_stay
    , cast(enc.admit_source_code as {{ dbt.type_string() }}) as admit_source_code
    , cast(admit_source.admit_source_description as {{ dbt.type_string() }}) as admit_source_description
    , cast(enc.admit_type_code as {{ dbt.type_string() }}) as admit_type_code
    , cast(admit_type.admit_type_description as {{ dbt.type_string() }}) as admit_type_description
    , cast(coalesce(
          discharge_disposition.discharge_disposition_code
        , cast(enc.discharge_disposition_code as {{ dbt.type_string() }})
      ) as {{ dbt.type_string() }}) as discharge_disposition_code
    , cast(discharge_disposition.discharge_disposition_description as {{ dbt.type_string() }}) as discharge_disposition_description
    , cast(enc.attending_provider_id as {{ dbt.type_string() }}) as attending_provider_id
    , cast(enc.attending_provider_name as {{ dbt.type_string() }}) as attending_provider_name
    , cast(enc.facility_npi as {{ dbt.type_string() }}) as facility_npi
    , cast(enc.facility_name as {{ dbt.type_string() }}) as facility_name
    , cast(null as {{ dbt.type_string() }}) as facility_type
    , cast(null as {{ dbt.type_int() }}) as observation_flag
    , cast(null as {{ dbt.type_int() }}) as lab_flag
    , cast(null as {{ dbt.type_int() }}) as dme_flag
    , cast(null as {{ dbt.type_int() }}) as ambulance_flag
    , cast(null as {{ dbt.type_int() }}) as pharmacy_flag
    , cast(null as {{ dbt.type_int() }}) as ed_flag
    , cast(null as {{ dbt.type_int() }}) as delivery_flag
    , cast(null as {{ dbt.type_string() }}) as delivery_type
    , cast(null as {{ dbt.type_int() }}) as newborn_flag
    , cast(null as {{ dbt.type_int() }}) as nicu_flag
    , cast(null as {{ dbt.type_int() }}) as snf_part_b_flag
    , cast(enc.primary_diagnosis_code_type as {{ dbt.type_string() }}) as primary_diagnosis_code_type
    , cast(enc.primary_diagnosis_code as {{ dbt.type_string() }}) as primary_diagnosis_code
    , cast(coalesce(icd10.long_description, icd9.long_description) as {{ dbt.type_string() }}) as primary_diagnosis_description
    , cast(enc.drg_code_type as {{ dbt.type_string() }}) as drg_code_type
    , cast(coalesce(
          msdrg.ms_drg_code
        , aprdrg.apr_drg_code
        , cast(enc.drg_code as {{ dbt.type_string() }})
      ) as {{ dbt.type_string() }}) as drg_code
    , cast(coalesce(msdrg.ms_drg_description, aprdrg.apr_drg_description) as {{ dbt.type_string() }}) as drg_description
    , cast(enc.paid_amount as {{ dbt.type_numeric() }}) as paid_amount
    , cast(enc.allowed_amount as {{ dbt.type_numeric() }}) as allowed_amount
    , cast(enc.charge_amount as {{ dbt.type_numeric() }}) as charge_amount
    , cast(null as {{ dbt.type_int() }}) as claim_count
    , cast(null as {{ dbt.type_int() }}) as inst_claim_count
    , cast(null as {{ dbt.type_int() }}) as prof_claim_count
    , cast(null as {{ dbt.type_string() }}) as source_model
    , cast('clinical' as {{ dbt.type_string() }}) as encounter_source_type
{%- endset -%}

{%- set tuva_metadata_columns -%}
    , cast(enc.ingest_datetime as {{ dbt.type_timestamp() }}) as ingest_datetime
    , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
    , cast(enc.data_source as {{ dbt.type_string() }}) as data_source
{%- endset %}

{%- set tuva_extension_columns -%}
    {{ select_extension_columns(ref('input_layer__encounter'), alias='enc', strip_prefix=false) }}
{%- endset %}

with enc as (
    select
        encounter.*
        , {{ try_to_cast_date('encounter.encounter_start_date', 'YYYY-MM-DD') }} as normalized_encounter_start_date
        , {{ try_to_cast_date('encounter.encounter_end_date', 'YYYY-MM-DD') }} as normalized_encounter_end_date
    from {{ ref('input_layer__encounter') }} as encounter
)

select
    {{ tuva_core_columns }}
    {{ tuva_extension_columns }}
    {{ tuva_metadata_columns }}
from enc
left outer join {{ ref('terminology__encounter_type') }} as encounter_type_lookup
    on cast(enc.encounter_type as {{ dbt.type_string() }})
        = cast(encounter_type_lookup.encounter_type as {{ dbt.type_string() }})
left outer join {{ ref('terminology__admit_source') }} as admit_source
    on cast(enc.admit_source_code as {{ dbt.type_string() }}) = admit_source.admit_source_code
left outer join {{ ref('terminology__admit_type') }} as admit_type
    on cast(enc.admit_type_code as {{ dbt.type_string() }}) = admit_type.admit_type_code
left outer join {{ ref('terminology__discharge_disposition') }} as discharge_disposition
    on {{ the_tuva_project.zero_pad_code('cast(enc.discharge_disposition_code as ' ~ dbt.type_string() ~ ')', 2) }} = discharge_disposition.discharge_disposition_code
left outer join {{ ref('terminology__icd_10_cm') }} as icd10
    on lower(cast(enc.primary_diagnosis_code_type as {{ dbt.type_string() }})) = 'icd-10-cm'
    and {{ the_tuva_project.clean_terminology_code('cast(enc.primary_diagnosis_code as ' ~ dbt.type_string() ~ ')') }} = icd10.icd_10_cm
left outer join {{ ref('terminology__icd_9_cm') }} as icd9
    on lower(cast(enc.primary_diagnosis_code_type as {{ dbt.type_string() }})) = 'icd-9-cm'
    and {{ the_tuva_project.clean_terminology_code('cast(enc.primary_diagnosis_code as ' ~ dbt.type_string() ~ ')') }} = icd9.icd_9_cm
left outer join {{ ref('terminology__ms_drg') }} as msdrg
    on lower(cast(enc.drg_code_type as {{ dbt.type_string() }})) = 'ms-drg'
    and {{ the_tuva_project.zero_pad_code('cast(enc.drg_code as ' ~ dbt.type_string() ~ ')', 3) }} = msdrg.ms_drg_code
left outer join {{ ref('terminology__apr_drg') }} as aprdrg
    on lower(cast(enc.drg_code_type as {{ dbt.type_string() }})) = 'apr-drg'
    and {{ the_tuva_project.zero_pad_code('cast(enc.drg_code as ' ~ dbt.type_string() ~ ')', 3) }} = aprdrg.apr_drg_code
