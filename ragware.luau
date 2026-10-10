--[[
    RagWare
    Engine: Roblox (Luau)   Tipo: LocalScript (StarterPlayerScripts) ou script de executor
    UI: PC + mobile, abas na lateral (Combat, Visual, Player, Config), janela arrastavel e redimensionavel
    Abrir/fechar: RightShift (configuravel) ou o botao flutuante "R" no mobile
    Configs: writefile/readfile quando o executor tiver; sem isso ficam so na sessao
    Executar de novo descarrega a instancia anterior.
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace   = game:GetService("Workspace")

local LP       = Players.LocalPlayer
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

local ENV = (getgenv and getgenv()) or _G
if ENV.__RAGWARE_UNLOAD then pcall(ENV.__RAGWARE_UNLOAD) end

----------------------------------------------------------------------------
-- settings
----------------------------------------------------------------------------
local DEFAULTS = {
    -- aimbot
    aimbot = false, aim_mode = "Hold", aim_key = "MouseButton2", aim_method = "Camera",
    aim_part = "Head", aim_priority = "Crosshair", aim_maxdist = 1500, smooth = 20,
    -- humanizer (imperfeicoes humanas na mira)
    humanize = false, human_noise = 0.8, human_offset = 0.3, human_delay = 120, human_speed = 25,
    -- fov
    aim_fov = 120, show_fov = true, fov_fullscreen = false, fov_origin = "Mouse",
    fov_color = {232, 238, 250}, fov_thick = 1.5,
    -- checks (valem para aimbot e triggerbot)
    wallcheck = true, teamcheck = true, deathcheck = true, ff_check = true,
    downcheck = false, friendcheck = false, invischeck = false,
    -- botao de mira (touch)
    aim_button = true, aim_btn_x = 88, aim_btn_y = 55, aim_btn_size = 64,
    -- triggerbot
    trigger = false, trigger_part = "Any", trigger_mode = "Click", fire_method = "Auto",
    trigger_delay = 40, trigger_interval = 90, trigger_range = 1000, trigger_radius = 3,
    trigger_aimkey = false,
    -- spinbot (spin_pause: para de girar enquanto voce atira, para o tiro sair reto)
    spinbot = false, spin_mode = "Spin", spin_method = "CFrame", spin_speed = 720, spin_reverse = false,
    spin_jitter = 90, spin_rate = 20, spin_pause = true, spin_resume = 180, spin_face = true,
    -- third person (camera deslocada para tras, funciona ate em jogo com camera propria)
    tp_on = false, tp_dist = 12, tp_height = 1.5, tp_side = 0, tp_collide = true, tp_body = true, tp_key = "None",
    -- chams (camada visivel + camada occluded)
    chams = false, chams_occ = false, chams_max = 15, chams_acc = false,
    chams_fill_c = {255, 90, 90}, chams_fill = 0.5, chams_line_c = {255, 255, 255}, chams_line = 0,
    occ_fill_c = {90, 170, 255}, occ_fill = 0.25, occ_line_c = {255, 255, 255}, occ_line = 0.2,
    -- esp
    esp_box = false, esp_skel = false, esp_name = false, esp_head = false, esp_health = false, esp_dist = false,
    esp_tracer = false, tracer_from = "Bottom", tracer_to = "Feet",
    esp_color = {255, 90, 90}, esp_team_color = {90, 170, 255}, esp_team = false,
    esp_namemode = "Display", esp_unit = "Studs", esp_maxdist = 2000, esp_thick = 1.5, esp_text = 13,
    -- player
    walk_on = false, walk = 32, jump_on = false, jump = 90, infjump = false, noclip = false,
    fly = false, fly_speed = 60, camfov_on = false, camfov = 90, grav_on = false, grav = 100, antiafk = false,
    bhop_on = false, bhop_mode = isMobile and "Moving" or "Hold", bhop_boost = false, bhop_speed = 28,
    -- ui
    ui_accent = {20, 168, 255}, ui_trans = 0.04, ui_scale = 1, ui_corner = 10, ui_desc = false,
    ui_font = "GothamMedium", ui_key = "RightShift", ui_btn = isMobile,
    win_w = 760, win_h = 470, win_cx = 0.5, win_cy = 0.5,
    resize_on = true, resize_corner = "Bottom right",
}

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

local S = {}
for k, v in pairs(DEFAULTS) do S[k] = copy(v) end

----------------------------------------------------------------------------
-- utils
----------------------------------------------------------------------------
local conns = {}
local function conn(c) conns[#conns + 1] = c return c end
local function col(t) return Color3.fromRGB(t[1], t[2], t[3]) end

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function matches(i, name)
    if name:sub(1, 5) == "Mouse" then return i.UserInputType.Name == name end
    return i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode.Name == name
end

local function safe(tag, fn)
    local warned = false
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok and not warned then
            warned = true
            warn("[ragware:" .. tag .. "] " .. tostring(err))
        end
    end
end

-- tabelas de modulo (preenchidas na parte de logica; os botoes da UI chamam em tempo de clique)
local TR = {state = "off", note = "", lastActive = -1000}   -- triggerbot
local CH = {}                           -- chams

----------------------------------------------------------------------------
-- configs (arquivo no executor, memoria sem writefile)
----------------------------------------------------------------------------
local ROOT, DIR = "RagWare", "RagWare/configs"
local hasFS = (writefile and readfile and isfile and isfolder and makefolder and listfiles) and true or false
local memStore = {}

if hasFS then
    pcall(function()
        if not isfolder(ROOT) then makefolder(ROOT) end
        if not isfolder(DIR) then makefolder(DIR) end
    end)
    -- configs salvas antes do rename (pasta NyxMenu) sao copiadas; as originais ficam la
    pcall(function()
        local old = "NyxMenu/configs"
        if not isfolder(old) then return end
        for _, f in ipairs(listfiles(old)) do
            local n = tostring(f):match("([^/\\]+)%.json$")
            if n and not isfile(DIR .. "/" .. n .. ".json") then
                writefile(DIR .. "/" .. n .. ".json", readfile(f))
            end
        end
    end)
end

local function clean(n)
    n = tostring(n or ""):gsub("[^%w_%- ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return n
end

local function cfgList()
    local out = {}
    if hasFS then
        local ok, files = pcall(listfiles, DIR)
        if ok and type(files) == "table" then
            for _, f in ipairs(files) do
                local n = tostring(f):match("([^/\\]+)%.json$")
                if n then out[#out + 1] = n end
            end
        end
    else
        for n in pairs(memStore) do out[#out + 1] = n end
    end
    table.sort(out)
    return out
end

local function cfgSave(name)
    name = clean(name)
    if name == "" then return false, "empty name" end
    local json = HttpService:JSONEncode(S)
    if hasFS then
        local ok, err = pcall(writefile, DIR .. "/" .. name .. ".json", json)
        if not ok then return false, tostring(err) end
    else
        memStore[name] = json
    end
    return true
end

local function cfgRead(name)
    local raw
    if hasFS then
        local p = DIR .. "/" .. name .. ".json"
        local ok, r = pcall(function() return isfile(p) and readfile(p) or nil end)
        raw = ok and r or nil
    else
        raw = memStore[name]
    end
    if not raw then return false, "not found" end
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(data) ~= "table" then return false, "invalid file" end
    for k, v in pairs(data) do
        if DEFAULTS[k] ~= nil and type(v) == type(DEFAULTS[k]) then
            if type(v) == "table" then
                if #v == 3 then S[k] = {tonumber(v[1]) or 0, tonumber(v[2]) or 0, tonumber(v[3]) or 0} end
            else
                S[k] = v
            end
        end
    end
    return true
end

local function cfgDelete(name)
    if hasFS then
        pcall(function() delfile(DIR .. "/" .. name .. ".json") end)
    else
        memStore[name] = nil
    end
end

local function autoloadSet(name)
    if hasFS then pcall(writefile, ROOT .. "/autoload.txt", name) end
end

do
    if hasFS then
        local ok, a = pcall(function()
            local p = ROOT .. "/autoload.txt"
            return isfile(p) and readfile(p) or nil
        end)
        if ok and a and a ~= "" then cfgRead(a) end
    end
end

----------------------------------------------------------------------------
-- ui toolkit
----------------------------------------------------------------------------
local TweenService = game:GetService("TweenService")
local refreshers, themeFns, textObjs, descObjs, cornerObjs, panelObjs = {}, {}, {}, {}, {}, {}

local function accent() return col(S.ui_accent) end
local function onTheme(fn) themeFns[#themeFns + 1] = fn fn() end
local function applyTheme() for _, f in ipairs(themeFns) do pcall(f) end end
local function refreshAll()
    for _, f in ipairs(refreshers) do pcall(f) end
    applyTheme()
end
local function curFont()
    local ok, f = pcall(function() return Enum.Font[S.ui_font] end)
    return (ok and f) or Enum.Font.GothamMedium
end

local RH = isMobile and 38 or 30
local T = {
    bg   = Color3.fromRGB(8, 12, 20),
    side = Color3.fromRGB(11, 16, 26),
    card = Color3.fromRGB(14, 20, 32),
    sub  = Color3.fromRGB(10, 15, 25),
    item = Color3.fromRGB(22, 31, 47),
    line = Color3.fromRGB(28, 39, 58),
    off  = Color3.fromRGB(40, 53, 76),
    text = Color3.fromRGB(226, 233, 246),
    dim  = Color3.fromRGB(118, 133, 160),
}

local function tween(o, props, t)
    pcall(function()
        TweenService:Create(o, TweenInfo.new(t or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
    end)
end

local function pointerDown(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

-- arrasto generico (slider, color picker): onMove recebe a posicao do ponteiro; o scroll fica travado durante o arrasto
local function bindDrag(frame, onMove)
    local dragging = false
    frame.InputBegan:Connect(function(i)
        if not pointerDown(i) then return end
        dragging = true
        local sf = frame:FindFirstAncestorWhichIsA("ScrollingFrame")
        if sf then sf.ScrollingEnabled = false end
        onMove(i.Position)
        local c
        c = i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then
                dragging = false
                if sf then sf.ScrollingEnabled = true end
                c:Disconnect()
            end
        end)
    end)
    conn(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
            onMove(i.Position)
        end
    end))
end

local order = {}
local function nextOrder(p) order[p] = (order[p] or 0) + 1 return order[p] end

local function text(parent, str, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.Text = str
    l.TextColor3 = T.text
    l.TextSize = 13
    l.Font = curFont()
    l.TextXAlignment = Enum.TextXAlignment.Left
    for k, v in pairs(props or {}) do l[k] = v end
    l.Parent = parent
    if not (props and props.Font) then textObjs[#textObjs + 1] = l end
    return l
end

-- cantos que acompanham o "Corner radius" da config (delta = diferenca para o raio da janela)
local function corner(o, delta)
    local c = new("UICorner", {}, o)
    cornerObjs[#cornerObjs + 1] = {c, delta or 0}
    return c
end

-- seta "v" feita de duas linhas (nao depende de fonte/icone); Rotation = 180 vira "^"
local function chevron(parent, pos)
    local h = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(14, 14),
        BackgroundTransparency = 1}, parent)
    local lines = {}
    for i, spec in ipairs({{4.5, 45}, {9.5, -45}}) do
        local l = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(spec[1], 6),
            Size = UDim2.fromOffset(7, 2), Rotation = spec[2], BackgroundColor3 = T.dim, BorderSizePixel = 0}, h)
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, l)
        lines[i] = l
    end
    return h, lines
end

-- linha plana: rotulo a esquerda (+ descricao opcional embaixo), controle a direita
local function newRow(parent, minH)
    return new("Frame", {Size = UDim2.new(1, 0, 0, minH or RH), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = nextOrder(parent)}, parent)
end

local function rowLabel(r, label, desc, rightPad)
    local pad = rightPad or 60
    local l = text(r, label, {Size = UDim2.new(1, -pad, 0, RH), TextTruncate = Enum.TextTruncate.AtEnd})
    if desc then
        local d = text(r, desc, {Position = UDim2.fromOffset(0, RH - 8), Size = UDim2.new(1, -pad, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, TextSize = 11, TextColor3 = T.dim, TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top, Visible = S.ui_desc})
        descObjs[#descObjs + 1] = d
    end
    return l
end

local function stack(parent, pad)
    local h = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = nextOrder(parent)}, parent)
    new("UIListLayout", {Padding = UDim.new(0, pad or 2), SortOrder = Enum.SortOrder.LayoutOrder}, h)
    return h
end

-- interruptor; devolve a funcao que aplica o estado (animado, ou direto quando instant = true)
local function switch(parent, rightOff)
    local sw = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, rightOff or 0, 0, RH / 2),
        Size = UDim2.fromOffset(32, 16), BackgroundColor3 = T.off, BorderSizePixel = 0}, parent)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, sw)
    local knob = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(12, 12), BackgroundColor3 = T.text, BorderSizePixel = 0}, sw)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, knob)
    return function(on, instant)
        local pos = on and UDim2.new(0, 18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
        local c = on and accent() or T.off
        if instant then
            sw.BackgroundColor3 = c
            knob.Position = pos
        else
            tween(sw, {BackgroundColor3 = c}, 0.12)
            tween(knob, {Position = pos}, 0.12)
        end
    end
end

local function Toggle(parent, label, key, cb, desc)
    local r = newRow(parent)
    rowLabel(r, label, desc, 52)
    local set = switch(r, 0)
    local btn = new("TextButton", {Size = UDim2.new(1, 0, 0, RH), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, ZIndex = 2}, r)
    btn.Activated:Connect(function()
        S[key] = not S[key]
        set(S[key])
        if cb then cb(S[key]) end
    end)
    refreshers[#refreshers + 1] = function() set(S[key], true) end
    onTheme(function() set(S[key], true) end)
    return r
end

-- feature = linha com toggle + seta no fim; a seta abre o painel de config logo abaixo (retorna esse painel).
-- o = {sub = false (sem seta), desc = "texto", cb = funcao}. key = nil vira um grupo so com seta.
local function Feature(parent, label, key, o)
    o = o or {}
    local hasSub = o.sub ~= false
    local holder = stack(parent, 2)
    local r = newRow(holder)
    rowLabel(r, label, o.desc, (key and 50 or 24) + (hasSub and 30 or 0))

    local sub, chev, lines
    local function open(v)
        sub.Visible = v
        chev.Rotation = v and 180 or 0
        for _, l in ipairs(lines) do l.BackgroundColor3 = v and accent() or T.dim end
    end
    if hasSub then
        local cbtn = new("TextButton", {Name = "Chevron", AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0, RH / 2), Size = UDim2.fromOffset(30, RH), BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, ZIndex = 3}, r)
        chev, lines = chevron(cbtn, UDim2.fromScale(0.5, 0.5))
        sub = new("Frame", {Name = "Sub", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = T.sub, BorderSizePixel = 0, Visible = false, LayoutOrder = 2}, holder)
        corner(sub, -4)
        new("UIStroke", {Color = T.line, Thickness = 1}, sub)
        new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10)}, sub)
        new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, sub)
        cbtn.Activated:Connect(function() open(not sub.Visible) end)
        onTheme(function()
            for _, l in ipairs(lines) do l.BackgroundColor3 = sub.Visible and accent() or T.dim end
        end)
    end
    if key then
        local setSw = switch(r, hasSub and -32 or 0)
        local btn = new("TextButton", {Size = UDim2.new(1, hasSub and -30 or 0, 0, RH), BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, ZIndex = 2}, r)
        btn.Activated:Connect(function()
            S[key] = not S[key]
            setSw(S[key])
            if o.cb then o.cb(S[key]) end
        end)
        refreshers[#refreshers + 1] = function() setSw(S[key], true) end
        onTheme(function() setSw(S[key], true) end)
    elseif hasSub then
        local btn = new("TextButton", {Size = UDim2.new(1, -30, 0, RH), BackgroundTransparency = 1, Text = "",
            AutoButtonColor = false, ZIndex = 2}, r)
        btn.Activated:Connect(function() open(not sub.Visible) end)
    end
    return sub
end

local function Slider(parent, label, get, set, mn, mx, step, suffix, desc)
    local holder = stack(parent, 0)
    local r = newRow(holder)
    rowLabel(r, label, desc, 74)
    local vb = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0, RH / 2),
        Size = UDim2.fromOffset(64, 20), BackgroundColor3 = T.item, BorderSizePixel = 0}, r)
    new("UICorner", {CornerRadius = UDim.new(0, 5)}, vb)
    local val = text(vb, "", {Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12})
    local tr = new("Frame", {Size = UDim2.new(1, 0, 0, isMobile and 26 or 20), BackgroundTransparency = 1,
        LayoutOrder = 2}, holder)
    local bar = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.4),
        Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = T.off, BorderSizePixel = 0}, tr)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, bar)
    local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BorderSizePixel = 0}, bar)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, fill)
    local knob = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(12, 12), BackgroundColor3 = T.text, BorderSizePixel = 0}, fill)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, knob)
    onTheme(function() fill.BackgroundColor3 = accent() end)
    local hit = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false}, tr)

    local function refresh()
        local v = get()
        fill.Size = UDim2.fromScale(math.clamp((v - mn) / (mx - mn), 0, 1), 1)
        local s = (step < 1) and string.format("%.2f", v) or string.format("%d", math.floor(v + 0.5))
        val.Text = s .. (suffix or "")
    end
    bindDrag(hit, function(pos)
        local w = bar.AbsoluteSize.X
        if w <= 0 then return end
        local v = mn + (mx - mn) * math.clamp((pos.X - bar.AbsolutePosition.X) / w, 0, 1)
        v = math.clamp(math.floor(v / step + 0.5) * step, mn, mx)
        set(tonumber(string.format("%.4f", v)))
        refresh()
    end)
    refreshers[#refreshers + 1] = refresh
    refresh()
    return holder
end

local function SK(parent, label, key, mn, mx, step, suffix, cb, desc)
    return Slider(parent, label, function() return S[key] end,
        function(v)
            S[key] = v
            if cb then cb(v) end
        end, mn, mx, step, suffix, desc)
end

-- dropdown: a lista abre inline, logo abaixo da linha (options pode ser tabela ou funcao que devolve a tabela)
local function Dropdown(parent, label, get, set, options, desc)
    local holder = stack(parent, 2)
    local r = newRow(holder)
    rowLabel(r, label, desc, 140)
    local btn = new("TextButton", {Name = "DropBtn", AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0, RH / 2), Size = UDim2.fromOffset(128, RH - 8), BackgroundColor3 = T.item,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false}, r)
    new("UICorner", {CornerRadius = UDim.new(0, 5)}, btn)
    new("UIStroke", {Color = T.line, Thickness = 1}, btn)
    local t = text(btn, "", {Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -28, 1, 0), TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd})
    local chev = chevron(btn, UDim2.new(1, -13, 0.5, 0))
    local list = new("Frame", {Name = "DropList", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.item, BorderSizePixel = 0, Visible = false, LayoutOrder = 2}, holder)
    new("UICorner", {CornerRadius = UDim.new(0, 6)}, list)
    new("UIPadding", {PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), PaddingLeft = UDim.new(0, 4),
        PaddingRight = UDim.new(0, 4)}, list)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, list)

    local function opts()
        if type(options) == "function" then return options() end
        return options
    end
    local function refresh() t.Text = tostring(get() or "-") end
    local function close()
        list.Visible = false
        chev.Rotation = 0
    end
    local function build()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
        local o = opts()
        if #o == 0 then
            text(list, "(none)", {Size = UDim2.new(1, 0, 0, RH - 4), TextSize = 12, TextColor3 = T.dim})
            return
        end
        for i, v in ipairs(o) do
            local b = new("TextButton", {Size = UDim2.new(1, 0, 0, RH - 4), BackgroundTransparency = 1,
                BorderSizePixel = 0, Text = tostring(v), TextSize = 12, Font = curFont(),
                TextColor3 = (v == get()) and accent() or T.text, TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = i, AutoButtonColor = false}, list)
            new("UIPadding", {PaddingLeft = UDim.new(0, 6)}, b)
            b.Activated:Connect(function()
                set(v)
                refresh()
                close()
            end)
        end
    end
    btn.Activated:Connect(function()
        if not list.Visible then build() end
        list.Visible = not list.Visible
        chev.Rotation = list.Visible and 180 or 0
    end)
    refreshers[#refreshers + 1] = refresh
    refresh()
    return holder, refresh
end

local function DK(parent, label, key, options, cb, desc)
    return Dropdown(parent, label, function() return S[key] end, function(v)
        S[key] = v
        if cb then cb(v) end
    end, options, desc)
end

local function Keybind(parent, label, key, clearable, desc)
    local r = newRow(parent)
    rowLabel(r, label, desc, 110)
    local btn = new("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0, RH / 2),
        Size = UDim2.fromOffset(96, RH - 8), BackgroundColor3 = T.item, BorderSizePixel = 0, Text = "",
        AutoButtonColor = false}, r)
    new("UICorner", {CornerRadius = UDim.new(0, 5)}, btn)
    new("UIStroke", {Color = T.line, Thickness = 1}, btn)
    local t = text(btn, "", {Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12})
    local listening = false
    local function refresh() t.Text = listening and "press a key" or tostring(S[key]) end
    btn.Activated:Connect(function()
        if listening then return end
        listening = true
        refresh()
        local c
        c = UIS.InputBegan:Connect(function(i)
            local ut = i.UserInputType
            if ut == Enum.UserInputType.Keyboard then
                if clearable and i.KeyCode == Enum.KeyCode.Backspace then
                    S[key] = "None"
                elseif i.KeyCode ~= Enum.KeyCode.Escape then
                    S[key] = i.KeyCode.Name
                end
            elseif ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.MouseButton2
                or ut == Enum.UserInputType.MouseButton3 then
                S[key] = ut.Name
            else
                return
            end
            listening = false
            c:Disconnect()
            refresh()
        end)
    end)
    refreshers[#refreshers + 1] = refresh
    refresh()
    return r
end

-- aceita "#RRGGBB", "RRGGBB" e "#RGB"
local function parseHex(str)
    str = tostring(str):gsub("#", ""):gsub("%s", "")
    if #str == 3 then str = str:gsub(".", function(c) return c .. c end) end
    if #str ~= 6 or str:find("%X") then return nil end
    return tonumber(str:sub(1, 2), 16), tonumber(str:sub(3, 4), 16), tonumber(str:sub(5, 6), 16)
end

local PALETTE = {
    {255, 255, 255}, {190, 198, 212}, {110, 120, 140}, {30, 34, 44},
    {255, 82, 82}, {255, 138, 40}, {255, 208, 50}, {150, 230, 70},
    {40, 210, 130}, {30, 210, 220}, {20, 168, 255}, {80, 100, 255},
    {150, 90, 255}, {232, 90, 232}, {255, 90, 160}, {170, 120, 80},
}

-- color picker: campo hex + quadrado saturacao/brilho + faixa de matiz (HSV, como o seletor do Roblox) + paleta.
-- o painel so e construido na primeira vez que abre.
local function ColorRow(parent, label, key, cb, desc)
    local holder = stack(parent, 2)
    local r = newRow(holder)
    rowLabel(r, label, desc, 60)
    local sw = new("TextButton", {Name = "Swatch", AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0, RH / 2), Size = UDim2.fromOffset(40, 18), BorderSizePixel = 0, Text = "",
        AutoButtonColor = false, ZIndex = 3}, r)
    new("UICorner", {CornerRadius = UDim.new(0, 5)}, sw)
    new("UIStroke", {Color = T.text, Transparency = 0.8, Thickness = 1}, sw)
    local rowBtn = new("TextButton", {Size = UDim2.new(1, -46, 0, RH), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, ZIndex = 2}, r)

    local h, s, v = 0, 0, 1
    local panel, built = nil, false
    local svBox, svDot, hueDot, hexBox

    local function readHSV()
        local hh, ss, vv = col(S[key]):ToHSV()
        if ss > 0.001 and vv > 0.001 then h = hh end
        s, v = ss, vv
    end
    local function hexText()
        local c = S[key]
        return string.format("#%02X%02X%02X", math.floor(c[1] + 0.5), math.floor(c[2] + 0.5), math.floor(c[3] + 0.5))
    end
    local function paint()
        sw.BackgroundColor3 = col(S[key])
        if built then
            svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            svDot.Position = UDim2.fromScale(s, 1 - v)
            hueDot.Position = UDim2.fromScale(0.5, h)
            hexBox.Text = hexText()
        end
    end
    local function commit()
        local c = Color3.fromHSV(h, s, v)
        S[key] = {math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)}
        paint()
        if cb then cb() end
    end
    local function setRGB(r8, g8, b8)
        S[key] = {r8, g8, b8}
        readHSV()
        paint()
        if cb then cb() end
    end

    local function build()
        built = true
        panel = new("Frame", {Name = "Picker", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = T.item, BorderSizePixel = 0, Visible = false, LayoutOrder = 2}, holder)
        new("UICorner", {CornerRadius = UDim.new(0, 6)}, panel)
        new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8)}, panel)
        new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, panel)

        local hr = new("Frame", {Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 1}, panel)
        text(hr, "Hex", {Size = UDim2.new(0, 36, 1, 0), TextColor3 = T.dim, TextSize = 12})
        hexBox = new("TextBox", {Name = "Hex", Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -40, 1, 0),
            BackgroundColor3 = T.sub, BorderSizePixel = 0, Text = hexText(), PlaceholderText = "#RRGGBB",
            PlaceholderColor3 = T.dim, TextColor3 = T.text, TextSize = 12, Font = curFont(), ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left}, hr)
        new("UICorner", {CornerRadius = UDim.new(0, 5)}, hexBox)
        new("UIPadding", {PaddingLeft = UDim.new(0, 8)}, hexBox)
        textObjs[#textObjs + 1] = hexBox
        hexBox.FocusLost:Connect(function()
            local r8, g8, b8 = parseHex(hexBox.Text)
            if r8 then setRGB(r8, g8, b8) else hexBox.Text = hexText() end
        end)

        local pr = new("Frame", {Size = UDim2.new(1, 0, 0, isMobile and 130 or 110), BackgroundTransparency = 1,
            LayoutOrder = 2}, panel)
        svBox = new("Frame", {Name = "SV", Size = UDim2.new(1, -26, 1, 0), BackgroundColor3 = Color3.fromHSV(h, 1, 1),
            BorderSizePixel = 0, Active = true}, pr)
        new("UICorner", {CornerRadius = UDim.new(0, 5)}, svBox)
        local white = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0}, svBox)
        new("UICorner", {CornerRadius = UDim.new(0, 5)}, white)
        new("UIGradient", {Transparency = NumberSequence.new(0, 1)}, white)
        local black = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
            BorderSizePixel = 0}, svBox)
        new("UICorner", {CornerRadius = UDim.new(0, 5)}, black)
        new("UIGradient", {Rotation = 90, Transparency = NumberSequence.new(1, 0)}, black)
        svDot = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10),
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3}, svBox)
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, svDot)
        new("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 2}, svDot)

        local hueBar = new("Frame", {Name = "Hue", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
            Size = UDim2.new(0, 18, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
            Active = true}, pr)
        new("UICorner", {CornerRadius = UDim.new(0, 5)}, hueBar)
        local stops = {}
        for i = 0, 6 do stops[#stops + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)) end
        new("UIGradient", {Rotation = 90, Color = ColorSequence.new(stops)}, hueBar)
        hueDot = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.new(1, 4, 0, 6), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3}, hueBar)
        new("UICorner", {CornerRadius = UDim.new(0, 3)}, hueDot)
        new("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 2}, hueDot)

        bindDrag(svBox, function(pos)
            local ap, as = svBox.AbsolutePosition, svBox.AbsoluteSize
            if as.X <= 0 or as.Y <= 0 then return end
            s = math.clamp((pos.X - ap.X) / as.X, 0, 1)
            v = 1 - math.clamp((pos.Y - ap.Y) / as.Y, 0, 1)
            commit()
        end)
        bindDrag(hueBar, function(pos)
            local ap, as = hueBar.AbsolutePosition, hueBar.AbsoluteSize
            if as.Y <= 0 then return end
            h = math.clamp((pos.Y - ap.Y) / as.Y, 0, 1)
            commit()
        end)

        local pal = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, LayoutOrder = 3}, panel)
        local cell = isMobile and 28 or 22
        new("UIGridLayout", {CellSize = UDim2.fromOffset(cell, cell), CellPadding = UDim2.fromOffset(6, 6),
            SortOrder = Enum.SortOrder.LayoutOrder}, pal)
        for i, c in ipairs(PALETTE) do
            local b = new("TextButton", {BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3]), BorderSizePixel = 0,
                Text = "", AutoButtonColor = false, LayoutOrder = i}, pal)
            new("UICorner", {CornerRadius = UDim.new(0, 5)}, b)
            new("UIStroke", {Color = T.text, Transparency = 0.85, Thickness = 1}, b)
            b.Activated:Connect(function() setRGB(c[1], c[2], c[3]) end)
        end
        readHSV()
        paint()
    end
    local function toggle()
        if not built then build() end
        panel.Visible = not panel.Visible
    end
    sw.Activated:Connect(toggle)
    rowBtn.Activated:Connect(toggle)
    refreshers[#refreshers + 1] = function()
        readHSV()
        paint()
    end
    readHSV()
    paint()
    return holder
end

local function Button(parent, label, cb)
    local b = new("TextButton", {Size = UDim2.new(1, 0, 0, RH - 2), BackgroundColor3 = T.item, BorderSizePixel = 0,
        Text = label, TextColor3 = T.text, TextSize = 12, Font = curFont(), AutoButtonColor = true,
        LayoutOrder = nextOrder(parent)}, parent)
    new("UICorner", {CornerRadius = UDim.new(0, 6)}, b)
    new("UIStroke", {Color = T.line, Thickness = 1}, b)
    textObjs[#textObjs + 1] = b
    b.Activated:Connect(cb)
    return b
end

local function Input(parent, label, default, placeholder)
    local r = newRow(parent)
    rowLabel(r, label, nil, 150)
    local tb = new("TextBox", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0, RH / 2),
        Size = UDim2.fromOffset(136, RH - 8), BackgroundColor3 = T.item, BorderSizePixel = 0, Text = default,
        PlaceholderText = placeholder or "", PlaceholderColor3 = T.dim, TextColor3 = T.text, TextSize = 12,
        Font = curFont(), ClearTextOnFocus = false}, r)
    new("UICorner", {CornerRadius = UDim.new(0, 5)}, tb)
    new("UIStroke", {Color = T.line, Thickness = 1}, tb)
    textObjs[#textObjs + 1] = tb
    return tb
end

-- linha so de leitura (valor mudando em tempo real)
local function StatusRow(parent, label)
    local r = newRow(parent)
    text(r, label, {Size = UDim2.new(0, 50, 0, RH), TextColor3 = T.dim, TextSize = 12})
    return text(r, "-", {Position = UDim2.fromOffset(54, 0), Size = UDim2.new(1, -54, 0, RH),
        TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd})
end

-- card = bloco com titulo; page.cols = duas colunas (viram uma so em janela estreita)
local function Card(page, title, colIdx)
    local card = new("Frame", {Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.card, BorderSizePixel = 0, LayoutOrder = #page.cards + 1}, page.cols[colIdx or 1])
    corner(card, -2)
    new("UIStroke", {Color = T.line, Thickness = 1}, card)
    new("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12)}, card)
    new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, card)
    text(card, title, {Size = UDim2.new(1, 0, 0, 22), TextSize = 12, Font = Enum.Font.GothamBold,
        TextColor3 = T.dim, LayoutOrder = 0})
    panelObjs[#panelObjs + 1] = {card, 0.6}
    page.cards[#page.cards + 1] = {frame = card, col = colIdx or 1}
    return card
end

----------------------------------------------------------------------------
-- window
----------------------------------------------------------------------------
local guiParent
do
    local ok, h = pcall(function() return gethui and gethui() end)
    guiParent = (ok and h) or LP:WaitForChild("PlayerGui")
end

local gui = new("ScreenGui", {Name = "RagWare", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 200,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, guiParent)
local overlay = new("ScreenGui", {Name = "RagWareOverlay", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, guiParent)

local SIDE_W = 150
local MIN_W, MIN_H = 440, 300
local NARROW_AT = 560   -- largura util do conteudo abaixo da qual as duas colunas viram uma

local win = new("Frame", {Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(S.win_w, S.win_h), BackgroundColor3 = T.bg, BorderSizePixel = 0, Active = true}, gui)
corner(win, 0)
new("UIStroke", {Color = T.line, Thickness = 1}, win)
local uiscale = new("UIScale", {}, win)
new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255),
    Color3.fromRGB(196, 204, 220))}, win)
panelObjs[#panelObjs + 1] = {win, 1}

-- filete de destaque no topo (some nas pontas)
local topLine = new("Frame", {Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 0, 2),
    BorderSizePixel = 0, ZIndex = 8}, win)
new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.15, 0), NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, 1)})}, topLine)

