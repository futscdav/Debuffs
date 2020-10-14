local db = DebuffsDB or {};
local addon = Debuffs;
local print = print or nil;
local insert = table.insert;
local remove = table.remove;
local numel = table.getn;

addon.onLoadHandlers["DebuffDraw"] = function()
	addon.tooltip = {};
	addon.tooltip.lastUpdate = 0;
end

function Debuffs:ClearDebuffsFrame(frame)
	frame.otherFrame:Hide();
	for _, cdframe in ipairs(frame.cooldownFrames) do
		cdframe:Hide();
	end
end

function Debuffs:ClearOtherFrame(frame)
	frame.otherFrame:Hide();
end

function Debuffs:DrawConsolidatedDebuffs(debuffs, frame)
	local count = numel(debuffs);

	if next(debuffs) then
		frame.otherFrame:SetScript("OnEnter", addon.MakeComplexTooltipAndSetOnUpdate);
		frame.otherFrame:SetScript("OnLeave", addon.HideTooltipAndRemoveOnUpdate);
		frame.otherFrame:Show();
		if addon.settings[frame.unit].showOtherCount then
			frame.otherFrame.fontString:SetText(tostring(count));
		end
	elseif frame.IsOtherVisible() then
		frame.otherFrame:SetScript("OnEnter", addon.MakeComplexTooltipAndSetOnUpdate);
		frame.otherFrame:SetScript("OnLeave", addon.HideTooltipAndRemoveOnUpdate);
		frame.otherFrame:Show();
		if addon.settings[frame.unit].showOtherCount then
			frame.otherFrame.fontString:SetText(tostring(count));
		end
	elseif not frame.IsOtherVisible() then
		frame.otherFrame:SetScript("OnUpdate", nil);
		frame.otherFrame:Hide();
	end
end

function Debuffs:DrawExpandedDebuffs(debuffs, frame)

	if (not debuffs or not frame) then
		error("Expected arg #1 and arg #2");
	end

	local count = numel(debuffs);
	frame.lastFrameNumDebuffs = frame.lastFrameNumDebuffs or 0;

	local i = 1;
	local consolidated = nil;
	for _, debuff in ipairs(debuffs) do
		
		if (i > addon.settings[frame.unit].expandedPerRow * addon.settings[frame.unit].maxRows) then
			
		end

		local cdframe = frame.cooldownFrames[i];
		if cdframe == nil then
			consolidated = consolidated or {};
			--probably not allocated yet
			cdframe = self:AddCooldownFrame(frame);
			if not cdframe then
				insert(consolidated, debuff);
			end
		end
		
		if not consolidated then
		if debuff.durationless then

			local texture = cdframe.texture;
			texture:SetTexture(debuff.icon);
			cdframe.unit = debuff.unit;
			cdframe.index = debuff.index;
			texture:Show();
			local fs = cdframe.fontString;
			if debuff.stacks and debuff.stacks > 0 then
				fs:SetText(tostring(debuff.stacks));
				fs:Show();
			else
				fs:Hide();
			end
			cdframe:SetScript("OnEnter", addon.MakeSpellTooltipAndSetOnUpdate);
			cdframe:SetScript("OnLeave", addon.HideTooltipAndRemoveOnUpdate);
			cdframe:Show();
		else
			if (cdframe.cooldown.cooldownStart ~= debuff.start or cdframe.cooldown.cooldownDuration ~= debuff.duration or not cdframe:IsShown()) then
				--print("Setting " .. debuff.start .. " start, duration = " .. debuff.duration .. " left = " .. debuff.start + debuff.duration - GetTime());
				cdframe.cooldown:SetCooldown(debuff.start, debuff.duration);
				cdframe.cooldown.cooldownStart = debuff.start;
				cdframe.cooldown.cooldownDuration = debuff.duration;
				-- save the spell id so spell tooltip knows which spell to show
				cdframe.spellid = debuff.spellid;
				cdframe.unit = debuff.unit;
				cdframe.index = debuff.index;

				local texture = cdframe.texture;
				texture:SetTexture(debuff.icon);

				local fs = cdframe.fontString;
				if debuff.stacks and debuff.stacks > 0 then
					fs:SetText(tostring(debuff.stacks));
					fs:Show();
				else
					fs:Hide();
				end

				--if debuff.dispel == "Curse" then
				--	addon:SetBorderColor(cdframe, 5, 0, 5, 1);
				--else
				--	addon:SetBorderColor(cdframe, 0, 0, 0, 1);
				--end

				cdframe:SetScript("OnEnter", addon.MakeSpellTooltipAndSetOnUpdate);
				cdframe:SetScript("OnLeave", addon.HideTooltipAndRemoveOnUpdate);
				cdframe:Show();
			end
		end
		i = i + 1;
	end
	end
	
	local savedi = i;

	while i < frame.lastFrameNumDebuffs do
		local cdframe = frame.cooldownFrames[i];
		cdframe.cooldown.cooldownStart = 0;
		cdframe.cooldown.cooldownDuration = 0;
		cdframe:Hide();
		i = i + 1;
	end

	frame.lastFrameNumDebuffs = savedi;
	if consolidated then
		Debuffs:DrawConsolidatedDebuffs(consolidated, frame);
	end

