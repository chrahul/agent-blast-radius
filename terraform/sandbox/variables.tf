variable "region" {
  description = "AWS region for the sandbox. Use a region you do not run production in."
  type        = string
  default     = "ap-south-1"
}

variable "owner" {
  description = "Tag value so these resources are attributable at a glance."
  type        = string
  default     = "rahul"
}
