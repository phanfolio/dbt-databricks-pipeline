{# Helper: turns ONE salary fragment (e.g. '$80K') into a number #}
{% macro _parse_salary_segment(segment) %}
    TRY_CAST(REPLACE(REGEXP_EXTRACT({{ segment }}, '([0-9][0-9,.]*)', 1), ',', '') AS DECIMAL(15, 2))
      * CASE UPPER(REGEXP_EXTRACT({{ segment }}, '[0-9][0-9,.]*([KkMm])', 1))
            WHEN 'K' THEN 1000
            WHEN 'M' THEN 1000000
            ELSE 1
        END
{% endmacro %}

{#
  parse_salary(part)
    Reads the `job_salary` column of whatever query it is used in.
    part = 'min' | 'max' | 'avg'  -> numeric
           'period' | 'currency'  -> text
#}
{% macro parse_salary(part) %}
    {%- set min_segment = "SPLIT(job_salary, '–')[0]" -%}
    {%- set max_segment = "ELEMENT_AT(SPLIT(job_salary, '–'), -1)" -%}

    {%- if part == 'min' -%}
        {{ _parse_salary_segment(min_segment) }}

    {%- elif part == 'max' -%}
        {{ _parse_salary_segment(max_segment) }}

    {%- elif part == 'avg' -%}
        ({{ _parse_salary_segment(min_segment) }} + {{ _parse_salary_segment(max_segment) }}) / 2

    {#- pay period, read off the end of the text: 'a year', 'an hour' -#}
    {%- elif part == 'period' -%}
        NULLIF(REGEXP_EXTRACT(job_salary, 'an? (year|hour|month|day|week)$', 1), '')

    {#- currency marker; a salaried row with no marker is stamped USD on purpose -#}
    {%- elif part == 'currency' -%}
        CASE
            WHEN job_salary IS NOT NULL
            THEN COALESCE(NULLIF(TRIM(REGEXP_EXTRACT(job_salary, '^([^0-9]+)', 1)), ''), 'USD')
        END

    {%- else -%}
        {{ exceptions.raise_compiler_error(
            "parse_salary: part must be 'min', 'max', 'avg', 'period' or 'currency', got '" ~ part ~ "'"
        ) }}
    {%- endif -%}
{% endmacro %}