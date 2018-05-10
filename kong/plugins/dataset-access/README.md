This is a custom plugin to manage dataset access. Settings:

* **template**: a RE template to match for dataset filtering. The $dataset_id placeholder will be replaced with the whitelist or blacklist options
* **acl_groups**: ACL groups to match against. If this is empty will match against all groups
* **whitelist**: List of allowed datasets
* **blacklist**: List of disallowed datasets

You cannot set both a whitelist and a blacklist. Note that the request must match the template for the dataset filter to be applied. 

The order of evaluation is:
1. Does the ACL group match the consumer (or is empty)
  a. If no, allow access
  b. If yes, continue
2. Does the request match the template
  a. If no, allow access
  b. If yes, continue
3. Does the request match any whitelist options
  a. If yes, allow access
  b. If no, block access
  c. If no whitelist entries, continue
4. Does the request match any blacklist options
  a. If yes, block access
  b. If no, allow access
