resource "aws_bedrockagent_knowledge_base" "this" {
  name        = var.knowledge_base_name
  description = var.knowledge_base_description
  role_arn    = aws_iam_role.knowledge-base-role.arn

  tags = {
    Name        = "${var.app_name}-${var.app_environment}-bedrock-knowledge-base"
    Environment = var.app_environment
  }

  knowledge_base_configuration {
    type = "SQL"

    sql_knowledge_base_configuration {
      type = "REDSHIFT"

      redshift_configuration {
        # Query engine: Redshift Serverless, authenticated with the KB IAM role.
        query_engine_configuration {
          type = "SERVERLESS"

          serverless_configuration {
            workgroup_arn = var.redshift_workgroup_arn

            auth_configuration {
              type = "IAM"
            }
          }
        }

        # Structured data store the query engine reads metadata from.
        storage_configuration {
          type = var.storage_type

          dynamic "aws_data_catalog_configuration" {
            for_each = local.use_catalog ? [1] : []
            content {
              table_names = [for t in var.glue_table_names : "${var.glue_database_name}.${t}"]
            }
          }

          dynamic "redshift_configuration" {
            for_each = local.use_catalog ? [] : [1]
            content {
              database_name = var.redshift_database_name
            }
          }
        }

        dynamic "query_generation_configuration" {
          for_each = (var.query_execution_timeout_seconds != null || length(var.query_generation_tables) > 0 || length(var.curated_queries) > 0) ? [1] : []
          content {
            execution_timeout_seconds = var.query_execution_timeout_seconds

            dynamic "generation_context" {
              for_each = (length(var.query_generation_tables) > 0 || length(var.curated_queries) > 0) ? [1] : []
              content {
                dynamic "table" {
                  for_each = var.query_generation_tables
                  content {
                    name        = table.value.name
                    description = table.value.description
                    inclusion   = table.value.inclusion

                    dynamic "column" {
                      for_each = table.value.columns
                      content {
                        name        = column.value.name
                        description = column.value.description
                        inclusion   = column.value.inclusion
                      }
                    }
                  }
                }

                dynamic "curated_query" {
                  for_each = var.curated_queries
                  content {
                    natural_language = curated_query.value.natural_language
                    sql              = curated_query.value.sql
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [aws_iam_role_policy.knowledge-base-read]

  lifecycle {
    precondition {
      condition     = local.use_catalog ? (var.glue_database_name != null && length(var.glue_table_names) > 0 && var.s3_bucket_arn != null && length(var.s3_parquet_prefixes) > 0) : var.redshift_database_name != null
      error_message = "AWS_DATA_CATALOG needs glue_database_name, glue_table_names, s3_bucket_arn and s3_parquet_prefixes; REDSHIFT needs redshift_database_name."
    }
  }
}

resource "aws_bedrockagent_data_source" "query_engine" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.this.id
  name              = "${var.knowledge_base_name}-query-engine"
  description       = "Redshift query engine metadata for ${var.knowledge_base_name}"

  data_source_configuration {
    type = "REDSHIFT_METADATA"
  }
}

resource "aws_lakeformation_permissions" "database_describe" {
  count = local.use_catalog && var.manage_lake_formation_permissions ? 1 : 0

  principal   = aws_iam_role.knowledge-base-role.arn
  permissions = ["DESCRIBE"]

  database {
    name       = var.glue_database_name
    catalog_id = local.catalog_account_id
  }
}

resource "aws_lakeformation_permissions" "table_select" {
  for_each = local.use_catalog && var.manage_lake_formation_permissions ? toset(var.glue_table_names) : toset([])

  principal   = aws_iam_role.knowledge-base-role.arn
  permissions = ["SELECT"]

  table_with_columns {
    database_name = var.glue_database_name
    name          = each.value
    catalog_id    = local.catalog_account_id
    column_names  = try(var.lake_formation_column_allowlist[each.value], null)
    wildcard      = !contains(keys(var.lake_formation_column_allowlist), each.value)
  }
}
