if not game:IsLoaded() then game.Loaded:Wait() end

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")
local Workspace    = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Teams        = game:GetService("Teams")

local LP       = Players.LocalPlayer
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled

local ENV = (getgenv and getgenv()) or _G
if ENV.__RAGWARE_UNLOAD then pcall(ENV.__RAGWARE_UNLOAD) end

----------------------------------------------------------------------------
-- loading screen
-- Fully black screen: "RagWare is loading", what is loading, the logo image, and a blue bar that fills over 4 seconds.
-- The script itself loads far faster than that, so the stage names (marked while the script loads) are stepped
-- through on the 4 second timer. The timer starts at the first frame that is drawn.
----------------------------------------------------------------------------
local Loader = {stages = {}}
do
    local DURATION = 4
    local BLUE = Color3.fromRGB(20, 168, 255)
    local IMAGE = "rbxassetid://82493817152039"

    local parent
    do
        local ok, h = pcall(function() return gethui and gethui() end)
        parent = (ok and h) or LP:WaitForChild("PlayerGui")
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "RagWareLoading"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 100000   -- above everything, including the menu
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = parent

    local bg = Instance.new("Frame")
    bg.Name = "Black"
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.new(0, 0, 0)
    bg.BorderSizePixel = 0
    bg.Active = true   -- swallows clicks, so nothing behind the screen is touched while loading
    bg.Parent = sg

    local function makeText(font, color)
        local l = Instance.new("TextLabel")
        l.AnchorPoint = Vector2.new(0.5, 0.5)
        l.BackgroundTransparency = 1
        l.BorderSizePixel = 0
        l.Font = font
        l.TextColor3 = color
        l.RichText = true
        l.Parent = bg
        return l
    end

    local title = makeText(Enum.Font.GothamBold, Color3.fromRGB(255, 255, 255))
    title.Text = 'Rag<font color="rgb(20,168,255)">Ware</font> is loading'
    local status = makeText(Enum.Font.Gotham, Color3.fromRGB(150, 150, 150))
    status.Text = "Starting..."

    local image = Instance.new("ImageLabel")
    image.Name = "Logo"
    image.AnchorPoint = Vector2.new(0.5, 0.5)
    image.Position = UDim2.fromScale(0.5, 0.5)
    image.BackgroundTransparency = 1
    image.BorderSizePixel = 0
    image.Image = IMAGE
    image.ScaleType = Enum.ScaleType.Fit
    image.Parent = bg

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.AnchorPoint = Vector2.new(0.5, 0.5)
    track.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    track.BorderSizePixel = 0
    track.Parent = bg
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = BLUE
    fill.BorderSizePixel = 0
    fill.Parent = track
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    -- sizes follow the screen: the image is a little big (about a third of the smaller side), text and bar around it
    local function layout()
        local vp = sg.AbsoluteSize
        if vp.X <= 0 or vp.Y <= 0 then
            local cam = Workspace.CurrentCamera
            vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        end
        local m = math.min(vp.X, vp.Y)
        local img = math.clamp(math.floor(m * 0.36), 150, 300)
        image.Size = UDim2.fromOffset(img, img)
        title.TextSize = math.clamp(math.floor(m * 0.045), 20, 32)
        status.TextSize = math.clamp(math.floor(m * 0.026), 13, 18)
        local tH, sH = title.TextSize + 8, status.TextSize + 6
        title.Size = UDim2.fromOffset(vp.X, tH)
        status.Size = UDim2.fromOffset(vp.X, sH)
        status.Position = UDim2.new(0.5, 0, 0.5, -(img / 2 + 12 + sH / 2))
        title.Position = UDim2.new(0.5, 0, 0.5, -(img / 2 + 12 + sH + 8 + tH / 2))
        track.Size = UDim2.fromOffset(math.clamp(math.floor(img * 1.3), 200, 380), 6)
        track.Position = UDim2.new(0.5, 0, 0.5, img / 2 + 28)
    end
    layout()
    sg:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

    local beat
    function Loader.destroy()
        if beat then
            beat:Disconnect()
            beat = nil
        end
        pcall(function() sg:Destroy() end)
    end

    -- called while the script loads: the name of what is being loaded right now
    function Loader.mark(name)
        Loader.stages[#Loader.stages + 1] = name
    end

    local t0, fading, shown = nil, false, nil
    beat = RunService.Heartbeat:Connect(function()
        if fading then return end
        t0 = t0 or os.clock()
        local p = math.clamp((os.clock() - t0) / DURATION, 0, 1)
        fill.Size = UDim2.fromScale(p, 1)
        local n = #Loader.stages
        if n > 0 then
            local txt = Loader.stages[math.min(math.floor(p * n) + 1, n)] .. "..."
            if txt ~= shown then
                shown = txt
                status.Text = txt
            end
        end
        if p >= 1 then
            fading = true
            status.Text = "Ready"
            task.delay(0.25, function()
                bg.Active = false
                local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                for _, tw in ipairs({
                    TweenService:Create(bg, info, {BackgroundTransparency = 1}),
                    TweenService:Create(image, info, {ImageTransparency = 1}),
                    TweenService:Create(title, info, {TextTransparency = 1}),
                    TweenService:Create(status, info, {TextTransparency = 1}),
                    TweenService:Create(track, info, {BackgroundTransparency = 1}),
                    TweenService:Create(fill, info, {BackgroundTransparency = 1}),
                }) do tw:Play() end
                task.delay(0.6, Loader.destroy)
            end)
        end
    end)
end

----------------------------------------------------------------------------
-- settings
-- DEFAULTS       = what the features do (saved in configs)
-- THEME_DEFAULTS = how everything looks and where it sits (saved in themes)
----------------------------------------------------------------------------
local DEFAULTS = {
    -- aimbot (its filters are the aim_chk_* keys, generated below)
    aimbot = false, aim_mode = "Hold", aim_key = "MouseButton2", aim_method = "Camera",
    aim_part = "Head", aim_priority = "Crosshair", aim_maxdist = 1500, smooth = 20,
    -- humanizer (human-like imperfections in the aim)
    humanize = false, human_noise = 0.8, human_offset = 0.3, human_delay = 120, human_speed = 25,
    -- fov
    aim_fov = 120, show_fov = true, fov_fullscreen = false, fov_origin = "Mouse",
    fov_color = {232, 238, 250}, fov_thick = 1.5,
    -- touch AIM button on/off (its look and position live in the theme)
    aim_button = true,
    -- triggerbot (its filters are the trig_chk_* keys, generated below)
    trigger = false, trigger_part = "Any", trigger_mode = "Click", fire_method = "Auto",
    trigger_delay = 40, trigger_interval = 90, trigger_range = 1000, trigger_radius = 3,
    trigger_aimkey = false,
    -- screen tap (touch devices): where it lands is set with the tap marker (theme); how it is sent is set here
    tap_method = "Auto", tap_hold = 40, tap_jitter = 0,
    -- spinbot (spin_pause: stops spinning while you shoot, so the shot goes straight)
    spinbot = false, spin_mode = "Spin", spin_method = "CFrame", spin_speed = 720, spin_reverse = false,
    spin_jitter = 90, spin_rate = 20, spin_pause = true, spin_resume = 180, spin_face = true,
    -- third person (camera pushed back, works even in games with their own camera)
    tp_on = false, tp_dist = 12, tp_height = 1.5, tp_side = 0, tp_collide = true, tp_body = true, tp_key = "None",
    -- chams: normal chams and occluded chams are two separate features
    chams = false, chams_depth = "Always on top", chams_team = true,
    chams_fill_c = {255, 90, 90}, chams_fill = 0.5, chams_line_c = {255, 255, 255}, chams_line = 0,
    occ_on = false, occ_team = true, occ_acc = false,
    occ_vis_fill_c = {255, 90, 90}, occ_vis_fill = 0.5, occ_vis_line_c = {255, 255, 255}, occ_vis_line = 0,
    occ_fill_c = {90, 170, 255}, occ_fill = 0.25, occ_line_c = {255, 255, 255}, occ_line = 0.2,
    chams_max = 15,
    -- esp
    esp_box = false, esp_skel = false, esp_name = false, esp_head = false, esp_health = false, esp_dist = false,
    esp_tracer = false, tracer_from = "Bottom", tracer_to = "Feet", esp_team = false,
    esp_namemode = "Display", esp_unit = "Studs", esp_maxdist = 2000, esp_thick = 1.5, esp_text = 13,
    -- esp health bar
    hp_side = "Left", hp_width = 4, hp_len = 100, hp_gap = 3, hp_pad = 1, hp_corner = 0, hp_segments = 0,
    hp_color_mode = "Gradient", hp_low = {255, 60, 60}, hp_high = {80, 255, 120}, hp_solid = {80, 255, 120},
    hp_back_c = {0, 0, 0}, hp_back_trans = 0.4, hp_outline = false, hp_outline_c = {0, 0, 0},
    hp_text = false, hp_text_mode = "Health", hp_text_size = 11, hp_text_follow = true, hp_text_fill = true,
    hp_text_c = {255, 255, 255}, hp_show_below = 100, hp_smooth = 0,
    -- esp: look of each element. "Player color" = the team color (or the target color); thickness 0 = ESP style thickness
    box_style = "Full", box_corner = 25, box_color_mode = "Player color", box_color = {255, 255, 255}, box_thick = 0,
    box_trans = 0, box_outline = false, box_fill = false, box_fill_player = true, box_fill_c = {255, 255, 255},
    box_fill_trans = 0.8,
    skel_color_mode = "Player color", skel_color = {255, 255, 255}, skel_thick = 0, skel_trans = 0, skel_joints = false,
    skel_joint_size = 4,
    name_color_mode = "Player color", name_color = {255, 255, 255}, name_size = 0, name_font = "GothamMedium",
    name_stroke = 0.2, name_offset = 2, name_team = false,
    dist_color_mode = "Player color", dist_color = {255, 255, 255}, dist_size = 0, dist_font = "GothamMedium",
    dist_stroke = 0.2, dist_offset = 2, dist_decimals = 0, dist_brackets = false,
    head_scale = 100, head_color_mode = "Player color", head_color = {255, 255, 255}, head_thick = 0, head_trans = 0,
    head_fill = false, head_fill_player = true, head_fill_c = {255, 255, 255}, head_fill_trans = 0.7,
    tracer_color_mode = "Player color", tracer_color = {255, 255, 255}, tracer_thick = 0, tracer_trans = 0,
    -- team colors (used by esp and chams)
    team_mode = "Team colors", team_colors = {}, col_ally = {90, 170, 255}, col_enemy = {255, 90, 90},
    col_noteam = {200, 200, 200}, esp_target_color = {255, 214, 10},
    -- player
    walk_on = false, walk = 32, jump_on = false, jump = 90, infjump = false, noclip = false,
    fly = false, fly_speed = 60, camfov_on = false, camfov = 90, grav_on = false, grav = 100, antiafk = false,
    bhop_on = false, bhop_mode = isMobile and "Moving" or "Hold", bhop_boost = false, bhop_speed = 28,
    -- player lists: ignored players are never a target; target_mode = Off / Only / Priority
    ignore_on = true, ignore_esp = false, target_mode = "Off", ignore_list = {}, target_list = {},
    -- same thing for whole teams (by team name). team_ignore_mine = false lets you aim at your own team
    ignore_teams_on = true, ignore_teams_esp = false, ignore_teams = {}, target_teams = {}, team_ignore_mine = true,
    -- teleport
    tele_offset = "Behind", tele_dist = 4,
    -- mobile quick buttons (which ones are shown; their look is in the theme) and the menu key
    qb_on = isMobile, qb_trig = true, qb_spin = true, qb_tp = true, qb_bhop = true,
    ui_key = "RightShift",
}

local THEME_DEFAULTS = {
    -- colors
    ui_accent = {20, 168, 255}, ui_bg = {7, 7, 7}, ui_side = {11, 11, 11}, ui_card = {16, 16, 16},
    ui_sub = {12, 12, 12}, ui_item = {27, 27, 27}, ui_line = {40, 40, 40}, ui_off = {55, 55, 55},
    ui_text = {232, 232, 232}, ui_dim = {128, 128, 128},
    -- window
    ui_trans = 0.04, ui_scale = 1, ui_corner = 10, ui_font = "GothamMedium", ui_stroke = 1, ui_stroke_trans = 0.55,
    ui_topline = true, ui_gradient = true, ui_desc = false, ui_sidew = 150,
    -- cards (the titled blocks) and the settings panels that open under a feature
    card_trans = 0.03, card_corner = 8, card_stroke = 1, card_stroke_trans = 0, card_stroke_accent = false,
    card_header = "Plain", card_title_size = 12, card_divider = true, card_pad = 12, card_gap = 10,
    card_collapse = true, card_collapsed = {}, sub_trans = 0,
    -- controls (buttons, dropdowns, inputs, keybinds), switches and sliders
    ctl_corner = 5, ctl_stroke = 1, ctl_stroke_trans = 0, ctl_stroke_accent = false, ctl_trans = 0, ctl_text = 12,
    sw_shape = "Pill", sw_w = 32, sw_h = 16, sw_knob = 12, sw_accent = true, sw_on = {20, 168, 255},
    sw_knob_c = {232, 232, 232},
    sl_shape = "Circle", sl_h = 4, sl_knob = 12, sl_accent = true, sl_fill = {20, 168, 255},
    win_w = 760, win_h = 470, win_cx = 0.5, win_cy = 0.5, resize_on = true, resize_corner = "Bottom right",
    -- close button (title bar)
    cb_size = 26, cb_corner = 6, cb_bg = {27, 27, 27}, cb_icon = {128, 128, 128}, cb_hover = {200, 60, 60},
    -- open / close button (the floating one)
    ui_btn = isMobile, fb_shape = "Circle", fb_text = "R", fb_textsize = 20, fb_size = 46, fb_ratio = 1, fb_lock = false,
    fb_bg = {11, 11, 11}, fb_trans = 0, fb_accent = true, fb_textc = {232, 232, 232}, fb_strokec = {232, 232, 232},
    fb_stroke = 2, fb_x = 0.06, fb_y = 0.3,
    -- AIM button (touch)
    ab_shape = "Circle", ab_text = "AIM", ab_textsize = 15, aim_btn_size = 64, aim_btn_x = 88, aim_btn_y = 55,
    ab_bg = {16, 16, 16}, ab_trans = 0.1, ab_accent = true, ab_textc = {232, 232, 232}, ab_strokec = {232, 232, 232},
    ab_stroke = 2, ab_ratio = 1, ab_lock = false,
    -- quick buttons (touch): the look is shared; position, size, aspect, lock and label of each one are added below
    qb_btn = {16, 16, 16}, qb_trans = 0.06, qb_shape = "Rounded", qb_accent = true, qb_strokec = {232, 232, 232},
    qb_stroke = 1, qb_textsize = 11, qb_textc = {128, 128, 128},
    -- tap point: the marker you drag onto the game's fire button (the triggerbot taps there)
    tap_x = 0.82, tap_y = 0.62, tap_size = 44, tap_ratio = 1, tap_lock = false, tap_shape = "Circle", tap_text = "TAP",
    tap_textsize = 11, tap_fill = {20, 168, 255}, tap_trans = 0.7, tap_accent = true, tap_strokec = {232, 232, 232},
    tap_stroke = 2, tap_textc = {232, 232, 232}, tap_vis = "Always",
    -- every button on the main GUI
    hud_lock_all = false,
}

-- the quick buttons: id, label, the setting they toggle, default height on screen.
-- Each one has its own position (qb_<id>_x / _y), size, aspect, lock and label.
local QUICK = {{"trig", "TRIG", "trigger", 0.30}, {"spin", "SPIN", "spinbot", 0.38}, {"tp", "3P", "tp_on", 0.46},
    {"bhop", "BHOP", "bhop_on", 0.54}}
for _, q in ipairs(QUICK) do
    local p = "qb_" .. q[1] .. "_"
    THEME_DEFAULTS[p .. "x"], THEME_DEFAULTS[p .. "y"] = 0.93, q[4]
    THEME_DEFAULTS[p .. "size"], THEME_DEFAULTS[p .. "ratio"] = 40, 0.75
    THEME_DEFAULTS[p .. "lock"], THEME_DEFAULTS[p .. "text"] = false, q[2]
end

-- the filters of the aimbot (aim_chk_*) and of the triggerbot (trig_chk_*) are the same set, one copy each
local CHECKS = {{"wall", "Wall"}, {"team", "Team"}, {"dead", "Death"}, {"ff", "ForceField"},
    {"down", "Downed"}, {"friend", "Friends"}, {"invis", "Invisible"}}
local CK = {aim = {}, trig = {}}   -- settings key of every filter, per feature
do
    local on = {wall = true, team = true, dead = true, ff = true}
    for pre, keys in pairs(CK) do
        for _, c in ipairs(CHECKS) do
            keys[c[1]] = pre .. "_chk_" .. c[1]
            DEFAULTS[keys[c[1]]] = on[c[1]] == true
        end
    end
end

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

local S = {}
for k, v in pairs(DEFAULTS) do S[k] = copy(v) end
for k, v in pairs(THEME_DEFAULTS) do S[k] = copy(v) end
S.hud_preview = false   -- runtime only (not saved): shows every button so it can be placed

----------------------------------------------------------------------------
-- player lists (ignore / target): stored in S as "id:name", with a per-id set cache
----------------------------------------------------------------------------
local LIST = {sets = {ignore_list = {}, target_list = {}, ignore_teams = {}, target_teams = {}},
    counts = {ignore_list = 0, target_list = 0, ignore_teams = 0, target_teams = 0}}

local function listId(e) return tonumber(tostring(e):match("^(%d+)")) end

function LIST.rebuild()
    for key in pairs(LIST.sets) do
        local set, n = {}, 0
        local byName = (key == "ignore_teams" or key == "target_teams")   -- team lists hold team names, not user ids
        for _, e in ipairs(S[key]) do
            local id = byName and e or listId(e)
            if id and not set[id] then
                set[id] = true
                n = n + 1
            end
        end
        LIST.sets[key] = set
        LIST.counts[key] = n
    end
end

function LIST.has(key, id) return LIST.sets[key][id] == true end
function LIST.count(key) return LIST.counts[key] end

-- adds / removes a player from a list; returns true when the player is in the list afterwards
function LIST.toggle(key, id, name)
    local arr = S[key]
    for i, e in ipairs(arr) do
        if listId(e) == id then
            table.remove(arr, i)
            LIST.rebuild()
            return false
        end
    end
    arr[#arr + 1] = id .. ":" .. tostring(name or "?")
    LIST.rebuild()
    return true
end

function LIST.clear(key)
    S[key] = {}
    LIST.rebuild()
end

-- adds / removes a team (by name); returns true when the team is in the list afterwards
function LIST.toggleTeam(key, name)
    local arr = S[key]
    for i, e in ipairs(arr) do
        if e == name then
            table.remove(arr, i)
            LIST.rebuild()
            return false
        end
    end
    arr[#arr + 1] = name
    LIST.rebuild()
    return true
end

-- is this player a target (in the target list, or on a target team)?
function LIST.isTarget(p)
    return LIST.sets.target_list[p.UserId] == true or (p.Team ~= nil and LIST.sets.target_teams[p.Team.Name] == true)
end

-- is this player ignored, as a player or through the team? (forEsp: only the ones that are also hidden from esp / chams)
function LIST.isIgnored(p, forEsp)
    if S.ignore_on and (not forEsp or S.ignore_esp) and LIST.sets.ignore_list[p.UserId] == true then return true end
    if S.ignore_teams_on and (not forEsp or S.ignore_teams_esp) and p.Team ~= nil
        and LIST.sets.ignore_teams[p.Team.Name] == true then
        return true
    end
    return false
end

----------------------------------------------------------------------------
-- utils
----------------------------------------------------------------------------
local conns = {}
local function conn(c) conns[#conns + 1] = c return c end

local function col(t)
    return Color3.fromRGB(math.clamp(t[1], 0, 255), math.clamp(t[2], 0, 255), math.clamp(t[3], 0, 255))
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

local function sameTeam(p) return LP.Team ~= nil and p.Team == LP.Team end

-- module tables (filled in the logic part; the UI buttons call into them at click time)
local TR = {state = "off", note = "", lastActive = -1000}   -- triggerbot
local CH = {}                                              -- chams

----------------------------------------------------------------------------
-- theme registry
-- T holds the current theme colors by role. Instances created with a role name
-- (BackgroundColor3 = "item") are remembered and recolored by applyTheme().
----------------------------------------------------------------------------
local T = {}
local function syncT()
    T.accent, T.bg, T.side, T.card, T.sub = col(S.ui_accent), col(S.ui_bg), col(S.ui_side), col(S.ui_card), col(S.ui_sub)
    T.item, T.line, T.off, T.text, T.dim = col(S.ui_item), col(S.ui_line), col(S.ui_off), col(S.ui_text), col(S.ui_dim)
end
syncT()

local themed = setmetatable({}, {__mode = "k"})   -- instance -> {property = role}
local COLOR_PROPS = {BackgroundColor3 = true, TextColor3 = true, Color = true, ImageColor3 = true,
    ScrollBarImageColor3 = true, PlaceholderColor3 = true, TextStrokeColor3 = true}

local function bind(o, prop, role)
    local m = themed[o]
    if not m then
        m = {}
        themed[o] = m
    end
    m[prop] = role
    o[prop] = T[role]
end

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do
        if type(v) == "string" and COLOR_PROPS[k] then bind(o, k, v) else o[k] = v end
    end
    if parent then o.Parent = parent end
    return o
end

local refreshers, themeFns = {}, {}
local textObjs, descObjs, cornerObjs, panelObjs, cardObjs, subObjs = {}, {}, {}, {}, {}, {}

local function accent() return T.accent end
local function onTheme(fn) themeFns[#themeFns + 1] = fn fn() end
local function setProp(o, p, v) o[p] = v end
local function applyTheme()
    syncT()
    for o, m in pairs(themed) do
        for prop, role in pairs(m) do pcall(setProp, o, prop, T[role]) end
    end
    for _, f in ipairs(themeFns) do pcall(f) end
end
local function refreshAll()
    LIST.rebuild()
    for _, f in ipairs(refreshers) do pcall(f) end
    applyTheme()
end
local function curFont()
    local ok, f = pcall(function() return Enum.Font[S.ui_font] end)
    return (ok and f) or Enum.Font.GothamMedium
end

local RH = isMobile and 40 or 30
local TS = isMobile and 14 or 13    -- default text size
local openDrop                      -- closes the open list when another one opens

----------------------------------------------------------------------------
-- team colors (esp + chams)
-- "Team colors"      every team uses its own TeamColor
-- "Custom per team"  one color picked per team (defaults to the TeamColor)
-- "Ally / Enemy"     one color for your team, one for every other team
----------------------------------------------------------------------------
local TC = {}

function TC.rgb(c) return {math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)} end

-- default color of a team, as {r, g, b}
function TC.default(team) return TC.rgb(team.TeamColor.Color) end

function TC.of(p)
    if S.team_mode == "Ally / Enemy" then
        return col(sameTeam(p) and S.col_ally or S.col_enemy)
    end
    local team = p.Team
    if not team then return col(S.col_noteam) end
    if S.team_mode == "Custom per team" then
        local c = S.team_colors[team.Name]
        if c then return col(c) end
    end
    return team.TeamColor.Color
end

-- final color for a player: target-list color first, then the team color (useTeam) or the given custom color
function TC.pick(p, useTeam, custom)
    if S.target_mode ~= "Off" and LIST.isTarget(p) then return col(S.esp_target_color) end
    if useTeam then return TC.of(p) end
    return col(custom)
end
Loader.mark("Loading settings")
----------------------------------------------------------------------------
-- storage: configs, themes and autoload (files in the executor's workspace, memory when there is no writefile)
-- RagWare/configs/<name>.json   feature settings
-- RagWare/themes/<name>.json    looks and layout
-- RagWare/autoload_config.txt, RagWare/autoload_theme.txt   name to load on start
----------------------------------------------------------------------------
local ST = {root = "RagWare"}
ST.dir = {config = ST.root .. "/configs", theme = ST.root .. "/themes"}
ST.fs = (writefile and readfile and isfile and isfolder and makefolder and listfiles) and true or false
ST.mem = {}   -- path -> text, used when the executor has no file functions

-- settings that are tables but not colors
ST.kinds = {ignore_list = "list", target_list = "list", ignore_teams = "list", target_teams = "list",
    team_colors = "map", card_collapsed = "flags"}

-- keys that only exist in older configs -> the keys that replaced them
ST.migrate = {
    wallcheck = {"aim_chk_wall", "trig_chk_wall"}, teamcheck = {"aim_chk_team", "trig_chk_team"},
    deathcheck = {"aim_chk_dead", "trig_chk_dead"}, ff_check = {"aim_chk_ff", "trig_chk_ff"},
    downcheck = {"aim_chk_down", "trig_chk_down"}, friendcheck = {"aim_chk_friend", "trig_chk_friend"},
    invischeck = {"aim_chk_invis", "trig_chk_invis"},
    chams_occ = {"occ_on"}, chams_acc = {"occ_acc"},
    esp_color = {"col_enemy"}, esp_team_color = {"col_ally"},
}

-- theme keys that are positions / sizes of things; built-in themes leave them alone
ST.layout = {win_w = true, win_h = true, win_cx = true, win_cy = true, card_collapsed = true, hud_lock_all = true}

-- every button on the main GUI: position, size, aspect and lock are layout too, so built-in themes leave them alone
ST.hudKeys = {"fb_x", "fb_y", "fb_size", "fb_ratio", "aim_btn_x", "aim_btn_y", "aim_btn_size", "ab_ratio",
    "tap_x", "tap_y", "tap_size", "tap_ratio"}
for _, q in ipairs(QUICK) do
    for _, f in ipairs({"x", "y", "size", "ratio"}) do ST.hudKeys[#ST.hudKeys + 1] = "qb_" .. q[1] .. "_" .. f end
    ST.layout["qb_" .. q[1] .. "_lock"] = true
end
for _, k in ipairs(ST.hudKeys) do ST.layout[k] = true end
for _, k in ipairs({"fb_lock", "ab_lock", "tap_lock"}) do ST.layout[k] = true end

ST.builtin = {
    {"Black", {}},
    {"Midnight", {ui_bg = {8, 12, 20}, ui_side = {11, 16, 26}, ui_card = {14, 20, 32}, ui_sub = {10, 15, 25},
        ui_item = {22, 31, 47}, ui_line = {28, 39, 58}, ui_off = {40, 53, 76}, ui_text = {226, 233, 246},
        ui_dim = {118, 133, 160}, cb_bg = {22, 31, 47}, cb_icon = {118, 133, 160}, fb_bg = {11, 16, 26},
        ab_bg = {14, 20, 32}, qb_btn = {14, 20, 32}}},
    {"Crimson", {ui_accent = {235, 64, 72}}},
    {"Violet", {ui_accent = {150, 90, 255}}},
}

if ST.fs then
    pcall(function()
        for _, d in ipairs({ST.root, ST.dir.config, ST.dir.theme}) do
            if not isfolder(d) then makefolder(d) end
        end
    end)
end

-- raw access --------------------------------------------------------------
function ST.put(path, txt)
    if ST.fs then
        local ok, err = pcall(writefile, path, txt)
        if not ok then return false, tostring(err) end
    else
        ST.mem[path] = txt
    end
    return true
end

function ST.get(path)
    if ST.fs then
        local ok, r = pcall(function() return isfile(path) and readfile(path) or nil end)
        return ok and r or nil
    end
    return ST.mem[path]
end

function ST.del(path)
    if ST.fs then
        if not delfile then return false, "this executor has no delfile" end
        local ok, err = pcall(delfile, path)
        if not ok then return false, tostring(err) end
    else
        ST.mem[path] = nil
    end
    return true
end

function ST.decode(txt)
    local ok, data = pcall(function() return HttpService:JSONDecode(txt) end)
    if ok and type(data) == "table" then return data end
    return nil
end

-- names ---------------------------------------------------------------------
function ST.clean(n)
    n = tostring(n or ""):gsub("[^%w_%- ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return n:sub(1, 32)
end

function ST.path(kind, name) return ST.dir[kind] .. "/" .. name .. ".json" end

function ST.names(kind)
    local out, dir = {}, ST.dir[kind]
    if ST.fs then
        local ok, files = pcall(listfiles, dir)
        if ok and type(files) == "table" then
            for _, f in ipairs(files) do
                local n = tostring(f):match("([^/\\]+)%.json$")
                if n then out[#out + 1] = n end
            end
        end
    else
        local prefix = "^" .. (dir:gsub("%p", "%%%0")) .. "/(.+)%.json$"
        for path in pairs(ST.mem) do
            local n = path:match(prefix)
            if n then out[#out + 1] = n end
        end
    end
    table.sort(out)
    return out
end

function ST.isBuiltin(name)
    for _, b in ipairs(ST.builtin) do
        if b[1]:lower() == tostring(name):lower() then return true end
    end
    return false
end

-- settings <-> json --------------------------------------------------------
function ST.defs(kind) return kind == "theme" and THEME_DEFAULTS or DEFAULTS end

function ST.encode(kind)
    local out = {}
    for k in pairs(ST.defs(kind)) do out[k] = S[k] end
    return HttpService:JSONEncode(out)
end

-- checks a decoded value against the type of the default; returns the value to store, or nil to skip it
function ST.convert(k, def, v)
    local kind = ST.kinds[k]
    if kind == "list" then
        if type(v) ~= "table" then return nil end
        local out = {}
        for i, e in ipairs(v) do
            if i > 300 then break end
            out[#out + 1] = tostring(e)
        end
        return out
    elseif kind == "map" then
        if type(v) ~= "table" then return nil end
        local out, n = {}, 0
        for name, c in pairs(v) do
            if type(name) == "string" and type(c) == "table" and #c == 3 then
                n = n + 1
                if n > 64 then break end
                out[name] = {tonumber(c[1]) or 0, tonumber(c[2]) or 0, tonumber(c[3]) or 0}
            end
        end
        return out
    elseif kind == "flags" then        -- {name = true}
        if type(v) ~= "table" then return nil end
        local out, n = {}, 0
        for name, on in pairs(v) do
            if type(name) == "string" and on == true then
                n = n + 1
                if n > 64 then break end
                out[name] = true
            end
        end
        return out
    elseif type(def) == "table" then   -- color {r, g, b}
        if type(v) == "table" and #v == 3 then
            return {tonumber(v[1]) or 0, tonumber(v[2]) or 0, tonumber(v[3]) or 0}
        end
        return nil
    elseif type(v) == type(def) then
        return v
    end
    return nil
end

function ST.apply(kind, data)
    local defs = ST.defs(kind)
    local function set(k, v)
        local def = defs[k]
        if def == nil then return end
        local nv = ST.convert(k, def, v)
        if nv ~= nil then S[k] = nv end
    end
    for k, v in pairs(data) do
        if defs[k] ~= nil then
            set(k, v)
        elseif kind == "config" and ST.migrate[k] then
            for _, nk in ipairs(ST.migrate[k]) do
                if data[nk] == nil then set(nk, v) end
            end
        end
    end
end

-- back to the defaults (a config / theme file only stores what it needs, the rest falls back to these)
function ST.resetConfig()
    for k, v in pairs(DEFAULTS) do S[k] = copy(v) end
end

function ST.resetTheme(overrides)
    for k, v in pairs(THEME_DEFAULTS) do
        if not ST.layout[k] then S[k] = copy(v) end
    end
    for k, v in pairs(overrides or {}) do S[k] = copy(v) end
end

-- save / load / rename -----------------------------------------------------
function ST.save(kind, name)
    name = ST.clean(name)
    if name == "" then return false, "empty name" end
    if kind == "theme" and ST.isBuiltin(name) then return false, "that name is reserved" end
    local ok, err = ST.put(ST.path(kind, name), ST.encode(kind))
    if not ok then return false, err end
    return true, name
end

function ST.load(kind, name)
    if kind == "theme" then
        for _, b in ipairs(ST.builtin) do
            if b[1] == name then
                ST.resetTheme(b[2])
                return true
            end
        end
    end
    local txt = ST.get(ST.path(kind, name))
    if not txt then return false, "not found" end
    local data = ST.decode(txt)
    if not data then return false, "invalid file" end
    if kind == "theme" then ST.resetTheme() else ST.resetConfig() end
    ST.apply(kind, data)
    return true
end

function ST.rename(kind, old, new)
    new = ST.clean(new)
    if new == "" then return false, "empty name" end
    if kind == "theme" and ST.isBuiltin(new) then return false, "that name is reserved" end
    if new == old then return false, "that is already its name" end
    if ST.get(ST.path(kind, new)) then return false, "name already exists" end
    local txt = ST.get(ST.path(kind, old))
    if not txt then return false, "not found" end
    local ok, err = ST.put(ST.path(kind, new), txt)
    if not ok then return false, err end
    ST.del(ST.path(kind, old))
    if ST.auto(kind) == old then ST.setAuto(kind, new) end
    return true, new
end

-- autoload -------------------------------------------------------------------
function ST.autoPath(kind) return ST.root .. "/autoload_" .. kind .. ".txt" end

function ST.auto(kind)
    local a = ST.get(ST.autoPath(kind))
    if a == nil and kind == "config" then a = ST.get(ST.root .. "/autoload.txt") end   -- file used by older versions
    return a and (a:gsub("%s+$", "")) or ""
end

function ST.setAuto(kind, name) return ST.put(ST.autoPath(kind), name or "") end

-- applies the autoload theme and config (called once, before the UI is built)
do
    local t = ST.auto("theme")
    if t ~= "" then pcall(ST.load, "theme", t) end
    local c = ST.auto("config")
    if c ~= "" then pcall(ST.load, "config", c) end
    LIST.rebuild()
    syncT()
end
Loader.mark("Building the interface")
----------------------------------------------------------------------------
-- ui toolkit
----------------------------------------------------------------------------
local W = {}
do
local sink = refreshers
function W.setSink(t) sink = t or refreshers end

local function tween(o, props, t)
    pcall(function()
        TweenService:Create(o, TweenInfo.new(t or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
    end)
end

local function pointerDown(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

-- generic drag (slider, color picker): onMove receives the pointer position; scrolling is locked while dragging
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

local order = setmetatable({}, {__mode = "k"})   -- weak: destroyed rows do not stay referenced
local function nextOrder(p) order[p] = (order[p] or 0) + 1 return order[p] end

local function text(parent, str, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.BorderSizePixel = 0
    l.Text = str
    bind(l, "TextColor3", "text")
    l.TextSize = TS
    l.Font = curFont()
    l.TextXAlignment = Enum.TextXAlignment.Left
    for k, v in pairs(props or {}) do
        if type(v) == "string" and COLOR_PROPS[k] then bind(l, k, v) else l[k] = v end
    end
    l.Parent = parent
    if not (props and props.Font) then textObjs[#textObjs + 1] = l end
    return l
end

-- corners that follow the "Corner radius" theme setting (delta = difference from the window radius)
local function corner(o, delta)
    local c = new("UICorner", {}, o)
    cornerObjs[#cornerObjs + 1] = {c, delta or 0}
    return c
end

-- controls (buttons, dropdowns, inputs, keybinds): every one registers here, so Theme > Controls can restyle them all.
-- flat = no border and no text size change (pills, lists)
local ctlObjs = setmetatable({}, {__mode = "k"})   -- surface -> {corner, stroke, flat}

local function ctlLabel(surface)
    if surface:IsA("TextBox") or (surface:IsA("TextButton") and surface.Text ~= "") then return surface end
    return surface:FindFirstChildWhichIsA("TextLabel")
end

local function ctlStyle(surface, c)
    c.corner.CornerRadius = UDim.new(0, S.ctl_corner)
    surface.BackgroundTransparency = S.ctl_trans
    if c.stroke then
        c.stroke.Color = S.ctl_stroke_accent and accent() or T.line
        c.stroke.Thickness = S.ctl_stroke
        c.stroke.Transparency = S.ctl_stroke_trans
    end
    if not c.flat then
        local lab = ctlLabel(surface)
        if lab then lab.TextSize = math.max(S.ctl_text, 1) end
    end
end

local function ctl(surface, flat)
    local c = {corner = new("UICorner", {}, surface), flat = flat}
    if not flat then c.stroke = new("UIStroke", {Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, surface) end
    ctlObjs[surface] = c
    ctlStyle(surface, c)
    return c.corner
end

onTheme(function()
    for surface, c in pairs(ctlObjs) do ctlStyle(surface, c) end
end)

-- "v" arrow made of two lines (no font/icon needed); Rotation = 180 turns it into "^"
local function chevron(parent, pos)
    local h = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(14, 14),
        BackgroundTransparency = 1}, parent)
    local lines = {}
    for i, spec in ipairs({{4.5, 45}, {9.5, -45}}) do
        local l = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(spec[1], 6),
            Size = UDim2.fromOffset(7, 2), Rotation = spec[2], BackgroundColor3 = "dim", BorderSizePixel = 0}, h)
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, l)
        lines[i] = l
    end
    return h, lines
end

-- flat row: label on the left (+ optional description below), control on the right
local function newRow(parent, minH)
    return new("Frame", {Size = UDim2.new(1, 0, 0, minH or RH), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = nextOrder(parent)}, parent)
end

local function rowLabel(r, label, desc, rightPad)
    local pad = rightPad or 60
    local l = text(r, label, {Size = UDim2.new(1, -pad, 0, RH), TextTruncate = Enum.TextTruncate.AtEnd})
    if desc then
        local d = text(r, desc, {Position = UDim2.fromOffset(0, RH - 8), Size = UDim2.new(1, -pad, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, TextSize = 11, TextColor3 = "dim", TextWrapped = true,
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

-- switch; returns the function that applies the state (animated, or immediate when instant = true)
local function switch(parent, rightOff)
    local sw = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, rightOff or 0, 0, RH / 2),
        BackgroundColor3 = "off", BorderSizePixel = 0}, parent)
    local swc = new("UICorner", {}, sw)
    local knob = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0}, sw)
    local knc = new("UICorner", {}, knob)
    -- size, shape and colors come from Theme > Switches (every switch is refreshed by applyTheme)
    return function(on, instant)
        local w, h = math.max(S.sw_w, 10), math.max(S.sw_h, 6)   -- a switch never gets so small that it disappears
        local k = math.max(math.min(S.sw_knob, h), 2)
        local m = math.floor((h - k) / 2)
        local shape = S.sw_shape
        sw.Size = UDim2.fromOffset(w, h)
        knob.Size = UDim2.fromOffset(k, k)
        swc.CornerRadius = (shape == "Pill") and UDim.new(1, 0) or UDim.new(0, shape == "Rounded" and math.floor(h * 0.3) or 0)
        knc.CornerRadius = (shape == "Pill") and UDim.new(1, 0) or UDim.new(0, shape == "Rounded" and math.floor(k * 0.3) or 0)
        knob.BackgroundColor3 = col(S.sw_knob_c)
        local pos = UDim2.new(0, on and (w - k - m) or m, 0.5, 0)
        local c = on and (S.sw_accent and accent() or col(S.sw_on)) or T.off
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
    sink[#sink + 1] = function() set(S[key], true) end
    onTheme(function() set(S[key], true) end)
    return r
end

-- feature = row with a toggle + arrow at the end; the arrow opens the settings panel right below (returns that panel).
-- o = {sub = false (no arrow), desc = "text", cb = function}. key = nil makes an arrow-only group.
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
            BackgroundColor3 = "sub", BorderSizePixel = 0, Visible = false, LayoutOrder = 2}, holder)
        corner(sub, -4)
        subObjs[#subObjs + 1] = sub   -- transparency of the settings panels (Theme > Cards)
        new("UIStroke", {Color = "line", Thickness = 1}, sub)
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
        sink[#sink + 1] = function() setSw(S[key], true) end
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
        Size = UDim2.fromOffset(64, 20), BackgroundColor3 = "item", BorderSizePixel = 0}, r)
    ctl(vb, true)
    local val = new("TextBox", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
        TextColor3 = "text", TextSize = 12, Font = curFont(), ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Center}, vb)
    textObjs[#textObjs + 1] = val
    local tr = new("Frame", {Size = UDim2.new(1, 0, 0, isMobile and 26 or 20), BackgroundTransparency = 1,
        LayoutOrder = 2}, holder)
    local bar = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.4),
        Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = "off", BorderSizePixel = 0}, tr)
    local barC = new("UICorner", {}, bar)
    local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BorderSizePixel = 0}, bar)
    local fillC = new("UICorner", {}, fill)
    local knob = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5),
        Size = UDim2.fromOffset(12, 12), BackgroundColor3 = "text", BorderSizePixel = 0}, fill)
    local knobC = new("UICorner", {}, knob)
    -- track thickness, knob size, shape and fill color come from Theme > Sliders
    onTheme(function()
        local r = (S.sl_shape == "Square") and UDim.new(0, 0) or UDim.new(1, 0)
        bar.Size = UDim2.new(1, 0, 0, S.sl_h)
        knob.Size = UDim2.fromOffset(S.sl_knob, S.sl_knob)
        barC.CornerRadius, fillC.CornerRadius, knobC.CornerRadius = r, r, r
        fill.BackgroundColor3 = S.sl_accent and accent() or col(S.sl_fill)
    end)
    local hit = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false}, tr)

    local function plain(v)
        return (step < 1) and string.format("%.2f", v) or string.format("%d", math.floor(v + 0.5))
    end
    local function refresh()
        local v = get()
        fill.Size = UDim2.fromScale(math.clamp((v - mn) / (mx - mn), 0, 1), 1)
        if not val:IsFocused() then val.Text = plain(v) .. (suffix or "") end
    end
    -- the value can be typed too: click it, write a number, press enter (it is kept inside the slider range)
    val.Focused:Connect(function()
        val.Text = plain(get())
        pcall(function()
            val.SelectionStart = 1
            val.CursorPosition = #val.Text + 1
        end)
    end)
    val.FocusLost:Connect(function()
        local n = tonumber((val.Text:gsub(",", "."):match("-?%d+%.?%d*")))
        if n then
            n = math.clamp(n, mn, mx)
            if step >= 1 then n = math.floor(n + 0.5) else n = math.floor(n * 1000 + 0.5) / 1000 end
            set(n)
        end
        refresh()
    end)
    bindDrag(hit, function(pos)
        local w = bar.AbsoluteSize.X
        if w <= 0 then return end
        local v = mn + (mx - mn) * math.clamp((pos.X - bar.AbsolutePosition.X) / w, 0, 1)
        v = math.clamp(math.floor(v / step + 0.5) * step, mn, mx)
        set(tonumber(string.format("%.4f", v)))
        refresh()
    end)
    sink[#sink + 1] = refresh
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

-- dropdown: the list opens inline, right below the row (options can be a table or a function returning one)
local function Dropdown(parent, label, get, set, options, desc)
    local holder = stack(parent, 2)
    local r = newRow(holder)
    rowLabel(r, label, desc, 140)
    local btn = new("TextButton", {Name = "DropBtn", AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0, RH / 2), Size = UDim2.fromOffset(128, RH - 8), BackgroundColor3 = "item",
        BorderSizePixel = 0, Text = "", AutoButtonColor = true}, r)
    ctl(btn)
    local t = text(btn, "", {Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -28, 1, 0), TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd})
    local chev = chevron(btn, UDim2.new(1, -13, 0.5, 0))
    local list = new("Frame", {Name = "DropList", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "item", BorderSizePixel = 0, Visible = false, LayoutOrder = 2}, holder)
    ctl(list, true)
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
        if openDrop == close then openDrop = nil end
    end
    local function build()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
        local o = opts()
        if #o == 0 then
            text(list, "(none)", {Size = UDim2.new(1, 0, 0, RH - 4), TextSize = 12, TextColor3 = "dim"})
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
        if list.Visible then
            close()
        else
            if openDrop then openDrop() end
            build()
            list.Visible = true
            chev.Rotation = 180
            openDrop = close
        end
    end)
    sink[#sink + 1] = refresh
    refresh()
    return holder, refresh
end

-- multiselect ("multi combo" style): one row with a summary; opens a list of boxes, each toggling a key of S.
-- items = {{key, label}, ...}
local function MultiSelect(parent, label, items, desc)
    local holder = stack(parent, 2)
    local r = newRow(holder)
    rowLabel(r, label, desc, 150)
    local btn = new("TextButton", {Name = "MultiBtn", AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0, RH / 2), Size = UDim2.fromOffset(136, RH - 8), BackgroundColor3 = "item",
        BorderSizePixel = 0, Text = "", AutoButtonColor = true}, r)
    ctl(btn)
    local t = text(btn, "", {Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -28, 1, 0), TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd})
    local chev = chevron(btn, UDim2.new(1, -13, 0.5, 0))
    local list = new("Frame", {Name = "MultiList", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "item", BorderSizePixel = 0, Visible = false, LayoutOrder = 2}, holder)
    ctl(list, true)
    new("UIPadding", {PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8)}, list)
    new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, list)

    local ticks = {}
    local function refresh()
        local names, n = {}, 0
        for i, it in ipairs(items) do
            local on = S[it[1]] and true or false
            ticks[i].Visible = on
            if on then
                n = n + 1
                names[#names + 1] = it[2]
            end
        end
        t.Text = (n == 0 and "None") or (n == #items and "All") or table.concat(names, ", ")
    end
    for i, it in ipairs(items) do
        local line = new("TextButton", {Size = UDim2.new(1, 0, 0, RH - 4), BackgroundTransparency = 1, Text = "",
            AutoButtonColor = false, LayoutOrder = i}, list)
        text(line, it[2], {Size = UDim2.new(1, -28, 1, 0), TextSize = 12})
        local box = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5),
            Size = UDim2.fromOffset(16, 16), BackgroundColor3 = "sub", BorderSizePixel = 0}, line)
        new("UICorner", {CornerRadius = UDim.new(0, 4)}, box)
        new("UIStroke", {Color = "line", Thickness = 1}, box)
        local tk = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0, Visible = false}, box)
        new("UICorner", {CornerRadius = UDim.new(0, 2)}, tk)
        onTheme(function() tk.BackgroundColor3 = accent() end)
        ticks[i] = tk
        line.Activated:Connect(function()
            S[it[1]] = not S[it[1]]
            refresh()
        end)
    end
    local function close()
        list.Visible = false
        chev.Rotation = 0
        if openDrop == close then openDrop = nil end
    end
    btn.Activated:Connect(function()
        if list.Visible then
            close()
        else
            if openDrop then openDrop() end
            list.Visible = true
            chev.Rotation = 180
            openDrop = close
        end
    end)
    sink[#sink + 1] = refresh
    refresh()
    return holder
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
        Size = UDim2.fromOffset(96, RH - 8), BackgroundColor3 = "item", BorderSizePixel = 0, Text = "",
        AutoButtonColor = true}, r)
    ctl(btn)
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
    sink[#sink + 1] = refresh
    refresh()
    return r
end

-- accepts "#RRGGBB", "RRGGBB" and "#RGB"
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

-- color picker: hex field + saturation/brightness square + hue strip (HSV, like Roblox's picker) + palette.
-- the panel is only built the first time it opens.
local function ColorRowG(parent, label, getc, setc, cb, desc)
    local holder = stack(parent, 2)
    local r = newRow(holder)
    rowLabel(r, label, desc, 60)
    local sw = new("TextButton", {Name = "Swatch", AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0, RH / 2), Size = UDim2.fromOffset(40, 18), BorderSizePixel = 0, Text = "",
        AutoButtonColor = false, ZIndex = 3}, r)
    new("UICorner", {CornerRadius = UDim.new(0, 5)}, sw)
    new("UIStroke", {Color = "text", Transparency = 0.8, Thickness = 1}, sw)
    local rowBtn = new("TextButton", {Size = UDim2.new(1, -46, 0, RH), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, ZIndex = 2}, r)

    local h, s, v = 0, 0, 1
    local panel, built = nil, false
    local svBox, svDot, hueDot, hexBox, rgbBoxes

    local function readHSV()
        local hh, ss, vv = col(getc()):ToHSV()
        if ss > 0.001 and vv > 0.001 then h = hh end
        s, v = ss, vv
    end
    local function hexText()
        local c = getc()
        return string.format("#%02X%02X%02X", math.floor(c[1] + 0.5), math.floor(c[2] + 0.5), math.floor(c[3] + 0.5))
    end
    local function paint()
        sw.BackgroundColor3 = col(getc())
        if built then
            svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            svDot.Position = UDim2.fromScale(s, 1 - v)
            hueDot.Position = UDim2.fromScale(0.5, h)
            hexBox.Text = hexText()
            local cc = getc()
            for i = 1, 3 do rgbBoxes[i].Text = tostring(math.floor(cc[i] + 0.5)) end
        end
    end
    local function commit()
        local c = Color3.fromHSV(h, s, v)
        setc({math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)})
        paint()
        if cb then cb() end
    end
    local function setRGB(r8, g8, b8)
        setc({r8, g8, b8})
        readHSV()
        paint()
        if cb then cb() end
    end

    local function build()
        built = true
        panel = new("Frame", {Name = "Picker", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = "item", BorderSizePixel = 0, Visible = false, LayoutOrder = 2}, holder)
        new("UICorner", {CornerRadius = UDim.new(0, 6)}, panel)
        new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8)}, panel)
        new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, panel)

        local hr = new("Frame", {Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 1}, panel)
        text(hr, "Hex", {Size = UDim2.new(0, 36, 1, 0), TextColor3 = "dim", TextSize = 12})
        hexBox = new("TextBox", {Name = "Hex", Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -40, 1, 0),
            BackgroundColor3 = "sub", BorderSizePixel = 0, Text = hexText(), PlaceholderText = "#RRGGBB",
            PlaceholderColor3 = "dim", TextColor3 = "text", TextSize = 12, Font = curFont(), ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left}, hr)
        new("UICorner", {CornerRadius = UDim.new(0, 5)}, hexBox)
        new("UIPadding", {PaddingLeft = UDim.new(0, 8)}, hexBox)
        textObjs[#textObjs + 1] = hexBox
        hexBox.FocusLost:Connect(function()
            local r8, g8, b8 = parseHex(hexBox.Text)
            if r8 then setRGB(r8, g8, b8) else hexBox.Text = hexText() end
        end)

        -- R / G / B boxes (0-255): every number of the color can be typed too
        local rgbRow = new("Frame", {Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 2}, panel)
        new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder}, rgbRow)
        rgbBoxes = {}
        for i, nm in ipairs({"R", "G", "B"}) do
            local cellF = new("Frame", {Size = UDim2.new(1 / 3, -4, 1, 0), BackgroundColor3 = "sub", BorderSizePixel = 0,
                LayoutOrder = i}, rgbRow)
            new("UICorner", {CornerRadius = UDim.new(0, 5)}, cellF)
            text(cellF, nm, {Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(12, 26), TextColor3 = "dim",
                TextSize = 12, Font = Enum.Font.GothamBold})
            local tb = new("TextBox", {Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -28, 1, 0),
                BackgroundTransparency = 1, Text = "", TextColor3 = "text", TextSize = 12, Font = curFont(),
                ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left}, cellF)
            textObjs[#textObjs + 1] = tb
            rgbBoxes[i] = tb
            tb.FocusLost:Connect(function()
                local cc = getc()
                local vals = {cc[1], cc[2], cc[3]}
                local n = tonumber((tb.Text:gsub(",", "."):match("-?%d+%.?%d*")))
                if n then
                    vals[i] = math.floor(math.clamp(n, 0, 255) + 0.5)
                    setRGB(vals[1], vals[2], vals[3])
                else
                    paint()
                end
            end)
        end

        local pr = new("Frame", {Size = UDim2.new(1, 0, 0, isMobile and 130 or 110), BackgroundTransparency = 1,
            LayoutOrder = 3}, panel)
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
            BackgroundTransparency = 1, LayoutOrder = 4}, panel)
        local cell = isMobile and 28 or 22
        new("UIGridLayout", {CellSize = UDim2.fromOffset(cell, cell), CellPadding = UDim2.fromOffset(6, 6),
            SortOrder = Enum.SortOrder.LayoutOrder}, pal)
        for i, c in ipairs(PALETTE) do
            local b = new("TextButton", {BackgroundColor3 = Color3.fromRGB(c[1], c[2], c[3]), BorderSizePixel = 0,
                Text = "", AutoButtonColor = false, LayoutOrder = i}, pal)
            new("UICorner", {CornerRadius = UDim.new(0, 5)}, b)
            new("UIStroke", {Color = "text", Transparency = 0.85, Thickness = 1}, b)
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
    sink[#sink + 1] = function()
        readHSV()
        paint()
    end
    readHSV()
    paint()
    return holder
end


local function ColorRow(parent, label, key, cb, desc)
    return ColorRowG(parent, label, function() return S[key] end, function(c) S[key] = c end, cb, desc)
end

-- simple icons made of Frames; returns (holder, paint(color))
local function icon(kind, parent, pos)
    local h = new("Frame", {Name = "Icon", Size = UDim2.fromOffset(18, 18), Position = pos, BackgroundTransparency = 1}, parent)
    local parts = {}
    local function ring(size, thick, x, y)
        local f = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, BorderSizePixel = 0}, h)
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, f)
        parts[#parts + 1] = {new("UIStroke", {Thickness = thick}, f), "Color"}
    end
    local function bar(x, y, w, hh, round, rot)
        local f = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y),
            Size = UDim2.fromOffset(w, hh), BorderSizePixel = 0, Rotation = rot or 0}, h)
        if round then new("UICorner", {CornerRadius = UDim.new(1, 0)}, f) end
        parts[#parts + 1] = {f, "BackgroundColor3"}
    end
    if kind == "Combat" then          -- crosshair
        ring(10, 2, 9, 9)
        bar(9, 2, 2, 4); bar(9, 16, 2, 4); bar(2, 9, 4, 2); bar(16, 9, 4, 2)
    elseif kind == "Visual" then      -- eye
        local e = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(9, 9),
            Size = UDim2.fromOffset(18, 11), BackgroundTransparency = 1, BorderSizePixel = 0}, h)
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, e)
        parts[#parts + 1] = {new("UIStroke", {Thickness = 2}, e), "Color"}
        bar(9, 9, 5, 5, true)
    elseif kind == "Player" then      -- person
        ring(7, 2, 9, 5)
        local b = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(9, 14),
            Size = UDim2.fromOffset(14, 8), BackgroundTransparency = 1, BorderSizePixel = 0}, h)
        new("UICorner", {CornerRadius = UDim.new(0, 5)}, b)
        parts[#parts + 1] = {new("UIStroke", {Thickness = 2}, b), "Color"}
    elseif kind == "Teleport" then    -- map pin
        ring(10, 2, 9, 6)
        bar(9, 13, 2, 5)
        bar(9, 17, 10, 2, true)
    elseif kind == "Theme" then       -- palette
        ring(16, 2, 9, 9)
        bar(6, 7, 3, 3, true); bar(11, 6, 3, 3, true); bar(12, 11, 3, 3, true)
    else                              -- Config: gear
        ring(10, 2, 9, 9)
        bar(9, 2, 3, 4); bar(9, 16, 3, 4); bar(2, 9, 4, 3); bar(16, 9, 4, 3)
        bar(3.5, 3.5, 3, 3, false, 45); bar(14.5, 3.5, 3, 3, false, 45)
        bar(3.5, 14.5, 3, 3, false, 45); bar(14.5, 14.5, 3, 3, false, 45)
    end
    return h, function(color)
        for _, p in ipairs(parts) do p[1][p[2]] = color end
    end
end

local function Button(parent, label, cb)
    local b = new("TextButton", {Size = UDim2.new(1, 0, 0, RH - 2), BackgroundColor3 = "item", BorderSizePixel = 0,
        Text = label, TextColor3 = "text", TextSize = 12, Font = curFont(), AutoButtonColor = true,
        LayoutOrder = nextOrder(parent)}, parent)
    ctl(b)
    textObjs[#textObjs + 1] = b
    b.Activated:Connect(cb)
    return b
end

local function Input(parent, label, default, placeholder)
    local r = newRow(parent)
    rowLabel(r, label, nil, 150)
    local tb = new("TextBox", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0, RH / 2),
        Size = UDim2.fromOffset(136, RH - 8), BackgroundColor3 = "item", BorderSizePixel = 0, Text = default,
        PlaceholderText = placeholder or "", PlaceholderColor3 = "dim", TextColor3 = "text", TextSize = 12,
        Font = curFont(), ClearTextOnFocus = false}, r)
    ctl(tb)
    textObjs[#textObjs + 1] = tb
    return tb
end

-- read-only row (value that changes in real time)
local function StatusRow(parent, label)
    local r = newRow(parent)
    text(r, label, {Size = UDim2.new(0, 50, 0, RH), TextColor3 = "dim", TextSize = 12})
    return text(r, "-", {Position = UDim2.fromOffset(54, 0), Size = UDim2.new(1, -54, 0, RH),
        TextXAlignment = Enum.TextXAlignment.Right, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd})
end

-- card = titled block; page.cols = two columns (they become one in a narrow window)
local function Card(page, title, colIdx)
    -- Returns the BODY of the card: everything is built inside it, so collapsing a card just hides the body.
    -- How the card looks (transparency, border, header, padding...) is applied by the theme callback in the window part.
    local card = new("Frame", {Name = "Card", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "card", BorderSizePixel = 0, LayoutOrder = #page.cards + 1}, page.cols[colIdx or 1])
    local cc = new("UICorner", {}, card)
    local stroke = new("UIStroke", {Thickness = 1}, card)
    local pad = new("UIPadding", {}, card)
    new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, card)
    -- header: (accent bar) + title + collapse arrow. The whole header is the button
    local head = new("TextButton", {Name = "Header", Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, LayoutOrder = -2}, card)
    local bar = new("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(3, 12), BackgroundColor3 = "accent", BorderSizePixel = 0, Visible = false}, head)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, bar)
    local label = text(head, title, {Size = UDim2.new(1, -20, 1, 0), TextSize = 12, Font = Enum.Font.GothamBold,
        TextColor3 = "dim"})
    local chev = chevron(head, UDim2.new(1, -8, 0.5, 0))
    local divider = new("Frame", {Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = "line", BorderSizePixel = 0,
        LayoutOrder = -1}, card)
    local body = new("Frame", {Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = 1}, card)
    new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, body)
    local key = tostring(page.name or "?") .. "/" .. title
    head.Activated:Connect(function()
        if not S.card_collapse then return end
        S.card_collapsed[key] = (not S.card_collapsed[key]) or nil
        applyTheme()
    end)
    cardObjs[#cardObjs + 1] = {frame = card, corner = cc, stroke = stroke, pad = pad, bar = bar, label = label,
        chev = chev, divider = divider, body = body, key = key}
    page.cards[#page.cards + 1] = {frame = card, col = colIdx or 1}
    return body
end

W.tween, W.pointerDown, W.bindDrag, W.nextOrder, W.text, W.corner, W.chevron = tween, pointerDown, bindDrag, nextOrder, text, corner, chevron
W.newRow, W.rowLabel, W.stack, W.switch, W.ctl = newRow, rowLabel, stack, switch, ctl
W.Toggle, W.Feature, W.Slider, W.SK, W.Dropdown, W.MultiSelect, W.DK, W.Keybind = Toggle, Feature, Slider, SK, Dropdown, MultiSelect, DK, Keybind
W.ColorRow, W.ColorRowG, W.icon, W.Button, W.Input, W.StatusRow, W.Card = ColorRow, ColorRowG, icon, Button, Input, StatusRow, Card
end   -- end of the toolkit block

----------------------------------------------------------------------------
-- window
----------------------------------------------------------------------------
local gui, overlay, win, pages, layout, updateGrip, selectTab, updateQuick, updateAim
local aimHeld = false

do
local text, corner, tween, pointerDown, icon = W.text, W.corner, W.tween, W.pointerDown, W.icon

local guiParent
do
    local ok, h = pcall(function() return gethui and gethui() end)
    guiParent = (ok and h) or LP:WaitForChild("PlayerGui")
end

gui = new("ScreenGui", {Name = "RagWare", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 200,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, guiParent)
overlay = new("ScreenGui", {Name = "RagWareOverlay", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, guiParent)

local MIN_W, MIN_H = 400, 340
local COMPACT_AT = 600   -- narrower than this: no sidebar, tabs in a row at the top
local NARROW_AT = 560    -- content width below which the two columns become one
local MF = isMobile and 0.92 or 0.98   -- fraction of the screen the window may fill (margin for notches / edges)
local TAB_H = isMobile and 36 or 32
local TITLE_H = 46
local function SW() return math.max(S.ui_sidew, 90) end   -- the sidebar never gets so thin that the tabs disappear
local CORNERS = {
    ["Bottom right"] = {1, 1}, ["Bottom left"] = {0, 1}, ["Top right"] = {1, 0}, ["Top left"] = {0, 0},
}

win = new("Frame", {Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(S.win_w, S.win_h), BackgroundColor3 = "bg", BorderSizePixel = 0, Active = true}, gui)
corner(win, 0)
local winStroke = new("UIStroke", {Thickness = 1, Transparency = 0.55}, win)
local uiscale = new("UIScale", {}, win)
local winGrad = new("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255),
    Color3.fromRGB(205, 205, 205))}, win)
panelObjs[#panelObjs + 1] = {win, 1}

-- accent line on top (fades out at the ends)
local topLine = new("Frame", {Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 0, 2),
    BackgroundColor3 = "accent", BorderSizePixel = 0, ZIndex = 8}, win)
new("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.15, 0), NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, 1)})}, topLine)

-- sidebar
local side = new("Frame", {Name = "Side", Size = UDim2.new(0, SW(), 1, 0), BackgroundColor3 = "side",
    BorderSizePixel = 0}, win)
corner(side, 0)
local sideFill = new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
    Size = UDim2.new(0, 18, 1, 0), BackgroundColor3 = "side", BorderSizePixel = 0}, side)   -- squares the right corners
new("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = "line", BorderSizePixel = 0, ZIndex = 2}, side)
panelObjs[#panelObjs + 1] = {side, 1}
panelObjs[#panelObjs + 1] = {sideFill, 1}

local logo = text(side, "", {Position = UDim2.fromOffset(18, 13), Size = UDim2.new(1, -24, 0, 24), TextSize = 20,
    Font = Enum.Font.GothamBold, RichText = true})
text(side, "v4.0", {Position = UDim2.fromOffset(19, 36), Size = UDim2.new(1, -24, 0, 14), TextSize = 11,
    TextColor3 = "dim"})
local tabs = new("Frame", {Name = "Tabs", Position = UDim2.fromOffset(8, 64), Size = UDim2.new(1, -16, 1, -120),
    BackgroundTransparency = 1}, side)
local tabLayout = new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, tabs)

do
    local foot = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -12),
        Size = UDim2.new(1, -28, 0, 36), BackgroundTransparency = 1}, side)
    local avatar = new("ImageLabel", {Position = UDim2.fromOffset(0, 3), Size = UDim2.fromOffset(30, 30),
        BackgroundColor3 = "item", BorderSizePixel = 0}, foot)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, avatar)
    text(foot, LP.DisplayName, {Position = UDim2.fromOffset(38, 2), Size = UDim2.new(1, -38, 0, 17), TextSize = 12,
        Font = Enum.Font.GothamBold, TextTruncate = Enum.TextTruncate.AtEnd})
    text(foot, "@" .. LP.Name, {Position = UDim2.fromOffset(38, 18), Size = UDim2.new(1, -38, 0, 14), TextSize = 11,
        TextColor3 = "dim", TextTruncate = Enum.TextTruncate.AtEnd})
    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        end)
        if ok and img then avatar.Image = img end
    end)
