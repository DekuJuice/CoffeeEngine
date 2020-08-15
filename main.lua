io.stdout:setvbuf("no") -- Buffered output can act oddly on Windows

-- CONSTANTS --
require("errorhandler")
settings = require("settings")
log = require("enginelib.log")

local frame_time = settings.get_setting("frame_time")
local max_accum = settings.get_setting("max_accum") * frame_time
local max_loop = settings.get_setting("max_loop")

-- LOCAL FUNCTIONS --
local function get_imgui_dt()
    return frame_time
end

local function plot_time_graph(buffer, w, h, max_h)
    local c = buffer:get_count()
    if c < 1 then return end

    local prev = buffer:at(-1)
    for x = 1, w - 1 do
        local s = buffer:at(-(math.floor( x / w * c ) + 1))


        love.graphics.line(x - 1,  h - prev / max_h * h,  x, h - s / max_h * h)
        prev = s

    end
end

-- Need to require classes first for them to deserialize properly
local function preload_class(dir)
    for _,v in ipairs(love.filesystem.getDirectoryItems(dir)) do
        local path = dir .. "/" .. v
        local info = love.filesystem.getInfo(path)
        if info.type == "directory" then
            preload_class(path)
        else
            require(path:match("^[^%.]+"):gsub("/", "."))
        end
    end
end

-- LIBRARIES
input = require("input")
local circularbuffer = require("enginelib.circularbuffer")
local lily

-- These 3 register themselves into the existing corresponding globals
require("enginelib.strong") -- Extensions to string library
require("enginelib.tableutil") -- Extensions to table library
require("enginelib.mathplus") -- Extensions to math library

utf8 = require("utf8") -- utf8 lib not loaded by default
vec2 = require("enginelib.vec2") -- 2d vectors
bit = require("bit") -- Luajit bitop library

-- MISC SETUP --

-- Override print to store console output

do
    _G.CONSOLE_OUTPUT = circularbuffer.new(1000)

    local old_print = print
    -- Output is stored in a circular buffer, _G.CONSOLE_BUFFER_TOP indicates the front

    print = function(...) 
        old_print(...)

        local str = table.pack(...)
        for i = 1, str.n do
            str[i] = tostring(str[i])
        end

        local ostr = table.concat(str, " ")
        local timestamp = os.clock()
        _G.CONSOLE_OUTPUT:push({ostr, timestamp})      
    end
end

do -- Register custom (non-class) types to binser
    -- Classes have their registration handled by the Object class
    local binser = require("enginelib.binser")

    -- Right now, vec2 is our only custom cdata struct, so we just
    -- assume all cdata types are vec2s. 

    -- This will need to be rewritten if any other cdata types are defined.
    binser.register("ffi", "ffi", 
        function(v2)
            return v2.x, v2.y
        end,
        function(x, y)
            return vec2(x, y)
        end
    )

    local ffi = require("ffi")
    local cdef = ffi.cdef
    function ffi.cdef(...) -- Warn if we define any more ctypes
        local info = debug.getinfo(2, "Sl")
        local lineinfo = info.short_src .. ":" .. info.currentline
        log.warn(("C Type defined at %s, please rewrite binser registration"):format(lineinfo))
        return cdef(...)
    end

end

-- CALLBACKS --

local update_times = circularbuffer.new(180)
local draw_times = circularbuffer.new(180)

