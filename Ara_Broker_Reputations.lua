--Version detection
local wowtextversion
if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then wowtextversion = "Classic" end 
if WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then wowtextversion = "TBC Classic" end
if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then wowtextversion = "Retail" end 

local addonName = ...
local BUTTON_HEIGHT, ICON_SIZE, GAP, TEXT_OFFSET, SIMPLE_BAR_WIDTH, ASCII_LENGTH, FONT_SIZE, MAX_ENTRIES =
       14,          13,     10,      3,            110,             30,          11
local f = CreateFrame("Frame", "AraReputation", UIParent, BackdropTemplateMixin and "BackdropTemplate")
local configMenu, options, ColorPickerChange, ColorPickerCancel, OpenColorPicker, SetOption, textures
local factions, config, char, UpdateTablet, UpdateBar = {}
local updateBeforeBlizzard, watchedFaction, watchedIndex, focusedButton
local sliderValue, hasSlider, c, nbEntries = 0
local prevSkin, tiptacBG, tiptacGradient
local defaultTexture = "Interface\\TargetingFrame\\UI-StatusBar"
local defaultConfig = {
    scale = 1.1,
    blockDisplay = "text",
    asciiBar = "dualColors",
    textFaction = true,
    textFactionColor = "blizzard",
    textStanding = true,
    textPerc = true,
    textValues = false,
    textParagon = true,
    showParagonCount = true,
    barTexture = defaultTexture,
    blizzColorsInstead = false,
    blizzColorsInsteadBroker = false,
    blizzColorsDefault = false,
    blizzardColors = FACTION_BAR_COLORS,  --hack to add back Blizzard colors
    asciiColors = {
        { r= .54, g= 0,   b= 0   }, -- hated
        { r= 1,   g= .10, b= .1  }, -- hostile
        { r= 1,   g= .55, b= 0   }, -- unfriendly
        { r= .87, g= .87, b= .87 }, -- neutral
        { r= 1,   g= 1,   b= 0   }, -- friendly
        { r= .1,  g= .9,  b= .1  }, -- honored
        { r= .25, g= .41, b= .88 }, -- revered
        { r= .6,  g= .2,  b= .8  }, -- exalted
        { r= .4,  g= 0,   b= .6  }, -- past exalted
    },
    useTipTacSkin = true,
}
local levelshift = {
	[2472] = 2,  -- The Archivists' Codex
	[2464] = 3,  -- Court of Night
	[2432] = 2,  -- Ve'nari
	[2135] = 1,  -- Chromie
	[1358] = 2,  -- Anglers / Nat Pagle
	[1273] = 2,  -- Tillers / Jogu the Drunk
	[1275] = 2,  -- Tillers / Ella
	[1276] = 2,  -- Tillers / Old Hillpaw
	[1277] = 2,  -- Tillers / Chee Chee
	[1278] = 2,  -- Tillers / Sho
	[1279] = 2,  -- Tillers / Haohan Mudclaw
	[1280] = 2,  -- Tillers / Tina Mudclaw
	[1281] = 2,  -- Tillers / Gina Mudclaw
	[1282] = 2,  -- Tillers / Fish Fellreed
	[1283] = 2,  -- Tillers / Farmer Fung
}
table.insert(defaultConfig.blizzardColors,{ r= 0,   g= .6,  b= .1  })

local defaultCharConfig = {
    collapsedHeaders = {},
}
local defaultColor = { r=.8, g=.8, b=.8 }

local backdrop = { bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=false, tileSize=0, edgeSize=14, insets = { left=3, right=3, top=3, bottom=3 } }

local GetFactionInfo, FACTION_INACTIVE, GUILD, OTHER =
    GetFactionInfo, FACTION_INACTIVE, GUILD, OTHER

--local Friends = {1273, 1275, 1276, 1277, 1278, 1279, 1280, 1281, 1282, 1283, 1358, 1733, 1736, 1737, 1738, 1739, 1740, 1741, 1975, 2135}

local levels = {} for i=1,8 do levels[i]=_G["FACTION_STANDING_LABEL"..i] end
table.insert(levels,"Paragon") -- Insert Paragon description into table

local colors = { "8b0000", "ff1919", "ff8c00", "dddddd", "ffff00", "19e619", "4169e1", "9932cc", "67009a" }
local nameColors = { "ff1919", "ff1919", "ffff00", "19ff19", "19ff19", "19ff19", "19ff19", "19ff19" }

local tt, startingRep, info = {}, {}, {}
local tables = setmetatable( {}, { __mode = "k" } )

local function new(...)
    local t = next(tables)
    if t then tables[t] = nil else t = {} end
    for i = 1, select( "#", ... ), 2 do
        local key, value = select( i, ... )
        t[key] = value
    end
    return t
end

local highlight = f:CreateTexture()
highlight:SetTexture"Interface\\QuestFrame\\UI-QuestTitleHighlight"
highlight:SetBlendMode"ADD"
highlight:SetAlpha(0)


local modules = {}

function f:AddModule(name, module)
    modules[name] = module
end

function CallModule(funcName, ...)
    for moduleName, module in next, modules do
        if module[funcName] then module[funcName](module, ...) end
    end
end

local merk 

local function Menu_OnEnter(self)
    if self and self.rep then
        highlight:SetAllPoints(self)
        highlight:SetAlpha(1)
        self.hovered = true
        if not config.showSeparateValues and not config.showRawInstead then 
            self.fs:SetText(self.rep.textValue) 
        end
        CallModule("OnEnterFaction", self)
    end
end

