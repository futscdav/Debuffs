Debuffs = {};
DebuffsDB = DebuffsDB or {};

--wont work here btw
local db = DebuffsDB or {};
local addon = Debuffs;
local print = print or nil;
local insert = table.insert;
local remove = table.remove;
local numel = table.getn;
local AddonName = 'Debuffs';

function Debuffs:FrameInit()
	Debuffs.frame = CreateFrame('Frame', 'DebuffsMainFrame', UIParent);
	-- Register for events here
	--Debuffs.frame:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED');
	Debuffs.frame:RegisterEvent('PLAYER_TARGET_CHANGED');
	Debuffs.frame:RegisterEvent('ADDON_LOADED');
	Debuffs.frame:RegisterEvent('UNIT_AURA');
	Debuffs.frame:SetScript("OnEvent", function(...) Debuffs:EventHandler(...) end);
	Debuffs.onLoadHandlers = {};
end

function Debuffs:Init()
	db = DebuffsDB;
	addon = Debuffs;
	
	-- is this testing mode?
	self.testingMode = false;
	-- load settings
	self.settings = LibStub("AceDB-3.0"):New("DebuffsDB", addon:CreateDefaultSettings(), true).profile;
	-- blacklist?
	self.blacklist = db.blacklist or {};

	-- create frames
	self.frames = {};
	--self:CreatePlayerFrame();
	self:CreateTargetFrame();
	self:SetNiceTooltip();
	Debuffs.frame:SetScript("OnUpdate", function(...) Debuffs:UpdateHandler(...) end);

	-- random shit
	dfr = CreateFrame("FRAME", nil, UIParent);
	dfr:SetSize(400, 400)
	local texture = dfr:CreateTexture();
	texture:SetTexture("Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_White")
	dfr.center = texture;
	texture:ClearAllPoints();
	texture:SetPoint("CENTER")
	texture:SetAlpha(1)
	texture:SetSize(20, 20)
	texture:SetVertexColor(1, 0, 0, 1)
	texture:SetDrawLayer("OVERLAY")

	local tex2 = dfr:CreateTexture();
	tex2:SetTexture("Interface\\PVPFrame\\Icons\\PVP-Banner-Emblem-68")
	dfr.tx = tex2;
	tex2:ClearAllPoints();
	tex2:SetPoint("CENTER")

	dfr:ClearAllPoints();
	dfr:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

	dfr:Hide();
end

function Debuffs:OnLoad()
	self:Init();
	self:CreateInterface();

	for name, handler in pairs(self.onLoadHandlers) do
		handler();
	end
end

local has_hook = false
function Debuffs:SetNiceTooltip()
	ran = true
	GameTooltip:SetBackdrop( { 
		bgFile = "Interface\\AddOns\\SharedMedia\\background\\smoke.tga", 
		edgeFile = "Interface\\AddOns\\SharedMedia\\border\\roth.tga", tile = false, tileSize = 0, edgeSize = 1, 
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	});
	ran = false
	GameTooltip:SetBackdropColor(0, 0, 0, 1);
	if not has_hook then
		hooksecurefunc(GameTooltip, "SetBackdrop", function() if not ran then addon:SetNiceTooltip() end end);
		has_hook = true
	end
end

function Debuffs:CreateDefaultSettings()
	local settings = {
		profile = {
			target = self:InitUnitSettings('target'),
		}
	}
	return settings;
end

function Debuffs:InitUnitSettings(unit)
	local settings = {
		playerExpandAll = true,
		paddingX = 1,
		paddingY = 1,
		border = 2,
		expandedPerRow = 5,
		maxRows = 2,

		framePositionX = 0,
		framePositionY = 0,

		expandedX = 32,
		expandedY = 32,
		otherX = 24,
		otherY = 24,

		ignoreShorterThan = 0,
		otherAlwaysVisible = true,
		showOtherCount = true,

		relativeTo = UIParent,
		relativePoint = "BOTTOMLEFT",
	}
	return settings;
end

