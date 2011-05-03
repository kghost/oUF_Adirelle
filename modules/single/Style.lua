--[=[
Adirelle's oUF layout
(c) 2009-2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]=]

local _G, moduleName, private = _G, ...
local oUF_Adirelle, assert = _G.oUF_Adirelle, _G.assert
local oUF = assert(oUF_Adirelle.oUF, "oUF is undefined in oUF_Adirelle")

if oUF_Adirelle.SingleStyle then return end

-- Make most globals local so I can check global leaks using "luac -l | grep GLOBAL"
local CreateFrame = _G.CreateFrame
local InCombatLockdown, UnitAlternatePowerInfo = _G.InCombatLockdown, _G.UnitAlternatePowerInfo
local UnitAlternatePowerTextureInfo= _G.UnitAlternatePowerTextureInfo
local UnitAffectingCombat, UnitAura = _G.UnitAffectingCombat, _G.UnitAura
local UnitCanAssist, UnitCanAttack = _G.UnitCanAssist, _G.UnitCanAttack
local UnitClass, UnitIsConnected = _G.UnitClass, _G.UnitIsConnected
local UnitIsDeadOrGhost, UnitIsUnit = _G.UnitIsDeadOrGhost, _G.UnitIsUnit
local UnitFrame_OnEnter, UnitFrame_OnLeave = _G.UnitFrame_OnEnter, _G.UnitFrame_OnLeave
local ipairs, select, setmetatable = _G.ipairs, _G.select, _G.setmetatable
local gsub, strmatch, tinsert, unpack = _G.gsub, _G.strmatch, _G.tinsert, _G.unpack
local mmin, mmax, floor, sort, pairs = _G.min, _G.max, _G.floor, _G.table.sort, _G.pairs
local GameFontNormal = _G.GameFontNormal

local GAP, BORDER_WIDTH, TEXT_MARGIN = private.GAP, private.BORDER_WIDTH, private.TEXT_MARGIN
local FRAME_MARGIN, AURA_SIZE = private.FRAME_MARGIN, private.AURA_SIZE

local backdrop, glowBorderBackdrop = oUF_Adirelle.backdrop, oUF_Adirelle.glowBorderBackdrop

local borderBackdrop = { edgeFile = [[Interface\Addons\oUF_Adirelle\media\white16x16]], edgeSize = BORDER_WIDTH }

local SpawnTexture, SpawnText, SpawnStatusBar = private.SpawnTexture, private.SpawnText, private.SpawnStatusBar

local function UpdateHealBar(bar, unit, current, max, incoming)
	if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
		current, incoming  = 0, 0
	end
	if bar.incoming ~= incoming or bar.current ~= current or bar.max ~= max then
		bar.incoming, bar.current, bar.max = incoming, current, max
		local health = bar:GetParent()
		if current and max and incoming and incoming > 0 and max > 0 and current < max then
			local width = health:GetWidth()
			bar:SetPoint("LEFT", width * current / max, 0)
			bar:SetWidth(width * mmin(incoming, max-current) / max)
			bar:Show()
		else
			bar:Hide()
		end
	end
end

local function IncomingHeal_PostUpdate(bar, event, unit, incoming)
	return UpdateHealBar(bar, unit, bar.current, bar.max, incoming or 0)
end

local function Health_PostUpdate(healthBar, unit, current, max)
	local bar = healthBar:GetParent().IncomingHeal
	return UpdateHealBar(bar, unit, current, max, bar.incoming)
end

local function Auras_PostCreateIcon(icons, button)
	local cd, count, overlay = button.cd, button.count, button.overlay
	button.icon:SetTexCoord(5/64, 59/64, 5/64, 59/64)
	count:SetParent(cd)
	count:SetAllPoints(button)
	count:SetJustifyH("RIGHT")
	count:SetJustifyV("BOTTOM")
	overlay:SetParent(cd)
	overlay:SetTexture([[Interface\AddOns\oUF_Adirelle\media\icon_border]])
	overlay:SetTexCoord(0, 1, 0, 1)
	cd.noCooldownCount = true
	cd:SetReverse(true)
	cd:SetDrawEdge(true)
