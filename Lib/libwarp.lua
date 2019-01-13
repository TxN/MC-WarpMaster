--libwarp
--Небольшая библиотека, поддерживающая весь основной функционал управления варп-ядром
--Теперь вам больше не нужны сложные компьютеры и большие программы для того чтобы прыгать
--Хватит и компьютера первого уровня
--

-- Адаптивная загрузка необходимых библиотек и компонентов
local libraries = {
	component = "component",
	term      = "term",
  utils     = "wm_utils"
}

for library in pairs(libraries) do if not _G[library] then _G[library] = require(libraries[library]) end end; libraries = nil
_G.gpu = component.gpu

local libwarp = {}

libwarp.JumpData = {
	distance  = 1,
	direction = 0,
	summon    = false
}
libwarp.ShipInfo = {
	shipName = "unnamed"
}

function libwarp.maxJumpLength() 
	if not libwarp.IsInHyper() then
		return 128
	else
		return 12800
	end
end

function libwarp.Warp(safe)
	component.warpdriveShipController.command("MANUAL")
	local safeFlag = false
	if safe == nil then
	    safeFlag = true
	elseif safe == false then
		safeFlag = true
	else
	    safeFlag = libwarp.MakePreFlightCheck()
	end
	
	if (safeFlag == true) then
     component.warpdriveShipController.direction(libwarp.JumpData.direction)
     component.warpdriveShipController.enable(true)
	 return true
	else 
		return false
	end
end

function libwarp.TurnOffCore()
	component.warpdriveShipController.command("OFFLINE")
	component.warpdriveShipController.enable(false)
end



function libwarp.SwitchHyper()
	component.warpdriveShipController.command("HYPERDRIVE")
	component.warpdriveShipController.enable(true)
	return true
end

function libwarp.SetDirection(dir)
	local toSet = 0
	if type(dir) == nil then
		return
	elseif type(dir) == "number" then
		toSet = dir
	elseif type(dir) == "string" then
		toSet = libwarp.EncodeDirection(dir)
	else
		return
	end	
	component.warpdriveShipController.direction(toSet)
end

function libwarp.EncodeDirection(dir)
	if dir == "up" then
		return 1
	elseif dir == "down" then
		return 2
	elseif dir == "front" then
		return 0
	elseif dir == "back" then
		return 180
	elseif dir == "left" then
		return 90
	elseif dir == "right" then
		return 255
	else
		return 0
	end	
end
function libwarp.DecodeDirection(dir)
	if dir == 1 then
		return "up"
	elseif dir == 2 then
		return "down"
	elseif dir == 0 then
		return "front"
	elseif dir == 180 then
		return "back"
	elseif dir == 90 then
		return "left"
	elseif dir == 255 then
		return "right"
	else
		return "wrong"
	end	
end
--[[
function libwarp.CalcRealDistance()
     if libwarp.IsInHyper() then
      realDistance = libwarp.JumpData.distance * 100
      minimumDistance = 1
     else
      if libwarp.JumpData.direction == 1 or libwarp.JumpData.direction == 2 then
       minimumDistance = libwarp.GetShipHeight()
       realDistance = libwarp.JumpData.distance + minimumDistance
      elseif libwarp.JumpData.direction == 0 or libwarp.JumpData.direction == 180 then
       minimumDistance = libwarp.GetShipLength()
       realDistance = libwarp.JumpData.distance + minimumDistance
      elseif libwarp.JumpData.direction == 90 or libwarp.JumpData.direction == 255 then
       minimumDistance = libwarp.GetShipWidth()
       realDistance = libwarp.JumpData.distance + minimumDistance
      end
      minimumDistance = minimumDistance + 1
     end
	 
	 return realDistance
end
--]]
function libwarp.GetJumpEnergyCost()
	component.warpdriveShipController.command("MANUAL")
	local success, result = component.warpdriveShipController.getEnergyRequired()
	return result
end

function libwarp.SetShipName(newName)
	component.warpdriveShipController.shipName(newName)
end

function libwarp.GetShipName()
	return component.warpdriveShipController.shipName()
end

--Получить поворот корабля после прыжка. По часовой стрелке 
function libwarp.GetRotation(inDegs) 
	if inDegs == nil or inDegs == false then
		return component.warpdriveShipController.rotationSteps()
	else
		return component.warpdriveShipController.rotationSteps()*90
	end
end

--Задать поворот корабля после прыжка (0-3 или 0-270). По часовой стрелке 
function libwarp.SetRotation(rotation) 
	if (rotation == nil) then
		return
	end
		
	if rotation < 0 or rotation > 270 then
		return
	end
	
	if rotation < 4 then
		component.warpdriveShipController.rotationSteps(rotation)
	else
		local rot = math.floor(rotation / 90 )
		component.warpdriveShipController.rotationSteps(rot)
	end	
end

function libwarp.IsInHyper() 
	return component.warpdriveShipController.isInHyperspace()
end

function libwarp.IsInSpace()
	return component.warpdriveShipController.isInSpace()
end

function libwarp.HasController()
	if component.isAvailable("warpdriveShipController") == false then
		return false
	else
		return true
	end
end

function libwarp.HasCore()
	return component.warpdriveShipController.isAssemblyValid()
end

function libwarp.CheckCore()
	if not libwarp.HasController() then
		return false
	else 
		if not libwarp.HasCore() then
			return false
		end
	end
	return true
end

function libwarp.GetShipWeight()
	return component.warpdriveShipController.getShipSize()
end

function libwarp.GetDimensions()
	local GFront, GRight, GUp = component.warpdriveShipController.dim_positive()
	local GBack, GLeft, GDown = component.warpdriveShipController.dim_negative()
	return GFront, GRight, GUp, GBack, GLeft, GDown
