{{
    config(
        materialized='incremental',
        unique_key='session_id',
        partition_by={'field': 'session_started_on_day', 'data_type': 'date'} if target.type not in ('spark','databricks') else ['session_started_on_day'],
        incremental_strategy = 'merge' if target.type not in ('postgres', 'redshift') else 'delete+insert',
        file_format = 'delta' 
    )
}}

-- need to grab all events for relevant users
with events as (

    select 
        event_type,
        occurred_at,
        unique_event_id,
        people_id,
        date_day,
        device_id,
        coalesce(device_id, people_id) as user_id

        {% if var('session_passthrough_columns', []) != [] %}
        ,
        {{ var('session_passthrough_columns', [] ) | join(', ') }}
        {% endif %}

    from {{ ref('mixpanel__event') }}

    -- remove any events, etc
    where {{ var('session_event_criteria', 'true') }} 

    {% if is_incremental() %}

    -- grab ALL events for each user to appropriately use window functions to sessionize
    and coalesce(device_id, people_id) in (

        select distinct coalesce(device_id, people_id)
        from {{ ref('mixpanel__event') }}

        -- events can come in late and we want to still be able to incorporate them
        -- in the sessionization without requiring a full refresh
        where occurred_at >= cast (coalesce((
          select
            {{ dbt.dateadd(
                'hour',
                -var('sessionization_trailing_window', 3),
                'max(session_started_at)'
            ) }}
          from {{ this }} ), '2010-01-01') as {{ dbt.type_timestamp() }} )
    )

    {% endif %}
),

previous_event as (

    select 
        *,
        -- limiting session-eligibility to same calendar day
        lag(occurred_at) over(partition by user_id, date_day order by occurred_at asc) as previous_event_at

    from events 

),

new_sessions as (
    
    select 
        *,
        -- had the previous session timed out? Either via inactivity or a new calendar day occurring
        case when {{ dbt.datediff('previous_event_at', 'occurred_at', 'minute') }} > {{ var('sessionization_inactivity', 30) }} or previous_event_at is null then 1
        else 0 end as is_new_session

    from previous_event
),

session_numbers as (

    select *,

    -- will cumulatively create session numbers
    sum(is_new_session) over (
            partition by user_id, date_day
            order by occurred_at asc
            rows between unbounded preceding and current row
            ) as session_number

    from new_sessions
),

session_ids as (

    select
        *,
        min(occurred_at) over (partition by user_id, date_day, session_number) as session_started_at,
        min(date_day) over (partition by user_id, date_day, session_number) as session_started_on_day,

        {{ dbt_utils.generate_surrogate_key(['user_id', 'session_number', 'date_day']) }} as session_id,

        count(unique_event_id) over (partition by user_id, date_day, session_number, event_type order by occurred_at rows between unbounded preceding and unbounded following) as number_of_this_event_type,
        count(unique_event_id) over (partition by user_id, date_day, session_number order by occurred_at rows between unbounded preceding and unbounded following) as total_number_of_events


    from session_numbers

),

agg_event_types as (

    select 
        session_id,
        -- turn into json
        {% if target.type in ('postgres','redshift') %}
        case when count(event_type) <= {{ var('mixpanel__event_frequency_limit', 1000) }} 
            then '{' || {{ fivetran_utils.string_agg("(event_type || ': ' || number_of_events)", "', '") }} || '}' 
            else 'Too many event types to render' 
        end
        {% else %}
        '{' || {{ fivetran_utils.string_agg("(event_type || ': ' || number_of_events)", "', '") }} || '}'
        {% endif %} as event_frequencies
    
    from (

        select
            session_id,
            event_type,
            count(unique_event_id) as number_of_events

        from session_ids
        group by session_id, event_type
    
    ) as sub group by session_id
), 

session_join as (

    select 
        session_ids.session_id,
        session_ids.people_id,
        session_ids.session_started_at,
        session_ids.session_started_on_day,
        session_ids.user_id, -- coalescing of device_id and peeople_id
        session_ids.device_id,
        session_ids.total_number_of_events,
        agg_event_types.event_frequencies

        {% if var('session_passthrough_columns', []) != [] %}
        ,
        {{ var('session_passthrough_columns', [] )  | join(', ') }}
        {% endif %}
    
    from session_ids
    join agg_event_types using(session_id) -- join regardless of event type 

    where session_ids.is_new_session = 1 -- only return fields of first event

)

select * from session_join