end

local function Auras_PostUpdateIcon(icons, unit, icon, index, offset)
	if not select(5, UnitAura(unit, index, icon.filter)) then
		icon.overlay:Hide()
	end
end

local LibDispellable = oUF_Adirelle.GetLib("LibDispellable-1.0")

local function IsMine(unit)
	return unit == "player" or unit == "vehicle" or unit == "pet"
end

local IsEncounterDebuff = oUF_Adirelle.IsEncounterDebuff

local canSteal = select(2, UnitClass("player")) == "MAGE"

local function Buffs_CustomFilter(icons, unit, icon, name, rank, texture, count, dtype, duration, timeLeft, caster, isStealable, shouldConsolidate, spellID, canApplyAura)
	if IsEncounterDebuff(spellID) then
		icon.bigger = true
	elseif UnitCanAttack("player", unit) then
		icon.bigger = (canSteal and isStealable) or LibDispellable:CanDispel(unit, true, dtype, spellID)
	elseif UnitCanAssist("player", unit) then
		icon.bigger = IsMine(caster)
		if UnitAffectingCombat("player") then
			return duration > 0 and (icon.bigger or canApplyAura or not shouldConsolidate)
		end
	else
		icon.bigger = false
	end
	return true
end

local function Debuffs_CustomFilter(icons, unit, icon, name, rank, texture, count, dtype, duration, timeLeft, caster, isStealable, shouldConsolidate, spellID, canApplyAura, isBossDebuff)
	if isBossDebuff or IsEncounterDebuff(spellID) or IsMine(caster) then
		icon.bigger = true
	elseif UnitCanAssist("player", unit) then
		icon.bigger = LibDispellable:CanDispel(unit, false, dtype, spellID)
	else
		icon.bigger = false
	end
	return true
end

local Auras_SetPosition
do
	local function CompareIcons(a, b)
		if a.bigger and not b.bigger then
			return true
		elseif not a.bigger and b.bigger then
			return false
		else
			return a:GetID() < b:GetID()
		end
	end

	function Auras_SetPosition(icons, numIcons)
		if not icons or numIcons == 0 then return end
		local spacing = icons.spacing or 1
		local size = icons.size or 16
		local anchor = icons.initialAnchor or "BOTTOMLEFT"
		local growthx = (icons["growth-x"] == "LEFT" and -1) or 1
		local growthy = (icons["growth-y"] == "DOWN" and -1) or 1
		local x = 0
		local y = 0
		local rowSize = 0
		local width = floor(icons:GetWidth() / size) * size
		local height = floor(icons:GetHeight() / size) * size

		sort(icons, CompareIcons)
		for i = 1, #icons do
			local button = icons[i]
			if button:IsShown() then
				local iconSize = button.bigger and size or size * 0.75
				rowSize = mmax(rowSize, iconSize)
				button:ClearAllPoints()
				button:SetWidth(iconSize)
				button:SetHeight(iconSize)
				button:SetPoint(anchor, icons, anchor, x * growthx, y * growthy)
				x = x + iconSize + spacing
				if x >= width then
					y = y + rowSize + spacing
					x = 0
					rowSize = 0
					if y >= height then
						for j = i+1, #icons do
							icons[j]:Hide()
						end
						return
					end
				end
			end
		end
	end
end

local function Auras_ForceUpdate(self, event, unit)
	if unit and unit ~= self.unit then return end
	if self.Buffs then
		self.Buffs:ForceUpdate()
	end
	if self.Debuffs then
		self.Debuffs:ForceUpdate()
	end
end

local function Power_PostUpdate(power, unit, min, max)
	if power.disconnected or UnitIsDeadOrGhost(unit) then
		power:SetValue(0)
	end
