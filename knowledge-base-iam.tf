data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  use_catalog        = var.storage_type == "AWS_DATA_CATALOG"
  catalog_account_id = coalesce(var.glue_catalog_account_id, data.aws_caller_identity.current.account_id)

  trimmed_s3_parquet_prefixes = [for prefix in var.s3_parquet_prefixes : trim(prefix, "/")]
  normalized_s3_parquet_prefixes = [
    for prefix in local.trimmed_s3_parquet_prefixes : prefix == "" ? "" : "${prefix}/"
  ]
  s3_parquet_object_arns = local.use_catalog ? [
    for prefix in local.normalized_s3_parquet_prefixes : "${var.s3_bucket_arn}/${prefix}*"
  ] : []
  s3_list_prefixes = distinct(concat(
    [for prefix in local.normalized_s3_parquet_prefixes : "${prefix}*"],
    [for prefix in local.trimmed_s3_parquet_prefixes : prefix if prefix != ""]
  ))

  # Glue / S3 locals are only meaningful for AWS_DATA_CATALOG storage. Guard them
  # so REDSHIFT storage (with null Glue/S3 inputs) never interpolates a null.
  glue_arn_prefix   = "arn:${data.aws_partition.current.partition}:glue:${data.aws_region.current.region}:${local.catalog_account_id}"
  glue_catalog_arn  = "${local.glue_arn_prefix}:catalog"
  glue_database_arn = local.use_catalog ? "${local.glue_arn_prefix}:database/${var.glue_database_name}" : null
  glue_table_arns = local.use_catalog ? [
    for table_name in var.glue_table_names : "${local.glue_arn_prefix}:table/${var.glue_database_name}/${table_name}"
  ] : []
}


data "aws_iam_policy_document" "knowledge-base-role-trust" {
  statement {
    sid     = "AllowBedrockKnowledgeBaseAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "knowledge-base-role" {
  name               = "${var.app_name}-${var.app_environment}-bedrock-knowledge-base-role"
  assume_role_policy = data.aws_iam_policy_document.knowledge-base-role-trust.json

  tags = {
    Name        = "${var.app_name}-${var.app_environment}-bedrock-knowledge-base-role"
    Environment = var.app_environment
  }
}

data "aws_iam_policy_document" "knowledge-base-read" {
  statement {
    sid       = "RedshiftDataApiExecute"
    effect    = "Allow"
    actions   = ["redshift-data:ExecuteStatement"]
    resources = [var.redshift_workgroup_arn]
  }

  statement {
    sid    = "RedshiftDataApiOwnStatements"
    effect = "Allow"
    actions = [
      "redshift-data:DescribeStatement",
      "redshift-data:GetStatementResult",
      "redshift-data:CancelStatement"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "redshift-data:statement-owner-iam-userid"
      values   = ["$${aws:userid}"]
    }
  }

  statement {
    sid       = "RedshiftServerlessGetCredentials"
    effect    = "Allow"
    actions   = ["redshift-serverless:GetCredentials"]
    resources = [var.redshift_workgroup_arn]
  }

  statement {
    sid    = "SqlGeneration"
    effect = "Allow"
    actions = [
      "sqlworkbench:GetSqlRecommendations",
      "sqlworkbench:PutSqlGenerationContext",
      "sqlworkbench:GetSqlGenerationContext",
      "sqlworkbench:DeleteSqlGenerationContext"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "GenerateQuery"
    effect    = "Allow"
    actions   = ["bedrock:GenerateQuery"]
    resources = ["*"]
  }

  # --- AWS_DATA_CATALOG storage only: the role reads Glue, S3 and Lake
  # Formation data itself (through Redshift's awsdatacatalog). ---

  dynamic "statement" {
    for_each = local.use_catalog ? [1] : []
    content {
      sid    = "ReadGlueCatalogMetadata"
      effect = "Allow"
      actions = [
        "glue:GetDatabase",
        "glue:GetDatabases",
        "glue:GetTable",
        "glue:GetTables",
        "glue:GetPartition",
        "glue:GetPartitions",
        "glue:BatchGetPartition",
        "glue:SearchTables"
      ]
      resources = concat(
        [local.glue_catalog_arn, local.glue_database_arn],
        local.glue_table_arns
      )
    }
  }

  dynamic "statement" {
    for_each = local.use_catalog ? [1] : []
    content {
      sid       = "LakeFormationDataAccess"
      effect    = "Allow"
      actions   = ["lakeformation:GetDataAccess"]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = local.use_catalog ? [1] : []
    content {
      sid       = "ListParquetPrefix"
      effect    = "Allow"
      actions   = ["s3:ListBucket"]
      resources = [var.s3_bucket_arn]

      condition {
        test     = "StringLike"
        variable = "s3:prefix"
        values   = local.s3_list_prefixes
      }
    }
  }

  dynamic "statement" {
    for_each = local.use_catalog ? [1] : []
    content {
      sid       = "GetBucketLocation"
      effect    = "Allow"
      actions   = ["s3:GetBucketLocation"]
      resources = [var.s3_bucket_arn]
    }
  }

  dynamic "statement" {
    for_each = local.use_catalog ? [1] : []
    content {
      sid       = "ReadParquetObjects"
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = local.s3_parquet_object_arns
    }
  }
}

resource "aws_iam_role_policy" "knowledge-base-read" {
  name   = "${var.app_name}-${var.app_environment}-bedrock-knowledge-base-policy"
  role   = aws_iam_role.knowledge-base-role.id
  policy = data.aws_iam_policy_document.knowledge-base-read.json
}