-- sidebar
local side = new("Frame", {Name = "Side", Size = UDim2.new(0, SIDE_W, 1, 0), BackgroundColor3 = T.side,
    BorderSizePixel = 0}, win)
corner(side, 0)
local sideFill = new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
    Size = UDim2.new(0, 18, 1, 0), BackgroundColor3 = T.side, BorderSizePixel = 0}, side)   -- quadra os cantos da direita
new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = T.line, BorderSizePixel = 0, ZIndex = 2}, side)
panelObjs[#panelObjs + 1] = {side, 1}
panelObjs[#panelObjs + 1] = {sideFill, 1}

local logo = text(side, "", {Position = UDim2.fromOffset(18, 13), Size = UDim2.new(1, -24, 0, 24), TextSize = 20,
    Font = Enum.Font.GothamBold, RichText = true})
text(side, "v3.0", {Position = UDim2.fromOffset(19, 36), Size = UDim2.new(1, -24, 0, 14), TextSize = 11,
    TextColor3 = T.dim})
local tabs = new("Frame", {Position = UDim2.fromOffset(8, 64), Size = UDim2.new(1, -16, 1, -128),
    BackgroundTransparency = 1}, side)
new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, tabs)

local foot = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -12),
    Size = UDim2.new(1, -28, 0, 36), BackgroundTransparency = 1}, side)
