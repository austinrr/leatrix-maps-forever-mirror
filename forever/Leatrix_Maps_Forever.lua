----------------------------------------------------------------------
-- Leatrix Maps: WoW Forever additions (this mirror's build only, not part of Leatrix Maps)
----------------------------------------------------------------------

-- Corrections to Leatrix Maps' icon table for WoW Forever, made at load.
-- Loaded after Leatrix_Maps_Icons.lua (forever/build.py adds it to the toc).
-- Each one changes or removes a row only while Leatrix Maps still has it, so it
-- does nothing once upstream catches up.
--
-- Sources:
--   Steamwheedle Port - Powderfuse Port boat serves both factions:
--     wowforeveratlas.com/boat-routes-guide ("Both factions"). Leatrix Maps marks it Horde,
--     which hides it from the Alliance by default. (OpenMap records no faction for any boat,
--     so it neither confirms nor contradicts this.)
--   No portals between Stormwind and Dalaran: seen in game (2026-11-15; neither end is there).
--     Reported missing from Stormwind: dtgre.com/2026/11/wow-forever-return-zephras-isle-alliance-portal-missing.html
--     (2026-11-09), us.forums.blizzard.com/en/wow/t/2385258.
--   Dungeon level ranges: OpenMap (MIT, github.com/openmap-world/openmap at 9ebb7d3,
--     OpenMap/Data/Forever/Places.lua), from the game's Group Finder (GroupFinderActivity:
--     MinLevel to MaxLevelSuggestion).
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

----------------------------------------------------------------------
-- Rows for things that aren't in the game
----------------------------------------------------------------------

local function Remove(mapID, kind, target)
	local rows = Icons[mapID]
	if not rows then return end
	for i = #rows, 1, -1 do
		if rows[i][1] == kind and rows[i][13] == target then
			table.remove(rows, i)
		end
	end
end

Remove(1453, "PortalA", 1416)	-- Stormwind City: portal to Dalaran (Alterac Mountains)
Remove(1416, "PortalA", 1453)	-- Alterac Mountains: Dalaran's portal to Stormwind

----------------------------------------------------------------------
-- Dungeon level ranges: the game's Group Finder ones (via OpenMap)
----------------------------------------------------------------------

local levels = {
	-- mapID, Leatrix Maps' name, min level, max level (only those that differ from Leatrix Maps')
	{1421, "Shadowfang Keep", 20, 30},
	{1453, "The Stockade", 24, 32},
	{1413, "Wailing Caverns", 15, 24},
	{1420, "Scarlet Monastery", 30, 46},	-- the span of its four wings (30-38, 33-41, 36-44, 38-46)
	{1444, "Dire Maul (East)", 54, 60},
	{1416, "City of Dalaran", 28, 35},
	{1434, "The Drowned City", 35, 42},
	{1445, "Alcaz Prison", 48, 55},
	{1437, "Excavation Site: Wetlands", 26, 33},
	{1458, "The Ruins of Lordaeron", 15, 22},
	{2548, "Krol'dok Stronghold", 40, 47},
	{1455, "The Hall of Thanes", 13, 20},
}

for _, d in ipairs(levels) do
	local name = L[d[2]]
	for _, row in ipairs(Icons[d[1]] or {}) do
		if (row[1] == "Dungeon" or row[1] == "Raid" or row[1] == "Dunraid") and row[4] == name then
			row[7], row[8] = d[3], d[4]
		end
	end
end
