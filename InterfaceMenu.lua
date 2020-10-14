--wont work here btw
local db = DebuffsDB or {};
local addon = Debuffs;
local print = print or nil;
local insert = table.insert;
local remove = table.remove;
local numel = table.getn;

local AceConfig = LibStub("AceConfig-3.0");
local AceConfigDialog = LibStub("AceConfigDialog-3.0");

SLASH_DEBUFFS1 = "/debuffs";

function SlashCmdList.DEBUFFS(cmd, editbox)
	InterfaceOptionsFrame_OpenToCategory("Debuffs");
end

--entrypoint
function Debuffs:CreateInterface()
	AceConfig:RegisterOptionsTable("Debuffs", self:CreateOptionsTable());
	AceConfigDialog:AddToBlizOptions("Debuffs");
end

function Debuffs:CreateOptionsTable()
	local options = {
		name = "Debuffs",
        type = "group",
        childGroups = "tab",
        args = {
			general = self:GetOptionsTableForGeneral("General Settings", 1),
			target = self:GetOptionsTableForFrame("Target", 2, 'target'),
		},
	};
    return options;
end

function Debuffs:GetOptionsTableForGeneral(name, order)
	local options = {
		type = "group",
		order = order,
		name = name,
		args = {
			testMode = self:CreateToggle("Test Mode", 1, "Test debuff mode", function () return self:IsTestingMode(); end, function() self:ToggleTestingMode(); end),
		},
	}
	return options;
end

function Debuffs:GetOptionsTableForFrame(frameName, order, unit)
	local options = {
		type = "group",
		order = order,
		name = frameName,
		args = {
			playerToggle = self:CreateToggle("Expand players", 2, "Expands all debuffs on players", 
															function() return self.settings["target"].playerExpandAll; end, 
															function(info, value) self.settings["target"].playerExpandAll = value; end),
			
			toggleLock = self:CreateToggle("Locked", 1, "Lock/Unlock", 
															function() return self:IsLocked(); end, 
															function() self:ToggleLock(); end),
			
			alwaysOthers = self:CreateToggle("Other always on", 3, "Always show other debuffs (even if 0)", 
															function() return self.settings[unit].otherAlwaysVisible; end, 
															function(info, value) self.settings[unit].otherAlwaysVisible = value; end),
			
			positionX = self:CreateRange("Horizontal", 4, "Adjust horizontal position", -910, 910, 1, 
															function() return self.settings[unit].framePositionX; end,
															function(i, v) self.settings[unit].framePositionX = v; self:RedrawFrame(self.frames[unit]); end),

			positionY = self:CreateRange("Vertical", 5, "Adjust vertical position", -510, 510, 1, 
															function() return self.settings[unit].framePositionY; end,
															function(i, v) self.settings[unit].framePositionY = v; self:RedrawFrame(self.frames[unit]); end),

			expanded = self:CreateRange("Columns", 6, "Number of expanded debuffs per row", 1, 10, 1,
															function() return self.settings[unit].expandedPerRow; end,
															function(i, v) self.settings[unit].expandedPerRow = v; self:RedrawFrame(self.frames[unit]); end),

			maxRows = self:CreateRange("Maximum Rows", 7, "Maximum number of rows displayed, additional debuffs will be silently ignored!", 1, 10, 1,
															function() return self.settings[unit].maxRows; end,
															function(i, v) self.settings[unit].maxRows = v; self:RedrawFrame(self.frames[unit]); end),

			paddingX = self:CreateRange("Horizontal padding", 8, nil, 0, 5, 1,
															function() return self.settings[unit].paddingX; end,
															function(i, v) self.settings[unit].paddingX = v; self:RedrawFrame(self.frames[unit]); end),

			paddingY = self:CreateRange("Vertical padding", 9, nil, 0, 5, 1,
															function() return self.settings[unit].paddingY; end,
															function(i, v) self.settings[unit].paddingY = v; self:RedrawFrame(self.frames[unit]); end),

			expandedX = self:CreateRange("Expanded X size", 10, nil, 12, 64, 1,
															function() return self.settings[unit].expandedX; end,
															function(i, v) self.settings[unit].expandedX = v; self:RedrawFrame(self.frames[unit]); end),

			expandedY = self:CreateRange("Expanded Y size", 11, nil, 12, 64, 1,
															function() return self.settings[unit].expandedY; end,
															function(i, v) self.settings[unit].expandedY = v; self:RedrawFrame(self.frames[unit]); end),

			border = self:CreateRange("Border size", 12, "Thickness of the border surrounding expanded debuffs.", 0, 5, 1,
															function() return self.settings[unit].border; end,
															function(i, v) self.settings[unit].border = v; self:RedrawFrame(self.frames[unit]); end),

			otherX = self:CreateRange("Consolidated Y size", 13, nil, 6, 64, 1,
															function() return self.settings[unit].otherX; end,
															function(i, v) self.settings[unit].otherX = v; self:RedrawFrame(self.frames[unit]); end),

			otherY = self:CreateRange("Consolidated Y size", 14, nil, 6, 64, 1,
															function() return self.settings[unit].otherY; end,
															function(i, v) self.settings[unit].otherY = v; self:RedrawFrame(self.frames[unit]); end),

			otherCount = self:CreateToggle("Consolidated count", 15, "Show how many debuffs are under the consolidated icon.", 
															function() return self.settings[unit].showOtherCount; end, 
															function(i, v) self.settings[unit].showOtherCount = v; end),
		},
	}
	return options;
end

function Debuffs:CreateRange(name, order, desc, min, max, step, get, set)
	local range = {
		name = name,
		type = "range",
		order = order,
		desc = desc,
		get = get,
		set = set,
		min = min,
		max = max,
		step = step,
	}
	return range;
end

function Debuffs:CreateToggle(name, order, desc, get, set)
	local toggle = {
		name = name,
		type = "toggle",
		order = order,
		desc = desc,
		get = get,
		set = set,
	};
	return toggle;
end