local avatar = new("ImageLabel", {Position = UDim2.fromOffset(0, 3), Size = UDim2.fromOffset(30, 30),
    BackgroundColor3 = T.item, BorderSizePixel = 0}, foot)
new("UICorner", {CornerRadius = UDim.new(1, 0)}, avatar)
text(foot, LP.DisplayName, {Position = UDim2.fromOffset(38, 2), Size = UDim2.new(1, -38, 0, 17), TextSize = 12,
    Font = Enum.Font.GothamBold, TextTruncate = Enum.TextTruncate.AtEnd})
text(foot, "@" .. LP.Name, {Position = UDim2.fromOffset(38, 18), Size = UDim2.new(1, -38, 0, 14), TextSize = 11,
    TextColor3 = T.dim, TextTruncate = Enum.TextTruncate.AtEnd})
task.spawn(function()
    local ok, img = pcall(function()
        return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    end)
    if ok and img then avatar.Image = img end
end)

-- area principal
local main = new("Frame", {Name = "Main", Position = UDim2.fromOffset(SIDE_W, 0), Size = UDim2.new(1, -SIDE_W, 1, 0),
    BackgroundTransparency = 1}, win)
local pageTitle = text(main, "Combat", {Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -110, 0, 46),
    TextSize = 17, Font = Enum.Font.GothamBold})
local content = new("Frame", {Position = UDim2.fromOffset(16, 48), Size = UDim2.new(1, -30, 1, -60),
    BackgroundTransparency = 1, ClipsDescendants = true}, main)

local dragBar = new("Frame", {Name = "DragBar", Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1,
    Active = true, ZIndex = 4}, win)
local closeBtn = new("TextButton", {Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -44, 0, 10),
    Size = UDim2.fromOffset(28, 26), BackgroundColor3 = T.item, BorderSizePixel = 0, Text = "", ZIndex = 6}, win)
new("UICorner", {CornerRadius = UDim.new(0, 6)}, closeBtn)
for _, rot in ipairs({45, -45}) do
    new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(12, 2), Rotation = rot, BackgroundColor3 = T.dim, BorderSizePixel = 0, ZIndex = 7}, closeBtn)
end
closeBtn.Activated:Connect(function() win.Visible = false end)

-- paginas e abas (a ordem das abas se troca aqui)
local TAB_ORDER = {"Combat", "Visual", "Player", "Config"}
local pages, tabBtns = {}, {}

local function makePage()
    local sf = new("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = isMobile and 4 or 3, ScrollBarImageColor3 = T.off, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false}, content)
    new("UIPadding", {PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 14), PaddingRight = UDim.new(0, 8)}, sf)
    local grid = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1}, sf)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder}, grid)
    local cols = {}
    for i = 1, 2 do
        cols[i] = new("Frame", {Size = UDim2.new(0.5, -5, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, LayoutOrder = i}, grid)
        new("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, cols[i])
    end
    return {sf = sf, cols = cols, cards = {}}
end

local function selectTab(name)
    for n, pg in pairs(pages) do pg.sf.Visible = (n == name) end
    for n, t in pairs(tabBtns) do t.sel = (n == name) end
    pageTitle.Text = name
    applyTheme()
end

for i, name in ipairs(TAB_ORDER) do
    local b = new("TextButton", {Size = UDim2.new(1, 0, 0, isMobile and 40 or 34), BackgroundColor3 = T.item,
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = i}, tabs)
    new("UICorner", {CornerRadius = UDim.new(0, 7)}, b)
    local bar = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(3, 16), BorderSizePixel = 0, Visible = false}, b)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, bar)
    local lbl = text(b, name, {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -16, 1, 0), TextSize = 13,
        TextColor3 = T.dim})
    tabBtns[name] = {btn = b, bar = bar, lbl = lbl, sel = false}
    pages[name] = makePage()
    b.Activated:Connect(function() selectTab(name) end)
end

