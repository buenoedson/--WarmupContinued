-- Updated WarmUp by Cybeloras of Mal'Ganis. Uses debugprofile start/stop instead of GetTime because it seems that GetTime() is not updated during loading screens anymore.
-- Further updated by Phanx for WoW 6.x (https://github.com/phanx-wow/Warmup)
-- Addon forked by tomchapin to work with WoW 7.1
-- Forked by ZZumMallen for WoW 11.0 prepatch
-- Lean - added historical data storage, graphical summary/hover charts, scale control and optional GC
-- Modernized for WoW 12.1.0 (Midnight) by buenoedson (Google Antigravity) as WarmupContinued

local addonName = ...

---@type any
local bdTemplate = BackdropTemplateMixin and "BackdropTemplate"

local defaultBackdrop = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	tile = true,
	tileSize = 16,
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local containerFrame = CreateFrame("Frame", "WarmupContinuedOutputFrame", UIParent, bdTemplate)
containerFrame:EnableMouse(false)
containerFrame:Hide()

local outputFrame = CreateFrame("ScrollingMessageFrame", "WarmupContinuedChatFrame", containerFrame, bdTemplate)
outputFrame:SetFontObject("ChatFontNormal")
outputFrame:SetMaxLines(512)

local outputScrollBar, copyButton, copyEditBox, copyMode, summaryPanel, hoverGraph, summaryScrollBar, totalGraphScrollBar
local leftBottomBar, rightBottomBar, rightModeLastBtn, rightModeTotalBtn, showStartupCheck, enableGCCheck
local summaryTitle
local outputLines = {}
local AddOutput, UpdateOutputScrollBar, UpdateSummaryChart
local sessionAddonOrder, sessionAddonLastMs, sessionAddonCount = {}, {}, 0
local sessionBlizzardAddons = {}
local summaryScrollOffset = 0
local totalHistoryScrollOffset = 0
local summaryMode = "last"

containerFrame:SetScript("OnShow", function(self)
	self:SetScript("OnShow", nil)
	self:HookScript("OnShow", function(frame)
		frame:EnableMouse(true)
		if copyEditBox and copyEditBox:IsShown() then
			copyEditBox:ClearFocus()
			copyEditBox:Hide()
		end
		if outputFrame then outputFrame:Show() end
		if UpdateOutputScrollBar then UpdateOutputScrollBar() end
	end)
	self:HookScript("OnHide", function(frame)
		frame:EnableMouse(false)
		copyMode = false
		if copyEditBox then
			copyEditBox:ClearFocus()
			copyEditBox:Hide()
		end
		if copyButton then copyButton:SetText("Copy..") end
		if hoverGraph then hoverGraph:Hide() end
		if outputFrame then outputFrame:Show() end
		if outputScrollBar then outputScrollBar:Hide() end
		GameTooltip:Hide()
	end)

	self:SetPoint("LEFT", 50, 100)
	self:SetSize(1020, 430)
	self:EnableMouse(true)
	self:SetMovable(true)
	self:SetClampedToScreen(true)

	local function StartWindowDrag(_, button)
		if button == "LeftButton" then
			self:StartMoving()
		end
	end
	local function StopWindowDrag(_, button)
		if button == "LeftButton" then
			self:StopMovingOrSizing()
		end
	end

	self:SetScript("OnMouseDown", StartWindowDrag)
	self:SetScript("OnMouseUp", StopWindowDrag)
	if not self.SetVerticalScroll then
		self.SetVerticalScroll = function() end
	end

	self:SetBackdrop(defaultBackdrop)
	self:SetBackdropColor(0, 0, 0)
	self:SetBackdropBorderColor(0.8, 0.8, 0.8)

	local bg = self:CreateTexture(nil, "BORDER")
	bg:SetPoint("BOTTOMLEFT", 5, 5)
	bg:SetPoint("TOPRIGHT", -5, -5)
	bg:SetAtlas("collections-background-tile")
	bg:SetAlpha(0.9)

	local close = CreateFrame("Button", nil, self, "UIPanelCloseButton", bdTemplate)
	close:SetPoint("TOPRIGHT", -5, -5)
	close:SetScale(0.8)
	close:SetScript("OnClick", function()
		self:Hide()
	end)

	local title = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 12, -2)
	title:SetHeight(close:GetHeight())
	title:SetJustifyH("LEFT")
	title:SetText("Warmup Continued")

	local scaleLabel = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	scaleLabel:SetPoint("RIGHT", close, "LEFT", -150, -5)
	scaleLabel:SetScale(1.2)
	scaleLabel:SetText("Scale")

	local scaleSlider = CreateFrame("Slider", nil, self, bdTemplate)
	scaleSlider:SetPoint("LEFT", scaleLabel, "RIGHT", 4, 0)
	scaleSlider:SetSize(90, 17)
	scaleSlider:SetScale(1.2)
	scaleSlider:SetOrientation("HORIZONTAL")
	scaleSlider:SetMinMaxValues(0.6, 1.4)
	scaleSlider:SetValueStep(0.05)
	scaleSlider:SetObeyStepOnDrag(true)

	local sliderTrack = scaleSlider:CreateTexture(nil, "BACKGROUND")
	sliderTrack:SetAllPoints(scaleSlider)
	sliderTrack:SetColorTexture(0.8, 0.8, 0.8, 0.95)

	local sliderThumb = scaleSlider:CreateTexture(nil, "OVERLAY")
	sliderThumb:SetSize(12, 17)
	sliderThumb:SetColorTexture(0.25, 0.25, 0.25, 1)
	scaleSlider:SetThumbTexture(sliderThumb)

	local scaleValue = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	scaleValue:SetPoint("LEFT", scaleSlider, "RIGHT", 5, 0)
	scaleValue:SetScale(1.2)
	title:SetPoint("RIGHT", scaleLabel, "LEFT", -10, 0)

	local dragTitleRegion = CreateFrame("Frame", nil, self)
	dragTitleRegion:SetPoint("TOPLEFT", 8, -8)
	dragTitleRegion:SetPoint("TOPRIGHT", -8, -8)
	dragTitleRegion:SetHeight(22)
	dragTitleRegion:EnableMouse(true)
	dragTitleRegion:SetScript("OnMouseDown", StartWindowDrag)
	dragTitleRegion:SetScript("OnMouseUp", StopWindowDrag)
	dragTitleRegion:SetFrameLevel(self:GetFrameLevel())

	local initialScale = (WarmupContinuedSV and WarmupContinuedSV.scale) or (WarmupSV and WarmupSV.scale) or 1
	self:SetScale(initialScale)
	scaleSlider:SetValue(initialScale)
	scaleValue:SetText(string.format("%.0f%%", initialScale * 100))

	scaleSlider:SetScript("OnValueChanged", function(_, value)
		value = math.floor(value * 20 + 0.5) / 20
		scaleValue:SetText(string.format("%.0f%%", value * 100))
	end)
	scaleSlider:SetScript("OnMouseUp", function(slider)
		local value = math.floor(slider:GetValue() * 20 + 0.5) / 20
		self:SetScale(value)
		scaleValue:SetText(string.format("%.0f%%", value * 100))
		if not WarmupContinuedSV then WarmupContinuedSV = {} end
		WarmupContinuedSV.scale = value
	end)

	local div = self:CreateTexture(nil, "ARTWORK")
	div:SetPoint("TOPLEFT", 8, -26)
	div:SetPoint("TOPRIGHT", -8, -26)
	div:SetHeight(8)
	div:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")

	local statusBarHeight = close:GetHeight() + 8

	summaryPanel = CreateFrame("Frame", nil, self, bdTemplate)
	summaryPanel:SetPoint("TOPRIGHT", -10, -31)
	summaryPanel:SetPoint("BOTTOMRIGHT", -10, 8 + statusBarHeight + 6)
	summaryPanel:SetWidth(470)
	summaryPanel:SetBackdrop(defaultBackdrop)
	summaryPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.7)
	summaryPanel:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
	if not summaryPanel.SetVerticalScroll then
		summaryPanel.SetVerticalScroll = function() end
	end

	leftBottomBar = CreateFrame("Frame", nil, self, bdTemplate)
	leftBottomBar:SetPoint("BOTTOMLEFT", 8, 8)
	leftBottomBar:SetPoint("BOTTOMRIGHT", summaryPanel, "BOTTOMLEFT", -6, 0)
	leftBottomBar:SetHeight(statusBarHeight)
	leftBottomBar:SetBackdrop(defaultBackdrop)
	leftBottomBar:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
	leftBottomBar:SetBackdropBorderColor(0.8, 0.8, 0.8)

	rightBottomBar = CreateFrame("Frame", nil, self, bdTemplate)
	rightBottomBar:SetPoint("BOTTOMLEFT", summaryPanel, "BOTTOMLEFT", 0, -statusBarHeight - 6)
	rightBottomBar:SetPoint("BOTTOMRIGHT", summaryPanel, "BOTTOMRIGHT", 0, -statusBarHeight - 6)
	rightBottomBar:SetPoint("TOPLEFT", summaryPanel, "BOTTOMLEFT", 0, -6)
	rightBottomBar:SetBackdrop(defaultBackdrop)
	rightBottomBar:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
	rightBottomBar:SetBackdropBorderColor(0.8, 0.8, 0.8)

	copyButton = CreateFrame("Button", nil, leftBottomBar, "UIPanelButtonTemplate")
	copyButton:SetPoint("LEFT", 6, 0)
	copyButton:SetSize(72, close:GetHeight() - 8)
	copyButton:SetText("Copy..")

	showStartupCheck = CreateFrame("CheckButton", nil, leftBottomBar, "UICheckButtonTemplate")
	showStartupCheck:SetPoint("LEFT", copyButton, "RIGHT", 12, 0)
	local initStartup = true
	if WarmupContinuedSV and WarmupContinuedSV.showOnStartup ~= nil then
		initStartup = WarmupContinuedSV.showOnStartup
	elseif WarmupSV and WarmupSV.showOnStartup ~= nil then
		initStartup = WarmupSV.showOnStartup
	end
	showStartupCheck:SetChecked(initStartup)

	local showStartupText = leftBottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	showStartupText:SetPoint("LEFT", showStartupCheck, "RIGHT", 2, 0)
	showStartupText:SetText("Show on startup")
	showStartupCheck:SetHitRectInsets(0, -(showStartupText:GetStringWidth() + 4), 0, 0)

	enableGCCheck = CreateFrame("CheckButton", nil, leftBottomBar, "UICheckButtonTemplate")
	enableGCCheck:SetPoint("LEFT", showStartupText, "RIGHT", 16, 0)
	local initGC = false
	if WarmupContinuedSV and WarmupContinuedSV.enableGC ~= nil then
		initGC = WarmupContinuedSV.enableGC
	elseif WarmupSV and WarmupSV.enableGC ~= nil then
		initGC = WarmupSV.enableGC
	end
	enableGCCheck:SetChecked(initGC)

	local enableGCText = leftBottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	enableGCText:SetPoint("LEFT", enableGCCheck, "RIGHT", 2, 0)
	enableGCText:SetText("Enable GC")
	enableGCCheck:SetHitRectInsets(0, -(enableGCText:GetStringWidth() + 4), 0, 0)
	enableGCCheck:SetScript("OnEnter", function(cb)
		GameTooltip:SetOwner(cb, "ANCHOR_TOP")
		GameTooltip:SetBackdropColor(0, 0, 0, 1)
		GameTooltip:SetText("On: shows retained vs garbage memory per addon (slower load)\nOff: faster load, memory totals only")
		GameTooltip:Show()
	end)
	enableGCCheck:SetScript("OnLeave", GameTooltip_Hide)

	summaryTitle = summaryPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	summaryTitle:SetPoint("TOPLEFT", 8, -6)
	summaryTitle:SetText("Last load time")

	summaryPanel.chartArea = CreateFrame("Frame", nil, summaryPanel)
	summaryPanel.chartArea:SetPoint("TOPLEFT", 8, -24)
	summaryPanel.chartArea:SetPoint("BOTTOMRIGHT", -26, 8)

	rightModeLastBtn = CreateFrame("CheckButton", nil, rightBottomBar, "UICheckButtonTemplate")
	rightModeLastBtn:SetPoint("LEFT", 6, 0)
	rightModeLastBtn:SetChecked(true)
	local rightModeLastText = rightBottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	rightModeLastText:SetPoint("LEFT", rightModeLastBtn, "RIGHT", 2, 0)
	rightModeLastText:SetText("Last load time")
	rightModeLastBtn:SetHitRectInsets(0, -(rightModeLastText:GetStringWidth() + 4), 0, 0)

	rightModeTotalBtn = CreateFrame("CheckButton", nil, rightBottomBar, "UICheckButtonTemplate")
	rightModeTotalBtn:SetPoint("LEFT", rightModeLastText, "RIGHT", 16, 0)
	local rightModeTotalText = rightBottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	rightModeTotalText:SetPoint("LEFT", rightModeTotalBtn, "RIGHT", 2, 0)
	rightModeTotalText:SetText("Overall load time")
	rightModeTotalBtn:SetHitRectInsets(0, -(rightModeTotalText:GetStringWidth() + 4), 0, 0)

	summaryScrollBar = CreateFrame("Slider", "WarmupContinuedSummaryScrollBar", summaryPanel, "UIPanelScrollBarTemplate")
	summaryScrollBar:SetPoint("TOPRIGHT", -8, -24)
	summaryScrollBar:SetPoint("BOTTOMRIGHT", -8, 22)
	summaryScrollBar:SetMinMaxValues(0, 0)
	summaryScrollBar:SetValueStep(1)
	summaryScrollBar:SetObeyStepOnDrag(true)
	summaryScrollBar:SetValue(0)

	local summaryUpBtn = summaryScrollBar.ScrollUpButton or _G[summaryScrollBar:GetName() .. "ScrollUpButton"]
	local summaryDownBtn = summaryScrollBar.ScrollDownButton or _G[summaryScrollBar:GetName() .. "ScrollDownButton"]
	if summaryUpBtn then
		summaryUpBtn:SetScript("OnClick", function()
			local low, high = summaryScrollBar:GetMinMaxValues()
			summaryScrollBar:SetValue(math.max(summaryScrollBar:GetValue() - 1, low))
		end)
	end
	if summaryDownBtn then
		summaryDownBtn:SetScript("OnClick", function()
			local low, high = summaryScrollBar:GetMinMaxValues()
			summaryScrollBar:SetValue(math.min(summaryScrollBar:GetValue() + 1, high))
		end)
	end
	summaryScrollBar:SetScript("OnValueChanged", function(_, value)
		summaryScrollOffset = math.floor(value + 0.5)
		if UpdateSummaryChart then UpdateSummaryChart() end
	end)

	totalGraphScrollBar = CreateFrame("Slider", nil, rightBottomBar, bdTemplate)
	totalGraphScrollBar:SetPoint("RIGHT", -8, 0)
	totalGraphScrollBar:SetSize(140, 14)
	totalGraphScrollBar:SetOrientation("HORIZONTAL")
	totalGraphScrollBar:SetMinMaxValues(0, 0)
	totalGraphScrollBar:SetValueStep(1)
	totalGraphScrollBar:SetObeyStepOnDrag(true)
	totalGraphScrollBar:SetValue(0)

	local totalThumb = totalGraphScrollBar:CreateTexture(nil, "OVERLAY")
	totalThumb:SetSize(12, 14)
	totalThumb:SetColorTexture(0.8, 0.8, 0.8, 1)
	totalGraphScrollBar:SetThumbTexture(totalThumb)
	totalGraphScrollBar:SetScript("OnValueChanged", function(_, value)
		totalHistoryScrollOffset = math.floor(value + 0.5)
		if UpdateSummaryChart then UpdateSummaryChart() end
	end)
	totalGraphScrollBar:Hide()

	local function SetSummaryMode(mode)
		summaryMode = mode
		rightModeLastBtn:SetChecked(mode == "last")
		rightModeTotalBtn:SetChecked(mode == "total")
		if summaryTitle then
			summaryTitle:SetText(mode == "total" and "Overall load time (last 50)" or "Last load time")
		end
		totalHistoryScrollOffset = 0
		summaryScrollOffset = 0
		if summaryScrollBar then summaryScrollBar:SetValue(0) end
		if totalGraphScrollBar then totalGraphScrollBar:SetValue(0) end
		if hoverGraph then hoverGraph:Hide() end
		if UpdateSummaryChart then UpdateSummaryChart() end
	end

	rightModeLastBtn:SetScript("OnClick", function() SetSummaryMode("last") end)
	rightModeTotalBtn:SetScript("OnClick", function() SetSummaryMode("total") end)

	showStartupCheck:SetScript("OnClick", function(cb)
		if not WarmupContinuedSV then WarmupContinuedSV = {} end
		WarmupContinuedSV.showOnStartup = cb:GetChecked() and true or false
	end)

	enableGCCheck:SetScript("OnClick", function(cb)
		if not WarmupContinuedSV then WarmupContinuedSV = {} end
		local enabled = cb:GetChecked() and true or false
		WarmupContinuedSV.enableGC = enabled
		if sv then
			sv.enableGC = enabled
		end
	end)

	outputScrollBar = CreateFrame("Slider", "WarmupContinuedOutputScrollBar", self, "UIPanelScrollBarTemplate")
	outputScrollBar:SetPoint("TOPRIGHT", summaryPanel, "TOPLEFT", -4, -16)
	outputScrollBar:SetPoint("BOTTOMRIGHT", summaryPanel, "BOTTOMLEFT", -4, 22)
	outputScrollBar:SetMinMaxValues(0, 0)
	outputScrollBar:SetValueStep(1)
	outputScrollBar:SetObeyStepOnDrag(true)
	outputScrollBar:SetValue(0)

	local outUpBtn = outputScrollBar.ScrollUpButton or _G[outputScrollBar:GetName() .. "ScrollUpButton"]
	local outDownBtn = outputScrollBar.ScrollDownButton or _G[outputScrollBar:GetName() .. "ScrollDownButton"]
	if outUpBtn then
		outUpBtn:SetScript("OnClick", function()
			outputFrame:ScrollUp()
			if UpdateOutputScrollBar then UpdateOutputScrollBar() end
		end)
	end
	if outDownBtn then
		outDownBtn:SetScript("OnClick", function()
			outputFrame:ScrollDown()
			if UpdateOutputScrollBar then UpdateOutputScrollBar() end
		end)
	end

	outputFrame:SetPoint("TOPLEFT", 12, -7 - 22)
	outputFrame:SetPoint("TOPRIGHT", outputScrollBar, "TOPLEFT", -4, -1)
	outputFrame:SetPoint("BOTTOMLEFT", 12, 20 + close:GetHeight())
	outputFrame:SetPoint("BOTTOMRIGHT", outputScrollBar, "BOTTOMLEFT", -4, 20 + close:GetHeight())
	outputFrame:SetJustifyH("LEFT")
	outputFrame:EnableMouse(true)
	outputFrame:SetScript("OnMouseDown", StartWindowDrag)
	outputFrame:SetScript("OnMouseUp", StopWindowDrag)

	summaryPanel.chartArea:EnableMouse(true)
	summaryPanel.chartArea:SetScript("OnMouseDown", StartWindowDrag)
	summaryPanel.chartArea:SetScript("OnMouseUp", StopWindowDrag)
	summaryPanel.chartArea:EnableMouseWheel(true)
	summaryPanel.chartArea:SetScript("OnMouseWheel", function(_, delta)
		if summaryMode == "total" and totalGraphScrollBar and totalGraphScrollBar:IsShown() then
			local low, high = totalGraphScrollBar:GetMinMaxValues()
			if high <= low then return end
			local step = IsShiftKeyDown() and (high - low) or (IsControlKeyDown() and 10 or 1)
			if delta > 0 then
				totalGraphScrollBar:SetValue(math.max(totalGraphScrollBar:GetValue() - step, low))
			elseif delta < 0 then
				totalGraphScrollBar:SetValue(math.min(totalGraphScrollBar:GetValue() + step, high))
			end
			return
		end

		if not summaryScrollBar or not summaryScrollBar:IsShown() then return end
		local low, high = summaryScrollBar:GetMinMaxValues()
		if high <= low then return end
		local step = IsShiftKeyDown() and (high - low) or (IsControlKeyDown() and 10 or 1)
		if delta > 0 then
			summaryScrollBar:SetValue(math.max(summaryScrollBar:GetValue() - step, low))
		elseif delta < 0 then
			summaryScrollBar:SetValue(math.min(summaryScrollBar:GetValue() + step, high))
		end
	end)

	copyEditBox = CreateFrame("EditBox", nil, self, bdTemplate)
	copyEditBox:SetPoint("TOPLEFT", 12, -7 - 22)
	copyEditBox:SetPoint("BOTTOMRIGHT", outputScrollBar, "BOTTOMLEFT", -4, 20 + close:GetHeight())
	copyEditBox:SetAutoFocus(false)
	copyEditBox:SetMultiLine(true)
	copyEditBox:SetFontObject("ChatFontNormal")
	copyEditBox:SetTextInsets(4, 4, 4, 4)
	copyEditBox:SetScript("OnEscapePressed", function(eb)
		eb:ClearFocus()
	end)
	copyEditBox:Hide()

	local function SetCopyMode(enabled)
		copyMode = enabled
		if enabled then
			outputFrame:Hide()
			outputScrollBar:Hide()
			hoverGraph:Hide()
			copyEditBox:SetText(table.concat(outputLines, "\n"))
			copyEditBox:Show()
			copyEditBox:SetFocus()
			copyEditBox:HighlightText()
			copyButton:SetText("Back")
		else
			copyEditBox:Hide()
			copyEditBox:ClearFocus()
			outputFrame:Show()
			copyButton:SetText("Copy..")
			if UpdateOutputScrollBar then UpdateOutputScrollBar() end
		end
	end

	copyButton:SetScript("OnClick", function()
		SetCopyMode(not copyMode)
	end)

	hoverGraph = CreateFrame("Frame", nil, self, bdTemplate)
	hoverGraph:SetSize(375, 240)
	hoverGraph:SetBackdrop(defaultBackdrop)
	hoverGraph:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
	hoverGraph:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.9)
	hoverGraph:Hide()
	hoverGraph.lines = {}
	hoverGraph.dots = {}
	hoverGraph.pointLabels = {}
	hoverGraph.canvas = CreateFrame("Frame", nil, hoverGraph)
	hoverGraph.canvas:SetPoint("TOPLEFT", 10, -26)
	hoverGraph.canvas:SetPoint("BOTTOMRIGHT", -10, 22)
	hoverGraph.title = hoverGraph:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hoverGraph.title:SetPoint("TOPLEFT", 10, -8)
	hoverGraph.axis = hoverGraph:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hoverGraph.axis:SetPoint("BOTTOMLEFT", 10, 8)

	outputScrollBar:SetScript("OnValueChanged", function(_, value)
		local _, maxValue = outputScrollBar:GetMinMaxValues()
		if outputFrame.SetScrollOffset then
			outputFrame:SetScrollOffset(maxValue - value)
		end
	end)

	outputFrame:SetFading(false)
	outputFrame:EnableMouseWheel(true)
	outputFrame:SetScript("OnMouseWheel", function(f, delta)
		if IsControlKeyDown() then
			local ok = delta > 0 and f:PageUp() or delta < 0 and f:PageDown()
			if UpdateOutputScrollBar then UpdateOutputScrollBar() end
			return ok
		end
		local n = IsShiftKeyDown() and f:GetNumMessages() or 5
		if delta > 0 then
			for _ = 1, n do
				f:ScrollUp()
			end
		elseif delta < 0 then
			for _ = 1, n do
				f:ScrollDown()
			end
		end
		if UpdateOutputScrollBar then UpdateOutputScrollBar() end
	end)

	if UpdateSummaryChart then UpdateSummaryChart() end
	if UpdateOutputScrollBar then UpdateOutputScrollBar() end
