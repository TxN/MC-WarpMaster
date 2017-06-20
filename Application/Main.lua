--Внимание: каша!
-- lua не очень располагает к написанию аккуратного кода, так что как-то так.
local c  = require("component")
local fs = require("filesystem")
c.gpu.setResolution(100,50)
local warpLockFlag  = false
local inputHandler  = nil
local mainCycleFlag = true

local libraries = {
	buffer        = "doubleBuffering",
	ecs           = "ECSAPI",
	event         = "event",
	image         = "image",
	unicode       = "unicode",
	warpdrive     = "libwarp",
	GUI           = "GUI",
	serialization = "serialization",
	filesystem    = "filesystem",
	computer      = "computer"
}
for library in pairs(libraries) do if not _G[library] then _G[library] = require(libraries[library]) end end; libraries = nil

local fileListURL            = "https://raw.githubusercontent.com/TxN/MC-WarpMaster/master/Installer/FileList.cfg"
local versionCheckURL        = "https://raw.githubusercontent.com/TxN/MC-WarpMaster/master/Application/Version.txt"
local currentVersionFilePath = "MineOS/Applications/WarpMaster.app/Version.txt"
local applicationDataPath    = "WarpMasterData"

local colors = {
	background  = 0x262626,
	window      = 0x4e8bc4,
	panel       = 0x262646,
	text        = 0x11202d,
	white       = 0xffffff,
	black       = 0x000000,
	menuButton  = 0xff7a00,
	redButton   = 0xCC4C4C,
	greenButton = 0x57A64E
}

local programSettings = {
	firstLaunch      = true,
	navScaleX        = 4,
	navScaleY        = 8,
	currentWorldType = "earth",
	lock             = false, --может быть и наивно, но смогут обойти не только лишь все.
	autopilotEnabled = false,
	autopilotTarget  = nil,
  planetsListFile  = "DreamfinityLate2016"
}

local shipInfo = {
	name               = "undefined",
	weight             = 0,
	height             = 1,
	length             = 1,
	width              = 1,
	core_front         = 0,
	core_right         = 0,
	core_up            = 0,
	core_back          = 0,
	core_left          = 0,
	core_down          = 0,
	core_movement      = { 0, 0, 0 },
	core_rotationSteps = 0
}

local trustedPlayers = {
}

local function LoadInfoFromCore()
	shipInfo.name = warpdrive.GetShipName()
	shipInfo.weight = warpdrive.GetShipWeight()
	shipInfo.height = warpdrive.GetShipHeight()
	shipInfo.length = warpdrive.GetShipLength()
	shipInfo.width = warpdrive.GetShipWidth()
	shipInfo.core_front,shipInfo.core_right,shipInfo.core_up,shipInfo.core_back,shipInfo.core_left,shipInfo.core_down = warpdrive.GetDimensions()
	shipInfo.core_movement = warpdrive.GetCoreMovement()
	shipInfo.core_rotationSteps = warpdrive.GetRotation(false) 
end

--структуры, хранящие методы и не только
local WGUI = {}
local tools = {}
local softLogic = {}

