-- ReconTracks-Lyrics.lua
-- A companion script for ReconTracks that handles lyrics and chord storage
-- Version 1.0

local scriptName = "ReconTracks-Lyrics"
local version = "1.0"
local debug_enabled = false
local debug_messages = {}
local currentEditorSong = nil

-- Define the variables a and b that were missing
local a = scriptName  -- Script name for UI display
local b = version     -- Version number for UI display

function debug(message)
    table.insert(debug_messages, message)
    if debug_enabled then
        reaper.ShowConsoleMsg(message .. "\n")
    end
end

function toggleConsole()
    debug_enabled = not debug_enabled
    if debug_enabled then
        reaper.ShowConsoleMsg("\n--- " .. scriptName .. " Console Enabled ---\n")
        for _, msg in ipairs(debug_messages) do
            reaper.ShowConsoleMsg(msg .. "\n")
        end
        reaper.ShowConsoleMsg("\n")
    else
        reaper.ClearConsole()
    end
end

function ensureDirectoryExists(filePath)
    local dir = filePath:match("(.*[/\\])")
    if dir then
        local exists = reaper.file_exists(dir)
        if not exists then
            local success = reaper.RecursiveCreateDirectory(dir, 0)
            if not success then
                debug("Failed to create directory: " .. dir)
            else
                debug("Created directory: " .. dir)
            end
        end
    end
end

-- File paths
local lyricsFile = reaper.GetResourcePath() .. "\\Scripts\\ReconTracks\\song_lyrics.json"

-- Data storage
local currentSong = nil
local lyricsData = {}
-- Global context storage to ensure reference remains valid
_G.lyricsEditorContext = nil

function saveLyricsData()
    ensureDirectoryExists(lyricsFile)
    debug("Saving lyrics to: " .. lyricsFile)
    
    local json = "{\n"
    local count = 0
    for path, text in pairs(lyricsData) do
        if count > 0 then json = json .. ",\n" end
        
        -- Escape special characters
        local escapedPath = path:gsub("\\", "\\\\"):gsub('"', '\\"')
        local escapedText = text:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")
        
        json = json .. '  "' .. escapedPath .. '": "' .. escapedText .. '"'
        count = count + 1
    end
    json = json .. "\n}"
    
    local file = io.open(lyricsFile, "w")
    if file then
        file:write(json)
        file:close()
        debug("Successfully saved " .. count .. " lyrics entries")
        return true
    else
        debug("ERROR: Failed to save lyrics to file")
        return false
    end
end

function loadLyricsData()
    debug("Loading lyrics from: " .. lyricsFile)
    local file = io.open(lyricsFile, "r")
    if not file then
        debug("No lyrics file found, starting with empty collection")
        return false
    end
    
    local content = file:read("*all")
    file:close()
    
    lyricsData = {}
    for path, text in content:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
        -- Unescape special characters
        path = path:gsub('\\\\', '\\'):gsub('\\"', '"')
        text = text:gsub('\\n', '\n'):gsub('\\r', '\r'):gsub('\\"', '"')
        lyricsData[path] = text
    end
    
    debug("Loaded " .. getTableSize(lyricsData) .. " lyrics entries")
    return true
end