end)

local function IsGCEnabled()
	if sv then
		return sv.enableGC == true
	end
	if WarmupContinuedSV then
		return WarmupContinuedSV.enableGC == true
	end
	if WarmupSV then
		return WarmupSV.enableGC == true
	end
	return false
end

local preInitGCEnabled = IsGCEnabled()
if preInitGCEnabled then
	collectgarbage("stop")
	collectgarbage("collect")
end

local initmem = collectgarbage("count")
local longesttime, biggestmem, totalmem, totalgarbage, mostgarbage, gctime = 0, 0, 0, 0, 0, 0
local totaltime = 0
local totalgameloadtime = 0
local eventcounts = {}
local eventargs = {}
local threshtimes, threshmems = {1.0, 0.5, 0.1}, {1000, 500, 100}
local threshcolors = {"|cffff0000", "|cffff8000", "|cffffff80", "|cff80ff80"}
local sv, longestaddon, biggestaddon, varsloadtime, logging, mostgarbageaddon, leftworld
local pendingOverallRecord = false
local startupAttributionActive = true
local memstack = {initmem}

local timerIsLocked = debugprofilestop()

local function start()
	timerIsLocked = debugprofilestop()
end

local function stop()
	return debugprofilestop() - timerIsLocked
end

start()

local frame = CreateFrame("Frame")
WarmupContinued = {}

