{% macro pivot_event_properties_json(list_of_properties) %}
{% for property in list_of_properties -%}

{%- if target.type == 'bigquery' -%}
replace(json_extract(event_properties, {{ "'$." ~ property ~ "'" }} ), '"', '')

{%- elif target.type == 'snowflake' -%}
replace(parse_json(event_properties):"{{ property }}", '"', '')

{%- elif target.type == 'redshift' -%}
replace(json_extract_path_text(event_properties, {{ "'" ~ property ~ "'" }} ), '"', '')

{%- elif target.type == 'postgres' -%}
replace(json_extract_path_text(event_properties, {{ "'" ~ property ~ "'" }} ), '"', '')
{% endif -%}

as {{ property | replace(' ', '_') | lower }}

{%- if not loop.last -%},{%- endif %}
{% endfor -%}
{% endmacro %}