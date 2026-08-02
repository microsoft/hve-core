variable "name_prefix" {
  description = "Prefix for all resource names. Follow your existing naming convention."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,16}$", var.name_prefix))
    error_message = "The name_prefix value must be 3 to 16 lowercase letters, digits, or hyphens."
  }
}

variable "resource_group_name" {
  description = "Existing resource group that will hold the telemetry resources."
  type        = string
}

variable "location" {
  description = "Region for all resources. The dashboard must sit in the same region as the workspace."
  type        = string
}

variable "retention_in_days" {
  description = "Log Analytics retention in days. This is a cost decision, not a default."
  type        = number
  default     = 90

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "The retention_in_days value must be between 30 and 730."
  }
}

variable "daily_quota_gb" {
  description = "Daily ingestion cap in GB. -1 disables the cap and removes the only spend guardrail."
  type        = number
  default     = 5
}

variable "reader_principal_id" {
  description = "Object ID of the principal that will read telemetry. Empty skips the role assignment."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
