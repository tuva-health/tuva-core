{#
    selected_claim_date — the single explicit contract for which date selects
    a medical claim line's calendar month.

    Both claims enrollment flagging
    (claims_enrollment__flag_claims_with_enrollment) and Core cost
    (int_cost_service_categories) consume this contract, so a claim line is
    always assigned to the same month for enrollment/member-month attribution
    and for PMPM cost reporting. Previously the two models disagreed: cost
    used coalesce(claim_start_date, claim_end_date) while enrollment used the
    line-level hierarchy, so a cross-month line could be enrolled in one month
    while its spend was reported in another. See #1140.

    Selection order:
      1. claim_line_start_date — most granular; the line's own service date.
      2. claim_start_date      — header-level start.
      3. admission_date        — facility-claim fallback.
      4. claim_end_date        — final fallback for end-date-only sources
                                 (e.g. CMS LDS) that carry no start dates.

    Usage: {{ selected_claim_date('claim_line_start_date', 'claim_start_date', 'admission_date', 'claim_end_date') }}
#}

{% macro selected_claim_date(claim_line_start_date, claim_start_date, admission_date, claim_end_date) -%}
    coalesce({{ claim_line_start_date }}, {{ claim_start_date }}, {{ admission_date }}, {{ claim_end_date }})
{%- endmacro %}
