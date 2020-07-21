io.stdout:setvbuf("no") -- Buffered output can act oddly on Windows

-- CONSTANTS --
_G.EDITOR_MODE = false
_G.DEBUG = false

local FRAME_TIME = 1 / 60
local STEP = 1 / 60
local MAX_ACCUM = FRAME_TIME * 5
local MAX_LOOP = 500

-- LOCAL FUNCTIONS --
local function get_imgui_dt()
    return FRAME_TIME
end

-- LIBRARIES
local input = require("input")
local lily

-- These 3 register themselves into the existing corresponding globals
require("enginelib.strong") -- Extensions to string library
require("enginelib.tableutil") -- Extensions to table library
require("enginelib.mathplus") -- Extensions to math library

utf8 = require("utf8") -- utf8 lib not loaded by default
vec2 = require("enginelib.vec2") -- 2d vectors

-- MISC SETUP --
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
        require("enginelib.log").warn(("C Type defined at %s, please rewrite binser registration"):format(lineinfo))
        return cdef(...)
    end

end

-- CALLBACKS --
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
        accum = math.min(accum + dt, MAX_ACCUM)
        
        if accum >= FRAME_TIME then
            -- Run updates until the accumulated time is less than the frame time
            while accum >= FRAME_TIME do
            
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
                
                if love.update then love.update(STEP) end
                accum = accum - FRAME_TIME
            end
            
            -- Draw once every update cycle
            if love.graphics.isActive() then
                love.graphics.clear(love.graphics.getBackgroundColor())
                love.graphics.origin()
                if love.draw then love.draw() end
                love.graphics.present()
            end
        end
        
        if love.timer then love.timer.sleep(1 / MAX_LOOP) end
    end
end

local main

--[[  
    TODO: Engine configuration file, to specify things such as
    viewport size, default scene, etc
]]--

function love.load(args, unfiltered_args)

    -- Check if editor or debug is enabled	
    for i, a in ipairs(args) do
        if a == "-editor" then
            _G.EDITOR_MODE = true
        elseif a == "-debug" then
            _G.DEBUG = true
		end
    end
    
    if _G.EDITOR_MODE then
        print("Starting Editor Mode")
        assert(not love.filesystem.isFused(), "Editor mode can only be used in unfused mode")
    end

    love.filesystem.setIdentity("CoffeeEngine")

    -- TODO: Load window settings from a file
    local window_settings = {}
    window_settings.title = "CoffeeEngine"
    window_settings.icon = nil
    window_settings.width = 640
    window_settings.height = 360
    window_settings.borderless = false
    window_settings.centered = true
    window_settings.resizable = true
    window_settings.minwidth = 640
    window_settings.minheight = 360
    window_settings.fullscreen = false
    window_settings.fullscreentype = "desktop"
    window_settings.vsync = 0
    window_settings.msaa = 0
    window_settings.depth = nil
    window_settings.stencil = nil
    window_settings.display = 1
    window_settings.highdpi = false
    window_settings.usedpiscale = false
    window_settings.x = nil
    window_settings.y = nil
    
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
    if _G.EDITOR_MODE then
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
    require("res")
    
    local SceneTree = require("class.engine.SceneTree")
    
    main = SceneTree()
    
    -- If editor mode enabled, main is the editor
    if _G.EDITOR_MODE then
        main:get_viewport():set_resolution( love.graphics.getDimensions() )
        main:get_viewport():set_background_color({0.2, 0.2, 0.25, 1})
        main:set_scale_mode("free")
        main:set_root( require("class.editor.Editor")())
        
    else -- Otherwise, it's the main game scene
        main:set_scale_mode("perfect")
        main:get_viewport():set_resolution(416, 240) 
        -- main:set_root( load main scene )
    end
    
    -- Load input bindings
    --[[input.add_action("foo")
    input.action_add_bind("foo", "keyboard", "a")
    input.action_add_bind("foo", "joystick", 1)
    input.action_add_bind("foo", "joystick", "axis1+")
    input.action_add_bind("foo", "joystick", "l1")
    ]]--

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

    if _G.DEBUG then
        -- Print debug info
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
        
        local x = 10
        local y = love.graphics.getHeight() - 22
        
        for i = 1, #info do
            love.graphics.print(info[#info - i + 1], x, y - (i - 1) * 15)
        end
    end

    if imgui then
        -- Newest version of imgui seems to have random errors in drawlist,
        -- pcall render so we don't crash
        local ok, err = pcall(imgui.Render)
        local log = require("enginelib.log")
        if err then log.error(err) end
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
    
    if input.keypressed then
        input:keypressed(key, scan, isrepeat)
    end
    
    if main.keypressed then
        main:keypressed(key, scan, isrepeat)
    end

end

function love.keyreleased(key, scan)
    if imgui then
        imgui.KeyReleased(key)
        if imgui.GetWantCaptureKeyboard() then return end
    end
    
    if input.keyreleased then
        input:keyreleased(key, scan)
    end
    
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
        if input[callback] then input[callback](...) end
        
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
    if _G.EDITOR_MODE then
        main:get_viewport():set_resolution(w, h)
    end
end

function love.quit()
    if imgui then
        imgui.ShutDown()
    end
    
    lily.quit()
end