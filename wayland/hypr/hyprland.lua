-- Canonical Hyprland 0.55+ configuration.
-- Keep this file as the single source of session behavior; hyprland.conf is legacy.

local terminal = "alacritty"
local fileManager = "alacritty -e yazi"
local menu = "rofi -show drun"
local mainMod = "SUPER"
local userBin = "$HOME/.local/bin"
local browser = userBin .. "/archcfg-firefox"
local screenshotDir = "$HOME/Pictures/screenshots"
local displayLayout = userBin .. "/hypr-display-layout"
local displayMenu = userBin .. "/hypr-display-menu"
local audioSelector = userBin .. "/hypr-audio-selector"

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "1",
})

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("GTK_THEME", "Adwaita-dark")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 3,
        border_size = 2,
        col = {
            active_border = "rgb(033e8c)",
            inactive_border = "rgba(595959aa)",
        },
        layout = "monocle",
    },
    decoration = {
        rounding = 0,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = { enabled = false },
        blur = { enabled = false },
    },
    animations = { enabled = false },
    dwindle = { preserve_split = true },
    master = { orientation = "left" },
    input = {
        kb_layout = "latam",
        follow_mouse = 2,
        numlock_by_default = true,
        touchpad = { natural_scroll = false },
    },
    cursor = { no_warps = true },
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
    },
})

for workspace = 1, 9 do
    hl.workspace_rule({ workspace = tostring(workspace), persistent = true })
end

local function applyDisplayLayout()
    hl.exec_cmd(displayLayout)
end

hl.on("hyprland.start", function()
    applyDisplayLayout()
    hl.exec_cmd(userBin .. "/hypr-waybar-start")
    hl.exec_cmd(userBin .. "/hypr-workspace-watch")
    hl.exec_cmd("mako")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_RUNTIME_DIR HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user start hyprsunset.service")
    hl.exec_cmd(userBin .. "/hyprsunset-apply-current")
end)

hl.on("monitor.added", applyDisplayLayout)
hl.on("monitor.removed", applyDisplayLayout)
hl.on("config.reloaded", applyDisplayLayout)

local function command(keys, value, options)
    hl.bind(keys, hl.dsp.exec_cmd(value), options)
end

-- Keep the familiar Qtile application and session bindings.
command(mainMod .. " + Return", terminal)
command(mainMod .. " + M", menu)
command(mainMod .. " + D", menu)
command(mainMod .. " + B", browser)
command(mainMod .. " + E", fileManager)
command(mainMod .. " + A", audioSelector)
hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.window.close())
command(mainMod .. " + L", "hyprlock")
command(mainMod .. " + Escape", "hyprlock")
command(mainMod .. " + SHIFT + L", "hyprctl reload")
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())

-- Native layout cycling keeps the visible Monocle window synchronized with focus.
hl.bind("ALT + Tab", hl.dsp.layout("cyclenext"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.layout("cycleprev"))
-- Keep Ctrl+Tab for application tabs, especially browsers such as Firefox.
hl.bind(mainMod .. " + CTRL + Tab", hl.dsp.layout("cyclenext"))
hl.bind(mainMod .. " + CTRL + SHIFT + Tab", hl.dsp.layout("cycleprev"))
hl.bind("ALT + Up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }))
hl.bind("ALT + Down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }))
hl.bind("ALT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind("ALT + SHIFT + Up", hl.dsp.window.move({ direction = "up" }))
hl.bind("ALT + SHIFT + Down", hl.dsp.window.move({ direction = "down" }))
command(mainMod .. " + Tab", userBin .. "/hypr-layout-cycle")
command(mainMod .. " + SHIFT + Tab", userBin .. "/hypr-layout-cycle")
hl.bind(mainMod .. " + comma", hl.dsp.focus({ monitor = "-1" }))
hl.bind(mainMod .. " + period", hl.dsp.focus({ monitor = "+1" }))

-- Preserve the useful directional Hyprland bindings without taking Super+L from locking.
hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
-- Keep pseudo-tiling available while using the conventional display-menu binding.
command(mainMod .. " + P", displayMenu)
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit"))

-- Nine global workspaces mirror the Qtile group model.
for workspace = 1, 9 do
    local workspaceName = tostring(workspace)
    hl.bind("ALT + " .. workspace, hl.dsp.focus({ workspace = workspaceName, on_current_monitor = true }))
    hl.bind("ALT + CTRL + " .. workspace, hl.dsp.window.move({ workspace = workspaceName, follow = false }))
    hl.bind(mainMod .. " + " .. workspace, hl.dsp.focus({ workspace = workspaceName, on_current_monitor = true }))
    hl.bind(mainMod .. " + SHIFT + " .. workspace, hl.dsp.window.move({ workspace = workspaceName, follow = false }))
end

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Hyprsunset is the Wayland-native Redshift replacement.
command(mainMod .. " + R", userBin .. "/hyprsunset-set temperature 3500")
command(mainMod .. " + SHIFT + R", userBin .. "/hyprsunset-set identity")

command(mainMod .. " + C", terminal .. " -e calcurse")
command("Print", "mkdir -p " .. screenshotDir .. " && grim " .. screenshotDir .. "/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png")
command("CTRL + Print", "grim - | wl-copy --type image/png")
command("SHIFT + Print", "mkdir -p " .. screenshotDir .. " && grim -g \"$(slurp)\" " .. screenshotDir .. "/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png")
command("CTRL + SHIFT + Print", "grim -g \"$(slurp)\" - | wl-copy --type image/png")
