local responses = require "kong.tools.responses"
local singletons = require "kong.singletons"
local constants = require "kong.constants"
local BasePlugin = require "kong.plugins.base_plugin"
local IPplugin = require "kong.plugins.ip-restriction.handler"
local iputils = require "resty.iputils"

local ngx_set_header = ngx.req.set_header

local IPAuthHandler = BasePlugin:extend()

IPAuthHandler.PRIORITY = 999
IPAuthHandler.VERSION = "0.1.0"

function IPAuthHandler:new()
  IPAuthHandler.super.new(self, "ip-auth")
end

-- copied from ip-restriction
local cache = {}
local new_tab
do
  local ok
  ok, new_tab = pcall(require, "table.new")
  if not ok then
    new_tab = function() return {} end
  end
end

local function cidr_cache(cidr_tab)
  local cidr_tab_len = #cidr_tab
  local parsed_cidrs = new_tab(cidr_tab_len, 0) 
  for i = 1, cidr_tab_len do
    local cidr        = cidr_tab[i]
    local parsed_cidr = cache[cidr]

    if parsed_cidr then
      parsed_cidrs[i] = parsed_cidr

    else
      local lower, upper = iputils.parse_cidr(cidr)

      cache[cidr] = { lower, upper }
      parsed_cidrs[i] = cache[cidr]
    end
  end
  return parsed_cidrs
end

local function load_consumer(consumer_id, anonymous)
  local result, err = singletons.dao.consumers:find { id = consumer_id }
  if not result then
    if anonymous and not err then
      err = 'consumer "' .. consumer_id .. '" not found'
    end
    return nil, err
  end
  return result
end

local function set_consumer(consumer)
  ngx_set_header(constants.HEADERS.CONSUMER_ID, consumer.id)
  ngx_set_header(constants.HEADERS.CONSUMER_CUSTOM_ID, consumer.custom_id)
  ngx_set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username)
  ngx.ctx.authenticated_consumer = consumer
  ngx_set_header(constants.HEADERS.CREDENTIAL_USERNAME, "VPN")
  ngx.ctx.authenticated_credential = "ip-auth"
  ngx_set_header(constants.HEADERS.ANONYMOUS, nil) -- in case of auth plugins concatenation
end


function IPAuthHandler:access(conf)
  IPAuthHandler.super.access(self)
  local binary_remote_addr = ngx.var.binary_remote_addr

  -- check if preflight request and whether it should be authenticated
  if conf.run_on_preflight == false and get_method() == "OPTIONS" then
    -- FIXME: the above `== false` test is because existing entries in the db will
    -- have `nil` and hence will by default start passing the preflight request
    -- This should be fixed by a migration to update the actual entries
    -- in the datastore
    return
  end
 
  if ngx.ctx.authenticated_credential then
    -- we're already authenticated, so already done.
    return
  end
  -- require('mobdebug').start("192.168.2.84")
  matched = iputils.binip_in_cidrs(binary_remote_addr, cidr_cache(conf.ip_masks))
  if not matched then 
    return false --can still stay as anonymous user
  else
    local cache = singletons.cache
    local dao       = singletons.dao
    local consumer_cache_key = singletons.dao.consumers:cache_key(conf.authenticate_as_UUID)
    local consumer, err = singletons.cache:get(consumer_cache_key, nil,
                                                 load_consumer,
                                                 conf.authenticate_as_UUID, true)
    if err then
      return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    end

    set_consumer(consumer)
    return nil
  end
  
end


return IPAuthHandler
