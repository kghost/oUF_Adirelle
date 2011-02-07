--[=[
Adirelle's oUF layout
(c) 2009-2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.

Elements handled: .RuneBar
--]=]

local parent, ns = ...
local oUF = assert(ns.oUF, "oUF is undefined in "..parent.." namespace")

local function OnUpdate(totem, elapsed)			
	local timeLeft = totem:GetValue() - elapsed
	if timeLeft <= 0 then
		totem:Hide()
	else
		totem:SetValue(timeLeft)
	end
end

local function Update(self, event, ...)
	for index, totem in ipairs(self.TotemBar) do
		local haveTotem, name, start, duration = GetTotemInfo(totem.totemType)
		if haveTotem and name and name ~= "" then
			totem:SetMinMaxValues(0, duration)
			totem:SetValue(start+duration-GetTime())
			totem:Show()
		else
			totem:Hide()
		end
	end
end

local function Enable(self)
	if self.TotemBar then
		self:RegisterEvent('PLAYER_TOTEM_UPDATE', Update)
		for index, totem in ipairs(self.TotemBar) do
			totem:Hide()
			totem:SetScript('OnUpdate', OnUpdate)
		end
		self.TotemBar:Show()
		return true
	end
end

local function Disable(self)
	if self.TotemBar then
		self:UnregisterEvent('PLAYER_TOTEM_UPDATE', Update)
	end
end

oUF:AddElement('TotemBar', Update, Enable, Disable)
