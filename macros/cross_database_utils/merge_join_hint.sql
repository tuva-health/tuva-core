{% macro merge_join_hint(relation_alias) -%}
  {{ return(adapter.dispatch('merge_join_hint', 'the_tuva_project')(relation_alias)) }}
{%- endmacro %}

{% macro default__merge_join_hint(relation_alias) -%}
  {{ return('') }}
{%- endmacro %}

{% macro databricks__merge_join_hint(relation_alias) -%}
  {{ return('/*+ MERGE(' ~ relation_alias ~ ') */') }}
{%- endmacro %}