onTheme(function()
    for _, t in pairs(tabBtns) do
        t.bar.Visible = t.sel
        t.bar.BackgroundColor3 = accent()
        t.lbl.TextColor3 = t.sel and T.text or T.dim
        t.btn.BackgroundTransparency = t.sel and 0.5 or 1
    end
end)

onTheme(function()
    local a = S.ui_accent
    topLine.BackgroundColor3 = accent()
    logo.Text = string.format('Rag<font color="rgb(%d,%d,%d)">Ware</font>', a[1], a[2], a[3])
    for _, c in ipairs(cornerObjs) do c[1].CornerRadius = UDim.new(0, math.max(S.ui_corner + c[2], 3)) end
    for _, p in ipairs(panelObjs) do p[1].BackgroundTransparency = math.clamp(S.ui_trans * p[2], 0, 1) end
    for _, d in ipairs(descObjs) do d.Visible = S.ui_desc end
    local f = curFont()
    for _, o in ipairs(textObjs) do o.Font = f end
end)

-- colunas: duas lado a lado em janela larga, uma so em janela estreita
local lastNarrow = nil
local function setColumns(w)
    local narrow = (w - SIDE_W - 30) < NARROW_AT
    if narrow == lastNarrow then return end
    lastNarrow = narrow
    for _, pg in pairs(pages) do
        pg.cols[1].Size = narrow and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -5, 0, 0)
        pg.cols[2].Visible = not narrow
        for _, c in ipairs(pg.cards) do
            c.frame.Parent = (narrow or c.col == 1) and pg.cols[1] or pg.cols[2]
        end
    end
end

-- tamanho/posicao da janela (S.win_*), com limites e shrink do UIScale em telas pequenas
local function layout()
    local c = Workspace.CurrentCamera
    if not c then return end
    local vp, s = c.ViewportSize, S.ui_scale
    local fit = math.min(1, vp.X * 0.98 / (MIN_W * s), vp.Y * 0.96 / (MIN_H * s))
    local sc = s * fit
    uiscale.Scale = sc
    local w = math.clamp(S.win_w, MIN_W, math.max(MIN_W, vp.X * 0.98 / sc))
    local h = math.clamp(S.win_h, MIN_H, math.max(MIN_H, vp.Y * 0.96 / sc))
    win.Size = UDim2.fromOffset(w, h)
    local hw, hh = w * sc / 2, h * sc / 2
    local cx = math.clamp(S.win_cx * vp.X, hw, math.max(hw, vp.X - hw))
    local cy = math.clamp(S.win_cy * vp.Y, hh, math.max(hh, vp.Y - hh))
    win.Position = UDim2.fromScale(cx / vp.X, cy / vp.Y)
    setColumns(w)
end

-- alca de redimensionar: o canto e escolhido em Config > Window
local grip = new("Frame", {Name = "Grip", BackgroundTransparency = 1, Active = true, ZIndex = 20}, win)
local gripLines = {}
for i = 1, 3 do
    gripLines[i] = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 21}, grip)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, gripLines[i])
end

local CORNERS = {
    ["Bottom right"] = {1, 1}, ["Bottom left"] = {0, 1}, ["Top right"] = {1, 0}, ["Top left"] = {0, 0},
}

local function updateGrip()
    local cr = CORNERS[S.resize_corner] or CORNERS["Bottom right"]
    local g = isMobile and 34 or 24
    grip.Visible = S.resize_on
    grip.Size = UDim2.fromOffset(g, g)
    grip.AnchorPoint = Vector2.new(cr[1], cr[2])
    grip.Position = UDim2.new(cr[1], cr[1] == 1 and -3 or 3, cr[2], cr[2] == 1 and -3 or 3)
    for i, l in ipairs(gripLines) do
        local len = i * g * 0.3
        local d = len / 2.83
        l.Position = UDim2.fromOffset(cr[1] == 1 and (g - d) or d, cr[2] == 1 and (g - d) or d)
        l.Size = UDim2.fromOffset(len, 2)
        l.Rotation = (cr[1] == cr[2]) and -45 or 45
        l.BackgroundColor3 = accent()
    end
    local topLeft = S.resize_on and cr[1] == 0 and cr[2] == 0
    logo.Position = UDim2.fromOffset(topLeft and 38 or 18, 13)
end
onTheme(updateGrip)

-- arrastar / redimensionar / botao flutuante: um unico estado de "drag" compartilhado
local drag = nil

local function beginDrag(kind, i, extra)
    drag = extra or {}
    drag.kind = kind
    drag.input = i
    drag.start = Vector2.new(i.Position.X, i.Position.Y)
    drag.moved = false
end

dragBar.InputBegan:Connect(function(i)
    if pointerDown(i) then
        beginDrag("move", i, {target = win, center = win.AbsolutePosition + win.AbsoluteSize / 2})
    end
end)

grip.InputBegan:Connect(function(i)
    if pointerDown(i) then
        beginDrag("resize", i, {
            corner = CORNERS[S.resize_corner] or CORNERS["Bottom right"],
            w = win.Size.X.Offset, h = win.Size.Y.Offset,
            center = win.AbsolutePosition + win.AbsoluteSize / 2,
        })
    end
end)

conn(UIS.InputChanged:Connect(function(i)
    if not drag then return end
    local t = i.UserInputType
    if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
    if t == Enum.UserInputType.Touch and drag.input.UserInputType == Enum.UserInputType.Touch
        and i ~= drag.input then
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local d = Vector2.new(i.Position.X, i.Position.Y) - drag.start
    if d.Magnitude > 6 then drag.moved = true end
    if not drag.moved then return end

    if drag.kind == "resize" then
        local sc = uiscale.Scale
        local right, bottom = drag.corner[1] == 1, drag.corner[2] == 1
        local nw = drag.w + (right and d.X or -d.X) / sc
        local nh = drag.h + (bottom and d.Y or -d.Y) / sc
        nw = math.clamp(nw, MIN_W, math.min(1100, math.max(MIN_W, vp.X * 0.98 / sc)))
        nh = math.clamp(nh, MIN_H, math.min(800, math.max(MIN_H, vp.Y * 0.96 / sc)))
        local dw, dh = (nw - drag.w) * sc, (nh - drag.h) * sc
        local cx = drag.center.X + (right and dw / 2 or -dw / 2)
        local cy = drag.center.Y + (bottom and dh / 2 or -dh / 2)
        win.Size = UDim2.fromOffset(nw, nh)
        win.Position = UDim2.fromScale(cx / vp.X, cy / vp.Y)
        S.win_w, S.win_h, S.win_cx, S.win_cy = nw, nh, cx / vp.X, cy / vp.Y
        setColumns(nw)
    else
        local tg = drag.target
        local hw, hh = tg.AbsoluteSize.X / 2, tg.AbsoluteSize.Y / 2
        local p = drag.center + d
        local cx = math.clamp(p.X, hw, math.max(hw, vp.X - hw))
        local cy = math.clamp(p.Y, hh, math.max(hh, vp.Y - hh))
        tg.Position = UDim2.fromScale(cx / vp.X, cy / vp.Y)
        if drag.kind == "move" then S.win_cx, S.win_cy = cx / vp.X, cy / vp.Y end
    end
end))

conn(UIS.InputEnded:Connect(function(i)
    if drag and pointerDown(i) then
        local d = drag
        drag = nil
        if d.kind == "float" and not d.moved and d.onTap then d.onTap() end
    end
end))

local floatBtn = new("TextButton", {Name = "RagWareToggle", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.06, 0.3), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = T.side,
    Text = "R", TextSize = 20, Font = Enum.Font.GothamBold, AutoButtonColor = false, Visible = S.ui_btn}, gui)
new("UICorner", {CornerRadius = UDim.new(1, 0)}, floatBtn)
local floatStroke = new("UIStroke", {Thickness = 2}, floatBtn)
onTheme(function()
    floatBtn.TextColor3 = accent()
    floatStroke.Color = accent()
    floatBtn.Visible = S.ui_btn
end)
floatBtn.InputBegan:Connect(function(i)
    if pointerDown(i) then
        beginDrag("float", i, {target = floatBtn, center = floatBtn.AbsolutePosition + floatBtn.AbsoluteSize / 2,
            onTap = function() win.Visible = not win.Visible end})
    end
end)

local aimHeld, aimToggled = false, false

local aimBtn = new("TextButton", {Name = "RagWareAim", AnchorPoint = Vector2.new(0.5, 0.5), Text = "AIM",
    TextSize = 15, Font = Enum.Font.GothamBold, BackgroundColor3 = T.card, BackgroundTransparency = 0.1,
    TextColor3 = T.text, AutoButtonColor = false, Visible = false}, gui)
new("UICorner", {CornerRadius = UDim.new(1, 0)}, aimBtn)
local aimStroke = new("UIStroke", {Thickness = 2}, aimBtn)
onTheme(function() aimStroke.Color = accent() end)
aimBtn.InputBegan:Connect(function(i)
    if pointerDown(i) then
        if S.aim_mode == "Toggle" then aimToggled = not aimToggled else aimHeld = true end
        local c
        c = i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then
                aimHeld = false
                c:Disconnect()
            end
        end)
    end
end)

----------------------------------------------------------------------------
-- pages
----------------------------------------------------------------------------
local trigStatus, status, refreshList   -- usados pela logica fora deste bloco
do
local card, sb          -- card atual / painel de config (sub) da feature atual

-- Combat ------------------------------------------------------------------
local PC = pages.Combat

card = Card(PC, "Aimbot", 1)
sb = Feature(card, "Aimbot", "aimbot")
DK(sb, "Mode", "aim_mode", {"Hold", "Toggle", "Always"})
if not isMobile then Keybind(sb, "Key", "aim_key") end
DK(sb, "Method", "aim_method", {"Camera", "Mouse"}, nil, "Mouse needs an executor (mousemoverel)")
DK(sb, "Hitbox", "aim_part", {"Head", "Torso", "Root", "Closest"})
DK(sb, "Priority", "aim_priority", {"Crosshair", "Distance", "Health"})
SK(sb, "Smooth", "smooth", 0, 99, 1, "%", nil, "0% snaps instantly")
SK(sb, "Max distance", "aim_maxdist", 50, 5000, 50, " st")
sb = Feature(card, "Humanizer", "humanize", {desc = "Human-like imperfections in the aim"})
SK(sb, "Noise", "human_noise", 0, 5, 0.1, " deg", nil, "Smooth wander around the target")
SK(sb, "Offset", "human_offset", 0, 2, 0.1, " st", nil, "Random aim point inside the hitbox")
SK(sb, "Reaction delay", "human_delay", 0, 500, 10, " ms", nil, "Waits before engaging a new target")
SK(sb, "Speed variation", "human_speed", 0, 60, 1, "%")
sb = Feature(card, "Show FOV", "show_fov")
SK(sb, "Size", "aim_fov", 10, 800, 5, " px")
DK(sb, "Origin", "fov_origin", {"Mouse", "Center"})
ColorRow(sb, "Color", "fov_color")
SK(sb, "Thickness", "fov_thick", 0.5, 4, 0.5, "")
Toggle(card, "Fullscreen", "fov_fullscreen", nil, "No FOV limit, the circle is hidden")

card = Card(PC, "Checks", 1)
Toggle(card, "Wall check", "wallcheck", nil, "Skips targets behind walls")
Toggle(card, "Team check", "teamcheck")
Toggle(card, "Death check", "deathcheck", nil, "Skips dead targets and pauses while you are dead")
Toggle(card, "ForceField check", "ff_check")
Toggle(card, "Downed check", "downcheck", nil, "Skips ragdolled or knocked players")
Toggle(card, "Friend check", "friendcheck")
Toggle(card, "Invisible check", "invischeck")

card = Card(PC, "Triggerbot", 2)
sb = Feature(card, "Triggerbot", "trigger")
DK(sb, "Hitbox", "trigger_part", {"Any", "Head", "Body"})
DK(sb, "Fire mode", "trigger_mode", {"Click", "Hold"})
DK(sb, "Fire method", "fire_method", {"Auto", "Executor", "VirtualInput", "Tool"}, nil,
    "Auto tries executor input, VirtualInput, then the held Tool")
SK(sb, "Reaction delay", "trigger_delay", 0, 500, 5, " ms")
SK(sb, "Click interval", "trigger_interval", 30, 600, 10, " ms")
SK(sb, "Range", "trigger_range", 50, 3000, 50, " st")
SK(sb, "Tolerance", "trigger_radius", 0, 30, 1, " px", nil, "Pixels around the crosshair that count as a hit")
Toggle(sb, "Only while aiming", "trigger_aimkey")
trigStatus = StatusRow(sb, "Status")
Button(sb, "Test fire in 3 s", function()
    TR.note = "testing in 3 s..."
    task.delay(3, function()
        local m = TR.fire()
        TR.note = m and ("test OK via " .. m) or "test failed: no fire method"
    end)
end)

