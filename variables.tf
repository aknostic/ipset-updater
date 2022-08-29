variable "ip_set_arn" {
  type = string
  description = "ARN of the IP Set which will be updated by the lambda function"
}

#  (#TODO for which resources is it used, specifically?)
# Maybe indicate that if the module is instantiated more than once, this value needs to be unique
variable "name_prefix" {
  type = string
  description = "Prefix we will add to all the resource names"
}

variable "domain_names" {
  type = string
  description = "List of domain names to check, separated by comma, e.g. 'www.google.com,www.yahoo.com'"
}

variable "frequency" {
  type = number
  description = "Frequency in which to run, in minutes"
  default = 30
}

variable "log_level" {
  type = string
  description = "Log level for the lambda function logging, e.g. 'ERROR', 'INFO', 'DEBUG'"
  default = "ERROR"
}
