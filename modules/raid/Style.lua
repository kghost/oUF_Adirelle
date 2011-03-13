--[=[
Adirelle's oUF layout
(c) 2009-2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]=]
local UnitClass = UnitClass
local UnitName = UnitName
local GetTime = GetTime
local strformat = string.format
local strsub = string.sub
local mmin = math.min
local mmax = math.max
local abs = math.abs
local tostring = tostring
local unpack = unpack

-- Use our own namespace
setfenv(1, _G.oUF_Adirelle)

SCALE = 1.0
WIDTH = 80
SPACING = 2
HEIGHT = 25
BORDER_WIDTH = 1
ICON_SIZE = 14

local borderBackdrop = { edgeFile = [[Interface\Addons\oUF_Adirelle\media\white16x16]], edgeSize = BORDER_WIDTH }

-- ------------------------------------------------------------------------------
-- Health bar and name updates
-- ------------------------------------------------------------------------------

-- Return the truncated name of unit
local function GetShortUnitName(unit)
	return unit and strsub(tostring(UnitName(unit)),1,10) or UNKNOWN
end

-- Health point formatting
local function SmartHPValue(value)
	if abs(value) >= 1000 then
		return strformat("%.1fk",value/1000)
	else
		return strformat("%d", value)
	end
end

-- Update name
local function UpdateName(self)
	local healthBar = self.Health
	local r, g, b = 0.5, 0.5, 0.5
	if self.nameColor then
		r, g, b = unpack(self.nameColor)
	end
	local text
	local healBar = self.IncomingHeal
	if healBar then
		local max = healBar.max
		if max > 0 then
			local overHeal = healBar.current + healBar.incoming + healBar.incomingOthers - max
			local f = overHeal / max
			if f > 0.1 then
				r, g, b = 0, 1, 0
				if f > 0.3 then
					text = "+"..SmartHPValue(overHeal)
				end
			end
		end
	end
	self.Name:SetTextColor(r, g, b, 1)
	self.Name:SetText(text or GetShortUnitName(SecureButton_GetUnit(self) or self.unit))
end

-- Update name and health bar on health change
local function Health_Update(self, event, unit)
	if self.unit ~= unit then return end
	local bar, max = self.Health, UnitHealthMax(unit) or 0
	bar.unit, bar.disconnected = unit, not UnitIsConnected(unit)
	local current = (bar.disconnected or UnitIsDeadOrGhost(unit)) and max or UnitHealth(unit) or 0
	if current ~= bar.current or max ~= bar.max then
		bar.current, bar.max = current, max
		bar:SetMinMaxValues(0, max)
		bar:SetValue(current)
		if bar.PostUpdate then
			bar:PostUpdate(unit, current, max)
		end
		return UpdateName(self)
	end
end

local IncomingHeal_PostUpdate, Health_PostUpdate
if oUF.HasIncomingHeal then
	-- Update incoming heal display
	local function UpdateHealBar(bar, unit, current, max, incoming, incomingOthers)
		if bar.current ~= current or bar.max ~= max or bar.incoming ~= incoming or bar.incomingOthers ~= incomingOthers then
			bar.current, bar.max, bar.incoming, bar.incomingOthers = current, max, incoming, incomingOthers
			local health = bar:GetParent()
			local self = health:GetParent()
			if max == 0 or current >= max then
				bar:Hide()
				self.IncomingOthersHeal:Hide()
				return
			end
			local pixelPerHP = health:GetWidth() / max
			if incomingOthers > 0 then
				local othersBar = self.IncomingOthersHeal
				local newCurrent = math.min(current + incomingOthers, max)
				othersBar:SetPoint('LEFT', health, 'LEFT', current * pixelPerHP, 0)
				othersBar:SetWidth((newCurrent-current) * pixelPerHP)
				othersBar:Show()
				current = newCurrent
			else
				self.IncomingOthersHeal:Hide()
			end
			if incoming > 0 and current < max then
				bar:SetPoint('LEFT', health, 'LEFT', current * pixelPerHP, 0)
				bar:SetWidth(math.min(max-current, incoming) * pixelPerHP)
				bar:Show()
			else
				bar:Hide()
			end
		end
	end

	function IncomingHeal_PostUpdate(bar, event, unit, incoming, incomingOthers)
		UpdateHealBar(bar, unit, bar.current, bar.max, incoming or 0, incomingOthers or 0)
		return UpdateName(bar:GetParent():GetParent())
	end

	function Health_PostUpdate(health, unit, current, max)
		local bar = health:GetParent().IncomingHeal
		return UpdateHealBar(bar, unit, current, max, bar.incoming, bar.incomingOthers)
	end