function Debuffs:CreateTargetFrame()
	local unit = 'target';
	local settings = self.settings[unit];

	self[unit] = {};
	self[unit].expanded = {};
	self[unit].consolidated = {};

	local totalX = settings.expandedPerRow * settings.expandedX + settings.paddingX * (settings.expandedPerRow - 1);
	local totalY = settings.maxRows * settings.expandedY + settings.paddingY * (settings.maxRows - 1);

	self.targetUiFrame = CreateFrame('Frame', 'DebuffsTargetFrame', settings.relativeTo);
	self.frames[unit] = self.targetUiFrame;
	self.targetUiFrame:SetFrameStrata("MEDIUM");

	self.targetUiFrame:SetSize(totalX, totalY);
	Mixin(self.targetUiFrame, BackdropTemplateMixin)
	self.targetUiFrame:SetBackdrop( {bgFile = "Interface\\ChatFrame\\ChatFrameBackground", insets = {top = 0, left = 0, bottom = 0, right = 0}});
	self.targetUiFrame:SetBackdropColor(1, 1, 1, 0);
	self.targetUiFrame:Show();
	self.targetUiFrame:SetPoint(settings.relativePoint, relativeTo, "CENTER", settings.framePositionX, settings.framePositionY);
	--local p, rt, rp, x, y = self.targetUiFrame:GetPoint();
	--print("Spawning the frame at ", x, " ", y, p, rt, rp);	

	self.targetUiFrame.IsOtherVisible = function() if UnitExists(unit) and settings.otherAlwaysVisible then return true; end; return false; end;
	self.targetUiFrame.unit = unit;

	-- init cooldowns
	local frame = self.targetUiFrame;
	if (frame.cooldownFrames == nil) then
		frame.otherFrame = self:CreateOthersFrame(frame);
		frame.cooldownFrames = {};
	end
end

function Debuffs:CreateOthersFrame(frame)
	local otherFrame = CreateFrame("Frame", frame);
	local settings = self.settings[frame.unit];
	otherFrame:ClearAllPoints();
	otherFrame:SetSize(settings.otherX, settings.otherY);
	otherFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, -settings.otherY);

	otherFrame.texture = otherFrame:CreateTexture(nil);
	otherFrame.texture:SetAlpha(1);
	otherFrame.texture:SetTexture("Interface\\icons\\Spell_ChargePositive");
	otherFrame.texture:SetAllPoints(otherFrame);

	otherFrame.unit = frame.unit;
	otherFrame.fontString = addon:MakeFontString(otherFrame);
	return otherFrame;
end

function Debuffs:AddCooldownFrame(frame)
	if frame.cooldownFrames == nil then
		error("This frame probably shouldn't have cooldown frames");
	end
	
	local settings = self.settings[frame.unit];
	frame.xoffset = frame.xoffset or 0;
	frame.yoffset = frame.yoffset or 0;
	if numel(frame.cooldownFrames) == 0 then
		-- obviously offsets should reset to 0
		frame.xoffset = 0;
		frame.yoffset = 0;
	end

	local i = numel(frame.cooldownFrames) + 1;
	if i > settings.expandedPerRow * settings.maxRows then
		-- do not overallocate!
		return nil;
	end

	local rowLength = settings.expandedPerRow * settings.expandedX + settings.expandedPerRow * settings.paddingX;

	-- Frame itself
	frame.cooldownFrames[i] = CreateFrame("Frame", "Dbfs"..i, frame); 
	frame.cooldownFrames[i]:ClearAllPoints();
	frame.cooldownFrames[i]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", frame.xoffset, frame.yoffset);
	frame.cooldownFrames[i]:SetSize(settings.expandedX, settings.expandedY);

	-- Texture
	frame.cooldownFrames[i].texture = frame.cooldownFrames[i]:CreateTexture(nil);
	frame.cooldownFrames[i].texture:SetAlpha(1);
	frame.cooldownFrames[i].texture:SetAllPoints();
	frame.cooldownFrames[i].texture:SetDrawLayer("ARTWORK", -7);

	-- Border
	addon:MakeBorder(frame.cooldownFrames[i], settings.border);
	-- Stacks count
	frame.cooldownFrames[i].fontHelper = CreateFrame("Frame", "dummy", frame.cooldownFrames[i]);
	frame.cooldownFrames[i].fontHelper:SetFrameStrata("HIGH");
	frame.cooldownFrames[i].fontHelper:SetAllPoints();
	frame.cooldownFrames[i].fontString = addon:MakeFontString(frame.cooldownFrames[i].fontHelper);

	-- Cooldown
	frame.cooldownFrames[i].cooldown = CreateFrame("Cooldown", "Dbfs"..i, frame.cooldownFrames[i], "CooldownFrameTemplate"); 
	frame.cooldownFrames[i].cooldown:ClearAllPoints();
	frame.cooldownFrames[i].cooldown:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", frame.xoffset, frame.yoffset);
	frame.cooldownFrames[i].cooldown:SetSize(settings.expandedX, settings.expandedY);
	frame.cooldownFrames[i].cooldown:SetReverse(true);
	frame.cooldownFrames[i].cooldown:SetDrawEdge(false);
	--frame.cooldownFrames[i].cooldown:SetFrameStrata("MEDIUM");
	frame.cooldownFrames[i].cooldown.cooldownStart = 0;
	frame.cooldownFrames[i].cooldown.cooldownDuration = 0;

	-- set next offsets
	frame.xoffset = (frame.xoffset + settings.expandedX + settings.paddingX) % rowLength;
	if i % settings.expandedPerRow == 0 then
		frame.yoffset = frame.yoffset + settings.expandedY + settings.paddingY;
	end

	return frame.cooldownFrames[i];