function love.run()
    love.math.setRandomSeed(os.time())
    love.load(love.arg.parseGameArguments(arg), arg)
    -- We don't want the first frame's dt to include time taken by love.load.
    love.timer.step()

    local dt = 0
    local accum = 0

    -- Main loop
    return function()
        -- Update dt, as we'll be passing it to update
        love.timer.step()
        dt = love.timer.getDelta()
        accum = math.min(accum + dt, max_accum)

        if accum >= frame_time then
            -- Run updates until the accumulated time is less than the frame time
            while accum >= frame_time do

                input.reset_state() -- Called before events are processed to reset pressed/released states

                -- Propagate event callbacks
                love.event.pump()
                for name, a,b,c,d,e,f in love.event.poll() do
                    if name == "quit" then
                        if not love.quit or not love.quit() then
                            return a or true
                        end
                    end
                    love.handlers[name](a,b,c,d,e,f)
                end

                local u_time = os.clock()

                if love.update then love.update(frame_time) end
                update_times:push(os.clock() - u_time)

                accum = accum - frame_time
            end

            -- Draw once every update cycle
            if love.graphics.isActive() then
                love.graphics.clear(love.graphics.getBackgroundColor())
                love.graphics.origin()


                local d_time = os.clock()

                if love.draw then love.draw() end                

                draw_times:push(os.clock() - d_time)

                love.graphics.present()
            end
        end

        if love.timer then love.timer.sleep(1 / max_loop) end
    end
end

local main

function love.load(args, unfiltered_args)

    for i, a in ipairs(args) do
        if a == "-editor" then
            settings.set_setting("is_editor", true)
        elseif a == "-debug" then
            settings.set_setting("is_debug", true)
            --require("mobdebug").start()
        end
    end

    if settings.get_setting("is_editor") then
        log.info("Starting Editor Mode")
        -- Editor must be run in unfused mode as we write files directly into the game directory,
        -- which we cannot do in fused mode
        assert(not love.filesystem.isFused(), "Editor mode can only be used in unfused mode")
    end

    love.filesystem.setIdentity("CoffeeEngine")

    -- Load config file
    local inifile = require("enginelib.inifile")
    local ok, res = pcall(inifile.parse, settings.get_setting("config_file"))

    if ok then
        for _, section in pairs(res) do
            for k,v in pairs(section) do
                settings.set_setting(k, v)
            end
        end
    else
        log.info(res)
    end

    local window_settings = {}
    window_settings.title = settings.get_setting("title")
    window_settings.icon = settings.get_setting("icon")
    window_settings.width = settings.get_setting("window_width")
    window_settings.height = settings.get_setting("window_height")
    window_settings.borderless = settings.get_setting("borderless")
    window_settings.centered = settings.get_setting("centered")
    window_settings.resizable = settings.get_setting("resizable")
    window_settings.minwidth = settings.get_setting("game_width")
    window_settings.minheight = settings.get_setting("game_height")
    window_settings.fullscreen = settings.get_setting("fullscreen")
    window_settings.fullscreentype = settings.get_setting("fullscreen_type")
    window_settings.vsync = settings.get_setting("vsync")
    window_settings.msaa = settings.get_setting("msaa")
    window_settings.depth = settings.get_setting("depth")
    window_settings.stencil = settings.get_setting("stencil")
    window_settings.display = settings.get_setting("display")
    window_settings.highdpi = settings.get_setting("highdpi")
    window_settings.usedpiscale = settings.get_setting("usedpiscale")
    window_settings.x = settings.get_setting("window_x")
    window_settings.y = settings.get_setting("window_y")

    -- WINDOW CREATED HERE, DO NOT CALL ANY GRAPHICS FUNCTIONS BEFORE THIS POINT --
    -- Create the window manually to avoid ugly resizing from default resolution
    require("love.window")
    assert(love.window.setMode(window_settings.width, window_settings.height,
            {
                fullscreen = window_settings.fullscreen,
                fullscreentype = window_settings.fullscreentype,
                vsync = window_settings.vsync,
                msaa = window_settings.msaa,
                stencil = window_settings.stencil,
                depth = window_settings.depth,
                resizable = window_settings.resizable,
                minwidth = window_settings.minwidth,
                minheight = window_settings.minheight,
                borderless = window_settings.borderless,
                centered = window_settings.centered,
                display = window_settings.display,
                highdpi = window_settings.highdpi,
                --usedpiscale = window_settings.usedpiscale,
                x = window_settings.x,
                y = window_settings.y

                }), "Could not open window")

    love.window.setTitle(window_settings.title)
    if window_settings.icon then
        love.window.setIcon(window_settings.icon)
    end

    -- Editor specific stuff
    if settings.get_setting("is_editor") then
        love.window.maximize()
        -- Load IMGUI
        _G.imgui = require("imgui")

        -- Font loading needs to be done before Init as that's when the
        -- font atlas is built
        imgui.AddFontFromFileTTF("engineres/Vera.ttf", 18)
        imgui.AddFontFromFileTTF("engineres/Feather.ttf", 16, true, {0xf100, 0xf21d, 0})

        _G.IconFont = require("engineres/IconFontConstants")
        for k,v in pairs(IconFont) do
            IconFont[k] = utf8.char(v)
        end

        imgui.Init()
        imgui.SetReturnValueLast(false)
        imgui.PushStyleVar("ImGuiStyleVar_WindowRounding", 3)
        imgui.PushStyleVar("ImGuiStyleVar_FrameRounding", 3)
        imgui.PushStyleVar("ImGuiStyleVar_WindowBorderSize", 1)
        imgui.PushStyleVar("ImGuiStyleVar_FrameBorderSize", 1)
    end

    love.graphics.setDefaultFilter("nearest")

    -- Initialize lily, needs to be done after love modules are loaded
    lily = require("enginelib.lily")

    -- Init resource manager, this registers some global functions for 
    -- managing resources
    resource = require("res")

    local SceneTree = require("class.engine.SceneTree")

    main = SceneTree()

    preload_class("class/engine")
    preload_class("class/game")

    -- If editor mode enabled, root is the editor
    if settings.get_setting("is_editor") then
        preload_class("class/engine")
    
        main:get_viewport():set_resolution( love.graphics.getDimensions() )
        main:get_viewport():set_background_color({0.2, 0.2, 0.25, 1})
        main:set_scale_mode("free")
        main:set_root( require("class.editor.Editor")())

    else -- Otherwise, it's the main game scene
        main:set_scale_mode( settings.get_setting("upscale_mode") )
        main:get_viewport():set_resolution(
            settings.get_setting("game_width"),
            settings.get_setting("game_height")
        )

        local mscene = resource.get_resource( settings.get_setting("main_scene") )
        assert(mscene ~= nil, "No main scene!")
        main:set_root(mscene:instance())
    end

    -- Load input bindings
    input.add_action("left")
    input.action_add_bind("left", "keyboard", "left")

    input.add_action("right")
    input.action_add_bind("right", "keyboard", "right")

    input.add_action("up")
    input.action_add_bind("up", "keyboard", "up")

    input.add_action("down")
    input.action_add_bind("down", "keyboard", "down")

    input.add_action("jump")
    input.action_add_bind("jump", "keyboard", "z")

    input.add_action("dash")
    input.action_add_bind("dash", "keyboard", "lshift")

    -- Catch stray globals
    setmetatable(_G, {__newindex = function(self,k,v) error(("Stray global declared '%s'"):format(k)) end})