card = Card(PC, "Spinbot", 2)
sb = Feature(card, "Spinbot", "spinbot")
DK(sb, "Mode", "spin_mode", {"Spin", "Jitter", "Random", "Backwards"})
DK(sb, "Method", "spin_method", {"CFrame", "Velocity"}, nil, "Velocity only works in Spin mode")
SK(sb, "Speed", "spin_speed", 30, 3600, 10, " deg/s")
Toggle(sb, "Reverse", "spin_reverse")
SK(sb, "Jitter angle", "spin_jitter", 5, 180, 5, " deg")
SK(sb, "Jitter rate", "spin_rate", 1, 60, 1, " Hz")
Toggle(sb, "Pause while shooting", "spin_pause", nil, "Stops spinning when you click or the triggerbot fires")
SK(sb, "Resume delay", "spin_resume", 0, 600, 10, " ms")
Toggle(sb, "Face aim while shooting", "spin_face", nil, "Turns the body toward the camera so shots go straight")

card = Card(PC, "Touch", 2)
sb = Feature(card, "AIM button", "aim_button")
SK(sb, "Position X", "aim_btn_x", 5, 95, 1, "%")
SK(sb, "Position Y", "aim_btn_y", 5, 95, 1, "%")
SK(sb, "Size", "aim_btn_size", 40, 120, 2, " px")

-- Visual ------------------------------------------------------------------
local PV = pages.Visual

card = Card(PV, "ESP", 1)
Feature(card, "Box", "esp_box", {sub = false})
Feature(card, "Skeleton", "esp_skel", {sub = false})
sb = Feature(card, "Name", "esp_name")
DK(sb, "Mode", "esp_namemode", {"Display", "Username"})
Feature(card, "Head circle", "esp_head", {sub = false})
Feature(card, "Health bar", "esp_health", {sub = false})
sb = Feature(card, "Distance", "esp_dist")
DK(sb, "Unit", "esp_unit", {"Studs", "Meters"})
sb = Feature(card, "Tracers", "esp_tracer", {desc = "Lines from the screen to every player"})
DK(sb, "From", "tracer_from", {"Bottom", "Center", "Top", "Mouse"})
DK(sb, "To", "tracer_to", {"Feet", "Root", "Head"})

card = Card(PV, "ESP style", 1)
ColorRow(card, "Enemy color", "esp_color")
ColorRow(card, "Team color", "esp_team_color")
Toggle(card, "Show teammates", "esp_team")
SK(card, "Max distance", "esp_maxdist", 100, 10000, 100, " st")
SK(card, "Line thickness", "esp_thick", 1, 4, 0.5, "")
SK(card, "Text size", "esp_text", 9, 22, 1, "")

card = Card(PV, "Chams", 2)
sb = Feature(card, "Chams", "chams", {desc = "Highlight, visible through walls"})
ColorRow(sb, "Fill color", "chams_fill_c")
SK(sb, "Fill transparency", "chams_fill", 0, 1, 0.05, "")
ColorRow(sb, "Outline color", "chams_line_c")
SK(sb, "Outline transparency", "chams_line", 0, 1, 0.05, "")
sb = Feature(card, "Occluded chams", "chams_occ", {desc = "Silhouette only where walls hide the target"})
ColorRow(sb, "Fill color", "occ_fill_c")
SK(sb, "Fill transparency", "occ_fill", 0, 1, 0.05, "")
ColorRow(sb, "Outline color", "occ_line_c")
SK(sb, "Outline transparency", "occ_line", 0, 1, 0.05, "")
Toggle(sb, "Include accessories", "chams_acc")
SK(card, "Max players", "chams_max", 1, 30, 1, "", nil, "Roblox draws 31 highlights; occluded uses 2 per player")

-- Player ------------------------------------------------------------------
local PP = pages.Player

card = Card(PP, "Movement", 1)
sb = Feature(card, "WalkSpeed", "walk_on")
SK(sb, "Speed", "walk", 16, 300, 1, "")
sb = Feature(card, "JumpPower", "jump_on")
SK(sb, "Power", "jump", 50, 400, 1, "")
Toggle(card, "Infinite jump", "infjump")
Toggle(card, "Noclip", "noclip")
sb = Feature(card, "Fly", "fly")
SK(sb, "Speed", "fly_speed", 10, 300, 5, "")
sb = Feature(card, "Bunny hop", "bhop_on")
DK(sb, "Mode", "bhop_mode", {"Hold", "Moving", "Always"}, nil, "Hold = while Space is held, Moving = while you move")
Toggle(sb, "Air speed", "bhop_boost", nil, "Keeps a constant speed in the air")
SK(sb, "Speed", "bhop_speed", 16, 120, 1, "")

card = Card(PP, "Camera", 2)
sb = Feature(card, "Third person", "tp_on", {desc = "Pulls the camera back"})
SK(sb, "Distance", "tp_dist", 2, 60, 1, " st")
SK(sb, "Height", "tp_height", -5, 15, 0.5, " st")
SK(sb, "Side offset", "tp_side", -12, 12, 0.5, " st")
Toggle(sb, "Collision", "tp_collide", nil, "Keeps the camera from clipping into walls")
Toggle(sb, "Show own body", "tp_body")
if not isMobile then Keybind(sb, "Key", "tp_key", true, "Backspace clears the key") end
sb = Feature(card, "FOV changer", "camfov_on")
SK(sb, "Field of view", "camfov", 40, 120, 1, "")

card = Card(PP, "World", 2)
sb = Feature(card, "Gravity", "grav_on")
SK(sb, "Value", "grav", 0, 400, 5, "")

card = Card(PP, "Misc", 2)
Toggle(card, "Anti AFK", "antiafk")
Button(card, "Reset character", function()
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = 0 end
end)

-- Config ------------------------------------------------------------------
local PF = pages.Config

card = Card(PF, "Interface", 1)
ColorRow(card, "Accent color", "ui_accent", applyTheme)
SK(card, "Transparency", "ui_trans", 0, 0.8, 0.02, "", applyTheme)
SK(card, "Scale", "ui_scale", 0.6, 1.6, 0.05, "x", layout)
SK(card, "Corner radius", "ui_corner", 0, 16, 1, " px", applyTheme)
DK(card, "Font", "ui_font", {"GothamMedium", "Gotham", "Ubuntu", "SourceSans", "Arial", "Code"}, applyTheme)
Keybind(card, "Menu key", "ui_key")
Toggle(card, "Floating button", "ui_btn", applyTheme)
Toggle(card, "Show descriptions", "ui_desc", applyTheme, "Small hint text under each option")

card = Card(PF, "Window", 1)
sb = Feature(card, "Resize handle", "resize_on", {cb = updateGrip, desc = "Drag the top bar to move, pull the grip to resize"})
DK(sb, "Corner", "resize_corner", {"Bottom right", "Bottom left", "Top right", "Top left"}, updateGrip)
Button(card, "Reset window size and position", function()
    S.win_w, S.win_h, S.win_cx, S.win_cy = DEFAULTS.win_w, DEFAULTS.win_h, DEFAULTS.win_cx, DEFAULTS.win_cy
    layout()
end)

card = Card(PF, "Configs", 2)
local nameBox = Input(card, "Name", "default", "config name")
local names, sel, statusLbl = {}, 0, nil
local savedRefresh, savedHolder
function status(m) if statusLbl then statusLbl.Text = m end end
function refreshList(pick)
    names = cfgList()
    sel = 0
    if pick then
        for i, n in ipairs(names) do
            if n == pick then sel = i end
        end
    end
    if sel == 0 and #names > 0 then sel = 1 end
    if savedRefresh then savedRefresh() end
end
savedHolder, savedRefresh = Dropdown(card, "Saved", function() return names[sel] or "(none)" end, function(v)
    for i, n in ipairs(names) do
        if n == v then sel = i end
    end
end, function() return names end)

Button(card, "Save config", function()
    local ok, err = cfgSave(nameBox.Text)
    if ok then
        local n = clean(nameBox.Text)
        refreshList(n)
        status("saved: " .. n)
    else
        status("error: " .. tostring(err))
    end
end)
Button(card, "Load selected", function()
    local n = names[sel] or clean(nameBox.Text)
    local ok, err = cfgRead(n)
    if ok then
        refreshAll()
        layout()
        nameBox.Text = n
        status("loaded: " .. n)
    else
        status("error: " .. tostring(err))
    end
end)
Button(card, "Delete selected", function()
    local n = names[sel]
    if n then
        cfgDelete(n)
        refreshList()
        status("deleted: " .. n)
    end
end)
Button(card, "Autoload selected on start", function()
    local n = names[sel]
    if not hasFS then
        status("autoload needs writefile")
    elseif n then
        autoloadSet(n)
        status("autoload: " .. n)
    else
        status("select a config first")
    end
end)
Button(card, "Reset to defaults", function()
    for k, v in pairs(DEFAULTS) do S[k] = copy(v) end
    refreshAll()
    layout()
    status("defaults restored")
end)
statusLbl = text(card, "", {Size = UDim2.new(1, 0, 0, 18), TextSize = 11, TextColor3 = T.dim,
    TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = nextOrder(card)})

card = Card(PF, "Script", 2)
Button(card, "Unload", function()
    if ENV.__RAGWARE_UNLOAD then ENV.__RAGWARE_UNLOAD() end
end)
end   -- fim do bloco das paginas

----------------------------------------------------------------------------
-- combat logic: checks, aimbot
----------------------------------------------------------------------------
local unloading = false

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
pcall(function() rayParams.RespectCanCollide = true end)

local function aimKeyActive()
    if S.aim_mode == "Always" then return true end
    if S.aim_mode == "Toggle" then return aimToggled end
    return aimHeld
end

local function aimOn() return S.aimbot and aimKeyActive() end

-- tiro do jogador: clique esquerdo fora do menu. O spinbot usa isto para parar de girar enquanto voce atira
local fireHeld, lastShotInput = false, -1000

local function overMenu(pos)
    if not win.Visible then return false end
    local p, sz = win.AbsolutePosition, win.AbsoluteSize
    return pos.X >= p.X and pos.X <= p.X + sz.X and pos.Y >= p.Y and pos.Y <= p.Y + sz.Y
end

-- atirando agora, ou ha menos de "Resume delay" ms (clique solto / triggerbot em cima de um alvo)
local function shooting()
    local now = os.clock()
    local resume = S.spin_resume / 1000
    return fireHeld or now - lastShotInput < resume or now - TR.lastActive < resume
end

local function origin(c)
    if S.fov_origin == "Mouse" and not isMobile then return UIS:GetMouseLocation() end
    local vp = c.ViewportSize
    return Vector2.new(vp.X / 2, vp.Y / 2)
end

local function sameTeam(p) return LP.Team ~= nil and p.Team == LP.Team end

-- voce esta vivo? (so conta quando o death check esta ligado)
local function selfAlive()
    if not S.deathcheck then return true end
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

-- amigos: IsFriendsWith e assincrono, entao guardamos em cache e consultamos em segundo plano
local friendCache, downCache = {}, {}

local function isFriend(p)
    local v = friendCache[p.UserId]
    if v == nil then
        friendCache[p.UserId] = false
        task.spawn(function()
            local ok, r = pcall(function() return LP:IsFriendsWith(p.UserId) end)
            friendCache[p.UserId] = (ok and r) and true or false
        end)
        return false
    end
    return v
end

local DOWN_FLAGS = {"Knocked", "KnockedOut", "Downed", "KO", "Ragdolled", "Ragdoll", "IsDead", "Dead"}

-- caido/ragdoll: estados do Humanoid + flags comuns (atributo ou BoolValue), com cache de 0.25s
local function isDowned(p, ch, hum)
    local now = os.clock()
    local c = downCache[p]
    if c and now - c.t < 0.25 then return c.v end
    local v = hum.PlatformStand
    if not v then
        local st = hum:GetState()
        v = st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown
            or st == Enum.HumanoidStateType.Dead
    end
    if not v then
        for _, n in ipairs(DOWN_FLAGS) do
            local o = ch:FindFirstChild(n)
            if ch:GetAttribute(n) == true or hum:GetAttribute(n) == true or p:GetAttribute(n) == true
                or (o and o:IsA("BoolValue") and o.Value) then
                v = true
                break
            end
        end
    end
    v = v and true or false
    downCache[p] = {t = now, v = v}
    return v
end

local function isInvisible(ch)
    local head = ch:FindFirstChild("Head")
    local torso = ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso")
    return head ~= nil and torso ~= nil and head.Transparency >= 0.9 and torso.Transparency >= 0.9
end