end

-- main area
local main = new("Frame", {Name = "Main", Position = UDim2.fromOffset(SW(), 0),
    Size = UDim2.new(1, -SW(), 1, 0), BackgroundTransparency = 1}, win)
local pageTitle = text(main, "Combat", {Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -110, 0, TITLE_H),
    TextSize = 17, Font = Enum.Font.GothamBold})
local miniLogo = text(main, "", {Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(160, TITLE_H), TextSize = 18,
    Font = Enum.Font.GothamBold, RichText = true, Visible = false})
local content = new("Frame", {Name = "Content", Position = UDim2.fromOffset(16, 48), Size = UDim2.new(1, -30, 1, -60),
    BackgroundTransparency = 1, ClipsDescendants = true}, main)

local dragBar = new("Frame", {Name = "DragBar", Size = UDim2.new(1, 0, 0, TITLE_H), BackgroundTransparency = 1,
    Active = true, ZIndex = 4}, win)

-- close button: sits at the right edge of the title bar, vertically centered
-- (it only moves left when the resize grip is in the top right corner)
local closeBtn = new("TextButton", {Name = "Close", AnchorPoint = Vector2.new(1, 0.5), Text = "", AutoButtonColor = false,
    BorderSizePixel = 0, ZIndex = 6}, win)
local closeCorner = new("UICorner", {}, closeBtn)
local xLines = {}
for n, rot in ipairs({45, -45}) do
    xLines[n] = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(12, 2), Rotation = rot, BorderSizePixel = 0, ZIndex = 7}, closeBtn)
