{% macro slugify(text) -%}

{{ text | replace(' ', '_') | lower }}

{%- endmacro %}