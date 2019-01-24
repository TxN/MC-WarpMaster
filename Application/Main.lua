local c  = require("component")
local fs = require("filesystem")

local warpLockFlag  = false

local libraries = {
	buffer        = "doubleBuffering",
	ecs           = "ECSAPI",
	event         = "event",
	image         = "image",
	unicode       = "unicode",
	warpdrive     = "libwarp",
	serialization = "serialization",
	filesystem    = "filesystem",
	computer      = "computer",
	internet      = "internet",
  wmUtils       = "wm_utils",
  GUI           = "GUI",
  MineOSCore    = "MineOSCore",
  MineOSPaths   = "MineOSPaths"
}
for library in pairs(libraries) do if not _G[library] then _G[library] = require(libraries[library]) end end; libraries = nil

local autopilot = require("wm_autopilot")

local fileListURL            = "https://raw.githubusercontent.com/TxN/MC-WarpMaster/master/Installer/FileList.cfg"
local versionCheckURL        = "https://raw.githubusercontent.com/TxN/MC-WarpMaster/master/Application/Version.txt"
local applicationPath        = MineOSCore.getCurrentScriptDirectory()
local currentVersionFilePath = applicationPath.."/Version.txt"
local applicationDataPath    = MineOSPaths.applicationData .. "WarpMasterData"

local colors = {
	background  = 0x262626,
	window      = 0x4e8bc4,
	panel       = 0x262646,
	text        = 0x11202d,
	white       = 0xffffff,
	black       = 0x000000,
	menuButton  = 0xff7a00,
	redButton   = 0xCC4C4C,
	greenButton = 0x57A64E,
  greenDark   = 0x47903E,
  gray        = 0x2D2D2D,
  blue        = 0x3366CC
}

local worldTypes = {
  earth  = "Земля",
  space  = "Космос",
  hyper  = "Гипер",
  planet = "Планета",
  other  = "Прочее"
 }
 
local uiModes = {}
uiModes["NAV"] = "Навигация"
uiModes["OPT"] = "Настройки"
uiModes["UTL"] = "Инструменты"
uiModes["NFO"] = "Инфо"
-- AUT - автопилот (скрытый режим)