end
local closeHover = false
local function styleClose()
    local cr = CORNERS[S.resize_corner] or CORNERS["Bottom right"]
    local gripSpace = (S.resize_on and cr[1] == 1 and cr[2] == 0) and ((isMobile and 34 or 24) + 4) or 0
    local sz = math.max(S.cb_size, 12)
    closeBtn.Size = UDim2.fromOffset(sz, sz)
    closeBtn.Position = UDim2.new(1, -(10 + gripSpace), 0, TITLE_H / 2)
    closeBtn.BackgroundColor3 = closeHover and col(S.cb_hover) or col(S.cb_bg)
    closeCorner.CornerRadius = UDim.new(0, math.min(S.cb_corner, math.floor(sz / 2)))
    local len = math.max(6, math.floor(sz * 0.46 / 2 + 0.5) * 2)
    for _, l in ipairs(xLines) do
        l.Size = UDim2.fromOffset(len, 2)
        l.BackgroundColor3 = col(S.cb_icon)
    end
end
closeBtn.Activated:Connect(function() win.Visible = false end)
if not isMobile then
    closeBtn.MouseEnter:Connect(function()
        closeHover = true
        closeBtn.BackgroundColor3 = col(S.cb_hover)
    end)
    closeBtn.MouseLeave:Connect(function()
        closeHover = false
        closeBtn.BackgroundColor3 = col(S.cb_bg)
    end)
end

-- pages and tabs (the tab order is changed here)
local TAB_ORDER = {"Combat", "Visual", "Player", "Teleport", "Theme", "Config"}
pages = {}
local tabBtns = {}
local compact = false

local function makePage(name)
    local sf = new("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = isMobile and 4 or 3, ScrollBarImageColor3 = "off", AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false}, content)
    new("UIPadding", {PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 14), PaddingRight = UDim.new(0, 8)}, sf)
    local grid = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1}, sf)
    local layouts = {new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, S.card_gap),
        SortOrder = Enum.SortOrder.LayoutOrder}, grid)}
    local cols = {}
    for i = 1, 2 do
        cols[i] = new("Frame", {Size = UDim2.new(0.5, -S.card_gap / 2, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, LayoutOrder = i}, grid)
        layouts[i + 1] = new("UIListLayout", {Padding = UDim.new(0, S.card_gap), SortOrder = Enum.SortOrder.LayoutOrder}, cols[i])
    end
    return {name = name, sf = sf, cols = cols, cards = {}, layouts = layouts}
end

function selectTab(name)
    openDrop = nil
    for n, pg in pairs(pages) do pg.sf.Visible = (n == name) end
    for n, t in pairs(tabBtns) do t.sel = (n == name) end
    pageTitle.Text = name
    applyTheme()
end

for i, name in ipairs(TAB_ORDER) do
    local b = new("TextButton", {Name = "Tab" .. name, Size = UDim2.new(1, 0, 0, TAB_H), BackgroundColor3 = "item",
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = i}, tabs)
    new("UICorner", {CornerRadius = UDim.new(0, 7)}, b)
    local bar = new("Frame", {Name = "Bar", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(3, 16), BorderSizePixel = 0, Visible = false}, b)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, bar)
    local ic, paintIcon = icon(name, b, UDim2.fromOffset(13, (TAB_H - 18) / 2))
    local lbl = text(b, name, {Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -40, 1, 0), TextSize = TS,
        TextColor3 = "dim"})
    tabBtns[name] = {btn = b, bar = bar, lbl = lbl, ic = ic, paint = paintIcon, sel = false}
    pages[name] = makePage(name)
    b.Activated:Connect(function() selectTab(name) end)
    if not isMobile then
        b.MouseEnter:Connect(function()
            if not tabBtns[name].sel then tween(b, {BackgroundTransparency = 0.8}, 0.1) end
        end)
        b.MouseLeave:Connect(function()
            if not tabBtns[name].sel then tween(b, {BackgroundTransparency = 1}, 0.1) end
        end)
    end