end

-- Playing with game tooltip, because using lambda causes memory leaks..
function Debuffs.HideGameToolip(frame)
	GameTooltip:Hide();
end

function Debuffs.MakeSpellTooltipAndSetOnUpdate(frame)
	GameTooltip:SetOwner(frame, "ANCHOR_BOTTOMRIGHT");
	GameTooltip:SetParent(UIParent);

	addon.tooltip.unit = frame.unit;
	addon.tooltip.index = frame.index;
	addon.tooltip.spellid = frame.spellid;

	frame:SetScript("OnUpdate", addon.SpellTooltipOnUpdate);
end

function Debuffs.SpellTooltipOnUpdate(dtime)
	if (addon.tooltip.lastUpdate + 0.1 > GetTime()) then
		return;
	end
	addon.tooltip.lastUpdate = GetTime();

	if addon.testingMode then
		GameTooltip:SetSpellByID(addon.tooltip.spellid);
	else
		GameTooltip:SetUnitDebuff(addon.tooltip.unit, addon.tooltip.index);
	end

	GameTooltip:Show();
end

function Debuffs.MakeComplexTooltipAndSetOnUpdate(frame)
	GameTooltip:SetOwner(frame, "ANCHOR_BOTTOMRIGHT");
	GameTooltip:SetParent(UIParent);
	
	addon.tooltip.unit = frame.unit;
	
	frame:SetScript("OnUpdate", addon.ComplexTooltipOnUpdate);
end

function Debuffs.HideTooltipAndRemoveOnUpdate(frame)
	GameTooltip:Hide();
	frame:SetScript("OnUpdate", nil);
end

function Debuffs.ComplexTooltipOnUpdate(dtime)
	if (addon.tooltip.lastUpdate  + 0.1 > GetTime()) then 
		return;
	end
	addon.tooltip.lastUpdate = GetTime();

	GameTooltip:ClearLines();
	local debuffs = addon[addon.tooltip.unit].consolidated;
	addon:PopulateTooltip(debuffs, addon.tooltip.unit);
	-- recalculates size of tooltip
	GameTooltip:Show();																								   
end

function Debuffs:PopulateTooltip(debuffs)
	
	if not debuffs then
		error("Expected argument #1");
	end

	addon:SortDebuffsByRemaining(debuffs);
	
	--apparently there has to be a line before you can add textures
	local numDebuffs = numel(debuffs);
	local debuffString = " Other Debuff";
	if numDebuffs ~= 1 then
		debuffString = debuffString .. "s";
	end
	GameTooltip:AddLine(tostring(numDebuffs) .. debuffString);
	for _, debuff in ipairs(debuffs) do
		
		--consolidated debuffs are skipped
		if not debuff.consolidated then
			
			local casterName;
			if debuff.count and debuff.count > 1 then
				casterName = tostring(debuff.count) .. "x";
			else
				if not debuff.caster then
					casterName = "Unknown";
				else
					casterName = UnitName(debuff.caster);
				end
			end

			--convert time remaning
			local hours = debuff.remaining / (60 * 60);
			local minutes = (hours - floor(hours)) * 60;
			local seconds = (minutes - floor(minutes)) * 60;

			local timestring;
			if floor(hours) > 0 then
				timestring = tostring(floor(hours)) .. ":" .. string.format("%02d",floor(minutes)) .. ":" .. string.format("%02d",floor(seconds));
			elseif floor(minutes) > 0 then
				timestring = string.format("%02d", floor(minutes)) .. ":" .. string.format("%02d", floor(seconds));
			else
				timestring = string.format("%.0f", debuff.remaining);
			end

			if (casterName == nil) then
				casterName = "Unknown";
			end

			GameTooltip:AddDoubleLine(debuff.name .. " (" .. casterName .. ")", timestring, 1, 1, 1, 0.7, 0.9, 0.4); -- true for word wrap
			if debuff.icon then
				GameTooltip:AddTexture(debuff.icon);
			end
		end
	end
	GameTooltip:AddLine("");
	
end