local function Menu_OnLeave(self)
    highlight:ClearAllPoints()
    if self and self.rep then
        self.hovered = nil
        highlight:SetAlpha(0)
        if not config.showSeparateValues and not config.showRawInstead then
            self.fs:SetText(levels[self.rep.level])
            --For Retail and Beta, get friends
            if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
                local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(self.rep.FactionID)
                if (friendID ~= nil) then
                    self.fs:SetText(friendTextLevel)  --self.fs:SetText(select(7,GetFriendshipReputation(tonumber(self.rep.FactionID))))           
                end
            end
        end
        CallModule("OnLeaveFaction", self)
    end
    if not f:IsMouseOver() then f:Hide() end
end


local orgSetWatchedFactionIndex = SetWatchedFactionIndex
function SetWatchedFactionIndex(...)
    orgSetWatchedFactionIndex(...)
    watchedFaction = GetFactionInfo(...)
    watchedIndex = ...
    updateBeforeBlizzard = true
    UpdateBar()
end


local function Faction_OnClick(self, button)
    local rep = self.rep
    if rep.header and not IsControlKeyDown() then
        if rep.collapsed then ExpandFactionHeader(rep.index) else CollapseFactionHeader(rep.index) end
        char.collapsedHeaders[rep.name] = not rep.collapsed
        UpdateTablet()
    elseif button == "MiddleButton" then
        if rep.inactive then SetFactionActive(rep.index) else SetFactionInactive(rep.index) end
        UpdateTablet()
    elseif button == "RightButton" then
        if not rep.showValue then return end
        --For Retail and Beta, get friends
        if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
            local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(rep.FactionID)
        else
            local friendID = nil
        end
        if (friendID ~= nil) then
            if rep.textValue == (friendTextLevel) then
                ChatFrame_OpenChat(rep.name.." - "..friendTextLevel, DEFAULT_CHAT_FRAME)
            else
                ChatFrame_OpenChat(rep.name.." - "..friendTextLevel.." - "..rep.textValue, DEFAULT_CHAT_FRAME)
            end
        else
            if rep.textValue == levels[8] then
                ChatFrame_OpenChat(rep.name.." - "..levels[rep.level], DEFAULT_CHAT_FRAME)
            else
                ChatFrame_OpenChat(rep.name.." - "..levels[rep.level].." - "..rep.textValue, DEFAULT_CHAT_FRAME)
            end
        end
    else
        SetWatchedFactionIndex( GetWatchedFactionInfo() == rep.name and 0 or rep.index)
        if focusedButton and focusedButton.rep.name then focusedButton.faction:SetText( (rep.header and "|cffffffff" or "|cffffd100")..focusedButton.rep.name ) end
        if watchedIndex ~= 0 then self.faction:SetText( "|cffe67319"..rep.name ) end
        focusedButton = self
    end
end


local function Scroll(self, delta)
    if IsControlKeyDown() then
        config.scale = config.scale - delta * 0.05
        return UpdateTablet()
    end
    slider:SetValue( sliderValue - delta * (IsModifierKeyDown() and 10 or 3) )
end

local baseFont = GameFontNormal:GetFont()
local buttons = setmetatable( {}, { __index = function(table, index)
    local button = CreateFrame("Button", nil, f)
    rawset( table, index, button )

    button:RegisterForClicks"AnyUp"
    button:SetHeight( BUTTON_HEIGHT )
    button:SetScript("OnEnter", Menu_OnEnter)
    button:SetScript("OnLeave", Menu_OnLeave)
    button:EnableMouseWheel(true)
    button:SetScript( "OnMouseWheel", Scroll)

    button.icon = button:CreateTexture()
    button.icon:SetWidth(ICON_SIZE) button.icon:SetHeight(ICON_SIZE)
    button.icon:SetPoint("LEFT", button)

    button.faction = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")-- "SystemFont_Shadow_Med1"
    button.faction:SetFont( baseFont, FONT_SIZE )
    button.faction:SetPoint("LEFT", button.icon, "RIGHT", TEXT_OFFSET, 0)

    button.fs = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.fs:SetFont( baseFont, FONT_SIZE )
    button.fs:SetWidth(SIMPLE_BAR_WIDTH)
    button.fs:SetJustifyH"CENTER"

    button.bar = button:CreateTexture(nil, "OVERLAY", button)
    button.bar:SetWidth(SIMPLE_BAR_WIDTH) button.bar:SetHeight(BUTTON_HEIGHT-4)
    button.bar:SetPoint("LEFT", button.fs)

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetWidth(SIMPLE_BAR_WIDTH+2) button.bg:SetHeight(BUTTON_HEIGHT-2)
    button.bg:SetTexture(0,0,0,.5)
    button.bg:SetPoint("LEFT", button.fs, "LEFT", -1, 0)

    button.values = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.values:SetFont( baseFont, FONT_SIZE )
    button.values:SetJustifyH"CENTER"
    button.values:SetPoint("LEFT", button.fs, "RIGHT", GAP, 0 )

    button.session = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.session:SetFont( baseFont, FONT_SIZE )
    button.session:SetJustifyH"RIGHT"

    button.togo = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.togo:SetFont( baseFont, FONT_SIZE )
    button.togo:SetJustifyH"RIGHT"

    return button
end } )


local function UpdateScrollButtons(nbEntries)
    for i=1, sliderValue do buttons[i]:Hide() end
    for i=nbEntries+1, #buttons do buttons[i]:Hide() end
    for i=1, nbEntries do
        button = buttons[sliderValue+i]
        button:SetPoint("TOPLEFT", f, "TOPLEFT", GAP, BUTTON_HEIGHT*(1-i) - GAP)
        button:Show()
    end
end

local function AddHint(hint)
    nbEntries = nbEntries + 1
    button = buttons[nbEntries]
    button:SetScript("OnClick", nil)
    button.rep = nil
    button.icon:SetTexture""
    button.faction:SetText(hint)
    button.bar:Hide() button.bg:Hide() button.fs:Hide() button.values:Hide() button.togo:Hide() button.session:Hide()
    button.icon:SetPoint("LEFT", button, "LEFT", -ICON_SIZE-TEXT_OFFSET, 0)