end

function love.update(dt)
    if main.update then
        main:update(dt)
    end
end

function love.draw()
    if imgui then
        -- Dumb hack to get correct dt passed to imgui, since
        -- we are using a non-standard main loop where 
        -- getDelta does not actually reflect how long a "frame" takes
        local old_gd = love.timer.getDelta
        love.timer.getDelta = get_imgui_dt        
        imgui.NewFrame()
        love.timer.getDelta = old_gd
    end

    if main.draw then
        main:draw(0, 0, love.graphics.getDimensions())
    end

    if imgui then
        -- Newest version of imgui seems to have random errors in drawlist,
        -- pcall render so we don't crash
        local ok, err = pcall(imgui.Render)
        if err then log.error(err) end
    end

    if settings.get_setting("is_debug") then
        local font = love.graphics.getFont()

        local fps = love.timer.getFPS()
        local gstats = love.graphics.getStats()
        local luamem = collectgarbage("count")

        local info = {
            ("FPS: %d"):format(fps),
            ("Draw Calls: %d"):format(gstats.drawcalls),
            ("Batched Calls: %d"):format(gstats.drawcallsbatched),
            ("Shader Switches: %d"):format(gstats.shaderswitches),
            ("Texture Memory: %d mb"):format(gstats.texturememory / 1024 / 1024),
            ("Lua Memory: %d kb"):format(luamem)
        }

        local info_str = table.concat(info, "\n")

        local tx = 10
        local ty = 10
        local tw = font:getWidth(info_str)
        local th = #info * font:getHeight() * font:getLineHeight()

        love.graphics.print(info_str, tx, love.graphics.getHeight() - th - ty)

        local gw = 200
        local gh = 90

        love.graphics.push("all")
        love.graphics.translate(tx + tw + 10, love.graphics.getHeight() - gh - 10)
        love.graphics.rectangle("line", 0, 0, gw, gh)
        love.graphics.setColor(1,0,0)
        plot_time_graph(update_times, gw, gh, frame_time)
        love.graphics.setColor(0,1,0)
        plot_time_graph(draw_times, gw, gh, frame_time)
        love.graphics.pop()

    end

