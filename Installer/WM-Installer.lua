local listURL    = "https://raw.githubusercontent.com/TxN/MC-WarpMaster/master/Installer/FileList.cfg"
local errorFlag  = false
local c          = require("component")
local term       = require("term")
local filesystem = require("filesystem")

local x,y        = c.gpu.maxResolution()
c.gpu.setResolution(x,y)
c.gpu.fill(1, 1, x, y, " ")
c.gpu.setForeground(0xFFFFFF)
c.gpu.setBackground(0x000000)
term.setCursor(1,1)

print("---- WarpMaster app installer ----")
print(" ")

if filesystem.exists("/lib/ECSAPI.lua") == false then 
	print("Error!")
	print("Could not find MineOS libraries.")
	print("Please install MineOS first.")
	print("---")
	errorFlag = true
end

if c.isAvailable("internet") == false then 
	print("Error!")
	print("Internet card is not installed.")
	print("Internet is required to install WarpMaster.")
	print("---")
	errorFlag = true
end

local libraries = {
	ecs = "ECSAPI",
	event = "event",
	computer = "computer",
	serialization = "serialization"
}

if errorFlag == false then
	for library in pairs(libraries) do if not _G[library] then _G[library] = require(libraries[library]) end end; libraries = nil
end
	
local function Download()
  local success, response = ecs.internetRequest(listURL)
  print("Getting file list...")
  if success == false then
    return false
  end
  
  local fileData = serialization.unserialize(response)
  
	for i=1,#fileData.url do
		ecs.getFileFromUrl(fileData.url[i], fileData.path[i])
		print("Downloading file " .. i .. " of " .. #fileData.url)
	end
  
  return true
end

if errorFlag == false then
	print("Downloading WarpMaster...")
	if Download() == true then
		print("Done!")
		print("Now you can run MineOS again. Type 'OS' command in console.")
	else
		print("Download error.")
	end
end
