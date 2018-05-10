local singletons = require "kong.singletons"
local responses = require "kong.tools.responses"

local function load_acls_into_memory(consumer_id)
  local results, err = singletons.dao.acls:find_all {consumer_id = consumer_id}
  if err then
    return nil, err
  end
  return results
end

local _M = {}

function acl_matched(conf)
--This matches consumer against an ACL group
  if next(conf.acl_groups) == nil then --Empty list matches everything
    return true
  else
    local consumer_id
    local ctx = ngx.ctx
    local authenticated_consumer = ctx.authenticated_consumer
    if authenticated_consumer then
      consumer_id = authenticated_consumer.id
    end

    if not consumer_id then
      local authenticated_credential = ctx.authenticated_credential
      if authenticated_credential then
        consumer_id = authenticated_credential.consumer_id
      end
    end

    if not consumer_id then
      ngx.log(ngx.ERR, "[dataset plugin] Cannot identify the consumer")
      responses.send_HTTP_FORBIDDEN("You cannot consume this service")
    end

  -- Retrieve ACL
    local cache_key = singletons.dao.acls:cache_key(consumer_id)
    local acls, err = singletons.cache:get(cache_key, nil,
                                          load_acls_into_memory, consumer_id)
    if err then
      responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    end
    if acls then
      for _,acl in ipairs(acls) do
        for _,group in ipairs(conf.acl_groups) do
          if group==acl.group then
            return true
          end
        end
      end
    end
    return false
  end
end

function _M.execute(conf)
  request_path=ngx.var.uri
  capture_pattern=conf.template:gsub("$dataset_id","(.*)")
  if not ngx.re.match(request_path,capture_pattern) then
    return nil
  end

  if not acl_matched(conf) then 
    return nil
  end
  
  if #conf.whitelist>0 then 
    for _,id in ipairs(conf.whitelist) do
      pattern=conf.template:gsub("$dataset_id",id)
      ngx.log(ngx.ERR, "Test request "..request_path.." against "..pattern)
      if ngx.re.match(request_path,pattern) then
        ngx.log(ngx.ERR, "Whitelist dataset match found for "..request_path)
        return nil
      end
    end
    ngx.log(ngx.ERR, "Whitelist dataset match not found for "..request_path)
    return responses.send_HTTP_FORBIDDEN("Dataset access not authorized")
  elseif #conf.blacklist>0 then
    for _,id in ipairs(conf.blacklist) do
      pattern=conf.template:gsub("$dataset_id",id)
      ngx.log(ngx.ERR, "Test request "..request_path.." against "..pattern)
      if ngx.re.match(request_path,pattern) then
        ngx.log(ngx.ERR, "Blacklist dataset match found for "..request_path)
        return responses.send_HTTP_FORBIDDEN("Dataset access not authorized")
      end
    end
    ngx.log(ngx.ERR, "Blacklist dataset match not found for "..request_path)
    return nil
  end
end

return _M