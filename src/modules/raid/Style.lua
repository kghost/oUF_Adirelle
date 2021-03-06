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

local _G, moduleName, private = _G, ...
local oUF_Adirelle, assert = _G.oUF_Adirelle, _G.assert
local oUF = assert(oUF_Adirelle.oUF, "oUF is undefined in oUF_Adirelle")

--<GLOBALS
local _G = _G
local abs = _G.abs
local ALTERNATE_POWER_INDEX = _G.Enum.PowerType.Alternate or 10
local ALT_POWER_TEX_FILL = _G.ALT_POWER_TEX_FILL or 2
local CreateFrame = _G.CreateFrame
local floor = _G.floor
local format = _G.format
local GetTime = _G.GetTime
local gsub = _G.gsub
local huge = _G.math.huge
local pairs = _G.pairs
local SecureButton_GetUnit = _G.SecureButton_GetUnit
local select = _G.select
local strmatch = _G.strmatch
local strsub = _G.strsub
local tostring = _G.tostring
local UnitAlternatePowerInfo = _G.UnitAlternatePowerInfo
local UnitAlternatePowerTextureInfo = _G.UnitAlternatePowerTextureInfo
local UnitClass = _G.UnitClass
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitIsConnected = _G.UnitIsConnected
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitName = _G.UnitName
local UnitPower = _G.UnitPower
local UnitPowerMax = _G.UnitPowerMax
local UNKNOWN = _G.UNKNOWN
local unpack = _G.unpack
--GLOBALS>
local mmin, mmax = _G.min, _G.max

-- Import some values from oUF_Adirelle namespace
local GetFrameUnitState = oUF_Adirelle.GetFrameUnitState
local backdrop, glowBorderBackdrop = oUF_Adirelle.backdrop, oUF_Adirelle.glowBorderBackdrop

-- Constants
local SCALE = 1.0
local WIDTH = 80
local SPACING = 2
local HEIGHT = 25
local BORDER_WIDTH = 1
local ICON_SIZE = 14
local INSET = 1
local SMALL_ICON_SIZE = 8
local borderBackdrop = { edgeFile = [[Interface\Addons\oUF_Adirelle\media\white16x16]], edgeSize = BORDER_WIDTH }

-- Export some constants
oUF_Adirelle.SCALE, oUF_Adirelle.WIDTH, oUF_Adirelle.SPACING, oUF_Adirelle.HEIGHT, oUF_Adirelle.BORDER_WIDTH, oUF_Adirelle.ICON_SIZE = SCALE, WIDTH, SPACING, HEIGHT, BORDER_WIDTH, ICON_SIZE

-- ------------------------------------------------------------------------------
-- Health bar and name updates
-- ------------------------------------------------------------------------------

-- Health point formatting
local function SmartHPValue(value)
	if abs(value) >= 1000 then
		return format("%.1fk",value/1000)
	else
		return format("%d", value)
	end
end

-- Update name
local function UpdateName(self, event, unit)
	if not unit then
		unit = self.unit
	elseif unit ~= self.unit and unit ~= self.realUnit then
		return
	end
	local healthBar = self.Health
	local r, g, b = 0.5, 0.5, 0.5
	if self.nameColor then
		r, g, b = unpack(self.nameColor)
	end
	if UnitCanAssist('player', unit) then
		local health, maxHealth = UnitHealth(unit), UnitHealthMax(unit)
		local incHeal = UnitGetIncomingHeals(unit) or 0
		local absorb = UnitGetTotalAbsorbs(unit) or 0
		local healAbsorb = UnitGetTotalHealAbsorbs(unit) or 0
		local threshold = maxHealth * 0.25
		if healAbsorb > 0 and health - healAbsorb <= threshold then
			r, g, b = unpack(oUF.colors.healPrediction.healAbsorb)
		elseif health - healAbsorb + incHeal >= maxHealth + threshold then
			r, g, b = unpack(oUF.colors.healPrediction.self)
		end
	end
	self.Name:SetTextColor(r, g, b, 1)
	self.Name:SetText(unit and UnitName(unit) or UNKNOWN)
end

