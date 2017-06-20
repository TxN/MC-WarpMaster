local c = require("component")
local libraries = {
	ecs = "ECSAPI",
	event = "event",
	filesystem = "filesystem",
	computer = "computer",
  serialization = "serialization",
  buffer = "doubleBuffering"
}
for library in pairs(libraries) do if not _G[library] then _G[library] = require(libraries[library]) end end; libraries = nil

local listURL = "https://raw.githubusercontent.com/TxN/MC-WarpMaster/master/Installer/FileList.cfg"

local function Download()
  local success, response = pcall(c.internet.request, listURL)
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

c.gpu.setResolution(100,50)
buffer.flush(100, 50)
ecs.clearScreen(0x000000)

print("Downloading WarpMaster...")
if Download() == true then
  print("Done!")
else
  print("Download error.")
end