-- devolve character, humanoid se o jogador e um alvo valido (aimbot e triggerbot usam esta funcao)
local function target(p)
    if p == LP then return nil end
    local ch = p.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    if S.deathcheck and (hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead) then return nil end
    if S.teamcheck and sameTeam(p) then return nil end
    if S.ff_check and ch:FindFirstChildOfClass("ForceField") then return nil end
    if S.friendcheck and isFriend(p) then return nil end
    if S.invischeck and isInvisible(ch) then return nil end
    if S.downcheck and isDowned(p, ch, hum) then return nil end
    return ch, hum
end

local function aimPart(ch, c, org)
    local m = S.aim_part
    if m == "Head" then return ch:FindFirstChild("Head") end
    if m == "Torso" then return ch:FindFirstChild("UpperTorso") or ch:FindFirstChild("Torso") end
    if m == "Root" then return ch:FindFirstChild("HumanoidRootPart") end
    local best, bd
    for _, n in ipairs({"Head", "UpperTorso", "Torso", "HumanoidRootPart"}) do
        local part = ch:FindFirstChild(n)
        if part then
            local sp = c:WorldToViewportPoint(part.Position)
            local d = (Vector2.new(sp.X, sp.Y) - org).Magnitude
            if not bd or d < bd then best, bd = part, d end
        end
    end
    return best
end

local function visible(c, part, ch)
    local o = c.CFrame.Position
    local hit = Workspace:Raycast(o, part.Position - o, rayParams)
    return hit == nil or hit.Instance:IsDescendantOf(ch)
end

local function getTarget(c, org)
    local best, bestScore
    local cp = c.CFrame.Position
    for _, p in ipairs(Players:GetPlayers()) do
        local ch, hum = target(p)
        if ch then
            local part = aimPart(ch, c, org)
            if part then
                local sp, onScreen = c:WorldToViewportPoint(part.Position)
                if onScreen then
                    local d2 = (Vector2.new(sp.X, sp.Y) - org).Magnitude
                    local d3 = (part.Position - cp).Magnitude
                    if d3 <= S.aim_maxdist and (S.fov_fullscreen or d2 <= S.aim_fov)
                        and (not S.wallcheck or visible(c, part, ch)) then
                        local score = d2
                        if S.aim_priority == "Distance" then
                            score = d3
                        elseif S.aim_priority == "Health" then
                            score = hum.Health
                        end
                        if not bestScore or score < bestScore then best, bestScore = part, score end
                    end
                end
            end
        end
    end
    return best
end

-- humanizer: estado por alvo (tempo de reacao, ponto aleatorio na hitbox) + ruido suave (Perlin) na direcao da mira
local aimUpdate
do
local hPart, hAcq, hRoll, hOff = nil, 0, 0, Vector3.zero
local hSeed = math.random() * 100

local function hRollOffset()
    local r = S.human_offset
    return Vector3.new((math.random() * 2 - 1) * r, (math.random() * 2 - 1) * r, (math.random() * 2 - 1) * r)
end

-- smooth 0% => alpha 1 (instantaneo). alpha independe de fps: 1 - s^(dt*60)
function aimUpdate(c, dt, org)
    if not aimOn() then
        hPart = nil
        return
    end
    local part = getTarget(c, org)
    if not part then
        hPart = nil
        return
    end
    local pos = part.Position
    local nx, ny, speedVar = 0, 0, 0
    if S.humanize then
        local now = os.clock()
        if part ~= hPart then
            hPart, hAcq, hRoll, hOff = part, now, now, hRollOffset()
        elseif now - hRoll > 1.5 then
            hRoll, hOff = now, hRollOffset()
        end
        if now - hAcq < S.human_delay / 1000 then return end
        pos = pos + hOff
        local amp = S.human_noise
        nx = math.noise(now * 1.3 + hSeed, 1.7, 0.3) * 2 * amp
        ny = math.noise(now * 1.1 + hSeed, 5.1, 0.9) * 2 * amp
        speedVar = math.noise(now * 0.7 + hSeed, 9.3, 2.1) * 2 * S.human_speed / 100
    else
        hPart = nil
    end
    local sm = math.clamp(S.smooth / 100, 0, 0.99)
    local a = (sm <= 0) and 1 or (1 - sm ^ (dt * 60))
    if speedVar ~= 0 then a = math.clamp(a * (1 + speedVar), 0.02, 1) end
    if S.aim_method == "Mouse" and mousemoverel then
        local sp = c:WorldToViewportPoint(pos)
        pcall(mousemoverel, (sp.X - org.X) * a + nx * 4, (sp.Y - org.Y) * a + ny * 4)
    else
        local cf = c.CFrame
        local want = CFrame.lookAt(cf.Position, pos)
        if nx ~= 0 or ny ~= 0 then want = want * CFrame.Angles(math.rad(ny), math.rad(nx), 0) end
        c.CFrame = cf:Lerp(want, a)
    end
end
end   -- fim do bloco do aimbot

----------------------------------------------------------------------------
-- triggerbot
-- deteccao: raios que atravessam o que nao bloqueia (transparente / sem colisao), com tolerancia em px
-- disparo: Executor (mouse1press/release/click), VirtualInput ou Tool:Activate, com fallback no Auto
----------------------------------------------------------------------------
do
    local VIM
    pcall(function() VIM = game:GetService("VirtualInputManager") end)

    local function heldTool()
        local ch = LP.Character
        return ch and ch:FindFirstChildOfClass("Tool")
    end

    local backends = {
        {name = "Executor",
         ok = function() return mouse1press ~= nil or mouse1click ~= nil end,
         hold = function() return mouse1press ~= nil and mouse1release ~= nil end,
         down = function()
             if mouse1press then mouse1press() else mouse1click() end
         end,
         up = function()
             if mouse1release then mouse1release() end
         end},
        {name = "VirtualInput",
         ok = function() return VIM ~= nil end,
         hold = function() return true end,
         down = function()
             local m = UIS:GetMouseLocation()
             VIM:SendMouseButtonEvent(m.X, m.Y, 0, true, game, 0)
         end,
         up = function()
             local m = UIS:GetMouseLocation()
             VIM:SendMouseButtonEvent(m.X, m.Y, 0, false, game, 0)
         end},
        {name = "Tool",
         ok = function() return heldTool() ~= nil end,
         hold = function() return true end,
         down = function() heldTool():Activate() end,
         up = function()
             local t = heldTool()
             if t then t:Deactivate() end
         end},
    }

    local holding = nil

    local function usable(b)
        return (S.fire_method == "Auto" or S.fire_method == b.name) and b.ok()
    end

    function TR.fire()
        for _, b in ipairs(backends) do
            if usable(b) and pcall(b.down) then
                task.delay(0.03, function() pcall(b.up) end)
                return b.name
            end
        end
        return nil
    end

    local function holdStart()
        for _, b in ipairs(backends) do
            if usable(b) and b.hold() and pcall(b.down) then
                holding = b
                return b.name
            end
        end
        return nil
    end

    function TR.stop()
        if holding then
            local b = holding
            holding = nil
            pcall(b.up)
        end
    end

    local trigParams = RaycastParams.new()
    trigParams.FilterType = Enum.RaycastFilterType.Exclude
    trigParams.IgnoreWater = true

    -- sobe pela hierarquia ate achar o Model que e o personagem de algum jogador
    local function playerOfPart(inst)
        local m = inst
        while m and m ~= Workspace do
            if m:IsA("Model") then
                local pl = Players:GetPlayerFromCharacter(m)
                if pl then return pl end
            end
            m = m.Parent
        end
        return nil
    end

    -- raio que atravessa partes invisiveis / sem colisao (hitbox falso, grama, zonas) e para em parede de verdade
    local function castThrough(o, d, c)
        local ignore = {c}
        if LP.Character then ignore[2] = LP.Character end
        for _ = 1, 8 do
            trigParams.FilterDescendantsInstances = ignore
            local hit = Workspace:Raycast(o, d, trigParams)
            if not hit then return nil end
            local pl = playerOfPart(hit.Instance)
            if pl then return hit, pl end
            local inst = hit.Instance
            if inst.Transparency >= 0.95 or (not inst.CanCollide and inst.Transparency >= 0.5) then
                ignore[#ignore + 1] = inst
            else
                return nil
            end
        end
        return nil
    end

    -- acerto na cabeca: a propria Head ou qualquer coisa colada nela (chapeu, cabelo)
    local function headHit(hit, ch)
        local head = ch:FindFirstChild("Head")
        if not head then return false end
        if hit.Instance == head then return true end
        return (hit.Position - head.Position).Magnitude <= head.Size.Magnitude * 0.5
    end

    local ring = {}
    for k = 0, 7 do
        local a = k * math.pi / 4
        ring[#ring + 1] = Vector2.new(math.cos(a), math.sin(a))
    end

    local function pick(c, org)
        local r = S.trigger_radius
        local count = (r > 0) and (#ring + 1) or 1
        for n = 1, count do
            local off = (n == 1) and Vector2.zero or ring[n - 1] * r
            local ray = c:ViewportPointToRay(org.X + off.X, org.Y + off.Y)
            local hit, pl = castThrough(ray.Origin, ray.Direction * S.trigger_range, c)
            if hit and pl then
                local ch = target(pl)
                if ch then
                    local want = S.trigger_part
                    if want == "Any" then return pl, hit end
                    local isHead = headHit(hit, ch)
                    if (want == "Head" and isHead) or (want == "Body" and not isHead) then return pl, hit end
                end
            end
        end
        return nil
    end

    local since, lastShot = nil, 0

    function TR.update(c, org)
        if not S.trigger then
            since = nil
            TR.stop()
            TR.state = "off"
            return
        end
        if not selfAlive() or (S.trigger_aimkey and not aimKeyActive()) then
            since = nil
            TR.stop()
            TR.state = "paused"
            return
        end
        local pl = pick(c, org)
        local now = os.clock()
        if not pl then
            since = nil
            TR.stop()
            TR.state = "no target"
            return
        end
        since = since or now
        TR.lastActive = now
        TR.state = "target: " .. pl.Name
        -- com o spinbot pausando no tiro, espera ao menos um frame para o corpo virar antes de disparar
        local wait = S.trigger_delay / 1000
        if S.spinbot and S.spin_pause then wait = math.max(wait, 0.04) end
        if now - since < wait then return end
        if S.trigger_mode == "Hold" then
            if not holding then holdStart() end
            if holding then
                TR.note = "holding via " .. holding.name
                return
            end
        end
        if now - lastShot >= S.trigger_interval / 1000 then
            lastShot = now
            local m = TR.fire()
            TR.note = m and ("fired via " .. m) or "no fire method (executor / VirtualInput / held Tool)"
        end
    end
end

----------------------------------------------------------------------------
-- chams
-- chams: Highlight AlwaysOnTop no personagem (visivel + atraves da parede)
-- chams occluded (tecnica do devforum): Highlight "line-of-sight" (Occluded) no personagem real mascara a
-- camada de oclusao; um clone sem textura, 0.99x e soldado as partes reais recebe o Highlight AlwaysOnTop,
-- entao so aparece onde a parede esconde o alvo
----------------------------------------------------------------------------
do
    local dir = Instance.new("Folder")
    dir.Name = "RagWareChams"
    dir.Parent = Workspace
    local states, clock = {}, 0

    local function clonePart(src)
        local c = src:Clone()
        if not c then return nil end
        local meshed = false
        for _, d in ipairs(c:GetChildren()) do
            if d:IsA("SpecialMesh") or d:IsA("BlockMesh") or d:IsA("CylinderMesh") then
                -- mantem a forma (cabeca R6, chapeus), tira textura e encolhe 1%
                if d:IsA("SpecialMesh") then d.TextureId = "" end
                d.Scale = d.Scale * 0.99
                meshed = true
            else
                d:Destroy()
            end
        end
        if c:IsA("MeshPart") then c.TextureID = "" end
        if not meshed then c.Size = c.Size * 0.99 end
        c.Anchored = false
        c.CanCollide = false
        c.CanQuery = false
        c.CanTouch = false
        c.Massless = true
        c.CastShadow = false
        return c
    end

    local function buildClones(p, ch, withAcc)
        local model = Instance.new("Model")
        model.Name = p.Name
        model.Parent = dir
        local function add(src)
            if src.Transparency >= 0.95 or src.Name == "HumanoidRootPart" then return end
            local ok, c = pcall(clonePart, src)
            if not (ok and c) then return end
            c.Parent = model
            local w = Instance.new("WeldConstraint")
            w.Part0 = c
            w.Part1 = src
            w.Parent = c
        end
        for _, d in ipairs(ch:GetChildren()) do
            if d:IsA("BasePart") then
                add(d)
            elseif withAcc and d:IsA("Accessory") then
                local h = d:FindFirstChild("Handle")
                if h and h:IsA("BasePart") then add(h) end
            end
        end
        return model
    end

    -- assinatura do rig: quantas partes/acessorios (mudou => refaz os clones)
    local function sig(ch)
        local n = 0
        for _, d in ipairs(ch:GetChildren()) do
            if d:IsA("BasePart") or d:IsA("Accessory") then n = n + 1 end
        end
        return n
    end

    local function destroy(p)
        local st = states[p]
        if not st then return end
        states[p] = nil
        if st.los then st.los:Destroy() end
        if st.model then st.model:Destroy() end
    end
    CH.drop = destroy

    local function apply(p, mode)
        local ch = p.Character
        local st = states[p]
        if st and (st.char ~= ch or st.mode ~= mode or not st.los.Parent
            or (mode == "occ" and (st.acc ~= S.chams_acc or st.n ~= sig(ch) or not st.model.Parent))) then
            destroy(p)
            st = nil
        end
        if not st then
            st = {char = ch, mode = mode, acc = S.chams_acc, n = sig(ch)}
            st.los = new("Highlight", {Name = "RagWareLOS", Adornee = ch}, ch)
            if mode == "occ" then
                st.model = buildClones(p, ch, S.chams_acc)
                st.occ = new("Highlight", {Name = "RagWareOCC", Adornee = st.model,
                    DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}, st.model)
            end
            states[p] = st
        end

        local team = sameTeam(p)
        local visFill = team and col(S.esp_team_color) or col(S.chams_fill_c)
        local occFill = team and col(S.esp_team_color) or col(S.occ_fill_c)
        local los = st.los
        if mode == "simple" then
            los.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            los.FillColor = visFill
            los.OutlineColor = col(S.chams_line_c)
            los.FillTransparency = S.chams_fill
            los.OutlineTransparency = S.chams_line
        else
            -- a camada line-of-sight tem que continuar "renderizando" (0.999) para mascarar a de oclusao
            los.DepthMode = Enum.HighlightDepthMode.Occluded
            if S.chams then
                los.FillColor = visFill
                los.OutlineColor = col(S.chams_line_c)
                los.FillTransparency = math.min(S.chams_fill, 0.999)
                los.OutlineTransparency = S.chams_line
            else
                los.FillTransparency = 0.999
                los.OutlineTransparency = 1
            end
            local o = st.occ
            o.FillColor = occFill
            o.OutlineColor = col(S.occ_line_c)
            o.FillTransparency = S.occ_fill
            o.OutlineTransparency = S.occ_line
            o.Enabled = true
        end
        los.Enabled = true
    end

    function CH.update(dt, c, eye)
        clock = clock + dt
        if clock < 0.2 then return end
        clock = 0
        local mode = S.chams_occ and "occ" or "simple"
        local list = {}
        if S.chams or S.chams_occ then
            local cp = eye or c.CFrame.Position
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then
                    local ch = p.Character
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local root = ch and ch:FindFirstChild("HumanoidRootPart")
                    if hum and root and hum.Health > 0 and (S.esp_team or not sameTeam(p)) then
                        list[#list + 1] = {p = p, d = (root.Position - cp).Magnitude}
                    end
                end
            end
            table.sort(list, function(a, b) return a.d < b.d end)
        end
        -- o Roblox so desenha 31 Highlights: modo occluded gasta 2 por jogador, entao prioriza os mais proximos
        local limit = math.min(S.chams_max, mode == "occ" and 15 or 31)
        local keep = {}
        for i = 1, math.min(#list, limit) do keep[list[i].p] = true end
        for p in pairs(states) do
            if not keep[p] then destroy(p) end
        end
        for p in pairs(keep) do apply(p, mode) end
    end

    function CH.clear()
        for p in pairs(states) do destroy(p) end
        dir:Destroy()
    end
end

----------------------------------------------------------------------------
-- esp (geometria real das partes)
----------------------------------------------------------------------------
local fovCircle = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
    BorderSizePixel = 0, Visible = false}, overlay)
new("UICorner", {CornerRadius = UDim.new(1, 0)}, fovCircle)
local fovStroke = new("UIStroke", {Thickness = 1.5}, fovCircle)

local espUpdate, espDrop, espClear
do
local R15 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local R6 = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

local pool = {}

local function newObj()
    local o = {shown = false, bodyShown = false}
    o.box = new("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false}, overlay)
    o.boxStroke = new("UIStroke", {Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Miter}, o.box)
    local function lbl(anchor)
        return new("TextLabel", {BackgroundTransparency = 1, AnchorPoint = anchor, Size = UDim2.fromOffset(240, 16),
            Font = Enum.Font.GothamMedium, TextSize = 13, TextStrokeTransparency = 0.2, Visible = false}, overlay)
    end
    o.name = lbl(Vector2.new(0.5, 1))
    o.dist = lbl(Vector2.new(0.5, 0))
    o.hpBack = new("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4,
        BorderSizePixel = 0, Visible = false}, overlay)
    o.hp = new("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1),
        BorderSizePixel = 0}, o.hpBack)
    o.head = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0,
        Visible = false}, overlay)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, o.head)
    o.headStroke = new("UIStroke", {Thickness = 1.5}, o.head)
    o.tracer = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false}, overlay)
    o.lines = {}
    for i = 1, 14 do
        o.lines[i] = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false}, overlay)
    end
    return o
