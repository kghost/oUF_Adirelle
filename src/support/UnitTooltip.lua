--[=[
Adirelle's oUF layout
(c) 2009-2016 Adirelle (adirelle@gmail.com)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
--]=]

local _G, addonName, private = _G, ...
local oUF_Adirelle, assert = _G.oUF_Adirelle, _G.assert
local oUF = assert(oUF_Adirelle.oUF, "oUF is undefined in oUF_Adirelle")

--<GLOBALS
local _G = _G
local GameTooltip = _G.GameTooltip
local InCombatLockdown = _G.InCombatLockdown
local UIParent = _G.UIParent
--GLOBALS>

local function UpdateTooltip(frame)
	if not GameTooltip:IsOwned(frame) then return end
	if GameTooltip:SetUnit(frame.unit) then
		frame.UpdateTooltip = UpdateTooltip
	else
		frame.UpdateTooltip = nil
	end
	local r, g, b = GameTooltip_UnitColor(frame.unit)
	_G.GameTooltipTextLeft1:SetTextColor(r, g, b)
end

function oUF_Adirelle.Unit_OnEnter(frame)
	if not oUF_Adirelle.layoutDB.profile.unitTooltip.enabled
		or (InCombatLockdown() and not oUF_Adirelle.layoutDB.profile.unitTooltip.inCombat) then
		-- Forcefully hide TipTop
		if TipTop and TipTop:IsVisible() then
			GameTooltip:Hide()
		end
		return
	end
	local anchor = oUF_Adirelle.layoutDB.profile.unitTooltip.anchor
	if anchor == "DEFAULT" then
		GameTooltip_SetDefaultAnchor(GameTooltip, frame)
	else
		local x = frame:GetCenter() / frame:GetEffectiveScale()
		local w = UIParent:GetWidth() / UIParent:GetEffectiveScale()
		local side = (x < w/2) and "LEFT" or "RIGHT"
		GameTooltip:SetOwner(frame, anchor..side)
	end
	return UpdateTooltip(frame)
end

function oUF_Adirelle.Unit_OnLeave(frame)
	if GameTooltip:IsOwned(frame) then
		if oUF_Adirelle.layoutDB.profile.unitTooltip.fadeOut then
			GameTooltip:FadeOut()
		else
			GameTooltip:Hide()
		end
	end
end
