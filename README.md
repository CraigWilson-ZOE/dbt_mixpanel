[![Apache License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
# Mixpanel ([docs](https://fivetran-dbt-mixpanel.netlify.app/#!/overview))

This package models Mixpanel data from [Fivetran's connector](https://fivetran.com/docs/applications/mixpanel). It uses the Mixpanel `event` table in the format described by [this ERD](https://docs.google.com/presentation/d/1WA0gCAYBy2ASlCQCPNfD1rLgyrgwRwJ_FmxTIJ1QfY8/edit#slide=id.p).

This package enables you to better understand user activity and retention through your event data. To do this, the package:
- Creates both a daily and monthly timeline of each type of event, complete with metrics about user activity, retention, resurrection, and churn
- Aggregates events into unique user sessions, complete with metrics about event frequency and any relevant fields from the session's first event
- Provides a macro to easily create an event funnel
- De-duplicates events according to [best practices from Mixpanel](https://developer.mixpanel.com/reference/http#event-deduplication)
- Pivots out custom event properties from JSONs into an enriched events table

> The Mixpanel dbt package is compatible with BigQuery, Redshift, and Snowflake.

## Models

This package contains transformation models. The primary outputs of this package are described below. Intermediate models are used to create these output models and can be found in the models/staging folder.

| **model**                | **description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [mixpanel__event](https://github.com/fivetran/dbt_mixpanel/blob/master/models/mixpanel__event.sql)             | Each record represents a de-duplicated Mixpanel event. This includes the default event properties collected by Mixpanel, along with any declared custom columns and event-specific properties. |
| [mixpanel__daily_events](https://github.com/fivetran/dbt_mixpanel/blob/master/models/mixpanel__daily_events.sql)             | Each record represents a day's activity for a type of event, as reflected in user metrics. These include the number of new, repeat, and returning/resurrecting users, as well as trailing 7-day and 28-day unique users. |
| [mixpanel__monthly_events](https://github.com/fivetran/dbt_mixpanel/blob/master/models/mixpanel__monthly_events.sql)          | Each record represents a month of activity for a type of event, as reflected in user metrics. These include the number of new, repeat, returning/resurrecting, and churned users, as well as the total active monthly users (regardless of event type). |
| [mixpanel__sessions](https://github.com/fivetran/dbt_mixpanel/blob/master/models/mixpanel__sessions.sql)          | Each record represents a unique user session, including metrics reflecting the frequency and type of actions taken during the session and any relevant fields from the session's first event. |

## Macros
### analyze_funnel [(source)](https://github.com/fivetran/dbt_mixpanel/blob/master/macros/analyze_funnel.sql)
You can use the `analyze_funnel(event_funnel, group_by_column, conversion_criteria)` macro to produce a funnel between a given list of event types. 

It returns the following:
- The number of events and users at each step
- The overall user and event conversion % between the top of the funnel and each step
- The relative user and event conversion % between subsequent steps 
> Note: The relative order of the steps is determined by their event volume, not the order in which they are input.

The macro takes the following as arguments:
- `event_funnel`: List of event types (not case sensitive). 
  - Example: `'['play_song', 'stop_song', 'exit']`
- `group_by_column`: (Optional) A column by which you want to segment the funnel (this macro pulls data from the `mixpanel__event` model). The default value is `None`. 
  - Examaple: `group_by_column = 'country_code'`.
- `conversion_criteria`: (Optional) A `WHERE` clause that will be applied when selecting from `mixpanel__event`. 
  - Example: To limit all events in the funnel to the United States, you'd provide `conversion_criteria = 'country_code = "US"'`. To limit the events to only song play events to the US, you'd input `conversion_criteria = 'country_code = "US"' OR event_type != 'play_song'`.

## Installation Instructions
Check [dbt Hub](https://hub.getdbt.com/) for the latest installation instructions, or [read the dbt docs](https://docs.getdbt.com/docs/package-management) for more information on installing packages.

Include in your `packages.yml`

```yaml
packages:
  - package: fivetran/mixpanel
    version: [">=0.5.0", "<0.6.0"]
```

## Configuration
By default, this package looks for your Mixpanel data in the `mixpanel` schema of your [target database](https://docs.getdbt.com/docs/running-a-dbt-project/using-the-command-line-interface/configure-your-profile). If this is not where your Mixpanel data is, add the following configuration to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
config-version: 2

vars:
  mixpanel:
    mixpanel_database: your_database_name
    mixpanel_schema: your_schema_name 
```

### Pivoting Out Event Properties
By default, this package selects the [default columns collected by Mixpanel](https://help.mixpanel.com/hc/en-us/articles/115004613766-What-properties-do-Mixpanel-s-libraries-store-by-default-). However, you likely have custom properties or columns that you'd like to include in the `mixpanel__event` model.

If there are properties in the `mixpanel.event.properties` JSON blob that you'd like to pivot out into columns, add the following variable to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
config-version: 2

vars:
  mixpanel:
    event_properties_to_pivot: ['the', 'list', 'of', 'property', 'fields'] # Note: this is case-SENSITIVE and must match the casing of the property as it appears in the JSON
```

### Passthrough Columns

Additionally, this package includes all standard source `EVENT` columns defined in the `staging_columns` macro. You can add more columns using our passthrough column variables. These variables allow the passthrough fields to be aliased (`alias`) and casted (`transform_sql`) if desired, although it is not required. Data type casting is configured via a SQL snippet within the `transform_sql` key. You may add the desired SQL snippet while omitting the `as field_name` part of the casting statement - this will be dealt with by the alias attribute - and your custom passthrough fields will be casted accordingly.

Use the following format for declaring the respective passthrough variables:

```yml
# dbt_project.yml

vars:
  mixpanel:
    event_custom_columns:
      - name:           "property_field_id"
        alias:          "new_name_for_this_field_id"
        transform_sql:  "cast(property_field_id as int64)"
      - name:           "this_other_field"
        transform_sql:  "cast(this_other_field as string)"
```

### Event Date Range
Because of the typical volume of event data, you may want to limit this package's models to work with a recent date range of your Mixpanel data (however, note that all final models are materialized as [incremental](https://docs.getdbt.com/docs/building-a-dbt-project/building-models/materializations#incremental) tables).

By default, the package looks at all events since January 1, 2010. To change this start date, add the following variable to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
config-version: 2

vars:
  mixpanel:
    date_range_start: 'yyyy-mm-dd' 
```

**Note:** This date range will not affect the `number_of_new_users` column in the `mixpanel__daily_events` or `mixpanel__monthly_events` models. This metric will be *true* new users.

### Global Event Filters
In addition to limiting the date range, you may want to employ other filters to remove noise from your event data. 

To apply a global filter to events (and therefore **all** models in this package), add the following variable to your `dbt_project.yml` file. It will be applied as a `WHERE` clause when selecting from the source table, `mixpanel.event`. 

```yml
# dbt_project.yml

...
config-version: 2

vars:
  mixpanel:
    # Ex: removing internal user
    global_event_filter: 'distinct_id != "1234abcd"'
```

### Session Configurations
#### Session Inactivity Timeout
This package sessionizes events based on the periods of inactivity between a user's events on a device. By default, the package will denote a new session once the period between events surpasses **30 minutes**. 

To change this timeout value, add the following variable to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
config-version: 2

vars:
  mixpanel:
    sessionization_inactivity: number_of_minutes # ex: 60
```

#### Session Pass-Through Columns
By default, the `mixpanel__sessions` model will contain the following columns from `mixpanel__event`:
- `people_id`: The ID of the user
- `device_id`: The ID of the device they used in this session
- `event_frequencies`: A JSON of the frequency of each `event_type` in the session

To pass through any additional columns from the events table to `mixpanel__sessions`, add the following variable to your `dbt_project.yml` file. The value of each field will be pulled from the first event of the session.

```yml
# dbt_project.yml

...
config-version: 2

vars:
  mixpanel:
    session_passthrough_columns: ['the', 'list', 'of', 'column', 'names'] 
```

#### Session Event Criteria
In addition to any global event filters, you may want to disclude events or place filters on them in order to qualify for sessionization. 

To apply any filters to the events in the sessions model, add the following variable to your `dbt_project.yml` file. It will be applied as a `WHERE` clause when selecting from `mixpanel__event`.

```yml
# dbt_project.yml

...
config-version: 2

vars:
  mixpanel:

    # ex: limit sessions to include only these kinds of events
    session_event_criteria: 'event_type in ("play_song", "stop_song", "create_playlist")'
```

#### Session Trailing Window
Events can sometimes come late. For example, events triggered on a mobile device that is offline will be sent to Mixpanel once the device reconnects to wifi or a cell network. This makes sessionizing a bit trickier/costlier, as the sessions model (and all final models in this package) is materialized as an incremental table. 

Therefore, to avoid requiring a full refresh to incorporate these delayed events into sessions, the package by default re-sessionizes the most recent 3 hours of events on each run. To change this, add the following variable to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
config-version: 2

vars:
  mixpanel:
    sessionization_trailing_window: number_of_hours # ex: 12
```

### Changing the Build Schema
By default this package will build the Mixpanel staging models within a schema titled (<target_schema> + `_stg_mixpanel`) and Mixpanel final models within a schema titled (<target_schema> + `mixpanel`) in your target database. If this is not where you would like your modeled Mixpanel data to be written to, add the following configuration to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
models:
    mixpanel:
      +schema: my_new_schema_name # leave blank for just the target_schema
      staging:
        +schema: my_new_schema_name # leave blank for just the target_schema
```

## Event De-Duplication Logic

Events are considered duplicates and consolidated by the package if they contain the same:
* `insert_id` (used for de-deuplication internally by Mixpanel)
* `people_id` (originally named `distinct_id`)
* type of event
* calendar date of occurrence (event timestamps are set in the timezone the Mixpanel project is configured to)

This is performed in line with Mixpanel's internal de-duplication process, in which events are de-duped at the end of each day. This means that if an event was triggered during an offline session at 11:59 PM and _resent_ when the user came online at 12:01 AM, these records would _not_ be de-duplicated. This is the case in both Mixpanel and the Mixpanel dbt package.

## Contributions
Additional contributions to this package are very welcome! Please create issues
or open PRs against `main`. Check out 
[this post](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) 
on the best workflow for contributing to a package.

## Database Support
This package has been tested on BigQuery, Snowflake, Redshift, and Postgres.

## Resources:
- Provide [feedback](https://www.surveymonkey.com/r/DQ7K7WW) on our existing dbt packages or what you'd like to see next
- Have questions, feedback, or need help? Book a time during our office hours [using Calendly](https://calendly.com/fivetran-solutions-team/fivetran-solutions-team-office-hours) or email us at solutions@fivetran.com
- Find all of Fivetran's pre-built dbt packages in our [dbt hub](https://hub.getdbt.com/fivetran/)
- Learn how to orchestrate [dbt transformations with Fivetran](https://fivetran.com/docs/transformations/dbt)
- Learn more about Fivetran overall [in our docs](https://fivetran.com/docs)
- Check out [Fivetran's blog](https://fivetran.com/blog)
- Learn more about dbt [in the dbt docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](http://slack.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the dbt blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices
