# ipset-updater
This Terraform module creates an AWS lambda function which updates a WAF IP set based on a list of domains.

The lambda function searches the IP addresses for the given domain names, and updates the IP set configured with the found list of IPs.

This module can help when using WAF, for example for whitelisting access to your application of third parties which do not provide a fixed list of IP addresses but only one or more domain names.

This module is partly inspired in [this](https://aws.amazon.com/blogs/security/automatically-update-aws-waf-ip-sets-with-aws-ip-ranges/) solution, which instead of Terraform uses a Cloudformation template to create a lambda function and update IP Sets with updated AWS services endpoints.

##Overview

![module resources](drawing/WAF-IPset-automatic-updating.drawio.png?raw=true)

The Terraform module creates a Cloudwatch event rule which will trigger a lambda function every x number of minutes (30 by default).
The IP Set to be updated is configured as well, it's NOT created by the module.

The lambda function is written in python and the code is in `code/lambda_function.py`.


##Usage

1. Create an IP Set and associate it to your WAF Web ACL. This IP Set will contain the IP addresses associated to the domains you want to whitelist.

2. Configure the TF module with the following inputs:

* `ip_set_arn`. IP Set associated to the WAF ACL that you are using.
* `name_prefix`. This prefix will be added to all the resource names we create. If you are planning to instantiate this module more than once make sure this prefix is unique.
* `domain_names`. List of domain names to check, separated by comma, e.g. 'www.google.com,www.yahoo.com'"
* `frequency`. Frequency to update the IP Set, in minutes. Default is 30.
* `log_level`. Log level for the lambda function logging in Cloudwatch, e.g. 'ERROR', 'INFO', 'DEBUG'. Default is ERROR.

Example:

```
module "sf_ips_updater" {
  source = "./ipset-updater"
  ip_set_arn = aws_wafv2_ip_set.external_service1_ips.arn )
  name_prefix = "my_application"
  domain_names = "service-accessing-my-app.domain1.com, another-service-accessing-my-app.domain2.com" )
  frequency = 20
}
```

