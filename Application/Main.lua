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
	shipInfo.core_movement = warpdrive.GetCoreMovement()
	shipInfo.core_rotationSteps = warpdrive.GetRotation(false) 
end

--структуры, хранящие методы и не только
local WGUI      = {}
local tools     = {}
local softLogic = {}
local shipLogic = {}

WGUI.refreshMethods = {}
WGUI.screenWidth  = 160
WGUI.screenHeight = 50

--	{"NavPoint1","earth", 140,80,-200},
local navPoints = {
  {"NavPoint1","earth", 140,80,-200}
  }

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
	table.insert(trustedPlayers, name)
end
function softLogic.RemoveTrusted(name)
	for i=1,#trustedPlayers do
		if trustedPlayers[i] == name then
			table.remove(trustedPlayers,i)
			return
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


function WGUI.Init() -- основной метод, где задаются все основные элементы интерфейса
  WGUI.app = GUI.application(1, 1, WGUI.screenWidth, WGUI.screenHeight)
  -- основное окно
  WGUI.mainWindow = WGUI.app:addChild(GUI.titledWindow(1, 1, WGUI.screenWidth, WGUI.screenHeight,"WarpMaster", true))
  WGUI.mainWindow.eventHandler = nil -- нам не нужна поддержка перетаскивания окна, оно должно быть всегда в одном положении.
  WGUI.mainWindow.titleLabel.textColor = colors.white
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
  WGUI.rightPanel.actionBoxPanel = WGUI.app:addChild(WGUI.BorderPanel(WGUI.screenWidth - 29, 16, 30, 21, colors.black, colors.white))
  WGUI.rightPanel.actionBoxPanel.titleText = WGUI.app:addChild(GUI.text(WGUI.screenWidth - 28, 16, colors.white, "ДЕЙСТВИЯ:"))
  WGUI.rightPanel.actionBoxPanel.jumpButton  = WGUI.app:addChild(GUI.framedButton(WGUI.screenWidth - 28, 17, 28, 3, colors.white, colors.white, colors.greenButton, colors.greenButton, "ПРЫЖОК"))
  WGUI.rightPanel.actionBoxPanel.hyperButton = WGUI.app:addChild(GUI.framedButton(WGUI.screenWidth - 28, 20, 28, 3, colors.white, colors.white, colors.greenButton, colors.greenButton, "ГИПЕР"))
  WGUI.rightPanel.actionBoxPanel.cloatTitle  = WGUI.app:addChild(GUI.text(WGUI.screenWidth - 27, 24, colors.white, "Маскировка: "))
  WGUI.rightPanel.actionBoxPanel.cloakBox    = WGUI.app:addChild(GUI.comboBox(WGUI.screenWidth - 12, 23, 12, 3, 0xEEEEEE, 0x2D2D2D, colors.greenButton, 0x888888))
  WGUI.rightPanel.actionBoxPanel.cloakBox:addItem("Откл.")
  WGUI.rightPanel.actionBoxPanel.cloakBox:addItem("Ур. 1")
  WGUI.rightPanel.actionBoxPanel.cloakBox:addItem("Ур. 2")
  --Группа информации на правой панели
  WGUI.rightPanel.infoBoxPanel = WGUI.app:addChild(WGUI.BorderPanel(WGUI.screenWidth - 29, 36, 30, 15, colors.black, colors.white))
  WGUI.rightPanel.infoBoxPanel.titleText   = WGUI.app:addChild(GUI.text(WGUI.screenWidth - 28, 36, colors.white, "ИНФО:"))
  WGUI.rightPanel.infoBoxPanel.coordsTitle = WGUI.app:addChild(GUI.text(WGUI.screenWidth - 27, 37, colors.white, "Координаты:"))
  WGUI.rightPanel.infoBoxPanel.xCoordText  = WGUI.app:addChild(GUI.text(WGUI.screenWidth - 27, 38, colors.white, "  X: 0"))
  WGUI.rightPanel.infoBoxPanel.yCoordText  = WGUI.app:addChild(GUI.text(WGUI.screenWidth - 27, 39, colors.white, "  Y: 0"))
  WGUI.rightPanel.infoBoxPanel.zCoordText  = WGUI.app:addChild(GUI.text(WGUI.screenWidth - 27, 40, colors.white, "  Z: 0"))
  WGUI.rightPanel.infoBoxPanel.dirText     = WGUI.app:addChild(GUI.text(WGUI.screenWidth - 27, 41, colors.white, "Направление: НЕТ ДАННЫХ"))
  WGUI.rightPanel.infoBoxPanel.update      = WGUI.UpdateShipInfoPanel -- !! Не работает!
  
  -- окно НАВ режима
  WGUI.navWindow = WGUI.app:addChild(GUI.container(1, 2, WGUI.screenWidth - 30, WGUI.screenHeight - 1))
  -- Панель со списком точек
  WGUI.navWindow.pointsBorder = WGUI.navWindow:addChild(WGUI.BorderPanel(1, 1, 30, 49, colors.black, colors.white))
  WGUI.navWindow.pointsBorder.titleText = WGUI.navWindow:addChild(GUI.text(2, 1, colors.white, "Навигационные точки:"))
  -- Список точек
  WGUI.navWindow.pointsBorder.listBox = WGUI.navWindow:addChild(GUI.textBox(2, 2, 28, 48, nil, colors.white, {}, 1, 0, 0, false, false))
  WGUI.navWindow.pointsBorder.listBox.scrollBarEnabled = true
  -- Панель карты
  WGUI.navWindow.mapBorder = WGUI.navWindow:addChild(WGUI.BorderPanel(31, 1, 100, 49, colors.black, colors.white))
  WGUI.navWindow.mapBorder.titleText = WGUI.navWindow:addChild(GUI.text(32, 1, colors.white, "Карта:"))
  WGUI.navWindow.mapBorder.addPointButton = WGUI.navWindow:addChild(GUI.adaptiveButton(8,49,1,0,colors.greenButton,colors.white,colors.greenDark, colors.white, "НОВАЯ ТОЧКА"))
  WGUI.navWindow.mapBorder.addPointButton.onTouch = WGUI.AddNewPointDialog
  -- Область отрисовки карты
  WGUI.navWindow.mapView = WGUI.navWindow:addChild(GUI.container(2, 2, 98, 46))
  WGUI.navWindow.isDirty = true
  WGUI.navWindow.mapView.update = WGUI.UpdateMapView
  WGUI.navWindow.mapView.jumpBorder = WGUI.navWindow.mapView:addChild(WGUI.BorderPanel(2, 2, 2, 2, colors.black, 0xff0000))  
  WGUI.navWindow.mapView.shipSymbol = WGUI.navWindow.mapView:addChild(GUI.text(49, 23, colors.white, "^"))
  WGUI.navWindow.mapView.warpDestPoint = WGUI.navWindow.mapView:addChild(GUI.text(49, 23, colors.greenDark, "X"))
  WGUI.navWindow.mapView.autoDestPoint = WGUI.navWindow.mapView:addChild(GUI.text(49, 23, colors.greenDark, "A"))
  WGUI.navWindow.mapView.autoDestPoint.hidden = true
  WGUI.navWindow.mapView.navPoints  = {} -- временный список отрисованных навигационных точек.
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

