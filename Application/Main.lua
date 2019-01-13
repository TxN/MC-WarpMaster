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
  gray        = 0x2D2D2D
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


function WGUI.Init()
  WGUI.app = GUI.application(1, 1, WGUI.screenWidth, WGUI.screenHeight)
  WGUI.mainWindow = WGUI.app:addChild(GUI.titledWindow(1, 1, WGUI.screenWidth, WGUI.screenHeight,"WarpMaster", true))
  local actionButtons = WGUI.mainWindow.actionButtons
  actionButtons.close.onTouch = WGUI.Terminate
  
  WGUI.mainWindow.backgroundPanel.colors.background = colors.black
  
  WGUI.app:draw(true)
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


if not warpdrive.CheckCore() then
	WGUI.DrawCoreNotFoundError()
else
	WarpSoftInit()
	
	if programSettings.firstLaunch == true or programSettings.firstLaunch == nil then
		--WGUI.FirstLaunch()
	end
end

WGUI.app:start()
