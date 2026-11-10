{% macro normalize_ndc_lookup_code(expression) -%}
    {%- set code = 'cast(' ~ expression ~ ' as ' ~ dbt.type_string() ~ ')' -%}
    {%- set digits = "replace(" ~ code ~ ", '-', '')" -%}
    case
      when {{ the_tuva_project.length(digits) }} = 11
        then {{ digits }}
      -- The three ten-digit layouts identify which segment needs its leading zero.
      when {{ the_tuva_project.length(code) }} = 12
       and {{ the_tuva_project.length(digits) }} = 10
       and {{ the_tuva_project.substring(code, 5, 1) }} = '-'
       and {{ the_tuva_project.substring(code, 10, 1) }} = '-'
        then {{ the_tuva_project.concat_custom(["'0'", digits]) }}
      when {{ the_tuva_project.length(code) }} = 12
       and {{ the_tuva_project.length(digits) }} = 10
       and {{ the_tuva_project.substring(code, 6, 1) }} = '-'
       and {{ the_tuva_project.substring(code, 10, 1) }} = '-'
        then {{ the_tuva_project.concat_custom([
            the_tuva_project.substring(code, 1, 5), "'0'",
            the_tuva_project.substring(code, 7, 3),
            the_tuva_project.substring(code, 11, 2)
        ]) }}
      when {{ the_tuva_project.length(code) }} = 12
       and {{ the_tuva_project.length(digits) }} = 10
       and {{ the_tuva_project.substring(code, 6, 1) }} = '-'
       and {{ the_tuva_project.substring(code, 11, 1) }} = '-'
        then {{ the_tuva_project.concat_custom([
            the_tuva_project.substring(code, 1, 5),
            the_tuva_project.substring(code, 7, 4), "'0'",
            the_tuva_project.substring(code, 12, 1)
        ]) }}
      -- Raw ten-digit codes remain aliases; never guess their missing segment zero.
      else {{ code }}
    end
{%- endmacro %}