end

local function AltPowerBar_PostUpdate(bar, min, cur, max)
	local unit = bar.__owner.unit
	if not unit then return end
	bar.Label:SetText(select(10, UnitAlternatePowerInfo(unit)))
	local _, powerRed, powerGreen, powerBlue = UnitAlternatePowerTextureInfo(unit, 2)
	local r, g, b = oUF.ColorGradient((cur-min)/(max-min), powerRed, powerGreen, powerBlue, 1, 0, 0)
	bar:SetStatusBarColor(r, g, b)
end

-- Additional auxiliary bars
local function LayoutAuxiliaryBars(self)
	local bars = self.AuxiliaryBars
	local anchor = self
	for i, bar in ipairs(self.AuxiliaryBars) do
		if bar:IsShown() then
			bar:SetPoint("TOP", anchor, "BOTTOM", 0, -FRAME_MARGIN)
			anchor = bar
		end
	end
end

local function LayoutAuxiliaryBars_Hook(bar)
	 return LayoutAuxiliaryBars(bar.__mainFrame)
end

local function AddAuxiliaryBar(self, bar)
	if not self.AuxiliaryBars then
		self.AuxiliaryBars = {}
	end
	tinsert(self.AuxiliaryBars, bar)
	bar.__mainFrame = self
	bar:HookScript('OnShow', LayoutAuxiliaryBars_Hook)
	bar:HookScript('OnHide', LayoutAuxiliaryBars_Hook)
end

-- General bar layout
local function LayoutBars(self)
	local width, height = self:GetSize()
	if not width or not height or width == 0 or height == 0 then return end
	self.Border:SetWidth(width + 2 * BORDER_WIDTH)
	self.Border:SetHeight(height + 2 * BORDER_WIDTH)
	local portrait = self.Portrait
	if portrait then
		portrait:SetSize(height, height)
	end
	local power = self.Power
	if power then
		local totalPowerHeight = height * 0.45 - GAP
		local powerHeight = totalPowerHeight		
		if self.SecondaryPowerBar and self.SecondaryPowerBar:IsShown() then
			powerHeight = (totalPowerHeight - GAP) / 2	
		end
		power:SetHeight(powerHeight)
		height = height - totalPowerHeight - GAP
	end
	self.Health:SetHeight(height)
	if self.AuxiliaryBars then
		LayoutAuxiliaryBars(self)
	end
end

local function Element_Layout(element)
	return LayoutBars(element.__owner)
end

local function CastBar_Update(castbar)
	local self = castbar.__owner
	if castbar:IsVisible() then
		local height = castbar:GetHeight()
		if height then
			castbar.Icon:SetSize(height, height)
		end
		self.Power:Hide()
	else
		self.Power:Show()
	end
end

local function OnApplySettings(self, layout, theme, force, event)
	if force or event == 'OnThemeModified' then
		local health = self.Health
		for k,v in pairs(theme.Health) do
			health[k] = v
		end	
		if self.baseUnit == "arena" then
			health.colorSmooth = false
		end
		if self.Power then
			for k,v in pairs(theme.Power) do
				self.Power[k] = v
			end
		end
	end
	if force or event == 'OnColorChanged' then
		if self.LowHealth then
			self.LowHealth:SetTexture(unpack(oUF.colors.lowHealth, 1, 4))
		end
		if self.XRange then
			self.XRange:SetTexture(unpack(oUF.colors.outOfRange, 1, 3))
		end
		if self.IncomingHeal then
			self.IncomingHeal:SetTexture(unpack(oUF.colors.incomingHeal.self, 1, 4))
		end
		self.Health:ForceUpdate()
		if self.Power then
			self.Power:ForceUpdate()
		end
	end
end

local DRAGON_TEXTURES = {
	rare  = { [[Interface\Addons\oUF_Adirelle\media\rare_graphic]],  6/128, 123/128, 17/128, 112/128, },
	elite = { [[Interface\Addons\oUF_Adirelle\media\elite_graphic]], 6/128, 123/128, 17/128, 112/128, },
}

