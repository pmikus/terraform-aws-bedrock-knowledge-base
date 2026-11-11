variable "app_name" {
  description = "Application name, used as a prefix for the IAM role and policy names."
  type        = string
}

variable "app_environment" {
  description = "Application environment, used in names and tags."
  type        = string
}

variable "knowledge_base_name" {
  description = "Name of the Bedrock Knowledge Base."
  type        = string
}

variable "knowledge_base_description" {
  description = "Optional description of the Bedrock Knowledge Base."
  type        = string
  default     = null
}

variable "redshift_workgroup_arn" {
  description = "ARN of the Redshift Serverless workgroup used as the query engine."
  type        = string
}

variable "query_execution_timeout_seconds" {
  description = "Optional timeout for SQL generated and run by the knowledge base. Null leaves the service default."
  type        = number
  default     = null
}

variable "storage_type" {
  description = "Where the knowledge base reads table metadata from: AWS_DATA_CATALOG (Glue Data Catalog, queried via Redshift's awsdatacatalog) or REDSHIFT (a Redshift database)."
  type        = string
  default     = "AWS_DATA_CATALOG"
  validation {
    condition     = contains(["AWS_DATA_CATALOG", "REDSHIFT"], var.storage_type)
    error_message = "storage_type must be AWS_DATA_CATALOG or REDSHIFT."
  }
}

variable "redshift_database_name" {
  description = "Redshift database used when storage_type = REDSHIFT."
  type        = string
  default     = null
}

variable "glue_database_name" {
  description = "Glue database containing the tables (used when storage_type = AWS_DATA_CATALOG)."
  type        = string
  default     = null
}

variable "glue_table_names" {
  description = "Glue tables the knowledge base may query (used when storage_type = AWS_DATA_CATALOG)."
  type        = list(string)
  default     = []
}

variable "glue_catalog_account_id" {
  description = "Account ID owning the Glue catalog; defaults to the current account."
  type        = string
  default     = null
  nullable    = true
}

variable "s3_bucket_arn" {
  description = "ARN of the bucket holding the Parquet data behind the Glue tables (used when storage_type = AWS_DATA_CATALOG)."
  type        = string
  default     = null
}

variable "s3_parquet_prefixes" {
  description = "S3 key prefixes holding the table data, without leading/trailing slashes (used when storage_type = AWS_DATA_CATALOG)."
  type        = list(string)
  default     = []
}

variable "manage_lake_formation_permissions" {
  description = "Grant the knowledge base role Lake Formation DESCRIBE on the Glue database and SELECT on the tables (AWS_DATA_CATALOG only)."
  type        = bool
  default     = true
}

variable "lake_formation_column_allowlist" {
  description = "Optional per-table SELECT column allowlists. Tables omitted receive SELECT on all columns."
  type        = map(set(string))
  default     = {}
}

variable "query_generation_tables" {
  description = "Optional table/column descriptions to improve SQL generation. Names are passed to Bedrock as-is (for example \"awsdatacatalog.csit.stats\")."
  type = list(object({
    name        = string
    description = optional(string)
    inclusion   = optional(string)
    columns = optional(list(object({
      name        = string
      description = optional(string)
      inclusion   = optional(string)
    })), [])
  }))
  default = []
}

variable "curated_queries" {
  description = "Optional example natural-language questions with their SQL, to guide query generation."
  type = list(object({
    natural_language = string
    sql              = string
  }))
  default = []
}