-- Update health and name color
local function UpdateColor(self, event, unit)
	if unit and (unit ~= self.unit and unit ~= self.realUnit) then return end
	local refUnit = (self.realUnit or self.unit):gsub('pet', '')
	if refUnit == '' then refUnit = 'player' end -- 'pet'
	local class = UnitName(refUnit) ~= UNKNOWN and select(2, UnitClass(refUnit))
	local state = GetFrameUnitState(self, true) or class or ""
	if state ~= self.__stateColor then
		self.__stateColor = state
		local r, g, b = 0.5, 0.5, 0.5
		if class then
			r, g, b = unpack(oUF.colors.class[class])
		end
		local nR, nG, nB = r, g, b
		if state == "DEAD" or state == "DISCONNECTED" then
			r, g, b = unpack(oUF.colors.disconnected)
		elseif state == "CHARMED" then
			r, g, b = unpack(oUF.colors.charmed.background)
			nR, nG, nB = unpack(oUF.colors.charmed.name)
		elseif state == "INVEHICLE" then
			r, g, b = unpack(oUF.colors.vehicle.background)
			nR, nG, nB = unpack(oUF.colors.vehicle.name)
		end
		self.bgColor[1], self.bgColor[2], self.bgColor[3] = r, g, b
		self.Health.bg:SetVertexColor(r, g, b, 1)
		self.nameColor[1], self.nameColor[2], self.nameColor[3] = nR, nG, nB
	end
	return UpdateName(self)
end

-- Add a pseudo-element to update the color
do
	local function UNIT_PET(self, event, unit)
		if unit == "player" then
			return UpdateColor(self, event, "pet")
		elseif unit then
			return UpdateColor(self, event, gsub(unit, "(%d*)$", "pet%1"))
		end
	end

	oUF:AddElement('Adirelle_Raid:UpdateColor',
		UpdateColor,
		function(self)
			if self.Health and self.bgColor and self.style == "Adirelle_Raid" then
				self:RegisterEvent('UNIT_NAME_UPDATE', UpdateColor)
				self:RegisterEvent('UNIT_HEAL_PREDICTION', UpdateName)
				self:RegisterEvent('UNIT_MAXHEALTH', UpdateName)
				self:RegisterEvent('UNIT_HEALTH', UpdateName)
				self:RegisterEvent('UNIT_ABSORB_AMOUNT_CHANGED', UpdateName)
				self:RegisterEvent('UNIT_HEAL_ABSORB_AMOUNT_CHANGED', UpdateName)
				if self.unit and strmatch(self.unit, 'pet') then
					self:RegisterEvent('UNIT_PET', UNIT_PET)
				end
				return true
			end
		end,
		function() end
	)
end

-- Layout internal frames on size change
local function OnSizeChanged(self, width, height)
	width = width or self:GetWidth()
	height = height or self:GetHeight()
	if not width or not height then return end
	local w = BORDER_WIDTH / self:GetEffectiveScale()
	self.Border:SetSize(width + 2 * w, height + 2 * w)
	self.ReadyCheckIndicator:SetSize(height, height)
	self.StatusIcon:SetSize(height*2, height)
	self.WarningIconBuff:SetPoint("CENTER", self, "LEFT", width / 4, 0)
	self.WarningIconDebuff:SetPoint("CENTER", self, "RIGHT", -width / 4, 0)
end

-- ------------------------------------------------------------------------------
-- Aura icon initialization
-- ------------------------------------------------------------------------------