local programSettings = {
	firstLaunch      = true,
	navScaleX        = 4,
	navScaleY        = 8,
	currentWorldType = "earth",
	lock             = false, 
	planetsListFile  = "Empty",
  currentGUIMode   = "NAV"
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

local trustedPlayers = {}

local function LoadInfoFromCore()
	shipInfo.name   = warpdrive.GetShipName()
	shipInfo.weight = warpdrive.GetShipWeight()
	shipInfo.height = warpdrive.GetShipHeight()
	shipInfo.length = warpdrive.GetShipLength()
	shipInfo.width  = warpdrive.GetShipWidth()
	shipInfo.core_front,shipInfo.core_right,shipInfo.core_up,shipInfo.core_back,shipInfo.core_left,shipInfo.core_down = warpdrive.GetDimensions()
	shipInfo.core_movement      = warpdrive.GetCoreMovement()
	shipInfo.core_rotationSteps = warpdrive.GetRotation(false) 
end

--структуры, хранящие методы и не только
local WGUI      = {}
local tools     = {}
local softLogic = {}
local shipLogic = {}

WGUI.screenWidth  = 160
WGUI.screenHeight = 50

--	{"NavPoint1","earth", 140,80,-200, "POI","Secret base"},
local navPoints = {  }

-- Формат описания навигационных точек:
-- point = {
	-- mapName = "pointMapName",
	-- listName = "pointListName",
	-- navIndex = 1,
	-- ex = 2
-- }

local navPointAppearance = {
    DEF = {color = colors.white, short = "НЗВ", long = "Неизвестно"},
    NAV = {color = colors.white, short = "НАВ", long = "Навигационная точка"},
    POI = {color = 0x0065FF, short = "ИНТ", long = "Точка интереса"},
    SHP = {color = 0xFF4900, short = "КОР", long = "Корабль"},
    RES = {color = 0xCC9240, short = "РЕС", long = "Ресурсы"},
  }

local displayedNavPoints = {}

--Данные об областях перехода на планеты
local celestialBodies = {}

function tools.CheckForUpdates()
  local result = false
  local version = 0
  local curVersion = 0
  local success, response = ecs.internetRequest(versionCheckURL)
  if success == true then
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
  return result, curVersion, version
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

function softLogic.IsTrustedPlayer(name)
	for i=1, #trustedPlayers do
		if trustedPlayers[i] == name then
			return true
		end
	end
	return false
end

function softLogic.AddTrusted(name)
  if name ~= nil and name ~= "" then
    	table.insert(trustedPlayers, name)
  end
end
function softLogic.RemoveTrusted(name)
	for i=1,#trustedPlayers do
		if trustedPlayers[i] == name then
			table.remove(trustedPlayers,i)
			return
		end
	end
end

function softLogic.ParseRCCommand(command,sender)
	if command == nil then
		return
	end
	local args = wmUtils.splitString(command, " ")
	
	if args[1] == "!rc" then
		if args[2] ~= shipInfo.name then
			return
		end
		if args[3] == "jump" then
			warpdrive.SetJumpTarget(args[4],args[5],args[6],args[7])
			warpdrive.Warp(false)
			warpLockFlag = true		
		elseif args[3] == "shutdown" then
			softLogic.Quit()
			computer.shutdown()
		elseif args[3] == "air" then
			if args[4] == "on" then
				warpdrive.SetAirGenerators(true)
			elseif args[4] == "off" then
				warpdrive.SetAirGenerators(false)
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
        WGUI.Refresh()
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

function softLogic.Save()
	wmUtils.SaveData(applicationDataPath.."/WarpMasterNavPoints.txt", navPoints)
	wmUtils.SaveData(applicationDataPath.."/WarpMasterSettings.txt", programSettings)
	wmUtils.SaveData(applicationDataPath.."/WarpMasterTrustedPlayers.txt", trustedPlayers)
end

function softLogic.Load()
	local loadedData = wmUtils.LoadData(applicationDataPath.."/WarpMasterNavPoints.txt")
	if loadedData ~= nil then
		navPoints = loadedData
	end
	loadedData = wmUtils.LoadData(applicationDataPath.."/WarpMasterSettings.txt")
	if loadedData ~= nil then
		programSettings = loadedData
	end
	loadedData = wmUtils.LoadData(applicationDataPath.."/WarpMasterTrustedPlayers.txt")
	if loadedData ~= nil then
		trustedPlayers = loadedData
	end
  
  if programSettings.planetsListFile == nil then
    programSettings.planetsListFile = "Empty"
  end
  loadedData = wmUtils.LoadData(applicationPath.."/Resources/CelestialBodiesLists/"..programSettings.planetsListFile..".txt")
	if loadedData ~= nil then
		celestialBodies = loadedData
	end
end

function softLogic.Quit()
	softLogic.Save()
	if warpdrive.CheckCore() then
		warpdrive.TurnOffCore()
	end
end

function softLogic.GetNearestNavPointIndex(x,y,z, ignoreY)
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

function shipLogic.GetCoreCharge() 
  local chargePercent = 0
	local energyLevel, maxEnergy = 0,1
	if warpdrive.CheckCore() == true then
		energyLevel, maxEnergy = warpdrive.GetEnergyLevel()
		chargePercent = math.ceil((energyLevel / maxEnergy) * 100)
	end
  return chargePercent, energyLevel, maxEnergy
end

function WGUI.BorderPanel(x, y, width, height, bgColor, borderColor,  transparency)
  local object = GUI.object(x, y, width, height)
  object.colors = {
		background   = bgColor,
    border       = borderColor,
		transparency = transparency
	}
  object.draw = WGUI.DrawBorderPanel
  
  return object
end

function WGUI.DrawBorderPanel(object) -- Чисто отрисовочный метод для кастомного объекта
	buffer.drawRectangle(object.x, object.y, object.width, object.height, object.colors.background, 0x0, " ", object.colors.transparency)
  local stringUp   = "┌"..string.rep("─", object.width - 2).."┐"
	local stringDown = "└"..string.rep("─", object.width - 2).."┘"
  buffer.drawText(object.x, object.y, object.colors.border, stringUp)
  buffer.drawText(object.x, object.y + object.height - 1, object.colors.border, stringDown)
  local yPos = 1
	for i = 1, (object.height - 2) do
		buffer.drawText(object.x, object.y + yPos, object.colors.border, "│")
		buffer.drawText(object.x + object.width - 1, object.y + yPos, object.colors.border, "│")
		yPos = yPos + 1
	end
	return object
end

function WGUI.TextBoxCustomHandler(application, object, e1, e2, e3, e4, e5) -- хендлер, который помимо скролла поддерживает возможность отследить по какой строке был клик
  if e1 == "scroll" then
		if e5 == 1 then
			object:scrollUp()
		else
			object:scrollDown()
		end
		application:draw()
	elseif e1 == "touch" then
    if object.lineTouchHandler ~= nil then
      local clickPos = e4 - object.y
      local itemIndex = clickPos + object.currentLine
      object.lineTouchHandler(itemIndex)
    end
  end
end

function WGUI.Init() -- основной метод, где задаются все основные элементы интерфейса
  WGUI.app = GUI.application(1, 1, WGUI.screenWidth, WGUI.screenHeight)
  local app = WGUI.app 
  -- основное окно
  WGUI.mainWindow = app:addChild(GUI.titledWindow(1, 1, WGUI.screenWidth, WGUI.screenHeight,"WarpMaster 2.0", true))
  app.eventHandler = WGUI.CommonEventHandler
  WGUI.mainWindow.eventHandler = nil-- нам не нужна поддержка перетаскивания окна, оно должно быть всегда в одном положении.
  WGUI.mainWindow.titleLabel.colors.text = colors.white
  local actionButtons = WGUI.mainWindow.actionButtons
  actionButtons.close.onTouch = WGUI.Terminate
  WGUI.mainWindow.backgroundPanel.colors.background = colors.black
  WGUI.mainWindow.titlePanel.colors.background = colors.panel
  -- Панель с уровнем заряда
  local chargeBarText = "Заряд ядра:[                    ]"
  WGUI.chargeBar = WGUI.mainWindow:addChild(GUI.text(WGUI.screenWidth - 33, 1, colors.white, chargeBarText))
  WGUI.chargeBarPanel =  WGUI.mainWindow:addChild(GUI.panel(WGUI.screenWidth - 21, 1, 20, 1, colors.blue))
  WGUI.chargeBarEnergyLevel = WGUI.mainWindow:addChild(GUI.text(WGUI.screenWidth - 11, 1, colors.white, "0%"))
  WGUI.chargeBar.update = WGUI.UpdateChargeBar
  --Правая панель меню
  WGUI.rightPanel = WGUI.app:addChild(WGUI.BorderPanel(WGUI.screenWidth - 29, 2, 30, 14, colors.black, colors.white))
  WGUI.rightPanel.titleText = WGUI.app:addChild(GUI.text(WGUI.screenWidth - 28, 2, colors.white, "МЕНЮ:"))
  --Кнопки основного меню
  WGUI.rightPanel.mainMenuList = WGUI.app:addChild(GUI.list(WGUI.screenWidth - 28,3,28,12,3,0,colors.gray, colors.white, colors.gray, colors.white, colors.menuButton, colors.white))
  local modeTypeIndex = 1
  for k,v in pairs(uiModes) do
    local button = WGUI.rightPanel.mainMenuList:addItem(v)
    button.onTouch =  function()  WGUI.SelectGUIMode(k) end
    if programSettings.currentGUIMode == k then
      WGUI.rightPanel.mainMenuList.selectedItem = modeTypeIndex
    end
    modeTypeIndex = modeTypeIndex + 1
  end
  -- Кнопки прыжка и гипера на правой панели
  
  WGUI.rightPanel.actionBoxPanel = app:addChild(WGUI.BorderPanel(WGUI.screenWidth - 29, 16, 30, 21, colors.black, colors.white))
  local actBoxPanel = WGUI.rightPanel.actionBoxPanel
  actBoxPanel.titleText   = app:addChild(GUI.text(WGUI.screenWidth - 28, 16, colors.white, "ДЕЙСТВИЯ:"))
  actBoxPanel.jumpButton  = app:addChild(GUI.framedButton(WGUI.screenWidth - 28, 17, 28, 3, colors.white, colors.white, colors.greenButton, colors.greenButton, "ПРЫЖОК"))
  actBoxPanel.hyperButton = app:addChild(GUI.framedButton(WGUI.screenWidth - 28, 20, 28, 3, colors.white, colors.white, colors.greenButton, colors.greenButton, "ГИПЕР"))
  actBoxPanel.scanButton  = app:addChild(GUI.framedButton(WGUI.screenWidth - 28, 23, 28, 3, colors.white, colors.white, colors.greenButton, colors.greenButton, "СКАНИРОВАТЬ"))
  actBoxPanel.cloakTitle  = app:addChild(GUI.text(WGUI.screenWidth - 27, 27, colors.white, "Маскировка: "))
  actBoxPanel.cloakBox    = app:addChild(GUI.comboBox(WGUI.screenWidth - 12, 26, 12, 3, 0xEEEEEE, 0x2D2D2D, colors.greenButton, 0x888888))
  actBoxPanel.cloakBox:addItem("Откл.").onTouch = function() WGUI.SetCloakTier(0) end
  actBoxPanel.cloakBox:addItem("Ур. 1").onTouch = function() WGUI.SetCloakTier(1) end
  actBoxPanel.cloakBox:addItem("Ур. 2").onTouch = function() WGUI.SetCloakTier(2) end
  
  actBoxPanel.jumpButton.onTouch  = WGUI.JumpButtonPush
  actBoxPanel.hyperButton.onTouch = WGUI.DrawHyperTransferWindow
  actBoxPanel.scanButton.onTouch  = WGUI.ScanButtonClick
  --Группа информации на правой панели
  WGUI.rightPanel.infoBoxPanel = WGUI.app:addChild(WGUI.BorderPanel(WGUI.screenWidth - 29, 36, 30, 15, colors.black, colors.white))
  local rightPanel = WGUI.rightPanel.infoBoxPanel
  rightPanel.titleText   = app:addChild(GUI.text(WGUI.screenWidth - 28, 36, colors.white, "ИНФО:"))
  rightPanel.statusText  = app:addChild(GUI.adaptiveButton(WGUI.screenWidth - 20,36,1,0,0x57A64E, colors.white,0x57A64E, colors.white, "ГОТОВ К ПРЫЖКУ")) -- TODO: обновление статуса кнопки.
  rightPanel.shipNameText= app:addChild(GUI.text(WGUI.screenWidth - 27, 37, colors.white, "Имя: НЕТ ДАННЫХ"))
  rightPanel.coordsTitle = app:addChild(GUI.text(WGUI.screenWidth - 27, 38, colors.white, "Координаты:"))
  rightPanel.xCoordText  = app:addChild(GUI.text(WGUI.screenWidth - 27, 39, colors.white, "  X: 0"))
  rightPanel.yCoordText  = app:addChild(GUI.text(WGUI.screenWidth - 27, 40, colors.white, "  Y: 0"))
  rightPanel.zCoordText  = app:addChild(GUI.text(WGUI.screenWidth - 27, 41, colors.white, "  Z: 0"))
  rightPanel.dirText     = app:addChild(GUI.text(WGUI.screenWidth - 27, 42, colors.white, "Направление: НЕТ ДАННЫХ"))
  rightPanel.weightText  =  app:addChild(GUI.text(WGUI.screenWidth - 27, 42, colors.white, "Масса корабля: НЕТ ДАННЫХ"))
  rightPanel.aboutText   = app:addChild(GUI.text(WGUI.screenWidth - 20, 50, colors.white, "(c)-TxN-2016-2019"))
  rightPanel.titleText.update = WGUI.UpdateShipInfoPanel
  
  WGUI.InitOptionsWindow(app)    -- окно настроек
  WGUI.InitAutopilotWindow(app)  -- окно активного автопилота
  
  -- окно НАВ режима
  WGUI.navWindow = app:addChild(GUI.container(1, 2, WGUI.screenWidth - 30, WGUI.screenHeight - 1))
  -- Панель со списком точек
  WGUI.navWindow.pointsBorder = WGUI.navWindow:addChild(WGUI.BorderPanel(1, 1, 30, 49, colors.black, colors.white))
  WGUI.navWindow.pointsBorder.titleText = WGUI.navWindow:addChild(GUI.text(2, 1, colors.white, "Навигационные точки:"))
  -- Список точек
  WGUI.navWindow.pointsBorder.listBox = WGUI.navWindow:addChild(GUI.textBox(2, 2, 28, 47, nil, colors.white, {}, 1, 0, 0, false, false))
  WGUI.navWindow.pointsBorder.listBox.scrollBarEnabled = true
  WGUI.navWindow.pointsBorder.listBox.eventHandler = WGUI.TextBoxCustomHandler
  WGUI.navWindow.pointsBorder.listBox.lineTouchHandler = WGUI.SelectPointFromList
  -- Панель карты
  WGUI.navWindow.mapBorder = WGUI.navWindow:addChild(WGUI.BorderPanel(31, 1, 100, 49, colors.black, colors.white))
  WGUI.navWindow.mapBorder.titleText = WGUI.navWindow:addChild(GUI.text(32, 1, colors.white, "Карта:"))
  WGUI.navWindow.mapBorder.addPointButton = WGUI.navWindow:addChild(GUI.adaptiveButton(8,49,1,0,colors.greenButton,colors.white,colors.greenDark, colors.white, "НОВАЯ ТОЧКА"))
  WGUI.navWindow.mapBorder.addPointButton.onTouch = WGUI.AddNewPointDialog
  -- Область отрисовки карты
  WGUI.navWindow.mapView = WGUI.navWindow:addChild(GUI.container(32, 2, 98, 46))
  WGUI.navWindow.isDirty = true
  local mapView =  WGUI.navWindow.mapView
  mapView.jumpBorder = mapView:addChild(GUI.panel(32, 15, 1, 1, colors.gray))  
  mapView.shipSymbol = mapView:addChild(GUI.text(49, 23, colors.white, "^"))
  mapView.warpDestPoint = mapView:addChild(GUI.text(49, 23, colors.greenDark, "X"))
  mapView.autoDestPoint = mapView:addChild(GUI.text(49, 23, colors.greenDark, "A"))
  mapView.autoDestPoint.hidden = true
  mapView.navPoints  = {} -- временный список отрисованных навигационных точек.
  
  WGUI.navWindow.xScaleText = WGUI.navWindow:addChild(GUI.text(34, 48, colors.white, "Масштаб по X: 8 м/пиксель"))
  WGUI.navWindow.yScaleText = WGUI.navWindow:addChild(GUI.text(64, 48, colors.white, "Масштаб по Y: 16 м/пиксель"))
  -- Контекстное меню карты
  WGUI.navWindow.mapView.eventHandler = WGUI.NavViewEventHandler
  -- Кнопки управления масштабом карты
  WGUI.navWindow.navMaxScaleButton   = WGUI.navWindow:addChild(GUI.adaptiveButton(103,49,1,0,0xCC4C4C, colors.black,0xCC4C4C, colors.black, "МАКС"))
  WGUI.navWindow.navResetScaleButton = WGUI.navWindow:addChild(GUI.adaptiveButton(109,49,1,0,0xFFF400, colors.black,0xFFF400, colors.black, "СБРОС"))
  WGUI.navWindow.navScaleLessButton  = WGUI.navWindow:addChild(GUI.adaptiveButton(116,49,1,0,0xCC4C4C, colors.white,0xCC4C4C, colors.white, "МШТБ-"))
  WGUI.navWindow.navScaleMoreButton  = WGUI.navWindow:addChild(GUI.adaptiveButton(123,49,1,0,0x57A64E, colors.white,0x57A64E, colors.white, "МШТБ+"))
  
  WGUI.navWindow.navMaxScaleButton.onTouch   = function() programSettings.navScaleX = 500  programSettings.navScaleY = 1000 WGUI.Refresh() end
  WGUI.navWindow.navResetScaleButton.onTouch = function() programSettings.navScaleX = 8    programSettings.navScaleY = 16   WGUI.Refresh() end
  WGUI.navWindow.navScaleMoreButton.onTouch  = function() programSettings.navScaleX = wmUtils.Clamp(programSettings.navScaleX - 2, 1,500) programSettings.navScaleY = wmUtils.Clamp(programSettings.navScaleY - 4,2,1000) WGUI.Refresh() end
  WGUI.navWindow.navScaleLessButton.onTouch  = function() programSettings.navScaleX = wmUtils.Clamp(programSettings.navScaleX + 2, 1,500) programSettings.navScaleY = wmUtils.Clamp(programSettings.navScaleY + 4,2,1000) WGUI.Refresh() end
  
  -- Кнопки выбора режима карты (тип местности)
  WGUI.navWindow.worldTypeSelector = WGUI.navWindow:addChild(GUI.list(39,1,45,1,9,0,colors.redButton, colors.white, colors.redButton, colors.white, colors.greenButton, colors.white))
  WGUI.navWindow.worldTypeSelector:setDirection(GUI.DIRECTION_HORIZONTAL)
  local mapTypeIndex = 1
  for k,v in pairs(worldTypes) do
    local button = WGUI.navWindow.worldTypeSelector:addItem(unicode.upper(v))
    button.onTouch =  function()  WGUI.SelectNavMapWorldType(k) end
    if programSettings.currentWorldType == k then
      WGUI.navWindow.worldTypeSelector.selectedItem = mapTypeIndex
    end
    mapTypeIndex = mapTypeIndex + 1
  end
  
end

function WGUI.InitOptionsWindow(app)
  WGUI.optionsWindow = app:addChild(GUI.container(1, 2, WGUI.screenWidth - 30, WGUI.screenHeight - 1))
  local opts = WGUI.optionsWindow
  opts.hidden = true
  
  opts.shipOptsBorder = opts:addChild(WGUI.BorderPanel(1, 1, 30, 49, colors.black, colors.white))
  opts.shipOptsTitle  = opts:addChild(GUI.text(2, 1, colors.white, "Настройки корабля:"))
  opts.progOptsBorder = opts:addChild(WGUI.BorderPanel(31, 1, 30, 49, colors.black, colors.white))
  opts.progOptsTitle  = opts:addChild(GUI.text(32, 1, colors.white, "Настройки программы:"))
  
  opts.changeShipNameButton   = opts:addChild(GUI.framedButton(2, 2, 28, 3, colors.white, colors.white, colors.greenButton, colors.greenButton, "Сменить имя: ".. shipInfo.name))
  opts.changeShipSizeButton   = opts:addChild(GUI.framedButton(2, 5, 28, 3, colors.white, colors.white, colors.greenButton, colors.greenButton, "Задать размеры корабля"))
  
  opts.clearAllPointsButton   = opts:addChild(GUI.framedButton(32, 2, 28, 3, colors.white, colors.white, colors.greenButton, colors.greenButton, "Очистить список точек"))
  opts.clearScanResultsButton = opts:addChild(GUI.framedButton(32, 5, 28, 3, colors.white, colors.white, colors.greenButton, colors.greenButton, "Очистить рез. сканирования"))
  
  opts.changeShipNameButton.onTouch = WGUI.DrawShipNameSetDialog
  opts.changeShipSizeButton.onTouch = WGUI.DrawShipSizeWindow
end

function WGUI.InitAutopilotWindow(app)
  WGUI.autopilotBusyWindow = app:addChild(GUI.container(1, 2, WGUI.screenWidth - 30, WGUI.screenHeight - 1))
  local busyWindow =  WGUI.autopilotBusyWindow
  busyWindow.hidden = true
  
  busyWindow.autopilotTitle   = busyWindow:addChild(GUI.text(70, 23, colors.white, "Автопилот активен"))
  busyWindow.disableAutopilot = busyWindow:addChild(GUI.framedButton(70, 25, 20, 3, colors.white, colors.white, colors.greenButton, colors.greenButton, "Очистить автопилот"))
  busyWindow.disableAutopilot.onTouch = function() autopilot.DeactivateAutopilot() end
end

function WGUI.SelectNavMapWorldType(worldType)
  programSettings.currentWorldType = worldType
  WGUI.Refresh()
end

function WGUI.SelectGUIMode(mode)
  programSettings.currentGUIMode = mode
  WGUI.Refresh()
end

function WGUI.SelectPointFromList(index)
  local point = WGUI.navWindow.mapView.navPoints[index]
  if point == nil then
    return
  end
  WGUI.DrawViewPointInfoDialog(point.info.navIndex)
  WGUI.Refresh()
end

function WGUI.AddNewPointDialog(x,y,z)
  local sx,sy,sz = warpdrive.GetShipPosition()
  WGUI.DrawNewNavPointWindow(x or sx,y or sy,z or sz)
end

function WGUI.ScanButtonClick()
  if not c.isAvailable("warpdriveRadar") then
   GUI.alert("Не найден подключенный радар. Подключите его и попробуйте снова.")
   return
 end
 WGUI.DrawScanDialog() 
end

function WGUI.DrawScanDialog()
  local okText     = "ОК"
	local cancelText = "Отмена"
	local bound  = 9999
	local radius = 100
	
	local data = ecs.universalWindow("auto", "auto", 40, colors.window, true,
		{"CenterText", colors.text, "Запуск варп-радара"},
		{"CenterText", colors.text, "Результаты будут отображены на навигационной карте"},
		{"EmptyLine"},
		{"CenterText", colors.text, "Радиус поиска в метрах:"},
		{"Input", 0x262626, colors.text, tostring(radius)},
		{"Separator", 0xaaaaaa},
		{"Button", {0x57A64E, 0xffffff, okText},{0xCC4C4C, 0xffffff, cancelText}})
    if data[2] ~= okText then
      return
    end
    radius = tonumber(data[1])
    radius = radius or 100
    local radar       = c.warpdriveRadar
    local energyReq   = radar.getEnergyRequired(radius)
    local availEnergy = radar.energy()
    if energyReq > availEnergy then
      GUI.alert("Недостаточно энергии в радаре. Требуется: ".. energyReq .. " EU, имеется ".. availEnergy .. " EU.")
      return
    end
    radar.radius(radius)
    radar.start()
    os.sleep(0.2)
    local scanTime = radar.getScanDuration(radius)
    for i=1,(scanTime + 1) do
			ecs.square(60,20,45,5,colors.window)
			ecs.colorText( 62, 21, 0x000000, "Ожидайте...")
			ecs.colorText( 62, 22, 0x000000, "Сканирование выполняется...")
			ecs.colorText( 62, 23, 0x000000, "Терминал заблокирован на "..tostring((scanTime + 1) - i).." секунд")
			os.sleep(1)
		end
    
    ecs.square(60,20,45,5,colors.window)
    ecs.colorText(62, 22, 0x000000, "Загрузка результатов...")
    
    local delay = 0
    local count
    repeat -- Ждем пока не появятся результаты
      count = radar.getResultsCount()
      os.sleep(0.1)
      delay = delay + 1
    until (count ~= nil and count ~= -1) or delay > 15
    
    local results = {}
    
    if count ~= nil and count > 0 then
      for i = 0, count - 1 do
        success, resType, name, x, y, z = radar.getResult(i)
        if success then
          -- local res = {} 
          table.insert(results,resType.." "..name.." @("..x.." "..y.." "..z..")") -- TODO: конвертация в SHP навигационную точку с правильными координатами и измерением.
        end
      end
    end
    WGUI.DrawScanResults(results)
end

function WGUI.DrawScanResults(results)
  if results == nil or results[1] == nil then
    WGUI.Refresh()
    return
  end
  local resultsText = ""
  for i = 1, #results do
    resultsText = resultsText .. tostring(i).. ") " .. results[i] .. ";"
  end
  local okText = "Сохранить"
  local cancelText = "Закрыть"
  local data   = ecs.universalWindow("auto", "auto", 60, colors.window, true,
		{"CenterText", colors.text, "Результаты сканирования:"},
		{"EmptyLine"},
    {"TextField", 5, 0xffffff, 0x262626, 0xcccccc, 0x3366CC, resultsText},
		{"Separator", 0xaaaaaa},
		{"Button", {0x57A64E, 0xffffff, okText},{0xCC4C4C, 0xffffff, cancelText}})
    if data[1] == okText then
      -- TODO: Добавление результатов на карту с определением координат по измерениям.
    end
  WGUI.Refresh()
end

function WGUI.DrawNewNavPointWindow(x,y,z)
	local okText = "ОК"
	local cancelText = "Отмена"
	local curPlaceText = "Тек. положение"
  x = x or 0
  y = y or 0
  z = z or 0
	
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
	{"Selector", 0x262626, 0x880000, programSettings.currentWorldType, "space", "hyper", "planet", "earth", "other"},
  {"CenterText", 0x262626, "Тип точки:"},
	{"Selector", 0x262626, 0x880000, "NAV", "NAV", "POI", "SHP", "RES"},
  {"CenterText", 0x262626, "Описание:"},
	{"Input", 0x262626, colors.text, ""},
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
  point[6] = data[6]
  point[7] = data[7]
	if data[8] == okText then
		table.insert(navPoints, point)
	elseif data[8] == curPlaceText then
		point[3],point[4],point[5] = warpdrive.GetShipPosition()
		table.insert(navPoints,point)
	end
  WGUI.Refresh()
end

function WGUI.DrawPrecizeJumpWindow(x,y,z)
  x = x or 0
  y = y or 0
  z = z or 0	
  local okText     = "ОК"
	local cancelText = "Отмена"
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
		dx = wmUtils.ClampMagnitude(dx, mindx, warpdrive.maxJumpLength() + mindx)
		end
		if dy ~= 0 then
		dy = wmUtils.ClampMagnitude(dy, mindy, warpdrive.maxJumpLength() + mindy)
		end
		if dz ~= 0 then
		dz = wmUtils.ClampMagnitude(dz, mindz, warpdrive.maxJumpLength() + mindz)
		end
		shipInfo.core_movement[1] = dx
		shipInfo.core_movement[2] = dy
		shipInfo.core_movement[3] = dz
		warpdrive.SetCoreMovement(dx,dy,dz)
		warpdrive.SetRotation(tonumber(data[4]))
	end	
  WGUI.Refresh()
end

function WGUI.DrawRemoveNavPointDialog(pointIndex)
	local point = navPoints[pointIndex]
	if point == nil then
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
  WGUI.Refresh()
end

function WGUI.DrawViewPointInfoDialog(pointIndex)
	local point = navPoints[pointIndex]
	if point == nil then
		return
	end
  local typeInfo      = WGUI.GetParamsForPointType(point[6])
	local dist          = warpdrive.CalcDistanceToPoint(point[3],point[4],point[5])
	local okText        = "OK"
	local setText       = "Прыжок к точке"
	local autopilotText = "Автопилот"
	local removeText    = "Удалить"
	local editText      = "Редактировать"
	local data = ecs.universalWindow("auto", "auto", 40, colors.window, true,
	{"CenterText", 0x262626, "Информация о путевой точке: ".. point[1]},
	{"CenterText", 0x262626, "X: ".. point[3]},
	{"CenterText", 0x262626, "Y: ".. point[4]},
	{"CenterText", 0x262626, "Z: ".. point[5]},
	{"CenterText", 0x262626, "Пространство: ".. worldTypes[point[2]]},
  {"CenterText", typeInfo.color, "Тип: ".. typeInfo.long},
	{"CenterText", 0x262626, "Расстояние до точки: "..dist.."м."},
	{"Button", {0x57A64E, 0xffffff, editText},{0x57A64E, 0xffffff, setText},{0x57A64E, 0xffffff, autopilotText},{0xCC4C4C, 0xffffff, removeText}},
	{"Button", {0x57A64E, 0xffffff, okText}}
	)
	
	if data[1] == setText then
		local x,y,z = WGUI.WorldToShipRelativeCoordinates(point[3],point[4],point[5])
		local mindx, mindy,mindz = shipInfo.length+2, shipInfo.height+2, shipInfo.width+2
		local bound = warpdrive.maxJumpLength()
		x = wmUtils.ClampMagnitude(x,mindx,bound + mindx)
		y = wmUtils.ClampMagnitude(y,mindy,bound + mindy)
		z = wmUtils.ClampMagnitude(z,mindz,bound + mindz)
		WGUI.DrawPrecizeJumpWindow(x,y,z)
	elseif data[1] == autopilotText then
		autopilot.SetTarget(point)
		autopilot.Start()
	elseif data[1] == removeText then
		WGUI.DrawRemoveNavPointDialog(pointIndex)
	elseif data[1] == editText then
		WGUI.DrawEditPointDialog(point)
	end
  WGUI.Refresh()
end

function WGUI.DrawShipSizeWindow()
	local okText     = "ОК"
	local cancelText = "Отмена"	
	local GFront, GRight, GUp, GBack, GLeft, GDown = warpdrive.GetDimensions()
	local data = ecs.universalWindow("auto", "auto", 40, colors.window, true,
		{"CenterText", colors.text, "Настройка размеров корабля"},
    {"CenterText", colors.text, "Хинт: Шифт+ПКМ по ядру визуализирует"},
    {"CenterText", colors.text, "текущие габариты корабля."},
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
  WGUI.Refresh()
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

function WGUI.JumpButtonPush()
	local function JumpQuestion()
		local okText     = "Да"	
		local cancelText = "Нет"		
		local jumpDistance = warpdrive.CalcJumpDistance()
		local energyCost   = warpdrive.GetJumpEnergyCost()
		
		local data = ecs.universalWindow("auto", "auto", 60, colors.window, true,
		{"CenterText", 0x262626, "Вы действительно хотите совершить прыжок?"},
		{"CenterText", 0x262626, "Отменить действие будет невозможно!"},
		{"CenterText", 0x262626, "Прыжок потребует "..tostring(energyCost).." EU"},
		{"Button", {0x57A64E, 0xffffff, okText},{0xCC4C4C, 0xffffff, cancelText}})
		if data[1] == okText then
			warpdrive.Warp(false)
			warpLockFlag = true
			for i=1,25 do
				ecs.square(60,20,45,5,colors.window)
				ecs.colorText( 62, 21, 0x000000, "Ожидайте...")
				ecs.colorText( 62, 22, 0x000000, "Прыжок выполняется...")
				ecs.colorText( 62, 23, 0x000000, "Терминал заблокирован на "..tostring(25-i).." секунд")
				computer.beep(25+15*25,0.5)
				os.sleep(0.5)
			end

			local x,y,z = warpdrive.GetShipPosition()	
      WGUI.Refresh()
		end
	end

	if warpdrive.MakePreFlightCheck() == false then
		local okText     = "Продолжить"	
		local cancelText = "Отмена"	
		local data = ecs.universalWindow("auto", "auto", 60, colors.window, true,
		{"CenterText", 0x262626, "Внимание!"},
		{"CenterText", 0x262626, "Самотестирование завершилось с ошибкой!"},
		{"CenterText", 0x262626, "Прыжок может быть небезопасен!"},
		{"Button", {0x57A64E, 0xffffff, okText},{0xCC4C4C, 0xffffff, cancelText}}
		)
		
		if data[1] == okText then
			JumpQuestion()
		end		
	else
		JumpQuestion()
	end
end

function WGUI.SwitchToHyper()
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
  WGUI.Refresh()
end

function WGUI.DrawHyperTransferWindow()
	local okText     = "Да"	
	local cancelText = "Нет"
		
	if shipInfo.weight < 1200 then
    GUI.alert("Недостаточная масса корабля! Текущая масса корабля: "..tostring(shipInfo.weight)..", а минимальная масса: 1200")
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
  buffer.clear(0x2D2D2D)
  GUI.alert("Не найден контроллер ядра корабля. Подключите его и перезапустите программу.")
end

function WGUI.DrawNoInternetWindow()
	local okText = "OK"
	local data   = ecs.universalWindow("auto", "auto", 60, colors.window, true,
	{"CenterText", 0x262626, "Не найдена интернет-плата."},
	{"CenterText", 0x262626, "Функции, связанные с интернетом, будут отключены."},
	{"CenterText", 0x262626, "Если вы уверены, что интернет плата установлена,"},
	{"CenterText", 0x262626, "попробуйте перезагрузить компьютер."},
	{"Button", {0x57A64E, 0xffffff, okText}})
end

function WGUI.FirstLaunch()
	local okText     = "ОК"
	local cancelText = "Отмена"
	local data = ecs.universalWindow("auto", "auto", 60, colors.window, true,
	{"EmptyLine"},
	{"CenterText", 0x262626, "Добро пожаловать!"},
	{"CenterText", 0x262626, "Вы установили программу Warp Master 2.0"},
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
	{"CenterText", 0x262626, "И направлена в сторону контроллера. "},
	{"CenterText", 0x262626, "Стрелка на ядре смотрит вперед."},
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
  WGUI.Refresh()
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
		softLogic.AddTrusted(data[1])
	elseif data[2] == remPlyText then
		softLogic.removeTrusted(data[1])
	end
  WGUI.Refresh()
end

function WGUI.ShowAutopilotNotice()
  WGUI.SelectGUIMode("AUT")
end

function WGUI.CloseAutopilotNotice()
  WGUI.SelectGUIMode("NAV")
end

function WGUI.UpdateMapView() 
  local scalex = programSettings.navScaleX -- блоков на знакоместо по x
	local scaley = programSettings.navScaleY -- аналогично по y
  local x,y,z = warpdrive.GetShipPosition()
	local ox, oy, oz = warpdrive.GetShipOrientation()
	local warpD = warpdrive.CalcDestinationPoint()
  
  local offsetX, offsetY = 0,0 -- TODO:Заготовка под возможность скроллить карту
  
  local maxZ = z + 49 * scalex
	local maxX = x + 23 * scaley
	local minZ = z - 49 * scalex
	local minX = x - 23*  scaley
  
  local function CheckNavPointRange(navPoint)
		if programSettings.currentWorldType == navPoint[2] then
			return true
		else 
			return false
		end
	end
 
  local mindx, mindy,mindz = shipInfo.length + 1, shipInfo.height + 1, shipInfo.width + 1
  local maxBound = warpdrive.maxJumpLength()
	local jRectX = wmUtils.Clamp( 49 - ((maxBound + mindz)/scalex),1,98)
	local jRectY = wmUtils.Clamp( 23 - ((maxBound + mindx)/scaley),1,46)
  
  local border = WGUI.navWindow.mapView.jumpBorder
  border.localX = wmUtils.round( jRectX )
  border.localY = wmUtils.round( jRectY )
  border.width  = wmUtils.round(wmUtils.Clamp(( (maxBound + mindz)*2)/scalex,0,98))
  border.height = wmUtils.round(wmUtils.Clamp(( (maxBound + mindx)*2)/scaley,0,45))
  
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
		dspX = wmUtils.Clamp(49 + math.floor(dspX/scalex), 1,98)
		dspY = wmUtils.Clamp(23 + math.floor(dspY/scaley),1, 46)
		return dspX,dspY
	end
    
  for k,v in ipairs(WGUI.navWindow.mapView.navPoints) do
    if v.mapElement  ~= nil then
      v.mapElement:remove()
    end
    if v.listElement ~= nil then
      v.listElement:remove()
    end
    v.info = nil
  end
  WGUI.navWindow.mapView.navPoints = {}
  
  local pointIndex = 0
  local displayedNavPoints = WGUI.navWindow.mapView.navPoints
  
  for i=1,#navPoints do
		if CheckNavPointRange(navPoints[i]) == true then
			pointIndex = pointIndex + 1
			local pointInfo = {}
			pointInfo.navIndex = i
			pointInfo.mapName = tostring(pointIndex)
			pointInfo.listName = pointIndex.." "..navPoints[i][1]
			local dx,dy = GetWorldPointNavCoords(navPoints[i][3],navPoints[i][4],navPoints[i][5])
			pointInfo.ex = string.len(pointInfo.mapName) - 1
      pointInfo.appearance = WGUI.GetParamsForPointType(navPoints[i][6])
      local point = {}
			displayedNavPoints[pointIndex] = point
      point.info = pointInfo
      point.mapElement = WGUI.navWindow.mapView:addChild(GUI.text(dx, dy, point.info.appearance.color, pointIndex))
      WGUI.navWindow.mapView.navPoints[pointIndex] = point
		end
	end
  
  local wtx,wty = GetWorldPointNavCoords(warpD.x,warpD.y,warpD.z)
  WGUI.navWindow.mapView.warpDestPoint.localX = wtx
  WGUI.navWindow.mapView.warpDestPoint.localY = wty
  
	if autopilot.point ~= nil then 
		local atx,aty = GetWorldPointNavCoords(autopilot.point[3],autopilot.point[4],autopilot.point[5])
    WGUI.navWindow.mapView.autoDestPoint.localX = atx
    WGUI.navWindow.mapView.autoDestPoint.localY = aty
    WGUI.navWindow.mapView.autoDestPoint.hidden = false
	else
    WGUI.navWindow.mapView.autoDestPoint.hidden = true
  end
  
  WGUI.navWindow.xScaleText.text = "Масштаб по X: ".. scalex .." м/пиксель"
  WGUI.navWindow.yScaleText.text = "Масштаб по Y: ".. scaley .. " м/пиксель"

  WGUI.navWindow.mapView.shipSymbol:moveToFront()
  
  WGUI.UpdateNavPointList() 
end

function WGUI.UpdateNavPointList() 
  WGUI.navWindow.pointsBorder.listBox.lines = {}
  for k,v in ipairs(WGUI.navWindow.mapView.navPoints) do
    table.insert(WGUI.navWindow.pointsBorder.listBox.lines, {text = v.info.listName, color = v.info.appearance.color})
  end
end

function WGUI.NavViewEventHandler(container, object, e1, e2, e3, e4)
  if e1 ~= "touch" then
    return
  end
  local contextMenu   = GUI.addContextMenu(container, e3, e4)
  local newPoint      = contextMenu:addItem("Добавить точку")
  newPoint.onTouch    = function() local x,y,z = WGUI.ScreenToWorldCoordinates(e3,e4) WGUI.AddNewPointDialog(x,y,z) end
  local removePoint   = contextMenu:addItem("Удалить точку")
  removePoint.onTouch = function() 
    local x,y,z      = WGUI.ScreenToWorldCoordinates(e3,e4)
		local pointIndex = softLogic.GetNearestNavPointIndex(x,y,z, true)
		local foundPoint = navPoints[pointIndex]
		if foundPoint ~= nil then
			WGUI.DrawRemoveNavPointDialog(pointIndex)
		end 
  end
  local pointInfo     = contextMenu:addItem("Инфо о точке")
  pointInfo.onTouch = function()
    local x,y,z = WGUI.ScreenToWorldCoordinates(e3,e4)
		local pointIndex = softLogic.GetNearestNavPointIndex(x,y,z,true)
		local foundPoint = navPoints[pointIndex]
		if foundPoint ~= nil then
			WGUI.DrawViewPointInfoDialog(pointIndex)
		end
  end
  local setAsTarget   = contextMenu:addItem("Задать как цель")
  setAsTarget.onTouch = function() local x,y,z = WGUI.ScreenToShipRelativeCoordinates(e3,e4) WGUI.DrawPrecizeJumpWindow(x,y,z)  end
  container:draw()
end

function WGUI.UpdateChargeBar() 
  local chargePercent, energyLevel, maxEnergy = shipLogic.GetCoreCharge()
  local maxBarWidth = 20
  local barWidth = math.ceil( (chargePercent * maxBarWidth) / 100)
  WGUI.chargeBarEnergyLevel.text = chargePercent.."% ("..energyLevel..")"
  WGUI.chargeBarEnergyLevel.localX = WGUI.screenWidth - 17
  WGUI.chargeBarPanel.width = barWidth
end

function WGUI.UpdateShipInfoPanel()
  local x,y,z    = warpdrive.GetShipPosition()
  local ox,oy,oz = warpdrive.GetShipOrientation()
  local orientationConverted = WGUI.ConvertRawOrientation(ox,oz)
  local panel = WGUI.rightPanel.infoBoxPanel
  panel.shipNameText.text = "Имя: ".. shipInfo.name
  panel.xCoordText.text   = "  X: "  .. x
  panel.yCoordText.text   = "  Y: "  .. y
  panel.zCoordText.text   = "  Z: "  .. z
  panel.dirText.text      = "Направление: " .. orientationConverted
  panel.weightText.text   = "Масса корабля: " .. shipInfo.weight .. " блоков"
end

function WGUI.UpdateOptionsWindow()
  WGUI.optionsWindow.changeShipNameButton.text = "Сменить имя: ".. shipInfo.name
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
	local centerx,centery = 80,25
	local dx,dy = sx - centerx, sy - centery
	dy = -dy
	local ox, oy, oz = warpdrive.GetShipOrientation()
	local relX = ox*dy*programSettings.navScaleY - oz*dx*programSettings.navScaleX
    local relY = 0
	local relZ = oz*dy*programSettings.navScaleY + ox*dx*programSettings.navScaleX
	return relX,relY,relZ
end

function WGUI.ScreenToShipRelativeCoordinates(sx,sy)
	local centerx,centery = 80,25
	local dx,dy = sx - centerx, sy - centery
	dx =  dx * programSettings.navScaleX
	dy = -dy * programSettings.navScaleY
	return dy,0,dx
end

function WGUI.ConvertRawOrientation(ox,oz)
  local orientationRaw = wmUtils.DirVectorToCompass(ox,oz)
  if orientationRaw == "west" then
    return "Запад"
  end
  if orientationRaw == "east" then
    return "Восток"
  end
  if orientationRaw == "south" then
    return "Юг"
  end
  if orientationRaw == "north" then
    return "Север"
  end
  return "НЕТ ДАННЫХ"
end

function WGUI.GetParamsForPointType(pointType)
  local result = navPointAppearance[pointType]
  if result == nil then
    result = navPointAppearance.DEF
  end
  return result
end

function WGUI.SetCloakTier(tier)
  if not c.isAvailable("warpdriveCloakingCore") then
    GUI.alert("Маскировщик не найден. Подключите маскировщик и попробуйте повторить.")
    return
  end
  local cloak = c.warpdriveCloakingCore
  tier = tier or 0
  if tier == 0 then
    cloak.enable(false)
    return
  end  
  local valid, msg = cloak.isAssemblyValid()
  if not valid then 
    GUI.alert("Ошибка! Маскировщик собран неверно: " ..msg)
    return
  end
  cloak.enable(false)
  os.sleep(0.1)
  cloak.tier(tier)
  cloak.enable(true)
end

function WGUI.Refresh()
  --Прячем все активные окошки
  WGUI.navWindow.hidden           = true
  WGUI.optionsWindow.hidden       = true
  WGUI.autopilotBusyWindow.hidden = true
  
  local curMode = programSettings.currentGUIMode
  if curMode == "NAV" then
    WGUI.navWindow.hidden = false
    WGUI.UpdateMapView() 
  elseif curMode == "OPT" then
    WGUI.optionsWindow.hidden = false
    WGUI.UpdateShipInfoPanel()
  elseif curMode == "UTL" then
    
  elseif curMode == "NFO" then
    
  elseif curMode == "AUT" then
    
  end
  WGUI.app:draw(true)
end

function WGUI.Terminate()
  softLogic.Quit()
  WGUI.app:stop()
end

local function WarpSoftInit()
	warpdrive.SetCoreMovement(0,0,0) 
	LoadInfoFromCore()
  autopilot.OnAutopilotBusy   = WGUI.ShowAutopilotNotice
  autopilot.OnAutopilotFinish = WGUI.CloseAutopilotNotice
  if programSettings.currentGUIMode == "AUT" then
    programSettings.currentGUIMode = "NAV"
  end
	
	if wmUtils.HasInternet() == true then
		local check, curVersion, remoteVersion = tools.CheckForUpdates()
		if check == true then
			WGUI.DrawNewVersionWindow(curVersion, remoteVersion)
		end
	else 
		WGUI.DrawNoInternetWindow()
	end
end

function WGUI.CommonEventHandler(container, object, e1, e2, e3, e4, ...) -- для обработки не UI-событий
  if e1 == "shipCoreCooldownDone" then
    computer.beep(800,0.5)
    warpLockFlag = false
  elseif e1 == "chat_message" then
    local ply_name = e3
		local message = e4
    if softLogic.IsTrustedPlayer(ply_name) == true then
			softLogic.ParseRCCommand(message,ply_name)
		end
  end
end

--Точка входа
filesystem.setAutorunEnabled(false)
softLogic.Load()
c.gpu.setResolution(WGUI.screenWidth, WGUI.screenHeight)

if not warpdrive.CheckCore() then
	WGUI.DrawCoreNotFoundError()
else
  WarpSoftInit()
  WGUI.Init()
  WGUI.UpdateMapView() 
  WGUI.Refresh()	
  if programSettings.firstLaunch == true or programSettings.firstLaunch == nil then
		WGUI.FirstLaunch()
	end
  WGUI.app:start()
end

