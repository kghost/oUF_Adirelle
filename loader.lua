--[=[
Adirelle's oUF layout
(c) 2009-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]=]

local Debug
if AdiDebug then
	Debug = AdiDebug:GetSink("oUF_Adirelle_Loader")
else
	function Debug() end
end

local loaderName = ...
local loaderFrame = CreateFrame("Frame")

local function CanLoad(name)
	if not IsAddOnLoaded(name) then
		local _, _, _, enabled, loadable = GetAddOnInfo(name)
		return enabled and loadable
	end
end

local function Load(name)
	local loaded, reason = LoadAddOn(name)
	if loaded then
		Debug(name, 'loaded')
	else
		Debug('Could not load', name, ':', reason)
	end
end

local function LoadModules(event)
	Debug('Trying to load modules on', event)
	if CanLoad('oUF_Adirelle_Raid') and (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0) then
		Load('oUF_Adirelle_Raid')
	end
	if CanLoad('oUF_Adirelle_Single') then
		Load('oUF_Adirelle_Single')	
	end
	local _, instanceType = IsInInstance()
	if CanLoad('oUF_Adirelle_Boss') and (instanceType == "party" or instanceType == "raid") then
		Load('oUF_Adirelle_Boss')
	elseif CanLoad('oUF_Adirelle_Arena') and instanceType == "arena" then
		Load('oUF_Adirelle_Arena')
	end
	if not CanLoad('oUF_Adirelle_Raid') and loaderFrame:IsEventRegistered('PARTY_MEMBERS_CHANGED') then
		Debug('Stop listening to PARTY_MEMBERS_CHANGED')
		loaderFrame:UnregisterEvent('PARTY_MEMBERS_CHANGED')
	end
	if not CanLoad('oUF_Adirelle_Boss') and not CanLoad('oUF_Adirelle_Arena') and loaderFrame:IsEventRegistered('PLAYER_ENTERING_WORLD') then
		Debug('Stop listening to PLAYER_ENTERING_WORLD')
		loaderFrame:UnregisterEvent('PLAYER_ENTERING_WORLD')
	end
end

loaderFrame:SetScript('OnEvent', function(self, event, ...)
	if event == 'ADDON_LOADED' then
		if ... == loaderName then
			Debug('Stop listening to ADDON_LOADED')
			loaderFrame:UnregisterEvent('ADDON_LOADED')
		else
			return
		end
	end
	return LoadModules(event)
end)
loaderFrame:RegisterEvent('ADDON_LOADED')
loaderFrame:RegisterEvent('PLAYER_LOGIN')
loaderFrame:RegisterEvent('PARTY_MEMBERS_CHANGED')
loaderFrame:RegisterEvent('PLAYER_ENTERING_WORLD')

LoadModules('initialization')