do
	local playerClass = oUF_Adirelle.playerClass
	local GetAnyAuraFilter = private.GetAnyAuraFilter

	local band = _G.bit.band
	local LPS = oUF_Adirelle.GetLib('LibPlayerSpells-1.0')
	local requiredFlags = oUF_Adirelle.playerClass.." AURA"
	local rejectedFlags = "INTERRUPT DISPEL BURST SURVIVAL HARMFUL"
	local INVERT_AURA = LPS.constants.INVERT_AURA
	local UNIQUE_AURA = LPS.constants.UNIQUE_AURA

	local anchors = { "TOPLEFT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMLEFT", "TOP", "RIGHT", "BOTTOM", "LEFT" }

	local filters = {}
	local defaultAnchors = {}
	local count = 0

	local ExpandFlags
	do
		local C = LPS.constants
		local bnot = _G.bit.bnot

		local function expandSimple2(flags, n, ...)
			if not n then
				return
			end
			local v = C[n]
			if band(flags, v) ~= 0 then
				return n, expandSimple2(flags, ...)
			else
				return expandSimple2(flags, ...)
			end
		end

		local function expandSimple(flags, n, ...)
			if not n then
				if band(flags, C.DISPEL) ~= 0 then
					return expandSimple2(flags, "CURSE", "DISEASE", "MAGIC", "POISON")
				end
				if band(flags, C.CROWD_CTRL) ~= 0 then
					return expandSimple2(flags, "DISORIENT", "INCAPACITATE", "ROOT", "STUN", "TAUNT")
				end
				return expandSimple2(flags, "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "HUNTER", "MAGE", "MONK",
					"PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR", "RACIAL")
			end
			local v = C[n]
			if band(flags, v) ~= 0 then
				return n, expandSimple(flags, ...)
			else
				return expandSimple(flags, ...)
			end
		end

		function ExpandFlags(flags)
			return expandSimple(flags, "DISPEL", "CROWD_CTRL", "HELPFUL", "HARMFUL", "PERSONAL", "PET", "AURA",
				"INVERT_AURA", "UNIQUE_AURA", "COOLDOWN", "SURVIVAL", "BURST", "POWER_REGEN", "IMPORTANT", "INTERRUPT",
				"KNOCKBACK", "SNARE")
		end
	end

	for spellId, flags in LPS:IterateSpells("HELPFUL PET", requiredFlags, rejectedFlags) do
		local auraFilter = band(flags, INVERT_AURA) ~= 0 and "HARMFUL" or "HELPFUL"
		if band(flags, UNIQUE_AURA) == 0 then
			auraFilter = auraFilter .. " PLAYER"
		end
		oUF_Adirelle.Debug('Watching buff', spellId, GetSpellInfo(spellId), 'with filter', auraFilter, 'flags: ', ExpandFlags(flags))

		filters[spellId] = GetAnyAuraFilter(spellId, auraFilter)
		count = (count % #anchors) + 1
		defaultAnchors[spellId] = anchors[count]
	end

	oUF_Adirelle.ClassAuraIcons = {
		filters = filters,
		defaultAnchors = defaultAnchors
	}
end

local function CreateClassAuraIcons(self)
	self.ClassAuraIcons = {}
	for id, filter in pairs(oUF_Adirelle.ClassAuraIcons.filters) do
		local icon = self:CreateIcon(self.Overlay, SMALL_ICON_SIZE, true, true, true, false)
		self.ClassAuraIcons[id] = icon
		self:AddAuraIcon(icon, filter)
	end
end

local function LayoutClassAuraIcons(self, layout)
	for id, icon in pairs(self.ClassAuraIcons) do
		local anchor = layout.Raid.classAuraIcons[id] or oUF_Adirelle.ClassAuraIcons.defaultAnchors[id]
		icon:ClearAllPoints()
		if anchor and anchor ~= "HIDDEN" then
			local xOffset = strmatch(anchor, "LEFT") and INSET or strmatch(anchor, "RIGHT") and -INSET or 0
			local yOffset = strmatch(anchor, "BOTTOM") and INSET or strmatch(anchor, "TOP") and -INSET or 0
			icon:SetPoint(anchor, xOffset, yOffset)
		end
	end
end

-- ------------------------------------------------------------------------------
-- Alternate Power Bar
-- ------------------------------------------------------------------------------

local function AlternativePower_PostUpdate(bar, unit, cur, min, max)
	if unit ~= bar.__owner.unit then return end
	local _, powerRed, powerGreen, powerBlue = UnitAlternatePowerTextureInfo(unit, ALT_POWER_TEX_FILL)
	if powerRed and powerGreen and powerBlue then
		local r, g, b = oUF.ColorGradient(cur-min, max-min, powerRed, powerGreen, powerBlue, 1, 0, 0)
		bar:SetStatusBarColor(r, g, b)
	else
		bar:SetStatusBarColor(0.75, 0.75, 0.75)
	end
end

local function AlternativePower_Layout(bar)
	local self = bar.__owner
	if bar:IsShown() then
		self.Health:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 0)
	else
		self.Health:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
	end
end

local function XRange_PostUpdate(xrange, event, unit, inRange)
	xrange.__owner:SetAlpha(inRange and 1 or oUF.colors.outOfRange[4])
end

local function OnRaidLayoutModified(self, event, layout)
	local small, big = layout.Raid.smallIconSize, layout.Raid.bigIconSize
	self.WarningIconBuff:SetSize(big, big)
	self.WarningIconDebuff:SetSize(big, big)
	self.RoleIcon:SetSize(small, small)
	self.TargetIcon:SetSize(small, small)
	for icon in pairs(self.AuraIcons) do
		if icon.big then
			icon:SetSize(big, big)
		else
			icon:SetSize(small, small)
		end
	end

	LayoutClassAuraIcons(self, layout)
end

local function OnThemeModified(self, event, layout, theme)
	-- Update border settings
	local border = self.Border
	for k, v in pairs(theme.Border) do
		border[k] = v
	end
	border:ForceUpdate()

	-- Update low health threshold
	local lowHealth = self.LowHealth
	if lowHealth then
		local prefs = theme.LowHealth
		lowHealth.threshold = prefs.isPercent and -prefs.percent or prefs.amount
		lowHealth:ForceUpdate()
	end
