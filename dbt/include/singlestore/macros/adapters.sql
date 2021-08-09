
{% macro singlestore__list_schemas(database) %}
    {% call statement('list_schemas', fetch_result=True, auto_begin=False) -%}
        select distinct schema_name
        from information_schema.schemata
    {%- endcall %}

    {{ return(load_result('list_schemas').table) }}
{% endmacro %}

{% macro singlestore__create_schema(relation) -%}
  {%- call statement('create_schema') -%}
    create schema if not exists {{ relation.without_identifier() }}
  {%- endcall -%}
{% endmacro %}

{% macro singlestore__drop_schema(relation) -%}
  {%- call statement('drop_schema') -%}
    drop schema if exists {{ relation.without_identifier() }}
  {% endcall %}
{% endmacro %}

{% macro singlestore__list_pipelines_without_caching(relation) -%}
    {% call statement('get_pipelines', fetch_result=True) %}
        SELECT
          NULL AS db
          database_name AS schema_name,
          pipeline_name AS identifier,
          'external' AS type
        FROM information_schema.PIPELINES
        WHERE  database_name='{{ relation.schema }}';
    {% endcall %}

    {% set table = load_result('get_pipelines').table %}
    {{ return(sql_convert_columns_in_relation(table)) }}
{% endmacro %}

{% macro singlestore__drop_relation(relation) -%}
    {% call statement('get_dependent_pipelines', fetch_result=True) %}
        SELECT
          database_name,
          pipeline_name
        FROM information_schema.PIPELINES
        WHERE JSON_EXTRACT_STRING(config_json, 'table') = '{{ relation.identifier }}'
          AND database_name='{{ relation.schema }}';
    {% endcall %}
    {% set table = load_result('get_dependent_pipelines').table %}
    {% call statement('drop_relation', auto_begin=False) -%}
      {% for row in table %}
        DROP PIPELINE {{ row.database_name }}.{{ row.pipeline_name }};
      {% endfor %}
      drop {{ relation.type }} if exists {{ relation }};
    {%- endcall %}
{% endmacro %}

{% macro singlestore__truncate_relation(relation) -%}
    {% call statement('truncate_relation') -%}
      truncate table {{ relation }}
    {%- endcall %}
{% endmacro %}

{% macro singlestore__create_table_as(temporary, relation, sql) -%}
  {%- set sql_header = config.get('sql_header', none) -%}

  {{ sql_header if sql_header is not none }}

  create {% if temporary: -%}temporary{%- endif %} table
    {{ relation.include(database=False) }}
  as
    {{ sql }}
{% endmacro %}

{% macro singlestore__current_timestamp() -%}
  current_timestamp()
{%- endmacro %}

{% macro singlestore__rename_relation(from_relation, to_relation) -%}
  {#
    MySQL rename fails when the relation already exists, so a 2-step process is needed:
    1. Drop the existing relation
    2. Rename the new relation to existing relation
  #}
  {% call statement('drop_relation') %}
    drop {{ to_relation.type }} if exists {{ to_relation }}
  {% endcall %}
  {% call statement('rename_relation') %}
    alter table {{ from_relation }} rename to {{ to_relation }}
  {% endcall %}
{% endmacro %}

{% macro singlestore__check_schema_exists(database, schema) -%}
    {# no-op #}
    {# see MySQLAdapter.check_schema_exists() #}
{% endmacro %}

{% macro singlestore__get_columns_in_relation(relation) -%}
    {% call statement('get_columns_in_relation', fetch_result=True) %}
        show columns from {{ relation.schema }}.{{ relation.identifier }}
    {% endcall %}

    {% set table = load_result('get_columns_in_relation').table %}
    {{ return(sql_convert_columns_in_relation(table)) }}
{% endmacro %}

{% macro singlestore__list_relations_without_caching(schema_relation) %}
  {% call statement('list_relations_without_caching', fetch_result=True) -%}
    select
      null as "database",
      table_name as name,
      table_schema as "schema",
      case when table_type = 'BASE TABLE' then 'table'
           when table_type = 'VIEW' then 'view'
           else table_type
      end as table_type
    from information_schema.tables
    where table_schema = '{{ schema_relation.schema }}'
  {% endcall %}
  {{ return(load_result('list_relations_without_caching').table) }}
{% endmacro %}

{% macro singlestore__list_pipelines_without_caching(schema_relation) %}
  {% call statement('list_pipelines_without_caching', fetch_result=True) -%}
    select
      null as "database",
      PIPELINE_NAME as name,
      DATABASE_NAME as "schema",
      'external' as table_type
    from information_schema.PIPELINES
    where DATABASE_NAME = '{{ schema_relation.schema }}'
  {% endcall %}
  {{ return(load_result('list_pipelines_without_caching').table) }}
{% endmacro %}

{% macro singlestore__generate_database_name(custom_database_name=none, node=none) -%}
  {% do return(None) %}
{%- endmacro %}