end

function Debuffs:RedrawFrame(frame)
	local settings = self.settings[frame.unit];
	frame:SetPoint(settings.relativePoint, settings.relativeTo, "CENTER", settings.framePositionX, settings.framePositionY);
	local totalX = settings.expandedPerRow * settings.expandedX + settings.paddingX * (settings.expandedPerRow - 1);
	local totalY = settings.maxRows * settings.expandedY + settings.paddingY * (settings.maxRows - 1);
	frame:SetSize(totalX, totalY);
	if frame.cooldownFrames then
		-- should recollect, but hide should be ok
		for _, f in pairs(frame.cooldownFrames) do f:Hide() end;
		frame.cooldownFrames = {};
	end
	if frame.otherFrame then
		frame.otherFrame:Hide();
		frame.otherFrame = self:CreateOthersFrame(frame);
	end
end

function Debuffs:MakeFontString(frame)
	local fs = frame:CreateFontString();
	fs:SetFont("Fonts\\FRIZQT__.TTF", 11, "THICKOUTLINE");
	fs:ClearAllPoints();
	fs:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0);
	return fs;
end

function Debuffs:MakeBorder(frame, size)
	if size == 0 then
		return;
	end
	frame.borderTop = self:MakeBorderPart(frame, frame:GetWidth(), size, 0, 0); -- top
	frame.borderLeft = self:MakeBorderPart(frame, size, frame:GetHeight(), 0, 0); -- left
	frame.borderBottom = self:MakeBorderPart(frame, frame:GetWidth(), size, 0, -frame:GetHeight() + size); -- bottom
	frame.borderRight = self:MakeBorderPart(frame, size, frame:GetHeight(), frame:GetWidth() - size, 0); -- right
end

function Debuffs:MakeBorderPart(frame, x, y, xoff, yoff)
	local part = frame:CreateTexture(nil);
	part:SetTexture(0, 0, 0, 1);
	part:ClearAllPoints();
	part:SetPoint("TOPLEFT", frame, "TOPLEFT", xoff, yoff);
	part:SetSize(x, y);
	part:SetDrawLayer("ARTWORK", 7);
	return part;
end

function Debuffs:SetBorderColor(frame, r, g, b, a)
	if not frame.borderTop then
		-- error(frame .. " has no border.");
		-- this may happen if border size is 0
		return;
	end
	frame.borderTop:SetTexture(r, g, b, a);
	frame.borderLeft:SetTexture(r, g, b, a);
	frame.borderBottom:SetTexture(r, g, b, a);
	frame.borderRight:SetTexture(r, g, b, a);
end

function Debuffs:ToggleLock()
	if self.targetUiFrame:IsMovable() then
		self:Lock();
	else
		self:Unlock();
	end
end

function Debuffs:IsLocked()
	return not self.targetUiFrame:IsMovable();
end

function Debuffs:Unlock()
	self.targetUiFrame:SetBackdropColor(0.25, 0.25, 0.25, 0.5);
	self.targetUiFrame.fontString = self.targetUiFrame.fontString or self.targetUiFrame:CreateFontString();
	self.targetUiFrame.fontString:SetFont("Fonts\\FRIZQT__.TTF", 11, "THICKOUTLINE");
	self.targetUiFrame.fontString:SetText("Drag this frame to reposition Debuffs");
	self.targetUiFrame.fontString:Show();
	self.targetUiFrame.fontString:SetAllPoints();
	self.targetUiFrame:SetMovable(true);
	self.targetUiFrame:EnableMouse(true);
	self.targetUiFrame:RegisterForDrag("LeftButton");
	self.targetUiFrame:SetScript("OnDragStart", self.targetUiFrame.StartMoving);
	self.targetUiFrame:SetScript("OnDragStop", self.targetUiFrame.StopMovingOrSizing);
end