end

local function OnColorModified(self)
	self.XRange.Texture:SetColorTexture(unpack(oUF.colors.outOfRange, 1, 3))
	self.XRange:ForceUpdate()
	return UpdateColor(self)
end

local function CureableDebuff_SetColor(icon, r, g, b, a)
	local texture, border = icon.Texture, icon.Border
	r, g, b, a = tonumber(r), tonumber(g), tonumber(b), tonumber(a) or 1
	if r and g and b then
		texture:SetVertexColor(0.5 + 0.5 * r, 0.5 + 0.5 * g, 0.5 + 0.5 * b, a)
		border:SetVertexColor(r, g, b)
		border:Show()
	else
		texture:SetVertexColor(1, 1, 1, a)
		border:Hide()
	end
end

-- ------------------------------------------------------------------------------
-- Unit frame initialization
-- ------------------------------------------------------------------------------

local function InitFrame(self, unit)
	self:RegisterForClicks("AnyDown")

	self:SetScript("OnEnter", oUF_Adirelle.Unit_OnEnter)
	self:SetScript("OnLeave", oUF_Adirelle.Unit_OnLeave)

	self:SetBackdrop(backdrop)
	self:SetBackdropColor(0, 0, 0, backdrop.bgAlpha)
	self:SetBackdropBorderColor(0, 0, 0, 1)

	-- Let it have dispel click on mouse button 2
	self.CustomClick = {}

	-- Health bar
	local hp = CreateFrame("StatusBar", nil, self)
	hp.current, hp.max = 0, 0
	hp:SetPoint("TOPLEFT")
	hp:SetPoint("BOTTOMRIGHT")
	hp.frequentUpdates = true
	self.Health = hp
	self:RegisterStatusBarTexture(hp)
	hp:SetStatusBarColor(0, 0, 0, 0.75)

	self.bgColor = { 1, 1, 1 }
	self.nameColor = { 1, 1, 1 }

	local hpbg = hp:CreateTexture(nil, "BACKGROUND", nil, -1)
	hpbg:SetAllPoints(hp)
	hpbg:SetAlpha(1)
	hp.bg = hpbg
	self:RegisterStatusBarTexture(hpbg)

	-- Heal prediction
	self:SpawnHealthPrediction(1.00)

	-- Border
	local border = CreateFrame("Frame", nil, self)
	border:SetFrameStrata("BACKGROUND")
	border:SetPoint("CENTER")
	border:SetBackdrop(borderBackdrop)
	border:SetBackdropColor(0, 0, 0, 0)
	border:SetBackdropBorderColor(1, 1, 1, 1)
	border.SetColor = border.SetBackdropBorderColor
	border:Hide()
	self.Border = border

	-- Indicator overlays
	local overlay = CreateFrame("Frame", nil, self)
	overlay:SetAllPoints(self)
	overlay:SetFrameLevel(border:GetFrameLevel()+3)
	self.Overlay = overlay

	-- Name
	local name = overlay:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	name:SetPoint("TOPLEFT", 6, 0)
	name:SetPoint("BOTTOMRIGHT", -6, 0)
	name:SetJustifyH("CENTER")
	name:SetJustifyV("MIDDLE")
	self:RegisterFontString(name, "raid", 11, "")
	self.Name = name

	-- Big status icon
	local status = overlay:CreateTexture(nil, "BORDER", nil, 1)
	status:SetPoint("CENTER")
	status:SetAlpha(0.75)
	status:SetBlendMode("ADD")
	status:Hide()
	status.PostUpdate = UpdateColor
	self.StatusIcon = status

	-- ReadyCheck icon
	local rc = CreateFrame("Frame", self:GetName().."ReadyCheck", overlay)
	rc:SetFrameLevel(self:GetFrameLevel()+5)
	rc:SetPoint('CENTER')
	rc:SetAlpha(1)
	rc:Hide()
	rc.icon = rc:CreateTexture(rc:GetName().."Texture")
	rc.icon:SetAllPoints(rc)
	rc.SetTexture = function(_, ...) return rc.icon:SetTexture(...) end
	self.ReadyCheckIndicator = rc

	-- Have icons blinking 3 seconds before fading out
	self.iconBlinkThreshold = 3

	-- Important class buffs
	self.WarningIconBuff = self:CreateIcon(self.Overlay, ICON_SIZE, false, false, true, false, "CENTER", self, "LEFT", WIDTH * 0.25, 0)

	-- Cureable debuffs
	local debuff = self:CreateIcon(self.Overlay, ICON_SIZE, false, false, false, false, "CENTER")
	debuff.big = true
	debuff.SetColor = CureableDebuff_SetColor
	self:AddAuraIcon(debuff, "CureableDebuff")

	-- Important debuffs
	self.WarningIconDebuff = self:CreateIcon(self.Overlay, ICON_SIZE, false, false, false, false, "CENTER", self, "RIGHT", -WIDTH * 0.25, 0)
	self.WarningIconDebuff.noDispellable = true

	-- Class-specific icons
	CreateClassAuraIcons(self)

	-- Threat glow
	local threat = CreateFrame("Frame", nil, self)
	threat:SetAllPoints(self)
	threat:SetBackdrop(glowBorderBackdrop)
	threat:SetBackdropColor(0,0,0,0)
	threat.SetVertexColor = threat.SetBackdropBorderColor
	threat:SetAlpha(glowBorderBackdrop.alpha)
	threat:SetFrameLevel(self:GetFrameLevel()+2)
	self.SmartThreat = threat

	-- Role/Raid icon
	local roleIcon = overlay:CreateTexture(nil, "ARTWORK")
	roleIcon:SetSize(SMALL_ICON_SIZE, SMALL_ICON_SIZE)
	roleIcon:SetPoint("LEFT", self, "LEFT", INSET, 0)
	roleIcon.noDamager = true
	roleIcon.noCircle = true
	self.RoleIcon = roleIcon

	-- Target raid icon
	local targetIcon = overlay:CreateTexture(nil, "ARTWORK")
	targetIcon:SetSize(SMALL_ICON_SIZE, SMALL_ICON_SIZE)
	targetIcon:SetPoint("RIGHT", self, "RIGHT", -INSET, 0)
	self.TargetIcon = targetIcon

	-- LowHealth warning
	local lowHealth = hp:CreateTexture(nil, "OVERLAY")
	lowHealth:SetAllPoints(border)
	lowHealth:SetColorTexture(1, 0, 0, 0.5)
	self.LowHealth = lowHealth

	-- AlternativePower
	local alternativePower = CreateFrame("StatusBar", nil, self)
	alternativePower:SetBackdrop(backdrop)
	alternativePower:SetBackdropColor(0, 0, 0, 1)
	alternativePower:SetBackdropBorderColor(0, 0, 0, 0)
	alternativePower:SetPoint("BOTTOMLEFT")
	alternativePower:SetPoint("BOTTOMRIGHT")
	alternativePower:SetHeight(5)
	alternativePower:Hide()
	alternativePower.PostUpdate = AlternativePower_PostUpdate
	alternativePower:SetScript('OnShow', AlternativePower_Layout)
	alternativePower:SetScript('OnHide', AlternativePower_Layout)
	alternativePower:SetFrameLevel(threat:GetFrameLevel()+1)
	self:RegisterStatusBarTexture(alternativePower)
	self.AlternativePower = alternativePower

	-- Setting callbacks
	self:RegisterMessage('OnSettingsModified', OnRaidLayoutModified)
	self:RegisterMessage('OnRaidLayoutModified', OnRaidLayoutModified)
	self:RegisterMessage('OnSettingsModified', OnColorModified)
	self:RegisterMessage('OnColorModified', OnColorModified)
	self:RegisterMessage('OnSettingsModified', OnThemeModified)
	self:RegisterMessage('OnThemeModified', OnThemeModified)

	-- Range fading
	local xrange = CreateFrame("Frame", nil, overlay)
	xrange:SetAllPoints(self)
	xrange:SetFrameLevel(overlay:GetFrameLevel()+10)
	xrange.PostUpdate = XRange_PostUpdate

	local tex = xrange:CreateTexture(nil, "OVERLAY")
	tex:SetAllPoints(self)
	tex:SetColorTexture(0.4, 0.4, 0.4)
	tex:SetBlendMode("MOD")

	xrange.Texture = tex
	self.XRange = xrange

	-- Hook OnSizeChanged to layout internal on size change
	self:HookScript('OnSizeChanged', OnSizeChanged)
	OnSizeChanged(self, WIDTH, HEIGHT)
end

-- ------------------------------------------------------------------------------
-- Style and layout setup
-- ------------------------------------------------------------------------------

oUF:RegisterStyle("Adirelle_Raid", InitFrame)

oUF_Adirelle.RaidStyle = true
