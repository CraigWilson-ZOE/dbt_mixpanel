# dbt_mixpanel v0.6.1
🎉 LISTAGG fix 🎉
## Fixes
- Redshift and Postgres warehouses have a limit to the amount of aggregation that may take place within certain functions. The `mixpanel__sessions` model currently performs a LISTAGG and customers have identified the aggregation sometimes exceeds the limit of the function. Therefore, a conditional was added to check if the target type is Redshift or Postgres. If it is either, it will only perform the aggregation if the count is less than the amount defined by the `mixpanel__event_frequency_limit` (default 1000) variable. Otherwise, it will return 'Too many event types to render'. ([#27](https://github.com/fivetran/dbt_mixpanel/pull/27))
# dbt_mixpanel v0.6.0
🎉 dbt v1.0.0 Compatibility 🎉
## 🚨 Breaking Changes 🚨
- Adjusts the `require-dbt-version` to now be within the range [">=1.0.0", "<2.0.0"]. Additionally, the package has been updated for dbt v1.0.0 compatibility. If you are using a dbt version <1.0.0, you will need to upgrade in order to leverage the latest version of the package.
  - For help upgrading your package, I recommend reviewing this GitHub repo's Release Notes on what changes have been implemented since your last upgrade.
  - For help upgrading your dbt project to dbt v1.0.0, I recommend reviewing dbt-labs [upgrading to 1.0.0 docs](https://docs.getdbt.com/docs/guides/migration-guide/upgrading-to-1-0-0) for more details on what changes must be made.
- Upgrades the package dependency to refer to the latest `dbt_fivetran_utils`. The latest `dbt_fivetran_utils` package also has a dependency on `dbt_utils` [">=0.8.0", "<0.9.0"].
  - Please note, if you are installing a version of `dbt_utils` in your `packages.yml` that is not in the range above then you will encounter a package dependency error.

# dbt_mixpanel v0.1.0 -> v0.5.0
Refer to the relevant release notes on the Github repository for specific details for the previous releases. Thank you!
