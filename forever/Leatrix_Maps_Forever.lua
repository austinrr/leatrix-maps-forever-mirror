----------------------------------------------------------------------
-- Leatrix Maps: WoW Forever additions (this mirror's build only, not part of Leatrix Maps)
----------------------------------------------------------------------

-- Map data Leatrix Maps doesn't have yet, merged into its icon table at load.
-- Loaded after Leatrix_Maps_Icons.lua (forever/build.py adds it to the toc).
-- Each addition is skipped when Leatrix Maps' own data already has one like it,
-- so it retires itself once upstream catches up.
--
-- Sources:
--   Steamwheedle Port - Powderfuse Port boat serves both factions: OpenMap's Places.lua (MIT,
--     github.com/openmap-world/openmap, no faction restriction) and
--     wowforeveratlas.com/boat-routes-guide ("Both factions"). Leatrix Maps marks it Horde,
--     which hides it from the Alliance by default.
--   (Leatrix Maps 1.60.30 added the Forever dungeon entrances this file used to add.)

local void, Leatrix_Maps = ...
local L = Leatrix_Maps.L
local Icons = Leatrix_Maps["Icons"]
if not Icons then return end

local Forever = {}
Leatrix_Maps.Forever = Forever

----------------------------------------------------------------------
-- Matching (shared with Leatrix_Maps_Editor.lua)
----------------------------------------------------------------------

local DungeonKinds = {Dungeon = true, Raid = true, Dunraid = true}
local TravelKinds = {TravelA = true, TravelH = true, TravelN = true}

local function IsNear(row, x, y, radius)
	local dx, dy = row[2] - x, row[3] - y
	return dx * dx + dy * dy <= radius * radius
end

-- The first built-in row (Leatrix Maps' own, or one added by this file) on a map that
-- is the same marker as kind/x/y/target/name; markers placed with the editor don't count
function Forever.FindMatch(rows, kind, x, y, target, name)
	if not rows then return nil end
	for i = 1, #rows do
		local row = rows[i]
		if not row.leaMapsCustom then
			local k = row[1]
			if kind == "Arrow" then
				if k == "Arrow" and row[13] == target and IsNear(row, x, y, 8) then return row end
			elseif DungeonKinds[kind] then
				if DungeonKinds[k] and (IsNear(row, x, y, 5) or (name and row[4] == name)) then return row end
			elseif kind == "Spirit" then
				if k == "Spirit" and IsNear(row, x, y, 3) then return row end
			elseif TravelKinds[kind] then
				if TravelKinds[k] and row[13] == target and IsNear(row, x, y, 8) then return row end
			end
		end
	end
	return nil
end

----------------------------------------------------------------------
-- Tanaris - Riverglades boat: both factions
----------------------------------------------------------------------

local function MakeNeutral(mapID, target)
	local rows = Icons[mapID]
	if not rows then return end
	for i = 1, #rows do
		local row = rows[i]
		if (row[1] == "TravelH" or row[1] == "TravelA") and row[13] == target then
			row[1] = "TravelN"
		end
	end
end

MakeNeutral(2548, 1446)	-- Riverglades: boat to Tanaris
MakeNeutral(1446, 2548)	-- Tanaris: boat to Riverglades
