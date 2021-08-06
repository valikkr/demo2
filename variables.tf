
variable "region" {
    type = string
    description = "Define AWS region"
    default = "eu-central-1"
}
variable "az_count" {
  description = "Number of AZs to cover in a given region"
  default     = "2"
}


