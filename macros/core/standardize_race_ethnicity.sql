{% macro standardize_race_ethnicity(race_column, ethnicity_column) -%}
{#
    Derives a single standardized race/ethnicity category aligned with the
    2024 OMB SPD 15 (Statistical Policy Directive No. 15) minimum categories:

        - American Indian or Alaska Native
        - Asian
        - Black or African American
        - Hispanic or Latino
        - Middle Eastern or North African
        - Native Hawaiian or Pacific Islander
        - White

    Tuva stores race and ethnicity as separate fields, so this macro collapses
    them into one standardized category using a Hispanic-ethnicity-first
    convention: when ethnicity indicates Hispanic or Latino the category is
    'Hispanic or Latino', otherwise the mapped race category is used. This is a
    pragmatic single-column rollup; the OMB 2024 standard itself favors a
    combined multi-select question where a person can report more than one
    category.

    Values that cannot be classified into an OMB minimum category (other race,
    asked but unknown, unknown, or missing) are returned as null.

    Middle Eastern or North African is a new OMB 2024 minimum category that does
    not exist in the legacy Tuva race terminology, so it is only produced when a
    source explicitly supplies it. Existing race and ethnicity columns are left
    unchanged; this derivation is purely additive.

    Arguments:
        race_column: name/expression of the race column (Tuva race description).
        ethnicity_column: name/expression of the ethnicity column.
#}
case
    when lower(trim(cast({{ ethnicity_column }} as {{ dbt.type_string() }}))) like 'hispanic%'
      or lower(trim(cast({{ ethnicity_column }} as {{ dbt.type_string() }}))) = 'latino'
        then 'Hispanic or Latino'
    when lower(trim(cast({{ race_column }} as {{ dbt.type_string() }}))) = 'white'
        then 'White'
    when lower(trim(cast({{ race_column }} as {{ dbt.type_string() }}))) = 'black or african american'
        then 'Black or African American'
    when lower(trim(cast({{ race_column }} as {{ dbt.type_string() }}))) = 'asian'
        then 'Asian'
    when lower(trim(cast({{ race_column }} as {{ dbt.type_string() }}))) = 'american indian or alaska native'
        then 'American Indian or Alaska Native'
    when lower(trim(cast({{ race_column }} as {{ dbt.type_string() }}))) in ('native hawaiian or other pacific islander', 'native hawaiian or pacific islander')
        then 'Native Hawaiian or Pacific Islander'
    when lower(trim(cast({{ race_column }} as {{ dbt.type_string() }}))) in ('middle eastern or north african', 'mena')
        then 'Middle Eastern or North African'
    else null
end
{%- endmacro %}
