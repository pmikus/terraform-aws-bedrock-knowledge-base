output "knowledge_base_arn" {
  description = "Bedrock Knowledge Base ARN."
  value       = aws_bedrockagent_knowledge_base.this.arn
}

output "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID."
  value       = aws_bedrockagent_knowledge_base.this.id
}

output "query_engine_data_source_id" {
  description = "ID of the REDSHIFT_METADATA data source; pass it to StartIngestionJob to sync the query engine."
  value       = aws_bedrockagent_data_source.query_engine.data_source_id
}

output "service_role_arn" {
  description = "IAM service role used by the knowledge base to access Redshift."
  value       = aws_iam_role.knowledge-base-role.arn
}

output "redshift_database_user" {
  description = "Redshift database user that Bedrock signs in as."
  value       = "IAMR:${aws_iam_role.knowledge-base-role.name}"
}

output "redshift_bootstrap_sql" {
  description = "SQL an admin must run once in Redshift (Query Editor v2) before syncing the knowledge base."
  value = local.use_catalog ? join("\n", [
    "CREATE USER \"IAMR:${aws_iam_role.knowledge-base-role.name}\" WITH PASSWORD DISABLE;",
    "GRANT USAGE ON DATABASE awsdatacatalog TO \"IAMR:${aws_iam_role.knowledge-base-role.name}\";",
    ]) : join("\n", [
    "CREATE USER \"IAMR:${aws_iam_role.knowledge-base-role.name}\" WITH PASSWORD DISABLE;",
    "-- for each schema the knowledge base should read:",
    "GRANT USAGE ON SCHEMA <schema> TO \"IAMR:${aws_iam_role.knowledge-base-role.name}\";",
    "GRANT SELECT ON ALL TABLES IN SCHEMA <schema> TO \"IAMR:${aws_iam_role.knowledge-base-role.name}\";",
  ])
}
