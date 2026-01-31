variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "simple-log-service"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "enable_config" {
  description = "Enable AWS Config for compliance monitoring"
  type        = bool
  default     = true
}

variable "config_snapshot_frequency" {
  description = "AWS Config snapshot delivery frequency"
  type        = string
  default     = "TwentyFour_Hours"
  validation {
    condition     = contains(["One_Hour", "Three_Hours", "Six_Hours", "Twelve_Hours", "TwentyFour_Hours"], var.config_snapshot_frequency)
    error_message = "Must be a valid AWS Config delivery frequency."
  }
}

variable "alarm_email" {
  description = "Email address for alarm notifications (leave empty to disable email notifications)"
  type        = string
  default     = ""
}