end

function love.mousepressed(x, y, button, is_touch, presses)
    if imgui then
        imgui.MousePressed(button)
        if imgui.GetWantCaptureMouse() then return end
    end

    if main.mousepressed then
        main:mousepressed(x, y, button, is_touch, presses)
    end
end

function love.mousereleased(x, y, button, is_touch, presses)
    if imgui then
        imgui.MouseReleased(button)
        if imgui.GetWantCaptureMouse() then return end
    end

    if main.mousereleased then
        main:mousereleased(x, y, button, is_touch, presses)
    end
end

function love.mousemoved(x, y, dx, dy, is_touch)
    if imgui then
        -- Passing true prevents things from behaving oddly when the mouse drags something
        -- out the window
        -- no clue why it occurs or what the bool is even doing
        imgui.MouseMoved(x, y, true)
        if imgui.GetWantCaptureMouse() then return end
    end

    if main.mousemoved then
        main:mousemoved(x, y, dx, dy, is_touch)
    end
end

function love.textinput(text) 
    if imgui then
        imgui.TextInput(text)
        if imgui.GetWantCaptureKeyboard() then return end
    end

    if main.textinput then
        main:textinput(text) 
    end
end

function love.wheelmoved(dx, dy)
    if imgui then
        imgui.WheelMoved(dy)
        if imgui.GetWantCaptureMouse() then return end
    end

    local mx, my = love.mouse.getPosition()    
    if main.wheelmoved then
        main:wheelmoved(mx, my, dx, dy)
    end
end

function love.keypressed(key, scan, isrepeat)

    if imgui then
        imgui.KeyPressed(key)
        if imgui.GetWantCaptureKeyboard() then return end
    end

    input.keypressed(key, scan, isrepeat)

    if main.keypressed then
        main:keypressed(key, scan, isrepeat)
    end

end

function love.keyreleased(key, scan)
    if imgui then
        imgui.KeyReleased(key)
        if imgui.GetWantCaptureKeyboard() then return end
    end

    input.keyreleased(key, scan)

    if main.keyreleased then
        main:keyreleased(key, scan)
    end
end

for _, callback in ipairs({
        "joystickpressed",
        "joystickreleased",
        "joystickaxis",
        "joystickhat"
        }) do
    love[callback] = function(...)
        input[callback](...)

        if main[callback] then
            main[callback](main, ...)
        end
    end
end

function input.actionpressed(name)
    if main.actionpressed then main:actionpressed(name) end
end

function input.actionreleased(name)
    if main.actionreleased then main:actionreleased(name) end
end

function love.resize(w, h)
    if settings.get_setting("is_editor") then
        main:get_viewport():set_resolution(w, h)
    end
end

function love.quit()
    if imgui then
        imgui.ShutDown()
    end

    lily.quit()
end