end

-- Update health and name color
local function UpdateColor(self, event, unit)
	if unit and unit ~= self.unit then return end
	local refUnit = (self.realUnit or self.unit):gsub('pet', '')
	if refUnit == '' then refUnit = 'player' end -- 'pet'
	local class = UnitName(refUnit) ~= UNKNOWN and select(2, UnitClass(refUnit))
	local state = oUF_Adirelle.GetFrameUnitState(self, true) or class or ""
	if state ~= self.__stateColor then
		self.__stateColor = state
		local r, g, b = 0.5, 0.5, 0.5
		if class then
			r, g, b = unpack(self.colors.class[class])
		end
		local nR, nG, nB = r, g, b
		if state == "DEAD" or state == "DISCONNECTED" then
			r, g, b = unpack(self.colors.disconnected)
		elseif state == "CHARMED" then
			r, g, b, nR, nG, nB = 1, 0, 0, 1, 0.6, 0.3
		elseif state == "INVEHICLE" then
			r, g, b, nR, nG, nB = 0.2, 0.6, 0, 0.4, 0.8, 0.2
		end
		self.bgColor[1], self.bgColor[2], self.bgColor[3] = r, g, b
		self.Health.bg:SetVertexColor(r, g, b, 1)
		self.nameColor[1], self.nameColor[2], self.nameColor[3] = nR, nG, nB
	end
	return UpdateName(self)
end

-- Add a pseudo-element to update the color
oUF:AddElement('Adirelle_Raid:UpdateColor',
	UpdateColor,
	function(self)
		if self.Health and self.bgColor and self.style == "Adirelle_Raid" then
			self:RegisterEvent('UNIT_NAME_UPDATE', UpdateColor)
			self:RegisterEvent('RAID_ROSTER_UPDATE', UpdateColor)
			self:RegisterEvent('PARTY_MEMBERS_CHANGED', UpdateColor)
			return true
		end
	end,
	function() end
)

-- Statusbar texturing
local function HealthBar_PostTextureUpdate(self)
	self:SetStatusBarColor(0, 0, 0, 0.75)
end

-- Layout internal frames on size change
local function OnSizeChanged(self, width, height)
	width = width or self:GetWidth()
	height = height or self:GetHeight()
	self.Border:SetWidth(width + 2 * BORDER_WIDTH)
	self.Border:SetHeight(height + 2 * BORDER_WIDTH)
	self.ReadyCheck:SetWidth(height)
	self.ReadyCheck:SetHeight(height)
	if self.DeathIcon then
		self.DeathIcon:SetWidth(height*2)
		self.DeathIcon:SetHeight(height)
	end
	if self.StatusIcon then
		self.StatusIcon:SetWidth(height*2)
		self.StatusIcon:SetHeight(height)
	end
end

-- ------------------------------------------------------------------------------
-- Aura icon initialization
-- ------------------------------------------------------------------------------