frame:SetScript("OnEvent", function(_, event, ...)
	if eventcounts then
		eventcounts[event] = (eventcounts[event] or 0) + 1
		eventargs[event] = math.max(select("#", ...), eventargs[event] or 0)
	end
	if WarmupContinued[event] then WarmupContinued[event](WarmupContinued, ...) end
end)

local function GetThreshColor(set, value)
	local t = set == "mem" and threshmems or threshtimes
	for i, v in ipairs(t) do
		if value >= v then return threshcolors[i] end
	end
	return threshcolors[4]
end

UpdateOutputScrollBar = function()
	if not outputScrollBar or copyMode then return end
	local maxOffset = math.max(outputFrame:GetNumMessages() - 1, 0)
	outputScrollBar:SetMinMaxValues(0, maxOffset)
	if outputFrame.GetScrollOffset then
		local offset = outputFrame:GetScrollOffset()
		outputScrollBar:SetValue(maxOffset - math.min(offset, maxOffset))
	end
	outputScrollBar:SetShown(maxOffset > 0)
end

local function TruncateAddonName(name)
	if #name > 10 then
		return name:sub(1, 10)
	end
	return name
end

local function ShowHoverGraph(targetAddon)
	if not hoverGraph or not sv or not sv.addonHistory or copyMode then return end
	local history = sv.addonHistory[targetAddon]
	if not history or #history == 0 then
		hoverGraph:Hide()
		return
	end

	hoverGraph:ClearAllPoints()
	hoverGraph:SetPoint("TOPLEFT", containerFrame, "TOPRIGHT", 0, -8)
	hoverGraph.title:SetText(targetAddon .. " (last 20)")

	local low, high = history[1], history[1]
	for i = 2, #history do
		low = math.min(low, history[i])
		high = math.max(high, history[i])
	end
	hoverGraph.axis:SetText(string.format("Load #1..#%d | %dms .. %dms", #history, low, high))

	for i = 1, #hoverGraph.lines do hoverGraph.lines[i]:Hide() end
	for i = 1, #hoverGraph.dots do hoverGraph.dots[i]:Hide() end
	for i = 1, #hoverGraph.pointLabels do hoverGraph.pointLabels[i]:Hide() end

	local range = math.max(high - low, 1)
	local width = hoverGraph.canvas:GetWidth()
	local height = hoverGraph.canvas:GetHeight()
	if width > 0 and height > 0 then
		local pointCount = #history
		local function pointX(i)
			if pointCount == 1 then return width * 0.5 end
			return ((i - 1) / (pointCount - 1)) * width
		end

		for i = 1, #history - 1 do
			local line = hoverGraph.lines[i]
			if not line then
				line = hoverGraph.canvas:CreateLine(nil, "ARTWORK")
				line:SetThickness(2)
				line:SetColorTexture(0.2, 0.8, 1.0, 1)
				hoverGraph.lines[i] = line
			end
			local x1 = pointX(i)
			local x2 = pointX(i + 1)
			local y1 = ((history[i] - low) / range) * height
			local y2 = ((history[i + 1] - low) / range) * height
			line:SetStartPoint("BOTTOMLEFT", hoverGraph.canvas, x1, y1)
			line:SetEndPoint("BOTTOMLEFT", hoverGraph.canvas, x2, y2)
			line:Show()
		end

		for i = 1, #history do
			local x = pointX(i)
			local y = ((history[i] - low) / range) * height
			local dot = hoverGraph.dots[i]
			if not dot then
				dot = hoverGraph.canvas:CreateTexture(nil, "OVERLAY")
				dot:SetColorTexture(1, 1, 1, 1)
				hoverGraph.dots[i] = dot
			end
			dot:SetSize(4, 4)
			dot:SetPoint("CENTER", hoverGraph.canvas, "BOTTOMLEFT", x, y)
			dot:Show()

			local ptLabel = hoverGraph.pointLabels[i]
			if not ptLabel then
				ptLabel = hoverGraph.canvas:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
				hoverGraph.pointLabels[i] = ptLabel
			end
			ptLabel:SetText(string.format("%.3fs", history[i] / 1000))
			ptLabel:SetPoint("BOTTOM", dot, "TOP", 0, 2)
			if ptLabel.SetRotation then
				ptLabel:SetRotation(math.pi / 2)
			end
			ptLabel:Show()
		end
	end

	hoverGraph:Show()
end

UpdateSummaryChart = function()
	if not summaryPanel then return end
	if not summaryPanel.bars then summaryPanel.bars = {} end
	if not summaryPanel.labels then summaryPanel.labels = {} end
	if not summaryPanel.hitboxes then summaryPanel.hitboxes = {} end
	if not summaryPanel.totalLines then summaryPanel.totalLines = {} end
	if not summaryPanel.totalDots then summaryPanel.totalDots = {} end
	if not summaryPanel.totalLabels then summaryPanel.totalLabels = {} end
	if not summaryPanel.totalHitboxes then summaryPanel.totalHitboxes = {} end

	local chart = summaryPanel.chartArea
	local panelWidth = chart:GetWidth()
	local panelHeight = chart:GetHeight()
	if panelWidth <= 0 or panelHeight <= 0 then return end

	for i = 1, #summaryPanel.bars do
		if summaryPanel.bars[i] then summaryPanel.bars[i]:Hide() end
		if summaryPanel.labels[i] then summaryPanel.labels[i]:Hide() end
		if summaryPanel.hitboxes[i] then summaryPanel.hitboxes[i]:Hide() end
	end
	for i = 1, #summaryPanel.totalLines do summaryPanel.totalLines[i]:Hide() end
	for i = 1, #summaryPanel.totalDots do summaryPanel.totalDots[i]:Hide() end
	for i = 1, #summaryPanel.totalLabels do summaryPanel.totalLabels[i]:Hide() end
	for i = 1, #summaryPanel.totalHitboxes do summaryPanel.totalHitboxes[i]:Hide() end

	if summaryMode == "total" then
		if summaryScrollBar then summaryScrollBar:Hide() end
		if not sv or not sv.totalLoadHistory or #sv.totalLoadHistory == 0 then
			if totalGraphScrollBar then totalGraphScrollBar:Hide() end
			GameTooltip:Hide()
			return
		end

		local history = sv.totalLoadHistory
		if totalGraphScrollBar then
			totalGraphScrollBar:SetMinMaxValues(0, 0)
			totalGraphScrollBar:SetValue(0)
			totalGraphScrollBar:Hide()
		end

		local first = math.max(#history - 49, 1)
		local last = #history
		local pointCount = last - first + 1
		local low, high = history[first].sec, history[first].sec
		for i = first + 1, last do
			low = math.min(low, history[i].sec)
			high = math.max(high, history[i].sec)
		end
		local range = math.max(high - low, 0.001)
		local graphHeight = panelHeight - 18
		local graphWidth = panelWidth - 8

		for i = 1, pointCount - 1 do
			local line = summaryPanel.totalLines[i]
			if not line then
				line = chart:CreateLine(nil, "ARTWORK")
				line:SetThickness(2)
				line:SetColorTexture(0.2, 0.85, 1.0, 1)
				summaryPanel.totalLines[i] = line
			end
			local x1 = ((i - 1) / math.max(pointCount - 1, 1)) * graphWidth + 4
			local x2 = (i / math.max(pointCount - 1, 1)) * graphWidth + 4
			local y1 = ((history[first + i - 1].sec - low) / range) * graphHeight + 4
			local y2 = ((history[first + i].sec - low) / range) * graphHeight + 4
			line:SetStartPoint("BOTTOMLEFT", chart, x1, y1)
			line:SetEndPoint("BOTTOMLEFT", chart, x2, y2)
			line:Show()
		end

		for i = 1, pointCount do
			local entry = history[first + i - 1]
			local x = ((i - 1) / math.max(pointCount - 1, 1)) * graphWidth + 4
			local y = ((entry.sec - low) / range) * graphHeight + 4

			local dot = summaryPanel.totalDots[i]
			if not dot then
				dot = chart:CreateTexture(nil, "OVERLAY")
				dot:SetColorTexture(1, 1, 1, 1)
				summaryPanel.totalDots[i] = dot
			end
			dot:SetSize(4, 4)
			dot:SetPoint("CENTER", chart, "BOTTOMLEFT", x, y)
			dot:Show()

			local label = summaryPanel.totalLabels[i]
			if not label then
				label = chart:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
				summaryPanel.totalLabels[i] = label
			end
			label:SetText(string.format("%.3fs", entry.sec))
			label:SetPoint("BOTTOM", dot, "TOP", 0, 2)
			if label.SetRotation then
				label:SetRotation(math.pi / 2)
			end
			label:Show()

			local hitbox = summaryPanel.totalHitboxes[i]
			if not hitbox then
				hitbox = CreateFrame("Button", nil, chart)
				summaryPanel.totalHitboxes[i] = hitbox
			end
			local hoverEntry = entry
			hitbox:SetPoint("CENTER", dot, "CENTER", 0, 0)
			hitbox:SetSize(40, 40)
			hitbox:SetScript("OnEnter", function(hb)
				GameTooltip:SetOwner(hb, "ANCHOR_RIGHT")
				GameTooltip:SetText("Total load time")
				GameTooltip:AddLine(string.format("Load: %.3f sec", hoverEntry.sec), 1, 1, 1)
				GameTooltip:AddLine(hoverEntry.at, 0.8, 0.8, 0.8)
				GameTooltip:Show()
			end)
			hitbox:SetScript("OnLeave", GameTooltip_Hide)
			hitbox:Show()
		end
		return
	end

	if totalGraphScrollBar then totalGraphScrollBar:Hide() end
	if summaryScrollBar then summaryScrollBar:Show() end
	for i = 1, #summaryPanel.totalHitboxes do
		if summaryPanel.totalHitboxes[i] then summaryPanel.totalHitboxes[i]:Hide() end
	end
	GameTooltip:Hide()

	local rowHeight = 20
	local labelWidth = 170
	local barHeight = 10
	local rows = {}
	local seen = {}
	for i = 1, sessionAddonCount do
		local aName = sessionAddonOrder[i]
		if aName and not seen[aName] then
			seen[aName] = true
			table.insert(rows, { name = aName, ms = sessionAddonLastMs[aName] or 0 })
		end
	end
	table.sort(rows, function(a, b) return a.ms > b.ms end)

	local count = #rows
	local visibleRows = math.max(math.floor(panelHeight / rowHeight), 1)
	local maxScroll = math.max(count - visibleRows, 0)
	local maxMs = 1
	for i = 1, count do
		maxMs = math.max(maxMs, rows[i].ms)
	end

	if summaryScrollBar then
		summaryScrollBar:SetMinMaxValues(0, maxScroll)
		summaryScrollBar:SetShown(maxScroll > 0)
		if summaryScrollOffset > maxScroll then
			summaryScrollOffset = maxScroll
			summaryScrollBar:SetValue(maxScroll)
		end
	end

	if count == 0 then return end

	local first = summaryScrollOffset + 1
	local last = math.min(count, first + visibleRows - 1)
	local barXOffset = labelWidth + 10
	local barMaxWidth = math.max(panelWidth - barXOffset - 8, 10)
	local row = 0
	for i = first, last do
		row = row + 1
		local aName = rows[i].name
		local ms = rows[i].ms
		local ratio = ms / maxMs
		local barWidth = math.max(2, ratio * barMaxWidth)
		local r, g = ratio, 1 - ratio
		local topY = -((row - 1) * rowHeight) - 2

		local bar = summaryPanel.bars[row]
		if not bar then
			bar = chart:CreateTexture(nil, "ARTWORK")
			summaryPanel.bars[row] = bar
		end
		bar:SetColorTexture(r, g, 0.15, 0.65)
		bar:SetSize(barWidth, barHeight)
		bar:SetPoint("TOPLEFT", chart, "TOPLEFT", barXOffset, topY - 2)
		bar:Show()

		local label = summaryPanel.labels[row]
		if not label then
			label = chart:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			summaryPanel.labels[row] = label
		end
		label:SetText(string.format("%s (%.3f sec)", TruncateAddonName(aName), ms / 1000))
		label:SetPoint("TOPLEFT", chart, "TOPLEFT", 2, topY)
		label:SetWidth(labelWidth - 4)
		label:SetJustifyH("LEFT")
		label:Show()

		local hitbox = summaryPanel.hitboxes[row]
		if not hitbox then
			hitbox = CreateFrame("Button", nil, chart)
			summaryPanel.hitboxes[row] = hitbox
		end
		local addonForHover = aName
		hitbox:SetPoint("TOPLEFT", chart, "TOPLEFT", 0, topY + 1)
		hitbox:SetPoint("TOPRIGHT", chart, "TOPRIGHT", -2, topY + 1)
		hitbox:SetHeight(rowHeight)
		hitbox:SetScript("OnEnter", function() ShowHoverGraph(addonForHover) end)
		hitbox:SetScript("OnLeave", function() hoverGraph:Hide() end)
		hitbox:Show()
	end
end

AddOutput = function(styledText, plainText)
	outputFrame:AddMessage(styledText)
	table.insert(outputLines, plainText or styledText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
	if #outputLines > 512 then
		table.remove(outputLines, 1)
	end
	if copyMode and copyEditBox and copyEditBox:IsShown() then
		copyEditBox:SetText(table.concat(outputLines, "\n"))
	end
	UpdateOutputScrollBar()
end

local function PutOut(txt, color, time, mem, gc)
	local outstr = (time and string.format("%.3f sec | ", time) or "") ..
		color .. txt ..
		(mem and string.format(" (%d KiB", mem) or "") ..
		(gc and string.format(" - %d KiB)", gc) or mem and ")" or "")
	local plainstr = (time and string.format("%.3f sec | ", time) or "") ..
		txt ..
		(mem and string.format(" (%d KiB", mem) or "") ..
		(gc and string.format(" - %d KiB)", gc) or mem and ")" or "")
	AddOutput(outstr, plainstr)
end

local function PutOutAO(_, name, time, mem, garbage, ms)
	local function FormatKiB(value)
		if math.abs(value) < 1 and value ~= 0 then
			return string.format("%.2f", value)
		end
		return string.format("%d", value)
	end

	local memText = FormatKiB(mem)
	local styled
	local plain
	if garbage == nil then
		styled = string.format("%s%.3f sec|r | %s (%s%s KiB|r - |cffffd200GC off|r)",
			GetThreshColor("time", time), time, name, GetThreshColor("mem", mem), memText)
		plain = string.format("%.3f sec | %s (%s KiB - GC off) [%dms]", time, name, memText, ms)
	else
		local garbageText = FormatKiB(garbage)
		styled = string.format("%s%.3f sec|r | %s (%s%s KiB|r - %s%s KiB|r)",
			GetThreshColor("time", time), time, name, GetThreshColor("mem", mem), memText, GetThreshColor("mem", garbage), garbageText)
		plain = string.format("%.3f sec | %s (%s KiB - %s KiB) [%dms]", time, name, memText, garbageText, ms)
	end
	AddOutput(styled, plain)
	return plain
end

do
	local loadandpop = function(...)
		local newm = table.remove(memstack) or 0
		local oldm = table.remove(memstack) or 0
		local origm = table.remove(memstack) or 0
		table.insert(memstack, origm + newm - oldm)
		return ...
	end
	local lao = LoadAddOn or (C_AddOns and C_AddOns.LoadAddOn)
	LoadAddOn = function (...)
		if timerIsLocked then
			stop()
		end

		if IsGCEnabled() then
			start()
			collectgarbage("collect")
			gctime = gctime + stop() / 1000
		end

		local newmem = collectgarbage("count")
		table.insert(memstack, newmem)
		table.insert(memstack, newmem)
		start()
		return loadandpop(lao(...))
	end
end

do
	for i = 1, C_AddOns.GetNumAddOns() do
		if C_AddOns.IsAddOnLoaded(i) then
			local aName = C_AddOns.GetAddOnInfo(i)
			if aName ~= addonName and aName ~= "!!WarmupContinued" and aName ~= "WarmupContinued" and aName ~= "!!Warmup" and aName ~= "Warmup" then
				AddOutput("Addon loaded before WarmupContinued: " .. aName)
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
	if not sv.addonHistory then sv.addonHistory = {} end
	if not sv.lastAddonMs then sv.lastAddonMs = {} end
	if not sv.totalLoadHistory then sv.totalLoadHistory = {} end
	sv.showOnStartup = (sv.showOnStartup ~= false)
	sv.enableGC = (sv.enableGC == true)
	if not sv.scale then sv.scale = 1 end
	containerFrame:SetScale(sv.scale)
	if showStartupCheck then showStartupCheck:SetChecked(sv.showOnStartup) end
	if enableGCCheck then enableGCCheck:SetChecked(sv.enableGC) end
	pendingOverallRecord = true
	sessionAddonOrder, sessionAddonLastMs, sessionAddonCount = {}, {}, 0
	sessionBlizzardAddons = {}
	summaryScrollOffset = 0
	totalHistoryScrollOffset = 0
	if summaryScrollBar then summaryScrollBar:SetValue(0) end
	if totalGraphScrollBar then totalGraphScrollBar:SetValue(0) end

	hooksecurefunc("ReloadUI", function()
		if sv then
			sv.reloadingUI = true
		end
	end)
end

function WarmupContinued:DumpEvents()
	local sortt = {}
	for ev in pairs(eventcounts) do table.insert(sortt, ev) end
	table.sort(sortt)

	for _, ev in ipairs(sortt) do
		AddOutput(
			string.format(threshcolors[1] .. "%d|r (%d) | %s%s|r", eventcounts[ev], eventargs[ev], threshcolors[4], ev),
			string.format("%d (%d) | %s", eventcounts[ev], eventargs[ev], ev)
		)
	end
	AddOutput("------------")
end

function WarmupContinued:ADDON_LOADED(addon)
	local addonmem = collectgarbage("count")
	local lastmem = table.remove(memstack) or 0
	local lasttime = stop() / 1000
	local diff = addonmem - lastmem

	if not startupAttributionActive and not leftworld then
		table.insert(memstack, addonmem)
		start()
		return
	end

	totalgameloadtime = totalgameloadtime + lasttime

	local gcmem = addonmem
	local garbage
	if IsGCEnabled() then
		start()
		collectgarbage("collect")
		gctime = gctime + stop() / 1000
		gcmem = collectgarbage("count")
		garbage = addonmem - gcmem
	end

	if not sv then self:Init() end

	local retainedMem = diff - (garbage or 0)
	local ms = math.floor(lasttime * 1000 + 0.5)

	if addon and addon:match("^Blizzard_") then
		table.insert(sessionBlizzardAddons, {
			name = addon,
			time = lasttime,
			mem = retainedMem,
			garbage = garbage,
			ms = ms,
		})
		table.insert(memstack, gcmem)
		start()
		return
	end

	totaltime = totaltime + lasttime

	local history = sv.addonHistory[addon] or {}
	table.insert(history, ms)
	if #history > 20 then
		table.remove(history, 1)
	end
	sv.addonHistory[addon] = history
	sv.lastAddonMs[addon] = ms

	sessionAddonCount = sessionAddonCount + 1
	sessionAddonOrder[sessionAddonCount] = addon
	sessionAddonLastMs[addon] = ms

	table.insert(sv.addoninfo, PutOutAO(sessionAddonCount, addon, lasttime, retainedMem, garbage, ms))
	if UpdateSummaryChart then UpdateSummaryChart() end

	if lasttime > longesttime then
		longesttime = lasttime
		longestaddon = addon
	end
	if retainedMem > biggestmem then
		biggestmem = retainedMem
		biggestaddon = addon
	end
	if garbage and garbage > mostgarbage then
		mostgarbage = garbage
		mostgarbageaddon = addon
	end
	totalgarbage = totalgarbage + (garbage or 0)
	totalmem = totalmem + diff
	table.insert(memstack, gcmem)
	start()
end

function WarmupContinued:VARIABLES_LOADED()
	if varsloadtime then return end
	stop()

	if IsGCEnabled() then
		start()
		collectgarbage("collect")
		gctime = gctime + stop() / 1000
	end

	local lastmem = collectgarbage("count")

	varsloadtime = GetTime()
	local mostGarbageLabel = mostgarbageaddon or "None"
	local longestAddonLabel = longestaddon or "None"
	local biggestAddonLabel = biggestaddon or "None"

	PutOut("Addon Loadup", threshcolors[4], totaltime, lastmem - initmem, totalgarbage)
	PutOut("Warmup's Garbage Collection", threshcolors[4], gctime)
	PutOut("Longest addon: " .. longestAddonLabel, threshcolors[2], longesttime)
	PutOut("Biggest addon: " .. biggestAddonLabel, threshcolors[2], nil, biggestmem)
	PutOut("Most Garbage: " .. mostGarbageLabel, threshcolors[2], nil, mostgarbage)
	if UpdateSummaryChart then UpdateSummaryChart() end

	pendingOverallRecord = true

	SlashCmdList["WARMUPCONTINUED"] = function()
		containerFrame:SetShown(not containerFrame:IsShown())
	end

	SLASH_WARMUPCONTINUED1 = "/wuc"
	SLASH_WARMUPCONTINUED2 = "/warmupcontinued"
	SLASH_WARMUPCONTINUED3 = "/warmup"
	SLASH_WARMUPCONTINUED4 = "/wu"

	function WarmupContinued_OnAddonCompartmentClick()
		containerFrame:SetShown(not containerFrame:IsShown())
	end

	if IsGCEnabled() then
		collectgarbage("restart")
	end
	start()
end

function WarmupContinued:PLAYER_LOGIN()
	if not sv then self:Init() end
	table.insert(UISpecialFrames, "WarmupContinuedOutputFrame")
	if sv.reloadingUI then
		sv.reloadingUI = nil
	end
	if sv.showOnStartup then
		C_Timer.After(2, function()
			if not UnitAffectingCombat("player") then
				containerFrame:Show()
			end
		end)
	end
	logging = true
end

function WarmupContinued:PLAYER_ENTERING_WORLD()
	if not pendingOverallRecord and not leftworld then
		return
	end
	if pendingOverallRecord then
		local entrytime = stop() / 1000
		local totalTime = entrytime + totaltime + gctime
		local totalGameLoadTime = entrytime + totalgameloadtime + gctime
		table.insert(sv.totalLoadHistory, {
			sec = totalTime,
			at = date("%m/%d %H:%M:%S"),
		})
		if #sv.totalLoadHistory > 50 then
			table.remove(sv.totalLoadHistory, 1)
		end
		PutOut("World entry", threshcolors[4], entrytime)
		PutOut("Total time", threshcolors[4], totalTime)
		if #sessionBlizzardAddons > 0 then
			PutOut("Blizzard addon load time breakdown", threshcolors[4])
			for i = 1, #sessionBlizzardAddons do
				local blizzardAddon = sessionBlizzardAddons[i]
				PutOutAO(i, blizzardAddon.name, blizzardAddon.time, blizzardAddon.mem, blizzardAddon.garbage, blizzardAddon.ms)
			end
		end
		PutOut("Total game load time (including Blizzard)", threshcolors[4], totalGameLoadTime)
		sv.time = nil
		varsloadtime = nil
		pendingOverallRecord = false
		startupAttributionActive = false

		frame:UnregisterEvent("PLAYER_LOGIN")
		frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
	elseif leftworld then
		PutOut("Zoning", threshcolors[4], stop() / 1000)
		leftworld = nil
	end

	logging = nil
	eventcounts = nil
end

function WarmupContinued:PLAYER_LEAVING_WORLD()
	sv.time = GetTime()
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
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("PLAYER_LOGOUT")