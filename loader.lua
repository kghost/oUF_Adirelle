--[=[
Adirelle's oUF layout
(c) 2009-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]=]

local modules = {
	oUF_Adirelle_Raid = {
		event = "PLAYER_MEMBERS_CHANGED",
		test = function() return GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 end, 
	},
	oUF_Adirelle_Arena = {
		event = "PLAYER_ENTERING_WORLD",
		test = function() return select(2, IsInInstance()) == "arena" end,
	},
	oUF_Adirelle_Boss = {
		event = "PLAYER_ENTERING_WORLD",
		test = function()
			local _, iType = IsInInstance()
			return iType == "party" or iType == "raid"
		end,
	},
}

-- Remove modules that cannot be loaded
for name, data in pairs(modules) do
	local _, _, enabled, loadable = GetAddOnInfo(name)
	if IsAddOnLoaded(name) or not enabled or not loadable then
		modules[name] = nil
	end
end

if not next(modules) then return end

local function TryToLoadModules()
	for name, data in pairs(modules) do
		if data.test() then
			if LoadAddOn(name) then
				modules[name] = nil
			end
		end
	end
end

-- Try immediately
TryToLoadModules()

if not next(modules) then return end

-- There are still unloaded modules, test them on PLAYER_LOGIN
local loaderFrame = CreateFrame("Frame")
loaderFrame:RegisterEvent('PLAYER_LOGIN')
loaderFrame:SetScript('OnEvent', function(self, event, name)
	self:UnregisterAllEvents()
	TryToLoadModules()
	for name, data in pairs(modules) do
		self:RegisterEvent(data.event)
	end	
end)

