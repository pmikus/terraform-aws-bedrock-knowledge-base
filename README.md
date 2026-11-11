# Bedrock Knowledge Base with a structured data store (Redshift query engine)

Creates an Amazon Bedrock Knowledge Base of type `SQL` that uses a Redshift Serverless workgroup as its **query engine**, plus a dedicated IAM service role. Bedrock turns natural-language questions into SQL, runs that SQL on Redshift as the service role, and returns the results.

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.41.0, < 7.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.41.0, < 7.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_bedrockagent_data_source.query_engine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagent_data_source) | resource |
| [aws_bedrockagent_knowledge_base.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagent_knowledge_base) | resource |
| [aws_iam_role.knowledge-base-role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.knowledge-base-read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lakeformation_permissions.database_describe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) | resource |
| [aws_lakeformation_permissions.table_select](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lakeformation_permissions) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.knowledge-base-read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.knowledge-base-role-trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_app_environment"></a> [app\_environment](#input\_app\_environment) | Application environment, used in names and tags. | `string` | n/a | yes |
| <a name="input_app_name"></a> [app\_name](#input\_app\_name) | Application name, used as a prefix for the IAM role and policy names. | `string` | n/a | yes |
| <a name="input_curated_queries"></a> [curated\_queries](#input\_curated\_queries) | Optional example natural-language questions with their SQL, to guide query generation. | <pre>list(object({<br/>    natural_language = string<br/>    sql              = string<br/>  }))</pre> | `[]` | no |
| <a name="input_glue_catalog_account_id"></a> [glue\_catalog\_account\_id](#input\_glue\_catalog\_account\_id) | Account ID owning the Glue catalog; defaults to the current account. | `string` | `null` | no |
| <a name="input_glue_database_name"></a> [glue\_database\_name](#input\_glue\_database\_name) | Glue database containing the tables (used when storage\_type = AWS\_DATA\_CATALOG). | `string` | `null` | no |
| <a name="input_glue_table_names"></a> [glue\_table\_names](#input\_glue\_table\_names) | Glue tables the knowledge base may query (used when storage\_type = AWS\_DATA\_CATALOG). | `list(string)` | `[]` | no |
| <a name="input_knowledge_base_description"></a> [knowledge\_base\_description](#input\_knowledge\_base\_description) | Optional description of the Bedrock Knowledge Base. | `string` | `null` | no |
| <a name="input_knowledge_base_name"></a> [knowledge\_base\_name](#input\_knowledge\_base\_name) | Name of the Bedrock Knowledge Base. | `string` | n/a | yes |
| <a name="input_lake_formation_column_allowlist"></a> [lake\_formation\_column\_allowlist](#input\_lake\_formation\_column\_allowlist) | Optional per-table SELECT column allowlists. Tables omitted receive SELECT on all columns. | `map(set(string))` | `{}` | no |
| <a name="input_manage_lake_formation_permissions"></a> [manage\_lake\_formation\_permissions](#input\_manage\_lake\_formation\_permissions) | Grant the knowledge base role Lake Formation DESCRIBE on the Glue database and SELECT on the tables (AWS\_DATA\_CATALOG only). | `bool` | `true` | no |
| <a name="input_query_execution_timeout_seconds"></a> [query\_execution\_timeout\_seconds](#input\_query\_execution\_timeout\_seconds) | Optional timeout for SQL generated and run by the knowledge base. Null leaves the service default. | `number` | `null` | no |
| <a name="input_query_generation_tables"></a> [query\_generation\_tables](#input\_query\_generation\_tables) | Optional table/column descriptions to improve SQL generation. Names are passed to Bedrock as-is (for example "awsdatacatalog.csit.stats"). | <pre>list(object({<br/>    name        = string<br/>    description = optional(string)<br/>    inclusion   = optional(string)<br/>    columns = optional(list(object({<br/>      name        = string<br/>      description = optional(string)<br/>      inclusion   = optional(string)<br/>    })), [])<br/>  }))</pre> | `[]` | no |
| <a name="input_redshift_database_name"></a> [redshift\_database\_name](#input\_redshift\_database\_name) | Redshift database used when storage\_type = REDSHIFT. | `string` | `null` | no |
| <a name="input_redshift_workgroup_arn"></a> [redshift\_workgroup\_arn](#input\_redshift\_workgroup\_arn) | ARN of the Redshift Serverless workgroup used as the query engine. | `string` | n/a | yes |
| <a name="input_s3_bucket_arn"></a> [s3\_bucket\_arn](#input\_s3\_bucket\_arn) | ARN of the bucket holding the Parquet data behind the Glue tables (used when storage\_type = AWS\_DATA\_CATALOG). | `string` | `null` | no |
| <a name="input_s3_parquet_prefixes"></a> [s3\_parquet\_prefixes](#input\_s3\_parquet\_prefixes) | S3 key prefixes holding the table data, without leading/trailing slashes (used when storage\_type = AWS\_DATA\_CATALOG). | `list(string)` | `[]` | no |
| <a name="input_storage_type"></a> [storage\_type](#input\_storage\_type) | Where the knowledge base reads table metadata from: AWS\_DATA\_CATALOG (Glue Data Catalog, queried via Redshift's awsdatacatalog) or REDSHIFT (a Redshift database). | `string` | `"AWS_DATA_CATALOG"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_knowledge_base_arn"></a> [knowledge\_base\_arn](#output\_knowledge\_base\_arn) | Bedrock Knowledge Base ARN. |
| <a name="output_knowledge_base_id"></a> [knowledge\_base\_id](#output\_knowledge\_base\_id) | Bedrock Knowledge Base ID. |
| <a name="output_query_engine_data_source_id"></a> [query\_engine\_data\_source\_id](#output\_query\_engine\_data\_source\_id) | ID of the REDSHIFT\_METADATA data source; pass it to StartIngestionJob to sync the query engine. |
| <a name="output_redshift_bootstrap_sql"></a> [redshift\_bootstrap\_sql](#output\_redshift\_bootstrap\_sql) | SQL an admin must run once in Redshift (Query Editor v2) before syncing the knowledge base. |
| <a name="output_redshift_database_user"></a> [redshift\_database\_user](#output\_redshift\_database\_user) | Redshift database user that Bedrock signs in as. |
| <a name="output_service_role_arn"></a> [service\_role\_arn](#output\_service\_role\_arn) | IAM service role used by the knowledge base to access Redshift. |
<!-- END_TF_DOCS -->