local warpdrive = require("libwarp")
local event     = require("event")

local autopilot = {
  enabled           = false,
	point             = nil,
	threshold         = 48,
	jumpStep          = 16,
	remainingDistance = 0,
	ignoreY           = true,
	delayTimerID      = nil,
	mode              = "cruise",
	wanderPoints,
	wanderIndex       = 1,
  OnAutopilotBusy   = function() return end, -- Эту оверрайдим для показа окна работающего автопилота.
  OnAutopilotFinish = function() return end,  -- Эту оверрайдим для ивента завершения работы автопилота.    
  runtimeParams = {
    warpLockFlag = false
  }
}

function autopilot.SetTarget(tgPoint)
	if tgPoint ~= nil then
		autopilot.point = tgPoint
	end
end

function autopilot.Start()
	if autopilot.point == nil then
		return
	end
	
	local estimatedDistance = warpdrive.CalcDistanceToPoint(autopilot.point[3],autopilot.point[4],autopilot.point[5], autopilot.ignoreY)
	
	if estimatedDistance <= autopilot.threshold then
		return
	end
	
	autopilot.remainingDistance = estimatedDistance
	autopilot.enabled = true
	
	if autopilot.runtimeParams.warpLockFlag == false then
		autopilot.ReadyToNextJump()
	end
end

function autopilot.Jump()
	local tx,ty,tz = autopilot.point[3],autopilot.point[4],autopilot.point[5]
	local rx,ry,rz = warpdrive.WorldToShipRelativeCoordinates(tx,ty,tz)
	if autopilot.ignoreY == true then
		ry = 0
	end
	
	warpdrive.SetJumpTargetLimited(rx, ry, rz, 0, autopilot.jumpStep)
	warpdrive.Warp(true)
	autopilot.runtimeParams.warpLockFlag = true	
	autopilot.OnAutopilotBusy()
	autopilot.delayTimerID = event.timer(16, autopilot.JumpDelayComplete)
end

function autopilot.JumpDelayComplete() 
	if autopilot.CheckDistance(autopilot.point[3],autopilot.point[4],autopilot.point[5]) == false then
		if autopilot.mode == "cruise" then
			autopilot.DeactivateAutopilot()
		elseif autopilot.mode == "wander" then
			autopilot.wanderIndex = autopilot.wanderIndex  + 1
			if autopilot.wanderPoints[autopilot.wanderIndex] == nil then
				autopilot.wanderIndex = 1
			end
			autopilot.point = autopilot.wanderPoints[autopilot.wanderIndex]
		end
	else 
		autopilot.OnAutopilotBusy()

	end
end

function autopilot.ReadyToNextJump()
	if autopilot.enabled == false then
		return
	end

	if autopilot.CheckDistance(autopilot.point[3],autopilot.point[4],autopilot.point[5]) == false then
		autopilot.DeactivateAutopilot()
	else 
		autopilot.OnAutopilotBusy()
		autopilot.Jump()
	end
end

function autopilot.DeactivateAutopilot()
	autopilot.enabled = false  
	autopilot.remainingDistance = 0
	autopilot.point = nil
	autopilot.mode = "cruise"
	autopilot.wanderIndex = 0
  autopilot.OnAutopilotFinish()
end

function autopilot.CheckDistance(x,y,z)
	local estimatedDistance = warpdrive.CalcDistanceToPoint(x,y,z, autopilot.ignoreY)
	autopilot.remainingDistance = estimatedDistance
	if estimatedDistance <= autopilot.threshold then
		return false
	end
	return true
end

return autopilot
