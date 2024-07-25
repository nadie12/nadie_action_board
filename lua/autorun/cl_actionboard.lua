--[[

    IMPLEMENTS A UI TO EASILY SWAP BETWEEN THE MAIN AND EVENT SERVER.
    CONTEXT MENU POPUP

    Made by Nadie (v1.0)

--]]

local EventBoard = {}

EventBoard.ALLOWED_USERGROUPS = {
    ["superadmin"] = true,
    ["tgm"] = true,
    ["sgm"] = true,
}

-- Color scheme
EventBoard.COL_BG = Color(30, 30, 35, 250)
EventBoard.COL_BUTTON = Color(50, 50, 55, 255)
EventBoard.COL_BUTTON_HOVER = Color(70, 70, 75, 255)
EventBoard.COL_TEXT = Color(255, 255, 255)
EventBoard.COL_ACCENT = Color(100, 200, 255)
EventBoard.COL_NOTFAVORITED = Color(80,80,80)
EventBoard.HEART_MATERIAL = Material("materials/wishlist.png", "noclamp smooth" )

EventBoard.NAB_PANEL = nil
EventBoard.favorites = EventBoard.favorites or {}

-- Path to the favorites file
local FAVORITES_FILE = "eventboard_favorites.txt"

-- Function to save favorite button IDs to a file
local function SaveFavorites(favorites)
    -- Only save buttons that are favorited
    local filteredFavorites = {}
    for id, favorited in pairs(favorites) do
        if favorited then
            filteredFavorites[id] = true
        end
    end
    file.Write(FAVORITES_FILE, util.TableToJSON(filteredFavorites))
    EventBoard.FAV_AMOUNT = table.Count(filteredFavorites)
end

-- Function to load favorite button IDs from a file
local function LoadFavorites()
    if file.Exists(FAVORITES_FILE, "DATA") then
        local data = file.Read(FAVORITES_FILE, "DATA")
        return util.JSONToTable(data) or {}
    end
    return {}
end

-- Initialize favorites table
local favorites = LoadFavorites()


EventBoard.FAV_AMOUNT = table.Count(favorites)

-- Create custom fonts
surface.CreateFont("NADIE.LABEL", {
    font = "Roboto",
    antialias = true,
    extended = true,
    weight = 700,
    size = ScrW() * 0.012,
})

surface.CreateFont("NADIE.BUTTON", {
    font = "Roboto",
    antialias = true,
    extended = true,
    weight = 500,
    size = ScrW() * 0.009,
})

surface.CreateFont("NADIE.DISPLAYTEXT", {
    font = "Roboto",
    antialias = true,
    extended = true,
    weight = 500,
    size = ScrW() * 0.035,
})

-- Networking function
function EventBoard.SendAction(action, data)
    net.Start("NAB_Action")
    net.WriteString(action)
    net.WriteTable(data)
    net.SendToServer()
end

-- Function to make a panel draggable
function MakePanelDraggable(panel)
    panel.isDragging = false
    panel.dragStartX = 0
    panel.dragStartY = 0

    panel.OnMousePressed = function(self, keyCode)
        if keyCode == MOUSE_LEFT then
            self.isDragging = true
            self.dragStartX, self.dragStartY = gui.MousePos()
            self:MouseCapture(true)
        end
    end

    panel.OnMouseReleased = function(self, keyCode)
        if keyCode == MOUSE_LEFT then
            self.isDragging = false
            self:MouseCapture(false)
        end
    end
end

-- Function to handle panel dragging logic
function HandlePanelDrag(panel)
    if panel.isDragging then
        local x, y = gui.MousePos()
        local dx = x - panel.dragStartX
        local dy = y - panel.dragStartY
        
        local newX, newY = panel:GetPos()
        newX = math.Clamp(newX + dx, 0, ScrW() - panel:GetWide())
        newY = math.Clamp(newY + dy, 0, ScrH() - panel:GetTall())
        
        panel:SetPos(newX, newY)
        
        panel.dragStartX = x
        panel.dragStartY = y
    end
