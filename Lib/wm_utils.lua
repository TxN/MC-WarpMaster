local c  = require("component")
local fs = require("filesystem")

local utils = {} 

function utils.Clamp(val, lower, upper)
    assert(val and lower and upper, "Not all values provided")
    if lower > upper then lower, upper = upper, lower end
    return math.max(lower, math.min(upper, val))
end

function utils.ClampMagnitude(val, lower, upper)
	local mag =  utils.Clamp(math.abs(val), lower, upper)
	return mag * utils.sign(val)
end

function utils.sign(x)
   if x < 0 then
     return -1
   elseif x > 0 then
     return 1
   else
     return 0
   end
end

function utils.dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. utils.dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function utils.splitString(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={} ; i=1
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end

function utils.SaveData(filename, object)
  fs.makeDirectory(fs.path(filename) or "")
	local file = io.open(""..filename, "w")
	if file ~= nil then
		file:write(serialization.serialize(object))
		file:close()
	else
		print("DATA SAVE ERROR!")
	end
end

function utils.LoadData(filename)
	if fs.exists(""..filename) then
		local file = fs.open(""..filename, "r")
		local size = fs.size(""..filename)
		local rawData = file:read(size)
		if rawData ~= nil then
			data = serialization.unserialize(rawData)
		end
		file:close()
		if data == nil then
			return nil
		else
			return data
		end
	end
end

function utils.SendTelemetry(...)
	if c.isAvailable("tunnel") == false then
		return
	end
	local tunnel = c.tunnel
	if tunnel == nil then
		return false
	end
	
	tunnel.send(...)
end

function utils.round(x)
  if x % 2 ~= 0.5 then
    return math.floor(x+0.5)
  end
  return x - 0.5
end

function utils.HasInternet() 
	return c.isAvailable("internet")
end

return utils