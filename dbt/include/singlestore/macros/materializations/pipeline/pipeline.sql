{% materialization pipeline, adapter='singlestore' -%}
    {%- set identifier = model['alias'] -%}
    {%- set pipeline_identifier = config.get('pipeline_name', default=identifier ~ '_pipeline') -%}
    {%- set pipeline_name = api.Relation.create(schema=schema, identifier=pipeline_identifier, type=None) -%}
    {%- set run_mode = config.get('run_mode', default='FOREGROUND') -%}
    {%- set old_relation = adapter.get_relation(schema=schema, identifier=identifier) -%}
    {%- set old_pipeline = adapter.get_pipeline(schema=schema, identifier=pipeline_identifier) -%}
    {%- set target_relation = api.Relation.create(schema=schema, identifier=identifier, type='table') -%}
    {%- set full_refresh_mode = (flags.FULL_REFRESH == True) -%}
    {%- set created_relations = [] -%}

    {%- set should_drop = old_relation is not none and (full_refresh_mode or old_pipeline is none) -%}

    {{ run_hooks(pre_hooks, inside_transaction=False) }}

    -- `BEGIN` happens here:
    {{ run_hooks(pre_hooks, inside_transaction=True) }}

    -- setup
    {% if old_relation is none -%}
    -- noop
    {%- elif should_drop -%}
        {{ adapter.drop_relation(old_relation) }}
        {%- set old_relation = none -%}
    {%- endif %}

    {%- call statement('main') -%}
        {% if full_refresh_mode or old_relation is none -%}
            {#
                -- Create an empty table with columns as specified in sql.
                -- We append a unique invocation_id to ensure no files are actually loaded, and an empty row set is returned,
                -- which serves as a template to create the table.
            #}
            -- old_relation: {{old_relation}}
            -- old_pipeline: {{old_pipeline}}
            -- full_refresh_mode: {{full_refresh_mode}}
            -- should_drop: {{should_drop}}
            -- schema: {{schema}}
            -- identifier: {{identifier}}
            CREATE {{ 'ROWSTORE' if config.get('rowstore', default=false) else 'COLUMNSTORE' }} TABLE {{ target_relation }} {{ sql }}
            {% do created_relations.append(target_relation) %}
        {%- endif %}
    {%- endcall -%}
    {%- call statement('create-pipeline') -%}
        {% if full_refresh_mode or old_pipeline is none -%}
            CREATE OR REPLACE PIPELINE {{ pipeline_name }}
            AS LOAD DATA {{ config.require('provider') }} '{{ config.require("url") }}'
            CREDENTIALS '{{ config.require("credentials") }}'
            INTO TABLE {{ identifier }}
            FORMAT {{ config.get('file_format', default='CSV') }};
        {%- endif %}
    {%- endcall -%}
    {%- call statement('start-pipeline') -%}
        START PIPELINE {{pipeline_name}} {{run_mode}};
    {%- endcall -%}

    {{ run_hooks(post_hooks, inside_transaction=True) }}

    -- `COMMIT` happens here
    {{ adapter.commit() }}

    {{ run_hooks(post_hooks, inside_transaction=False) }}
    {{ return({'relations': [created_relations]}) }}
{%- endmaterialization %}
