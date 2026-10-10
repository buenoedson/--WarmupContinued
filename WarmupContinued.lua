-- Updated WarmUp by Cybeloras of Mal'Ganis. Uses debugprofile start/stop instead of GetTime because it seems that GetTime() is not updated during loading screens anymore.
-- Further updated by Phanx for WoW 6.x (https://github.com/phanx-wow/Warmup)
-- Addon forked by tomchapin to work with WoW 7.1
-- Forked by ZZumMallen for WoW 11.0 prepatch
-- Gemini (Google) - Updated for WoW 11.2.0 The War Within and renamed to WarmupContinued

local addonName = ...

---@type any
local bdTemplate = BackdropTemplateMixin and "BackdropTemplate"

local containerFrame = CreateFrame("Frame", "WarmupContinuedOutputFrame", UIParent, bdTemplate)
containerFrame:Hide()

local outputFrame = CreateFrame("ScrollingMessageFrame", "WarmupContinuedChatFrame", containerFrame, bdTemplate)
outputFrame:SetFontObject("ChatFontNormal")
outputFrame:SetMaxLines(512)
outputFrame:SetPoint("TOPLEFT", 12, -29)
outputFrame:SetPoint("BOTTOMRIGHT", -8, 12)
outputFrame:SetJustifyH("LEFT")

containerFrame:SetScript("OnShow", function(self)
	self:SetScript("OnShow", nil)

	self:SetPoint("LEFT", 50, 100)
	self:SetSize(525, 390)
	self:EnableMouse(true)
	self:SetMovable(true)
	self:SetClampedToScreen(true)
	self:RegisterForDrag("LeftButton")
	self:SetScript("OnDragStart", self.StartMoving)
	self:SetScript("OnDragStop", self.StopMovingOrSizing)

	self:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	self:SetBackdropColor(0, 0, 0)
	self:SetBackdropBorderColor(0.8, 0.8, 0.8)

	local bg = self:CreateTexture(nil, "BORDER")
	bg:SetPoint("BOTTOMLEFT", 5, 5)
	bg:SetPoint("TOPRIGHT", -5, -5)
	bg:SetAtlas("collections-background-tile")
	bg:SetAlpha(0.9)

	local close = CreateFrame("Button", nil, self, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT")
	close:SetScript("OnClick", function()
		self:Hide()
	end)

	local title = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 12, -2)
	title:SetPoint("RIGHT", close, "LEFT", -6, 0)
	title:SetHeight(close:GetHeight())
	title:SetJustifyH("LEFT")
	title:SetText("Warmup Continued")

	local div = self:CreateTexture(nil, "ARTWORK")
	div:SetPoint("TOPLEFT", 8, -26)
	div:SetPoint("TOPRIGHT", -8, -26)
	div:SetHeight(8)
	div:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")

	outputFrame:SetFading(false)
	outputFrame:EnableMouseWheel(true)
	outputFrame:SetScript("OnMouseWheel", function(self, delta)
		if IsControlKeyDown() then
			return delta > 0 and self:PageUp() or delta < 0 and self:PageDown()
		end
		local n = IsShiftKeyDown() and self:GetNumMessages() or 5
		if delta > 0 then
			for i = 1, n do
				self:ScrollUp()
			end
		elseif delta < 0 then
			for i = 1, n do
				self:ScrollDown()
			end
		end
	end)
end)

collectgarbage("stop")
collectgarbage("collect")
local initmem = collectgarbage("count")
local longesttime, biggestmem, totalmem, totalgarbage, mostgarbage, gctime = 0, 0, 0, 0, 0, 0
local totaltime = 0
local eventcounts = {}
local eventargs = {}
local threshtimes, threshmems = {1.0, 0.5, 0.1}, {1000, 500, 100}
local threshcolors = {"|cffff0000", "|cffff8000", "|cffffff80", "|cff80ff80"}
local sv, longestaddon, biggestaddon, varsloadtime, logging, mostgarbageaddon, leftworld
local memstack = {initmem}

local timerIsLocked = debugprofilestop()
local previousTimer

local function start()
	if previousTimer then
		previousTimer = nil
	end
	if timerIsLocked then
		-- Timer was already running
	end
	timerIsLocked = debugprofilestop()
end

local function stop()
	if not timerIsLocked then
		-- Timer was not running
	end
	local elapsed = debugprofilestop() - timerIsLocked
	previousTimer = timerIsLocked
	return elapsed, previousTimer
end

start()

local frame = CreateFrame("Frame")
WarmupContinued = {}

frame:SetScript("OnEvent", function(self, event, ...)
	if eventcounts then
		eventcounts[event] = (eventcounts[event] or 0) + 1
		eventargs[event] = max(select("#", ...), eventargs[event] or 0)
	end
	if WarmupContinued[event] then WarmupContinued[event](WarmupContinued, ...) end
end)


local function GetThreshColor(set, value)
	local t = set == "mem" and threshmems or threshtimes
	for i,v in ipairs(t) do
		if value >= v then return threshcolors[i] end
	end
	return threshcolors[4]
end


local function PutOut(txt, color, time, mem, gc)
	local outstr = (time and string.format("%.3f sec | ", time) or "") ..
		color .. txt ..
		(mem and string.format(" (%d KiB", mem) or "") ..
		(gc and string.format(" - %d KiB)", gc) or mem and ")" or "")
	outputFrame:AddMessage(outstr)
end


local function PutOutAO(name, time, mem, garbage)
	outputFrame:AddMessage(string.format("%s%.3f sec|r | %s (%s%d KiB|r - %s%d KiB|r)", GetThreshColor("time", time), time,
		name, GetThreshColor("mem", mem), mem, GetThreshColor("mem", garbage), garbage))
	return string.format("%.3f sec | %s (%d KiB - %d KiB)", time, name, mem, garbage)
end

do
	local loadandpop = function(...)
		local newm = tremove(memstack) or 0
		local oldm = tremove(memstack) or 0
		local origm = tremove(memstack) or 0
		tinsert(memstack, origm + newm - oldm)
		return ...
	end
	local lao = LoadAddOn
	LoadAddOn = function (...)
		if timerIsLocked then
			stop()
		end

		start()
		collectgarbage("collect")
		gctime = gctime + stop()/1000

		local newmem = collectgarbage("count")
		tinsert(memstack, newmem)
		tinsert(memstack, newmem)
		start()
		return loadandpop(lao(...))
	end
end

do
	for i = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(i)
		if C_AddOns.IsAddOnLoaded(i) then
			if name ~= addonName and name ~= "WarmupContinued" and name ~= "!!WarmupContinued" then
				outputFrame:AddMessage("Addon loaded before WarmupContinued: " .. name)
			end
		end
	end
end

function WarmupContinued:Init()
	if not WarmupContinuedSV then
		WarmupContinuedSV = WarmupSV or {}
	end
	sv = WarmupContinuedSV
	sv.addoninfo = {}

	hooksecurefunc("ReloadUI", function()
		if sv then
			sv.reloadingUI = true
		end
	end)
end


function WarmupContinued:DumpEvents()
	local sortt = {}
	for ev,val in pairs(eventcounts) do tinsert(sortt, ev) end
	table.sort(sortt)
	for i,ev in ipairs(sortt) do
		outputFrame:AddMessage(string.format(threshcolors[1].."%d|r (%d) | %s%s|r", eventcounts[ev], eventargs[ev], threshcolors[4], ev))
	end
	outputFrame:AddMessage("------------")
end


function WarmupContinued:ADDON_LOADED(addon)
	local addonmem = collectgarbage("count")
	local lastmem = tremove(memstack) or 0
	local lasttime = stop()/1000
	local diff = addonmem - lastmem

	totaltime = totaltime + lasttime

	start()
	collectgarbage("collect")
	gctime = gctime + stop()/1000

	local gcmem = collectgarbage("count")
	local garbage = addonmem - gcmem

	if not sv then self:Init() end

	tinsert(sv.addoninfo, PutOutAO(addon, lasttime, diff - garbage, garbage))

	if lasttime > longesttime then
		longesttime = lasttime
		longestaddon = addon
	end
	if (diff - garbage) > biggestmem then
		biggestmem = diff - garbage
		biggestaddon = addon
	end
	if garbage > mostgarbage then
		mostgarbage = garbage
		mostgarbageaddon = addon
	end
	totalgarbage = totalgarbage + garbage
	totalmem = totalmem + diff
	tinsert(memstack, gcmem)
	start()
end


function WarmupContinued:VARIABLES_LOADED()
	if varsloadtime then return end
	stop()

	start()
	collectgarbage("collect")
	gctime = gctime + stop()/1000

	local lastmem = collectgarbage("count")

	varsloadtime = GetTime()
	PutOut("Addon Loadup", threshcolors[4], totaltime, lastmem - initmem, totalgarbage)
	PutOut("Warmup's Garbage Collection", threshcolors[4], gctime)
	PutOut("Longest addon: " .. (longestaddon or "None"), threshcolors[2], longesttime)
	PutOut("Biggest addon: " .. (biggestaddon or "None"), threshcolors[2], nil, biggestmem)
	PutOut("Most Garbage: " .. (mostgarbageaddon or "None"), threshcolors[2], nil, mostgarbage)

	frame:RegisterEvent("PLAYER_LOGIN")

	SlashCmdList["WARMUPCONTINUED"] = function()
		containerFrame:SetShown(not containerFrame:IsShown())
	end

	SLASH_WARMUPCONTINUED1 = "/wuc"
	SLASH_WARMUPCONTINUED2 = "/warmupcontinued"
	SLASH_WARMUPCONTINUED3 = "/warmup"
	SLASH_WARMUPCONTINUED4 = "/wu"

	collectgarbage("restart")
	start()
end


function WarmupContinued:PLAYER_LOGIN()
	tinsert(UISpecialFrames, "WarmupContinuedOutputFrame")
	if sv.reloadingUI then
		sv.reloadingUI = nil
	else
		C_Timer.After(2, function()
			if not UnitAffectingCombat("player") then
				containerFrame:Show()
			end
		end)
	end
	logging = true
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
end


function WarmupContinued:PLAYER_ENTERING_WORLD()
	if logging then
		local entrytime = stop()/1000
		PutOut("World entry", threshcolors[4], entrytime)
		PutOut("Total time", threshcolors[4], entrytime + totaltime + gctime)
		sv.time = nil
		varsloadtime = nil
	elseif leftworld then
		PutOut("Zoning", threshcolors[4], stop()/1000)
		leftworld = nil
	end

	logging = nil
	frame:UnregisterEvent("PLAYER_LOGIN")
	frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
	frame:UnregisterEvent("ADDON_LOADED")

	eventcounts = nil
end


function WarmupContinued:PLAYER_LEAVING_WORLD()
	sv.time = GetTime()
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_LOGOUT")

	eventcounts = {}
	if timerIsLocked then
		stop()
	end
	start()
	leftworld = true
end


function WarmupContinued:PLAYER_LOGOUT()
	if not sv.reloadingUI then sv.time = nil end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("PLAYER_LOGOUT")