end

UpdateTablet = function(self)
    CloseDropDownMenus()
    f:SetScale( config.scale )
    MAX_ENTRIES = floor( (UIParent:GetHeight() / config.scale - GAP*2) / BUTTON_HEIGHT - 4 / config.scale )

    local menuFactionWidth, menuValuesWidth, menuToGoWidth, menuSessionWidth = 0, 0, 0, 0
    local itemFactionWidth, itemValuesWidth, itemToGoWidth, itemSessionWidth, button, inactive

    for i, f in next, factions do
        tables[wipe(f)] = true
        factions[i] = nil
    end

    local inactive, skip, skipChild
    nbEntries = 0

    for i = 1, GetNumFactions() do
        local pValTtl = nil
        local name, showValue, level, minVal, maxVal, value, atWar, canBeAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, FactionID = GetFactionInfo(i)
        pNum = nil
        if name then
        if isHeader and not (isChild and skipChild) then
            skip = char.collapsedHeaders[name]
            skipChild = skip and not isChild
        end
        if not skip or isHeader and not (isChild and skipChild) then
            local standingText = levels[level]
            local isCapped = level == MAX_REPUTATION_REACTION
            --If not Classic, do Paragon config
            if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
                if (FactionID and C_Reputation.IsFactionParagon(FactionID)) then
                    local currValue, threshold, rewardQuestID, hasRewardPending = C_Reputation.GetFactionParagonInfo(FactionID)
                    local pMin = currValue - (currValue % threshold)
                    local pMax = pMin + threshold
                    pValTtl = currValue
                    value   = value + currValue
                    minVal  = minVal + pMin
                    maxVal  = maxVal + pMax
                    pNum = pMin/threshold
                    level   = MAX_REPUTATION_REACTION + 1
                    standingText = levels[level]
                    isCapped = false
                    textValue = ("%i / %i"):format(value-minVal, maxVal-minVal)
                end
                -- check if this is a friendship faction 
                local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(FactionID)
                if (friendID ~= nil) then
                    name = friendName
                    standingText = friendTextLevel
                    if ( nextFriendThreshold ) then
                        minVal, maxVal, value = friendThreshold, nextFriendThreshold, friendRep
                    elseif (friendID and C_Reputation.IsFactionParagon(friendID)) then
						isCapped = false
					else
                        isCapped = true
                    end
                end
            end
            if isCapped then 
                textValue = standingText
            else
                if pNum ~= nil and config.showParagonCount then
                    textValue = ("%i / %i"):format(value-minVal, maxVal-minVal) .. ' ('..pNum..')'
                else
                    textValue = ("%i / %i"):format(value-minVal, maxVal-minVal) 
                end
            end

            nbEntries = nbEntries + 1
            showValue = not isHeader or hasRep
            if isHeader and name == FACTION_INACTIVE then inactive = true end
            isCollapsed = char.collapsedHeaders[name] or isCollapsed
            factions[#factions+1] = new(
                "index", i,
                "name", name,
                "header", isHeader,
                "showValue", showValue,
                "level", level,
                "collapsed", isCollapsed,
                "inactive", inactive,
                "textValue", textValue,
                "FactionID", FactionID
            )
            button = buttons[nbEntries]
            button:SetScript("OnClick", Faction_OnClick)
            button.rep = factions[#factions]
            button.faction:SetText( (name == watchedFaction and "|cffe67319" or isHeader and "|cffffffff" or "|cffffd100")..name )
            if name == watchedFaction then focusedButton = button end

            if showValue then
                local perc = 0
				local colorshift = 0
                if isCapped then perc = 1 else perc = (value - minVal) / (maxVal - minVal) end
                if level > 9 then level = 9 end
				if config.applyColorShift and FactionID and levelshift[FactionID] then colorshift = levelshift[FactionID] end
                if colorshift > 0 and (level+colorshift) > 9 then colorshift = 9 - level end
                local color = config.blizzColorsInstead and config.blizzardColors[level+colorshift] or config.asciiColors[level+colorshift]
                button.bar:SetVertexColor( color.r, color.g, color.b )
                button.bar:SetWidth( SIMPLE_BAR_WIDTH * (perc == 0 and 0.0001 or perc) )
                button.bar:SetTexture(config.barTexture)
                if config.showRawInstead and not config.showSeparateValues then
                    button.fs:SetText(button.rep.textValue)
                else
                    button.fs:SetText( levels[level] )
                    if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
                        local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(FactionID)
                        if (friendID ~= nil) then
                            button.fs:SetText( friendTextLevel )
                        end
                    end
                end
                button.bar:Show() button.fs:Show()
                if config.showSeparateValues then button.values:SetText(button.rep.textValue) end
                if config.showRepToGo then button.togo:SetText( button.rep.level == 8 and "-" or maxVal - value ) end
                if config.showSessionGain then
                    local gain = 0
                    if pValTtl then
                        if not startingRep[name] then startingRep[name] = pValTtl end
                        gain = pValTtl - startingRep[name]
                    else
                        if not startingRep[name] then startingRep[name] = value end
                        gain = value - startingRep[name]
                    end
                    button.session:SetText( gain == 0 and "-" or gain)
                end
            else
                button.bar:Hide() button.fs:Hide() button.bg:Hide()
                if nbEntries > 1 then button.values:Hide() button.togo:Hide() button.session:Hide() end
            end
            button.icon:SetTexture(not isHeader and "" or isCollapsed and "Interface\\Buttons\\UI-PlusButton-UP" or "Interface\\Buttons\\UI-MinusButton-UP")
            button.icon:SetPoint("LEFT", button, "LEFT", isChild and ICON_SIZE + TEXT_OFFSET or 0, 0)

            if nbEntries == 1 then
                button.togo:SetText("|cffffffffTo Go")
                button.session:SetText("|cffffffffSession")
            end
            itemFactionWidth = button.faction:GetStringWidth() + (isChild and ICON_SIZE + TEXT_OFFSET or 0)
            if itemFactionWidth > menuFactionWidth then menuFactionWidth = itemFactionWidth end
            itemValuesWidth = button.values:GetStringWidth()
            if itemValuesWidth > menuValuesWidth then menuValuesWidth = itemValuesWidth end
            itemToGoWidth = button.togo:GetStringWidth()
            if itemToGoWidth > menuToGoWidth then menuToGoWidth = itemToGoWidth end
            itemSessionWidth = button.session:GetStringWidth()
            if itemSessionWidth > menuSessionWidth then menuSessionWidth = itemSessionWidth end
        end;end
    end

    if config.showHints then
        AddHint""
        AddHint"|cffff8020Click |cff33ff33to |cffffd100watch faction |cff33ff33or |cffffffffexpand/collapse|cff33ff33."
        AddHint"|cffff8020Right-Click |cff33ff33to copy to chatbox."
        AddHint"|cffff8020Middle-Click |cff33ff33to move to active/inactive."
        AddHint"|cffff8020Ctrl+MouseWheel |cff33ff33to resize tooltip."
    end

    local valuesX = ICON_SIZE + TEXT_OFFSET + menuFactionWidth + GAP
    local togoX =  valuesX + SIMPLE_BAR_WIDTH + (config.showSeparateValues and GAP + menuValuesWidth or 0)
    local sessionX = togoX + (config.showRepToGo and GAP + menuToGoWidth or 0)
    local buttonWidth = sessionX + (config.showSessionGain and GAP + menuSessionWidth + TEXT_OFFSET or 0)

    for i=1, nbEntries do
        button = buttons[i]
        button:SetWidth(buttonWidth)
        button.fs:SetPoint("LEFT", button, "LEFT", valuesX, 0)
        if button.rep then
            if button.rep.showValue then button.bg:Show() else button.bg:Hide() end
            if button.rep.showValue or i == 1 then
                if config.showSeparateValues then
                    button.values:SetWidth(menuValuesWidth)
                    button.values:Show()
                else    button.values:Hide() end
                if config.showRepToGo then
                    button.togo:SetPoint("LEFT", button, "LEFT", togoX, 0)
                    button.togo:SetWidth(menuToGoWidth+GAP)
                    button.togo:Show()
                else    button.togo:Hide() end
                if config.showSessionGain then
                    button.session:SetPoint("LEFT", button, "LEFT", sessionX, 0)
                    button.session:SetWidth(menuSessionWidth+GAP)
                    button.session:Show()
                else    button.session:Hide() end
            end
        end
    end

    if config.sortByRep then
        local currentSiblings = {}
        local currentFirstID = nil
        local compareFunc = function(a,b)
            if a.rep.level == b.rep.level then
                local aRep          = nil
                local bRep          = nil
                local repSortByName = false
                -- As of the Legion update where Paragon rep was added, Exalted rep and Best Friend rep 
                -- no longer return numerical values.  As they don't, this new code sorts those factions
                -- alphabetically by name (within Exalted or Best Friend)
                -- This also fixes an error where tonumber(aRep) and tonumber (bRep) for Exalted and 
                -- Best Friend were causing errors because they return nil as the numeric rep value
                if a.rep.textValue == levels[8] then 
                    --Exalted Rep
                    repSortByName = true
                elseif a.rep.textValue == (select(7,GetFriendshipReputation(tonumber(a.rep.FactionID)))) then
                    --Best Friend Rep
                    repSortByName = true
                else
                    aRep = string.gsub(a.rep.textValue, "/.+", "")
                end
                if b.rep.textValue == levels[8] then
                    --Exalted Rep
                    repSortByName = true
                elseif b.rep.textValue == (select(7,GetFriendshipReputation(tonumber(b.rep.FactionID)))) then
                    --Best Friend Rep
                    repSortByName = true
                else
                    bRep = string.gsub(b.rep.textValue, "/.+", "")
                end
                
                if repSortByName then 
                    return a.rep.name < b.rep.name
                else
                    return tonumber(aRep) > tonumber(bRep)
                end
            end
        end
    
        for i=1, nbEntries do
            button = buttons[i]
            
            if button.rep then
                if button.rep.header then
                    if #currentSiblings > 0 then
                        table.sort(currentSiblings, compareFunc)
                        
                        for j, btn in ipairs(currentSiblings) do
                            local cur = currentFirstID + j - 1
                            buttons[cur] = btn
                        end
                        
                        table.wipe(currentSiblings)
                        currentFirstID = nil
                    end
                else
                    if not currentFirstID then
                        currentFirstID = i
                    end
                    
                    currentSiblings[#currentSiblings + 1] = button
                end
            end
        end
    end
    
    local maxEntries = math.min(MAX_ENTRIES, nbEntries)
    local maxValue = math.max( 0, nbEntries - MAX_ENTRIES )
    slider:SetMinMaxValues( 0, maxValue )
    slider:SetValue( math.min( sliderValue, maxValue ) )
    hasSlider = nbEntries > MAX_ENTRIES
    if hasSlider then slider:Show() else slider:Hide() end

    UpdateScrollButtons(maxEntries)
    if hasSlider then
        slider:SetHeight(BUTTON_HEIGHT*(MAX_ENTRIES+1))
        slider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, BUTTON_HEIGHT*.5 - GAP)
    end
    f:SetWidth( buttonWidth + GAP*2 + (hasSlider and 16 + TEXT_OFFSET*2 or 0) )
    f:SetHeight( BUTTON_HEIGHT * maxEntries + GAP*2 )

    if not (f.onBlock or f:IsMouseOver()) then f:Hide() end
end


local function Block_OnClick(self, button)
    if button == "LeftButton" then
        ToggleCharacter"ReputationFrame"
    elseif button == "RightButton" then
        f:Hide()
        if not configMenu then f:SetupConfigMenu() end
        configMenu.scale = UIParent:GetScale()
        ToggleDropDownMenu(1, nil, configMenu, self, 0, 0)
    end
end


local function SetSkin()
    if config.useTipTacSkin and TipTac then
        tiptacBG = tiptacBG or { tile=false, insets={} }
        local cfg = TipTac_Config
        tiptacBG.bgFile = cfg.tipBackdropBG
        tiptacBG.edgeFile = cfg.tipBackdropEdge
        tiptacBG.edgeSize = cfg.backdropEdgeSize
        tiptacBG.insets.left = cfg.backdropInsets
        tiptacBG.insets.right = cfg.backdropInsets
        tiptacBG.insets.top = cfg.backdropInsets
        tiptacBG.insets.bottom = cfg.backdropInsets
        f:SetBackdrop(tiptacBG)
        f:SetBackdropColor(unpack(cfg.tipColor))
        f:SetBackdropBorderColor(unpack(cfg.tipBorderColor))
        if not cfg.gradientTip then
            return tiptacGradient and tiptacGradient:Hide()
        elseif not tiptacGradient then
            tiptacGradient = f:CreateTexture()
            tiptacGradient:SetTexture(1,1,1,1)
        end
        tiptacGradient:SetGradientAlpha("VERTICAL",0,0,0,0,unpack(cfg.gradientColor))
        tiptacGradient:SetPoint("TOPLEFT",cfg.backdropInsets,-cfg.backdropInsets)
        tiptacGradient:SetPoint("BOTTOMRIGHT",f,"TOPRIGHT",-cfg.backdropInsets,-36)
        tiptacGradient:Show()
    elseif Skinner then
        Skinner:applySkin(f)
    else
        if tiptacGradient then tiptacGradient:Hide() end
        f:SetBackdrop(backdrop)
        f:SetBackdropColor( .1, .1, .1, .9 )
        f:SetBackdropBorderColor( .3, .3, .3, .9 )
        prevSkin = "default"
    end
end


local block = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("|cffffb366Ara|r Reputations", {
    type = "data source",
    icon = UnitFactionGroup"player" == "Horde" and "Interface\\Icons\\ability_warrior_warcry" or "Interface\\Icons\\spell_nature_enchantarmor",
    iconCoords = { 0.075, 0.925, 0.075, 0.925 },
    text = "No Faction",
    OnEnter = function(frame)
        CloseDropDownMenus()
        f.onBlock = true
        f:Show()
        f:ClearAllPoints()
        local showBelow = select(2, frame:GetCenter()) > UIParent:GetHeight()/2
        f:SetPoint(showBelow and "TOP" or "BOTTOM", frame, showBelow and "BOTTOM" or "TOP")
        SetSkin()
        UpdateTablet()
    end,
    OnLeave = function()
        f.onBlock = nil
        if not f:IsMouseOver() then f:Hide() end
    end,
    OnClick = Block_OnClick
} )

local firstCall = true

UpdateBar = function()
    local name, _, level, minVal, maxVal, value, FactionID
    if firstCall then
        for i=1, GetNumFactions() do
            local pValTtl = nil

            local name, showValue, level, minVal, maxVal, value, atWar, canBeAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, FactionID = GetFactionInfo(i)
            if name then
                if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
                    if (FactionID and C_Reputation.IsFactionParagon(FactionID)) then
                        local currValue, threshold, rewardQuestID, hasRewardPending = C_Reputation.GetFactionParagonInfo(FactionID)
                        pValTtl = currValue
                        if not isHeader or hasRep then startingRep[name] = pValTtl end
                    else
                        if not isHeader or hasRep then startingRep[name] = value end
                    end
                else
                    if not isHeader or hasRep then startingRep[name] = value end
                end
                if name == watchedFaction then FactionID = factID; watchedIndex = i end
            end
        end
        firstCall = false
    end

    if updateBeforeBlizzard then
        updateBeforeBlizzard = false
        name, _, level, minVal, maxVal, value, _, _, _, _, _, _, _, FactionID = GetFactionInfo(watchedIndex)
    else    
        if watchedIndex then
            name, _, level, minVal, maxVal, value, _, _, _, _, _, _, _, FactionID = GetFactionInfo(watchedIndex)
        else 
            name, level, minVal, maxVal, value = GetWatchedFactionInfo()
        end
    end

    if not name or name == OTHER then
        block.text = NOT_APPLICABLE--"No Faction"
        return
    end

    local pValTtl = nil
    local isCapped = level == MAX_REPUTATION_REACTION
    local standingText = levels[level]
    pNum = nil
    if FactionID then
        if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
            if (FactionID and C_Reputation.IsFactionParagon(FactionID)) then
                local currValue, threshold, rewardQuestID, hasRewardPending = C_Reputation.GetFactionParagonInfo(FactionID)
                local pMin = currValue - (currValue % threshold)
                local pMax = pMin + threshold
                pValTtl = currValue
                value   = value + currValue
                minVal  = minVal + pMin
                maxVal  = maxVal + pMax
                pNum = pMin/threshold
                level   = MAX_REPUTATION_REACTION + 1
                standingText = levels[level]
                isCapped = false
            end
            -- check if this is a friendship faction 
            local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(FactionID)
            if (friendID ~= nil) then
                name = friendName
                standingText = friendTextLevel
                if ( nextFriendThreshold ) then
                    minVal, maxVal, value = friendThreshold, nextFriendThreshold, friendRep
				elseif (friendID and C_Reputation.IsFactionParagon(friendID)) then
					isCapped = false
                else
                    isCapped = true
                end
            end
        else
            --not sure this is needed here
            --isCapped = true
        end
    end
    
    local c1, c2 = config.asciiColors[level], config.asciiColors[level]
    local perc = 0
    if isCapped then perc = 1 else perc = (value - minVal) / (maxVal - minVal) end

    if config.blockDisplay == "text" then
        wipe(tt)
        if level > 9 then level = 9 end
		local colorshift = 0
		if config.applyColorShift and FactionID and levelshift[FactionID] then colorshift = levelshift[FactionID] end
        if colorshift > 0 and (level+colorshift) > 9 then colorshift = 9 - level end
        local asciiColor = config.blizzColorsInsteadBroker and config.blizzardColors[level+colorshift] or config.asciiColors[level+colorshift]
        asciiColor = ("|cff%.2x%.2x%.2x"):format(asciiColor.r*255, asciiColor.g*255, asciiColor.b*255)
        if config.textStanding then
            tt[#tt+1] = (#tt>0 and "" or asciiColor)..standingText.."|r"
        end
        if config.textPerc then
            tt[#tt+1] = ("%s%i%%|r"):format(#tt>0 and "" or asciiColor, floor(perc*100))
        end
        if config.textValues then
            if not isCapped then
                if pNum ~= nil and config.textParagon then
                    tt[#tt+1] = ("%s%i/%i|r"):format(#tt>0 and "" or asciiColor, value - minVal, maxVal - minVal) .. ' ('..pNum..')'
                else
                    tt[#tt+1] = ("%s%i/%i|r"):format(#tt>0 and "" or asciiColor, value - minVal, maxVal - minVal)
                end
            end
        end
        if config.textToGo then
            if not isCapped then
                tt[#tt+1] = ("%s%i to go|r"):format(#tt>0 and "" or asciiColor, maxVal - value)
            else
                tt[#tt+1] = ("Capped|r") 
            end
        end
        if config.textSession then
            local gain = 0
            if pValTtl then
                if not startingRep[name] then startingRep[name] = pValTtl end
                gain = pValTtl - startingRep[name]
            else
                if not startingRep[name] then startingRep[name] = value end
                gain = value - startingRep[name]
            end
            tt[#tt+1] = ("%sSession %s%i|r"):format(#tt>0 and "" or asciiColor, gain >= 0 and "+" or "", gain)
        end
        if config.textFaction then
			local colorshift = 0
			if config.applyColorShift and FactionID and levelshift[FactionID] then colorshift = levelshift[FactionID] end
            if colorshift > 0 and (level+colorshift) > 9 then colorshift = 9 - level end
            local color = defaultColor
            if config.textFactionColor == "none"     then color = defaultColor end
            if config.textFactionColor == "ascii"    then color = config.asciiColors[level+colorshift] end 
            if config.textFactionColor == "blizzard" then color = config.blizzardColors[level+colorshift] end
            tinsert(tt,1, ("|cff%.2x%.2x%.2x%s|r"):format(color.r*255, color.g*255, color.b*255, name) )
        end
        block.text = table.concat(tt, " - ")
        wipe(tt)
    elseif config.blockDisplay == "ascii" then
        local steps = perc * ASCII_LENGTH
        if config.asciiBar == "singleColor" then c1 = defaultColor end
        block.text = ("|cff%.2x%.2x%.2x%s|cff%.2x%.2x%.2x%s"):format(
            c2.r*255, c2.g*255, c2.b*255, ("||"):rep(steps),
            c1.r*255, c1.g*255, c1.b*255, ("||"):rep(ASCII_LENGTH-steps) )
    end
end


local fsInc = FACTION_STANDING_INCREASED:gsub("%%d", "([0-9]+)"):gsub("%%s", "(.*)")
local fsInc2 = FACTION_STANDING_INCREASED_ACH_BONUS:gsub("%%d", "([0-9]+)"):gsub("%%s", "(.*)"):gsub(" %(%+.*%)" ,"")
local fsInc3 = FACTION_STANDING_INCREASED_GENERIC:gsub("%%s", "(.*)"):gsub(" %(%+.*%)" ,"")
local fsDec = FACTION_STANDING_DECREASED:gsub("%%d", "([0-9]+)"):gsub("%%s", "(.*)")

function f:CHAT_MSG_COMBAT_FACTION_CHANGE(msg)
    msg = msg:gsub(" %(%+.*%)" ,"")
    local faction, value, neg, updated = msg:match(fsInc)
    if not faction then
        faction, value, neg, updated = msg:match(fsInc2)
        if not faction then
            faction = msg:match(fsInc3)
            if not faction then
                faction, value = msg:match(fsDec)
                if not faction then return end
                neg = true
            end
        end
    end
    if tonumber(faction) then faction, value = value, tonumber(faction) else value = tonumber(value) end

    local switch = not neg and config.autoSwitch and (faction ~= GUILD or not config.exceptGuild)
    if faction == GUILD then faction = GetGuildInfo"player" end

    if switch or #modules>0 then
        for i = 1, GetNumFactions() do
            if GetFactionInfo(i) == faction then
                CallModule("OnFactionChange", faction, i)
                if switch then return SetWatchedFactionIndex(i) else break end
            end
        end
    end
    if faction == watchedFaction then UpdateBar() end
end


function f:SetupConfigMenu()
    configMenu = CreateFrame("Frame", "AraReputationConfigMenu")
    configMenu.displayMode = "MENU"

    options = {
    { text = ("Ara Reputations %s"):format( GetAddOnMetadata(addonName, "Version") ), isTitle = true },
    { text = ("WoW Version Detected: %s"):format( wowtextversion ), isTitle = true },
    { text = "Block Display", submenu = {
        { text = "ASCII Bar", radio = "blockDisplay", val = "ascii", submenu = {
            { text = "Single Color", radio = "asciiBar", val = "singleColor" },
            { text = "Dual Colors",  radio = "asciiBar", val = "dualColors" } } },
        { text = "Text", radio = "blockDisplay", val = "text", submenu = {
            { text = "Faction Name Color", radio = "textBlock", val = "factionNameColor", submenu = {
                { text = "No Color", radio = "textFactionColor", val = "default" },
                { text = "ASCII Color", radio = "textFactionColor", val = "ascii" },
                { text = "Blizzard Color",  radio = "textFactionColor", val = "blizzard" } } },
            { text = "Faction", check = "textFaction" },
            { text = "Standing", check = "textStanding" },
            { text = "Percentage", check = "textPerc" },
            { text = "Raw Numbers", check = "textValues" },
            { text = "Reputation To Go", check = "textToGo" },
            { text = "Session Gain", check = "textSession" }, 
            { text = "Paragon Count", check = "textParagon" } } } } },
    { text = "Tooltip Columns", submenu = {
        { text = "Show Raw Numbers instead of Standing", check = "showRawInstead" },
        { text = "Show Separate Raw Numbers", check = "showSeparateValues" },
        { text = "Show Reputation To Go", check = "showRepToGo" },
        { text = "Show Session Gain", check = "showSessionGain" },
        { text = "Show Paragon Count", check = "showParagonCount" } } },
    { text = "Bar Texture", submenu = function(self, level)
        local sharedMedia = LibStub"LibSharedMedia-3.0"
        for i, name in ipairs(sharedMedia and textures or {"Blizzard"}) do
            local texture = name == "Blizzard" and defaultTexture or sharedMedia.MediaTable.statusbar[name]
            if texture then
                info = wipe(info)
                info.text = name
                info.checked = config.barTexture == texture
                info.func, info.arg1, info.arg2 = SetOption, "barTexture", texture
                info.keepShownOnClick = true
                UIDropDownMenu_AddButton( info, level )
            end
        end
    end},
    { text = "Blizzard Colors", submenu = {
        { text = levels[1], color = "blizzardColors", index = 1 },
        { text = levels[2], color = "blizzardColors", index = 2 },
        { text = levels[3], color = "blizzardColors", index = 3 },
        { text = levels[4], color = "blizzardColors", index = 4 },
        { text = levels[5], color = "blizzardColors", index = 5 },
        { text = levels[6], color = "blizzardColors", index = 6 },
        { text = levels[7], color = "blizzardColors", index = 7 },
        { text = levels[8], color = "blizzardColors", index = 8 },
        { text = levels[9], color = "blizzardColors", index = 9 } } },
    { text = "ASCII Colors", submenu = {
        { text = levels[1], color = "asciiColors", index = 1 },
        { text = levels[2], color = "asciiColors", index = 2 },
        { text = levels[3], color = "asciiColors", index = 3 },
        { text = levels[4], color = "asciiColors", index = 4 },
        { text = levels[5], color = "asciiColors", index = 5 },
        { text = levels[6], color = "asciiColors", index = 6 },
        { text = levels[7], color = "asciiColors", index = 7 },
        { text = levels[8], color = "asciiColors", index = 8 },
        { text = levels[9], color = "asciiColors", index = 9 } } },
    { text = "Color Options", submenu = {
        { text = "Use Blizzard colors for broker", check = "blizzColorsInsteadBroker" },
        { text = "Use Blizzard colors for tooltip", check = "blizzColorsInstead" },
        { text = "Reload Blizzard colors on startup", check = "blizzColorsDefault" } } },
    { text = "Tooltip Size", submenu = {
        { text =  "90%", radio = "scale", val = 0.9 },
        { text = "100%", radio = "scale", val = 1.0 },
        { text = "110%", radio = "scale", val = 1.1 },
        { text = "120%", radio = "scale", val = 1.2 },
        { text = "Custom...", radio="scaleX", func=function() StaticPopup_Show"SET_ABR_SCALE" end } } },
    { text = "Auto switch on reputation gain", check = "autoSwitch", submenu = {
        { text = "Except for guild reputation", check = "exceptGuild" } } },
    { text = "Apply Color Shift for special Factions", check = "applyColorShift" }, 
    { text = "Sort by Reputation Level", check = "sortByRep" }, 
    { text = "Use TipTac skin (requires TipTac)", check = "useTipTacSkin" },
    { text = "Show Hints", check = "showHints" },
    }
    for k, m in next, modules do
        if m.options then
            for _, v in ipairs(m.options) do
                options[#options+1] = v
            end
        end
    end

    ColorPickerChange = function() c.r, c.g, c.b = ColorPickerFrame:GetColorRGB() UpdateBar() end
    ColorPickerCancel = function(prev) c.r, c.g, c.b = unpack(prev) UpdateBar() end
    OpenColorPicker = function(self, col, index)
        c = config[col][index]
        ColorPickerFrame.previousValues = { c.r, c.g, c.b }
        ColorPickerFrame.func = ColorPickerChange
        ColorPickerFrame.cancelFunc = ColorPickerCancel
        ColorPickerFrame:SetColorRGB( c.r, c.g, c.b )
        ColorPickerFrame:Show()
    end

    SetOption = function(bt, var, val, checked)
        config[var] = val or checked
        if var == "blockDisplay" or var == "asciiBar" or var:sub(1, 4) == "text" then UpdateBar() end
        if var == "blizzColorsInsteadBroker" then UpdateBar() end
        if not val then return end

        local sub = bt:GetName():sub(1, 19)
        for i = 1, bt:GetParent().numButtons do
            if _G[sub..i] == bt then _G[sub..i.."Check"]:Show() else _G[sub..i.."Check"]:Hide() _G[sub..i.."UnCheck"]:Show() end
        end
    end

    textures = { "Armory", "BantoBar", "Blizzard", "Glaze", "LiteStep", "Minimalist", "Otravi", "Smooth", "Smooth v2" }

    f.SetCustomScale = function(self,dialog)
        local val = tonumber( self.editBox:GetText():match"(%d+)" )
        if not val or val<70 or val>200 then
            baseScript = BasicScriptErrors:GetScript"OnHide"
            BasicScriptErrors:SetScript("OnHide",Error_OnHide)
            BasicScriptErrorsText:SetText"Invalid scale.\nShould be a number between 70 and 200%"
            return BasicScriptErrors:Show()
        end
        config.scale = val/100
    end

    StaticPopupDialogs.SET_ABR_SCALE = {
        text = "Set a custom tooltip scale.\nEnter a value between 70 and 200 (%%).",
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = 1,
        maxLetters = 4,
        OnAccept = AraReputation.SetCustomScale,
        OnShow = function(self) CloseDropDownMenus() self.editBox:SetText(config.scale*100) self.editBox:SetFocus() end,
        OnHide = ChatEdit_FocusActiveWindow,
        EditBoxOnEnterPressed = function(self) local p=self:GetParent() AraReputation:SetCustomScale(p) p:Hide() end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0,
        exclusive = 1,
        whileDead = 1,
        hideOnEscape = 1
    }

    configMenu.initialize = function(self, level)
        if not level then return end
        if level > 1 and type(UIDROPDOWNMENU_MENU_VALUE) == "function" then
            return UIDROPDOWNMENU_MENU_VALUE(self, level)
        end

        for i, v in ipairs( level > 1 and UIDROPDOWNMENU_MENU_VALUE or options ) do
            local adjust
            info = wipe(info)
            info.text = v.text
            info.isTitle, info.hasArrow, info.value = v.isTitle, v.submenu ~= nil, v.submenu
            if v.radio then
                if v.radio == "scaleX" then
                    info.checked = config.scale ~= .9 and config.scale ~= 1 and config.scale ~= 1.1 and config.scale ~= 1.2
                    info.func = v.func
                    if info.checked then
                        info.text = ("%s (%i%%)"):format(info.text, config.scale*100)
                    end
                else
                    info.checked = config[v.radio] == v.val
                    info.func, info.arg1, info.arg2 = SetOption, v.radio, v.val
                    info.keepShownOnClick = true
                end
            elseif v.check then
                info.checked = config[v.check]
                info.func, info.arg1 = SetOption, v.check
                info.keepShownOnClick = true
                info.isNotRadio = true
            elseif v.color then
                c = config[v.color][v.index]
                info.r, info.g, info.b = c.r, c.g, c.b
                info.hasColorSwatch, info.notCheckable, info.notClickable, info.padding = true, true, false, 10
                info.swatchFunc = function() OpenColorPicker(self, v.color, v.index) end
                info.func, info.arg1, info.arg2 = OpenColorPicker, v.color, v.index
            end
            if level==1 and not info.func then
                info.text = ("       %s"):format(info.text)
                info.notCheckable = true
                info.keepShownOnClick = true
                adjust = v.submenu
            end
            UIDropDownMenu_AddButton(info, level)
            if adjust then
                local frame = _G[("DropDownList1Button%i"):format(DropDownList1.numButtons)]
                frame:SetPoint("TOPLEFT", 11, select(5,frame:GetPoint())) --
            end
        end
    end

    f.SetupConfigMenu = nil
end

local function FirstUpdate()
    f:SetScript("OnUpdate", nil)
    f:Hide()
    watchedFaction = GetWatchedFactionInfo()
    UpdateBar()
end

local function Init()
    f:SetScript("OnUpdate", FirstUpdate)
end

function f:ADDON_LOADED(addon)
    if addon ~= addonName then return end

    AraReputationsDB = AraReputationsDB or defaultConfig
    if not AraReputationsDB.blizzardColors[9] then table.insert(AraReputationsDB.blizzardColors,{ r= 0,   g= .6,  b= .1  }) end --insert Paragon color
    config = AraReputationsDB
    for k, v in next, defaultConfig do -- easy upgrade
        if config[k] == nil then config[k] = v end
    end

    local charPath = GetRealmName().." - "..GetUnitName"player"
    config[charPath] = config[charPath] or defaultCharConfig
    char = config[charPath]
    for k, v in next, defaultCharConfig do
        if char[k] == nil then char[k] = v end
    end

    if config.blizzColorsDefault then
        config.blizzardColors = defaultConfig.blizzardColors
    end
   
    f:SetFrameStrata"TOOLTIP"
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetScript("OnEnter", Menu_OnEnter)
    f:SetScript("OnLeave", Menu_OnLeave)
    f:RegisterEvent"CHAT_MSG_COMBAT_FACTION_CHANGE"

--  slider = CreateFrame("Slider", nil, f, AraBackdropTemplate)
    slider = CreateFrame("Slider", nil, f, BackdropTemplateMixin and "BackdropTemplate")
    slider:SetWidth(16)
    slider:SetThumbTexture"Interface\\Buttons\\UI-SliderBar-Button-Horizontal"
    slider:SetBackdrop( {
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        edgeSize = 8, tile = true, tileSize = 8,
        insets = {left = 3, right = 3, top = 6, bottom = 6}
    } )
    slider:SetValueStep(1)
    slider:SetScript( "OnLeave", Menu_OnLeave )
    slider:SetScript( "OnValueChanged", function(self, value)
        if hasSlider then
            sliderValue = value
            if f:IsShown() then UpdateScrollButtons(MAX_ENTRIES) end
        end
    end )

    if IsLoggedIn() then Init()
    else
        f:RegisterEvent"PLAYER_ENTERING_WORLD"
        f.PLAYER_ENTERING_WORLD = Init
    end

    f:UnregisterEvent"ADDON_LOADED"
    f.ADDON_LOADED = nil
end

f:SetScript("OnEvent", function(self, event, ...) return self[event](self, ...) end)
f:RegisterEvent"ADDON_LOADED"
