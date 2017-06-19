--libwarp
--��������� ����������, �������������� ���� �������� ���������� ���������� ����-�����
--������ ��� ������ �� ����� ������� ���������� � ������� ��������� ��� ���� ����� �������
--������ � ���������� ������� ������
--

-- ���������� �������� ����������� ��������� � �����������
local libraries = {
	component = "component",
	term = "term"
}

for library in pairs(libraries) do if not _G[library] then _G[library] = require(libraries[library]) end end; libraries = nil
_G.gpu = component.gpu

local libwarp = {}

libwarp.JumpData = {
	distance = 1,
	direction = 0,
	summon = false
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
	component.warpdriveShipController.mode(1)
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
     component.warpdriveShipController.jump()
	 return true
	else 
		return false
	end
end

function libwarp.TurnOffCore()
	component.warpdriveShipController.mode(0)
end



function libwarp.SwitchHyper()
	component.warpdriveShipController.mode(5)
	component.warpdriveShipController.jump()
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
function libwarp.GetJumpEnergyCost(distance)
	component.warpdriveShipController.mode(1)
	return component.warpdriveShipController.getEnergyRequired(distance)
end

function libwarp.SetShipName(newName)
	component.warpdriveShipController.coreFrequency(newName)
end

function libwarp.GetShipName()
	return component.warpdriveShipController.coreFrequency()
end

--�������� ������� ������� ����� ������. �� ������� ������� 
function libwarp.GetRotation(inDegs) 
	if inDegs == nil or inDegs == false then
		return component.warpdriveShipController.rotationSteps()
	else
		return component.warpdriveShipController.rotationSteps()*90
	end
end

--������ ������� ������� ����� ������ (0-3 ��� 0-270). �� ������� ������� 
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
	return component.warpdriveShipController.isAttached()
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
	distance = libwarp.CalcJumpDistance()
	energy = libwarp.GetEnergyLevel()
	energyCost = libwarp.GetJumpEnergyCost(distance)
	if energy < energyCost then
		return false
	end
	
	return true
end

function libwarp.GetEnergyLevel()
	return component.warpdriveShipController.energy()
end

return libwarp