local CreateClassAuraIcons
do
	local INSET, SMALL_ICON_SIZE = 1, 8
	local function SpawnSmallIcon(self, ...) return self:CreateIcon(self.Overlay, SMALL_ICON_SIZE, true, true, true, false, ...)	end

	-- Create the specific icons depending on player class
	if playerClass == "DRUID" then
		function CreateClassAuraIcons(self)
			-- Rejuvenation
			self:AddAuraIcon(
				SpawnSmallIcon(self, "TOPLEFT", self, "TOPLEFT", INSET, -INSET),
				GetOwnAuraFilter(774, 0.6, 0, 1)
			)
			-- Regrowth
			self:AddAuraIcon(
				SpawnSmallIcon(self, "TOP", self, "TOP", 0, -INSET),
				GetOwnAuraFilter(8936, 0, 0.6, 0)
			)
			-- Lifebloom
			for i = 1, 3 do
				self:AddAuraIcon(
					SpawnSmallIcon(self, "TOPRIGHT", self, "TOPRIGHT", -INSET - SMALL_ICON_SIZE*(i-1), -INSET),
					GetOwnStackedAuraFilter(33763, i, 0, 1, 0)
				).blinkThreshold = 4
			end
			-- Wild Growth
			self:AddAuraIcon(
				SpawnSmallIcon(self, "BOTTOMLEFT", self, "BOTTOMLEFT", INSET, INSET),
				GetOwnAuraFilter(48438, 0, 1, 0)
			)
		end

	elseif playerClass == 'PALADIN' then
		function CreateClassAuraIcons(self)
			-- Beacon of light
			self:AddAuraIcon(
				SpawnSmallIcon(self, "TOPRIGHT", self, "TOPRIGHT", -INSET, -INSET),
				GetOwnAuraFilter(53563)
			)
		end

	elseif playerClass == "SHAMAN" then
		function CreateClassAuraIcons(self)
			-- Earth Shield
			for i = 1, 6 do
				self:AddAuraIcon(
					SpawnSmallIcon(self, "BOTTOMRIGHT", self, "BOTTOMRIGHT", -INSET - SMALL_ICON_SIZE*(i-1), INSET),
					GetOwnStackedAuraFilter(974, i)
				)
			end
			-- Riptide
			self:AddAuraIcon(
				SpawnSmallIcon(self, "TOPRIGHT", self, "TOPRIGHT", -INSET, -INSET),
				GetOwnAuraFilter(61295)
			)
		end

	elseif playerClass == 'WARLOCK' then
		function CreateClassAuraIcons(self)
			-- Soulstones
			self:AddAuraIcon(SpawnSmallIcon(self, "BOTTOMLEFT", self, "BOTTOMLEFT", INSET, INSET), GetAnyAuraFilter(20707, "HELPFUL"))
			-- Dark intents
			self:AddAuraIcon(SpawnSmallIcon(self, "BOTTOMRIGHT", self, "BOTTOMRIGHT", -INSET, INSET), GetAnyAuraFilter(80398, "HELPFUL"))
		end

	elseif playerClass == 'MAGE' then
		function CreateClassAuraIcons(self)
			-- Focus magic
			self:AddAuraIcon(SpawnSmallIcon(self, "BOTTOMRIGHT", self, "BOTTOMRIGHT", -INSET, INSET), GetAnyAuraFilter(54646, "HELPFUL"))
		end

	elseif playerClass == 'PRIEST' then
		function CreateClassAuraIcons(self)
			-- PW:Shield or Weakened Soul
			self:AddAuraIcon(
				SpawnSmallIcon(self, "TOPLEFT", self, "TOPLEFT", INSET, -INSET),
				"PW:Shield"
			)
			-- Renew
			self:AddAuraIcon(
				SpawnSmallIcon(self, "TOPRIGHT", self, "TOPRIGHT", -INSET, -INSET),
				GetOwnAuraFilter(139)
			).blinkThreshold = 4
			-- Prayer of Mending
			self:AddAuraIcon(
				SpawnSmallIcon(self, "BOTTOMRIGHT", self, "BOTTOMRIGHT", -INSET, INSET),
				GetOwnAuraFilter(33076)
			)
			-- Lightwell Renew
			self:AddAuraIcon(
				SpawnSmallIcon(self, "BOTTOMLEFT", self, "BOTTOMLEFT", INSET, INSET),
				GetOwnAuraFilter(7001)
			)
		end

	end
end

-- ------------------------------------------------------------------------------
-- Alternate Power Bar
-- ------------------------------------------------------------------------------

local function AltPowerBar_Update(bar, min, cur, max)
	local unit = bar.__owner.unit
	if not unit then return end
	local _, powerRed, powerGreen, powerBlue = UnitAlternatePowerTextureInfo(unit, 2)
	local r, g, b = oUF.ColorGradient((cur-min)/(max-min), powerRed, powerGreen, powerBlue, 1, 0, 0)
	local c = bar.textureColor
	if c[1] ~= r or c[2] ~= g or c[3] ~= b then
		c[1], c[2], c[3] = r, g, b
		bar:SetStatusBarColor(r, g, b)
	end
end

