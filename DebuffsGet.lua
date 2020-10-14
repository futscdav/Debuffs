local db = DebuffsDB or {};
local addon = Debuffs;
local print = print or nil;
local insert = table.insert;
local remove = table.remove;
local numel = table.getn;

addon.onLoadHandlers["DebuffsGet"] = function()
	--recycling tables
	addon.tableBin = {};
	addon.emptyDebuffs = {};
	addon.emptyDebuffs.mine = {};
	addon.emptyDebuffs.other = {};
end

-- Playing with tables, because garbage collection happens after fights...
function Debuffs:GetDebuffStruct()
	local last = numel(self.tableBin);
	if last > 0 then
		local t = self.tableBin[last];
		self.tableBin[last] = nil;
		return t;
	end
	-- have to allocate a new table here
	return {};
end

function Debuffs:ReleaseTables(metatable)
	for k, v in pairs(metatable) do
		table.wipe(v);
		insert(self.tableBin, v);
		metatable[k] = nil;
	end
end

function Debuffs:ReleaseTable(t)
	table.wipe(t)
	insert(self.tableBin, t)
end


function Debuffs:GetDebuffs(unit)

	local dbfs = addon.currentDebuffs or {};
	--saving garbage
	addon:ReleaseTables(dbfs);
	addon.currentDebuffs = dbfs;

	if (not UnitExists(unit)) then
		return dbfs;
	end

	local i = 1;
	while true do
		local name, icon, count, dispelType, duration, expires, caster, isStealable, shouldConsolidate,
		 spellID, canApplyAura, isBossDebuff, value1, value2, value3 = UnitDebuff(unit, i);

		-- all debuffs seen
		if (name == nil) then
			break;
		end

		--create dbf struct
		local dbf = addon:GetDebuffStruct();
		dbf.name = name;
		dbf.icon = icon;
		dbf.remaining = expires - GetTime();
		dbf.duration = duration;
		dbf.caster = caster;
		dbf.start = expires - duration;
		dbf.spellid = spellID;
		dbf.index = i;
		dbf.unit = unit;
		dbf.stacks = count;
		dbf.dispel = dispelType;
		dbf.durationless = expires == 0

		if (caster == 'player') then
			dbf.mine = true;
		else
			dbf.mine = false;
		end

		if not addon:Ignore(dbf, unit) then
			insert(dbfs, dbf);
		else
			addon:ReleaseTable(dbf);
		end

		i = i + 1;
	end

	return dbfs;
end

-- Get UnitDebuffs
function Debuffs:Ignore(debuff, unit)
	if debuff.duration < self.settings[unit].ignoreShorterThan then
		--return true;
	end
	return false;
end

function Debuffs:GetPhonyDebuffs(debuffs)	
	local okids = {605, 603, 77787, 1822, 2823};
	local badids = {115767, 119381, 52502, 770, 78144};
	for i, id in ipairs(okids) do
		local name, _, icon = GetSpellInfo(id);
		local dbf = addon:GetDebuffStruct();
		dbf.name = name;
		dbf.icon = icon;
		dbf.remaining = i;
		dbf.duration = i + 10;
		dbf.caster = 'player';
		dbf.start = GetTime() - (dbf.duration - dbf.remaining);
		dbf.spellid = id;
		dbf.dispel = "Curse";
		dbf.mine = true;
		dbf.durationless = false;
		insert(debuffs, dbf);
	end
	for i, id in ipairs(badids) do
		local name, _, icon = GetSpellInfo(id);
		local dbf = addon:GetDebuffStruct();
		dbf.name = name;
		dbf.icon = icon;
		dbf.remaining = i;
		dbf.duration = i + 10;
		dbf.caster = 'boss1';
		dbf.start = GetTime() - (dbf.duration - dbf.remaining);
		dbf.spellid = id;
		dbf.mine = false;
		dbf.durationless = false;
		insert(debuffs, dbf);
	end
end