function WGUI.SelectNavMapWorldType(worldType)
  programSettings.currentWorldType = worldType
  WGUI.Refresh()
end

function WGUI.SelectGUIMode(mode)
  programSettings.currentGUIMode = mode
  WGUI.Refresh()
end

function WGUI.AddNewPointDialog()
  
end

function WGUI.Refresh()
  for k,v in ipairs(WGUI.refreshMethods) do
    v()
  end
  WGUI.app:draw(true)
end

function WGUI.UpdateChargeBar() 
  local chargePercent, energyLevel, maxEnergy = shipLogic.GetCoreCharge()
  local maxBarWidth = 20
  local barWidth = math.ceil( (chargePercent * maxBarWidth) / 100)
  WGUI.chargeBarEnergyLevel.text = chargePercent.."% ("..energyLevel..")"
  WGUI.chargeBarEnergyLevel.localX = WGUI.screenWidth - 16
  WGUI.chargeBarPanel.width = barWidth
end

function WGUI.UpdateShipInfoPanel()
  local x,y,z    = warpdrive.GetShipPosition()
  local ox,oy,oz = warpdrive.GetShipOrientation()
  local orientationConverted = WGUI.ConvertRawOrientation(ox,oz)
  WGUI.rightPanel.infoBoxPanel.xCoordText.text = "  X: ".. x
  WGUI.rightPanel.infoBoxPanel.xCoordText.text = "  Y: ".. y
  WGUI.rightPanel.infoBoxPanel.xCoordText.text = "  Z: ".. z
  WGUI.rightPanel.infoBoxPanel.dirText.text    = "Направление: " .. orientationConverted