end

-- esconde tudo menos o tracer (que pode continuar valido mesmo com o alvo fora da tela)
local function hideBody(o)
    if not o.bodyShown then return end
    o.bodyShown = false
    o.box.Visible = false
    o.name.Visible = false
    o.dist.Visible = false
    o.hpBack.Visible = false
    o.head.Visible = false
    for _, l in ipairs(o.lines) do l.Visible = false end
end

local function hideObj(o)
    hideBody(o)
    o.tracer.Visible = false
    o.shown = false
end

local function destroyObj(o)
    o.box:Destroy()
    o.name:Destroy()
    o.dist:Destroy()
    o.hpBack:Destroy()
    o.head:Destroy()
    o.tracer:Destroy()
    for _, l in ipairs(o.lines) do l:Destroy() end
end

-- de onde o tracer sai na tela
local function tracerFrom(vp)
    local m = S.tracer_from
    if m == "Mouse" and not isMobile then return UIS:GetMouseLocation() end
    if m == "Center" then return Vector2.new(vp.X / 2, vp.Y / 2) end
    if m == "Top" then return Vector2.new(vp.X / 2, 0) end
    return Vector2.new(vp.X / 2, vp.Y)
end

local function drawPlayer(o, p, ch, hum, root, c, vp, dist, team)
    local color = team and col(S.esp_team_color) or col(S.esp_color)

    -- caixa orientada: extremos de cada parte no espaco local do root (tamanho + CFrame reais)
    local cf = root.CFrame
    local mn = Vector3.new(math.huge, math.huge, math.huge)
    local mx = Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, part in ipairs(ch:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:ToObjectSpace(part.CFrame):GetComponents()
            local h = part.Size * 0.5
            local ex = math.abs(r00) * h.X + math.abs(r01) * h.Y + math.abs(r02) * h.Z
            local ey = math.abs(r10) * h.X + math.abs(r11) * h.Y + math.abs(r12) * h.Z
            local ez = math.abs(r20) * h.X + math.abs(r21) * h.Y + math.abs(r22) * h.Z
            mn = mn:Min(Vector3.new(x - ex, y - ey, z - ez))
            mx = mx:Max(Vector3.new(x + ex, y + ey, z + ez))
        end
    end
    if mn.X == math.huge then
        if o.shown then hideObj(o) end
        return
    end

    -- tracer: da origem escolhida ate o alvo (pes = base da caixa orientada pelas partes reais, ou root / cabeca)
    if S.esp_tracer then
        local to
        local th = ch:FindFirstChild("Head")
        if S.tracer_to == "Root" then
            to = root.Position
        elseif S.tracer_to == "Head" and th then
            to = th.Position
        else
            to = cf:PointToWorldSpace(Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2))
        end
        local tsp = c:WorldToViewportPoint(to)
        local px, py = tsp.X, tsp.Y
        if tsp.Z < 0 then px, py = vp.X - px, vp.Y - py end   -- atras da camera: espelha para apontar para o lado certo
        local from = tracerFrom(vp)
        local td = Vector2.new(px, py) - from
        o.tracer.Size = UDim2.fromOffset(td.Magnitude, S.esp_thick)
        o.tracer.Position = UDim2.fromOffset((px + from.X) / 2, (py + from.Y) / 2)
        o.tracer.Rotation = math.deg(math.atan2(td.Y, td.X))
        o.tracer.BackgroundColor3 = color
        o.tracer.Visible = true
        o.shown = true
    elseif o.tracer.Visible then
        o.tracer.Visible = false
    end

    local x0, y0, x1, y1, front = math.huge, math.huge, -math.huge, -math.huge, 0
    for ix = 0, 1 do
        for iy = 0, 1 do
            for iz = 0, 1 do
                local lp = Vector3.new(ix == 0 and mn.X or mx.X, iy == 0 and mn.Y or mx.Y, iz == 0 and mn.Z or mx.Z)
                local sp = c:WorldToViewportPoint(cf:PointToWorldSpace(lp))
                if sp.Z > 0 then
                    front = front + 1
                    if sp.X < x0 then x0 = sp.X end
                    if sp.X > x1 then x1 = sp.X end
                    if sp.Y < y0 then y0 = sp.Y end
                    if sp.Y > y1 then y1 = sp.Y end
                end
            end
        end
    end
    if front < 8 or x1 < 0 or x0 > vp.X or y1 < 0 or y0 > vp.Y or (x1 - x0) < 2 then
        hideBody(o)
        o.shown = S.esp_tracer and true or false
        return
    end

    o.shown = true
    o.bodyShown = true
    local w, h, th = x1 - x0, y1 - y0, S.esp_thick

    if S.esp_box then
        o.box.Position = UDim2.fromOffset(x0, y0)
        o.box.Size = UDim2.fromOffset(w, h)
        o.boxStroke.Color = color
        o.boxStroke.Thickness = th
        o.box.Visible = true
    else
        o.box.Visible = false
    end

    if S.esp_name then
        o.name.Text = (S.esp_namemode == "Display") and p.DisplayName or p.Name
        o.name.TextColor3 = color
        o.name.TextSize = S.esp_text
        o.name.Position = UDim2.fromOffset(x0 + w / 2, y0 - 2)
        o.name.Visible = true
    else
        o.name.Visible = false
    end

    if S.esp_dist then
        o.dist.Text = (S.esp_unit == "Meters") and string.format("%.0f m", dist * 0.28)
            or string.format("%.0f st", dist)
        o.dist.TextColor3 = color
        o.dist.TextSize = S.esp_text
        o.dist.Position = UDim2.fromOffset(x0 + w / 2, y1 + 2)
        o.dist.Visible = true
    else
        o.dist.Visible = false
    end

    if S.esp_health then
        local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        o.hpBack.Position = UDim2.fromOffset(x0 - 7, y0 - 1)
        o.hpBack.Size = UDim2.fromOffset(4, h + 2)
        o.hp.Size = UDim2.new(1, -2, ratio, 0)
        o.hp.BackgroundColor3 = Color3.fromHSV(ratio * 0.33, 0.85, 1)
        o.hpBack.Visible = true
    else
        o.hpBack.Visible = false
    end

    local head = ch:FindFirstChild("Head")
    o.head.Visible = false
    if S.esp_head and head then
        local hp = c:WorldToViewportPoint(head.Position)
        if hp.Z > 0 then
            local rp = c:WorldToViewportPoint(head.Position + c.CFrame.RightVector * (head.Size.Y * 0.5))
            local r = (Vector2.new(rp.X, rp.Y) - Vector2.new(hp.X, hp.Y)).Magnitude
            o.head.Position = UDim2.fromOffset(hp.X, hp.Y)
            o.head.Size = UDim2.fromOffset(r * 2, r * 2)
            o.headStroke.Color = color
            o.headStroke.Thickness = th
            o.head.Visible = true
        end
    end

    if S.esp_skel then
        local map = (hum.RigType == Enum.HumanoidRigType.R15) and R15 or R6
        local cache = {}
        local function proj(n)
            local v = cache[n]
            if v == nil then
                local part = ch:FindFirstChild(n)
                v = false
                if part then
                    local sp = c:WorldToViewportPoint(part.Position)
                    if sp.Z > 0 then v = Vector2.new(sp.X, sp.Y) end
                end
                cache[n] = v
            end
            return v
        end
        for i, l in ipairs(o.lines) do
            local pair = map[i]
            local a = pair and proj(pair[1])
            local b = pair and proj(pair[2])
            if a and b then
                local d = b - a
                l.Size = UDim2.fromOffset(d.Magnitude, th)
                l.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
                l.Rotation = math.deg(math.atan2(d.Y, d.X))
                l.BackgroundColor3 = color
                l.Visible = true
            else
                l.Visible = false
            end
        end
    else
        for _, l in ipairs(o.lines) do l.Visible = false end
    end
end

