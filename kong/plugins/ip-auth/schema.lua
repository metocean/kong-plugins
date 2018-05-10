local Errors = require "kong.dao.errors"

return {
  no_consumer = true,
  fields = {
    ip_masks = {type = "array", default = {}},
    authenticate_as_UUID = {type = "string"}
  }
}