end

onTheme(function()
    local a = accent()
    for _, t in pairs(tabBtns) do
        t.bar.Visible = t.sel
        t.bar.BackgroundColor3 = a
        t.lbl.TextColor3 = t.sel and T.text or T.dim
        t.paint(t.sel and a or T.dim)
        t.btn.BackgroundTransparency = t.sel and 0.5 or 1
    end
end)

onTheme(function()
    local a = S.ui_accent
    local rich = string.format('Rag<font color="rgb(%d,%d,%d)">Ware</font>',
        math.floor(a[1] + 0.5), math.floor(a[2] + 0.5), math.floor(a[3] + 0.5))
    winStroke.Color = accent()
    winStroke.Thickness = S.ui_stroke
    winStroke.Transparency = S.ui_stroke_trans
    topLine.Visible = S.ui_topline
    winGrad.Enabled = S.ui_gradient
    logo.Text = rich
    miniLogo.Text = rich
    for _, c in ipairs(cornerObjs) do c[1].CornerRadius = UDim.new(0, math.max(S.ui_corner + c[2], 3)) end
    for _, p in ipairs(panelObjs) do p[1].BackgroundTransparency = math.clamp(S.ui_trans * p[2], 0, 1) end
    for _, d in ipairs(descObjs) do d.Visible = S.ui_desc end
    local f = curFont()
    for _, o in ipairs(textObjs) do o.Font = f end
    styleClose()
end)

-- layout: narrow window (phone in portrait, shrunk window) = no sidebar, tabs in a row at the top
local function setMode(w)
    local c = w < COMPACT_AT
    if c ~= compact then
        compact = c
        side.Visible = not c
        tabs.Parent = c and main or side
        tabLayout.FillDirection = c and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
        pageTitle.Visible = not c
        miniLogo.Visible = c
        for _, t in pairs(tabBtns) do
            t.btn.Size = c and UDim2.new(1 / #TAB_ORDER, -4, 1, 0) or UDim2.new(1, 0, 0, TAB_H)
            t.ic.Visible = not c
            t.lbl.Position = c and UDim2.fromOffset(0, 0) or UDim2.fromOffset(40, 0)
            t.lbl.Size = c and UDim2.fromScale(1, 1) or UDim2.new(1, -40, 1, 0)
            t.lbl.TextXAlignment = c and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
            t.lbl.TextSize = c and 11 or TS
            t.bar.AnchorPoint = c and Vector2.new(0.5, 1) or Vector2.new(0, 0.5)
            t.bar.Position = c and UDim2.fromScale(0.5, 1) or UDim2.fromScale(0, 0.5)
            t.bar.Size = c and UDim2.fromOffset(26, 3) or UDim2.fromOffset(3, 16)
        end
    end
    -- sizes that depend on the sidebar width (can change at any time)
    local sw = compact and 0 or SW()
    side.Size = UDim2.new(0, SW(), 1, 0)
    main.Position = UDim2.fromOffset(sw, 0)
    main.Size = UDim2.new(1, -sw, 1, 0)
    tabs.Position = compact and UDim2.fromOffset(14, TITLE_H) or UDim2.fromOffset(8, 64)
    tabs.Size = compact and UDim2.new(1, -28, 0, TAB_H) or UDim2.new(1, -16, 1, -120)
    content.Position = compact and UDim2.fromOffset(14, TITLE_H + TAB_H + 8) or UDim2.fromOffset(16, 48)
    content.Size = compact and UDim2.new(1, -28, 1, -(TITLE_H + TAB_H + 20)) or UDim2.new(1, -30, 1, -60)
end

-- columns: two side by side in a wide window, a single one in a narrow window
local lastNarrow = nil
local function setColumns(w, force)
    local narrow = (w - (compact and 0 or SW()) - 30) < NARROW_AT
    if narrow == lastNarrow and not force then return end
    lastNarrow = narrow
    local half = S.card_gap / 2
    for _, pg in pairs(pages) do
        pg.cols[1].Size = narrow and UDim2.new(1, 0, 0, 0) or UDim2.new(0.5, -half, 0, 0)
        pg.cols[2].Size = UDim2.new(0.5, -half, 0, 0)
        pg.cols[2].Visible = not narrow
        for _, c in ipairs(pg.cards) do
            c.frame.Parent = (narrow or c.col == 1) and pg.cols[1] or pg.cols[2]
        end
    end
end

-- how the cards look (Theme > Cards): transparency, corners, border, header style, padding, spacing, collapsed state
local lastGap = S.card_gap
onTheme(function()
    local a = accent()
    local p, hs = S.card_pad, S.card_header
    for _, c in ipairs(cardObjs) do
        local collapsed = S.card_collapse and S.card_collapsed[c.key] == true
        c.frame.BackgroundTransparency = S.card_trans
        c.corner.CornerRadius = UDim.new(0, S.card_corner)
        c.stroke.Color = S.card_stroke_accent and a or T.line
        c.stroke.Thickness = S.card_stroke
        c.stroke.Transparency = S.card_stroke_trans
        c.pad.PaddingTop = UDim.new(0, math.max(p - 2, 4))
        c.pad.PaddingBottom = UDim.new(0, math.max(p - 4, 4))
        c.pad.PaddingLeft = UDim.new(0, p)
        c.pad.PaddingRight = UDim.new(0, p)
        c.label.TextSize = math.max(S.card_title_size, 1)
        c.label.TextColor3 = (hs == "Accent text") and a or T.dim
        c.label.Position = UDim2.fromOffset(hs == "Accent bar" and 10 or 0, 0)
        c.label.Size = UDim2.new(1, hs == "Accent bar" and -30 or -20, 1, 0)
        c.bar.Visible = hs == "Accent bar"
        c.divider.Visible = S.card_divider and not collapsed
        c.divider.BackgroundColor3 = (hs == "Accent line") and a or T.line
        c.body.Visible = not collapsed
        c.chev.Visible = S.card_collapse
        c.chev.Rotation = collapsed and 0 or 180
    end
    for _, sp in ipairs(subObjs) do sp.BackgroundTransparency = S.sub_trans end
    local g = S.card_gap
    for _, pg in pairs(pages) do
        for _, l in ipairs(pg.layouts) do l.Padding = UDim.new(0, g) end
    end
    if g ~= lastGap then
        lastGap = g
        setColumns(win.Size.X.Offset, true)
    end
end)

local restyleButtons   -- defined with the floating buttons below

-- size of the GUI space the window lives in. Every position is a scale of THIS size, so all the maths uses it
-- (it falls back to the camera viewport until the ScreenGui has been laid out)
local function viewport()
    local a = gui.AbsoluteSize
    if a.X > 0 and a.Y > 0 then return a end
    local cam = Workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

-- window size / position (S.win_*), with limits and a UIScale shrink on small screens
function layout()
    local vp, s = viewport(), math.max(S.ui_scale, 0.3)   -- the menu never shrinks to nothing
    local fit = math.min(1, vp.X * MF / (MIN_W * s), vp.Y * 0.96 / (MIN_H * s))
    local sc = s * fit
    uiscale.Scale = sc
    local w = math.clamp(S.win_w, MIN_W, math.max(MIN_W, vp.X * MF / sc))
    local h = math.clamp(S.win_h, MIN_H, math.max(MIN_H, vp.Y * 0.96 / sc))
    win.Size = UDim2.fromOffset(w, h)
    local hw, hh = w * sc / 2, h * sc / 2
    local cx = math.clamp(S.win_cx * vp.X, hw, math.max(hw, vp.X - hw))
    local cy = math.clamp(S.win_cy * vp.Y, hh, math.max(hh, vp.Y - hh))
    win.Position = UDim2.fromScale(cx / vp.X, cy / vp.Y)
    setMode(w)
    setColumns(w)
    if restyleButtons then restyleButtons() end
end

conn(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() layout() end))

-- resize grip: the corner is chosen in Theme > Window
local grip = new("Frame", {Name = "Grip", BackgroundTransparency = 1, Active = true, ZIndex = 20}, win)
local gripLines = {}
for i = 1, 3 do
    gripLines[i] = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 21}, grip)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, gripLines[i])
end

function updateGrip()
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
    miniLogo.Position = UDim2.fromOffset(topLeft and 38 or 16, 0)
    styleClose()
end

----------------------------------------------------------------------------
-- dragging / resizing: one shared "drag" state.
-- Every position is worked out from the scale values we set ourselves (never from AbsolutePosition) and from
-- pointer deltas, so nothing depends on how the executor's GUI inset / viewport are reported. Resizing keeps the
-- edges opposite to the grip exactly where they are, which fixes the window jumping up when the grip was grabbed.
----------------------------------------------------------------------------
local drag = nil

-- center of an element in pixels, from its (scale based) Position
local function centerOf(tg)
    local vp = viewport()
    return Vector2.new(tg.Position.X.Scale * vp.X, tg.Position.Y.Scale * vp.Y)
end

-- pointer position from ONE source for the whole drag: touches use their own position, the mouse uses GetMouseLocation
-- (so a click event and the following move events can never disagree about the coordinate space)
local function pointerPos(i)
    if i.UserInputType == Enum.UserInputType.Touch then return Vector2.new(i.Position.X, i.Position.Y) end
    return UIS:GetMouseLocation()
end

local function beginDrag(kind, i, extra)
    drag = extra or {}
    drag.kind = kind
    drag.input = i
    drag.start = pointerPos(i)
    drag.moved = false
end

dragBar.InputBegan:Connect(function(i)
    if pointerDown(i) then beginDrag("move", i, {target = win, center = centerOf(win)}) end
end)

grip.InputBegan:Connect(function(i)
    if not pointerDown(i) then return end
    local c = centerOf(win)
    local sc = uiscale.Scale
    local w, h = win.Size.X.Offset, win.Size.Y.Offset
    local cr = CORNERS[S.resize_corner] or CORNERS["Bottom right"]
    beginDrag("resize", i, {
        corner = cr, w = w, h = h, sc = sc,
        fx = (cr[1] == 1) and (c.X - w * sc / 2) or (c.X + w * sc / 2),   -- fixed vertical edge (x)
        fy = (cr[2] == 1) and (c.Y - h * sc / 2) or (c.Y + h * sc / 2),   -- fixed horizontal edge (y)
    })
end)

conn(UIS.InputChanged:Connect(function(i)
    if not drag then return end
    local t = i.UserInputType
    if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
    if t == Enum.UserInputType.Touch and drag.input.UserInputType == Enum.UserInputType.Touch and i ~= drag.input then
        return
    end
    if drag.noMove then return end   -- a locked button only does its tap / hold action
    local vp = viewport()
    local pos = pointerPos(i)
    if not drag.moved then
        if (pos - drag.start).Magnitude <= 6 then return end
        drag.moved = true
        drag.start = pos   -- measure from here, so nothing jumps when the threshold is crossed
        if drag.onMoveStart then drag.onMoveStart() end
    end
    local d = pos - drag.start

    if drag.kind == "resize" then
        local sc = drag.sc
        local right, bottom = drag.corner[1] == 1, drag.corner[2] == 1
        local maxW = right and (vp.X - drag.fx) or drag.fx
        local maxH = bottom and (vp.Y - drag.fy) or drag.fy
        local nw = drag.w + (right and d.X or -d.X) / sc
        local nh = drag.h + (bottom and d.Y or -d.Y) / sc
        nw = math.clamp(nw, MIN_W, math.max(MIN_W, math.min(1100, maxW / sc)))
        nh = math.clamp(nh, MIN_H, math.max(MIN_H, math.min(800, maxH / sc)))
        local cx = right and (drag.fx + nw * sc / 2) or (drag.fx - nw * sc / 2)
        local cy = bottom and (drag.fy + nh * sc / 2) or (drag.fy - nh * sc / 2)
        win.Size = UDim2.fromOffset(nw, nh)
        win.Position = UDim2.fromScale(cx / vp.X, cy / vp.Y)
        S.win_w, S.win_h, S.win_cx, S.win_cy = nw, nh, cx / vp.X, cy / vp.Y
        setMode(nw)
        setColumns(nw)
    elseif drag.kind == "hud" then
        -- a button of the main GUI is being moved
        local h = drag.hud
        local hw, hh = h.btn.AbsoluteSize.X / 2, h.btn.AbsoluteSize.Y / 2
        local p = drag.center + d
        local cx = math.clamp(p.X, hw, math.max(hw, vp.X - hw))
        local cy = math.clamp(p.Y, hh, math.max(hh, vp.Y - hh))
        h.btn.Position = UDim2.fromScale(cx / vp.X, cy / vp.Y)
        drag.hudSetPos(h.def, cx / vp.X, cy / vp.Y)
    elseif drag.kind == "hudsize" then
        -- a button of the main GUI is being resized with its corner handle
        local h = drag.hud
        S[h.def.k.size] = math.clamp(math.floor(drag.size0 + d.X + d.Y + 0.5), 20, 220)
        drag.hudRestyle(h)
    else
        -- the window, by its title bar
        local tg = drag.target
        local hw, hh = tg.AbsoluteSize.X / 2, tg.AbsoluteSize.Y / 2
        local p = drag.center + d
        local cx = math.clamp(p.X, hw, math.max(hw, vp.X - hw))
        local cy = math.clamp(p.Y, hh, math.max(hh, vp.Y - hh))
        tg.Position = UDim2.fromScale(cx / vp.X, cy / vp.Y)
        S.win_cx, S.win_cy = cx / vp.X, cy / vp.Y
    end
end))

conn(UIS.InputEnded:Connect(function(i)
    if drag and pointerDown(i) then
        local d = drag
        drag = nil
        if d.onEnd then pcall(d.onEnd, d.moved) end
        if not d.moved and d.onTap then d.onTap() end
        -- the typed boxes of the Theme tab show the new position / size
        if d.moved and (d.kind == "hud" or d.kind == "hudsize") then refreshAll() end
    end
end))

----------------------------------------------------------------------------
-- HUD buttons: every button of the main GUI (open / close, AIM, quick buttons, tap point).
-- An unlocked button can be dragged (a tap still does its action) and resized with the corner handle that shows
-- up on it. Locked buttons (each one, or all of them) only do their action.
-- Look, size, position and lock are theme settings (Theme tab).
----------------------------------------------------------------------------
local function shapeRadius(shape, size)
    if shape == "Circle" then return UDim.new(1, 0) end
    if shape == "Square" then return UDim.new(0, 0) end
    return UDim.new(0, math.max(4, math.floor(size * 0.22)))
end

local hudList, HUD = {}, {}   -- every button in creation order / by id

local function hudLocked(d) return S.hud_lock_all or S[d.k.lock] end

-- position in fractions of the screen (the AIM button stores percent)
local function hudPos(d)
    local fx, fy = S[d.k.x], S[d.k.y]
    if d.pct then return fx / 100, fy / 100 end
    return fx, fy
end

local function hudSetPos(d, fx, fy)
    if d.pct then
        S[d.k.x], S[d.k.y] = fx * 100, fy * 100
    else
        S[d.k.x], S[d.k.y] = fx, fy
    end
end

local function hudDims(d)
    local w = math.clamp(S[d.k.size], 16, 400)
    return w, math.max(math.floor(w * S[d.k.ratio] + 0.5), 12)
end

-- colors, visibility and whether the corner handle is shown
local function hudPaint(h)
    local d = h.def
    local a = accent()
    h.stroke.Color = S[d.k.acc] and a or col(S[d.k.sc])
    if d.paint then
        d.paint(h, a)
    else
        local bg, tc = d.colors(h.active, a)
        h.btn.BackgroundColor3 = bg
        h.btn.TextColor3 = tc
    end
    local vis = (d.visible and d.visible()) or h.show
    local locked = hudLocked(d)
    h.btn.Visible = vis and true or false
    h.handle.Visible = vis and not locked
    if d.marker then
        -- a locked marker lets touches through to the game, an unlocked one can be grabbed
        h.btn.Active = not locked
        h.handle.Active = not locked
    end
end

-- size, position, shape and text (everything that is not a state color)
local function hudRestyle(h)
    local d = h.def
    local k = d.k
    local vp = viewport()
    local w, ht = hudDims(d)
    local fx, fy = hudPos(d)
    -- keep the button on the screen
    fx = math.clamp(fx, math.min(w / 2 / vp.X, 0.5), math.max(1 - w / 2 / vp.X, 0.5))
    fy = math.clamp(fy, math.min(ht / 2 / vp.Y, 0.5), math.max(1 - ht / 2 / vp.Y, 0.5))
    hudSetPos(d, fx, fy)
    h.btn.Size = UDim2.fromOffset(w, ht)
    if not (drag and drag.kind == "hud" and drag.hud == h) then h.btn.Position = UDim2.fromScale(fx, fy) end
    h.corner.CornerRadius = shapeRadius(S[k.shape], math.min(w, ht))
    h.btn.BackgroundTransparency = S[k.trans]
    h.stroke.Thickness = S[k.st]
    h.label.Text = S[k.text]
    h.label.TextSize = math.max(S[k.ts], 1)
    local hs = math.clamp(math.floor(math.min(w, ht) * 0.4), 12, 22)
    h.handle.Size = UDim2.fromOffset(hs, hs)
    hudPaint(h)
end

