{#

    Cleans an ICD or HCPCS code for matching against Tuva terminology.

    Terminology codes are upper case with no decimal point and no surrounding
    whitespace, so a source value that differs only in case, spacing, or a
    decimal point still matches. A value that is absent from terminology after
    cleaning still fails to match.

#}

{% macro clean_terminology_code(expression) %}
  upper({{ the_tuva_project.trim("replace(" ~ expression ~ ", '.', '')") }})
{% endmacro %}
