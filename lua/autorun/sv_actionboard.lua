--[[

    SERVER-SIDE EVENT BOARD HANDLER

    Made by Nadie (v1.0)

--]]

util.AddNetworkString("NAB_Action")
util.AddNetworkString("NAB_Action_DisplayText")

local LAST_ACTION = {
    NAME = "",
    TIME = 0
}

local ALLOWED_USERGROUPS = {
    ["superadmin"] = true,
    ["tgm"] = true,
    ["sgm"] = true,
}

local function ApplyScreenshake(intensity, duration)
    local randomPitch = math.random(-intensity, intensity)
    local randomYaw = math.random(-intensity, intensity)
    local randomRoll = math.random(-intensity, intensity)

    for _, ply in ipairs(player.GetAll()) do
        
        ply:ViewPunch(Angle(randomPitch, randomYaw, randomRoll))
        util.ScreenShake(ply:GetPos(), intensity, 5, duration, 1000)
    end
end

local function spiralGrid(rings)
    local grid = {}
    local col, row
    for ring = 1, rings do
        row = ring
        for col = 1 - ring, ring do
            table.insert(grid, {col, row})
        end
        col = ring
        for row = ring - 1, -ring, -1 do
            table.insert(grid, {col, row})
        end
        row = -ring
        for col = ring - 1, -ring, -1 do
            table.insert(grid, {col, row})
        end
        col = -ring
        for row = 1 - ring, ring do
            table.insert(grid, {col, row})
        end
    end
    return grid
end

local function SafeTeleport(caller, targets, rings)
    local cell_size = 50 -- Constant spacing value
    local tpGrid = spiralGrid(rings or 24) -- Generate grid, default to 24 rings if not specified

    local players_involved = {caller}
    for _, v in ipairs(targets) do
        table.insert(players_involved, v)
    end

    local teleported_players = {}

    -- Check if the caller's position is clear
    local callerTrace = util.TraceEntity({
        start = caller:GetPos(),
        endpos = caller:GetPos(),
        filter = caller
    }, caller)

    if callerTrace.Hit then
        return teleported_players, "Caller is obstructed"
    end

    for i = 1, #tpGrid do
        local c = tpGrid[i][1]
        local r = tpGrid[i][2]
        local target = table.remove(targets)
        if not target then break end

        local yawForward = caller:EyeAngles().yaw
        local offset = Vector(r * cell_size, c * cell_size, 0)
        offset:Rotate(Angle(0, yawForward, 0))

        local start_pos = caller:GetPos() + Vector(0, 0, 32) -- Move them up a bit so they can travel across the ground
        local end_pos = start_pos + offset

        local tr = util.TraceEntity({
            start = start_pos,
            endpos = end_pos,
            filter = players_involved
        }, target)

        if not tr.Hit then
            if target:InVehicle() then target:ExitVehicle() end
            target:SetPos(end_pos)
            target:SetLocalVelocity(Vector(0, 0, 0))
            table.insert(teleported_players, target)
        else
            table.insert(targets, target) -- Put back in the queue if the spot is not free
        end
    end

    return teleported_players, #targets > 0 and "Not enough free space to teleport everyone" or nil
end

local function TeleportPlayers(ply, destination)
    local targets = {}
    for _, v in pairs(player.GetAll()) do
        --if (!ALLOWED_USERGROUPS[v:GetUserGroup()]) then
            table.insert(targets, v)
        --end
    end
    
    -- Fade to black for targeted players
    for _, p in ipairs(targets) do
        p:ScreenFade(SCREENFADE.OUT, Color(0, 0, 0, 255), 1, 0.5)
    end

    -- Wait for fade to complete before teleporting
    timer.Simple(1, function()
        local teleported, error = SafeTeleport(ply, targets)
        
        -- Fade from black for teleported players after teleport
        timer.Simple(0.5, function()
            for _, p in ipairs(teleported) do
                p:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 255), 1, 0)
            end
        end)

        -- Print result
        if error then
            print(error)
        else
            print(ply:Nick() .. " teleported " .. #teleported .. " players")
        end
    end)
end

local function DisplayText(text)
    net.Start("NAB_Action_DisplayText")
    net.WriteString(text)
    net.Broadcast()
end

local function SpawnBomb(ply, bombclass)
    local bomb = ents.Create("prop_physics")
    local pos = ply:GetPos() + Vector(15, 0, 32)

    bomb:SetModel(bombclass)
    bomb:SetPos(pos)
    bomb:Spawn()
    bomb:SetOwner(ply)
    bomb:GetPhysicsObject():Wake()

end

local ActionHandlers = {
    teleport_players = function(ply, data)
        TeleportPlayers(ply, data.destination)
        print(ply:Nick() .. " teleported players to " .. tostring(data.destination))
    end,

    screen_shake = function(ply, data)
        ApplyScreenshake(data.intensity, data.duration)
        print(ply:Nick() .. " activated " .. data.intensity .. " Screenshake for " .. data.duration .. " seconds")
    end,

    play_sound = function(ply, data)
        -- Playsound logic here
    end,

    display_text = function(ply, data)
        DisplayText(data.text)
    end,

    spawn_bomb = function(ply, data)
        SpawnBomb(ply, data.bombclass)
    end


}

net.Receive("NAB_Action", function(len, ply)
    if not ALLOWED_USERGROUPS[ply:GetUserGroup()] then
        print("Player " .. ply:Nick() .. " attempted to use Event Board without permission.")
        return
    end
    
    local action = net.ReadString()
    local data = net.ReadTable()

    if(LAST_ACTION) then
        if (LAST_ACTION.TIME + 1 > CurTime()and LAST_ACTION.NAME == action) then return end
    end
    
    local handler = ActionHandlers[action]
    if handler then
        LAST_ACTION.NAME = action
        LAST_ACTION.TIME = CurTime()
        handler(ply, data)
    else
        print("Invalid action received from " .. ply:Nick())
    end
end)



