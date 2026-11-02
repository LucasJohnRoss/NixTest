------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1200",
    position = "0x0",
    scale    = "1",
})


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "ghostty"
local fileManager = terminal .. " -e yazi"
local editor      = terminal .. " -e nvim"
local calculator  = "flatpak run io.github.Qalculate"
local systemInfo  = terminal .. " -e btop"
local passwordManager = "bitwarden-desktop"
local browser = "brave-origin"
local notion = "/home/lucas/.local/share/AppImages/Notion_Electron-2.4.1-x86_64.AppImage"

-- Noctalia shell IPC: every shell action is `noctalia msg <command>`
-- (list them with `noctalia msg --help`)
local noctalia = "noctalia msg "


-------------------
---- AUTOSTART ----
-------------------

-- Nothing to start here on NixOS. Everything that used to be exec'd is now a
-- systemd user service started with the UWSM session:
--   noctalia (bar, wallpaper, notifications, polkit agent, clipboard, idle/lock)
--                       -> programs.noctalia.systemd in configuration.nix
--   nm-applet, udiskie  -> home.nix section 7
--   xdg-desktop-portal-hyprland -> started on demand over D-Bus
--   blueman-applet      -> XDG autostart, run by UWSM
--
-- On a machine WITHOUT the systemd service (e.g. back on CachyOS), uncomment:
-- hl.on("hyprland.start", function ()
--     hl.exec_cmd("noctalia")
-- end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")


-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 2, -- Gap Between Windows
        gaps_out = 10, -- Gap Between Window and Screen Edge
        border_size = 3,
        col = {
            active_border   = { colors = {"rgba(ffffffff)"}, angle = 0 },
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding       = 0,
        active_opacity   = 0.95,
        inactive_opacity = 0.95,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
            new_optimizations = 0,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })

hl.config({
    dwindle = {
        preserve_split = true,
    },
})



----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 1,    -- Disabled
        disable_hyprland_logo   = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        --Keyboard
        kb_layout  = "gb",

        follow_mouse = 1,

        sensitivity = -0.2, --Mouse Sensitivity, -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = true,
            scroll_factor = 0.3,
        },
    },
})

-- use hyprctl devices to identify

---------------------
---- KEYBINDINGS ----
---------------------

--- General ---
local mainMod = "SUPER" -- Sets "Windows" key as main modifier
hl.bind(mainMod .. " + Q", hl.dsp.window.close())

--- Applications ---
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(editor))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(passwordManager))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(calculator, {float=true}))

--- Noctalia shell ---
hl.bind(mainMod .. " + R",         hl.dsp.exec_cmd(noctalia .. "panel-toggle launcher"))  -- was rofi -show drun
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(noctalia .. "panel-toggle clipboard")) -- clipboard history (was cliphist)
hl.bind(mainMod .. " + comma",     hl.dsp.exec_cmd(noctalia .. "settings-toggle"))        -- Noctalia settings window

--- Special Workspaces ---
--hl.bind("SUPER + SHIFT + code:201", hl.dsp.workspace.toggle_special("browserWorkspace")) -- SUPER+SHIFT+code:201 = Copilot Key
hl.bind(mainMod .. " + T", hl.dsp.workspace.toggle_special("systemInfoWorkspace"))
--hl.bind(mainMod .. " + N", hl.dsp.workspace.toggle_special("notionWorkspace"))

--- Actions ---
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + S", hl.dsp.layout("togglesplit"))    -- dwindle only
-- Lock with Noctalia's lock screen (was ~/.config/hypr/scripts/arm-lock.sh,
-- which drove hyprlock/hypridle)
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd(noctalia .. "session lock"))
hl.bind(mainMod .. " + escape", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle"}))

--- Screenshots (Noctalia; were hyprshot) ---
-- Each bind overrides the [shell.screenshot] defaults in noctalia/config.toml
-- for that one call, reproducing the old hyprshot behaviour:
-- the Super variants grab the focused monitor, plain Print a region;
-- without Shift → clipboard only, with Shift → file in ~/Images/Screenshots
-- (the folder is set as `directory` in noctalia/config.toml).
local toClipboard = "--copy-to-clipboard --no-save-to-file --no-annotate "
local toFile      = "--save-to-file --no-copy-to-clipboard --no-annotate "
hl.bind(mainMod .. " + Print",         hl.dsp.exec_cmd(noctalia .. "screenshot-fullscreen " .. toClipboard))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd(noctalia .. "screenshot-fullscreen " .. toFile))
hl.bind("Print",                       hl.dsp.exec_cmd(noctalia .. "screenshot-region " .. toClipboard))
hl.bind("SHIFT + Print",               hl.dsp.exec_cmd(noctalia .. "screenshot-region " .. toFile))
-- Region capture with Noctalia's annotation editor (arrows, blur, crop...)
hl.bind(mainMod .. " + CTRL + Print",  hl.dsp.exec_cmd(noctalia .. "screenshot-region --annotate"))

--- Windows ---
hl.bind(mainMod .. " + h",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + k",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + j",  hl.dsp.focus({ direction = "down" }))
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


--- Special Keys ---
-- Laptop multimedia keys for volume and LCD brightness.
-- Noctalia watches PipeWire and the backlight, so it shows its volume and
-- brightness OSD for these as well — no need to route them through its IPC.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Lid closure: no bind needed any more. logind suspends on lid close
-- (configuration.nix section 5) and Noctalia locks before the system sleeps
-- (`lock_before_suspend`). The old hyprlock bind also ran its own
-- `systemctl suspend`, which would have overridden suspend-then-hibernate.


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Noctalia's settings window floats at a usable size
hl.window_rule({
    name  = "noctalia-settings",
    match = { class = "dev.noctalia.Noctalia" },
    float = true,
    size  = { 1080, 920 },
})

-- Blur behind Noctalia's bar, panels, notifications and OSD, and leave their
-- animations to Noctalia (Hyprland's layer animations would double up)
hl.layer_rule({
    name  = "noctalia",
    match = {
        namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
    },
    no_anim      = true,
    ignore_alpha = 0.5,
    blur         = true,
    blur_popups  = true,
})

hl.workspace_rule({ workspace = "special:systemInfoWorkspace", on_created_empty = systemInfo })
--hl.workspace_rule({ workspace = "special:browserWorkspace", on_created_empty = browser })
--hl.workspace_rule({ workspace = "special:notionWorkspace", on_created_empty = notion })

