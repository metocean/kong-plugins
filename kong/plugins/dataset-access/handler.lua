local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.dataset-access.access"

local DatasetAccessHandler = BasePlugin:extend()

function DatasetAccessHandler:new()
  DatasetAccessHandler.super.new(self, "dataset-access")
end

function DatasetAccessHandler:access(conf)
  DatasetAccessHandler.super.access(self)
  access.execute(conf)
end

DatasetAccessHandler.PRIORITY = 905
DatasetAccessHandler.VERSION = "0.1.0"

return DatasetAccessHandler
