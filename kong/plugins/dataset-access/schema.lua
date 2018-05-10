local Errors = require "kong.dao.errors"

return {
  no_consumer = true,
  fields = {
    acl_groups = {type = "array", default = {}},
    template = {type = "string", default="/(.*)/$dataset_id"},
    blacklist = {type = "array", default = {}},
    whitelist = {type = "array", default = {}}
  },
  self_check = function(schema, plugin_t, dao, is_update)
    if next(plugin_t.whitelist or {}) and next(plugin_t.blacklist or {}) then
      return false, Errors.schema "You cannot set both a whitelist and a blacklist"
    elseif not (next(plugin_t.whitelist or {}) or next(plugin_t.blacklist or {})) then
      return false, Errors.schema "You must set at least a whitelist or blacklist"
    end
    _,id = next(plugin_t.whitelist or plugin_t.blacklist)
    pattern_check=plugin_t.template:gsub("$dataset_id",id)
    m, err = ngx.re.match("",pattern_check)
    if (err ~= nil) then
      return false, Errors.schema ("Syntax error in template: " .. err)
    end
    return true
  end
}
