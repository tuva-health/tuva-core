{{ config(
     enabled = (the_tuva_project.tuva_boolean_var('claims_enabled', false))
       or (the_tuva_project.tuva_boolean_var('clinical_enabled', false)),
     severity = 'error',
     tags = ['contract', 'public_flag_contract']
   )
}}

{#
  Public fields ending in _flag are nullable binary integers. This contract
  covers Input Layer, Normalized outputs, public Claims Preprocessing outputs,
  and Core outputs. Internal working flags, Logical DQ result flags, and Data
  Asset or terminology attributes are intentionally out of scope.
#}

{% set claims_enabled = the_tuva_project.tuva_boolean_var('claims_enabled', false) %}
{% set clinical_enabled = the_tuva_project.tuva_boolean_var('clinical_enabled', false) %}
{% set contract_relations = [] %}

{% if claims_enabled %}
    {% do contract_relations.extend([
        {'model_name': 'input_layer__eligibility', 'flags': ['death_flag', 'hospice_flag', 'institutional_snp_flag', 'long_term_institutional_flag'], 'check_physical': false},
        {'model_name': 'input_layer__medical_claim', 'flags': ['in_network_flag'], 'check_physical': false},
        {'model_name': 'input_layer__pharmacy_claim', 'flags': ['in_network_flag'], 'check_physical': false},
        {'model_name': 'normalized__eligibility', 'flags': ['death_flag', 'hospice_flag', 'institutional_snp_flag', 'long_term_institutional_flag']},
        {'model_name': 'normalized__medical_claim', 'flags': ['in_network_flag']},
        {'model_name': 'normalized__pharmacy_claim', 'flags': ['in_network_flag']},
        {'model_name': 'core__eligibility', 'flags': ['hospice_flag', 'institutional_snp_flag', 'long_term_institutional_flag']},
        {'model_name': 'core__medical_claim', 'flags': ['in_network_flag', 'enrollment_flag']},
        {'model_name': 'core__pharmacy_claim', 'flags': ['in_network_flag', 'enrollment_flag']}
    ]) %}

    {% set cpp_common_flags = ['lab_flag', 'dme_flag', 'ambulance_flag', 'pharmacy_flag'] %}
    {% set cpp_observation_flags = cpp_common_flags + ['observation_flag'] %}
    {% set cpp_inpatient_flags = cpp_observation_flags + ['ed_flag', 'mortality_flag'] %}

    {% for model_name in ['ambulance__encounter_grain', 'asc__encounter_grain', 'dialysis__encounter_grain', 'dme__encounter_grain', 'home_health__encounter_grain', 'lab__encounter_grain', 'office_visit__encounter_grain', 'orphaned_claim__encounter_grain'] %}
        {% do contract_relations.append({'model_name': model_name, 'flags': cpp_common_flags}) %}
    {% endfor %}
    {% for model_name in ['outpatient_hospice__encounter_grain', 'outpatient_hospital_or_clinic__encounter_grain', 'outpatient_injections__encounter_grain', 'outpatient_psych__encounter_grain', 'outpatient_ptotst__encounter_grain', 'outpatient_radiology__encounter_grain', 'outpatient_rehab__encounter_grain', 'outpatient_substance_use__encounter_grain', 'outpatient_surgery__encounter_grain', 'urgent_care__encounter_grain'] %}
        {% do contract_relations.append({'model_name': model_name, 'flags': cpp_observation_flags}) %}
    {% endfor %}
    {% for model_name in ['inpatient_hospice__encounter_grain', 'inpatient_long_term__encounter_grain', 'inpatient_psych__encounter_grain', 'inpatient_rehab__encounter_grain', 'inpatient_substance_use__encounter_grain'] %}
        {% do contract_relations.append({'model_name': model_name, 'flags': cpp_inpatient_flags}) %}
    {% endfor %}
    {% do contract_relations.append({'model_name': 'emergency_department__encounter_grain', 'flags': cpp_observation_flags + ['mortality_flag']}) %}
    {% do contract_relations.append({'model_name': 'inpatient_snf__encounter_grain', 'flags': cpp_inpatient_flags + ['snf_part_b_flag']}) %}
    {% do contract_relations.append({'model_name': 'acute_inpatient__encounter_grain', 'flags': cpp_inpatient_flags + ['delivery_flag', 'newborn_flag', 'nicu_flag']}) %}
{% endif %}

{% if clinical_enabled %}
    {% do contract_relations.extend([
        {'model_name': 'input_layer__patient', 'flags': ['death_flag'], 'check_physical': false},
        {'model_name': 'normalized__patient', 'flags': ['death_flag']},
        {'model_name': 'normalized__encounter', 'flags': ['observation_flag', 'lab_flag', 'dme_flag', 'ambulance_flag', 'pharmacy_flag', 'ed_flag', 'delivery_flag', 'newborn_flag', 'nicu_flag', 'snf_part_b_flag']}
    ]) %}
{% endif %}

{% do contract_relations.extend([
    {'model_name': 'core__patient', 'flags': ['death_flag']},
    {'model_name': 'core__encounter', 'flags': ['observation_flag', 'lab_flag', 'dme_flag', 'ambulance_flag', 'pharmacy_flag', 'ed_flag', 'delivery_flag', 'newborn_flag', 'nicu_flag', 'snf_part_b_flag']}
]) %}

{% set mismatch_queries = [] %}

{% for contract_relation in contract_relations %}
    {# Calling ref outside the execute guard records the graph dependency. #}
    {% set relation = ref(contract_relation['model_name']) %}

    {% if execute %}
        {% set model_node = dq_find_model_node(contract_relation['model_name']) %}
        {% set actual_column_types = {} %}

        {% if contract_relation.get('check_physical', true) %}
            {% for actual_column in adapter.get_columns_in_relation(relation) %}
                {% do actual_column_types.update({actual_column.name | lower: actual_column.data_type}) %}
            {% endfor %}
        {% endif %}

        {% for flag_name in contract_relation['flags'] %}
            {% set documented_column = model_node.columns.get(flag_name) if model_node is not none else none %}
            {% set column_meta = documented_column.config.meta
                if documented_column is not none
                and documented_column.config is not none
                and documented_column.config.meta is not none
                else {} %}
            {% set declared_type = column_meta.get('data_type') %}

            {% if declared_type != 'integer' %}
                {% set metadata_query %}
                    select
                          {{ dq_string_literal_sql(contract_relation['model_name']) }} as public_model_name
                        , {{ dq_string_literal_sql(flag_name) }} as flag_column_name
                        , {{ dq_string_literal_sql('non_integer_or_missing_metadata') }} as mismatch_type
                        , {{ dq_string_literal_sql(declared_type) if declared_type is not none else 'cast(null as ' ~ dbt.type_string() ~ ')' }} as actual_value
                {% endset %}
                {% do mismatch_queries.append(metadata_query | trim) %}
            {% endif %}

            {% if contract_relation.get('check_physical', true) %}
                {# Some CPP model docs describe a shared superset of encounter
                   columns. Enforce the type when a documented flag is present;
                   column-presence validation belongs to Structural DQ. #}
                {% if flag_name in actual_column_types and dq_type_family(actual_column_types[flag_name]) != 'integer' %}
                    {% set type_query %}
                        select
                              {{ dq_string_literal_sql(contract_relation['model_name']) }} as public_model_name
                            , {{ dq_string_literal_sql(flag_name) }} as flag_column_name
                            , {{ dq_string_literal_sql('non_integer_physical_type') }} as mismatch_type
                            , {{ dq_string_literal_sql(actual_column_types[flag_name]) }} as actual_value
                    {% endset %}
                    {% do mismatch_queries.append(type_query | trim) %}
                {% endif %}
            {% endif %}
        {% endfor %}

        {% if contract_relation.get('check_physical', true) %}
            {% for actual_column_name in actual_column_types.keys() %}
                {% if actual_column_name.endswith('_flag') and actual_column_name not in contract_relation['flags'] %}
                    {% set unregistered_query %}
                        select
                              {{ dq_string_literal_sql(contract_relation['model_name']) }} as public_model_name
                            , {{ dq_string_literal_sql(actual_column_name) }} as flag_column_name
                            , {{ dq_string_literal_sql('unregistered_physical_flag') }} as mismatch_type
                            , {{ dq_string_literal_sql(actual_column_types[actual_column_name]) }} as actual_value
                    {% endset %}
                    {% do mismatch_queries.append(unregistered_query | trim) %}
                {% endif %}
            {% endfor %}
        {% endif %}
    {% endif %}
{% endfor %}

{% if mismatch_queries | length > 0 %}
    {{ mismatch_queries | join('\nunion all\n') }}
{% else %}
    select
          cast(null as {{ dbt.type_string() }}) as public_model_name
        , cast(null as {{ dbt.type_string() }}) as flag_column_name
        , cast(null as {{ dbt.type_string() }}) as mismatch_type
        , cast(null as {{ dbt.type_string() }}) as actual_value
    from (select 1 as _tuva_empty_fixture) as _tuva_empty_fixture
    where 1 = 0
{% endif %}