local function OoC_UnitFrame_OnEnter(...)
	if not InCombatLockdown() then return UnitFrame_OnEnter(...) end
end

local function InitFrame(settings, self, unit)
	local unit = gsub(unit or self.unit, "%d+", "")	
	local isArenaUnit = strmatch(unit, "arena")
	self.baseUnit, self.isArenaUnit = unit, isArenaUnit

	self:SetSize(settings['initial-width'], settings['initial-height'])

	self:RegisterForClicks("AnyDown")

	self:SetScript("OnEnter", OoC_UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)

	if self:CanChangeAttribute() then
		self:SetAttribute("type", "target")
	end

	private.SetupUnitDropdown(self, unit)

	self:SetBackdrop(backdrop)
	self:SetBackdropColor(0,0,0,backdrop.bgAlpha)
	self:SetBackdropBorderColor(0,0,0,0)

	-- Border
	local border = CreateFrame("Frame", nil, self)
	border:SetFrameStrata("BACKGROUND")
	border:SetPoint("CENTER", self)
	border:SetBackdrop(borderBackdrop)
	border:SetBackdropColor(0, 0, 0, 0)
	border:SetBackdropBorderColor(1, 1, 1, 1)
	border.SetColor = border.SetBackdropBorderColor
	border.blackByDefault = true
	border.noTarget = true
	self.Border = border

	local barContainer
	local left, right, dir = "LEFT", "RIGHT", 1
	if settings.mirroredFrame then
		left, right, dir = "RIGHT", "LEFT", -1
	end

	-- Portrait
	if not settings.noPortrait then
		-- Spawn the player model
		local portrait = CreateFrame("PlayerModel", nil, self)
		portrait:SetPoint(left)
		self.Portrait = portrait

		-- Create an icon displaying important debuffs (either PvP or PvE) all over the portrait
		local importantDebuff = self:CreateIcon(portrait)
		importantDebuff:SetAllPoints(portrait)
		local stack = importantDebuff.Stack
		stack:ClearAllPoints()
		stack:SetPoint("BOTTOMRIGHT", importantDebuff, -1, 1)
		importantDebuff.Stack:SetFont(GameFontNormal:GetFont(), 14, "OUTLINE")
		self.WarningIcon = importantDebuff

		-- Spawn a container frame that spans remaining space
		barContainer = CreateFrame("Frame", nil, self)
		barContainer:SetPoint("TOP"..left, portrait, "TOP"..right, GAP*dir, 0)
		barContainer:SetPoint("BOTTOM"..right)
	else
		barContainer = self
	end
	self.BarContainer = barContainer

	-- Health bar
	local health = SpawnStatusBar(self, false, "TOPLEFT", barContainer)
	health:SetPoint("TOPRIGHT", barContainer)
	health.frequentUpdates = true
	self.Health = health
	
	-- Name
	local name = SpawnText(health, "OVERLAY", "TOPLEFT", "TOPLEFT", TEXT_MARGIN)
	name:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT", TEXT_MARGIN)
	name:SetPoint("RIGHT", health.Text, "LEFT")
	self:Tag(name, (unit == "player" or unit == "pet" or unit == "boss" or isArenaUnit) and "[name]" or "[name][ <>status<>]")
	self.Name = name

	if unit ~= "boss" then
		-- Low health indicator
		local lowHealth = self:CreateTexture(nil, "OVERLAY")
		lowHealth:SetPoint("TOPLEFT", self, -2, 2)
		lowHealth:SetPoint("BOTTOMRIGHT", self, 2, -2)
		self.LowHealth = lowHealth
		
		-- Incoming heals
		local incomingHeal = health:CreateTexture(nil, "OVERLAY")
		incomingHeal:SetBlendMode("ADD")
		incomingHeal:SetPoint("TOP", health)
		incomingHeal:SetPoint("BOTTOM", health)
		incomingHeal.PostUpdate = IncomingHeal_PostUpdate
		incomingHeal.current, incomingHeal.max, incomingHeal.incoming = 0, 0, 0
		self.IncomingHeal = incomingHeal

		-- PostUpdate is only needed with incoming heals
		health.PostUpdate = Health_PostUpdate
	end

	-- Used for some overlays
	local indicators = CreateFrame("Frame", nil, self)
	indicators:SetAllPoints(self)
	indicators:SetFrameLevel(health:GetFrameLevel()+3)
	self.Indicators = indicators

	-- Power bar
	if not settings.noPower then
		local power = SpawnStatusBar(self, false, "TOPLEFT", health, "BOTTOMLEFT", 0, -GAP)
		power:SetPoint('RIGHT', barContainer)
		power.frequentUpdates = true
		power.PostUpdate = Power_PostUpdate
		self.Power = power

		if unit == "player" and private.SetupSecondaryPowerBar then
			-- Add player specific secondary power bar
			local bar = private.SetupSecondaryPowerBar(self)
			if bar then
				bar:SetPoint('TOPLEFT', self.Power, 'BOTTOMLEFT', 0, -GAP)
				bar:SetPoint('BOTTOMRIGHT', self.BarContainer)	
				bar.__owner = self
				bar:HookScript('OnShow', Element_Layout)
				bar:HookScript('OnHide', Element_Layout)
				self.SecondaryPowerBar = bar
			end
		end

		-- Unit level and class (or creature family)
		if unit ~= "player" and unit ~= "pet" then
			local classif = SpawnText(power, "OVERLAY")
			classif:SetPoint("TOPLEFT", self.Health, "BOTTOMLEFT", 0, -GAP)
			classif:SetPoint("BOTTOM", barContainer)
			classif:SetPoint("RIGHT", power.Text, "LEFT")
			self:Tag(classif, "[smartlevel][ >smartclass<]")
		end

		-- Casting Bar
		if unit ~= 'player' then
			local castbar = CreateFrame("StatusBar", nil, self)
			castbar:Hide()
			castbar.__owner = self
			castbar:SetPoint('BOTTOMRIGHT', power)
			castbar.PostCastStart = function() castbar:SetStatusBarColor(1.0, 0.7, 0.0) end
			castbar.PostChannelStart = function() castbar:SetStatusBarColor(0.0, 1.0, 0.0) end
			castbar:SetScript('OnSizeChanged', CastBar_Update)
			castbar:SetScript('OnShow', CastBar_Update)
			castbar:SetScript('OnHide', CastBar_Update)
			self:RegisterStatusBarTexture(castbar)
			self.Castbar = castbar

			local icon = castbar:CreateTexture(nil, "ARTWORK")
			icon:SetPoint('TOPLEFT', power)
			icon:SetTexCoord(4/64, 60/64, 4/64, 60/64)
			castbar.Icon = icon

			local spellText = SpawnText(castbar, "OVERLAY")
			spellText:SetPoint('TOPLEFT', castbar, 'TOPLEFT', TEXT_MARGIN, 0)
			spellText:SetPoint('BOTTOMRIGHT', castbar, 'BOTTOMRIGHT', -TEXT_MARGIN, 0)
			castbar.Text = spellText

			castbar:SetPoint("TOPLEFT", icon, "TOPRIGHT", GAP, 0)
			CastBar_Update(castbar)
		end
	end

	-- Threat Bar
	if unit == "target" then
		-- Add a simple threat bar on the target
		local threatBar = SpawnStatusBar(self, false)
		threatBar:SetBackdrop(backdrop)
		threatBar:SetBackdropColor(0,0,0,backdrop.bgAlpha)
		threatBar:SetBackdropBorderColor(0,0,0,1)
		threatBar:SetWidth(190*0.5)
		threatBar:SetHeight(14)
		threatBar:SetMinMaxValues(0, 100)
		threatBar.PostUpdate = function(self, event, unit, bar, isTanking, status, scaledPercent, rawPercent, threatValue)
			if not bar.Text then return end
			if threatValue then
				local value, unit = threatValue / 100, ""
				if value > 1000000 then
					value, unit = value / 1000000, "m"
				elseif value > 1000 then
					value, unit = value / 1000, "k"
				end
				bar.Text:SetFormattedText("%d%% (%.1f%s)", scaledPercent, value, unit)
				bar.Text:Show()
			else
				bar.Text:Hide()
			end
		end
		self.ThreatBar = threatBar
		AddAuxiliaryBar(self, threatBar)
	end

	-- Raid target icon
	self.RaidIcon = SpawnTexture(indicators, 16)
	self.RaidIcon:SetPoint("CENTER", barContainer)

	-- Threat glow
	local threat = CreateFrame("Frame", nil, self)
	threat:SetAllPoints(self.Border)
	threat:SetBackdrop(glowBorderBackdrop)
	threat:SetBackdropColor(0,0,0,0)
	threat.SetVertexColor = threat.SetBackdropBorderColor
	threat:SetAlpha(glowBorderBackdrop.alpha)
	threat:SetFrameLevel(self:GetFrameLevel()+2)
	self.SmartThreat = threat
		
	if unit ~= "boss" and not isArenaUnit then
		-- Various indicators
		self.Leader = SpawnTexture(indicators, 16, "TOP"..left)
		self.Assistant = SpawnTexture(indicators, 16, "TOP"..left)
		self.MasterLooter = SpawnTexture(indicators, 16, "TOP"..left, 16*dir)
		self.Combat = SpawnTexture(indicators, 16, "BOTTOM"..left)

		-- Indicators around the portrait, if there is one
		if self.Portrait then
			-- Group role icons
			self.RoleIcon = SpawnTexture(indicators, 16)
			self.RoleIcon:SetPoint("CENTER", self.Portrait, "TOP"..right)
			self.RoleIcon.noRaidTarget = true

			-- PvP flag
			local pvp = SpawnTexture(indicators, 16)
			pvp:SetTexCoord(0, 0.6, 0, 0.6)
			pvp:SetPoint("CENTER", self.Portrait, "BOTTOM"..right)
			self.PvP = pvp
				
			-- PvP timer
			if unit == "player" then
				local timer = CreateFrame("Frame", nil, indicators)
				timer:SetAllPoints(pvp)
				timer.text = SpawnText(timer, "OVERLAY")
				timer.text:SetPoint("CENTER", pvp)
				self.PvPTimer = timer
			end
		end
	end

	if unit == "player" then
		-- Player resting status
		self.Resting = SpawnTexture(indicators, 16, "BOTTOMLEFT")

	elseif unit == "target" then
		-- Combo points
		local DOT_SIZE = 10
		local cpoints = {}
		for i = 0, 4 do
			local cpoint = SpawnTexture(indicators, DOT_SIZE)
			cpoint:SetTexture([[Interface\AddOns\oUF_Adirelle\media\combo]])
			cpoint:SetTexCoord(3/16, 13/16, 5/16, 15/16)
			cpoint:SetPoint("LEFT", health, "BOTTOMLEFT", i*(DOT_SIZE+GAP), 0)
			cpoint:Hide()
			tinsert(cpoints, cpoint)
		end
		self.ComboPoints = cpoints
	end

	-- Auras
	local buffs, debuffs
	if unit == "pet" then
		buffs = CreateFrame("Frame", nil, self)
		buffs:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, FRAME_MARGIN)
		buffs.initialAnchor = "BOTTOMLEFT"
		buffs['growth-x'] = "RIGHT"
		buffs['growth-y'] = "UP"

	elseif unit == "target" or unit == "focus" or unit == "boss" or unit == "arena" then
		buffs = CreateFrame("Frame", nil, self)
		buffs:SetPoint("BOTTOM"..right, self, "BOTTOM"..left, -FRAME_MARGIN*dir, 0)
		buffs.showType = true
		buffs.initialAnchor = "BOTTOM"..right
		buffs['growth-x'] = left
		buffs['growth-y'] = "UP"

		debuffs = CreateFrame("Frame", nil, self)
		debuffs:SetPoint("TOP"..right, self, "TOP"..left, -FRAME_MARGIN*dir, 0)
		debuffs.showType = true
		debuffs.initialAnchor = "TOP"..right
		debuffs['growth-x'] = left
		debuffs['growth-y'] = "DOWN"
	end

	if buffs then
		buffs.size = AURA_SIZE
		buffs.num = 12
		buffs:SetWidth(AURA_SIZE * 12)
		buffs:SetHeight(AURA_SIZE)
		buffs.CustomFilter = Buffs_CustomFilter
		buffs.SetPosition = Auras_SetPosition
		buffs.PostCreateIcon = Auras_PostCreateIcon
		buffs.PostUpdateIcon = Auras_PostUpdateIcon
		self.Buffs = buffs
	end
	if debuffs then
		debuffs.size = AURA_SIZE
		debuffs.num = 12
		debuffs:SetWidth(AURA_SIZE * 12)
		debuffs:SetHeight(AURA_SIZE)
		debuffs.CustomFilter = Debuffs_CustomFilter
		debuffs.SetPosition = Auras_SetPosition
		debuffs.PostCreateIcon = Auras_PostCreateIcon
		debuffs.PostUpdateIcon = Auras_PostUpdateIcon
		self.Debuffs = debuffs
	end
	
	if buffs or debuffs then
		self:RegisterEvent('UNIT_FACTION', Auras_ForceUpdate)
		self:RegisterEvent('UNIT_TARGETABLE_CHANGED', Auras_ForceUpdate)
		self:RegisterEvent('PLAYER_REGEN_ENABLED', Auras_ForceUpdate)
		self:RegisterEvent('PLAYER_REGEN_DISABLED', Auras_ForceUpdate)
	end

	-- Classification dragon
	if unit == "target" or unit == "focus" or unit == "boss" then
		local dragon = indicators:CreateTexture(nil, "ARTWORK")
		local DRAGON_HEIGHT = 45*95/80+2
		dragon:SetWidth(DRAGON_HEIGHT*117/95)
		dragon:SetHeight(DRAGON_HEIGHT)
		dragon:SetPoint('TOPLEFT', self, 'TOPLEFT', -44*DRAGON_HEIGHT/95-1, 15*DRAGON_HEIGHT/95+1)
		dragon.elite = DRAGON_TEXTURES.elite
		dragon.rare = DRAGON_TEXTURES.rare
		self.Dragon = dragon
	end

	-- Experience Bar for player
	if unit == "player" then
		local xpFrame = CreateFrame("Frame", nil, self)
		xpFrame:SetPoint("TOP")
		xpFrame:SetPoint("RIGHT")
		xpFrame:SetHeight(12)
		xpFrame:SetBackdrop(backdrop)
		xpFrame:SetBackdropColor(0,0,0,backdrop.bgAlpha)
		xpFrame:SetBackdropBorderColor(0,0,0,1)
		xpFrame:EnableMouse(false)

		local xpBar = SpawnStatusBar(self, true)
		xpBar:SetParent(xpFrame)
		xpBar:SetAllPoints(xpFrame)
		xpBar.Show = function() return xpFrame:Show() end
		xpBar.Hide = function() return xpFrame:Hide() end
		xpBar.IsShown = function() return xpFrame:IsShown() end
		xpBar:EnableMouse(false)

		local restedBar = SpawnStatusBar(self, true)
		restedBar:SetParent(xpFrame)
		restedBar:SetAllPoints(xpFrame)
		restedBar:EnableMouse(false)

		local levelText = SpawnText(xpBar, "OVERLAY", "TOPLEFT", "TOPLEFT", TEXT_MARGIN, 0)
		levelText:SetPoint("BOTTOMLEFT", xpBar, "BOTTOMLEFT", TEXT_MARGIN, 0)

		local xpText = SpawnText(xpBar, "OVERLAY", "TOPRIGHT", "TOPRIGHT", -TEXT_MARGIN, 0)
		xpText:SetPoint("BOTTOMRIGHT", xpBar, "BOTTOMRIGHT", -TEXT_MARGIN, 0)
	
		local smartValue = private.smartValue
		xpBar.UpdateText = function(self, bar, current, max, rested, level)
			levelText:SetFormattedText(level)
			if rested and rested > 0 then
				xpText:SetFormattedText("%s(+%s)/%s", smartValue(current), smartValue(rested), smartValue(max))
			else
				xpText:SetFormattedText("%s/%s", smartValue(current), smartValue(max))
			end
		end

		xpBar.Rested = restedBar
		xpBar:SetFrameLevel(restedBar:GetFrameLevel()+1)

		self.ExperienceBar = xpBar
		AddAuxiliaryBar(self, xpFrame)
	end

	-- Range indicator
	if unit ~= "player" then
		local xrange = indicators:CreateTexture(nil, "BACKGROUND")
		xrange:SetAllPoints(self)
		xrange:SetTexture(0.4, 0.4, 0.4)
		xrange:SetBlendMode("MOD")
		self.XRange = xrange
		--self.XRange = true
	end

	-- Special events
	if unit == "boss" then
		self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", self.UpdateAllElements)
	end
	self:RegisterEvent("UNIT_TARGETABLE_CHANGED", function(_, event, unit)
		if unit == self.unit then return self:UpdateAllElements(event)	end
	end)

	-- Altenate power bar (e.g. sound on Atramedes, or poison on Isorath)
	if unit == "player" or unit == "target" then

		local altPowerBar = SpawnStatusBar(self)
		altPowerBar:SetBackdrop(backdrop)
		altPowerBar:SetBackdropColor(0,0,0,backdrop.bgAlpha)
		altPowerBar:SetBackdropBorderColor(0,0,0,1)
		altPowerBar:SetPoint("LEFT")
		altPowerBar:SetPoint("RIGHT")
		altPowerBar:SetHeight(12)
		altPowerBar.showOthersAnyway = true
		altPowerBar.textureColor = { 1, 1, 1, 1 }
		altPowerBar.PostUpdate = AltPowerBar_PostUpdate

		local label = SpawnText(altPowerBar, "OVERLAY", "TOPLEFT", "TOPLEFT", TEXT_MARGIN, 0)
		label:SetPoint("RIGHT", altPowerBar.Text, "LEFT", -TEXT_MARGIN, 0)
		altPowerBar.Label = label

		self.AltPowerBar = altPowerBar
		AddAuxiliaryBar(self, altPowerBar)
	end

	self.OnApplySettings = OnApplySettings
	
	-- Update layout at least once
	self:HookScript('OnSizeChanged', LayoutBars)
	LayoutBars(self)
end

local single_style = setmetatable({
	["initial-width"] = 190,
	["initial-height"] = 47,
}, {
	__call = InitFrame,
})

oUF:RegisterStyle("Adirelle_Single", single_style)

local single_style_right = setmetatable({
	mirroredFrame = true
}, {
	__call = InitFrame,
	__index = single_style,
})

oUF:RegisterStyle("Adirelle_Single_Right", single_style_right)

local single_style_health = setmetatable({
	["initial-height"] = 20,
	noPower = true,
	noPortrait = true
}, {
	__call = InitFrame,
	__index = single_style,
})

oUF:RegisterStyle("Adirelle_Single_Health", single_style_health)

oUF_Adirelle.SingleStyle = true