local function AltPowerBar_Layout(bar)
	local self = bar.__owner
	if bar:IsShown() then
		self.Health:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 0)
	else
		self.Health:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
	end
end

-- ------------------------------------------------------------------------------
-- Unit frame initialization
-- ------------------------------------------------------------------------------

local function UNIT_NAME_UPDATE(self, event, unit)
	if unit == self.unit or unit == self.realUnit then
		return UpdateName(self)
	end
end

local function UNIT_PET(self, event, unit)
	if unit == "player" then
		return UNIT_NAME_UPDATE(self, event, "pet")
	elseif unit then
		return UNIT_NAME_UPDATE(self, event, gsub(unit, "(%d*)$", "pet%1"))
	end
end

local function InitFrame(self, unit)
	self:RegisterForClicks("AnyDown")

	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)

	self:SetBackdrop(backdrop)
	self:SetBackdropColor(0, 0, 0, backdrop.bgAlpha)
	self:SetBackdropBorderColor(0, 0, 0, 1)

	-- Health bar
	local hp = CreateFrame("StatusBar", nil, self)
	hp.Update = Health_Update
	hp.current, hp.max = 0, 0
	hp:SetPoint("TOPLEFT")
	hp:SetPoint("BOTTOMRIGHT")
	hp.frequentUpdates = true
	self:RegisterStatusBarTexture(hp, HealthBar_PostTextureUpdate)
	self.Health = hp

	self.bgColor = { 1, 1, 1 }
	self.nameColor = { 1, 1, 1 }

	local hpbg = hp:CreateTexture(nil, "BACKGROUND", nil, -1)
	hpbg:SetAllPoints(hp)
	hpbg:SetAlpha(1)
	self:RegisterStatusBarTexture(hpbg)
	hp.bg = hpbg

	-- Incoming heals
	local heal = hp:CreateTexture(nil, "OVERLAY")
	heal:SetTexture(0, 1, 0, 0.5)
	heal:SetBlendMode("BLEND")
	heal:SetPoint("TOP")
	heal:SetPoint("BOTTOM")
	heal:Hide()
	heal.PostUpdate = IncomingHeal_PostUpdate
	heal.current, heal.max, heal.incoming, heal.incomingOthers = 0, 0, 0, 0
	self.IncomingHeal = heal

	local othersHeal = hp:CreateTexture(nil, "OVERLAY")
	othersHeal:SetTexture(0.5, 0, 1, 0.5)
	othersHeal:SetBlendMode("BLEND")
	othersHeal:SetPoint("TOP")
	othersHeal:SetPoint("BOTTOM")
	othersHeal:Hide()
	self.IncomingOthersHeal = othersHeal

	hp.PostUpdate = Health_PostUpdate

	-- Indicator overlays
	local overlay = CreateFrame("Frame", nil, self)
	overlay:SetAllPoints(self)
	overlay:SetFrameLevel(hp:GetFrameLevel()+3)
	self.Overlay = overlay

	-- Name
	local name = overlay:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	name:SetAllPoints(self)
	name:SetJustifyH("CENTER")
	name:SetJustifyV("MIDDLE")
	name:SetFont(GameFontNormal:GetFont(), 11)
	name:SetTextColor(1, 1, 1, 1)
	self.Name = name
	self:RegisterEvent('UNIT_NAME_UPDATE', UNIT_NAME_UPDATE)
	if unit and strmatch(unit, 'pet') then
		self:RegisterEvent('UNIT_PET', UNIT_PET)
	end

	-- Border
	local border = CreateFrame("Frame", nil, self)
	border:SetFrameStrata("BACKGROUND")
	border:SetPoint("CENTER", self)
	border:SetWidth(WIDTH + 2 * BORDER_WIDTH)
	border:SetHeight(HEIGHT + 2 * BORDER_WIDTH)
	border:SetBackdrop(borderBackdrop)
	border:SetBackdropColor(0, 0, 0, 0)
	border:SetBackdropBorderColor(1, 1, 1, 1)
	border.SetColor = border.SetBackdropBorderColor
	border:Hide()
	self.Border = border

	-- Big status icon
	local status = hp:CreateTexture(nil, "OVERLAY", nil, 1)
	status:SetWidth(HEIGHT)
	status:SetHeight(HEIGHT)
	status:SetPoint("CENTER")
	status:SetAlpha(0.75)
	status:SetBlendMode("ADD")
	status:Hide()
	status.PostUpdate = UpdateColor
	self.StatusIcon = status

	-- ReadyCheck icon
	local rc = CreateFrame("Frame", self:GetName().."ReadyCheck", overlay)
	rc:SetFrameLevel(self:GetFrameLevel()+5)
	rc:SetPoint('CENTER', self)
	rc:SetWidth(HEIGHT)
	rc:SetHeight(HEIGHT)
	rc:SetAlpha(1)
	rc:Hide()
	rc.icon = rc:CreateTexture(rc:GetName().."Texture")
	rc.icon:SetAllPoints(rc)
	rc.SetTexture = function(_, ...) return rc.icon:SetTexture(...) end
	self.ReadyCheck = rc

	-- Have icons blinking 3 seconds before fading out
	self.iconBlinkThreshold = 3

	-- Important class buffs
	self.WarningIconBuff = self:CreateIcon(self.Overlay, ICON_SIZE, false, false, false, false, "CENTER", self, "LEFT", WIDTH * 0.25, 0)
	
	-- Cureable debuffs
	local debuff = self:CreateIcon(self.Overlay, ICON_SIZE, false, false, false, false, "CENTER")
	self:AddAuraIcon(debuff, "CureableDebuff")
	
	-- Important debuffs
	self.WarningIconDebuff = self:CreateIcon(self.Overlay, ICON_SIZE, false, false, false, false, "CENTER", self, "LEFT", WIDTH * 0.75, 0)

	-- Class-specific icons
	if CreateClassAuraIcons then
		CreateClassAuraIcons(self)
	end
		
	-- Threat glow
	local threat = CreateFrame("Frame", nil, self)
	threat:SetAllPoints(self)
	threat:SetBackdrop(glowBorderBackdrop)
	threat:SetBackdropColor(0,0,0,0)
	threat.SetVertexColor = threat.SetBackdropBorderColor
	threat:SetAlpha(glowBorderBackdrop.alpha)
	threat:SetFrameLevel(self:GetFrameLevel()+2)
	self.Threat = threat

	-- Role/Raid icon
	local roleIcon = overlay:CreateTexture(nil, "OVERLAY")
	roleIcon:SetWidth(8)
	roleIcon:SetHeight(8)
	roleIcon:SetPoint("LEFT", self, INSET, 0)
	roleIcon.noDamager = true
	roleIcon.noCircle = true
	self.RoleIcon = roleIcon

	-- Hook OnSizeChanged to layout internal on size change
	self:HookScript('OnSizeChanged', OnSizeChanged)

	-- LowHealth warning
	local lowHealth = hp:CreateTexture(nil, "OVERLAY")
	lowHealth:SetPoint("TOPLEFT", self, -2, 2)
	lowHealth:SetPoint("BOTTOMRIGHT", self, 2, -2)
	lowHealth:SetTexture(1, 0, 0, 0.5)
	self.LowHealth = lowHealth

	-- AltPowerBar
	local altPowerBar = CreateFrame("StatusBar", nil, self)
	altPowerBar:SetPoint("BOTTOMLEFT")
	altPowerBar:SetPoint("BOTTOMRIGHT")
	altPowerBar:SetHeight(4)
	altPowerBar:Hide()
	altPowerBar.textureColor = { 1, 1, 1, 1 }
	altPowerBar.showOthersAnyway = true
	altPowerBar.PostUpdate = AltPowerBar_Update
	altPowerBar:SetScript('OnShow', AltPowerBar_Layout)
	altPowerBar:SetScript('OnHide', AltPowerBar_Layout)
	altPowerBar:SetFrameLevel(threat:GetFrameLevel()+1)
	self:RegisterStatusBarTexture(altPowerBar)
	self.AltPowerBar = altPowerBar

	-- Range fading
	self.XRange = true
	self.inRangeAlpha = 1.0
	self.outsideRangeAlpha = 0.40
end

-- ------------------------------------------------------------------------------
-- Style and layout setup
-- ------------------------------------------------------------------------------

oUF:RegisterStyle("Adirelle_Raid", InitFrame)