end

-- Function to create a custom input panel
function EventBoard.CreateCustomInputPanel(parent, inputFields, callback)
    local inputPanel = vgui.Create("DPanel", parent)
    local parentW, parentH = parent:GetSize()
    inputPanel:SetSize(parent:GetSize())
    inputPanel:SetPos(0, 0)
    inputPanel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(40,40,40,250))
    end

    local headerHeight = parentH * 0.05
    local inputWidth = parentW * 0.4
    local inputHeight = parentH * 0.1
    local marginY = parentH * 0.05

    local inputs = {}

    -- Calculate total content height
    local contentHeight = (#inputFields * (inputHeight + marginY)) + inputHeight -- inputs + apply button
    local startY = (parentH - contentHeight) / 2 -- Center vertically

    -- Ensure startY is below the back button
    startY = math.max(startY, headerHeight * 3)

    for i, field in ipairs(inputFields) do
        local yPos = startY + (i - 1) * (inputHeight + marginY)

        local label = vgui.Create("DLabel", inputPanel)
        label:SetText(field.label)
        label:SetTextColor(EventBoard.COL_TEXT)
        label:SetPos(parentW * 0.1, yPos)
        label:SizeToContents()

        local theinput = vgui.Create("DTextEntry", inputPanel)
        theinput:SetSize(inputWidth, inputHeight)
        theinput:SetPos(parentW * 0.5, yPos)
        if field.numeric then
            theinput:SetNumeric(true)
        end
        inputs[field.name] = theinput
    end

    -- Apply Button
    local applyButton = vgui.Create("DButton", inputPanel)
    applyButton:SetText("Apply")
    applyButton:SetTextColor(EventBoard.COL_TEXT)
    applyButton:SetSize(inputWidth, inputHeight)
    applyButton:SetPos(parentW * 0.5 - inputWidth * 0.5, startY + (#inputFields * (inputHeight + marginY)))
    applyButton.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, EventBoard.COL_BUTTON)
        if self:IsHovered() then
            draw.RoundedBox(8, 0, 0, w, h, EventBoard.COL_BUTTON_HOVER)
        end
    end
    applyButton.DoClick = function()
        local data = {}
        for name, theinput in pairs(inputs) do
            local value = theinput:GetValue()
            data[name] = tonumber(value) or value
        end
        callback(data)
        inputPanel:Remove()
    end

    -- Back Button
    local backButtonWidth = parentW * 0.15
    local backButtonHeight = headerHeight * 2
    local backButtonMargin = headerHeight * 0.7

    EventBoard.CreateButton(inputPanel, "Back", backButtonMargin, backButtonMargin, backButtonWidth, backButtonHeight, function()
        if IsValid(parent) then
            EventBoard.CreateButtons(parent, EventBoard.BUTTONS)
        end
    end)

    return inputPanel
end

-- Function to create a button
function EventBoard.CreateButton(parent, text, x, y, w, h, onClick, favoritable, buttonId)
    if not IsValid(parent) then return end
    
    local button = vgui.Create("DButton", parent)
    if not IsValid(button) then return end
    
    button:SetPos(x, y)
    button:SetSize(w, h)
    button:SetText("")
    button.favorited = favorites[buttonId] or false
    
    local hoverAlpha = 0
    local clickAlpha = 0

    -- print("Button " .. text .. " favoritable " .. tostring(favoritable))

    if favoritable then
        local favoriteButton = vgui.Create("DImageButton", button)
        favoriteButton:SetSize(32, 32)
        favoriteButton:SetPos(w - 36, 4)
        favoriteButton:SetColor(color_white)
        favoriteButton.DoClick = function(s, w, h)
            s:GetParent().favorited = not s:GetParent().favorited
            if s:GetParent().favorited then
                favorites[buttonId] = true
            else
                favorites[buttonId] = nil
            end
            SaveFavorites(favorites)
        end
    end
    
    button.Paint = function(self, w, h)
        -- Base button
        draw.RoundedBox(8, 0, 0, w, h, EventBoard.COL_BUTTON)

        if favoritable then
            if self.favorited then
                surface.SetDrawColor(color_white)
                surface.SetMaterial(EventBoard.HEART_MATERIAL)
                surface.DrawTexturedRect(w - 36, 4, 32, 32)
            else
                surface.SetDrawColor(EventBoard.COL_NOTFAVORITED)
                surface.SetMaterial(EventBoard.HEART_MATERIAL)
                surface.DrawTexturedRect(w - 36, 4, 32, 32)
            end
        end
        
        -- Hover effect
        if self:IsHovered() then
            hoverAlpha = math.Approach(hoverAlpha, 1, FrameTime() * 5)
        else
            hoverAlpha = math.Approach(hoverAlpha, 0, FrameTime() * 5)
        end
        surface.SetDrawColor(ColorAlpha(EventBoard.COL_BUTTON_HOVER, hoverAlpha * 255))
        surface.SetMaterial(Material("gui/gradient_up"))
        surface.DrawTexturedRect(0, 0, w, h)
        
        -- Click effect
        if self:IsDown() then
            clickAlpha = math.Approach(clickAlpha, 1, FrameTime() * 10)
        else
            clickAlpha = math.Approach(clickAlpha, 0, FrameTime() * 10)
        end
        surface.SetDrawColor(ColorAlpha(EventBoard.COL_ACCENT, clickAlpha * 100))
        surface.DrawRect(0, 0, w, h)
        
        -- Text
        draw.SimpleText(text, "NADIE.BUTTON", w / 2, h / 2, EventBoard.COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        -- Underline (centered expansion)
        local underlineWidth = w * (hoverAlpha + clickAlpha)
        local underlineStartX = w * 0.5 - underlineWidth * 0.5
        surface.SetDrawColor(EventBoard.COL_ACCENT)
        surface.DrawRect(underlineStartX, h - 2, underlineWidth, 2)
    end
    
    button.DoClick = onClick
    button.OnCursorEntered = function() surface.PlaySound("UI/buttonrollover.wav") end
    
    return button
end


function EventBoard.CreateButtons(parent, buttons, isSubmenu)
    if not IsValid(parent) then return end

    -- Remove existing children instead of clearing
    for _, child in pairs(parent:GetChildren()) do
        if IsValid(child) then
            child:Remove()
        end
    end

    -- Get panel dimensions
    local panelW, panelH = parent:GetSize()

    -- Calculate optimal grid size
    local buttonCount = #buttons
    local columns = math.min(2, buttonCount)
    local rows = math.ceil(buttonCount / columns)

    -- Calculate button dimensions and margins
    local marginX = panelW * 0.03
    local marginY = panelH * 0.03
    local startY = panelH * 0.2

    local availableWidth = panelW - (marginX * (columns + 1))
    local availableHeight = panelH - startY - (marginY * (rows + 1))

    local buttonWidth = availableWidth / columns
    local buttonHeight = availableHeight / rows

    -- Create buttons
    for i, buttonConfig in ipairs(buttons) do
        local row = math.floor((i - 1) / columns)
        local col = (i - 1) % columns
        
        local x = marginX + col * (buttonWidth + marginX)
        local y = startY + row * (buttonHeight + marginY)

        local onClick
        local favoritable = not buttonConfig.submenu -- Set favoritable to true for non-submenu buttons

        if buttonConfig.submenu then
            onClick = function()
                if IsValid(parent) then
                    EventBoard.CreateButtons(parent, buttonConfig.submenu, true)
                end
            end
        else
            onClick = function()
                buttonConfig.action(parent)
            end
        end

        EventBoard.CreateButton(parent, buttonConfig.text, x, y, buttonWidth, buttonHeight, onClick, favoritable, buttonConfig.id)
    end

    -- Add back button if it's a submenu
    if isSubmenu then
        local headerHeight = panelH * 0.05
        local backButtonWidth = panelW * 0.15
        local backButtonHeight = headerHeight * 2
        local backButtonMargin = headerHeight * 0.7

        EventBoard.CreateButton(parent, "Back", backButtonMargin, backButtonMargin, backButtonWidth, backButtonHeight, function()
            if IsValid(parent) then
                EventBoard.CreateButtons(parent, EventBoard.BUTTONS)
            end
        end)
    end
end


-- Button configurations
EventBoard.BUTTONS = {
    {
        text = "Screenshake", submenu = {
            {text = "Small", id = "screen_shake_small", action = function() 
                EventBoard.SendAction("screen_shake", {intensity = 5, duration = 1}) 
            end},
            {text = "Medium", id = "screen_shake_medium", action = function() 
                EventBoard.SendAction("screen_shake", {intensity = 10, duration = 3}) 
            end},
            {text = "Large", id = "screen_shake_large", action = function() 
                EventBoard.SendAction("screen_shake", {intensity = 20, duration = 7}) 
            end},
            {text = "Custom", id = "screen_shake_custom", action = function(parent) 
                EventBoard.CreateCustomInputPanel(parent, {
                    {name = "intensity", label = "Intensity (1-100):", numeric = true},
                    {name = "duration", label = "Duration (seconds):", numeric = true}
                    {name = "radius", label = "Radius (0 for global):", numeric = true}
                }, function(data)
                    data.intensity = math.Clamp(data.intensity or 0, 1, 100)
                    data.duration = math.max(data.duration or 0, 0)
                    EventBoard.SendAction("screen_shake", data)
                end)
            end},
        }
    },
    {
        text = "Teleport Players", submenu = {
            {text = "Spawn", id = "teleport_players_spawn", action = function() 
                EventBoard.SendAction("teleport_players", {destination = "spawn"}) 
            end},
            {text = "To Me", id = "teleport_players_to_me", action = function()
                EventBoard.SendAction("teleport_players", {destination = "to me"})
            end},
        }
    },
    {
        text = "Play Sound", submenu = {
            {text = "Vader Theme", id = "play_sound_vader_theme", action = function() 
                EventBoard.SendAction("play_sound", {soundfile = "sounds/vadertheme.wav"}) 
            end},
            {text = "Placeholder Sound", id = "play_sound_placeholder", action = function()
                EventBoard.SendAction("play_sound", {soundfile = "sounds/placeholder.wav"})
            end},
        }
    },
    {text = "Display Text", id = "display_text", action = function(parent) 
        EventBoard.CreateCustomInputPanel(parent, {
            {name = "text", label = "Text (string)", numeric = false},
            {name = "duration", label = "Duration (seconds):", numeric = true}
        }, function(data)
            data.duration = math.max(data.duration or 0, 0)
            EventBoard.SendAction("display_text", data)
        end)
    end},
    {
        text = "Spawn Bomb", submenu = {
            {text = "Bomb 1", id = "spawn_bomb_1", action = function() 
                EventBoard.SendAction("spawn_bomb", {bombclass = "models/props_c17/gravestone_coffinpiece002a.mdl"}) 
            end},
            {text = "Bomb 2", id = "spawn_bomb_2", action = function()
                EventBoard.SendAction("spawn_bomb", {bombclass = "models/props_c17/gravestone_coffinpiece001a.mdl"})
            end},
            {text = "Bomb 3", id = "spawn_bomb_3", action = function()
                EventBoard.SendAction("spawn_bomb", {bombclass = "models/props_c17/gravestone_coffinpiece001a.mdl"})
            end},
            {text = "Bomb 4", id = "spawn_bomb_4", action = function()
                EventBoard.SendAction("spawn_bomb", {bombclass = "models/props_c17/gravestone_coffinpiece001a.mdl"})
            end},
        }
    },
}


function EventBoard.Open()
    local w, h = ScrW(), ScrH()

    if IsValid(EventBoard.NAB_PANEL) then
        EventBoard.NAB_PANEL:Remove()
    end

    local PANEL = vgui.Create("EditablePanel")
    if not IsValid(PANEL) then return end

    PANEL:SetParent(g_ContextMenu)
    PANEL:SetSize(w * 0.25, h * 0.3)
    PANEL:SetPos(w, h * 0.65)
    PANEL:MoveTo(w * 0.735, h * 0.65, 0.3, 0, 0.5, function() end)
    PANEL:SetMouseInputEnabled(true)
    
    local headerHeight = h * 0.05
    
    PANEL.Paint = function(self, w, h)
        -- Background
        draw.RoundedBox(10, 0, 0, w, h, EventBoard.COL_BG)
        
        -- Header
        draw.RoundedBoxEx(10, 0, 0, w, headerHeight, EventBoard.COL_ACCENT, true, true, false, false)
        draw.SimpleText("Event Action Board", "NADIE.LABEL", w * 0.5, headerHeight * 0.5, EventBoard.COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        surface.SetDrawColor(EventBoard.COL_BUTTON)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end

    -- Make the panel draggable
    MakePanelDraggable(PANEL)

    PANEL.Think = function(self)
        HandlePanelDrag(self)
    end

    EventBoard.NAB_PANEL = PANEL

    EventBoard.CreateButtons(PANEL, EventBoard.BUTTONS)

    return PANEL
end


local function DisplayText()
    local text = net.ReadString()
    local w, h = ScrW(), ScrH()

    -- Create the frame
    local frame = vgui.Create("EditablePanel")
    frame:SetSize(w * 0.5, h * 0.1)
    local startX, startY = (w - frame:GetWide()) / 2, -frame:GetTall()
    frame:SetPos(startX, startY)

    local endY = (h - frame:GetTall()) * 0.1
    frame:MoveTo(startX, endY, 1, 0, 1, function() timer.Simple(5, function() frame:AlphaTo(0, 1, 0, function() frame:Remove() end) end) end)

    frame.Paint = function(s, w, h)
        --draw.RoundedBox(0, 0, 09, w, h, Color(0, 0, 0, 255))
        
        draw.SimpleText(text, "NADIE.DISPLAYTEXT", w/2, h/2, EventBoard.COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
    end
end
 
function EventBoard.OpenFavorites()
    if table.IsEmpty(favorites) then 
        if IsValid(EventBoard.FAV_PANEL) then
            EventBoard.FAV_PANEL:Remove()
        end
    return end

    if IsValid(EventBoard.FAV_PANEL) then
        EventBoard.FAV_PANEL:Remove()
    end

    local w, h = ScrW(), ScrH()
    
    PrintTable(favorites)

    print("fav count", table.Count(favorites))
    local favorites_amount = table.Count(favorites)

    local PANEL = vgui.Create("EditablePanel")
    PANEL:SetSize(EventBoard.FAV_AMOUNT * 60, 60)
    PANEL:SetParent(g_ContextMenu)
    PANEL:SetPos(w /2 ,h / 2)
    PANEL:SetMouseInputEnabled(true)
    PANEL.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, EventBoard.COL_BG)

    end
    
    MakePanelDraggable(PANEL)
    PANEL.Think = function(self) HandlePanelDrag(self) end

    EventBoard.FAV_PANEL = PANEL

    return PANEL

end


net.Receive("NAB_Action_DisplayText", DisplayText)

hook.Add("OnContextMenuOpen", "NAB.ContextMenuOpen", function()
    -- Only open action board for users with sufficient permissions
    local plyUserGroup = LocalPlayer():GetUserGroup()
    if not EventBoard.ALLOWED_USERGROUPS[plyUserGroup] then return end
     
    local PANEL = EventBoard.Open()
    local PANEL_FAVORITES = EventBoard.OpenFavorites()
    
end)