end

function WGUI.UpdateMapView() 
  if WGUI.navWindow.isDirty == false then
    return
  end
  WGUI.navWindow.isDirty = false
  
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
	local jRectX = wmUtils.Clamp( 49 - (maxBound + mindz)/scalex,1,98)
	local jRectY = wmUtils.Clamp( 23 - (maxBound + mindx)/scaley,1,46)
  
  local border = WGUI.navWindow.mapView.jumpBorder
  border.localX = jRectX
  border.localY = jRectY
  border.width  = wmUtils.Clamp(( (maxBound + mindz)*2)/scalex,0,98)
  border.height = wmUtils.Clamp(( (maxBound + mindx)*2)/scaley,0,45)
  
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
		dspX = tools.Clamp(49 + math.floor(dspX/scalex), 1,98)
		dspY = tools.Clamp(23 + math.floor(dspY/scaley),1, 46)
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
      local point = {}
			displayedNavPoints[pointIndex] = point
      point.info = pointInfo
      point.mapElement = WGUI.navWindow.mapView:addChild(GUI.text(dx, dy, colors.white, pointIndex)) --TODO: раскрашивать точки по типам.
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
  
  WGUI.navWindow.mapView.shipSymbol:moveToFront()
  
  WGUI.UpdateNavPointList() 
end

function WGUI.UpdateNavPointList() 
  WGUI.navWindow.pointsBorder.listBox.lines = {}
  for k,v in ipairs(WGUI.navWindow.mapView.navPoints) do
    table.insert(WGUI.navWindow.pointsBorder.listBox.lines, {v.info.listName, colors.white})
  end
end

function WGUI.NavViewEventHandler(container, object, e1, e2, e3, e4)
  if e1 ~= "touch" then
    return
  end
  local contextMenu = GUI.addContextMenu(container, e3, e4)
  local newPoint    = contextMenu:addItem("Добавить точку")
  local removePoint = contextMenu:addItem("Удалить точку")
  local pointInfo   = contextMenu:addItem("Инфо о точке")
  local setAsTarget = contextMenu:addItem("Задать как цель")
  
  container:draw()
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

function WGUI.Terminate()
  softLogic.Quit()
  WGUI.app:stop()
end

local function WarpSoftInit()
	warpdrive.SetCoreMovement(0,0,0) 
	LoadInfoFromCore()
	
	if wmUtils.HasInternet() == true then
		local check, curVersion, remoteVersion = tools.CheckForUpdates()
		if check == true then
			WGUI.DrawNewVersionWindow(curVersion, remoteVersion)
		end
	else 
		WGUI.DrawNoInternetWindow()
	end
	
end

local function HandleInput(event)

end


--Точка входа
filesystem.setAutorunEnabled(false)
softLogic.Load()
c.gpu.setResolution(WGUI.screenWidth, WGUI.screenHeight)
WGUI.Init()
WGUI.Refresh()

if not warpdrive.CheckCore() then
	WGUI.DrawCoreNotFoundError()
else
	WarpSoftInit()
	
	if programSettings.firstLaunch == true or programSettings.firstLaunch == nil then
		--WGUI.FirstLaunch()
	end
end

WGUI.app:start()