end

function libwarp.GetShipLength()
	local front, right, up, back, left, down = libwarp.GetDimensions()
	return front + back
end

function libwarp.GetShipWidth()
	local front, right, up, back, left, down = libwarp.GetDimensions()
	return right + left
end

function libwarp.GetShipHeight()
	local front, right, up, back, left, down = libwarp.GetDimensions()
	return down + up
end

function libwarp.SetDimensions(front,back, left,right, up, down)
	component.warpdriveShipController.dim_positive(front, right, up)
	component.warpdriveShipController.dim_negative(back, left, down)
end
 
function libwarp.CalcDestinationPoint()
  local posx,posy,posz = libwarp.GetShipPosition()
  local res = { x = posx, y = posy, z = posz }
  local dx, dy, dz = libwarp.GetShipOrientation()
  local core_movement = libwarp.GetCoreMovement() 
  local worldMovement = { x = 0, y = 0, z = 0 }
  worldMovement.x = dx * core_movement[1] - dz * core_movement[3]
  worldMovement.y = core_movement[2]
  worldMovement.z = dz * core_movement[1] + dx * core_movement[3]
  res.x = res.x + worldMovement.x
  res.y = res.y + worldMovement.y
  res.z = res.z + worldMovement.z
  return res
end

function libwarp.CalcJumpDistance()
  local dx, dy, dz = libwarp.GetShipOrientation()
  local core_movement = libwarp.GetCoreMovement() 
  local worldMovement = { x = 0, y = 0, z = 0 }
  worldMovement.x = dx * core_movement[1] - dz * core_movement[3]
  worldMovement.y = core_movement[2]
  worldMovement.z = dz * core_movement[1] + dx * core_movement[3]
  local core_actualDistance = math.ceil(math.sqrt(worldMovement.x * worldMovement.x + worldMovement.y * worldMovement.y + worldMovement.z * worldMovement.z))
  return core_actualDistance
end

function libwarp.GetCoreMovement() 
	return {component.warpdriveShipController.movement()}
end

function libwarp.SetCoreMovement(x,y,z) 
	component.warpdriveShipController.movement(x,y,z)
end

function libwarp.SummonAll()
	component.warpdriveShipController.summon_all()
end 

function libwarp.Summon(index)
	component.warpdriveShipController.summon(index)
end 

function libwarp.GetAttachedPlayers()
	return component.warpdriveShipController.getAttachedPlayers()
end

function libwarp.GetShipOrientation()
	return component.warpdriveShipController.getOrientation()
end 

function libwarp.GetShipPosition()
	return component.warpdriveShipController.position()
end

function libwarp.MakePreFlightCheck()
	if libwarp.HasController() == false then
		return false
	end
	if libwarp.HasCore() == false then
		return false
	end	
	energy = libwarp.GetEnergyLevel()
	energyCost = libwarp.GetJumpEnergyCost()
	if energy < energyCost then
		return false
	end
	
	return true
end

function libwarp.GetEnergyLevel()
	return component.warpdriveShipController.energy()
end

function libwarp.CalcDistanceToPoint(x,y,z, ignoreY)
	if ignoreY == nil then
		ignoreY = false
	end
	if y == nil then
		y = 0
	end
	local posx,posy,posz = libwarp.GetShipPosition()
	x = x - posx
	y = y - posy
	z = z - posz
	if ignoreY == true then
		y = 0
	end
	local dist = math.sqrt(x*x + y*y + z*z)
	
	return math.floor(dist)
end

--капец как криво, но работает.
function libwarp.WorldToShipRelativeCoordinates(tx,ty,tz)
	local posx,posy,posz = libwarp.GetShipPosition()
	local ox, oy, oz     = libwarp.GetShipOrientation()
	local dx = tx - posx
	local dy = ty - posy
	local dz = tz - posz
	local dspX = 0
	local dspY = 0
	if ox == 1 then
		dspX = dz
		dspY = dx
	elseif ox == -1 then
		dspX = -dz
		dspY = -dx
	elseif oz == 1 then
		dspX = -dx
		dspY = dz
	elseif oz == -1 then
		dspX = dx
		dspY = -dz
	end
	return dspY,dy,dspX
end

-- Задает точку прыжка, соответствующую ограничениям (не меньше минимальной дистанции, но и не больше максимальной)
function libwarp.SetJumpTargetLimited(x,y,z,rot,step)
  if x == nil or y == nil or z == nil then
		return false
	end
	if rot == nil then 
		rot = "0"
	end
  local mindz = libwarp.GetShipWidth() + 2
  local mindy = libwarp.GetShipHeight() + 2
  local mindx = libwarp.GetShipLength() + 2
  local dx,dy,dz = tonumber(x),tonumber(y),tonumber(z)
  local maxJumpDist =  libwarp.maxJumpLength()
  
  if dx ~= 0 then
    dx = utils.ClampMagnitude(dx, mindx, maxJumpDist + mindx)
	end
	if dy ~= 0 then
    dy = utils.ClampMagnitude(dy, mindy, maxJumpDist + mindy)
	end
	if dz ~= 0 then
    dz = utils.ClampMagnitude(dz, mindz, maxJumpDist + mindz)
  end
  
  if step ~= nil then
		dx = utils.round(dx/step)*step
		dz = utils.round(dz/step)*step
	end
  
  libwarp.SetCoreMovement(dx,dy,dz)
	libwarp.SetRotation(tonumber(rot))
  return true, dx, dy, dz
end

-- На будущее: подумать о том, что генераторов на корабле может быть дофига
function libwarp.SetAirGenerators(flag)
	if not component.isAvailable("warpdriveAirGenerator") then
		return
	end
	component.warpdriveAirGenerator.enable(flag)
end


return libwarp