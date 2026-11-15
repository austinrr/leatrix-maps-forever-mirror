----------------------------------------------------------------------
-- Leatrix Maps: marker editor (this mirror's build only, not part of Leatrix Maps)
----------------------------------------------------------------------

-- Place your own zone crossings, spirit healers and dungeon entrances on the world map.
-- They're saved in LeaMapsForeverDB (WTF\Account\<account>\SavedVariables\Leatrix_Maps.lua)
-- and drawn by Leatrix Maps itself, exactly like its own icons (and shown or hidden by
-- the same settings). A marker retires itself when Leatrix Maps, or
-- Leatrix_Maps_Forever.lua, gains one like it.
--
--   /lmf edit     edit mode on or off: Alt-click the map to add a marker; drag one of yours to
--                 move it, click it to turn or delete it
--   /lmf export   your markers as Leatrix_Maps_Icons.lua rows, to copy
--   /lmf list     your markers per zone
--   /lmf purge    forget retired markers

local void, Leatrix_Maps = ...
local L = Leatrix_Maps.L
local Icons = Leatrix_Maps["Icons"]
local Forever = Leatrix_Maps.Forever
if not Icons or not Forever then return end

local Editor = {}
Forever.Editor = Editor

local DB					-- LeaMapsForeverDB, set at ADDON_LOADED
local editMode = false
local TURN = math.pi / 12	-- 15 degrees per click
local TWO_PI = 2 * math.pi

local function Print(msg)
	print("|cff69ccf0Leatrix Maps+|r: " .. msg)
end

local function Round1(v)
	return math.floor(v * 10 + 0.5) / 10
end

local function ZoneName(mapID)
	local info = mapID and C_Map.GetMapInfo(mapID)
	return info and info.name or ("Map " .. tostring(mapID))
end

----------------------------------------------------------------------
-- Markers and the rows Leatrix Maps draws for them
----------------------------------------------------------------------

-- A marker: {kind = "Arrow" | "Spirit" | "Dungeon", x, y (0-100), target (Arrow: map ID),
-- rot (Arrow: radians, counter-clockwise from up), name, minLevel, maxLevel (Dungeon), retired}

local EDIT_HINT = "|cff88ccffYour marker: drag to move, click to edit|r"

local function RowNote(m)
	if m.kind == "Dungeon" then
		return editMode and (L["Dungeon"] .. "|n" .. EDIT_HINT) or L["Dungeon"]
	end
	return editMode and EDIT_HINT or nil
end

local function BuildRow(m)
	local row
	if m.kind == "Arrow" then
		row = {"Arrow", m.x, m.y, ZoneName(m.target), nil, "Garr_LevelUpgradeArrow", nil, nil, nil, nil, nil, m.rot or 0, m.target}
	elseif m.kind == "Spirit" then
		row = {"Spirit", m.x, m.y, L["Spirit Healer"], nil, "Vehicle-TempleofKotmogu-GreenBall", nil, nil}
	elseif m.kind == "Dungeon" then
		row = {"Dungeon", m.x, m.y, m.name or L["Dungeon"], L["Dungeon"], "Dungeon", m.minLevel, m.maxLevel}
	end
	if row then
		row.leaMapsCustom = m
		row[5] = RowNote(m)
	end
	return row
end

local function Rows(mapID)
	local rows = Icons[mapID]
	if not rows then
		rows = {}
		Icons[mapID] = rows
	end
	return rows
end

local function InsertRow(mapID, m)
	local row = BuildRow(m)
	if row then
		local rows = Rows(mapID)
		rows[#rows + 1] = row
	end
	return row
end

local function RemoveRow(mapID, row)
	local rows = Icons[mapID]
	if not rows then return end
	for i = #rows, 1, -1 do
		if rows[i] == row then table.remove(rows, i) end
	end
end

local function CustomRows(mapID)
	local list = {}
	for _, row in ipairs(Icons[mapID] or {}) do
		if row.leaMapsCustom then list[#list + 1] = row end
	end
	return list
end

-- Edit mode adds a hint to your markers' tooltips
local function UpdateNotes()
	for _, rows in pairs(Icons) do
		for _, row in ipairs(rows) do
			if row.leaMapsCustom then row[5] = RowNote(row.leaMapsCustom) end
		end
	end
end

local function SaveMarker(mapID, m)
	DB.markers[mapID] = DB.markers[mapID] or {}
	table.insert(DB.markers[mapID], m)
end

local function ForgetMarker(mapID, m)
	local list = DB.markers[mapID]
	if not list then return end
	for i = #list, 1, -1 do
		if list[i] == m then table.remove(list, i) end
	end
	if #list == 0 then DB.markers[mapID] = nil end
end

-- Merge saved markers into Leatrix Maps' icons, retiring those it now has itself
local retiredAtLoad = 0
function Editor.Load()
	LeaMapsForeverDB = LeaMapsForeverDB or {}
	DB = LeaMapsForeverDB
	DB.markers = DB.markers or {}
	for mapID, list in pairs(DB.markers) do
		for _, m in ipairs(list) do
			if not m.retired then
				if Forever.FindMatch(Icons[mapID], m.kind, m.x, m.y, m.target, m.name) then
					m.retired = date("%Y-%m-%d")
					retiredAtLoad = retiredAtLoad + 1
				else
					InsertRow(mapID, m)
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Leatrix Maps' pins on the map
----------------------------------------------------------------------

-- Leatrix Maps makes its pins when the map changes. A new marker needs that; a moved,
-- turned or deleted one is changed on its pin directly.

local SyncHandles	-- (Drag handles, below)

-- Show the map's parent then the map again (C_Map.OpenWorldMap, as Leatrix Maps itself
-- uses, so the map isn't tainted); not in combat
local function RefreshMap()
	if not WorldMapFrame:IsShown() or InCombatLockdown() or not C_Map.OpenWorldMap then return false end
	local mapID = WorldMapFrame:GetMapID()
	local info = C_Map.GetMapInfo(mapID)
	local parent = info and info.parentMapID
	if not parent or parent == 0 then return false end
	C_Map.OpenWorldMap(parent)
	C_Timer.After(0, function()
		if WorldMapFrame:IsShown() and not InCombatLockdown() then C_Map.OpenWorldMap(mapID) end
	end)
	return true
end

local function FindPinFrame(row)
	for _, child in ipairs({WorldMapFrame:GetCanvas():GetChildren()}) do
		if child.isLeaMapsPin and child.data == row and child:IsShown() then return child end
	end
end

-- Match the pin to its row after a move or turn (as Leatrix Maps' SetupIcon and PositionPOI do)
local function UpdatePinFrame(row)
	local pin = FindPinFrame(row)
	if not pin then return end
	for _, tex in ipairs(pin.textures or {pin.Texture, pin.Highlight}) do
		tex:SetRotation(row[12] or 0)
	end
	local canvas = WorldMapFrame:GetCanvas()
	local scale = pin:GetScale()
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", canvas, "TOPLEFT", (canvas:GetWidth() * row[2] / 100) / scale, -(canvas:GetHeight() * row[3] / 100) / scale)
end

----------------------------------------------------------------------
-- Neighbouring zones and arrow direction
----------------------------------------------------------------------

-- A spot on mapID (0-100) in its parent map's coordinates (0-1)
local function OnParent(mapID, x, y)
	local info = C_Map.GetMapInfo(mapID)
	local parent = info and info.parentMapID
	if not parent or parent == 0 then return end
	local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(mapID, parent)
	if not minX then return end
	return parent, minX + (maxX - minX) * x / 100, minY + (maxY - minY) * y / 100
end

-- The parent map's zones nearest the spot, nearest first
local function NearbyZones(mapID, x, y, count)
	local parent, px, py = OnParent(mapID, x, y)
	if not parent then return {} end
	local zones = {}
	for _, child in ipairs(C_Map.GetMapChildrenInfo(parent, Enum.UIMapType.Zone) or {}) do
		if child.mapID ~= mapID then
			local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(child.mapID, parent)
			if minX then
				-- Distance to the zone's rectangle (0 inside it), then to its middle
				local ox = math.max(minX - px, 0, px - maxX)
				local oy = math.max(minY - py, 0, py - maxY)
				local cx, cy = (minX + maxX) / 2 - px, (minY + maxY) / 2 - py
				zones[#zones + 1] = {mapID = child.mapID, name = child.name, d = math.sqrt(ox * ox + oy * oy) * 10 + math.sqrt(cx * cx + cy * cy)}
			end
		end
	end
	table.sort(zones, function(a, b) return a.d < b.d end)
	while #zones > count do table.remove(zones) end
	return zones
end

-- Rotation pointing from the spot toward the target zone's middle
local function PointTowards(mapID, x, y, target)
	local parent, px, py = OnParent(mapID, x, y)
	if not parent then return 0 end
	local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(target, parent)
	if not minX then return 0 end
	local canvas = WorldMapFrame:GetCanvas()
	local aspect = canvas:GetWidth() / canvas:GetHeight()
	local dx, dy = ((minX + maxX) / 2 - px) * aspect, (minY + maxY) / 2 - py
	-- SetRotation turns counter-clockwise; 0 is up (north) and y grows downward
	local r = math.atan2(-dx, -dy)
	if r < 0 then r = r + TWO_PI end
	return Round1(r)
end

----------------------------------------------------------------------
-- Panel
----------------------------------------------------------------------

local panel, title, buttons, inputs, layoutY
local BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = {left = 4, right = 4, top = 4, bottom = 4},
}
local PANEL_WIDTH = 220

local function CreatePanel()
	panel = CreateFrame("Frame", nil, WorldMapFrame, "BackdropTemplate")
	panel:SetBackdrop(BACKDROP)
	panel:SetBackdropColor(0, 0, 0, 0.92)
	panel:SetFrameStrata("DIALOG")
	panel:SetToplevel(true)
	panel:EnableMouse(true)
	panel:SetClampedToScreen(true)
	panel:SetWidth(PANEL_WIDTH)
	panel:Hide()

	title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetPoint("TOPRIGHT", -10, -10)
	title:SetJustifyH("LEFT")

	buttons, inputs = {}, {}
	for i = 1, 3 do
		local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
		box:SetAutoFocus(false)
		box:SetHeight(20)
		box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		box.label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		box.label:SetPoint("BOTTOMLEFT", box, "TOPLEFT", -4, 1)
		box:Hide()
		box.label:Hide()
		inputs[i] = box
	end
end

local function ClearPanel(text)
	if not panel then CreatePanel() end
	for _, b in ipairs(buttons) do b:Hide() end
	for _, box in ipairs(inputs) do
		box:Hide()
		box.label:Hide()
		box:ClearFocus()
	end
	buttons.used, inputs.used = 0, 0
	title:SetText(text)
	layoutY = 32
end

-- A row of buttons: {{text, onClick}, ...}
local function AddButtons(list)
	local gap = 4
	local w = (PANEL_WIDTH - 20 - gap * (#list - 1)) / #list
	for i, def in ipairs(list) do
		buttons.used = buttons.used + 1
		local b = buttons[buttons.used]
		if not b then
			b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
			buttons[buttons.used] = b
		end
		b:SetSize(w, 22)
		b:SetText(def[1])
		b:SetScript("OnClick", def[2])
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", 10 + (i - 1) * (w + gap), -layoutY)
		b:Show()
	end
	layoutY = layoutY + 24
end

local function AddButton(text, onClick)
	AddButtons({{text, onClick}})
end

-- Text inputs side by side: {{label, width}, ...}; returns the boxes
local function AddInputs(list)
	layoutY = layoutY + 12
	local boxes, x = {}, 14
	for i, def in ipairs(list) do
		inputs.used = inputs.used + 1
		local box = inputs[inputs.used]
		box:SetWidth(def[2])
		box:ClearAllPoints()
		box:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -layoutY)
		box.label:SetText(def[1])
		box:SetText("")
		box:Show()
		box.label:Show()
		boxes[i] = box
		x = x + def[2] + 12
	end
	layoutY = layoutY + 28
	return boxes
end

local function ShowPanel()
	panel:SetHeight(layoutY + 8)
	local x, y = GetCursorPosition()
	local s = panel:GetEffectiveScale()
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s + 16, y / s - 8)
	panel:Show()
end

local function HidePanel()
	if panel then panel:Hide() end
end

----------------------------------------------------------------------
-- Adding and editing
----------------------------------------------------------------------

local ShowEditPanel

local function AddMarker(mapID, m)
	SaveMarker(mapID, m)
	local row = InsertRow(mapID, m)
	if not RefreshMap() then
		Print("Marker saved. It shows the next time this map opens.")
	end
	return row
end

local function ShowZonePicker(mapID, x, y)
	ClearPanel("Zone crossing to:")
	for _, zone in ipairs(NearbyZones(mapID, x, y, 8)) do
		AddButton(zone.name, function()
			local m = {kind = "Arrow", x = x, y = y, target = zone.mapID, rot = PointTowards(mapID, x, y, zone.mapID)}
			local row = AddMarker(mapID, m)
			ShowEditPanel(mapID, row)
		end)
	end
	AddButton(CANCEL, HidePanel)
	ShowPanel()
end

local function ShowDungeonForm(mapID, x, y)
	ClearPanel("Dungeon entrance")
	local name = AddInputs({{"Name", 180}})[1]
	local levels = AddInputs({{"Min level", 50}, {"Max level", 50}})
	local nameBox, minBox, maxBox = name, levels[1], levels[2]
	AddButtons({
		{SAVE, function()
			local text = strtrim(nameBox:GetText() or "")
			if text == "" then
				Print("The dungeon needs a name.")
				return
			end
			local m = {kind = "Dungeon", x = x, y = y, name = text, minLevel = tonumber(minBox:GetText()), maxLevel = tonumber(maxBox:GetText())}
			if m.minLevel and not m.maxLevel then m.maxLevel = m.minLevel end
			if m.maxLevel and not m.minLevel then m.minLevel = m.maxLevel end
			HidePanel()
			AddMarker(mapID, m)
		end},
		{CANCEL, HidePanel},
	})
	ShowPanel()
	nameBox:SetFocus()
end

local function ShowAddPanel(mapID, x, y)
	ClearPanel(format("Add marker at %.1f, %.1f", x, y))
	AddButton("Zone crossing...", function() ShowZonePicker(mapID, x, y) end)
	AddButton(L["Spirit Healer"], function()
		HidePanel()
		AddMarker(mapID, {kind = "Spirit", x = x, y = y})
	end)
	AddButton("Dungeon entrance...", function() ShowDungeonForm(mapID, x, y) end)
	AddButton(CANCEL, HidePanel)
	ShowPanel()
end

local function Turn(row, by)
	local m = row.leaMapsCustom
	m.rot = Round1(((m.rot or 0) + by) % TWO_PI)
	row[12] = m.rot
	UpdatePinFrame(row)
end

function ShowEditPanel(mapID, row)
	local m = row.leaMapsCustom
	local label = m.kind == "Arrow" and ("To " .. ZoneName(m.target)) or row[4]
	ClearPanel(format("%s (%.1f, %.1f)", label, m.x, m.y))
	if m.kind == "Arrow" then
		AddButtons({
			{"<< Turn", function() Turn(row, TURN) end},
			{"Turn >>", function() Turn(row, -TURN) end},
		})
	end
	AddButton(DELETE, function()
		ForgetMarker(mapID, m)
		RemoveRow(mapID, row)
		local pin = FindPinFrame(row)
		if pin then pin:Hide() end
		SyncHandles()
		HidePanel()
	end)
	AddButton(DONE, HidePanel)
	ShowPanel()
end

-- An Alt-click on the map (normalized position nx, ny on mapID)
local function OnAltClick(mapID, nx, ny)
	local info = mapID and C_Map.GetMapInfo(mapID)
	if not info or info.mapType < Enum.UIMapType.Zone then
		Print("Markers go on zone maps. Open a zone first.")
		return
	end
	if not nx or nx < 0 or nx > 1 or ny < 0 or ny > 1 then return end
	ShowAddPanel(mapID, Round1(nx * 100), Round1(ny * 100))
end

----------------------------------------------------------------------
-- Clicks: an Alt layer over the map, and a handle over each of your markers
----------------------------------------------------------------------

-- Clicks on the map itself would open the zone under the pointer (near a border, the next
-- zone) or, on an arrow, Leatrix Maps' click catcher would follow it. So in edit mode, while
-- Alt is held, an invisible frame of our own covers the map and takes the click, the way
-- Leatrix Maps' click catcher does for its pins. Without Alt the map works as usual.
local altLayer

-- In edit mode each of your markers gets an invisible handle over its pin (above the Alt
-- layer): drag it to move the marker, click it (left or right) to turn or delete it. The
-- handle has the mouse, so dragging moves the marker instead of panning the map.
local handles = {}
local dragging

local function FollowCursor(handle)
	local nx, ny = WorldMapFrame:GetNormalizedCursorPosition()
	if not nx then return end
	local row = handle.row
	row[2] = math.min(math.max(nx, 0), 1) * 100
	row[3] = math.min(math.max(ny, 0), 1) * 100
	UpdatePinFrame(row)
end

local function StopDrag(handle)
	if dragging ~= handle then return end
	dragging = nil
	handle:SetScript("OnUpdate", nil)
	local row = handle.row
	local m = row.leaMapsCustom
	m.x, m.y = Round1(row[2]), Round1(row[3])
	row[2], row[3] = m.x, m.y
	UpdatePinFrame(row)
end

local function CreateHandle()
	local h = CreateFrame("Button", nil, WorldMapFrame:GetCanvas())
	h:SetFrameStrata("HIGH")
	h:SetFrameLevel(120)	-- over Leatrix Maps' pins (100) and click catcher, and the Alt layer
	h:EnableMouse(true)
	h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	h:RegisterForDrag("LeftButton")
	h:SetScript("OnMouseDown", function(self) self.dragged = false end)
	h:SetScript("OnDragStart", function(self)
		if InCombatLockdown() then return end
		self.dragged = true
		HidePanel()
		dragging = self
		self:SetScript("OnUpdate", FollowCursor)
	end)
	h:SetScript("OnDragStop", StopDrag)
	h:SetScript("OnHide", StopDrag)
	h:SetScript("OnClick", function(self)
		if self.dragged or InCombatLockdown() then return end
		ShowEditPanel(self.mapID, self.row)
	end)
	return h
end

-- Put a handle over each of your markers' pins on the map shown (Leatrix Maps remakes its
-- pins when the map changes, so this runs often; it only changes handles that are wrong)
function SyncHandles()
	if dragging then return end
	local want = {}
	if editMode and WorldMapFrame:IsShown() and not InCombatLockdown() then
		local mapID = WorldMapFrame:GetMapID()
		for _, row in ipairs(CustomRows(mapID)) do
			local pin = FindPinFrame(row)
			if pin then want[#want + 1] = {row = row, pin = pin, mapID = mapID} end
		end
	end
	for i = 1, math.max(#want, #handles) do
		local w, h = want[i], handles[i]
		if w then
			if not h then
				h = CreateHandle()
				handles[i] = h
			end
			if h.row ~= w.row or h.pin ~= w.pin or not h:IsShown() then
				h.row, h.pin, h.mapID = w.row, w.pin, w.mapID
				h:ClearAllPoints()
				h:SetAllPoints(w.pin)
				h:Show()
			end
		elseif h and h:IsShown() then
			h:Hide()
			h.row, h.pin = nil, nil
		end
	end
end

local function InstallClickHooks()
	altLayer = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
	altLayer:SetAllPoints()
	altLayer:SetFrameStrata("HIGH")
	altLayer:SetFrameLevel(110)
	altLayer:EnableMouse(true)
	altLayer:Hide()
	altLayer:SetScript("OnMouseUp", function(self, button)
		if button ~= "LeftButton" or InCombatLockdown() then return end
		local nx, ny = WorldMapFrame:GetNormalizedCursorPosition()
		OnAltClick(WorldMapFrame:GetMapID(), nx, ny)
	end)

	-- While the map is open: the Alt layer follows the Alt key, the handles follow the pins
	local driver = CreateFrame("Frame", nil, WorldMapFrame)
	local elapsed = 0
	driver:SetScript("OnUpdate", function(self, delta)
		local alt = editMode and IsAltKeyDown() and not InCombatLockdown() and not dragging
		if alt ~= altLayer:IsShown() then altLayer:SetShown(alt) end
		elapsed = elapsed + delta
		if elapsed > 0.2 then
			elapsed = 0
			SyncHandles()
		end
	end)

	WorldMapFrame:HookScript("OnHide", function()
		HidePanel()
		SyncHandles()
	end)
end

----------------------------------------------------------------------
-- Edit mode
----------------------------------------------------------------------

local banner

local function UpdateBanner()
	if not banner then
		banner = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer, "BackdropTemplate")
		banner:SetBackdrop(BACKDROP)
		banner:SetBackdropColor(0, 0, 0, 0.8)
		banner:SetFrameStrata("HIGH")
		banner:SetFrameLevel(200)
		banner:SetPoint("TOP", 0, -8)
		banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		banner.text:SetPoint("CENTER")
		banner.text:SetText("Marker edit mode: Alt-click to add. Drag yours to move, click to edit.  (/lmf edit to stop)")
		banner:SetSize(banner.text:GetStringWidth() + 24, 28)
	end
	banner:SetShown(editMode)
end

local function SetEditMode(on)
	editMode = on
	if not on then HidePanel() end
	UpdateNotes()
	if WorldMapFrame then UpdateBanner() end
	if altLayer then SyncHandles() end
	Print(on and "Edit mode on. Open the map and Alt-click to add a marker." or "Edit mode off.")
end

----------------------------------------------------------------------
-- Export
----------------------------------------------------------------------

local function LuaString(s)
	return '"' .. tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function Num(v)
	return v and tostring(v) or "nil"
end

-- Your markers as rows in Leatrix_Maps_Icons.lua's format
function Editor.ExportText()
	local maps = {}
	for mapID, list in pairs(DB.markers) do
		local any = false
		for _, m in ipairs(list) do if not m.retired then any = true end end
		if any then maps[#maps + 1] = mapID end
	end
	table.sort(maps)
	local out = {}
	for _, mapID in ipairs(maps) do
		out[#out + 1] = format("--[[%s]] [%d] = {", ZoneName(mapID), mapID)
		for _, m in ipairs(DB.markers[mapID]) do
			if not m.retired then
				if m.kind == "Arrow" then
					out[#out + 1] = format('\t{"Arrow", %.1f, %.1f, L[%s], nil, arTex, nil, nil, nil, nil, nil, %.1f, %d},', m.x, m.y, LuaString(ZoneName(m.target)), m.rot or 0, m.target)
				elseif m.kind == "Spirit" then
					out[#out + 1] = format('\t{"Spirit", %.1f, %.1f, L["Spirit Healer"], nil, spTex, nil, nil},', m.x, m.y)
				elseif m.kind == "Dungeon" then
					out[#out + 1] = format('\t{"Dungeon", %.1f, %.1f, L[%s], L["Dungeon"], dnTex, %s, %s},', m.x, m.y, LuaString(m.name or "Dungeon"), Num(m.minLevel), Num(m.maxLevel))
				end
			end
		end
		out[#out + 1] = "},"
	end
	return table.concat(out, "\n")
end

local exportFrame

local function ShowExport()
	local text = Editor.ExportText()
	if text == "" then
		Print("You haven't placed any markers yet.")
		return
	end
	if not exportFrame then
		local f = CreateFrame("Frame", "LeaMapsForeverExportFrame", UIParent, "BackdropTemplate")
		f:SetBackdrop(BACKDROP)
		f:SetBackdropColor(0, 0, 0, 0.95)
		f:SetSize(640, 400)
		f:SetPoint("CENTER")
		f:SetFrameStrata("DIALOG")
		f:EnableMouse(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		tinsert(UISpecialFrames, "LeaMapsForeverExportFrame")

		local heading = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		heading:SetPoint("TOPLEFT", 12, -12)
		heading:SetText("Your markers (Ctrl-C to copy)")

		local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", -2, -2)

		local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 12, -34)
		scroll:SetPoint("BOTTOMRIGHT", -32, 12)

		local box = CreateFrame("EditBox", nil, scroll)
		box:SetMultiLine(true)
		box:SetAutoFocus(false)
		box:SetFontObject(ChatFontNormal)
		box:SetWidth(590)
		box:SetScript("OnEscapePressed", function() f:Hide() end)
		scroll:SetScrollChild(box)
		f.box = box
		exportFrame = f
	end
	exportFrame.box:SetText(text)
	exportFrame:Show()
	exportFrame.box:SetFocus()
	exportFrame.box:HighlightText()
end

----------------------------------------------------------------------
-- Slash command and events
----------------------------------------------------------------------

local function ListMarkers()
	local active, retired = 0, 0
	for mapID, list in pairs(DB.markers) do
		local a, r = 0, 0
		for _, m in ipairs(list) do
			if m.retired then r = r + 1 else a = a + 1 end
		end
		active, retired = active + a, retired + r
		Print(format("%s: %d marker(s)%s", ZoneName(mapID), a, r > 0 and format(", %d retired", r) or ""))
	end
	Print(format("%d marker(s), %d retired.", active, retired))
end

local function Purge()
	local n = 0
	for mapID, list in pairs(DB.markers) do
		for i = #list, 1, -1 do
			if list[i].retired then
				table.remove(list, i)
				n = n + 1
			end
		end
		if #list == 0 then DB.markers[mapID] = nil end
	end
	Print(format("Forgot %d retired marker(s).", n))
end

SLASH_LEAMAPSFOREVER1 = "/lmf"
SlashCmdList["LEAMAPSFOREVER"] = function(msg)
	if not DB then return end
	local cmd = strlower(strtrim(msg or ""))
	if cmd == "edit" then
		SetEditMode(not editMode)
	elseif cmd == "export" then
		ShowExport()
	elseif cmd == "list" then
		ListMarkers()
	elseif cmd == "purge" then
		Purge()
	else
		Print("/lmf edit (add markers: Alt-click the map), /lmf export, /lmf list, /lmf purge")
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == "Leatrix_Maps" then
		Editor.Load()
	elseif event == "PLAYER_LOGIN" then
		-- Hook the map's clicks once it first opens, after Leatrix Maps (set up at PLAYER_LOGIN) has
		local installed = false
		WorldMapFrame:HookScript("OnShow", function()
			if installed then return end
			installed = true
			InstallClickHooks()
			UpdateBanner()
		end)
		if retiredAtLoad > 0 then
			C_Timer.After(5, function()
				Print(format("%d of your markers are now in Leatrix Maps and were retired (/lmf list, /lmf purge).", retiredAtLoad))
			end)
		end
	end
end)