function getTableSize(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function getLyrics(songPath)
    return lyricsData[songPath] or ""
end

function setLyrics(songPath, text)
    lyricsData[songPath] = text
    saveLyricsData()
    debug("Set lyrics for " .. songPath)
end

function showLyricsEditor(path, name)
    if not path or path == "" then
        reaper.ShowMessageBox("No song selected", "ReconTracks Lyrics", 0)
        return
    end
    
    -- If there's already an editor open
    if _G.lyricsEditorContext then
        -- If it's the same song, just bring window to front (no need to reload)
        if currentEditorSong and currentEditorSong.path == path then
            debug("Same song selected, keeping current editor open: " .. path)
            return
        else
            -- Close the current editor before opening a new one
            debug("Closing previous editor before opening new one")
            if reaper.ImGui_DestroyContext then
                reaper.ImGui_DestroyContext(_G.lyricsEditorContext)
            else
                debug("Warning: ImGui_DestroyContext not available")
            end
            _G.lyricsEditorContext = nil
        end
    end
    
    -- Store reference to currently edited song
    currentEditorSong = {path=path, name=name}
    local lyrics = getLyrics(path)
    
    local ctx = reaper.ImGui_CreateContext(a..' Editor')
    _G.lyricsEditorContext = ctx
    
    local font = reaper.ImGui_CreateFont('monospace', 14)
    reaper.ImGui_Attach(ctx, font)
    
    local open = true
    local text = lyrics
    local width = 800
    local height = 600
    
    local function loop()
        if not open then
            -- Clean up when window is closed
            if reaper.ImGui_DestroyContext then
                reaper.ImGui_DestroyContext(ctx)
            else
                debug("Warning: ImGui_DestroyContext not available")
            end
            _G.lyricsEditorContext = nil
            currentEditorSong = nil
            return
        end
        
        local visible, opened = reaper.ImGui_Begin(ctx, a..': '..name, true)
        open = opened
        
        if visible then
            if reaper.ImGui_BeginMenuBar(ctx) then
                if reaper.ImGui_BeginMenu(ctx, "File") then
                    if reaper.ImGui_MenuItem(ctx, "Save", "Ctrl+S") then
                        setLyrics(currentEditorSong.path, text)
                        reaper.ShowMessageBox("Lyrics saved successfully", "ReconTracks Lyrics", 0)
                    end
                    
                    if reaper.ImGui_MenuItem(ctx, "Clear") then
                        if reaper.ShowMessageBox("Are you sure you want to clear all lyrics?", "Confirm Clear", 4) == 6 then
                            text = ""
                        end
                    end
                    
                    if reaper.ImGui_MenuItem(ctx, "Close") then
                        open = false
                    end
                    
                    reaper.ImGui_EndMenu(ctx)
                end
                
                if reaper.ImGui_BeginMenu(ctx, "Help") then
                    if reaper.ImGui_MenuItem(ctx, "About") then
                        reaper.ShowMessageBox(a.." v"..b.."\n\n"..
                            "A companion script for ReconTracks that stores lyrics and chords.\n\n"..
                            "Enter your lyrics and chords in the editor area.\n"..
                            "The text will be stored exactly as typed with all spacing and formatting preserved.\n\n"..
                            "Press Ctrl+S or use File > Save to save your changes.", "About "..a, 0)
                    end
                    
                    reaper.ImGui_EndMenu(ctx)
                end
                
                reaper.ImGui_EndMenuBar(ctx)
            end
            
            local w, h = reaper.ImGui_GetContentRegionAvail(ctx)
            reaper.ImGui_Text(ctx, "Enter lyrics and chords below. All formatting will be preserved exactly as typed.")
            reaper.ImGui_Text(ctx, "Press Ctrl+S to save or use the File menu.")
            
            reaper.ImGui_PushFont(ctx, font)
            changed, text = reaper.ImGui_InputTextMultiline(ctx, "##lyrics", text, w, h-50, reaper.ImGui_InputTextFlags_AllowTabInput())
            reaper.ImGui_PopFont(ctx)
            
            if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl()) then
                if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_S()) then
                    setLyrics(currentEditorSong.path, text)
                    reaper.ShowMessageBox("Lyrics saved successfully", "ReconTracks Lyrics", 0)
                end
            end
            
            reaper.ImGui_Separator(ctx)
            reaper.ImGui_Text(ctx, "Lines: "..countLines(text).."   Characters: "..#text)
            
            reaper.ImGui_End(ctx)
        end
        
        reaper.defer(loop)
    end
    
    reaper.defer(loop)
end

function isLyricsEditorOpen()
    return _G.lyricsEditorContext ~= nil
end

function closeLyricsEditor()
    if _G.lyricsEditorContext then
        -- Check if the ImGui function exists before calling it
        if reaper.ImGui_DestroyContext then
            reaper.ImGui_DestroyContext(_G.lyricsEditorContext)
        else
            -- Alternative cleanup if the function doesn't exist
            debug("Warning: ImGui_DestroyContext not available")
        end
        _G.lyricsEditorContext = nil
        currentEditorSong = nil
    end
end

function countLines(text)
    if not text or text == "" then return 0 end
    local count = 1
    for _ in text:gmatch("\n") do
        count = count + 1
    end
    return count
end

function init()
    debug("Initializing "..a.." v"..b)
    loadLyricsData()
    
    _G.ReconTracksLyrics = {
        showEditor = showLyricsEditor,
        getLyrics = getLyrics,
        setLyrics = setLyrics,
        isEditorOpen = isLyricsEditorOpen,
        closeEditor = closeLyricsEditor
    }
    
    local path = reaper.GetExtState("ReconTracks", "CurrentSongPath")
    local name = reaper.GetExtState("ReconTracks", "CurrentSongName")
    
    if path and path ~= "" then
        debug("Opening editor for: "..path)
        showLyricsEditor(path, name or "Unnamed Song")
    else
        reaper.ShowMessageBox(a.." v"..b.."\n\n"..
            "This script is designed to be launched from ReconTracks.\n\n"..
            "Please use the 'L' button next to songs in ReconTracks to open the lyrics editor.", "ReconTracks Lyrics", 0)
    end
end

init()