local autopilot = {
	point             = nil,
	threshold         = 48,
	jumpStep          = 16,
	remainingDistance = 0,
	ignoreY           = true,
	delayTimerID      = nil,
	mode              = "cruise",
	wanderPoints,
	wanderIndex       = 1
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
	
	local estimatedDistance = WGUI.CalcDistanceToPoint(autopilot.point[3],autopilot.point[4],autopilot.point[5], autopilot.ignoreY)
	
	if estimatedDistance <= autopilot.threshold then
		return
	end
	
	autopilot.remainingDistance = estimatedDistance
	
	programSettings.autopilotEnabled = true
	
	if warpLockFlag == false then
		autopilot.ReadyToNextJump()
	end
	
end

function autopilot.Jump()
	local tx,ty,tz = autopilot.point[3],autopilot.point[4],autopilot.point[5]
	local rx,ry,rz = WGUI.WorldToShipRelativeCoordinates(tx,ty,tz)
	if autopilot.ignoreY == true then
		ry = 0
	end
	
	tools.SetJumpTarget(rx,ry,rz,0,autopilot.jumpStep)
	warpdrive.Warp(true)
	warpLockFlag = true	
	ecs.square(1,2,100,50,0xff0000)
	WGUI.DrawAutopilotBusyWindow()
	inputHandler = nil
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
		WGUI.DrawAutopilotBusyWindow()
		inputHandler = WGUI.HandleAutopilot
	end
end

function autopilot.ReadyToNextJump()
	if programSettings.autopilotEnabled == false then
		return
	end

	if autopilot.CheckDistance(autopilot.point[3],autopilot.point[4],autopilot.point[5]) == false then
		autopilot.DeactivateAutopilot()
	else 
		WGUI.DrawAutopilotBusyWindow()
		inputHandler = WGUI.HandleAutopilot
		autopilot.Jump()
	end
end

function autopilot.DeactivateAutopilot()
	programSettings.autopilotEnabled = false
	WGUI.Clear()
	WGUI.DrawNav()
	inputHandler = WGUI.HandleNavInput
	autopilot.remainingDistance = 0
	autopilot.point = nil
	autopilot.mode = "cruise"
	autopilot.wanderIndex = 0
end

function autopilot.CheckDistance(x,y,z)
	local estimatedDistance = WGUI.CalcDistanceToPoint(x,y,z, autopilot.ignoreY)
	autopilot.remainingDistance = estimatedDistance
	if estimatedDistance <= autopilot.threshold then
		return false
	end
	return true
end

--	{"NavPoint1","earth", 140,80,-200},
local navPoints = {}

-- Формат описания навигационных точек:
-- point = {
	-- mapName = "pointMapName",
	-- listName = "pointListName",
	-- navIndex = 1,
	-- ex = 2
-- }
local displayedNavPoints = {}

--Данные об областях перехода на планеты
local celestialBodies = {}

local function CheckCore()
	if not warpdrive.HasController() then
		return false
	else 
		if not warpdrive.HasCore() then
			return false
		end
	end
	return true
end

function tools.CheckForUpdates()
  local result = false
  local version = 0
  local success, response = ecs.internetRequest(versionCheckURL)
  if success == true then
      local curVersion = 0
      version = tonumber(response)
    	if fs.exists(""..currentVersionFilePath) then
        local file = fs.open(""..currentVersionFilePath, "r")
        local size = fs.size(""..currentVersionFilePath)
        local rawData = file:read(size)
        if rawData ~= nil then
          curVersion = tonumber(rawData)
          if version > curVersion then
            result = true
          end
        end
      end
  end
  return result, version
end

function tools.LoadFileList()
  data = nil
  local success, response = ecs.internetRequest(fileListURL)
  if success == true then
    data = serialization.unserialize(response)
  end
  return data
end

function tools.DownloadUpdate(data)
	if data == nil then
		return
	end
	
	for i=1,#data.url do
		ecs.getFileFromUrl(data.url[i], data.path[i])
	end
end

function tools.Clamp(val, lower, upper)
    assert(val and lower and upper, "Not all values provided")
    if lower > upper then lower, upper = upper, lower end
    return math.max(lower, math.min(upper, val))
end

function tools.ClampMagnitude(val, lower, upper)
	local mag =  tools.Clamp(math.abs(val), lower, upper)
	return mag * tools.sign(val)
end

function tools.sign(x)
   if x<0 then
     return -1
   elseif x>0 then
     return 1
   else
     return 0
   end
end

function tools.dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. tools.dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function tools.splitString(inputstr, sep)
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

function tools.SetJumpTarget(x,y,z,rot,step)
	if x == nil or y == nil or z == nil then
		return
	end
	if rot == nil then 
		rot = "0"
	end
	local mindx, mindy,mindz = shipInfo.length+2, shipInfo.height+2, shipInfo.width+2
	local dx,dy,dz = tonumber(x),tonumber(y),tonumber(z)
	if dx ~= 0 then
	dx = tools.ClampMagnitude(dx, mindx, warpdrive.maxJumpLength() + mindx)
	end
	if dy ~= 0 then
	dy = tools.ClampMagnitude(dy, mindy, warpdrive.maxJumpLength() + mindy)
	end
	if dz ~= 0 then
	dz = tools.ClampMagnitude(dz, mindz, warpdrive.maxJumpLength() + mindz)
	end
	
	if step ~= nil then
		dx = tools.round(dx/step)*step
		dz = tools.round(dz/step)*step
	end
	shipInfo.core_movement[1] = dx
	shipInfo.core_movement[2] = dy
	shipInfo.core_movement[3] = dz
	warpdrive.SetCoreMovement(dx,dy,dz)
	warpdrive.SetRotation(tonumber(rot))

end

function tools.CheckInputEvent(event, container)
	if event[1] == container.evType then
		if container.evType == "touch" then
			if ecs.clickedAtArea(event[3], event[4], container.sx, container.sy, container.ex, container.ey) then
				if container.action ~= nil then
					container.action(event)
				end
			end
		end
	end
end

function tools.SaveData(filename, object)
  fs.makeDirectory(fs.path(filename) or "")
	local file = io.open(""..filename, "w")
	if file ~= nil then
		file:write(serialization.serialize(object))
		file:close()
	else
		print("DATA SAVE ERROR!")
	end
end

function tools.LoadData(filename)
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

function tools.SendTelemetry(...)
	if c.isAvailable("tunnel") == false then
		return
	end
	local tunnel = c.tunnel
	if tunnel == nil then
		return false
	end
	
	tunnel.send(...)
	
end

function tools.round(x)
  if x%2 ~= 0.5 then
    return math.floor(x+0.5)
  end
  return x-0.5
end

function softLogic.ParseRCCommand(command,sender)
	if command == nil then
		return
	end
	
	local args = tools.splitString(command, " ")
	
	if args[1] == "!rc" then
		if args[2] ~= shipInfo.name then
			return
		end
		if args[3] == "jump" then
			tools.SetJumpTarget(args[4],args[5],args[6],args[7])
			warpdrive.Warp(false)
			warpLockFlag = true	
			WGUI.DrawNav()
			inputHandler = WGUI.HandleNavInput				
		elseif args[3] == "shutdown" then
			softLogic.Quit()
			computer.shutdown()
		elseif args[3] == "air" then
			if args[4] == "on" then
				softLogic.SetAirGenerators(true)
			elseif args[4] == "off" then
				softLogic.SetAirGenerators(false)
			end
		elseif args[3] == "lock" then
			programSettings.lock = true
			softLogic.Save()
		elseif args[3] == "unlock" then
			programSettings.lock = false
			softLogic.Save()
		elseif args[3] == "addTrusted" then
			if args[4] ~= nil then
				softLogic.addTrusted(args[4])
			end
		elseif args[3] == "removeTrusted" then
			if args[4] ~= nil then
				softLogic.removeTrusted(args[4])
			end			
		elseif args[3] == "autopilot" then
			if args[4] ~= nil then
				for i= 1, #navPoints do
					if navPoints[i][1] == args[4] then
						autopilot.SetTarget(navPoints[i])
						autopilot.Start()
					end
				end
			end			
		elseif args[3] == "newPoint" then
			if args[4] ~= nil then
				local nPoint = {args[4], args[5], tonumber(args[6]), tonumber(args[7]), tonumber(args[8])}
				table.insert(navPoints, nPoint)
				if inputHandler == WGUI.HandleNavInput then
					WGUI.DrawNav()
				end
			end		
		elseif args[3] == "autopilotStop" then
			autopilot.DeactivateAutopilot()
		elseif args[3] == "autoWander" then
			local wanderPoints = {}
			local k = 4
			while args[k] ~= nil do
				for i= 1, #navPoints do
					if navPoints[i][1] == args[k] then
						table.insert(wanderPoints,navPoints[i])
					end
				end
				k = k + 1
			end
			autopilot.wanderPoints = wanderPoints
			autopilot.mode = "wander"
			autopilot.wanderIndex = 1
			autopilot.SetTarget(autopilot.wanderPoints[1])
			autopilot.Start()
		end
	end
end

function softLogic.addTrusted(name)
	table.insert(trustedPlayers, name)
end

function softLogic.removeTrusted(name)
	for i=1,#trustedPlayers do
		if trustedPlayers[i] == name then
			table.remove(trustedPlayers,i)
			return
		end
	end
end

--к сожалению, как оказалось, управляющего метода у генератора воздуха нет. когда добавят, можно будет быстро допилить. Upd: метод добавлен в репу на гитхабе, надо проверить, есть ли он в релизе.
function softLogic.SetAirGenerators(flag)
	if flag == true then
	
	else
	
	end
end

function softLogic.SwitchToHyper()
	warpdrive.SwitchHyper()
	warpLockFlag = true
	for i=1,35 do
		ecs.square(30,20,45,5,colors.window)
		ecs.colorText( 32, 21, 0x000000, "Ожидайте...")
		ecs.colorText( 32, 22, 0x000000, "Гипер-переход выполняется...")
		ecs.colorText( 32, 23, 0x000000, "Терминал заблокирован на "..tostring(35-i).." секунд")
		computer.beep(80,0.5)
		os.sleep(0.5)
	end
	local x,y,z = warpdrive.GetShipPosition()
	tools.SendTelemetry("Ship Position after hyper transfer ",x,y,z)		
	WGUI.Clear()  	
	WGUI.DrawNav()
	inputHandler = WGUI.HandleNavInput	
end

function softLogic.Quit()
    mainCycleFlag = false
	WGUI.Clear()
	WGUI.DrawExitScreen()
	softLogic.Save()
	if CheckCore() then
		warpdrive.TurnOffCore()
	end
end

function softLogic.Save()
	tools.SaveData(applicationDataPath.."/WarpMasterNavPoints.txt", navPoints)
	tools.SaveData(applicationDataPath.."/WarpMasterSettings.txt", programSettings)
	tools.SaveData(applicationDataPath.."/WarpMasterTrustedPlayers.txt", trustedPlayers)
end

function softLogic.Load()
	local loadedData = tools.LoadData(applicationDataPath.."/WarpMasterNavPoints.txt")
	if loadedData ~= nil then
		navPoints = loadedData
	end
	loadedData = tools.LoadData(applicationDataPath.."/WarpMasterSettings.txt")
	if loadedData ~= nil then
		programSettings = loadedData
	end
	loadedData = tools.LoadData(applicationDataPath.."/WarpMasterTrustedPlayers.txt")
	if loadedData ~= nil then
		trustedPlayers = loadedData
	end
  
  if programSettings.planetsListFile == nil then
    programSettings.planetsListFile = "Empty"
  end
  loadedData = tools.LoadData(applicationDataPath.."/"..programSettings.planetsListFile..".txt")
	if loadedData ~= nil then
		celestialBodies = loadedData
	end
end

function WGUI.Clear()  
	c.gpu.setResolution(100,50)
	buffer.flush(100, 50)

	WGUI.DrawBackground()
	WGUI.DrawStatusBars()
end

function WGUI.DrawBackground() 
	ecs.clearScreen(colors.black)
end

function WGUI.MenuClick()
	WGUI.DrawMenu()
	inputHandler = WGUI.HandleMenuInput
end

function WGUI.NavClick()
	WGUI.DrawNav()
	inputHandler = WGUI.HandleNavInput
end

function WGUI.WarpClick()
	local movement = warpdrive.GetCoreMovement()
	WGUI.DrawPrecizeJumpWindow(movement[1],movement[2],movement[3])
end

function WGUI.PointsClick()

end

function WGUI.JumpClick()
	WGUI.JumpButtonPush()
end

function WGUI.HyperClick()
	WGUI.DrawHyperTransferWindow()
end

function WGUI.InfoClick()
	WGUI.DrawShipInfoSummary()
end

function WGUI.DrawStatusBars()
	ecs.square(1, 1, 100, 1, colors.panel)
	ecs.square(1, 50, 100, 1, colors.panel)
	ecs.colorTextWithBack(1, 50, colors.white, colors.panel, "  МЕНЮ    НАВ    ВАРП    ИНФО    ТОЧКИ    ПРЫЖОК    ГИПЕР    ")
	ecs.drawCloses(1, 1, 1)
	ecs.colorTextWithBack(73, 1, colors.white, colors.panel, "Заряд [")
	ecs.colorTextWithBack(100, 1, colors.white, colors.panel, "]")
	
	local chargePercent = 0
	local energyLevel, maxEnergy = 0,1
	if CheckCore() == true then
		energyLevel, maxEnergy = warpdrive.GetEnergyLevel()
		chargePercent = math.ceil((energyLevel / maxEnergy) *100)
	end
	
	ecs.progressBar(80, 1, 20, 1, 0xCCCCCC, ecs.colors.blue, chargePercent)
	ecs.colorText(85,1,colors.white,tostring(energyLevel))
end

function WGUI.HandleBarInput(e)

	local statusBarZones = {
		{1,8,WGUI.MenuClick},
		{9,15,WGUI.NavClick},
		{16,23,WGUI.WarpClick},
		{24,31,WGUI.InfoClick},
		{32,40,WGUI.PointsClick},
		{41,50,WGUI.JumpClick},
		{51,60,WGUI.HyperClick}
	}

	if e[1] == "touch" then
		for i=1, #statusBarZones do
			if ecs.clickedAtArea(e[3], e[4], statusBarZones[i][1], 50, statusBarZones[i][2], 50) then
				if statusBarZones[i][3] ~= nil then
					statusBarZones[i][3]()
				else 
					print("ERROR")
				end
			end
		end
	end
end

function WGUI.DrawLoadScreen() 
	ecs.emptyWindow(30,15,40,20,"Warp Navigation Master")
	WGUI.logo = image.load("MineOS/Applications/WarpMaster.app/Resources/WarpMasterIcon.pic")
	image.draw(35,16,WGUI.logo)
end

function WGUI.DrawShipSizeWindow()
	local okText = "ОК"
	local cancelText = "Отмена"
	
	local GFront, GRight, GUp, GBack, GLeft, GDown = warpdrive.GetDimensions()

	local data = ecs.universalWindow("auto", "auto", 40, colors.window, true,
		{"CenterText", colors.text, "Настройка размеров корабля"},
		{"EmptyLine"},
		{"CenterText", colors.text, "Блоки спереди:"},
		{"Input", 0x262626, colors.text, tostring(GFront)},
		{"CenterText", colors.text, "Блоки сзади:"},
		{"Input", 0x262626, colors.text, tostring(GBack)},
		{"CenterText", colors.text, "Блоки сверху:"},
		{"Input", 0x262626, colors.text, tostring(GUp)},
		{"CenterText", colors.text, "Блоки снизу:"},
		{"Input", 0x262626, colors.text, tostring(GDown)},
		{"CenterText", colors.text, "Блоки слева:"},
		{"Input", 0x262626, colors.text, tostring(GLeft)},
		{"CenterText", colors.text, "Блоки справа:"},
		{"Input", 0x262626, colors.text, tostring(GRight)},

		{"Separator", 0xaaaaaa},
		{"Button", {0x57A64E, 0xffffff, okText},{0xCC4C4C, 0xffffff, cancelText}}
	)
	
	if data[7] == okText then
		warpdrive.SetDimensions(tonumber(data[1]),tonumber(data[2]), tonumber(data[5]),tonumber(data[6]), tonumber(data[3]), tonumber(data[4]))
		LoadInfoFromCore()
	end
end

function WGUI.DrawPrecizeJumpWindow(x,y,z)
	local okText = "ОК"
	local cancelText = "Отмена"
	if x == nil then
		x = 0
	end
	if y == nil then
		y = 0
	end
	if z == nil then
		z = 0
	end
	
	local bound = warpdrive.maxJumpLength()
	
	local mindx, mindy,mindz = shipInfo.length+2, shipInfo.height+2, shipInfo.width+2
	
	local data = ecs.universalWindow("auto", "auto", 40, colors.window, true,
		{"CenterText", colors.text, "Установка точных параметров прыжка"},
		{"CenterText", colors.text, "Введенные значения будут ограничены автоматически."},
		{"EmptyLine"},
		{"CenterText", colors.text, "Ось вперед-назад ( "..mindx.." - "..tostring(bound + mindx)..")"},
		{"Input", 0x262626, colors.text, tostring(x)},
		{"CenterText", colors.text, "Ось верх-низ ( "..mindy.." - "..tostring(bound + mindy)..")"},
		{"Input", 0x262626, colors.text, tostring(y)},
		{"CenterText", colors.text, "Ось лево-право ( "..mindz.." - "..tostring(bound + mindz)..")"},
		{"Input", 0x262626, colors.text, tostring(z)},
		{"CenterText", colors.text, "Угол вращения по часовой стрелке (0 - 270)"},
		{"CenterText", colors.text, "Шаг 90 градусов"},
		{"Input", 0x262626, colors.text, "0"},
		{"Separator", 0xaaaaaa},
		{"Button", {0x57A64E, 0xffffff, okText},{0xCC4C4C, 0xffffff, cancelText}}
	)
	
	if data[5] == okText then
		if data[1] == nil or data[2] == nil or data[3] == nil then
			return
		end
		local dx,dy,dz = tonumber(data[1]),tonumber(data[2]),tonumber(data[3])
		if dx ~= 0 then
		dx = tools.ClampMagnitude(dx, mindx, warpdrive.maxJumpLength() + mindx)
		end
		if dy ~= 0 then
		dy = tools.ClampMagnitude(dy, mindy, warpdrive.maxJumpLength() + mindy)
		end
		if dz ~= 0 then
		dz = tools.ClampMagnitude(dz, mindz, warpdrive.maxJumpLength() + mindz)
		end
		shipInfo.core_movement[1] = dx
		shipInfo.core_movement[2] = dy
		shipInfo.core_movement[3] = dz
		warpdrive.SetCoreMovement(dx,dy,dz)
		warpdrive.SetRotation(tonumber(data[4]))
	end	
end

function WGUI.DrawHyperTransferWindow()
	local okText = "Да"	
	local cancelText = "Нет"
		
	if shipInfo.weight < 1200 then
		local msg = ecs.universalWindow("auto", "auto", 60, colors.window, true,
		{"CenterText", 0x262626, "Недостаточная масса корабля!"},
		{"CenterText", 0x262626, "Текущая масса корабля: "..tostring(shipInfo.weight)},
		{"CenterText", 0x262626, "Минимальная масса: 1200"},
		{"Button", {0x57A64E, 0xffffff, okText}}
		)
		return
	end
	
	local data = ecs.universalWindow("auto", "auto", 60, colors.window, true,
	{"CenterText", 0x262626, "Вы действительно хотите совершить гипер-переход?"},
	{"CenterText", 0x262626, "Отменить действие будет невозможно!"},
	{"Button", {0x57A64E, 0xffffff, okText},{0xCC4C4C, 0xffffff, cancelText}}
	)
	if data[1] == okText then
		softLogic.SwitchToHyper()
	end
end

function WGUI.DrawCoreNotFoundError() 
	local errorText = "";
	if not warpdrive.HasController() then
		errorText = "Отсутствует варп контроллер!"
	else 
		if not warpdrive.HasCore() then
			errorText = "Отсутствует ядро корабля!"
		end
	end
	
	ecs.universalWindow("auto", "auto", 30, colors.window, true,
	{"EmptyLine"},
	{"CenterText", 0x262626, "Ошибка!"},
	{"CenterText", 0x262626, errorText},
	{"EmptyLine"},
	{"Button", {0x880000, 0xffffff, "ОК!"}}
	)
end

function WGUI.DrawShipNameSetDialog()
	local okText = "ОК"
	local cancelText = "Отмена"

	local oldName = warpdrive.GetShipName()
	local data = ecs.universalWindow("auto", "auto", 40, colors.window, true,
	{"EmptyLine"},
	{"CenterText", 0x262626, "Введите имя корабля:"},
	{"Input", 0x262626, colors.text, oldName},
	{"EmptyLine"},
	{"Button", {0x57A64E, 0xffffff, okText},{0xCC4C4C, 0xffffff, cancelText}}
	)
	
	if data[2] == okText then
		warpdrive.SetShipName(data[1])
	end
end

function WGUI.DrawShipInfoSummary()
	LoadInfoFromCore()
	local okText = "ОК"
	
	local data = ecs.universalWindow("auto", "auto", 50, colors.window, true,
	{"CenterText", 0x262626, "Информация о корабле "..shipInfo.name},
	{"CenterText", 0x262626, "Масса: "..shipInfo.weight},
	{"CenterText", 0x262626, "Длина: "..shipInfo.length},
	{"CenterText", 0x262626, "Ширина: "..shipInfo.width},
	{"CenterText", 0x262626, "Высота: "..shipInfo.height},
	{"EmptyLine"},
	{"Button", {0x57A64E, 0xffffff, okText}}
	)
end

function WGUI.DrawShipInfoDump()
	local x,y,z = warpdrive.GetShipPosition()
	tools.SendTelemetry("Ship Position",x,y,z)

	local infoText = tools.dump(shipInfo)
	ecs.universalWindow("auto", "auto", 44, colors.window, true,
	{"CenterText", 0x262626, "Информация о корабле:"},
	{"EmptyLine"},
	{"TextField", 10, 0xffffff, 0x262626, 0xcccccc, 0x3366CC, infoText},
	{"EmptyLine"},
	{"Button", {0x008800, 0xffffff, "ОК!"}}
	)
end

function WGUI.DrawExitScreen()
	ecs.emptyWindow(30,15,40,20,"Warp Navigation Master")
	ecs.colorText(40, 24, colors.text, "Приложение закрывается")
	ecs.colorText(40, 25, colors.text, "Благодарим за использование")
	ecs.colorText(40, 26, colors.text, "программы WarpMaster!")
end

function WGUI.ManageTrustedPlayers() 
	local cancelText = "Отмена"
	local addPlyText = "Добавить"
	local remPlyText = "Удалить"

	local trustedList = ""
	
	for i=1, #trustedPlayers do
		trustedList = trustedList .. trustedPlayers[i] .. " "
	end
	
	local data = ecs.universalWindow("auto", "auto", 70, colors.window, true,
	{"EmptyLine"},
	{"CenterText", 0x262626, "Управление доверенными игроками"},
	{"CenterText", 0x262626, "Игроки из списка смогут управлять кораблем через чат."},
	{"CenterText", 0x262626, "Список доверенных игроков:"},
	{"TextField", 10, 0xffffff, 0x262626, 0xcccccc, 0x3366CC, trustedList},
	{"EmptyLine"},
	{"CenterText", 0x262626, "Введите ник игрока, которого вы хотите добавить/удалить:"},
	{"Input", 0x262626, colors.text, ""},
	{"EmptyLine"},
	{"Button", {0xCC4C4C, 0xffffff, remPlyText},{0x57A64E, 0xffffff, addPlyText},{0xCC4C4C, 0xffffff, cancelText}}
	)
	
	if data[2] == addPlyText then
		softLogic.addTrusted(data[1])
	elseif data[2] == remPlyText then
		softLogic.removeTrusted(data[1])
	end
end

function WGUI.DrawSoftwareUpdateWindow()
	local okText = "ОК"
	local cancelText = "Отмена"

	local data = ecs.universalWindow("auto", "auto", 55, colors.window, true,
	{"EmptyLine"},
	{"CenterText", 0x262626, "Вы хотите загрузить обновление?"},
	{"CenterText", 0xCC4C4C, "Все изменения в коде программы будут потеряны!"},
	{"EmptyLine"},
	{"Button", {0x57A64E, 0xffffff, okText},{0xCC4C4C, 0xffffff, cancelText}}
	)
	
	if data[1] == okText then
    
    local oldPixels = ecs.rememberOldPixels(30, 20, 75, 25)
   	ecs.square(30,20,45,5,colors.window)
		ecs.colorText( 32, 22, 0x000000, "Обновление программы...")
    
    
    local paths = tools.LoadFileList()
    if paths ~= nil then
      tools.DownloadUpdate(paths)
    end		
    
    ecs.drawOldPixels(oldPixels)
    
    data = ecs.universalWindow("auto", "auto", 50, colors.window, true,
	    {"EmptyLine"},
	    {"CenterText", 0x262626, "Готово."},
	    {"CenterText", 0xCC4C4C, "Теперь перезапустите программу."},
	    {"EmptyLine"},
	    {"Button", {0x57A64E, 0xffffff, okText}}
	  )
	end
end

WGUI.MenuButtons = {
	{
	title = "Имя корабля",
	sx = 6,
	sy = 6,
	ex = 24,
	ey = 10,
	action = WGUI.DrawShipNameSetDialog,
	evType = "touch"
	},
	{
	title = "Размеры корабля",
	sx = 6,
	sy = 12,
	ex = 24,
	ey = 16,
	action = WGUI.DrawShipSizeWindow,
	evType = "touch"
	},
	{
	title = "Инфо",
	sx = 6,
	sy = 18,
	ex = 24,
	ey = 22,
	action = WGUI.DrawShipInfoDump,
	evType = "touch"
	},
	{
	title = "Доверенные игроки",
	sx = 6,
	sy = 24,
	ex = 24,
	ey = 29,
	action = WGUI.ManageTrustedPlayers,
	evType = "touch"
	},
	{
	title = "Обновить ПО",
	sx = 6,
	sy = 30,
	ex = 24,
	ey = 35,
	action = WGUI.DrawSoftwareUpdateWindow,
	evType = "touch"
	}
}

function WGUI.DrawMenu()
	ecs.square(1,2,100,48,0x000000)
	ecs.border(1, 2,100, 48, 0x000000, 0xffffff)
	
	for i = 1, #WGUI.MenuButtons do
		local button = WGUI.MenuButtons[i]
		ecs.drawButton(button.sx,button.sy,button.ex - button.sx,button.ey - button.sy,button.title,colors.menuButton,colors.black)
	end
end

function WGUI.HandleMenuInput(e)
	
	for i = 1, #WGUI.MenuButtons do
		local button = WGUI.MenuButtons[i]
		tools.CheckInputEvent(e, button)	
	end
end

function WGUI.DrawNav()
	local scalex = programSettings.navScaleX -- блоков на знакоместо по x
	local scaley = programSettings.navScaleY -- аналогично по y
	
	local x,y,z = warpdrive.GetShipPosition()
	local ox, oy, oz = warpdrive.GetShipOrientation()
	local warpD = warpdrive.CalcDestinationPoint()
	
	local maxZ = z + 40 * scalex
	local maxX = x + 23*scaley
	local minZ = z - 40 * scalex
	local minX = x - 23*scaley
	
	local orientationSymbol = "^"
	
	local function CheckNavPointRange(navPoint)
		if programSettings.currentWorldType == navPoint[2] then
			return true
		else 
			return false
		end
	end 
	
	ecs.square(20,2,81,48,0x000000)
	ecs.square(1,2,19,48,0x000000)
	
	
	local mindx, mindy,mindz = shipInfo.length+1, shipInfo.height+1, shipInfo.width+1
	local maxBound = warpdrive.maxJumpLength()
	local jRectX = tools.Clamp( 60 - (maxBound + mindz)/scalex,21,99)
	local jRectY = tools.Clamp( 25 - (maxBound + mindx)/scaley,3,48)
	
	ecs.border(jRectX, jRectY, tools.Clamp(( (maxBound + mindz)*2)/scalex,0,78), tools.Clamp(( (maxBound + mindx)*2)/scaley,0,45), 0x000000, 0xff0000)
	
	ecs.colorText(21, 4, 0xffffff, "X: "..x)
	ecs.colorText(21, 5, 0xffffff, "Y: "..y)
	ecs.colorText(21, 6, 0xffffff, "Z: "..z)
	ecs.colorText(21, 7, 0xffffff, "Ориентация: X:"..ox.." Z:"..oz)
	ecs.border(20, 2, 81, 48, 0x000000, 0xffffff)
	ecs.border(1, 2,19, 48, 0x000000, 0xffffff)
	ecs.colorText(2, 3, 0xffffff, "Нав. точки:")
	
	local pointIndex = 0

	local function GetWorldPointNavCoords(tx,ty,tz)
		local dx = tx - x
		local dz = tz - z
		local dspX = 0
		local dspY = 0
		if ox == 1 then
			dspX = dz
			dspY = -dx
		elseif ox == -1 then
			dspX = -dz
			dspY = dx
		elseif oz == 1 then
			dspX = -dx
			dspY = -dz
		elseif oz == -1 then
			dspX = dx
			dspY = dz
		end
		dspX = tools.Clamp(60 + math.floor(dspX/scalex), 21,99)
		dspY = tools.Clamp(25 + math.floor(dspY/scaley),3, 48)
		return dspX,dspY
	end
	
	displayedNavPoints = {}
	if programSettings.currentWorldType ~= "planetMap" then
		for i=1,#navPoints do
			if CheckNavPointRange(navPoints[i]) == true then
				pointIndex = pointIndex + 1
				local pointInfo = {}
				pointInfo.navIndex = i
				pointInfo.mapName = tostring(pointIndex)
				pointInfo.listName = pointIndex.." "..navPoints[i][1]
				local dx,dy = GetWorldPointNavCoords(navPoints[i][3],navPoints[i][4],navPoints[i][5])
				pointInfo.ex = string.len(pointInfo.mapName) - 1
				table.insert(displayedNavPoints,pointInfo)
				ecs.colorText(dx, dy, 0xffffff, pointInfo.mapName)
				ecs.colorText(2, 3 + pointIndex, 0xffffff, pointInfo.listName)
			end
		end
	else
		for i=1,#celestialBodies do
			pointIndex = pointIndex + 1
			local pointInfo = {}
			pointInfo.navIndex = i	
			pointInfo.mapName = string.sub(celestialBodies[i][1],1,3)
			pointInfo.listName = pointIndex.." "..celestialBodies[i][1]		
			local dx,dy = GetWorldPointNavCoords(celestialBodies[i][3],220,celestialBodies[i][4])	
			pointInfo.ex = string.len(pointInfo.mapName) - 1	
			table.insert(displayedNavPoints,pointInfo)
			ecs.colorText(dx, dy, 0xffffff, pointInfo.mapName)
			ecs.colorText(2, 3 + pointIndex, 0xffffff, pointInfo.listName)			
		end
	end
	local wtx,wty = GetWorldPointNavCoords(warpD.x,warpD.y,warpD.z)
	ecs.colorText( wtx, wty, 0x00ff00, "X")
	if autopilot.point ~= nil then 
		local atx,aty = GetWorldPointNavCoords(autopilot.point[3],autopilot.point[4],autopilot.point[5])
		ecs.colorText( atx, aty, 0x0000ff, "A")
	end
		
	ecs.colorText(60, 25, 0xffffff, orientationSymbol)
	if warpLockFlag == false then
		ecs.drawButton(21,2,7,1,"ГОТОВ",0x57A64E,0xffffff)
	else 
		ecs.drawButton(21,2,9,1,"НЕ ГОТОВ",0xCC4C4C,0xffffff)
	end
	
	local function placeButtonColor(place)
		if place == programSettings.currentWorldType then
			return colors.greenButton
		else 
			return colors.redButton
		end
	end
	ecs.drawButton(30,2,7,1,"ЗЕМЛЯ",placeButtonColor("earth"),0xffffff)
	ecs.drawButton(37,2,8,1,"КОСМОС",placeButtonColor("space"),0xffffff)
	ecs.drawButton(45,2,7,1,"ГИПЕР",placeButtonColor("hyper"),0xffffff)
	ecs.drawButton(52,2,9,1,"ПЛАНЕТЫ",placeButtonColor("planetMap"),0xffffff)
	
	ecs.drawButton(21,49,7,1,"НОВАЯ",0x57A64E,0xffffff)
	
	ecs.drawButton(73,49,6,1,"МАКС",0xCC4C4C,0x000000)
	ecs.drawButton(79,49,7,1,"СБРОС",0xFFF400,0x000000)
	ecs.drawButton(93,49,7,1,"МШТБ-",0xCC4C4C,0xffffff)
	ecs.drawButton(86,49,7,1,"МШТБ+",0x57A64E,0xffffff)
end

function WGUI.HandleNavInput(event)
	
	local windowDirty = false
	
	local eventHandlers = {
		{ evType = "touch",
		sx = 79, sy = 49, ex=85, ey = 49,
		action = function(event)
			programSettings.navScaleX = 8
			programSettings.navScaleY = 16
			windowDirty = true		 
		end},
		{ evType = "touch",
		sx = 73, sy = 49, ex=78, ey = 49,
		action = function(event)
			programSettings.navScaleX = 1000
			programSettings.navScaleY = 2000
			windowDirty = true		 
		end},
		{ evType = "touch",
		sx = 93, sy = 49, ex=100, ey = 49,
		action = function(event)
			programSettings.navScaleX = tools.Clamp(programSettings.navScaleX + 2, 1,2000)
			programSettings.navScaleY = tools.Clamp(programSettings.navScaleY + 4,2,2000)	
			windowDirty = true		 
		end},
		{ evType = "touch",
		sx = 86, sy = 49, ex=92, ey = 49,
		action = function(event)
			programSettings.navScaleX = tools.Clamp(programSettings.navScaleX - 2, 1,2000)
			programSettings.navScaleY = tools.Clamp(programSettings.navScaleY - 4,2,2000)	
			windowDirty = true		 
		end},
		{ evType = "touch",
		sx = 21, sy = 49, ex=28, ey = 49,
		action = function(event)
			WGUI.DrawNewNavPointWindow()
			windowDirty = true		 
		end},
		{ evType = "touch",
		sx = 21, sy = 3, ex=99, ey = 48,
		action = function(event)
			if programSettings.currentWorldType ~="planetMap" then
				WGUI.DrawNavWindowContextMenu(event)
				windowDirty = true
			end
		end},
		{ evType = "touch",
		sx = 30, sy = 2, ex=36, ey = 2,
		action = function(event)
			programSettings.currentWorldType = "earth"
			windowDirty = true	
		end},
		{ evType = "touch",
		sx = 37, sy = 2, ex=44, ey = 2,
		action = function(event)
			programSettings.currentWorldType = "space"
			windowDirty = true	
		end},
		{ evType = "touch",
		sx = 45, sy = 2, ex=51, ey = 2,
		action = function(event)
			programSettings.currentWorldType = "hyper"
			windowDirty = true	
		end},
		{ evType = "touch",
		sx = 52, sy = 2, ex=60, ey = 2,
		action = function(event)
			programSettings.currentWorldType = "planetMap"
			windowDirty = true	
		end}
	}

	for i=1,#eventHandlers do
		tools.CheckInputEvent(event, eventHandlers[i])
	end
	
	if event[1] == "touch" then
		for i=1,#displayedNavPoints do
			if ecs.clickedAtArea(event[3], event[4], 2, 3+i, 19, 3+i) then
				if programSettings.currentWorldType ~="planetMap" then
					WGUI.DrawViewPointInfoDialog(displayedNavPoints[i].navIndex)
					windowDirty = true	
				else
					WGUI.DrawPlanetInfoDialog(celestialBodies[displayedNavPoints[i].navIndex])
					windowDirty = true
				end
			end
		end
	end
	
	if windowDirty == true then -- запуск перерисовки окна
		WGUI.Clear()
		WGUI.DrawNav()
	end
end

function WGUI.DrawNewNavPointWindow(x,y,z)
	local okText = "ОК"
	local cancelText = "Отмена"
	local curPlaceText = "Тек. положение"

	if x == nil then
		x = 0
	end
	if y == nil then
		y = 0
	end
	if z == nil then
		z = 0
	end
	
	local data = ecs.universalWindow("auto", "auto", 40, colors.window, true,
	{"CenterText", 0x262626, "Добавить новую путевую точку:"},
	{"Input", 0x262626, colors.text, "Имя Точки"},
	{"CenterText", 0x262626, "X:"},
	{"Input", 0x262626, colors.text, tostring(x)},
	{"CenterText", 0x262626, "Y:"},
	{"Input", 0x262626, colors.text, tostring(y)},
	{"CenterText", 0x262626, "Z:"},
	{"Input", 0x262626, colors.text, tostring(z)},
	{"CenterText", 0x262626, "Пространство:"},
	{"Selector", 0x262626, 0x880000, programSettings.currentWorldType, "space", "hyper", "planet"},
	{"EmptyLine"},
	{"Button", {0x57A64E, 0xffffff, okText},{0xCC4C4C, 0xfff400, curPlaceText},{0xCC4C4C, 0xffffff, cancelText}}
	)
	
	local point = {}
	point[1] = data[1]
	point[2] = data[5]

	x = tonumber(data[2])
	y = tonumber(data[3])
	z = tonumber(data[4])
	point[3] = x
	point[4] = y
	point[5] = z
	
	if data[6] == okText then
		table.insert(navPoints, point)
	elseif data[6] == curPlaceText then
		point[3],point[4],point[5] = warpdrive.GetShipPosition()
		table.insert(navPoints,point)
	end
end

function WGUI.DrawRemoveNavPointDialog(pointIndex)
	local point = navPoints[pointIndex]
	if point == null then
		return
	end

	local okText = "Да"
	local cancelText = "Нет"
	
	local data = ecs.universalWindow("auto", "auto", 60, colors.window, true,
	{"CenterText", 0x262626, "Вы действительно хотите удалить точку ".. point[1].."?"},
	{"Button", {0x57A64E, 0xffffff, okText},{0xCC4C4C, 0xffffff, cancelText}}
	)
	
	if data[1] == okText then
		table.remove(navPoints, pointIndex)
	end
end

function WGUI.DrawViewPointInfoDialog(pointIndex)
	local point = navPoints[pointIndex]
	if point == null then
		return
	end
	local dist = WGUI.CalcDistanceToPoint(point[3],point[4],point[5])
	local okText = "OK"
	local setText = "Прыжок к точке"
	local autopilotText = "Автопилот"
	local removeText = "Удалить"
	local editText = "Редактировать"
	local data = ecs.universalWindow("auto", "auto", 40, colors.window, true,
	{"CenterText", 0x262626, "Информация о путевой точке: ".. point[1]},
	{"CenterText", 0x262626, "X: ".. point[3]},
	{"CenterText", 0x262626, "Y: ".. point[4]},
	{"CenterText", 0x262626, "Z: ".. point[5]},
	{"CenterText", 0x262626, "Пространство: ".. point[2]},
	{"CenterText", 0x262626, "Расстояние до точки: "..dist.."м."},
	{"Button", {0x57A64E, 0xffffff, editText},{0x57A64E, 0xffffff, setText},{0x57A64E, 0xffffff, autopilotText},{0xCC4C4C, 0xffffff, removeText}},
	{"Button", {0x57A64E, 0xffffff, okText}}
	)
	
	if data[1] == setText then
		local x,y,z = WGUI.WorldToShipRelativeCoordinates(point[3],point[4],point[5])
		local mindx, mindy,mindz = shipInfo.length+2, shipInfo.height+2, shipInfo.width+2
		local bound = warpdrive.maxJumpLength()
		x = tools.ClampMagnitude(x,mindx,bound + mindx)
		y = tools.ClampMagnitude(y,mindy,bound + mindy)
		z = tools.ClampMagnitude(z,mindz,bound + mindz)
		WGUI.DrawPrecizeJumpWindow(x,y,z)
	elseif data[1] == autopilotText then
		autopilot.SetTarget(point)
		autopilot.Start()
	elseif data[1] == removeText then
		WGUI.DrawRemoveNavPointDialog(pointIndex)
	elseif data[1] == editText then
		WGUI.DrawEditPointDialog(point)
	end
end

function WGUI.DrawEditPointDialog(point)
	local okText = "ОК"
	local cancelText = "Отмена"
	local curPlaceText = "Тек. положение"
	
	if point == null then
		return
	end
	
	local x,y,z = point[3],point[4],point[5]
	
	local data = ecs.universalWindow("auto", "auto", 40, colors.window, true,
	{"CenterText", 0x262626, "Редактировать путевую точку "..point[1]},
	{"Input", 0x262626, colors.text, point[1]},
	{"CenterText", 0x262626, "X:"},
	{"Input", 0x262626, colors.text, tostring(x)},
	{"CenterText", 0x262626, "Y:"},
	{"Input", 0x262626, colors.text, tostring(y)},
	{"CenterText", 0x262626, "Z:"},
	{"Input", 0x262626, colors.text, tostring(z)},
	{"CenterText", 0x262626, "Пространство:"},
	{"Selector", 0x262626, 0x880000, point[2], "space", "hyper", "planet"},
	{"EmptyLine"},
	{"Button", {0x57A64E, 0xffffff, okText},{0xCC4C4C, 0xfff400, curPlaceText},{0xCC4C4C, 0xffffff, cancelText}}
	)
	
	if data[6] == okText then
		point[1],point[2],point[3],point[4],point[5] = data[1],data[5],tonumber(data[2]),tonumber(data[3]),tonumber(data[4])
	elseif data[6] == curPlaceText then
		point[1],point[2] =  data[1],data[5]
		point[3],point[4],point[5] = warpdrive.GetShipPosition()
	end
	
end

function WGUI.DrawPlanetInfoDialog(point)
	if point == null then
		return
	end
	local dist = WGUI.CalcDistanceToPoint(point[3],0,point[4],true)
	local okText = "OK"
	local setText = "Прыжок к планете"
	local autopilotText = "Автопилот"
	
	local data = ecs.universalWindow("auto", "auto", 60, colors.window, true,
	{"CenterText", 0x262626, "Информация о планетарной точке: ".. point[1]},
	{"CenterText", 0x262626, "X: ".. point[3]},
	{"CenterText", 0x262626, "Z: ".. point[4]},
	{"CenterText", 0x262626, "Расстояние до планеты: "..dist.."м."},
	{"CenterText", 0x262626, "Радиус планеты: "..point[2].."м."},
	{"Button", {0x57A64E, 0xffffff, okText},{0x57A64E, 0xffffff, setText},{0x57A64E, 0xffffff, autopilotText}}
	)
	
	if data[1] == setText then
		local cx,cy,cz = warpdrive.GetShipPosition()
		local x,y,z = WGUI.WorldToShipRelativeCoordinates(point[3],cy,point[4])
		local mindx, mindy,mindz = shipInfo.length+2, shipInfo.height+2, shipInfo.width+2
		local bound = warpdrive.maxJumpLength()
		x = tools.ClampMagnitude(x,mindx,bound + mindx)
		y = tools.ClampMagnitude(y,mindy,bound + mindy)
		z = tools.ClampMagnitude(z,mindz,bound + mindz)
		WGUI.DrawPrecizeJumpWindow(x,y,z)
	elseif data[1] == autopilotText then
		local tmpNavPoint = {point[1],"space",point[3],0,point[4]}
		autopilot.SetTarget(tmpNavPoint)
		autopilot.Start()
	end
end

function WGUI.DrawNavWindowContextMenu(e)
	local newPoint = "Добавить точку"
	local removePoint = "Удалить точку"
	local pointInfo = "Инфо о точке"
	local setAsTarget = "Задать как цель"

	local action = GUI.contextMenu(e[3], e[4], {newPoint, false, ""}, {removePoint, false, ""}, {pointInfo, false, ""},{setAsTarget, false, ""}):show()
	if action == newPoint then
		local x,y,z = WGUI.ScreenToWorldCoordinates(e[3],e[4])
		WGUI.DrawNewNavPointWindow(x,y,z)
	elseif action == removePoint then
		local x,y,z = WGUI.ScreenToWorldCoordinates(e[3],e[4])
		local pointIndex = WGUI.GetNearestNavPointIndex(x,y,z, true)
		local foundPoint = navPoints[pointIndex]
		if foundPoint ~= nil then
			WGUI.DrawRemoveNavPointDialog(pointIndex)
		end
	elseif action == pointInfo then
		local x,y,z = WGUI.ScreenToWorldCoordinates(e[3],e[4])
		local pointIndex = WGUI.GetNearestNavPointIndex(x,y,z,true)
		local foundPoint = navPoints[pointIndex]
		if foundPoint ~= nil then
			WGUI.DrawViewPointInfoDialog(pointIndex)
		end
	elseif action == setAsTarget then
		local x,y,z = WGUI.ScreenToShipRelativeCoordinates(e[3],e[4])
		WGUI.DrawPrecizeJumpWindow(x,y,z)
	end
	
end

function WGUI.ScreenToWorldCoordinates(sx,sy)
	local x,y,z = warpdrive.GetShipPosition()
	local worldx,worldy,worldz = WGUI.ScreenToShipOffsetCoordinates(sx,sy)
	worldx = worldx + x
	worldy = worldy + y
	worldz = worldz + z
	return worldx,worldy,worldz
end

function WGUI.ScreenToShipOffsetCoordinates(sx,sy)
	local centerx,centery = 60,25
	local dx,dy = sx - centerx, sy - centery
	dy = -dy
	local ox, oy, oz = warpdrive.GetShipOrientation()
	local relX = ox*dy*programSettings.navScaleY - oz*dx*programSettings.navScaleX
    local relY = 0
	local relZ = oz*dy*programSettings.navScaleY + ox*dx*programSettings.navScaleX
	return relX,relY,relZ
end

function WGUI.ScreenToShipRelativeCoordinates(sx,sy)
	local centerx,centery = 60,25
	local dx,dy = sx - centerx, sy - centery
	dx = dx * programSettings.navScaleX
	dy = -dy * programSettings.navScaleY
	return dy,0,dx
end

--капец как криво, но должно работать. (и вроде бы таки работает)
function WGUI.WorldToShipRelativeCoordinates(tx,ty,tz)
	local posx,posy,posz = warpdrive.GetShipPosition()
	local ox, oy, oz = warpdrive.GetShipOrientation()
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

function WGUI.CalcDistanceToPoint(x,y,z, ignoreY)
	if ignoreY == nil then
		ignoreY = false
	end
	if y == nil then
		y = 0
	end
	local posx,posy,posz = warpdrive.GetShipPosition()
	x = x - posx
	y = y - posy
	z = z - posz
	if ignoreY == true then
		y = 0
	end
	local dist = math.sqrt(x*x + y*y + z*z)
	
	return math.floor(dist)
end

function WGUI.GetNearestNavPointIndex(x,y,z, ignoreY)
	if ignoreY == nil then
		ignoreY = false
	end
	local function GetSquaredDelta(x1,y1,z1,x2,y2,z2) 
		local dx = x2 - x1
		local dy = y2 - y1
		local dz = z2 - z1
		local mg = dx*dx + dy*dy + dz*dz
		return mg
	end
	
	if navPoints[1] == nil then
		return
	end
	local nearest = 1
	local minDist = GetSquaredDelta(navPoints[1][3],navPoints[1][4],navPoints[1][5],x,y,z)
	
	for i=1,#navPoints do
		dst = 0
		if ignoreY == true then
			dst = GetSquaredDelta(navPoints[i][3],0,navPoints[i][5],x,0,z)
		else
			dst = GetSquaredDelta(navPoints[i][3],navPoints[i][4],navPoints[i][5],x,y,z)
		end
		
		if dst < minDist then
			nearest = i
			minDist = dst
		end
	end
	
	return nearest
	
end
--TODO: поправить баг с нерабочей проверкой безопасности
function WGUI.JumpButtonPush()
	tools.SendTelemetry("JumpButtonPush")

	if warpdrive.MakePreFlightCheck() == nil then
		local okText = "OK"	
		local data = ecs.universalWindow("auto", "auto", 60, colors.window, true,
		{"CenterText", 0x262626, "Ошибка!"},
		{"CenterText", 0x262626, "Невозможно совершить прыжок"},
		{"Button", {0x57A64E, 0xffffff, okText}}
		)
	else
		local okText = "Да"	
		local cancelText = "Нет"
		
		local jumpDistance = warpdrive.CalcJumpDistance()
		local energyCost = warpdrive.GetJumpEnergyCost(jumpDistance)
		
		
		local data = ecs.universalWindow("auto", "auto", 60, colors.window, true,
		{"CenterText", 0x262626, "Вы действительно хотите совершить прыжок?"},
		{"CenterText", 0x262626, "Отменить действие будет невозможно!"},
		{"CenterText", 0x262626, "Прыжок потребует "..tostring(energyCost).." EU"},
		{"Button", {0x57A64E, 0xffffff, okText},{0xCC4C4C, 0xffffff, cancelText}}
		)
		if data[1] == okText then
			warpdrive.Warp(false)
			warpLockFlag = true
			for i=1,15 do
				ecs.square(30,20,45,5,colors.window)
				ecs.colorText( 32, 21, 0x000000, "Ожидайте...")
				ecs.colorText( 32, 22, 0x000000, "Прыжок выполняется...")
				ecs.colorText( 32, 23, 0x000000, "Терминал заблокирован на "..tostring(15-i).." секунд")
				computer.beep(25+15*25,0.5)
				os.sleep(0.5)
			end

			local x,y,z = warpdrive.GetShipPosition()
			tools.SendTelemetry("Ship Position",x,y,z)			
			WGUI.Clear()  
			WGUI.DrawNav()
			inputHandler = WGUI.HandleNavInput			
			
		end
		
	end
end


function WGUI.HandleAutopilot(event)
	if event[1] == "touch" then
		if ecs.clickedAtArea(event[3], event[4], 1, 1, 100, 50) then
			autopilot.DeactivateAutopilot()
		end
	end
end

function WGUI.DrawAutopilotBusyWindow()
	WGUI.Clear()
	WGUI.DrawNav()
	ecs.square(30,20,50,5,colors.window)
	ecs.colorText( 32, 21, 0xFF0000, "Автопилот активен")
	ecs.colorText( 32, 22, 0x000000, "Оценочное расстояние до точки: "..autopilot.remainingDistance.."м.")
	ecs.colorText( 32, 23, 0x000000, "Кликните по экрану для отключения автопилота")
end

function WGUI.FirstLaunch()
	local okText = "ОК"
	local cancelText = "Отмена"

	local data = ecs.universalWindow("auto", "auto", 60, colors.window, true,
	{"EmptyLine"},
	{"CenterText", 0x262626, "Добро пожаловать!"},
	{"CenterText", 0x262626, "Вы установили программу Warp Master"},
	{"CenterText", 0x262626, "созданную специально для управления"},
	{"CenterText", 0x262626, "космическими кораблями."},
	{"EmptyLine"},
	{"CenterText", 0xCC4C4C, "Для продолжения нажмите ОК"},
	{"Button", {0x57A64E, 0xffffff, okText}}
	)
	
	data = ecs.universalWindow("auto", "auto", 60, colors.window, true,
	{"EmptyLine"},
	{"CenterText", 0x262626, "Первым делом вам надо задать имя корабля."},
	{"CenterText", 0x262626, "Если вы собираетесь использовать дистанционное"},
	{"CenterText", 0x262626, "управление, то не пропускайте этот шаг."},
	{"EmptyLine"},
	{"CenterText", 0x262626, "В следующем окне введите имя корабля"},
	{"CenterText", 0xCC4C4C, "И нажмите ОК"},
	{"Button", {0x57A64E, 0xffffff, okText}}
	)
	WGUI.DrawShipNameSetDialog()
	
	data = ecs.universalWindow("auto", "auto", 70, colors.window, true,
	{"EmptyLine"},
	{"CenterText", 0x262626, "Теперь необходимо задать размеры корабля."},
	{"CenterText", 0x262626, "Шаг ВАЖНЫЙ!"},
	{"CenterText", 0x262626, "Вы же не хотите после прыжка оказаться с половиной корабля?"},
	{"EmptyLine"},
	{"CenterText", 0x262626, "Подсказка:"},
	{"CenterText", 0x262626, "Ось X (перед-зад) корабля проходит через ядро и контроллер"},
	{"CenterText", 0x262626, "И направлена в сторону контроллера."},
	{"CenterText", 0x262626, "Другими словами, контроллер должен смотреть вперед корабля."},
	{"CenterText", 0x262626, "Размеры задаются без учета блока ядра."},
	{"CenterText", 0x262626, "Т.е. если бы корабль состоял только из блока ядра"},
	{"CenterText", 0x262626, "Его размеры были бы 0 0 0"},
	{"EmptyLine"},
	{"CenterText", 0xCC4C4C, "ОК для продолжения..."},
	{"Button", {0x57A64E, 0xffffff, okText}}
	)
	
	WGUI.DrawShipSizeWindow()
	
	data = ecs.universalWindow("auto", "auto", 70, colors.window, true,
	{"EmptyLine"},
	{"CenterText", 0x262626, "Отлично!"},
	{"CenterText", 0x262626, "Теперь вам надо назначить себя владельцем корабля."},
	{"CenterText", 0x262626, "В следующем окне в поле для ввода введите свой ник и нажмите Добавить."},
	{"EmptyLine"},
	{"Button", {0x57A64E, 0xffffff, okText}}
	)
	
	WGUI.ManageTrustedPlayers() 
	
	data = ecs.universalWindow("auto", "auto", 60, colors.window, true,
	{"EmptyLine"},
	{"CenterText", 0x262626, "Готово!"},
	{"CenterText", 0x262626, "В случае чего, вы в любой момент можете изменить эти настройки"},
	{"CenterText", 0x262626, "кликнув по пункту МЕНЮ нижней панели."},
	{"EmptyLine"},
	{"CenterText", 0x262626, "Успешных полетов!"},
	{"Button", {0x57A64E, 0xffffff, okText}}
	)
	
	programSettings.firstLaunch = false
	softLogic.Save()
	
end

local function WarpSoftInit()
	LoadInfoFromCore()
end

local function CheckPlayer(name)
	for i=1,#trustedPlayers do
		if trustedPlayers[i] == name then
			return true
		end
	end
	return false
end

local function HandleInput(event)
	if event[1] == "shipCoreCooldownDone" then
		tools.SendTelemetry("Core cooldown done")
		computer.beep(800,1)
		warpLockFlag = false
		if programSettings.autopilotEnabled == true then
			autopilot.ReadyToNextJump()
		end
		if inputHandler == WGUI.HandleNavInput then
			WGUI.DrawNav()
		end
	elseif event[1] == "chat_message" then
		local ply_name = event[3]
		local message = event[4]
		if CheckPlayer(ply_name) == true then
			softLogic.ParseRCCommand(message,ply_name)
		else
			return
		end
	end
	
	if programSettings.lock == true then
		return
	end

	if (inputHandler ~= nil) then
		inputHandler(event)
	end
	
	if event[1] == "touch" then
		if ecs.clickedAtArea(event[3], event[4], 1, 1, 1, 1) then
			mainCycleFlag = false
		end
	end
end

--Точка входа
filesystem.setAutorunEnabled(false)
softLogic.Load()

if programSettings.autopilotEnabled == true then
	programSettings.autopilotEnabled = false
	programSettings.autopilotTarget = nil
end


WGUI.Clear()
os.sleep(0.3)
WGUI.DrawLoadScreen()
os.sleep(1)
WGUI.Clear()

if not CheckCore() then
	WGUI.DrawCoreNotFoundError()
	mainCycleFlag = false
else
	WarpSoftInit()
	
	if programSettings.firstLaunch == true or programSettings.firstLaunch == nil then
		WGUI.FirstLaunch()
	end
	
	WGUI.DrawNav()
	inputHandler = WGUI.HandleNavInput

end
 
while mainCycleFlag == true do
	local e = {event.pull()}
	if 	programSettings.lock == false then
		WGUI.HandleBarInput(e)
	end
	HandleInput(e)
end
softLogic.Quit()