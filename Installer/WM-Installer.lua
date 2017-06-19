local c = require("component")
local libraries = {
	ecs = "ECSAPI",
	event = "event",
	filesystem = "filesystem",
	computer = "computer"
}
for library in pairs(libraries) do if not _G[library] then _G[library] = require(libraries[library]) end end; libraries = nil

local url = {
			"https://raw.githubusercontent.com/TxN/MC-WarpMaster/master/Application/Main.lua",
			"https://raw.githubusercontent.com/TxN/MC-WarpMaster/master/Application/Resources/Icon.pic",
			"https://raw.githubusercontent.com/TxN/MC-WarpMaster/master/Application/Resources/WarpMasterIcon.pic",
			"https://raw.githubusercontent.com/TxN/MC-WarpMaster/master/Lib/libwarp.lua",
			"https://raw.githubusercontent.com/TxN/MC-WarpMaster/master/Application/Resources/About/Russian.txt",
      "https://raw.githubusercontent.com/TxN/MC-WarpMaster/master/Application/Version.txt"
			}
local path = {
			"MineOS/Applications/WarpMaster.app/Main.lua",
			"MineOS/Applications/WarpMaster.app/Resources/Icon.pic",
			"MineOS/Applications/WarpMaster.app/Resources/WarpMasterIcon.pic",
			"lib/libwarp.lua",
			"MineOS/Applications/WarpMaster.app/Resources/About/Russian.txt",
      "MineOS/Applications/WarpMaster.app/Version.txt"
			}

local function Download()
	for i=1,#url do
		ecs.getFileFromUrl(url[i], path[i])
		print("Downloading file " .. i .. " of " .. #url)
	end
	
end

print("Downloading WarpMaster...")
Download()
print("Done!")