function Debuffs:Lock()
	self.targetUiFrame:SetBackdropColor(0.5, 0.5, 0.5, 0);
	self.targetUiFrame.fontString:Hide();
	self.targetUiFrame:SetMovable(false);
	self.targetUiFrame:EnableMouse(false);
	self.targetUiFrame:UnregisterEvent("OnDragStart");
	self.targetUiFrame:UnregisterEvent("OnDragStop");
	local settings = self.settings['target'];
	--local p, rt, rp, x, y = self.targetUiFrame:GetPoint();
	--print("Leaving the frame at ", x, " ", y, p, rt, rp);
	self.settings['target'].relativePoint, self.settings['target'].relativeTo, _, self.settings['target'].framePositionX, 
		self.settings['target'].framePositionY = self.targetUiFrame:GetPoint()
end

function Debuffs:IsTestingMode()
	return self.testingMode;
end

function Debuffs:ToggleTestingMode()
	self.testingMode = not self.testingMode;
end

function Debuffs:CombatEvent(...)
	--nothing here for now
end

-- in case there is something data specific
function Debuffs:DebuffComparator(a, b)
	return a.remaining < b.remaining;
end

function Debuffs.Comparator(a, b)
	return addon:DebuffComparator(a, b);
end

function Debuffs:SortDebuffsByRemaining(debuffs)
	table.sort(debuffs, Debuffs.Comparator);
end

function Debuffs:ConsolidateDebuffs(debuffs)
	
	for index, debuff in ipairs(debuffs) do
		local dbf = nil;
		index = index - 1;
		while index > 0 do
			if debuff.spellid == debuffs[index].spellid then
				dbf = debuffs[index];
			end
			index = index - 1;
		end
		if dbf then
			debuff.consolidated = true;
			dbf.count = dbf.count or 1;
			dbf.count = dbf.count + 1;
			if (debuff.remaining > dbf.remaining) then
				dbf.remaining = debuff.remaining;
			end
		end
	end

end

function Debuffs:TransformDebuffs(debuffs, unit)
	if self.settings[unit].playerExpandAll and UnitIsPlayer(unit) then
		-- throw all others into mine
		for index, debuff in ipairs(debuffs.other) do
			remove(debuffs.other, index);
			insert(debuffs.mine, debuff);
		end
	end

	return debuffs;
end

function Debuffs:TargetDebuffs()
	local unit = 'target';

	table.wipe(addon[unit].expanded);
	table.wipe(addon[unit].consolidated);

	if (UnitExists(unit)) then
		local dbfs = addon:GetDebuffs(unit);
		if addon.testingMode then
			addon:GetPhonyDebuffs(dbfs);
		end

		if addon.settings[unit].playerExpandAll and UnitIsPlayer(unit) then
			addon:ClearOtherFrame(addon.targetUiFrame);

			--Mine first!
			addon:DrawExpandedDebuffs(dbfs, addon.targetUiFrame);
		else
			
			for _, debuff in ipairs(dbfs) do
				if debuff.mine then
					insert(addon[unit].expanded, debuff);
				else
					insert(addon[unit].consolidated, debuff);
				end
			end

			addon:DrawExpandedDebuffs(addon[unit].expanded, addon.targetUiFrame);

			addon:ConsolidateDebuffs(addon[unit].consolidated);
			addon:DrawConsolidatedDebuffs(addon[unit].consolidated, addon.targetUiFrame);
		end
	else
		--hide target debuffs
		addon:ClearDebuffsFrame(addon.targetUiFrame);
	end
end

-- frame update handler
function Debuffs:UpdateHandler(self, dtime)
	
	addon.lastUpdate = addon.lastUpdate or 0;
	if (addon.lastUpdate + 0.1 > GetTime()) then
		return;
	end
	addon.lastUpdate = GetTime();
	
	-- Target
	addon:TargetDebuffs();
	-- Player
	-- Pet
	-- TargetOfTarget
	-- Boss1
	-- Boss2
	-- Boss3
end

function Debuffs:EventHandler(self, event, ...)
	if event == 'COMBAT_LOG_EVENT_UNFILTERED' then
		addon:CombatEvent(...);
		return;
	end
	
	if event == 'ADDON_LOADED' then
		local name = ...;
		if name == AddonName then
			addon:OnLoad();
		end
	end

	if event == 'PLAYER_TARGET_CHANGED' then
		-- force update
		addon.lastUpdate = 0;
	end

	if event == 'UNIT_AURA' then
		local unit = ...;
		if unit == "target" then
			--addon:UpdateAuras(unit);
		end
	end
end

Debuffs:FrameInit();