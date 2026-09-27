{{ config(
     enabled = (the_tuva_project.tuva_boolean_var('data_quality_enabled', false))
       and ((the_tuva_project.tuva_boolean_var('claims_enabled', false)) or (the_tuva_project.tuva_boolean_var('clinical_enabled', false))),
     severity = 'error',
     tags = ['data_quality', 'dq_logical']
   )
}}

with temporal_input_columns as (
    select
          input_table_name
        , input_column_name
    from {{ ref('data_quality__input_layer_catalog') }}
    where expected_type_family in ('date', 'timestamp')
)

, absolute_range_tests as (
    select
          test_columns.input_table_name
        , test_columns.input_column_name
        , count(*) as test_count
        , min(test_catalog.test_type) as minimum_test_type
        , max(test_catalog.test_type) as maximum_test_type
        , min(test_catalog.severity) as minimum_severity
        , max(test_catalog.severity) as maximum_severity
    from {{ ref('data_quality__logical_test_input_columns') }} as test_columns
    inner join {{ ref('data_quality__logical_test_catalog') }} as test_catalog
        on test_columns.test_name = test_catalog.test_name
       and test_columns.input_table_name = test_catalog.input_table_name
    where test_catalog.flag_column_name in (
          {{ concat_custom([
              'test_columns.input_column_name',
              dq_string_literal_sql('_outside_supported_date_range')
          ]) }}
        , {{ concat_custom([
              'test_columns.input_column_name',
              dq_string_literal_sql('_out_of_reasonable_range')
          ]) }}
        , {{ concat_custom([
              'test_columns.input_column_name',
              dq_string_literal_sql('_out_of_range')
          ]) }}
    )
    group by
          test_columns.input_table_name
        , test_columns.input_column_name
)

, temporal_column_counts as (
    select
          sum(case when input_catalog.expected_type_family = 'date' then 1 else 0 end) as date_column_count
        , sum(case when input_catalog.expected_type_family = 'timestamp' then 1 else 0 end) as timestamp_column_count
    from {{ ref('data_quality__input_layer_catalog') }} as input_catalog
    where input_catalog.expected_type_family in ('date', 'timestamp')
)

, coverage_violations as (
    select
          temporal_input_columns.input_table_name
        , temporal_input_columns.input_column_name
        , coalesce(absolute_range_tests.test_count, 0) as test_count
        , absolute_range_tests.minimum_test_type
        , absolute_range_tests.maximum_test_type
        , absolute_range_tests.minimum_severity
        , absolute_range_tests.maximum_severity
    from temporal_input_columns
    left join absolute_range_tests
        on temporal_input_columns.input_table_name = absolute_range_tests.input_table_name
       and temporal_input_columns.input_column_name = absolute_range_tests.input_column_name
    where coalesce(absolute_range_tests.test_count, 0) <> 1
       or absolute_range_tests.minimum_test_type <> 'invalid'
       or absolute_range_tests.maximum_test_type <> 'invalid'
       or absolute_range_tests.minimum_severity <> 2
       or absolute_range_tests.maximum_severity <> 2
)

select *
from coverage_violations

{% if (the_tuva_project.tuva_boolean_var('claims_enabled', false))
      and (the_tuva_project.tuva_boolean_var('clinical_enabled', false))
      and (the_tuva_project.tuva_boolean_var('provider_attribution_enabled', false)) %}
union all

select
      '__catalog_contract__' as input_table_name
    , 'date' as input_column_name
    , date_column_count as test_count
    , cast(null as {{ dbt.type_string() }}) as minimum_test_type
    , cast(null as {{ dbt.type_string() }}) as maximum_test_type
    , cast(null as {{ dbt.type_int() }}) as minimum_severity
    , cast(null as {{ dbt.type_int() }}) as maximum_severity
from temporal_column_counts
where date_column_count <> 53

union all

select
      '__catalog_contract__' as input_table_name
    , 'timestamp' as input_column_name
    , timestamp_column_count as test_count
    , cast(null as {{ dbt.type_string() }}) as minimum_test_type
    , cast(null as {{ dbt.type_string() }}) as maximum_test_type
    , cast(null as {{ dbt.type_int() }}) as minimum_severity
    , cast(null as {{ dbt.type_int() }}) as maximum_severity
from temporal_column_counts
where timestamp_column_count <> 19
{% endif %}
