 --[=[
Adirelle's oUF layout
(c) 2014-2016 Adirelle (adirelle@gmail.com)

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

Elements handled: .CustomClick
--]=]

local _G, addonName, private = _G, ...
local oUF_Adirelle, assert = _G.oUF_Adirelle, _G.assert
local oUF = assert(oUF_Adirelle.oUF, "oUF is undefined in oUF_Adirelle")

--<GLOBALS
local _G = _G
local band = _G.bit.band
local bor = _G.bit.bor
--GLOBALS>

local Dispels = oUF_Adirelle.Dispels
local LPS = oUF_Adirelle.GetLib('LibPlayerSpells-1.0')
local LS = oUF_Adirelle.GetLib('LibSpellbook-1.0')
local C = LPS.constants
local HARMFUL = C.HARMFUL

local function SetAction(self, targetType, spellID)
	self:Debug("CustomClick", targetType, spellID and GetSpellInfo(spellID) or "-")
	self:SetAttribute("*" .. targetType .. "button" .. self.CustomClick.button, spellID and targetType)
	self:SetAttribute("type-" .. targetType, spellID and "spell")
	self:SetAttribute("spell-" .. targetType, spellID)
end

local function Update(self)
	if not self:CanChangeAttribute() then return end

	local flags = self.CustomClick.flags
	local helpful, harmful
	for spellID, data in pairs(Dispels) do
		if LS:IsKnown(spellID) then
			if not helpful and band(data[1], flags) ~= 0 then
				helpful = spellID
			end
			if not harmful and band(data[1], HARMFUL) ~= 0 then
				harmful = spellID
			end
			if helpful and harmful then
				break
			end
        end
	end

	SetAction(self, "help", helpful)
	SetAction(self, "harm", harmful)
end

local function ForceUpdate(element)
	return Update(element.__owner)
end

local function Enable(self)
	local element = self.CustomClick
	if element and next(Dispels) then

		if not element.button then
			element.button = "2"
		end

		if not element.flags then
			local unit = self.unit
			if unit == "pet" then
				element.flags = bor(C.HELPFUL, C.PET)
			elseif unit == "player" then
				element.flags = bor(C.HELPFUL, C.PERSONAL)
			else
				element.flags = C.HELPFUL
			end
		end

		element.__owner, element.ForceUpdate = self, ForceUpdate
		self:RegisterEvent('PLAYER_REGEN_DISABLED', Update, true)
		self:RegisterEvent('PLAYER_REGEN_ENABLED', Update, true)
		LS.RegisterCallback(self, 'LibSpellbook_Spells_Changed', Update, self)
		return true
	end
end

local function Disable(self)
	if self.CustomClick and next(Dispels) then
		if self:CanChangeAttribute() then
			SetAction(self, "help", nil)
			SetAction(self, "harm", nil)
		end
		self:UnregisterEvent('PLAYER_REGEN_DISABLED', Update)
		self:UnregisterEvent('PLAYER_REGEN_ENABLED', Update)
		LS.UnregisterCallback(self, 'LibSpellbook_Spells_Changed')
	end
end

oUF:AddElement('CustomClick', Update, Enable, Disable)
