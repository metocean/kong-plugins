This is a custom plugin to allow for automated auth against an IP origin.

Settings:

* **authenticate_as**: The consumer to authorize as (must use the UUID)
* **ip_masks**: List of IPs or CIDR ranges that are allowed

If the IP range matches, authentication is granted to the specified consumer ID. Note that this plugin runs AFTER other auth plugins and an anonymous consumer must be set on the upstream auth plugins for this one to run.

The ACL plugin will still be applied as usual.

