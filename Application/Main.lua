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
  gray        = 0x2D2D2D,
  blue        = 0x3366CC
}

local programSettings = {
	firstLaunch      = true,
	navScaleX        = 4,
	navScaleY        = 8,
	currentWorldType = "earth",
	lock             = false, --может быть и наивно, но смогут обойти не только лишь все.
	planetsListFile  = "Empty"
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


function WGUI.Init()
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
  WGUI.rightPanel = WGUI.app:addChild(WGUI.BorderPanel(WGUI.screenWidth - 29, 2, 30, WGUI.screenHeight - 1, colors.black, colors.white))
  WGUI.rightPanel.titleText = WGUI.app:addChild(GUI.text(WGUI.screenWidth - 28, 2, colors.white, "МЕНЮ:"))
  
  -- окно НАВ режима
  
  WGUI.navWindow = WGUI.app:addChild(GUI.container(1, 2, WGUI.screenWidth - 30, WGUI.screenHeight - 1))
  -- Панель со списком точек
  WGUI.navWindow.pointsBorder = WGUI.navWindow:addChild(WGUI.BorderPanel(1, 1, 30, 49, colors.black, colors.white))
  WGUI.navWindow.pointsBorder.titleText = WGUI.navWindow:addChild(GUI.text(2, 1, colors.white, "Навигационные точки:"))
  -- Панель карты
  WGUI.navWindow.mapBorder = WGUI.navWindow:addChild(WGUI.BorderPanel(31, 1, 100, 49, colors.black, colors.white))
  WGUI.navWindow.mapBorder.titleText = WGUI.navWindow:addChild(GUI.text(32, 1, colors.white, "Карта:"))

  --table.insert(WGUI.refreshMethods, WGUI.UpdateChargeBar)
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