function espUpdate(c, eye)
    local any = S.esp_box or S.esp_skel or S.esp_name or S.esp_head or S.esp_health or S.esp_dist or S.esp_tracer
    local vp, cp = c.ViewportSize, eye or c.CFrame.Position
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local o = pool[p]
            if not o then
                o = newObj()
                pool[p] = o
            end
            local ch = p.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local root = ch and ch:FindFirstChild("HumanoidRootPart")
            local team = sameTeam(p)
            local dist = root and (root.Position - cp).Magnitude or 0
            if any and hum and root and hum.Health > 0 and dist <= S.esp_maxdist and (S.esp_team or not team) then
                drawPlayer(o, p, ch, hum, root, c, vp, dist, team)
            elseif o.shown then
                hideObj(o)
            end
        end
    end
end

function espDrop(p)
    local o = pool[p]
    if o then
        destroyObj(o)
        pool[p] = nil
    end
end

function espClear()
    for p, o in pairs(pool) do pcall(destroyObj, o) end
end
end   -- fim do bloco do esp

----------------------------------------------------------------------------
-- player logic
----------------------------------------------------------------------------
local playerStep
do
local base, spinAng, spun, flyVel = {}, 0, false, nil
local jitClock, jitSign, spinVel = 0, 1, nil

function playerStep(dt)
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    local cam = Workspace.CurrentCamera
    local function on(k) return S[k] and not unloading end

    if on("grav_on") then
        if not base.grav then base.grav = Workspace.Gravity end
        Workspace.Gravity = S.grav
    elseif base.grav then
        Workspace.Gravity = base.grav
        base.grav = nil
    end

    if not (hum and root) then return end
    local alive = hum.Health > 0

    -- spinbot. Spin = giro continuo; Jitter = alterna +-angulo em relacao a mira; Random = yaw aleatorio;
    -- Backwards = de costas para onde a camera olha. "Velocity" usa BodyAngularVelocity (so no modo Spin)
    local spinOn = on("spinbot") and alive
    local paused = spinOn and S.spin_pause and shooting()
    if spinOn and not paused then
        if hum.AutoRotate then
            hum.AutoRotate = false
            spun = true
        end
        local mode = S.spin_mode
        local dirSign = S.spin_reverse and -1 or 1
        local yaw
        if mode == "Spin" then
            spinAng = (spinAng + math.rad(S.spin_speed) * dt * dirSign) % (math.pi * 2)
            yaw = spinAng
        elseif mode == "Random" then
            yaw = math.random() * math.pi * 2
        else
            local look = (cam or root).CFrame.LookVector
            local baseYaw = math.atan2(-look.X, -look.Z)
            if mode == "Backwards" then
                yaw = baseYaw + math.pi
            else
                jitClock = jitClock + dt
                if jitClock >= 1 / math.max(S.spin_rate, 1) then
                    jitClock = 0
                    jitSign = -jitSign
                end
                yaw = baseYaw + math.rad(S.spin_jitter) * jitSign
            end
        end
        if mode == "Spin" and S.spin_method == "Velocity" then
            if not spinVel or spinVel.Parent ~= root then
                if spinVel then spinVel:Destroy() end
                spinVel = Instance.new("BodyAngularVelocity")
                spinVel.Name = "RagWareSpin"
                spinVel.MaxTorque = Vector3.new(0, 1e9, 0)
                spinVel.P = 1e5
                spinVel.Parent = root
            end
            spinVel.AngularVelocity = Vector3.new(0, math.rad(S.spin_speed) * dirSign, 0)
        else
            if spinVel then
                spinVel:Destroy()
                spinVel = nil
            end
            root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
        end
    else
        if spun then
            hum.AutoRotate = true
            spun = false
        end
        if spinVel then
            spinVel:Destroy()
            spinVel = nil
        end
        if paused and S.spin_face and cam then
            -- atirando: o corpo volta a olhar para onde a camera mira, assim o tiro sai reto
            local look = cam.CFrame.LookVector
            root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
        end
    end

    -- bunny hop: pula sozinho ao tocar o chao enquanto a condicao do modo valer; "Air speed" mantem a velocidade no ar
    if on("bhop_on") and alive then
        local md = hum.MoveDirection
        local moving = md.Magnitude > 0.1
        local want = S.bhop_mode == "Always" or (S.bhop_mode == "Moving" and moving)
            or (S.bhop_mode == "Hold" and UIS:IsKeyDown(Enum.KeyCode.Space))
        if want then
            if hum.FloorMaterial ~= Enum.Material.Air then
                hum.Jump = true
            elseif S.bhop_boost and moving then
                local v = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(md.X * S.bhop_speed, v.Y, md.Z * S.bhop_speed)
            end
        end
    end

    if on("walk_on") then
        if not base.walk then base.walk = hum.WalkSpeed end
        hum.WalkSpeed = S.walk
    elseif base.walk then
        hum.WalkSpeed = base.walk
        base.walk = nil
    end

    if on("jump_on") then
        if not base.jump then base.jump = {hum.UseJumpPower, hum.JumpPower} end
        hum.UseJumpPower = true
        hum.JumpPower = S.jump
    elseif base.jump then
        hum.UseJumpPower = base.jump[1]
        hum.JumpPower = base.jump[2]
        base.jump = nil
    end

    -- fly: BodyVelocity segura o personagem no ar; direcao = stick/WASD relativo a camera (com pitch)
    if on("fly") and alive and cam then
        if not flyVel or flyVel.Parent ~= root then
            if flyVel then flyVel:Destroy() end
            flyVel = Instance.new("BodyVelocity")
            flyVel.Name = "RagWareFly"
            flyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            flyVel.Parent = root
        end
        local cf = cam.CFrame
        local md = hum.MoveDirection
        local v = Vector3.zero
        if md.Magnitude > 0 then
            local fl = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
            local fr = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
            local f = fl.Magnitude > 0 and md:Dot(fl.Unit) or 0
            local r = fr.Magnitude > 0 and md:Dot(fr.Unit) or 0
            v = cf.LookVector * f + cf.RightVector * r
        end
        if UIS:IsKeyDown(Enum.KeyCode.Space) or hum.Jump then v = v + Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
            v = v - Vector3.yAxis
        end
        flyVel.Velocity = v * S.fly_speed
    elseif flyVel then
        flyVel:Destroy()
        flyVel = nil
    end
end

end   -- fim do bloco do player

local function noclipStep()
    if not S.noclip or unloading then return end
    local ch = LP.Character
    if not ch then return end
    for _, d in ipairs(ch:GetDescendants()) do
        if d:IsA("BasePart") and d.CanCollide then d.CanCollide = false end
    end
end

----------------------------------------------------------------------------
-- loop principal (depois do script de camera, para o ESP ler a camera final)
----------------------------------------------------------------------------
-- third person: roda depois do script de camera do jogo e empurra a camera para tras ao longo dos eixos dela.
-- Como o deslocamento e feito sobre o CFrame final, funciona com camera padrao e com camera propria do jogo.
-- A mira nao perde alinhamento: o alvo continua na mesma linha que passa pelo crosshair.
local tpParams = RaycastParams.new()
tpParams.FilterType = Enum.RaycastFilterType.Exclude
tpParams.IgnoreWater = true
pcall(function() tpParams.RespectCanCollide = true end)

local function thirdPerson(c)
    if not S.tp_on then return end
    local ch = LP.Character
    if not ch then return end
    local cf = c.CFrame
    local pos = (cf * CFrame.new(S.tp_side, S.tp_height, S.tp_dist)).Position
    if S.tp_collide then
        local ign = {c}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then ign[#ign + 1] = p.Character end
        end
        tpParams.FilterDescendantsInstances = ign
        local from = cf.Position
        local dir = pos - from
        local hit = Workspace:Raycast(from, dir, tpParams)
        if hit then pos = from + dir.Unit * math.max(hit.Distance - 0.5, 0) end
    end
    c.CFrame = CFrame.new(pos) * cf.Rotation
    if S.tp_body then
        for _, d in ipairs(ch:GetDescendants()) do
            if d:IsA("BasePart") then d.LocalTransparencyModifier = 0 end
        end
    end
end

local statusClock = 0

local function renderStep(dt)
    local c = Workspace.CurrentCamera
    if unloading or not c then return end
    local org = origin(c)
    local eye = c.CFrame.Position   -- posicao real do olho (antes do third person), usada nas distancias
    local ch = LP.Character
    rayParams.FilterDescendantsInstances = ch and {ch, c} or {c}

    if selfAlive() then aimUpdate(c, dt, org) end
    TR.update(c, org)
    thirdPerson(c)

    local showFov = S.aimbot and S.show_fov and not S.fov_fullscreen
    fovCircle.Visible = showFov and true or false
    if showFov then
        fovCircle.Position = UDim2.fromOffset(org.X, org.Y)
        fovCircle.Size = UDim2.fromOffset(S.aim_fov * 2, S.aim_fov * 2)
        fovStroke.Color = col(S.fov_color)
        fovStroke.Thickness = S.fov_thick
    end

    local touchAim = S.aimbot and S.aim_button and S.aim_mode ~= "Always" and UIS.TouchEnabled
    aimBtn.Visible = touchAim and true or false
    if touchAim then
        local active = aimOn()
        aimBtn.Position = UDim2.fromScale(S.aim_btn_x / 100, S.aim_btn_y / 100)
        aimBtn.Size = UDim2.fromOffset(S.aim_btn_size, S.aim_btn_size)
        aimBtn.BackgroundColor3 = active and accent() or T.card
        aimBtn.TextColor3 = active and T.bg or T.text
    end

    espUpdate(c, eye)
    CH.update(dt, c, eye)

    statusClock = statusClock + dt
    if statusClock > 0.15 then
        statusClock = 0
        local s = TR.state .. (TR.note ~= "" and ("  |  " .. TR.note) or "")
        if trigStatus.Text ~= s then trigStatus.Text = s end
    end
end

-- FOV changer: aplicado no ULTIMO passo do render, depois de qualquer script de camera do jogo. So escreve quando o valor
-- difere e devolve o FOV original ao desligar. (Antes era no Heartbeat e brigava com o jogo, a camera tremia.)
local fovBase
local function fovStep()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    if S.camfov_on and not unloading then
        if not fovBase then fovBase = cam.FieldOfView end
        if math.abs(cam.FieldOfView - S.camfov) > 0.01 then cam.FieldOfView = S.camfov end
    elseif fovBase then
        cam.FieldOfView = fovBase
        fovBase = nil
    end
end

RunService:BindToRenderStep("RagWareRender", Enum.RenderPriority.Camera.Value + 1, safe("render", renderStep))
RunService:BindToRenderStep("RagWareFov", Enum.RenderPriority.Last.Value, safe("fov", fovStep))
conn(RunService.Heartbeat:Connect(safe("player", playerStep)))
conn(RunService.Stepped:Connect(safe("noclip", noclipStep)))

----------------------------------------------------------------------------
-- input / eventos
----------------------------------------------------------------------------
conn(UIS.InputBegan:Connect(function(i)
    if UIS:GetFocusedTextBox() then return end
    if matches(i, S.ui_key) then win.Visible = not win.Visible end
    if matches(i, S.tp_key) then
        S.tp_on = not S.tp_on
        refreshAll()
    end
    if matches(i, S.aim_key) then
        if S.aim_mode == "Toggle" then aimToggled = not aimToggled else aimHeld = true end
    end
    if i.UserInputType == Enum.UserInputType.MouseButton1 and not overMenu(i.Position) then fireHeld = true end
end))
conn(UIS.InputEnded:Connect(function(i)
    if matches(i, S.aim_key) then aimHeld = false end
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        if fireHeld then lastShotInput = os.clock() end
        fireHeld = false
    end
end))

conn(UIS.JumpRequest:Connect(function()
    if not S.infjump or unloading then return end
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end))

conn(LP.Idled:Connect(function()
    if not S.antiafk or unloading then return end
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
end))

conn(Players.PlayerRemoving:Connect(function(p)
    espDrop(p)
    CH.drop(p)
    downCache[p] = nil
end))

if Workspace.CurrentCamera then
    conn(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout))
end

----------------------------------------------------------------------------
-- unload
----------------------------------------------------------------------------
local function unload()
    unloading = true
    pcall(playerStep, 0)
    pcall(fovStep)
    pcall(TR.stop)
    pcall(function() RunService:UnbindFromRenderStep("RagWareRender") end)
    pcall(function() RunService:UnbindFromRenderStep("RagWareFov") end)
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    pcall(CH.clear)
    pcall(espClear)
    pcall(function() gui:Destroy() end)
    pcall(function() overlay:Destroy() end)
    ENV.__RAGWARE_UNLOAD = nil
end
ENV.__RAGWARE_UNLOAD = unload

----------------------------------------------------------------------------
-- start
----------------------------------------------------------------------------
refreshList()
selectTab("Combat")
applyTheme()
layout()
status(hasFS and "ready" or "no writefile: configs live only in this session")