local function makeHud(d)
    local h = {def = d, active = false, show = false}
    if d.marker then
        -- the tap point: a plain frame (so Active decides whether it catches touches)
        h.btn = new("Frame", {Name = d.name, AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false}, gui)
        h.label = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center}, h.btn)
        h.dot = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0}, h.btn)
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, h.dot)
    else
        h.btn = new("TextButton", {Name = d.name, AnchorPoint = Vector2.new(0.5, 0.5), Text = "", Font = Enum.Font.GothamBold,
            AutoButtonColor = false, BorderSizePixel = 0, Visible = false}, gui)
        h.label = h.btn
    end
    h.corner = new("UICorner", {}, h.btn)
    -- Border: on a TextButton the default stroke mode would outline the text instead of the button
    h.stroke = new("UIStroke", {ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, h.btn)
    -- corner handle (only on unlocked buttons)
    h.handle = new("Frame", {Name = "ResizeHandle", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 4, 1, 4),
        BackgroundColor3 = "accent", BackgroundTransparency = 0.15, BorderSizePixel = 0, Visible = false, Active = true,
        ZIndex = 5}, h.btn)
    new("UICorner", {CornerRadius = UDim.new(0, 5)}, h.handle)
    new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.7, 0, 0, 2),
        Rotation = -45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 6}, h.handle)

    h.btn.InputBegan:Connect(function(i)
        if not pointerDown(i) then return end
        if drag and drag.input and drag.input.UserInputState ~= Enum.UserInputState.End then return end
        if d.onDown then d.onDown(i) end
        beginDrag("hud", i, {hud = h, center = centerOf(h.btn), noMove = hudLocked(d), onTap = d.onTap, onEnd = d.onUp,
            onMoveStart = d.onMoveStart, hudSetPos = hudSetPos})
    end)
    h.handle.InputBegan:Connect(function(i)
        if not pointerDown(i) or hudLocked(d) then return end
        beginDrag("hudsize", i, {hud = h, size0 = S[d.k.size], hudRestyle = hudRestyle})
    end)
    hudList[#hudList + 1] = h
    HUD[d.id] = h
    return h
end

-- open / close
makeHud({id = "open", name = "RagWareToggle", pct = false,
    k = {x = "fb_x", y = "fb_y", size = "fb_size", ratio = "fb_ratio", lock = "fb_lock", shape = "fb_shape", text = "fb_text",
         ts = "fb_textsize", trans = "fb_trans", acc = "fb_accent", sc = "fb_strokec", st = "fb_stroke"},
    -- on a touch device a hidden menu always keeps its open button, so you can never lock yourself out
    visible = function() return S.ui_btn or (isMobile and not win.Visible) or S.hud_preview end,
    colors = function(_, a) return col(S.fb_bg), S.fb_accent and a or col(S.fb_textc) end,
    onTap = function() win.Visible = not win.Visible end})

-- AIM (touch): hold to aim, or tap to toggle. Dragging it (when unlocked) never leaves the aim stuck on.
makeHud({id = "aim", name = "RagWareAim", pct = true,
    k = {x = "aim_btn_x", y = "aim_btn_y", size = "aim_btn_size", ratio = "ab_ratio", lock = "ab_lock", shape = "ab_shape",
         text = "ab_text", ts = "ab_textsize", trans = "ab_trans", acc = "ab_accent", sc = "ab_strokec", st = "ab_stroke"},
    colors = function(active, a)
        local ac = S.ab_accent and a or col(S.ab_strokec)
        if active then return ac, T.bg end
        return col(S.ab_bg), S.ab_accent and T.text or col(S.ab_textc)
    end,
    onDown = function() if S.aim_mode ~= "Toggle" then aimHeld = true end end,
    onTap = function()
        if S.aim_mode == "Toggle" then
            S.aimbot = not S.aimbot   -- Toggle mode: the button flips the aimbot switch itself
            refreshAll()
        end
    end,
    onUp = function() aimHeld = false end,
    onMoveStart = function() aimHeld = false end})

-- quick buttons: triggerbot, spinbot, third person and bunny hop without opening the menu. Each flag is in Config > Mobile.
for _, q in ipairs(QUICK) do
    local pre = "qb_" .. q[1] .. "_"
    makeHud({id = q[1], name = "RagWareQuick" .. q[2], pct = false,
        k = {x = pre .. "x", y = pre .. "y", size = pre .. "size", ratio = pre .. "ratio", lock = pre .. "lock",
             shape = "qb_shape", text = pre .. "text", ts = "qb_textsize", trans = "qb_trans", acc = "qb_accent",
             sc = "qb_strokec", st = "qb_stroke"},
        visible = function() return (S.qb_on and S["qb_" .. q[1]]) or S.hud_preview end,
        state = function() return S[q[3]] end,
        colors = function(active, a)
            if active then return a, T.bg end
            return col(S.qb_btn), col(S.qb_textc)
        end,
        onTap = function()
            S[q[3]] = not S[q[3]]
            refreshAll()
        end})
end

-- tap point: the marker the triggerbot taps (Screen tap fire method). Drag it onto the game's fire button, then lock it.
makeHud({id = "tap", name = "RagWareTapPoint", pct = false, marker = true,
    k = {x = "tap_x", y = "tap_y", size = "tap_size", ratio = "tap_ratio", lock = "tap_lock", shape = "tap_shape",
         text = "tap_text", ts = "tap_textsize", trans = "tap_trans", acc = "tap_accent", sc = "tap_strokec", st = "tap_stroke"},
    visible = function()
        if S.hud_preview then return true end
        if S.tap_vis == "Hidden" or S.fire_method ~= "Screen tap" then return false end
        if S.tap_vis == "While unlocked" and (S.hud_lock_all or S.tap_lock) then return false end
        return true
    end,
    paint = function(h, a)
        local follow = S.tap_accent
        h.btn.BackgroundColor3 = follow and a or col(S.tap_fill)
        h.label.TextColor3 = col(S.tap_textc)
        h.dot.BackgroundColor3 = follow and a or col(S.tap_strokec)
        h.dot.Visible = (S.tap_text == "")   -- a dot marks the exact point when there is no label
    end})

-- screen position the triggerbot taps, and a switch that makes the (unlocked) marker let a tap through
TR.tapPos = function()
    local vp = viewport()
    return Vector2.new(S.tap_x * vp.X, S.tap_y * vp.Y)
end
TR.tapBusy = function(on)
    local h = HUD.tap
    if h and not hudLocked(h.def) then
        h.btn.Active = not on
        h.handle.Active = not on
    end
end

-- AIM button: called every frame by the render loop
function updateAim(show, active)
    local h = HUD.aim
    h.show = show or S.hud_preview
    h.active = active
    hudPaint(h)
end

-- also called every ~0.15 s by the render loop (keeps the quick buttons in sync with the toggles)
function updateQuick()
    for _, h in ipairs(hudList) do
        if h.def.state then h.active = h.def.state() and true or false end
        if h.def.id ~= "aim" then hudPaint(h) end
    end
end

function restyleButtons()
    for _, h in ipairs(hudList) do hudRestyle(h) end
end

onTheme(updateGrip)
onTheme(restyleButtons)
end   -- end of the window block

----------------------------------------------------------------------------
-- pages
----------------------------------------------------------------------------
Loader.mark("Building the menu")
local trigStatus   -- used by the logic outside of this block
do
local text, nextOrder, stack, newRow = W.text, W.nextOrder, W.stack, W.newRow
local Toggle, Feature, Slider, SK = W.Toggle, W.Feature, W.Slider, W.SK
local Dropdown, DK, MultiSelect, Keybind = W.Dropdown, W.DK, W.MultiSelect, W.Keybind
local ColorRow, ColorRowG, Button, Input, StatusRow, Card = W.ColorRow, W.ColorRowG, W.Button, W.Input, W.StatusRow, W.Card
local ctl = W.ctl
local card, sb   -- current card / settings panel (sub) of the current feature

local SHAPES = {"Circle", "Rounded", "Square"}

-- helpers built from the toolkit ---------------------------------------------
local function Heading(parent, str)
    local r = newRow(parent, 24)
    text(r, str, {Size = UDim2.new(1, 0, 0, 24), TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = "dim"})
    return r
end

-- button that needs a second click within 3 seconds (for destructive actions)
local function ConfirmButton(parent, label, cb)
    local b
    local armed = false
    b = Button(parent, label, function()
        if armed then
            armed = false
            b.Text = label
            cb()
            return
        end
        armed = true
        b.Text = "Click again to confirm"
        task.delay(3, function()
            if armed then
                armed = false
                b.Text = label
            end
        end)
    end)
    return b
end

-- text box bound to a string setting
local function TextK(parent, label, key, cb, maxLen, hint)
    local tb = Input(parent, label, tostring(S[key]), hint)
    tb.FocusLost:Connect(function()
        local v = tb.Text
        if maxLen then v = v:sub(1, maxLen) end
        S[key] = v
        tb.Text = v
        if cb then cb(v) end
    end)
    refreshers[#refreshers + 1] = function() tb.Text = tostring(S[key]) end
    return tb
end

local function checkItems(pre)
    local items = {}
    for _, c in ipairs(CHECKS) do items[#items + 1] = {CK[pre][c[1]], c[2]} end
    return items
end

-- search box + one row per player, each row with buttons.
-- pills = {{label, state(e) -> bool (optional), onColor() -> Color3, onBg() -> Color3, click(e)}}
-- withLeft = also list players that are saved in the ignore / target lists but left the server
-- source (optional) = {entries = function() -> list of {id, name, display, here}, signals = {...}, empty = text, gone = text}
--   makes the list show something else, like teams
local function PlayerList(parent, pills, withLeft, source)
    local holder = stack(parent, 4)
    local search = new("TextBox", {Name = "Search", Size = UDim2.new(1, 0, 0, RH - 2), BackgroundColor3 = "item",
        BorderSizePixel = 0, Text = "", PlaceholderText = "Search players", PlaceholderColor3 = "dim",
        TextColor3 = "text", TextSize = 12, Font = curFont(), ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1}, holder)
    ctl(search)
    new("UIPadding", {PaddingLeft = UDim.new(0, 10)}, search)
    textObjs[#textObjs + 1] = search
    local box = new("Frame", {Name = "PlayerRows", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = 2}, holder)
    new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, box)
    local empty = text(holder, (source and source.empty) or "No players found", {Size = UDim2.new(1, 0, 0, RH), TextSize = 12, TextColor3 = "dim",
        TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Visible = false})

    local rows = {}   -- {e = entry, btns = {...}}

    local function paint(b, spec, e)
        if spec.state then
            local on = spec.state(e)
            b.TextColor3 = on and spec.onColor() or T.dim
            b.BackgroundColor3 = on and spec.onBg() or T.sub
        else
            b.TextColor3 = spec.onColor()
            b.BackgroundColor3 = spec.onBg()
        end
    end
    local function repaint()
        for _, r in ipairs(rows) do
            for n, spec in ipairs(pills) do paint(r.btns[n], spec, r.e) end
        end
    end
    -- players of the server (+ whoever is saved in the lists but left)
    local function entries()
        local out, seen = {}, {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                seen[p.UserId] = true
                out[#out + 1] = {id = p.UserId, name = p.Name, display = p.DisplayName, here = true}
            end
        end
        if withLeft then
            for _, key in ipairs({"ignore_list", "target_list"}) do
                for _, e in ipairs(S[key]) do
                    local id = listId(e)
                    local nm = tostring(e):match("^%d+:(.*)$") or "?"
                    if id and not seen[id] then
                        seen[id] = true
                        out[#out + 1] = {id = id, name = nm, display = nm, here = false}
                    end
                end
            end
        end
        table.sort(out, function(a, b) return a.display:lower() < b.display:lower() end)
        return out
    end
    local function rebuild()
        for _, c in ipairs(box:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        rows = {}
        local q = search.Text:lower()
        local n = 0
        local pw = isMobile and 58 or 52
        local taken = (pw + 4) * #pills + 14
        for _, e in ipairs((source and source.entries or entries)()) do
            if q == "" or e.display:lower():find(q, 1, true) or e.name:lower():find(q, 1, true) then
                n = n + 1
                local row = new("Frame", {Name = "PlayerRow", Size = UDim2.new(1, 0, 0, RH + 2),
                    BackgroundColor3 = "item", BorderSizePixel = 0, LayoutOrder = n}, box)
                new("UICorner", {CornerRadius = UDim.new(0, 6)}, row)
                text(row, e.display .. (e.here and "" or ((source and source.gone) or " (left)")), {Position = UDim2.fromOffset(10, 0),
                    Size = UDim2.new(1, -(taken + 10), 1, 0), TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
                    TextColor3 = e.here and "text" or "dim"})
                local btns = {}
                for k, spec in ipairs(pills) do
                    local b = new("TextButton", {Name = spec.label, AnchorPoint = Vector2.new(1, 0.5),
                        Position = UDim2.new(1, -6 - (#pills - k) * (pw + 4), 0.5, 0),
                        Size = UDim2.fromOffset(pw, RH - 8), BackgroundColor3 = "sub", BorderSizePixel = 0,
                        Text = spec.label, TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = "dim",
                        AutoButtonColor = false}, row)
                    ctl(b, true)
                    b.Activated:Connect(function()
                        spec.click(e)
                        repaint()
                    end)
                    btns[k] = b
                end
                rows[#rows + 1] = {e = e, btns = btns}
            end
        end
        empty.Visible = (n == 0)
        repaint()
    end
    search:GetPropertyChangedSignal("Text"):Connect(rebuild)
    local pending = false
    local function schedule()
        if pending then return end
        pending = true
        task.delay(0.15, function()
            pending = false
            rebuild()
        end)
    end
    conn(Players.PlayerAdded:Connect(schedule))
    conn(Players.PlayerRemoving:Connect(schedule))
    for _, sg in ipairs(source and source.signals or {}) do conn(sg:Connect(schedule)) end
    refreshers[#refreshers + 1] = rebuild
    onTheme(repaint)
    rebuild()
    return rebuild
end

-- saved configs / themes: save new, overwrite, load, rename, delete, autoload
local function Manager(parent, kind)
    local isTheme = kind == "theme"
    local nameBox = Input(parent, "Name", isTheme and "my theme" or "default", kind .. " name")
    local names, sel = {}, 0
    local statusLbl, autoLbl, savedRefresh

    local function setStatus(m) if statusLbl then statusLbl.Text = m end end
    local function refreshAuto()
        local a = ST.auto(kind)
        if autoLbl then autoLbl.Text = (a ~= "") and a or "none" end
    end
    local function refreshList(pick)
        names = {}
        if isTheme then
            for _, b in ipairs(ST.builtin) do names[#names + 1] = b[1] end
        end
        for _, n in ipairs(ST.names(kind)) do
            if not (isTheme and ST.isBuiltin(n)) then names[#names + 1] = n end
        end
        sel = 0
        if pick then
            for i, n in ipairs(names) do
                if n == pick then sel = i end
            end
        end
        if sel == 0 and #names > 0 then sel = 1 end
        if savedRefresh then savedRefresh() end
    end

    local _
    _, savedRefresh = Dropdown(parent, "Saved", function() return names[sel] or "(none)" end, function(v)
        for i, n in ipairs(names) do
            if n == v then sel = i end
        end
        nameBox.Text = v
    end, function() return names end)

    Button(parent, "Save new", function()
        local n = ST.clean(nameBox.Text)
        if n == "" then return setStatus("type a name first") end
        for _, x in ipairs(names) do
            if x:lower() == n:lower() then return setStatus("already exists: use Overwrite or pick another name") end
        end
        local ok, res = ST.save(kind, n)
        if ok then
            refreshList(res)
            setStatus("saved: " .. res)
        else
            setStatus("error: " .. tostring(res))
        end
    end)
    ConfirmButton(parent, "Overwrite selected", function()
        local n = names[sel]
        if not n then return setStatus("nothing selected") end
        if isTheme and ST.isBuiltin(n) then return setStatus("built-in themes are read-only") end
        local ok, res = ST.save(kind, n)
        setStatus(ok and ("overwritten: " .. n) or ("error: " .. tostring(res)))
    end)
    Button(parent, "Load selected", function()
        local n = names[sel]
        if not n then return setStatus("nothing selected") end
        local ok, err = ST.load(kind, n)
        if ok then
            refreshAll()
            layout()
            nameBox.Text = n
            setStatus("loaded: " .. n)
        else
            setStatus("error: " .. tostring(err))
        end
    end)
    Button(parent, "Rename selected", function()
        local n = names[sel]
        if not n then return setStatus("nothing selected") end
        if isTheme and ST.isBuiltin(n) then return setStatus("built-in themes are read-only") end
        local ok, res = ST.rename(kind, n, nameBox.Text)
        if ok then
            refreshList(res)
            refreshAuto()
            setStatus("renamed to: " .. res)
        else
            setStatus("error: " .. tostring(res))
        end
    end)
    ConfirmButton(parent, "Delete selected", function()
        local n = names[sel]
        if not n then return setStatus("nothing selected") end
        if isTheme and ST.isBuiltin(n) then return setStatus("built-in themes can't be deleted") end
        local ok, err = ST.del(ST.path(kind, n))
        if ok then
            if ST.auto(kind) == n then ST.setAuto(kind, "") end
            refreshList()
            refreshAuto()
            setStatus("deleted: " .. n)
        else
            setStatus("error: " .. tostring(err))
        end
    end)
    Button(parent, "Autoload selected on start", function()
        local n = names[sel]
        if not ST.fs then return setStatus("autoload needs writefile") end
        if not n then return setStatus("select one first") end
        local ok, err = ST.setAuto(kind, n)
        refreshAuto()
        setStatus(ok and ("autoload: " .. n) or ("error: " .. tostring(err)))
    end)
    Button(parent, "Disable autoload", function()
        ST.setAuto(kind, "")
        refreshAuto()
        setStatus("autoload disabled")
    end)
    ConfirmButton(parent, isTheme and "Reset to Black theme" or "Reset to defaults", function()
        if isTheme then ST.resetTheme() else ST.resetConfig() end
        refreshAll()
        layout()
        setStatus(isTheme and "theme reset" or "defaults restored")
    end)
    autoLbl = StatusRow(parent, "Autoload")
    statusLbl = text(parent, "", {Size = UDim2.new(1, 0, 0, 18), TextSize = 11, TextColor3 = "dim",
        TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = nextOrder(parent)})
    refreshList()
    refreshAuto()
end

-- Combat ------------------------------------------------------------------
local PC = pages.Combat

card = Card(PC, "Aimbot", 1)
sb = Feature(card, "Aimbot", "aimbot")
DK(sb, "Mode", "aim_mode", {"Hold", "Toggle", "Always"}, nil,
    "Toggle: the aim key (or the AIM button) switches the aimbot itself on and off, so the menu switch and the FOV circle follow it")
if not isMobile then Keybind(sb, "Key", "aim_key") end
DK(sb, "Method", "aim_method", {"Camera", "Mouse"}, nil, "Mouse needs an executor (mousemoverel)")
DK(sb, "Hitbox", "aim_part", {"Head", "Torso", "Root", "Closest"})
DK(sb, "Priority", "aim_priority", {"Crosshair", "Distance", "Health"})
SK(sb, "Smooth", "smooth", 0, 99, 1, "%", nil, "0% snaps instantly")
SK(sb, "Max distance", "aim_maxdist", 0, 5000, 50, " st")
MultiSelect(sb, "Filters", checkItems("aim"), "Targets that fail an enabled filter are skipped by the aimbot")
sb = Feature(card, "Humanizer", "humanize", {desc = "Human-like imperfections in the aim"})
SK(sb, "Noise", "human_noise", 0, 5, 0.1, " deg", nil, "Smooth wander around the target")
SK(sb, "Offset", "human_offset", 0, 2, 0.1, " st", nil, "Random aim point inside the hitbox")
SK(sb, "Reaction delay", "human_delay", 0, 500, 10, " ms", nil, "Waits before engaging a new target")
SK(sb, "Speed variation", "human_speed", 0, 60, 1, "%")
sb = Feature(card, "Show FOV", "show_fov")
SK(sb, "Size", "aim_fov", 0, 800, 5, " px")
DK(sb, "Origin", "fov_origin", {"Mouse", "Center"})
ColorRow(sb, "Color", "fov_color")
SK(sb, "Thickness", "fov_thick", 0, 4, 0.5, "")
Toggle(card, "Fullscreen", "fov_fullscreen", nil, "No FOV limit, the circle is hidden")

-- player lists (moved here from the old Targets tab)
local ignCount, tgtCount, ignTeamCount, tgtTeamCount
local function updateCounts()
    if ignCount then ignCount.Text = tostring(LIST.count("ignore_list")) end
    if tgtCount then tgtCount.Text = tostring(LIST.count("target_list")) end
    if ignTeamCount then ignTeamCount.Text = tostring(LIST.count("ignore_teams")) end
    if tgtTeamCount then tgtTeamCount.Text = tostring(LIST.count("target_teams")) end
end
refreshers[#refreshers + 1] = updateCounts

card = Card(PC, "Lists", 1)
sb = Feature(card, "Ignore list", "ignore_on", {desc = "Ignored players are never aimed at or triggered on"})
Toggle(sb, "Hide from ESP and chams", "ignore_esp")
ignCount = StatusRow(sb, "Entries")
Button(sb, "Clear ignore list", function()
    LIST.clear("ignore_list")
    refreshAll()
end)
sb = Feature(card, "Target list", nil, {desc = "Focus on specific players (and teams, see Target teams)"})
DK(sb, "Mode", "target_mode", {"Off", "Only", "Priority"}, nil,
    "Only = ignore everyone else, Priority = prefer these players when several are in range")
ColorRow(sb, "Color", "esp_target_color", nil, "ESP and chams color for target players and teams")
tgtCount = StatusRow(sb, "Entries")
Button(sb, "Clear target list", function()
    LIST.clear("target_list")
    refreshAll()
end)
sb = Feature(card, "Ignore teams", "ignore_teams_on", {desc = "Players of an ignored team are never aimed at or triggered on. Pick teams in the Teams card"})
Toggle(sb, "Hide from ESP and chams", "ignore_teams_esp")
ignTeamCount = StatusRow(sb, "Entries")
Button(sb, "Clear ignored teams", function()
    LIST.clear("ignore_teams")
    refreshAll()
end)
sb = Feature(card, "Target teams", nil, {desc = "Focus on whole teams. Uses the Mode and the color of the Target list"})
tgtTeamCount = StatusRow(sb, "Entries")
Button(sb, "Clear target teams", function()
    LIST.clear("target_teams")
    refreshAll()
end)
updateCounts()

card = Card(PC, "Triggerbot", 2)
sb = Feature(card, "Triggerbot", "trigger")
DK(sb, "Hitbox", "trigger_part", {"Any", "Head", "Body"})
DK(sb, "Fire mode", "trigger_mode", {"Click", "Hold"})
DK(sb, "Fire method", "fire_method", {"Auto", "Executor", "VirtualInput", "Tool", "Screen tap"}, nil,
    "Auto tries executor input, VirtualInput, then the held Tool. Screen tap touches the tap point you place on the screen (mobile)")
SK(sb, "Reaction delay", "trigger_delay", 0, 500, 5, " ms")
SK(sb, "Click interval", "trigger_interval", 0, 600, 10, " ms")
SK(sb, "Range", "trigger_range", 0, 3000, 50, " st")
SK(sb, "Tolerance", "trigger_radius", 0, 30, 1, " px", nil, "Pixels around the crosshair that count as a hit")
Toggle(sb, "Only while aiming", "trigger_aimkey")
MultiSelect(sb, "Filters", checkItems("trig"), "Same filters as the aimbot, set separately. Wall off = fires through walls")
Heading(sb, "Screen tap (mobile)")
DK(sb, "Tap method", "tap_method", {"Auto", "Touch", "Mouse"}, nil,
    "Touch sends a real touch at the tap point, Mouse sends a click there. Auto tries touch first")
SK(sb, "Tap hold", "tap_hold", 0, 300, 5, " ms", nil, "How long each tap is held down")
SK(sb, "Tap spread", "tap_jitter", 0, 30, 1, " px", nil, "Random offset around the tap point")
Toggle(sb, "Lock tap point", "tap_lock", applyTheme, "Drag the marker onto the game's fire button, then lock it. Look and size: Theme > Tap point")
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
SK(sb, "Speed", "spin_speed", 0, 3600, 10, " deg/s")
Toggle(sb, "Reverse", "spin_reverse")
SK(sb, "Jitter angle", "spin_jitter", 0, 180, 5, " deg")
SK(sb, "Jitter rate", "spin_rate", 0, 60, 1, " Hz")
Toggle(sb, "Pause while shooting", "spin_pause", nil, "Stops spinning when you click or the triggerbot fires")
SK(sb, "Resume delay", "spin_resume", 0, 600, 10, " ms")
Toggle(sb, "Face aim while shooting", "spin_face", nil, "Turns the body toward the camera so shots go straight")

-- the teams of the game: ignore / target a whole team, and choose whether your own team is ignored
local function teamEntries()
    local out, seen = {}, {}
    for _, tm in ipairs(Teams:GetTeams()) do
        seen[tm.Name] = true
        out[#out + 1] = {id = tm.Name, name = tm.Name, display = tm.Name .. ((LP.Team == tm) and " (you)" or ""), here = true}
    end
    -- teams that are saved in the lists but do not exist in this game
    for _, key in ipairs({"ignore_teams", "target_teams"}) do
        for _, name in ipairs(S[key]) do
            if not seen[name] then
                seen[name] = true
                out[#out + 1] = {id = name, name = name, display = name, here = false}
            end
        end
    end
    table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
    return out
end

card = Card(PC, "Teams", 2)
Toggle(card, "Ignore my team", "team_ignore_mine", nil,
    "Off = your teammates can be aimed at and triggered on, whatever the Team filters say. On = the Team filters decide")
PlayerList(card, {
    {label = "Ignore", state = function(e) return LIST.has("ignore_teams", e.id) end,
     onColor = function() return Color3.fromRGB(255, 110, 110) end,
     onBg = function() return Color3.fromRGB(56, 26, 32) end,
     click = function(e)
         LIST.toggleTeam("ignore_teams", e.id)
         updateCounts()
     end},
    {label = "Target", state = function(e) return LIST.has("target_teams", e.id) end,
     onColor = accent, onBg = function() return T.sub:Lerp(accent(), 0.25) end,
     click = function(e)
         LIST.toggleTeam("target_teams", e.id)
         updateCounts()
     end},
}, false, {entries = teamEntries, signals = {Teams.ChildAdded, Teams.ChildRemoved, LP:GetPropertyChangedSignal("Team")},
    empty = "This game has no teams", gone = " (not here)"})

card = Card(PC, "Players", 2)
PlayerList(card, {
    {label = "Ignore", state = function(e) return LIST.has("ignore_list", e.id) end,
     onColor = function() return Color3.fromRGB(255, 110, 110) end,
     onBg = function() return Color3.fromRGB(56, 26, 32) end,
     click = function(e)
         LIST.toggle("ignore_list", e.id, e.name)
         updateCounts()
     end},
    {label = "Target", state = function(e) return LIST.has("target_list", e.id) end,
     onColor = accent, onBg = function() return T.sub:Lerp(accent(), 0.25) end,
     click = function(e)
         LIST.toggle("target_list", e.id, e.name)
         updateCounts()
     end},
}, true)

-- Visual ------------------------------------------------------------------
local PV = pages.Visual

card = Card(PV, "ESP", 1)
local COLOR_MODES = {"Player color", "Custom"}
local FONTS = {"GothamMedium", "GothamBold", "Gotham", "Ubuntu", "SourceSans", "Arial", "Code"}
local COLOR_DESC = "Player color = the team color (or the target color). Custom uses the color below"

sb = Feature(card, "Box", "esp_box", {desc = "Rectangle around every player"})
DK(sb, "Style", "box_style", {"Full", "Corners"})
SK(sb, "Corner length", "box_corner", 0, 50, 1, "%", nil, "Length of each corner line (Corners style)")
DK(sb, "Color", "box_color_mode", COLOR_MODES, nil, COLOR_DESC)
ColorRow(sb, "Custom color", "box_color")
SK(sb, "Thickness", "box_thick", 0, 6, 0.5, "", nil, "0 = use the ESP style thickness")
SK(sb, "Line transparency", "box_trans", 0, 1, 0.05, "")
Toggle(sb, "Outline", "box_outline", nil, "Dark outline behind the lines")
Toggle(sb, "Fill", "box_fill")
Toggle(sb, "Fill uses player color", "box_fill_player")
ColorRow(sb, "Fill color", "box_fill_c", nil, "Used when Fill uses player color is off")
SK(sb, "Fill transparency", "box_fill_trans", 0, 1, 0.05, "")
sb = Feature(card, "Skeleton", "esp_skel", {desc = "Lines along the bones"})
DK(sb, "Color", "skel_color_mode", COLOR_MODES, nil, COLOR_DESC)
ColorRow(sb, "Custom color", "skel_color")
SK(sb, "Thickness", "skel_thick", 0, 6, 0.5, "", nil, "0 = use the ESP style thickness")
SK(sb, "Transparency", "skel_trans", 0, 1, 0.05, "")
Toggle(sb, "Joints", "skel_joints", nil, "A dot at every joint")
SK(sb, "Joint size", "skel_joint_size", 0, 12, 1, " px")
sb = Feature(card, "Name", "esp_name")
DK(sb, "Mode", "esp_namemode", {"Display", "Username"})
Toggle(sb, "Show team", "name_team", nil, "Puts the team name in front, like [Red] Name")
DK(sb, "Color", "name_color_mode", COLOR_MODES, nil, COLOR_DESC)
ColorRow(sb, "Custom color", "name_color")
SK(sb, "Size", "name_size", 0, 24, 1, " px", nil, "0 = use the ESP style text size")
DK(sb, "Font", "name_font", FONTS)
SK(sb, "Outline", "name_stroke", 0, 1, 0.05, "", nil, "Transparency of the text outline. 1 = no outline")
SK(sb, "Height above box", "name_offset", -10, 30, 1, " px")
sb = Feature(card, "Head circle", "esp_head", {desc = "Circle around the head"})
SK(sb, "Size", "head_scale", 0, 300, 5, "%")
DK(sb, "Color", "head_color_mode", COLOR_MODES, nil, COLOR_DESC)
ColorRow(sb, "Custom color", "head_color")
SK(sb, "Thickness", "head_thick", 0, 6, 0.5, "", nil, "0 = use the ESP style thickness")
SK(sb, "Line transparency", "head_trans", 0, 1, 0.05, "")
Toggle(sb, "Fill", "head_fill")
Toggle(sb, "Fill uses player color", "head_fill_player")
ColorRow(sb, "Fill color", "head_fill_c", nil, "Used when Fill uses player color is off")
SK(sb, "Fill transparency", "head_fill_trans", 0, 1, 0.05, "")
sb = Feature(card, "Health bar", "esp_health", {desc = "Bar next to the box. Every value can be typed in its box"})
Heading(sb, "Shape")
DK(sb, "Side", "hp_side", {"Left", "Right", "Top", "Bottom"}, nil, "Left / Right = vertical bar, Top / Bottom = horizontal bar")
SK(sb, "Thickness", "hp_width", 0, 14, 1, " px")
SK(sb, "Length", "hp_len", 0, 100, 5, "%", nil, "Of the box height (width for Top / Bottom)")
SK(sb, "Distance from box", "hp_gap", 0, 24, 1, " px")
SK(sb, "Inner padding", "hp_pad", 0, 4, 1, " px")
SK(sb, "Corner radius", "hp_corner", 0, 7, 1, " px")
SK(sb, "Segments", "hp_segments", 0, 10, 1, "", nil, "Splits the bar into equal parts. 0 = off")
Heading(sb, "Colors")
DK(sb, "Fill", "hp_color_mode", {"Gradient", "Two colors", "Solid", "Player color"}, nil,
    "Gradient = red to green. Two colors blends low to full health")
ColorRow(sb, "Low health", "hp_low", nil, "Used by Two colors")
ColorRow(sb, "Full health", "hp_high", nil, "Used by Two colors")
ColorRow(sb, "Solid color", "hp_solid", nil, "Used by Solid")
ColorRow(sb, "Background", "hp_back_c")
SK(sb, "Background transparency", "hp_back_trans", 0, 1, 0.05, "")
Toggle(sb, "Outline", "hp_outline")
ColorRow(sb, "Outline color", "hp_outline_c")
Heading(sb, "Text")
Toggle(sb, "Show text", "hp_text")
DK(sb, "Text", "hp_text_mode", {"Health", "Percent", "Health / Max"})
SK(sb, "Text size", "hp_text_size", 0, 20, 1, " px")
Toggle(sb, "Follow the fill", "hp_text_follow", nil, "The text moves with the end of the bar")
Toggle(sb, "Match bar color", "hp_text_fill")
ColorRow(sb, "Text color", "hp_text_c", nil, "Used when Match bar color is off")
Heading(sb, "Behavior")
SK(sb, "Show when below", "hp_show_below", 0, 100, 1, "%", nil, "Hides the bar above this health. 100 = always visible")
SK(sb, "Smoothing", "hp_smooth", 0, 95, 1, "%", nil, "How slowly the bar follows health changes. 0 = instant")
sb = Feature(card, "Distance", "esp_dist")
DK(sb, "Unit", "esp_unit", {"Studs", "Meters"})
SK(sb, "Decimals", "dist_decimals", 0, 2, 1, "")
Toggle(sb, "Brackets", "dist_brackets", nil, "Shows [120 st] instead of 120 st")
DK(sb, "Color", "dist_color_mode", COLOR_MODES, nil, COLOR_DESC)
ColorRow(sb, "Custom color", "dist_color")
SK(sb, "Size", "dist_size", 0, 24, 1, " px", nil, "0 = use the ESP style text size")
DK(sb, "Font", "dist_font", FONTS)
SK(sb, "Outline", "dist_stroke", 0, 1, 0.05, "", nil, "Transparency of the text outline. 1 = no outline")
SK(sb, "Distance below box", "dist_offset", -10, 30, 1, " px")
sb = Feature(card, "Tracers", "esp_tracer", {desc = "Lines from the screen to every player"})
DK(sb, "From", "tracer_from", {"Bottom", "Center", "Top", "Mouse"})
DK(sb, "To", "tracer_to", {"Feet", "Root", "Head"})
DK(sb, "Color", "tracer_color_mode", COLOR_MODES, nil, COLOR_DESC)
ColorRow(sb, "Custom color", "tracer_color")
SK(sb, "Thickness", "tracer_thick", 0, 6, 0.5, "", nil, "0 = use the ESP style thickness")
SK(sb, "Transparency", "tracer_trans", 0, 1, 0.05, "")

card = Card(PV, "ESP style", 1)
Toggle(card, "Show teammates", "esp_team", nil, "Teammates also get ESP and chams")
SK(card, "Max distance", "esp_maxdist", 0, 10000, 100, " st")
SK(card, "Line thickness", "esp_thick", 0, 4, 0.5, "")
SK(card, "Text size", "esp_text", 0, 22, 1, "")

-- team colors: the rows under the mode are rebuilt whenever teams change
local rebuildTeams
card = Card(PV, "Team colors", 1)
local teamStatus = StatusRow(card, "Your team")
DK(card, "Mode", "team_mode", {"Team colors", "Custom per team", "Ally / Enemy"}, function() rebuildTeams() end,
    "Team colors: every team uses its own color. Custom: pick a color for each team. Ally / Enemy: one color for your team and one for all the others")
local teamBox = stack(card, 2)

function rebuildTeams()
    for _, c in ipairs(teamBox:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    W.setSink({})   -- these rows are rebuilt from scratch, so they must not pile up in the global refresh list
    local mine = LP.Team
    teamStatus.Text = mine and mine.Name or "None"
    if S.team_mode == "Custom per team" then
        local list = Teams:GetTeams()
        table.sort(list, function(a, b) return a.Name < b.Name end)
        for _, tm in ipairs(list) do
            local name = tm.Name
            ColorRowG(teamBox, name .. ((mine == tm) and "  (you)" or ""),
                function() return S.team_colors[name] or TC.default(tm) end,
                function(c) S.team_colors[name] = c end)
        end
        if #list == 0 then
            text(teamBox, "This game has no teams", {Size = UDim2.new(1, 0, 0, RH), TextSize = 12, TextColor3 = "dim"})
        end
        Button(teamBox, "Reset team colors", function()
            S.team_colors = {}
            rebuildTeams()
        end)
    elseif S.team_mode == "Ally / Enemy" then
        ColorRow(teamBox, "Your team", "col_ally")
        ColorRow(teamBox, "All other teams", "col_enemy")
    end
    ColorRow(teamBox, "No team", "col_noteam", nil, "Players that are not on any team")
    W.setSink(nil)
end
do
    local pending = false
    local function schedule()
        if pending then return end
        pending = true
        task.delay(0.2, function()
            pending = false
            rebuildTeams()
        end)
    end
    conn(Teams.ChildAdded:Connect(schedule))
    conn(Teams.ChildRemoved:Connect(schedule))
    conn(LP:GetPropertyChangedSignal("Team"):Connect(schedule))
end
refreshers[#refreshers + 1] = function() rebuildTeams() end
rebuildTeams()

card = Card(PV, "Chams", 2)
sb = Feature(card, "Chams", "chams", {desc = "One highlight on every player",
    cb = function(on)
        if on and S.occ_on then S.occ_on = false end   -- Roblox draws one highlight per character
        refreshAll()
    end})
DK(sb, "Depth", "chams_depth", {"Always on top", "Visible only"}, nil, "Always on top = visible through walls")
Toggle(sb, "Use team colors", "chams_team", nil, "Fill uses the Team colors card. Turn off to use the color below")
ColorRow(sb, "Fill color", "chams_fill_c")
SK(sb, "Fill transparency", "chams_fill", 0, 1, 0.05, "")
ColorRow(sb, "Outline color", "chams_line_c")
SK(sb, "Outline transparency", "chams_line", 0, 1, 0.05, "")
sb = Feature(card, "Occluded chams", "occ_on", {desc = "Separate colors for the visible part and the part behind walls (shows when a player peeks)",
    cb = function(on)
        if on and S.chams then S.chams = false end
        refreshAll()
    end})
Toggle(sb, "Use team colors", "occ_team", nil, "Fill uses the Team colors card. Turn off to use the colors below")
Toggle(sb, "Include accessories", "occ_acc")
Heading(sb, "Visible (peeking)")
ColorRow(sb, "Fill color", "occ_vis_fill_c")
SK(sb, "Fill transparency", "occ_vis_fill", 0, 1, 0.05, "")
ColorRow(sb, "Outline color", "occ_vis_line_c")
SK(sb, "Outline transparency", "occ_vis_line", 0, 1, 0.05, "")
Heading(sb, "Behind wall")
ColorRow(sb, "Fill color", "occ_fill_c")
SK(sb, "Fill transparency", "occ_fill", 0, 1, 0.05, "")
ColorRow(sb, "Outline color", "occ_line_c")
SK(sb, "Outline transparency", "occ_line", 0, 1, 0.05, "")
SK(card, "Max players", "chams_max", 0, 30, 1, "", nil, "Roblox draws 31 highlights; occluded uses 2 per player")

-- Player ------------------------------------------------------------------
local PP = pages.Player

card = Card(PP, "Movement", 1)
sb = Feature(card, "WalkSpeed", "walk_on")
SK(sb, "Speed", "walk", 0, 300, 1, "")
sb = Feature(card, "JumpPower", "jump_on")
SK(sb, "Power", "jump", 0, 400, 1, "")
Toggle(card, "Infinite jump", "infjump")
Toggle(card, "Noclip", "noclip")
sb = Feature(card, "Fly", "fly")
SK(sb, "Speed", "fly_speed", 0, 300, 5, "")
sb = Feature(card, "Bunny hop", "bhop_on")
DK(sb, "Mode", "bhop_mode", {"Hold", "Moving", "Always"}, nil, "Hold = while Space is held, Moving = while you move")
Toggle(sb, "Air speed", "bhop_boost", nil, "Keeps a constant speed in the air")
SK(sb, "Speed", "bhop_speed", 0, 120, 1, "")

card = Card(PP, "Camera", 2)
sb = Feature(card, "Third person", "tp_on", {desc = "Pulls the camera back"})
SK(sb, "Distance", "tp_dist", 0, 60, 1, " st")
SK(sb, "Height", "tp_height", -5, 15, 0.5, " st")
SK(sb, "Side offset", "tp_side", -12, 12, 0.5, " st")
Toggle(sb, "Collision", "tp_collide", nil, "Keeps the camera from clipping into walls")
Toggle(sb, "Show own body", "tp_body")
if not isMobile then Keybind(sb, "Key", "tp_key", true, "Backspace clears the key") end
sb = Feature(card, "FOV changer", "camfov_on")
SK(sb, "Field of view", "camfov", 0, 120, 1, "")

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

-- Teleport ----------------------------------------------------------------
local PTP = pages.Teleport

-- waypoints are saved per game, so every map keeps its own list
local WP = {list = {}, path = ST.root .. "/waypoints_" .. tostring(game.PlaceId) .. ".json"}

local function wpSave()
    local out = {}
    for _, w in ipairs(WP.list) do out[#out + 1] = {name = w.name, cf = w.cf} end
    ST.put(WP.path, HttpService:JSONEncode(out))
end

do
    local txt = ST.get(WP.path)
    local data = txt and ST.decode(txt)
    for _, w in ipairs(data or {}) do
        if #WP.list >= 100 then break end
        if type(w) == "table" and type(w.name) == "string" and type(w.cf) == "table" and #w.cf == 12 then
            local ok = true
            for i = 1, 12 do
                if type(w.cf[i]) ~= "number" then ok = false end
            end
            if ok then WP.list[#WP.list + 1] = {name = w.name:sub(1, 40), cf = w.cf} end
        end
    end
end

local function myRoot()
    local ch = LP.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function teleportTo(cf)
    local root = myRoot()
    if not root then return false end
    root.CFrame = cf
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    return true
end

local teleStatus
local function say(m)
    if teleStatus then teleStatus.Text = m end
end

local wpRebuild
card = Card(PTP, "Waypoints", 1)
local wpName = Input(card, "Name", "", "waypoint name")
Button(card, "Set waypoint at my position", function()
    local root = myRoot()
    if not root then return say("no character") end
    if #WP.list >= 100 then return say("waypoint limit reached (100)") end
    local nm = wpName.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if nm == "" then nm = "Waypoint " .. (#WP.list + 1) end
    nm = nm:sub(1, 40)
    WP.list[#WP.list + 1] = {name = nm, cf = {root.CFrame:GetComponents()}}
    wpSave()
    wpRebuild()
    wpName.Text = ""
    say("saved: " .. nm)
end)
teleStatus = StatusRow(card, "Status")
local wpBox = stack(card, 4)
local wpEmpty = text(wpBox, "No waypoints yet", {Size = UDim2.new(1, 0, 0, RH), TextSize = 12, TextColor3 = "dim",
    TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 0, Visible = false})

function wpRebuild()
    for _, c in ipairs(wpBox:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    wpEmpty.Visible = (#WP.list == 0)
    local pw = isMobile and 46 or 40
    for idx, w in ipairs(WP.list) do
        local row = new("Frame", {Name = "WaypointRow", Size = UDim2.new(1, 0, 0, RH + 2), BackgroundColor3 = "item",
            BorderSizePixel = 0, LayoutOrder = idx}, wpBox)
        new("UICorner", {CornerRadius = UDim.new(0, 6)}, row)
        -- the name is an editable box: click it, type, press enter to rename
        local nameBox = new("TextBox", {Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -(pw * 3 + 26), 1, 0),
            BackgroundTransparency = 1, Text = w.name, TextColor3 = "text", TextSize = 12, Font = curFont(),
            ClearTextOnFocus = false, ClipsDescendants = true, TextXAlignment = Enum.TextXAlignment.Left}, row)
        textObjs[#textObjs + 1] = nameBox
        nameBox.FocusLost:Connect(function()
            local nm = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
            if nm == "" then
                nameBox.Text = w.name
                return
            end
            w.name = nm:sub(1, 40)
            nameBox.Text = w.name
            wpSave()
        end)
        local function pill(label, k)
            local b = new("TextButton", {Name = label, AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -6 - (3 - k) * (pw + 4), 0.5, 0), Size = UDim2.fromOffset(pw, RH - 8),
                BackgroundColor3 = "sub", BorderSizePixel = 0, Text = label, TextSize = 11, Font = Enum.Font.GothamBold,
                TextColor3 = "text", AutoButtonColor = true}, row)
            ctl(b, true)
            return b
        end
        local go, here, del = pill("TP", 1), pill("Here", 2), pill("Del", 3)
        go.Activated:Connect(function()
            say(teleportTo(CFrame.new(table.unpack(w.cf))) and ("teleported to " .. w.name) or "no character")
        end)
        here.Activated:Connect(function()
            local root = myRoot()
            if not root then return say("no character") end
            w.cf = {root.CFrame:GetComponents()}
            wpSave()
            say("moved " .. w.name .. " here")
        end)
        local armed = false
        del.Activated:Connect(function()
            if armed then
                for i, x in ipairs(WP.list) do
                    if x == w then
                        table.remove(WP.list, i)
                        break
                    end
                end
                wpSave()
                wpRebuild()
                say("deleted: " .. w.name)
                return
            end
            armed = true
            del.Text = "Sure?"
            task.delay(2.5, function()
                if armed then
                    armed = false
                    if del.Parent then del.Text = "Del" end
                end
            end)
        end)
    end
end
wpRebuild()

card = Card(PTP, "Teleport to player", 2)
DK(card, "Position", "tele_offset", {"Behind", "In front", "Above", "On target"}, nil, "Where you land relative to the player")
SK(card, "Distance", "tele_dist", 0, 20, 1, " st")

local function tpToPlayer(id, name)
    local pl = Players:GetPlayerByUserId(id)
    local tr = pl and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
    if not tr then return say("that player has no character") end
    local cf, d, mode = tr.CFrame, S.tele_dist, S.tele_offset
    local pos, look
    if mode == "Behind" then
        pos, look = cf.Position - cf.LookVector * d, cf.LookVector
    elseif mode == "In front" then
        pos, look = cf.Position + cf.LookVector * d, -cf.LookVector
    elseif mode == "Above" then
        pos, look = cf.Position + Vector3.new(0, d, 0), cf.LookVector
    else
        pos, look = cf.Position, cf.LookVector
    end
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
    say(teleportTo(CFrame.lookAt(pos, pos + flat)) and ("teleported to " .. name) or "no character")
end
PlayerList(card, {
    {label = "TP", onColor = accent, onBg = function() return T.sub end,
     click = function(e) tpToPlayer(e.id, e.display) end},
}, false)

-- Theme -------------------------------------------------------------------
local PTH = pages.Theme

card = Card(PTH, "Colors", 1)
for _, c in ipairs({{"Accent", "ui_accent"}, {"Background", "ui_bg"}, {"Sidebar", "ui_side"}, {"Cards", "ui_card"},
    {"Panels", "ui_sub"}, {"Controls", "ui_item"}, {"Borders", "ui_line"}, {"Switch off", "ui_off"},
    {"Text", "ui_text"}, {"Dim text", "ui_dim"}}) do
    ColorRow(card, c[1], c[2], applyTheme)
end

card = Card(PTH, "Window", 1)
SK(card, "Window transparency", "ui_trans", 0, 0.8, 0.02, "", applyTheme)
SK(card, "Scale", "ui_scale", 0, 1.6, 0.05, "x", layout)
SK(card, "Corner radius", "ui_corner", 0, 16, 1, " px", applyTheme)
SK(card, "Sidebar width", "ui_sidew", 0, 220, 5, " px", layout)
SK(card, "Outline thickness", "ui_stroke", 0, 4, 0.5, "", applyTheme)
SK(card, "Outline transparency", "ui_stroke_trans", 0, 1, 0.05, "", applyTheme)
DK(card, "Font", "ui_font", {"GothamMedium", "Gotham", "Ubuntu", "SourceSans", "Arial", "Code"}, applyTheme)
Toggle(card, "Top accent line", "ui_topline", applyTheme)
Toggle(card, "Background gradient", "ui_gradient", applyTheme)
Toggle(card, "Show descriptions", "ui_desc", applyTheme, "Small hint text under each option")
sb = Feature(card, "Resize handle", "resize_on", {cb = updateGrip, desc = "Drag the top bar to move, pull the grip to resize"})
DK(sb, "Corner", "resize_corner", {"Bottom right", "Bottom left", "Top right", "Top left"}, updateGrip)
Button(card, "Reset window size and position", function()
    S.win_w, S.win_h, S.win_cx, S.win_cy = THEME_DEFAULTS.win_w, THEME_DEFAULTS.win_h, THEME_DEFAULTS.win_cx, THEME_DEFAULTS.win_cy
    layout()
end)

card = Card(PTH, "Cards", 1)
SK(card, "Card transparency", "card_trans", 0, 1, 0.02, "", applyTheme)
SK(card, "Panel transparency", "sub_trans", 0, 1, 0.02, "", applyTheme, "The settings panels that open under a feature")
SK(card, "Corner radius", "card_corner", 0, 16, 1, " px", applyTheme)
SK(card, "Border thickness", "card_stroke", 0, 4, 0.5, "", applyTheme)
SK(card, "Border transparency", "card_stroke_trans", 0, 1, 0.05, "", applyTheme)
Toggle(card, "Accent border", "card_stroke_accent", applyTheme)
DK(card, "Header style", "card_header", {"Plain", "Accent text", "Accent bar", "Accent line"}, applyTheme)
SK(card, "Title size", "card_title_size", 0, 18, 1, " px", applyTheme)
Toggle(card, "Title divider", "card_divider", applyTheme)
SK(card, "Padding", "card_pad", 0, 20, 1, " px", applyTheme)
SK(card, "Spacing between cards", "card_gap", 0, 20, 1, " px", applyTheme)
Toggle(card, "Collapsible cards", "card_collapse", applyTheme, "Click a card title to collapse or expand it")
Button(card, "Expand all cards", function()
    S.card_collapsed = {}
    applyTheme()
end)

card = Card(PTH, "Controls", 1)
SK(card, "Corner radius", "ctl_corner", 0, 12, 1, " px", applyTheme, "Buttons, dropdowns, inputs and keybinds")
SK(card, "Border thickness", "ctl_stroke", 0, 3, 0.5, "", applyTheme)
SK(card, "Border transparency", "ctl_stroke_trans", 0, 1, 0.05, "", applyTheme)
Toggle(card, "Accent border", "ctl_stroke_accent", applyTheme)
SK(card, "Transparency", "ctl_trans", 0, 1, 0.05, "", applyTheme)
SK(card, "Text size", "ctl_text", 0, 15, 1, " px", applyTheme)

card = Card(PTH, "Switches", 1)
DK(card, "Shape", "sw_shape", {"Pill", "Rounded", "Square"}, applyTheme)
SK(card, "Width", "sw_w", 0, 44, 2, " px", applyTheme)
SK(card, "Height", "sw_h", 0, 24, 2, " px", applyTheme)
SK(card, "Knob size", "sw_knob", 0, 20, 2, " px", applyTheme)
Toggle(card, "Follow accent color", "sw_accent", applyTheme, "The on color uses the accent color")
ColorRow(card, "On color", "sw_on", applyTheme)
ColorRow(card, "Knob color", "sw_knob_c", applyTheme)

card = Card(PTH, "Sliders", 1)
DK(card, "Shape", "sl_shape", {"Circle", "Square"}, applyTheme)
SK(card, "Track thickness", "sl_h", 0, 10, 1, " px", applyTheme)
SK(card, "Knob size", "sl_knob", 0, 16, 2, " px", applyTheme)
Toggle(card, "Follow accent color", "sl_accent", applyTheme, "The filled part uses the accent color")
ColorRow(card, "Fill color", "sl_fill", applyTheme)

card = Card(PTH, "Themes", 2)
Manager(card, "theme")

card = Card(PTH, "Close button", 2)
SK(card, "Size", "cb_size", 0, 40, 2, " px", applyTheme)
SK(card, "Corner radius", "cb_corner", 0, 20, 1, " px", applyTheme)
ColorRow(card, "Background", "cb_bg", applyTheme)
ColorRow(card, "Icon", "cb_icon", applyTheme)
ColorRow(card, "Hover", "cb_hover", applyTheme)

-- position / size / lock rows that every button of the main GUI has. k = the settings keys of that button
local function HudCommon(parent, k, pct)
    Toggle(parent, "Lock position and size", k.lock, applyTheme, "A locked button can't be dragged or resized. Unlocked buttons show a corner handle")
    SK(parent, "Size", k.size, 0, 220, 2, " px", applyTheme)
    SK(parent, "Aspect (height / width)", k.ratio, 0, 2.5, 0.05, "", applyTheme)
    local m = pct and 1 or 100
    Slider(parent, "Position X", function() return S[k.x] * m end, function(v)
        S[k.x] = v / m
        applyTheme()
    end, 0, 100, 0.5, "%")
    Slider(parent, "Position Y", function() return S[k.y] * m end, function(v)
        S[k.y] = v / m
        applyTheme()
    end, 0, 100, 0.5, "%")
end

card = Card(PTH, "HUD buttons", 2)
Toggle(card, "Lock all buttons", "hud_lock_all", applyTheme, "Locked buttons only do their action: no dragging, no resizing")
Toggle(card, "Show every button", "hud_preview", applyTheme, "Shows the buttons that are normally hidden, so you can place them. Not saved")
ConfirmButton(card, "Reset positions and sizes", function()
    for _, key in ipairs(ST.hudKeys) do S[key] = copy(THEME_DEFAULTS[key]) end
    refreshAll()
    layout()
end)

card = Card(PTH, "Open / close button", 2)
Toggle(card, "Show button", "ui_btn", applyTheme, "Floating button that opens and closes the menu")
HudCommon(card, {lock = "fb_lock", size = "fb_size", ratio = "fb_ratio", x = "fb_x", y = "fb_y"}, false)
DK(card, "Shape", "fb_shape", SHAPES, applyTheme)
TextK(card, "Label", "fb_text", applyTheme, 3, "R")
SK(card, "Text size", "fb_textsize", 0, 32, 1, " px", applyTheme)
SK(card, "Transparency", "fb_trans", 0, 1, 0.05, "", applyTheme)
SK(card, "Outline thickness", "fb_stroke", 0, 6, 0.5, "", applyTheme)
Toggle(card, "Follow accent color", "fb_accent", applyTheme, "Text and outline use the accent color")
ColorRow(card, "Background", "fb_bg", applyTheme)
ColorRow(card, "Text color", "fb_textc", applyTheme)
ColorRow(card, "Outline color", "fb_strokec", applyTheme)

card = Card(PTH, "AIM button", 2)
HudCommon(card, {lock = "ab_lock", size = "aim_btn_size", ratio = "ab_ratio", x = "aim_btn_x", y = "aim_btn_y"}, true)
DK(card, "Shape", "ab_shape", SHAPES, applyTheme)
TextK(card, "Label", "ab_text", applyTheme, 6, "AIM")
SK(card, "Text size", "ab_textsize", 0, 30, 1, " px", applyTheme)
SK(card, "Transparency", "ab_trans", 0, 1, 0.05, "", applyTheme)
SK(card, "Outline thickness", "ab_stroke", 0, 6, 0.5, "", applyTheme)
Toggle(card, "Follow accent color", "ab_accent", applyTheme, "Outline and active fill use the accent color")
ColorRow(card, "Background", "ab_bg", applyTheme)
ColorRow(card, "Text color", "ab_textc", applyTheme)
ColorRow(card, "Outline color", "ab_strokec", applyTheme)

card = Card(PTH, "Quick buttons", 2)
DK(card, "Shape", "qb_shape", SHAPES, applyTheme)
SK(card, "Text size", "qb_textsize", 0, 20, 1, " px", applyTheme)
SK(card, "Transparency", "qb_trans", 0, 1, 0.02, "", applyTheme)
SK(card, "Outline thickness", "qb_stroke", 0, 4, 0.5, "", applyTheme)
Toggle(card, "Follow accent color", "qb_accent", applyTheme, "Outline and active fill use the accent color")
ColorRow(card, "Button color", "qb_btn", applyTheme)
ColorRow(card, "Text color", "qb_textc", applyTheme)
ColorRow(card, "Outline color", "qb_strokec", applyTheme)
for _, q in ipairs(QUICK) do
    local pre = "qb_" .. q[1] .. "_"
    sb = Feature(card, q[2] .. " button", nil, {desc = "Label, position, size and lock of this button"})
    TextK(sb, "Label", pre .. "text", applyTheme, 5, q[2])
    HudCommon(sb, {lock = pre .. "lock", size = pre .. "size", ratio = pre .. "ratio", x = pre .. "x", y = pre .. "y"}, false)
end

card = Card(PTH, "Tap point", 2)
DK(card, "Marker", "tap_vis", {"Always", "While unlocked", "Hidden"}, applyTheme,
    "Shown while the triggerbot fire method is Screen tap. The tap lands on the center of the marker")
HudCommon(card, {lock = "tap_lock", size = "tap_size", ratio = "tap_ratio", x = "tap_x", y = "tap_y"}, false)
DK(card, "Shape", "tap_shape", SHAPES, applyTheme)
TextK(card, "Label", "tap_text", applyTheme, 6, "TAP")
SK(card, "Text size", "tap_textsize", 0, 24, 1, " px", applyTheme)
SK(card, "Fill transparency", "tap_trans", 0, 1, 0.05, "", applyTheme)
SK(card, "Outline thickness", "tap_stroke", 0, 6, 0.5, "", applyTheme)
Toggle(card, "Follow accent color", "tap_accent", applyTheme, "Fill and outline use the accent color")
ColorRow(card, "Fill color", "tap_fill", applyTheme)
ColorRow(card, "Outline color", "tap_strokec", applyTheme)
ColorRow(card, "Text color", "tap_textc", applyTheme)

-- Config ------------------------------------------------------------------
local PF = pages.Config

card = Card(PF, "Configs", 1)
Manager(card, "config")

card = Card(PF, "Menu", 1)
Keybind(card, "Menu key", "ui_key")

card = Card(PF, "Mobile", 2)
Feature(card, "AIM button", "aim_button", {sub = false, desc = "Hold to aim when there is no mouse (look, size, position and lock: Theme tab)"})
sb = Feature(card, "Quick buttons", "qb_on", {cb = updateQuick, desc = "Floating toggles you can drag anywhere (look, size, position and lock of each one: Theme tab)"})
Toggle(sb, "Triggerbot", "qb_trig", updateQuick)
Toggle(sb, "Spinbot", "qb_spin", updateQuick)
Toggle(sb, "Third person", "qb_tp", updateQuick)
Toggle(sb, "Bunny hop", "qb_bhop", updateQuick)
Toggle(card, "Lock all buttons", "hud_lock_all", applyTheme, "Every button on the screen stops being draggable and resizable")

card = Card(PF, "Script", 2)
Button(card, "Unload", function()
    if ENV.__RAGWARE_UNLOAD then ENV.__RAGWARE_UNLOAD() end
end)
end   -- end of the pages block
Loader.mark("Loading combat modules")
----------------------------------------------------------------------------
-- combat logic: filters, aimbot
----------------------------------------------------------------------------
local unloading = false

-- wall checks: players are never walls.
-- Every wall / visibility check (aimbot, triggerbot, chams, third person camera) ignores all characters, so only real
-- geometry blocks the view. Vis.filter(extra) = `extra` plus every character (the character list is cached for 0.2 s).
local Vis = {chars = {}, stamp = -1}

function Vis.refresh()
    local now = os.clock()
    if now - Vis.stamp < 0.2 then return Vis.chars end
    Vis.stamp = now
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then list[#list + 1] = p.Character end
    end
    Vis.chars = list
    return list
end

function Vis.filter(extra)
    local out = {extra}
    for _, ch in ipairs(Vis.refresh()) do out[#out + 1] = ch end
    return out
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
pcall(function() rayParams.RespectCanCollide = true end)

local function aimKeyActive()
    if S.aim_mode == "Always" then return true end
    if S.aim_mode == "Toggle" then return S.aimbot end   -- Toggle: the aim key flips the aimbot switch itself
    return aimHeld
end

local function aimOn() return S.aimbot and aimKeyActive() end

-- player's shot: left click outside the menu. The spinbot uses this to stop spinning while you shoot
local fireHeld, toolDown, lastShotInput = false, false, -1000

local function overMenu(pos)
    if not win.Visible then return false end
    local p, sz = win.AbsolutePosition, win.AbsoluteSize
    return pos.X >= p.X and pos.X <= p.X + sz.X and pos.Y >= p.Y and pos.Y <= p.Y + sz.Y
end

-- shooting right now, or less than "Resume delay" ms ago (released click / triggerbot on a target)
local function shooting()
    local now = os.clock()
    local resume = S.spin_resume / 1000
    local held = fireHeld and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    return held or toolDown or now - lastShotInput < resume or now - TR.lastActive < resume
end

-- classic "Tool" weapons: Activated / Deactivated also count as shooting (covers mobile, which has no mouse click)
do
    local hooked = setmetatable({}, {__mode = "k"})
    local function hookTool(tool)
        if hooked[tool] then return end
        hooked[tool] = true
        conn(tool.Activated:Connect(function() toolDown = true end))
        conn(tool.Deactivated:Connect(function()
            toolDown = false
            lastShotInput = os.clock()
        end))
    end
    local function hookChar(ch)
        for _, t in ipairs(ch:GetChildren()) do
            if t:IsA("Tool") then hookTool(t) end
        end
        conn(ch.ChildAdded:Connect(function(t)
            if t:IsA("Tool") then hookTool(t) end
        end))
    end
    if LP.Character then hookChar(LP.Character) end
    conn(LP.CharacterAdded:Connect(hookChar))
end

local function origin(c)
    if S.fov_origin == "Mouse" and not isMobile then return UIS:GetMouseLocation() end
    local vp = c.ViewportSize
    return Vector2.new(vp.X / 2, vp.Y / 2)
end

-- are you alive? (only counts when that feature's death filter is on; pre = "aim" or "trig")
local function selfAlive(pre)
    if not S[CK[pre].dead] then return true end
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

-- friends: IsFriendsWith is asynchronous, so it is cached and queried in the background
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

-- downed/ragdoll: Humanoid states + common flags (attribute or BoolValue), cached for 0.25s
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

-- returns character, humanoid when the player is a valid target for that feature's filters
-- (pre = "aim" or "trig"; each feature has its own set of filters)
local function target(p, pre)
    if p == LP then return nil end
    if LIST.isIgnored(p) then return nil end
    if S.target_mode == "Only" and (LIST.count("target_list") > 0 or LIST.count("target_teams") > 0)
        and not LIST.isTarget(p) then
        return nil
    end
    local ch = p.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    local k = CK[pre]
    if S[k.dead] and (hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead) then return nil end
    if S[k.team] and S.team_ignore_mine and sameTeam(p) then return nil end
    if S[k.ff] and ch:FindFirstChildOfClass("ForceField") then return nil end
    if S[k.friend] and isFriend(p) then return nil end
    if S[k.invis] and isInvisible(ch) then return nil end
    if S[k.down] and isDowned(p, ch, hum) then return nil end
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
        local ch, hum = target(p, "aim")
        if ch then
            local part = aimPart(ch, c, org)
            if part then
                local sp, onScreen = c:WorldToViewportPoint(part.Position)
                if onScreen then
                    local d2 = (Vector2.new(sp.X, sp.Y) - org).Magnitude
                    local d3 = (part.Position - cp).Magnitude
                    if d3 <= S.aim_maxdist and (S.fov_fullscreen or d2 <= S.aim_fov)
                        and (not S.aim_chk_wall or visible(c, part, ch)) then
                        local score = d2
                        if S.aim_priority == "Distance" then
                            score = d3
                        elseif S.aim_priority == "Health" then
                            score = hum.Health
                        end
                        if S.target_mode == "Priority" and LIST.isTarget(p) then score = score - 1e6 end
                        if not bestScore or score < bestScore then best, bestScore = part, score end
                    end
                end
            end
        end
    end
    return best
end

-- humanizer: per-target state (reaction time, random point inside the hitbox) + smooth (Perlin) noise on the aim direction
local aimUpdate
do
local hPart, hAcq, hRoll, hOff = nil, 0, 0, Vector3.zero
local hSeed = math.random() * 100

local function hRollOffset()
    local r = S.human_offset
    return Vector3.new((math.random() * 2 - 1) * r, (math.random() * 2 - 1) * r, (math.random() * 2 - 1) * r)
end

-- smooth 0% => alpha 1 (instant). alpha is framerate independent: 1 - s^(dt*60)
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
end   -- end of the aimbot block
----------------------------------------------------------------------------
-- triggerbot
-- detection: rays that pass through whatever does not block (transparent / no collision), with a pixel tolerance
-- firing: Executor (mouse1press/release/click), VirtualInput or Tool:Activate, with a fallback in Auto
----------------------------------------------------------------------------
do
    local VIM
    pcall(function() VIM = game:GetService("VirtualInputManager") end)

    local function heldTool()
        local ch = LP.Character
        return ch and ch:FindFirstChildOfClass("Tool")
    end

    -- Screen tap: touches (or clicks) the point set with the tap marker (Theme > Tap point). Made for devices without a
    -- mouse: put the marker on the game's fire button and the triggerbot taps it. The same x / y is used for the
    -- press and the release.
    local tapId, tapX, tapY = 3, 0, 0
    local function tapEvent(down)
        if down then
            local pos = TR.tapPos and TR.tapPos()
            if not pos then return false end
            tapX, tapY = pos.X, pos.Y
            local j = S.tap_jitter
            if j > 0 then
                local ang, r = math.random() * math.pi * 2, math.sqrt(math.random()) * j
                tapX, tapY = tapX + math.cos(ang) * r, tapY + math.sin(ang) * r
            end
        end
        local ok = false
        if S.tap_method ~= "Mouse" then
            ok = pcall(function() VIM:SendTouchEvent(tapId, down and 0 or 2, tapX, tapY) end)
        end
        if S.tap_method == "Mouse" or (S.tap_method == "Auto" and not ok) then
            ok = pcall(function() VIM:SendMouseButtonEvent(tapX, tapY, 0, down, game, 0) end)
        end
        return ok
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
        {name = "Screen tap",
         ok = function() return VIM ~= nil end,
         hold = function() return true end,
         down = function()
             if TR.tapBusy then TR.tapBusy(true) end   -- the marker must not catch its own tap
             if not tapEvent(true) then
                 if TR.tapBusy then TR.tapBusy(false) end
                 error("tap failed")
             end
         end,
         up = function()
             tapEvent(false)
             if TR.tapBusy then TR.tapBusy(false) end
         end},
    }

    local holding = nil

    -- Screen tap is never part of Auto: it needs the marker to be placed first
    local function usable(b)
        return (S.fire_method == b.name or (S.fire_method == "Auto" and b.name ~= "Screen tap")) and b.ok()
    end

    function TR.fire()
        for _, b in ipairs(backends) do
            if usable(b) and pcall(b.down) then
                task.delay(b.name == "Screen tap" and S.tap_hold / 1000 or 0.03, function() pcall(b.up) end)
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

    -- walks up the hierarchy until it finds the Model that is some player's character
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

    -- ray that passes through invisible / non-colliding parts (fake hitboxes, grass, zones) and stops at a real wall
    -- with the Wall filter off the ray ignores every non-player part (shoots through walls)
    local function castThrough(o, d, c)
        local ignore = {c}
        if LP.Character then ignore[2] = LP.Character end
        local ghost = not S.trig_chk_wall
        for _ = 1, (ghost and 16 or 8) do
            trigParams.FilterDescendantsInstances = ignore
            local hit = Workspace:Raycast(o, d, trigParams)
            if not hit then return nil end
            local pl = playerOfPart(hit.Instance)
            if pl then
                if target(pl, "trig") then return hit, pl end
                -- a player that is not a valid target (teammate, ignored, filtered...) is not a wall either: the ray goes through
                if pl.Character then ignore[#ignore + 1] = pl.Character end
            else
                local inst = hit.Instance
                if ghost or inst.Transparency >= 0.95 or (not inst.CanCollide and inst.Transparency >= 0.5) then
                    ignore[#ignore + 1] = inst
                else
                    return nil
                end
            end
        end
        return nil
    end

    -- headshot: the Head itself or anything stuck to it (hat, hair)
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
            local hit, pl = castThrough(ray.Origin, ray.Direction * math.max(S.trigger_range, 1), c)
            if hit and pl then
                local ch = target(pl, "trig")
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
        if not selfAlive("trig") or (S.trigger_aimkey and not aimKeyActive()) then
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
        -- with the spinbot pausing while shooting, wait at least one frame for the body to turn before firing
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
            TR.note = m and ("fired via " .. m) or "no fire method (executor / VirtualInput / held Tool / Screen tap)"
        end
    end
end
Loader.mark("Loading visuals")
----------------------------------------------------------------------------
-- chams
-- Chams:          one Highlight on the character (always on top, or visible only).
-- Occluded chams: two layers, so a player that is peeking shows both of them (devforum technique):
--   visible layer     = Highlight "line of sight" (Occluded) on the real character;
--   behind-wall layer = a texture-less clone (0.99x, welded to the real parts) with an AlwaysOnTop Highlight.
--                       The line-of-sight layer masks it, so it only shows where a wall hides the target.
-- The two are separate features with separate settings. Roblox draws one highlight per character,
-- so when both are switched on, occluded chams is the one that is drawn.
----------------------------------------------------------------------------
do
    local dir = Instance.new("Folder")
    dir.Name = "RagWareChams"
    dir.Parent = Workspace
    local states, clock = {}, 0

    -- R6 body part names -> their canonical mesh asset paths.
    -- The forum fix (devforum.roblox.com/t/3642028) says: for R6, destroy all children then recreate a
    -- fresh SpecialMesh from the known path; cloning the existing mesh and just clearing it leaves the
    -- clone with the wrong shape because R6 uses file-based meshes that need the correct asset path.
    local R6_MESHES = {
        Head        = "rbxasset://fonts/head.mesh",
        Torso       = "rbxasset://fonts/torso.mesh",
        ["Left Arm"]  = "rbxasset://fonts/leftarm.mesh",
        ["Right Arm"] = "rbxasset://fonts/rightarm.mesh",
        ["Left Leg"]  = "rbxasset://fonts/leftleg.mesh",
        ["Right Leg"] = "rbxasset://fonts/rightleg.mesh",
    }

    local function clonePart(src)
        local c = src:Clone()
        if not c then return nil end
        -- strip everything: joints, scripts, tags, highlight, movers, etc.
        for _, d in ipairs(c:GetChildren()) do d:Destroy() end
        local meshed = false
        if c:IsA("MeshPart") then
            c.TextureID = ""
            c.Size = c.Size * 0.99
            meshed = true
        else
            local r6path = R6_MESHES[src.Name]
            if r6path then
                -- R6 body part: recreate a clean SpecialMesh with the correct mesh file.
                -- This is the fix from the DevForum tutorial; copying the existing mesh leaves it broken.
                local sm = Instance.new("SpecialMesh")
                sm.MeshType = Enum.MeshType.FileMesh
                sm.MeshId   = r6path
                sm.TextureId = ""
                sm.Scale    = Vector3.new(0.99, 0.99, 0.99)
                sm.Parent   = c
                meshed = true
            else
                -- Accessory handle, hat, R15 part with a non-file mesh: clone the original mesh cleanly
                local srcMesh = src:FindFirstChildWhichIsA("SpecialMesh")
                             or src:FindFirstChildWhichIsA("BlockMesh")
                             or src:FindFirstChildWhichIsA("CylinderMesh")
                if srcMesh then
                    local mc = srcMesh:Clone()
                    mc:ClearAllChildren()
                    if mc:IsA("SpecialMesh") then mc.TextureId = "" end
                    mc.Scale = mc.Scale * 0.99
                    mc.Parent = c
                    meshed = true
                end
            end
        end
        if not meshed then c.Size = c.Size * 0.99 end
        -- anchor temporarily so the part sits at the right CFrame while the WeldConstraint is wired up
        c.Anchored = true
        c.CFrame = src.CFrame
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
            -- parent first so the engine knows which Workspace the weld lives in
            c.Parent = model
            local w = Instance.new("WeldConstraint")
            w.Part0 = c
            w.Part1 = src
            w.Parent = c
            -- unanchor only after the weld is in place; otherwise the clone falls before it is attached
            c.Anchored = false
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

    -- rig signature: how many parts / accessories (when it changes the clones are rebuilt)
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
            or (mode == "occ" and (st.acc ~= S.occ_acc or st.n ~= sig(ch) or not st.model.Parent))) then
            destroy(p)
            st = nil
        end
        if not st then
            st = {char = ch, mode = mode, acc = S.occ_acc, n = sig(ch)}
            st.los = new("Highlight", {Name = "RagWareLOS", Adornee = ch}, ch)
            if mode == "occ" then
                st.model = buildClones(p, ch, S.occ_acc)
                st.occ = new("Highlight", {Name = "RagWareOCC", Adornee = st.model,
                    DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}, st.model)
            end
            states[p] = st
        end

        local los = st.los
        if mode == "simple" then
            los.DepthMode = (S.chams_depth == "Visible only") and Enum.HighlightDepthMode.Occluded
                or Enum.HighlightDepthMode.AlwaysOnTop
            los.FillColor = TC.pick(p, S.chams_team, S.chams_fill_c)
            los.OutlineColor = col(S.chams_line_c)
            los.FillTransparency = S.chams_fill
            los.OutlineTransparency = S.chams_line
        else
            -- the line-of-sight layer must keep "rendering" (0.999 at most) so it can mask the behind-wall layer
            los.DepthMode = Enum.HighlightDepthMode.Occluded
            los.FillColor = TC.pick(p, S.occ_team, S.occ_vis_fill_c)
            los.OutlineColor = col(S.occ_vis_line_c)
            los.FillTransparency = math.min(S.occ_vis_fill, 0.999)
            los.OutlineTransparency = S.occ_vis_line
            local o = st.occ
            o.FillColor = TC.pick(p, S.occ_team, S.occ_fill_c)
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
        local mode = (S.occ_on and "occ") or (S.chams and "simple") or nil
        local list = {}
        if mode then
            local cp = eye or c.CFrame.Position
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP then
                    local ch = p.Character
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local root = ch and ch:FindFirstChild("HumanoidRootPart")
                    local hidden = LIST.isIgnored(p, true)
                    if hum and root and hum.Health > 0 and not hidden and (S.esp_team or not sameTeam(p)) then
                        list[#list + 1] = {p = p, d = (root.Position - cp).Magnitude}
                    end
                end
            end
            table.sort(list, function(a, b) return a.d < b.d end)
        end
        -- Roblox only draws 31 Highlights: occluded mode uses 2 per player, so the closest players come first
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
-- esp (real part geometry)
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
local espDt, espLast = 0.016, nil   -- seconds since the previous esp update (health bar smoothing)

local function newObj()
    local o = {shown = false, bodyShown = false}
    o.boxFill = new("Frame", {BorderSizePixel = 0, Visible = false}, overlay)
    o.boxOut = new("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false}, overlay)
    o.boxOutStroke = new("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 3, LineJoinMode = Enum.LineJoinMode.Miter}, o.boxOut)
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
    o.hpBackCorner = new("UICorner", {}, o.hpBack)
    o.hpStroke = new("UIStroke", {Thickness = 1, Enabled = false}, o.hpBack)
    o.hp = new("Frame", {BorderSizePixel = 0}, o.hpBack)
    o.hpCorner = new("UICorner", {}, o.hp)
    o.hpTicks = {}   -- segment dividers (up to 9 lines = 10 segments)
    for i = 1, 9 do
        o.hpTicks[i] = new("Frame", {BorderSizePixel = 0, Visible = false, ZIndex = 2}, o.hpBack)
    end
    o.hpText = new("TextLabel", {BackgroundTransparency = 1, Size = UDim2.fromOffset(70, 14), Font = Enum.Font.GothamMedium,
        TextSize = 11, TextStrokeTransparency = 0.2, Visible = false}, overlay)
    o.hpR = nil   -- health ratio that is currently drawn (for the smoothing)
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

-- hides everything except the tracer (which can stay valid even with the target off screen)
local function hideBody(o)
    if not o.bodyShown then return end
    o.bodyShown = false
    o.box.Visible = false
    o.boxOut.Visible = false
    o.boxFill.Visible = false
    o.name.Visible = false
    o.dist.Visible = false
    o.hpBack.Visible = false
    o.hpText.Visible = false
    o.head.Visible = false
    for _, l in ipairs(o.lines) do l.Visible = false end
    if o.cr then
        for i = 1, 8 do
            o.cr[i].Visible = false
            o.crOut[i].Visible = false
        end
    end
    if o.joints then
        for _, j in ipairs(o.joints) do j.Visible = false end
    end
end

local function hideObj(o)
    hideBody(o)
    o.tracer.Visible = false
    o.shown = false
end

local function destroyObj(o)
    o.box:Destroy()
    o.boxOut:Destroy()
    o.boxFill:Destroy()
    if o.cr then
        for i = 1, 8 do
            o.cr[i]:Destroy()
            o.crOut[i]:Destroy()
        end
    end
    if o.joints then
        for _, j in ipairs(o.joints) do j:Destroy() end
    end
    o.name:Destroy()
    o.dist:Destroy()
    o.hpBack:Destroy()
    o.hpText:Destroy()
    o.head:Destroy()
    o.tracer:Destroy()
    for _, l in ipairs(o.lines) do l:Destroy() end
end

-- where the tracer starts on screen
local function tracerFrom(vp)
    local m = S.tracer_from
    if m == "Mouse" and not isMobile then return UIS:GetMouseLocation() end
    if m == "Center" then return Vector2.new(vp.X / 2, vp.Y / 2) end
    if m == "Top" then return Vector2.new(vp.X / 2, 0) end
    return Vector2.new(vp.X / 2, vp.Y)
end

-- text fonts by name (cached) and the distance formats ("Decimals" setting: 0, 1 or 2)
local fontCache = {}
local function fontOf(name)
    local f = fontCache[name]
    if not f then
        local ok, v = pcall(function() return Enum.Font[name] end)
        f = (ok and v) or Enum.Font.GothamMedium
        fontCache[name] = f
    end
    return f
end
local UNIT_FMT = {Meters = {[0] = "%.0f m", "%.1f m", "%.2f m"}, Studs = {[0] = "%.0f st", "%.1f st", "%.2f st"}}

local function drawPlayer(o, p, ch, hum, root, c, vp, dist, team)
    local color = TC.pick(p, true)   -- target-list color, otherwise the team color mode

    -- oriented box: extremes of every part in the root's local space (real size + CFrame)
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

    -- tracer: from the chosen origin to the target (feet = base of the box built from the real parts, or root / head)
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
        if tsp.Z < 0 then px, py = vp.X - px, vp.Y - py end   -- behind the camera: mirror it so it points the right way
        local from = tracerFrom(vp)
        local td = Vector2.new(px, py) - from
        o.tracer.Size = UDim2.fromOffset(td.Magnitude, (S.tracer_thick > 0) and S.tracer_thick or S.esp_thick)
        o.tracer.Position = UDim2.fromOffset((px + from.X) / 2, (py + from.Y) / 2)
        o.tracer.Rotation = math.deg(math.atan2(td.Y, td.X))
        o.tracer.BackgroundColor3 = (S.tracer_color_mode == "Custom") and col(S.tracer_color) or color
        o.tracer.BackgroundTransparency = S.tracer_trans
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
        local bth = (S.box_thick > 0) and S.box_thick or th
        local bcol = (S.box_color_mode == "Custom") and col(S.box_color) or color
        local btr = S.box_trans
        local corners = (S.box_style == "Corners")
        -- fill: a plain rectangle behind the lines
        if S.box_fill then
            o.boxFill.Position = UDim2.fromOffset(x0, y0)
            o.boxFill.Size = UDim2.fromOffset(w, h)
            o.boxFill.BackgroundColor3 = S.box_fill_player and color or col(S.box_fill_c)
            o.boxFill.BackgroundTransparency = S.box_fill_trans
            o.boxFill.Visible = true
        else
            o.boxFill.Visible = false
        end
        if not corners then
            o.box.Position = UDim2.fromOffset(x0, y0)
            o.box.Size = UDim2.fromOffset(w, h)
            o.boxStroke.Color = bcol
            o.boxStroke.Thickness = bth
            o.boxStroke.Transparency = btr
            o.box.Visible = true
            if S.box_outline then   -- a black stroke, wider than the line, drawn behind it
                o.boxOut.Position = UDim2.fromOffset(x0, y0)
                o.boxOut.Size = UDim2.fromOffset(w, h)
                o.boxOutStroke.Thickness = bth + 2
                o.boxOutStroke.Transparency = btr
                o.boxOut.Visible = true
            else
                o.boxOut.Visible = false
            end
            if o.cr then
                for i = 1, 8 do
                    o.cr[i].Visible = false
                    o.crOut[i].Visible = false
                end
            end
        else
            o.box.Visible = false
            o.boxOut.Visible = false
            if not o.cr then   -- the corner segments (and their outlines) are only created when this style is used
                o.cr, o.crOut = {}, {}
                for i = 1, 8 do
                    o.crOut[i] = new("Frame", {BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Visible = false}, overlay)
                end
                for i = 1, 8 do
                    o.cr[i] = new("Frame", {BorderSizePixel = 0, Visible = false}, overlay)
                end
            end
            local len = math.max(math.floor(math.min(w, h) * S.box_corner / 100), 3)
            -- each corner = one horizontal and one vertical segment: {x, y, width, height}
            local segs = {
                {x0, y0, len, bth}, {x0, y0, bth, len},
                {x1 - len, y0, len, bth}, {x1 - bth, y0, bth, len},
                {x0, y1 - bth, len, bth}, {x0, y1 - len, bth, len},
                {x1 - len, y1 - bth, len, bth}, {x1 - bth, y1 - len, bth, len},
            }
            for i, sg in ipairs(segs) do
                local f = o.cr[i]
                f.Position = UDim2.fromOffset(sg[1], sg[2])
                f.Size = UDim2.fromOffset(sg[3], sg[4])
                f.BackgroundColor3 = bcol
                f.BackgroundTransparency = btr
                f.Visible = true
                local g = o.crOut[i]
                if S.box_outline then
                    g.Position = UDim2.fromOffset(sg[1] - 1, sg[2] - 1)
                    g.Size = UDim2.fromOffset(sg[3] + 2, sg[4] + 2)
                    g.BackgroundTransparency = btr
                    g.Visible = true
                else
                    g.Visible = false
                end
            end
        end
    else
        o.box.Visible = false
        o.boxOut.Visible = false
        o.boxFill.Visible = false
        if o.cr then
            for i = 1, 8 do
                o.cr[i].Visible = false
                o.crOut[i].Visible = false
            end
        end
    end

    if S.esp_name then
        local nm = (S.esp_namemode == "Display") and p.DisplayName or p.Name
        if S.name_team and p.Team then nm = "[" .. p.Team.Name .. "] " .. nm end
        local l = o.name
        l.Text = nm
        l.TextColor3 = (S.name_color_mode == "Custom") and col(S.name_color) or color
        l.TextSize = math.max((S.name_size > 0) and S.name_size or S.esp_text, 1)
        l.Font = fontOf(S.name_font)
        l.TextStrokeTransparency = S.name_stroke
        l.Position = UDim2.fromOffset(x0 + w / 2, y0 - S.name_offset)
        l.Visible = true
    else
        o.name.Visible = false
    end

    if S.esp_dist then
        local fmts = UNIT_FMT[S.esp_unit] or UNIT_FMT.Studs
        local txt = string.format(fmts[math.clamp(math.floor(S.dist_decimals), 0, 2)], (S.esp_unit == "Meters") and dist * 0.28 or dist)
        if S.dist_brackets then txt = "[" .. txt .. "]" end
        local l = o.dist
        l.Text = txt
        l.TextColor3 = (S.dist_color_mode == "Custom") and col(S.dist_color) or color
        l.TextSize = math.max((S.dist_size > 0) and S.dist_size or S.esp_text, 1)
        l.Font = fontOf(S.dist_font)
        l.TextStrokeTransparency = S.dist_stroke
        l.Position = UDim2.fromOffset(x0 + w / 2, y1 + S.dist_offset)
        l.Visible = true
    else
        o.dist.Visible = false
    end

    -- health bar: every setting of it is in Visual > ESP > Health bar
    local hpVisible = false
    if S.esp_health then
        local real = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        if S.hp_show_below >= 100 or real * 100 <= S.hp_show_below then
            hpVisible = true
            -- smoothing: the drawn ratio follows the real one (0% = instantly)
            local ratio = real
            if S.hp_smooth > 0 and o.hpR then
                ratio = o.hpR + (real - o.hpR) * (1 - (S.hp_smooth / 100) ^ (espDt * 60))
            end
            o.hpR = ratio

            -- geometry: left / right = vertical bar, top / bottom = horizontal bar
            local bt, gap, frac, side = S.hp_width, S.hp_gap, S.hp_len / 100, S.hp_side
            local pad = math.max(math.min(S.hp_pad, math.floor((bt - 1) / 2)), 0)
            local vertical = (side == "Left" or side == "Right")
            local bx, by, bw, bh
            if vertical then
                bw, bh = bt, h * frac + 2
                by = y0 + (h - h * frac) / 2 - 1
                bx = (side == "Left") and (x0 - gap - bt) or (x0 + w + gap)
            else
                bw, bh = w * frac + 2, bt
                bx = x0 + (w - w * frac) / 2 - 1
                if side == "Top" then
                    by = y0 - gap - bt - (S.esp_name and (S.esp_text + 3) or 0)   -- above the name when it is shown
                else
                    by = y1 + gap + (S.esp_dist and (S.esp_text + 3) or 0)        -- under the distance when it is shown
                end
            end
            bx, by, bw, bh = math.floor(bx + 0.5), math.floor(by + 0.5), math.floor(bw + 0.5), math.floor(bh + 0.5)
            o.hpBack.Position = UDim2.fromOffset(bx, by)
            o.hpBack.Size = UDim2.fromOffset(bw, bh)
            o.hpBack.BackgroundColor3 = col(S.hp_back_c)
            o.hpBack.BackgroundTransparency = S.hp_back_trans
            o.hpStroke.Enabled = S.hp_outline
            o.hpStroke.Color = col(S.hp_outline_c)
            local rad = UDim.new(0, S.hp_corner)
            o.hpBackCorner.CornerRadius = rad
            o.hpCorner.CornerRadius = rad

            -- fill (grows from the bottom for a vertical bar, from the left for a horizontal one)
            local innerW, innerH = math.max(bw - pad * 2, 1), math.max(bh - pad * 2, 1)
            if vertical then
                o.hp.AnchorPoint = Vector2.new(0.5, 1)
                o.hp.Position = UDim2.new(0.5, 0, 1, -pad)
                o.hp.Size = UDim2.fromOffset(innerW, innerH * ratio)
            else
                o.hp.AnchorPoint = Vector2.new(0, 0.5)
                o.hp.Position = UDim2.new(0, pad, 0.5, 0)
                o.hp.Size = UDim2.fromOffset(innerW * ratio, innerH)
            end
            local mode, fillC = S.hp_color_mode, nil
            if mode == "Two colors" then
                fillC = col(S.hp_low):Lerp(col(S.hp_high), ratio)
            elseif mode == "Solid" then
                fillC = col(S.hp_solid)
            elseif mode == "Player color" then
                fillC = color
            else
                fillC = Color3.fromHSV(ratio * 0.33, 0.85, 1)   -- red to green
            end
            o.hp.BackgroundColor3 = fillC

            -- segments
            local segs = S.hp_segments
            for i, tk in ipairs(o.hpTicks) do
                if i < segs then
                    tk.BackgroundColor3 = col(S.hp_back_c)
                    if vertical then
                        tk.AnchorPoint = Vector2.new(0, 0.5)
                        tk.Position = UDim2.new(0, 0, i / segs, 0)
                        tk.Size = UDim2.new(1, 0, 0, 1)
                    else
                        tk.AnchorPoint = Vector2.new(0.5, 0)
                        tk.Position = UDim2.new(i / segs, 0, 0, 0)
                        tk.Size = UDim2.new(0, 1, 1, 0)
                    end
                    tk.Visible = true
                else
                    tk.Visible = false
                end
            end

            -- text
            local tl = o.hpText
            if S.hp_text then
                local txt
                if S.hp_text_mode == "Percent" then
                    txt = string.format("%d%%", math.floor(real * 100 + 0.5))
                elseif S.hp_text_mode == "Health / Max" then
                    txt = string.format("%d/%d", math.floor(hum.Health + 0.5), math.floor(hum.MaxHealth + 0.5))
                else
                    txt = string.format("%d", math.floor(hum.Health + 0.5))
                end
                local ts = math.max(S.hp_text_size, 1)
                tl.Text = txt
                tl.TextSize = ts
                tl.TextColor3 = S.hp_text_fill and fillC or col(S.hp_text_c)
                if vertical then
                    local ty = S.hp_text_follow and (by + pad + innerH * (1 - ratio)) or (by + bh / 2)
                    ty = math.clamp(ty, by + ts / 2, math.max(by + bh - ts / 2, by + ts / 2))
                    tl.AnchorPoint = Vector2.new(side == "Left" and 1 or 0, 0.5)
                    tl.Position = UDim2.fromOffset(side == "Left" and (bx - 3) or (bx + bw + 3), ty)
                    tl.TextXAlignment = (side == "Left") and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
                else
                    local tx = S.hp_text_follow and (bx + pad + innerW * ratio) or (bx + bw / 2)
                    tl.AnchorPoint = Vector2.new(0.5, side == "Top" and 1 or 0)
                    tl.Position = UDim2.fromOffset(tx, side == "Top" and (by - 2) or (by + bh + 2))
                    tl.TextXAlignment = Enum.TextXAlignment.Center
                end
                tl.Visible = true
            else
                tl.Visible = false
            end
            o.hpBack.Visible = true
        end
    end
    if not hpVisible then
        o.hpBack.Visible = false
        o.hpText.Visible = false
        o.hpR = nil
    end

    local head = ch:FindFirstChild("Head")
    o.head.Visible = false
    if S.esp_head and head then
        local hp = c:WorldToViewportPoint(head.Position)
        if hp.Z > 0 then
            local rp = c:WorldToViewportPoint(head.Position + c.CFrame.RightVector * (head.Size.Y * 0.5))
            local r = (Vector2.new(rp.X, rp.Y) - Vector2.new(hp.X, hp.Y)).Magnitude * (S.head_scale / 100)
            local hcol = (S.head_color_mode == "Custom") and col(S.head_color) or color
            o.head.Position = UDim2.fromOffset(hp.X, hp.Y)
            o.head.Size = UDim2.fromOffset(r * 2, r * 2)
            o.headStroke.Color = hcol
            o.headStroke.Thickness = (S.head_thick > 0) and S.head_thick or th
            o.headStroke.Transparency = S.head_trans
            if S.head_fill then
                o.head.BackgroundColor3 = S.head_fill_player and hcol or col(S.head_fill_c)
                o.head.BackgroundTransparency = S.head_fill_trans
            else
                o.head.BackgroundTransparency = 1
            end
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
        local sth = (S.skel_thick > 0) and S.skel_thick or th
        local scol = (S.skel_color_mode == "Custom") and col(S.skel_color) or color
        local str = S.skel_trans
        for i, l in ipairs(o.lines) do
            local pair = map[i]
            local a = pair and proj(pair[1])
            local b = pair and proj(pair[2])
            if a and b then
                local d = b - a
                l.Size = UDim2.fromOffset(d.Magnitude, sth)
                l.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
                l.Rotation = math.deg(math.atan2(d.Y, d.X))
                l.BackgroundColor3 = scol
                l.BackgroundTransparency = str
                l.Visible = true
            else
                l.Visible = false
            end
        end
        -- joints: a dot at every bone end (created the first time they are used)
        if S.skel_joints then
            if not o.joints then
                o.joints = {}
                for i = 1, 15 do
                    local j = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false}, overlay)
                    new("UICorner", {CornerRadius = UDim.new(1, 0)}, j)
                    o.joints[i] = j
                end
            end
            local k, seen = 0, {}
            for _, pair in ipairs(map) do
                for n = 1, 2 do
                    local name = pair[n]
                    if not seen[name] then
                        seen[name] = true
                        local v = proj(name)
                        if v and k < 15 then
                            k = k + 1
                            local j = o.joints[k]
                            j.Position = UDim2.fromOffset(v.X, v.Y)
                            j.Size = UDim2.fromOffset(S.skel_joint_size, S.skel_joint_size)
                            j.BackgroundColor3 = scol
                            j.BackgroundTransparency = str
                            j.Visible = true
                        end
                    end
                end
            end
            for i = k + 1, 15 do o.joints[i].Visible = false end
        elseif o.joints then
            for _, j in ipairs(o.joints) do j.Visible = false end
        end
    else
        for _, l in ipairs(o.lines) do l.Visible = false end
        if o.joints then
            for _, j in ipairs(o.joints) do j.Visible = false end
        end
    end
end

function espUpdate(c, eye)
    local now = os.clock()
    espDt = espLast and math.min(now - espLast, 0.1) or 0.016
    espLast = now
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
            local hidden = LIST.isIgnored(p, true)
            if any and not hidden and hum and root and hum.Health > 0 and dist <= S.esp_maxdist
                and (S.esp_team or not team) then
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
end   -- end of the esp block
Loader.mark("Loading player modules")
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

    -- spinbot. Spin = continuous rotation; Jitter = alternates +-angle relative to the aim; Random = random yaw;
    -- Backwards = back turned to where the camera looks. "Velocity" uses BodyAngularVelocity (Spin mode only)
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
            -- shooting: the body turns back to where the camera aims, so the shot goes straight
            local look = cam.CFrame.LookVector
            root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
        end
    end

    -- bunny hop: jumps by itself when touching the ground while the mode condition holds; "Air speed" keeps the speed in the air
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

    -- fly: BodyVelocity holds the character in the air; direction = stick/WASD relative to the camera (with pitch)
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

end   -- end of the player block

local function noclipStep()
    if not S.noclip or unloading then return end
    local ch = LP.Character
    if not ch then return end
    for _, d in ipairs(ch:GetDescendants()) do
        if d:IsA("BasePart") and d.CanCollide then d.CanCollide = false end
    end
end
Loader.mark("Starting")
----------------------------------------------------------------------------
-- main loop (after the camera script, so the ESP reads the final camera)
----------------------------------------------------------------------------
-- third person: runs after the game's camera script and pushes the camera back along its own axes.
-- Since the offset is applied to the final CFrame, it works with the default camera and with a custom game camera.
-- Aim stays aligned: the target remains on the same line through the crosshair.
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
    if S.tp_collide and (pos - cf.Position).Magnitude > 0.05 then   -- no ray when the camera is not pushed back
        tpParams.FilterDescendantsInstances = Vis.filter(c)
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
    local eye = c.CFrame.Position   -- real eye position (before third person), used for distances
    rayParams.FilterDescendantsInstances = Vis.filter(c)   -- players are never walls

    if selfAlive("aim") then aimUpdate(c, dt, org) end
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

    local touchAim = S.aim_button and S.aim_mode ~= "Always" and UIS.TouchEnabled and (S.aimbot or S.aim_mode == "Toggle")
    updateAim(touchAim and true or false, aimOn())

    espUpdate(c, eye)
    CH.update(dt, c, eye)

    statusClock = statusClock + dt
    if statusClock > 0.15 then
        statusClock = 0
        local s = TR.state .. (TR.note ~= "" and ("  |  " .. TR.note) or "")
        if trigStatus.Text ~= s then trigStatus.Text = s end
        updateQuick()
    end
end

-- FOV changer: applied in the LAST render step, after any game camera script. Only writes when the value
-- differs and restores the original FOV when turned off. (It used to run on Heartbeat and fought the game, shaking the camera.)
local fovBase
local function fovStep()
    local cam = Workspace.CurrentCamera
    if not cam then return end
    if S.camfov_on and not unloading then
        if not fovBase then fovBase = cam.FieldOfView end
        local fov = math.max(S.camfov, 1)   -- Roblox does not accept a field of view of 0
        if math.abs(cam.FieldOfView - fov) > 0.01 then cam.FieldOfView = fov end
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
-- input / events
----------------------------------------------------------------------------
conn(UIS.InputBegan:Connect(function(i)
    if UIS:GetFocusedTextBox() then return end
    if matches(i, S.ui_key) then win.Visible = not win.Visible end
    if matches(i, S.tp_key) then
        S.tp_on = not S.tp_on
        refreshAll()
    end
    if matches(i, S.aim_key) then
        if S.aim_mode == "Toggle" then
            S.aimbot = not S.aimbot   -- the key flips the aimbot switch itself, so the menu and the FOV circle follow it
            refreshAll()
        else
            aimHeld = true
        end
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
    pcall(Loader.destroy)
    pcall(function() gui:Destroy() end)
    pcall(function() overlay:Destroy() end)
    ENV.__RAGWARE_UNLOAD = nil
end
ENV.__RAGWARE_UNLOAD = unload

----------------------------------------------------------------------------
-- start
----------------------------------------------------------------------------
selectTab("Combat")
layout()
