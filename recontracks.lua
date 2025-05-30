-- ReconTracks - Enhanced Backing Track Loader for Recontastic
-- Version 2.1

-- SETTINGS
local defaultSongFolder = "C:\\Users\\recontastic\\Desktop\\backtracks" -- <- fallback directory with proper backslashes
local isConsoleVisible = false -- Set to false to hide console output by default
local scriptVersion = "2.1"
local lastLoadedSong = nil

local useSongCache = true -- Enable/disable song caching
local songCacheFilePath = reaper.GetResourcePath() .. "\\Scripts\\ReconTracks\\song_cache.json"

local volumeMemory = nil
local useVolumeMemory = true  -- Set to false if you want to disable the feature

-- Global variables for genre management
local genreTags = {"Rock", "Metal", "Country", "Funk", "Soul", "Classic Rock", "Custom..."} -- Preset genres
local songGenres = {} -- Will store song path -> genre mapping
local customGenreInput = "" -- For entering custom genres
local genreFilePath = reaper.GetResourcePath() .. "\\Scripts\\ReconTracks\\song_genres.json"
local showCustomGenreInput = false -- Flag to show/hide custom genre input field


local favorites = {} -- Will store song path -> favorite status (true/false)
local favoritesFilePath = reaper.GetResourcePath() .. "\\Scripts\\ReconTracks\\song_favorites.json"
local showOnlyFavorites = false -- Flag to filter only favorites

-- Add these variables near the top with other similar declarations
local playCounts = {}
local playCountsFilePath = reaper.GetResourcePath() .. "\\Scripts\\ReconTracks\\song_playcounts.json"

-- Add these functions with the other data persistence functions

function saveSongPlayCounts()
  ensureDirectoryExists(playCountsFilePath)
  debug("Saving song play counts to: " .. playCountsFilePath)
  
  local jsonString = "{\n"
  local count = 0
  
  for path, playCount in pairs(playCounts) do
    if count > 0 then
      jsonString = jsonString .. ",\n"
    end
    
    local escapedPath = path:gsub("\\", "\\\\"):gsub('"', '\\"')
    jsonString = jsonString .. ' "' .. escapedPath .. '": ' .. playCount
    count = count + 1
  end
  
  jsonString = jsonString .. "\n}"
  
  local file = io.open(playCountsFilePath, "w")
  if file then
    file:write(jsonString)
    file:close()
    debug("Successfully saved " .. count .. " play count entries")
    return true
  else
    debug("ERROR: Failed to save play counts to file")
    return false
  end
end

function loadSongPlayCounts()
  debug("Loading song play counts from: " .. playCountsFilePath)
  local file = io.open(playCountsFilePath, "r")
  if not file then
    debug("No play counts file found, starting with empty collection")
    return false
  end
  
  local content = file:read("*all")
  file:close()
  
  playCounts = {}
  
  for path, count in content:gmatch('"([^"]+)"%s*:%s*(%d+)') do
    path = path:gsub('\\\\', '\\'):gsub('\\"', '"')
    playCounts[path] = tonumber(count) or 0
  end
  
  debug("Loaded " .. getTableSize(playCounts) .. " play count entries")
  return true
end

function incrementPlayCount(songPath)
  if not songPath then return end
  
  playCounts[songPath] = (playCounts[songPath] or 0) + 1
  debug("Incremented play count for " .. songPath .. " to " .. playCounts[songPath])
  saveSongPlayCounts()
end

function getSongPlayCount(songPath)
  return playCounts[songPath] or 0
end

-- Create the ReconTracks directory if it doesn't exist
function ensureDirectoryExists(path)
  local dirPath = path:match("(.*[/\\])")
  if dirPath then
    local exists = reaper.file_exists(dirPath)
    if not exists then
      -- Try to create the directory
      local success = reaper.RecursiveCreateDirectory(dirPath, 0)
      if not success then
        debug("Failed to create directory: " .. dirPath)
      else
        debug("Created directory: " .. dirPath)
      end
    end
  end
end

-- Save genres to JSON file
function saveGenres()
  ensureDirectoryExists(genreFilePath)
  debug("Saving genres to: " .. genreFilePath)
  
  -- Convert table to JSON string
  local jsonString = "{\n"
  local count = 0
  
  for path, genre in pairs(songGenres) do
    if count > 0 then
      jsonString = jsonString .. ",\n"
    end
    -- Escape backslashes and quotes for JSON
    local escapedPath = path:gsub("\\", "\\\\"):gsub('"', '\\"')
    jsonString = jsonString .. '  "' .. escapedPath .. '": "' .. genre .. '"'
    count = count + 1
  end
  
  jsonString = jsonString .. "\n}"
  
  -- Save to file
  local file = io.open(genreFilePath, "w")
  if file then
    file:write(jsonString)
    file:close()
    debug("Successfully saved " .. count .. " genre entries")
    return true
  else
    debug("ERROR: Failed to save genres to file")
    return false
  end
end

-- Load genres from JSON file
function loadGenres()
  debug("Loading genres from: " .. genreFilePath)
  local file = io.open(genreFilePath, "r")
  if not file then
    debug("No genres file found, starting with empty collection")
    return false
  end
  
  local content = file:read("*all")
  file:close()
  
  -- Clear existing data
  songGenres = {}
  
  -- More robust JSON parsing
  -- Look for "path": "genre" patterns
  for path, genre in content:gmatch('"([^"]+)"%s*:%s*"([^"]+)"') do
    -- Unescape path
    path = path:gsub('\\\\', '\\'):gsub('\\"', '"')
    
    -- Add to collection
    songGenres[path] = genre
  end
  
  debug("Loaded " .. getTableSize(songGenres) .. " genre entries")
  return true
end
-- Save favorites to JSON file
function saveFavorites()
  ensureDirectoryExists(favoritesFilePath)
  debug("Saving favorites to: " .. favoritesFilePath)
  
  -- Convert table to JSON string
  local jsonString = "{\n"
  local count = 0
  
  for path, isFavorite in pairs(favorites) do
    if count > 0 then
      jsonString = jsonString .. ",\n"
    end
    -- Escape backslashes and quotes for JSON
    local escapedPath = path:gsub("\\", "\\\\"):gsub('"', '\\"')
    jsonString = jsonString .. '  "' .. escapedPath .. '": ' .. (isFavorite and "true" or "false")
    count = count + 1
  end
  
  jsonString = jsonString .. "\n}"
  
  -- Save to file
  local file = io.open(favoritesFilePath, "w")
  if file then
    file:write(jsonString)
    file:close()
    debug("Successfully saved " .. count .. " favorite entries")
    return true
  else
    debug("ERROR: Failed to save favorites to file")
    return false
  end
end

-- Load favorites from JSON file
function loadFavorites()
  debug("Loading favorites from: " .. favoritesFilePath)
  local file = io.open(favoritesFilePath, "r")
  if not file then
    debug("No favorites file found, starting with empty collection")
    return false
  end
  
  local content = file:read("*all")
  file:close()
  
  -- Clear existing data
  favorites = {}
  
  -- Look for "path": true/false patterns
  for path, status in content:gmatch('"([^"]+)"%s*:%s*(%a+)') do
    -- Unescape path
    path = path:gsub('\\\\', '\\'):gsub('\\"', '"')
    
    -- Add to collection (convert text "true"/"false" to boolean)
    favorites[path] = (status == "true")
  end
  
  debug("Loaded " .. getTableSize(favorites) .. " favorite entries")
  return true
end

-- Function to get favorite status for a song
function isFavorite(songPath)
  return favorites[songPath] == true
end

-- Function to toggle favorite status for a song
function toggleFavorite(songPath)
  favorites[songPath] = not isFavorite(songPath)
  saveFavorites() -- Save immediately after change
  debug("Toggled favorite for " .. songPath .. " to " .. tostring(isFavorite(songPath)))
end

-- Helper function to get table size
function getTableSize(t)
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

-- Function to get genre for a song
function getSongGenre(songPath)
  return songGenres[songPath] or "Unassigned"
end


-- Function to set genre for a song
function setSongGenre(songPath, genre)
  songGenres[songPath] = genre
  saveGenres() -- Save immediately after change
  debug("Set genre for " .. songPath .. " to " .. genre)
end

-- Modified function to ensure all songs have genre information
function addGenreToSongsTable(songs)
  for _, song in ipairs(songs) do
    if not song.genre then 
      song.genre = getSongGenre(song.path)
    end
  end
  return songs
end


-- Debug helper - only shows in console if explicitly toggled
local logBuffer = {}
function debug(message)
  table.insert(logBuffer, message)
  if isConsoleVisible then
    reaper.ShowConsoleMsg(message .. "\n")
  end
end

-- Toggle console visibility function
function toggleConsole()
  isConsoleVisible = not isConsoleVisible
  if isConsoleVisible then
    reaper.ShowConsoleMsg("\n--- ReconTracks Console Enabled ---\n")
    -- Show all buffered messages
    for _, msg in ipairs(logBuffer) do
      reaper.ShowConsoleMsg(msg .. "\n")
    end
    reaper.ShowConsoleMsg("\n")
  else
    reaper.ClearConsole()
  end
end

-- Save and retrieve last used folder using REAPER's persistent storage
function getSavedFolder()
  local lastFolder = reaper.GetExtState("ReconTracks", "LastFolder")
  if lastFolder and lastFolder ~= "" then
    debug("Using saved folder: " .. lastFolder)
    return lastFolder
  else
    -- Force the default folder explicitly
    debug("No saved folder found, using default: " .. defaultSongFolder)
    -- Make sure the default folder exists
    local exists = reaper.file_exists(defaultSongFolder)
    if exists then
      debug("Default folder exists and will be used")
    else
      debug("WARNING: Default folder doesn't exist: " .. defaultSongFolder)
      -- Try to get user's desktop as fallback
      local desktop = reaper.GetResourcePath():match("(.+)[/\\]"):match("(.+)[/\\]") .. "\\Desktop"
      debug("Falling back to Desktop: " .. desktop)
      return desktop
    end
    return defaultSongFolder
  end
end

function saveFolder(folderPath)
  debug("Saving folder path for future use: " .. folderPath)
  reaper.SetExtState("ReconTracks", "LastFolder", folderPath, true) -- true = persist
end

-- Find track by name or create if it doesn't exist
function findOrCreateTrack(name)
  -- First search for existing track with this name
  for i = 0, reaper.CountTracks(0)-1 do
    local track = reaper.GetTrack(0, i)
    local retval, trackName = reaper.GetTrackName(track)
    if trackName == name or trackName:match("^" .. name .. ":") then 
      debug("Found existing track named: " .. trackName)
      -- Reset the name back to just the base name
      reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
      return track 
    end
  end
  
  -- If we get here, track wasn't found, so create it
  debug("Creating new track: " .. name)
  reaper.InsertTrackAtIndex(reaper.CountTracks(0), true)
  local track = reaper.GetTrack(0, reaper.CountTracks(0)-1)
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
  return track
end


function saveLastLoadedSong(songInfo)
  if songInfo then
    reaper.SetExtState("ReconTracks", "LastSongName", songInfo.name or "", true)
    reaper.SetExtState("ReconTracks", "LastSongPath", songInfo.path or "", true)
    reaper.SetExtState("ReconTracks", "LastSongTime", tostring(songInfo.timestamp or os.time()), true)
  end
end

function loadLastLoadedSong()
  local name = reaper.GetExtState("ReconTracks", "LastSongName")
  local path = reaper.GetExtState("ReconTracks", "LastSongPath")
  local timestamp = reaper.GetExtState("ReconTracks", "LastSongTime")
  
  if name ~= "" and path ~= "" then
    return {
      name = name,
      path = path,
      timestamp = tonumber(timestamp) or os.time()
    }
  end
  
  return nil
end

-- Insert media directly using lower-level REAPER functions at specific position
function insertMediaDirect(track, filePath, position)
  -- Create new item at specified position
  local item = reaper.AddMediaItemToTrack(track)
  
  if not item then
    debug("Failed to create media item")
    return false
  end
  
  -- Set item position
  reaper.SetMediaItemPosition(item, position, false)
  
  -- Create a take with the audio file
  local take = reaper.AddTakeToMediaItem(item)
  if not take then
    debug("Failed to create take")
    reaper.DeleteTrackMediaItem(track, item)
    return false
  end
  
  local source = reaper.PCM_Source_CreateFromFile(filePath)
  if not source then
    debug("Failed to create PCM source from file: " .. filePath)
    debug("This might be due to an unsupported file format or path issues")
    reaper.DeleteTrackMediaItem(track, item)
    return false
  end
  
  debug("Successfully created PCM source")
  reaper.SetMediaItemTake_Source(take, source)
  
  -- Get source length and adjust item length
  local srclen = reaper.GetMediaSourceLength(source)
  if srclen > 0 then
    reaper.SetMediaItemLength(item, srclen, false)
    debug("Set item length to source length: " .. srclen .. " seconds")
  else
    -- Set a default length if we couldn't get source length
    reaper.SetMediaItemLength(item, 300, false) -- 5 minutes default
    debug("Could not get source length, set default 5 minute length")
  end
  
  -- Get filename only for the take name
  local filename = filePath:match("([^/\\]+)$")
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", filename or "Take 1", true)
  return srclen > 0 and srclen or 300
end

-- Get the end position of all items on a track
function getTrackEndPosition(track)
  local itemCount = reaper.CountTrackMediaItems(track)
  if itemCount == 0 then return 0 end
  
  local endPosition = 0
  for i = 0, itemCount-1 do
    local item = reaper.GetTrackMediaItem(track, i)
    local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemLen = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local itemEnd = itemPos + itemLen
    
    if itemEnd > endPosition then
      endPosition = itemEnd
    end
  end
  
  return endPosition
end

-- Try to insert media at a specific position
function tryInsertMedia(track, songPath, position)
  -- Try direct PCM source creation (most reliable)
  debug("Inserting media at position: " .. position)
  local length = insertMediaDirect(track, songPath, position)
  if length then
    debug("Media inserted successfully")
    return length
  end
  
  debug("Failed to insert media")
  return false
end

-- Load new song at given position (0 = start or after current playback queue)
function loadSong(path, position, append)
  if volumeMemory and not append then 
    volumeMemory.onBeforeSongLoad()
  end
  
  debug("Attempting to load file: " .. path)
  local trackName = "ReconTracks"
  local track = findOrCreateTrack(trackName)
  
  if not append then
    -- Clear existing track content when not appending
    reaper.SetOnlyTrackSelected(track)
    reaper.Main_OnCommand(40421, 0) -- Select all items on selected tracks
    local itemCount = reaper.CountSelectedMediaItems(0)
    if itemCount > 0 then
      debug("Removing " .. itemCount .. " existing items")
      reaper.Main_OnCommand(40006, 0) -- Delete selected items
    else
      debug("No existing items to remove")
    end
    position = 0
  else
    if position == 0 then
      position = getTrackEndPosition(track)
      debug("Appending to end of track at position: " .. position)
    end
  end
  
  reaper.PreventUIRefresh(1)
  local result = tryInsertMedia(track, path, position)
  
  if result then
    reaper.SetMediaTrackInfo_Value(track, "B_MUTE", 0)
    local filename = path:match("([^/\\]+)$")
    
    if not append then
      reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "ReconTracks: " .. filename, true)
    end
    
    if not append then
      reaper.SetEditCurPos(0, true, false)
    end
    
    lastLoadedSong = {
      name = filename,
      path = path,
      timestamp = os.time()
    }
    saveLastLoadedSong(lastLoadedSong)
    reaper.Main_OnCommand(40454, 0) -- Peaks building
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    
    -- Call volumeMemory.onAfterSongLoad after successfully loading the song
    if volumeMemory then
      volumeMemory.onAfterSongLoad(path)
    end
	incrementPlayCount(path)
    
    return result
  else
    debug("ERROR: Failed to insert media")
    reaper.ShowMessageBox("Failed to insert the audio file. Try enabling the console for details.", "ReconTracks Error", 0)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    return false
  end
end

function openLyricsEditor(path, songName)
    if not path or path == "" then
        debug("Cannot open lyrics editor: No song path provided")
        return false
    end
    
    local lyricsScript = reaper.GetResourcePath().."\\Scripts\\ReconTracks-Lyrics.lua"
    if not reaper.file_exists(lyricsScript) then
        debug("Error: Lyrics script not found at: "..lyricsScript)
        reaper.ShowMessageBox("Could not find ReconTracks-Lyrics.lua in the Scripts folder.\n\nPlease make sure the script is installed correctly.", "Script Not Found", 0)
        return false
    end
    
    -- First check if we have an active lyrics editor
    if _G.ReconTracksLyrics and _G.ReconTracksLyrics.isEditorOpen then
        local isOpen = _G.ReconTracksLyrics.isEditorOpen()
        if isOpen then
            debug("Found existing lyrics editor, will update for: " .. path)
            -- If there's already a lyrics editor open, we'll close it
            _G.ReconTracksLyrics.closeEditor()
        end
    end
    
    -- Set state for the lyrics editor
    reaper.SetExtState("ReconTracks", "CurrentSongPath", path, false)
    reaper.SetExtState("ReconTracks", "CurrentSongName", songName or "", false)
    
    -- Now run the lyrics script
    local cmdId = '_SCRIPTNAME:'..lyricsScript
    local actionId = reaper.NamedCommandLookup(cmdId)
    
    if actionId == 0 then
        actionId = reaper.AddRemoveReaScript(true, 0, lyricsScript, true)
    end
    
    if actionId ~= 0 then
        reaper.Main_OnCommand(actionId, 0)
        debug("Lyrics editor opened for: "..path)
        return true
    else
        debug("Failed to register lyrics script as action")
        reaper.ShowMessageBox("Could not run the lyrics editor script.", "Error", 0)
        return false
    end
end

-- Extract folder path from a full file path
function getFolderFromPath(filePath)
  -- Match everything until the last slash or backslash
  return filePath:match("(.+)[/\\][^/\\]*$")
end

-- Get audio file extensions
function getAudioExtensions()
  return {
    ".wav", ".mp3", ".ogg", ".flac", ".aif", ".aiff", 
    ".m4a", ".mp2", ".mp4", ".wma", ".mid", ".midi"
  }
end

-- Check if a file has an audio extension
function isAudioFile(filename)
  local extensions = getAudioExtensions()
  local lowerFilename = filename:lower()
  
  for _, ext in pairs(extensions) do
    if lowerFilename:match(ext .. "$") then
      return true
    end
  end
  return false
end

-- Optimized song cache loading with better performance for large libraries
function loadSongCache(directoryPath)
    if not useSongCache then return nil end
    debug("Trying to load song cache for directory: " .. directoryPath)
    
    local file = io.open(songCacheFilePath, "r")
    if not file then
        debug("No cache file found at: " .. songCacheFilePath)
        return nil
    end
    
    -- Read only the first part of the file to get metadata
    local headerContent = file:read(2048) -- Read first 2KB to get header info
    
    -- Extract directory from header
    local cachedDir = headerContent:match('"directory":%s*"([^"]+)"')
    if not cachedDir then
        debug("Invalid cache format - no directory found")
        file:close()
        return nil
    end
    
    cachedDir = cachedDir:gsub("\\\\", "\\")
    if cachedDir ~= directoryPath then
        debug("Cache is for a different directory: " .. cachedDir .. " vs requested " .. directoryPath)
        file:close()
        return nil
    end
    
    -- Extract timestamp from header
    local timestamp = tonumber(headerContent:match('"timestamp":%s*(%d+)'))
    if not timestamp then
        debug("Invalid cache format - no timestamp found")
        file:close()
        return nil
    end
    
    -- Check if cache is too old (configurable time period)
    local cacheMaxAge = 24 * 3600 -- 24 hours
    if os.time() - timestamp > cacheMaxAge then
        debug("Cache is older than " .. (cacheMaxAge/3600) .. " hours, will refresh")
        file:close()
        return nil
    end
    
    -- Get current directory fingerprint
    local currentFingerprint = getDirectoryFingerprint(directoryPath)
    
    -- If we can't get a fingerprint, fallback to using cache
    if not currentFingerprint then
        debug("Couldn't generate directory fingerprint, using cache anyway")
    else
        -- Extract fingerprint from header
        local cachedFingerprint = headerContent:match('"fingerprint":%s*"([^"]*)"')
        
        -- Compare fingerprints
        if not cachedFingerprint then
            debug("No fingerprint in cache, will refresh")
            file:close()
            return nil
        end
        
        -- Only check file count for a quick comparison
        local cachedFileCount = tonumber(cachedFingerprint:match("#(%d+)"))
        local currentFileCount = currentFingerprint.fileCount
        
        -- If file count differs by more than 3 files, refresh cache
        if cachedFileCount and currentFileCount and math.abs(cachedFileCount - currentFileCount) > 3 then
            debug("Directory file count changed significantly: " .. cachedFileCount .. " vs " .. currentFileCount)
            file:close()
            return nil
        end
    end
    
    -- If all checks pass, read the full file and parse songs
    file:seek("set", 0) -- Reset to beginning of file
    local content = file:read("*all")
    file:close()
    
    local songs = {}
    local pattern = '"name":%s*"([^"]*)".-"path":%s*"([^"]*)".-"genre":%s*"([^"]*)".-"duration":%s*([%d%.]+)'
    
    -- Reuse a table for file existence checks to improve performance
    local fileExistsCache = {}
    local songsAdded = 0
    
    -- Process songs more efficiently
    for name, path, genre, duration in content:gmatch(pattern) do
        path = path:gsub("\\\\", "\\")
        name = name:gsub('\\"', '"')
        genre = genre:gsub('\\"', '"')
        
        -- Cache file existence checks
        if fileExistsCache[path] == nil then
            fileExistsCache[path] = reaper.file_exists(path)
        end
        
        if fileExistsCache[path] then
            local song = {
                name = name,
                path = path,
                genre = genre or "Unassigned",
                duration = tonumber(duration) or 0
            }
            table.insert(songs, song)
            songsAdded = songsAdded + 1
        end
    end
    
    if songsAdded > 0 then
        debug("Successfully loaded " .. songsAdded .. " songs from cache")
        return songs
    else
        debug("Cache contained no valid songs")
        return nil
    end
end

-- More efficient song list scanning with pagination support
function getSongList(directoryPath)
    debug("Scanning directory: " .. directoryPath)
    
    -- Try using cache first
    local cachedSongs = loadSongCache(directoryPath)
    if cachedSongs then
        debug("Using valid cache with " .. #cachedSongs .. " songs")
        return addGenreToSongsTable(cachedSongs)
    end
    
    -- Cache invalid or missing, scan directory
    local songs = {}
    local i = 0
    local batchSize = 50 -- Process in batches for large directories
    local batchCount = 0
    
    debug("Full directory scan: " .. directoryPath)
    
    repeat
        local fileName = reaper.EnumerateFiles(directoryPath, i)
        if fileName and isAudioFile(fileName) then
            local filePath = directoryPath .. "\\" .. fileName
            local song = {name = fileName, path = filePath}
            
            -- Only get duration for first 200 files immediately
            -- rest will be loaded on demand or in background
            if #songs < 200 then
                local source = reaper.PCM_Source_CreateFromFile(filePath)
                if source then
                    song.duration = reaper.GetMediaSourceLength(source)
                    reaper.PCM_Source_Destroy(source)
                end
            end
            
            song.genre = getSongGenre(filePath)
            table.insert(songs, song)
            
            -- Update UI periodically for large directories
            batchCount = batchCount + 1
            if batchCount >= batchSize then
                debug("Scanned " .. #songs .. " files so far...")
                batchCount = 0
                -- Could add a reaper.defer call here for smoother UI updates
            end
        end
        i = i + 1
    until not fileName
    
    -- Sort songs by name
    table.sort(songs, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    
    -- Save cache in background
    saveSongCache(directoryPath, songs)
    return addGenreToSongsTable(songs)
end

function initVolumeMemory()
  if not useVolumeMemory then return false end
  
  local vm_path = reaper.GetResourcePath() .. "\\Scripts\\ReconTracks-VolumeMemory.lua"
  
  -- Check if the file exists
  if not reaper.file_exists(vm_path) then
    debug("VolumeMemory script not found at: " .. vm_path)
    return false
  end
  
  debug("Loading VolumeMemory script...")
  
  -- Load the script
  local load_result, vm_module = pcall(dofile, vm_path)
  
  if not load_result or not vm_module then
    debug("Failed to load VolumeMemory module: " .. tostring(vm_module))
    return false
  end
  
  volumeMemory = vm_module
  volumeMemory.init()
  debug("VolumeMemory module loaded successfully")
  return true
end



-- Optimized save song cache for large libraries
function saveSongCache(directoryPath, songs)
    if not useSongCache then return false end
    
    ensureDirectoryExists(songCacheFilePath)
    debug("Saving song cache for directory: " .. directoryPath)
    
    local fingerprint = getDirectoryFingerprint(directoryPath)
    local timestamp = os.time()
    
    -- Prepare song data more efficiently
    local file = io.open(songCacheFilePath, "w")
    if not file then
        debug("ERROR: Failed to open cache file for writing: " .. songCacheFilePath)
        return false
    end
    
    -- Write cache more efficiently using chunks
    -- Write header
    file:write('{\n')
    file:write('  "timestamp": ' .. timestamp .. ',\n')
    file:write('  "directory": "' .. directoryPath:gsub("\\", "\\\\") .. '",\n')
    file:write('  "fingerprint": "' .. fingerprint.hashValue .. '",\n')
    file:write('  "songs": [\n')
    
    -- Write songs in chunks to avoid memory issues
    for i, song in ipairs(songs) do
        if i > 1 then file:write(",\n") end
        
        local escapedPath = song.path:gsub("\\", "\\\\"):gsub('"', '\\"')
        local escapedName = song.name:gsub('"', '\\"')
        local escapedGenre = (song.genre or "Unassigned"):gsub('"', '\\"')
        
        local chunk = '    {\n'
        chunk = chunk .. '      "name": "' .. escapedName .. '",\n'
        chunk = chunk .. '      "path": "' .. escapedPath .. '",\n'
        chunk = chunk .. '      "genre": "' .. escapedGenre .. '",\n'
        chunk = chunk .. '      "duration": ' .. (song.duration or 0) .. '\n'
        chunk = chunk .. '    }'
        
        file:write(chunk)
    end
    
    file:write("\n  ]\n}")
    file:close()
    
    debug("Successfully saved cache with " .. #songs .. " songs to " .. songCacheFilePath)
    return true
end


function showSongTable(context, songs, pageSize, currentPage)
    -- Calculate pagination
    local totalSongs = #songs
    local totalPages = math.ceil(totalSongs / pageSize)
    currentPage = math.min(currentPage, totalPages)
    
    -- Display pagination controls
    reaper.ImGui_Text(context, "Page " .. currentPage .. " of " .. totalPages)
    reaper.ImGui_SameLine(context)
    
    local startIdx = (currentPage - 1) * pageSize + 1
    local endIdx = math.min(startIdx + pageSize - 1, totalSongs)
    
    if reaper.ImGui_Button(context, "<<") and currentPage > 1 then
        currentPage = 1
    end
    reaper.ImGui_SameLine(context)
    
    if reaper.ImGui_Button(context, "<") and currentPage > 1 then
        currentPage = currentPage - 1
    end
    reaper.ImGui_SameLine(context)
    
    if reaper.ImGui_Button(context, ">") and currentPage < totalPages then
        currentPage = currentPage + 1
    end
    reaper.ImGui_SameLine(context)
    
    if reaper.ImGui_Button(context, ">>") and currentPage < totalPages then
        currentPage = totalPages
    end
    
    -- Display current range
    reaper.ImGui_SameLine(context)
    reaper.ImGui_Text(context, "Showing " .. startIdx .. "-" .. endIdx .. " of " .. totalSongs)
    
    -- Return page info to be stored
    return currentPage, startIdx, endIdx
end

function modifyUIForPagination(context, filteredSongs)
    -- Add these variables to your UI function
    local pageSize = 50 -- Adjust as needed
    local currentPage = 1 -- Track this globally in your UI function
    
    currentPage, startIdx, endIdx = showSongTable(context, filteredSongs, pageSize, currentPage)
    
    -- Then in your table rendering loop:
    if reaper.ImGui_BeginTable(context, "SongTable", 4, 
                               reaper.ImGui_TableFlags_Borders() + 
                               reaper.ImGui_TableFlags_RowBg() + 
                               reaper.ImGui_TableFlags_ScrollY(), 0, tableHeight) then
        -- Setup columns as before
        
        -- Only process songs for current page
        for i = startIdx, endIdx do
            local song = filteredSongs[i]
            -- Render song row as before
        end
        
        reaper.ImGui_EndTable(context)
    end
    
    return currentPage -- Store this for next frame
end

function lazyLoadDuration(song)
    if not song.duration or song.duration <= 0 then
        local source = reaper.PCM_Source_CreateFromFile(song.path)
        if source then
            song.duration = reaper.GetMediaSourceLength(source)
            reaper.PCM_Source_Destroy(source)
        end
    end
    return song.duration or 0
end

-- File fingerprinting for directory change detection
function getDirectoryFingerprint(directoryPath)
    local fingerprint = {
        path = directoryPath,
        fileCount = 0,
        hashValue = ""
    }
    
    -- Fast fingerprinting by using file count and file names
    local fileNames = {}
    local i = 0
    local maxFilesToCheck = 50 -- Check limited sample for large directories
    local sampleCount = 0
    local totalFileSize = 0
    
    debug("Generating fingerprint for: " .. directoryPath)
    
    repeat
        local fileName = reaper.EnumerateFiles(directoryPath, i)
        if fileName and isAudioFile(fileName) then
            fingerprint.fileCount = fingerprint.fileCount + 1
            
            -- Only sample some files for very large directories
            if sampleCount < maxFilesToCheck then
                table.insert(fileNames, fileName)
                local filePath = directoryPath .. "\\" .. fileName
                
                -- Get file size if possible
                local size = 0
                local file = io.open(filePath, "rb")
                if file then
                    local current = file:seek()
                    size = file:seek("end")
                    file:seek("set", current)
                    file:close()
                    totalFileSize = totalFileSize + size
                end
                
                sampleCount = sampleCount + 1
            end
        end
        i = i + 1
    until not fileName
    
    -- Sort the filenames to ensure consistent ordering
    table.sort(fileNames)
    
    -- Create a hash value based on directory contents
    local hashBase = ""
    
    -- For large directories, use a simplified hash based on count and sample
    if fingerprint.fileCount > 300 then
        -- Use first 10 and last 10 files (sorted) plus file count and total size
        local sampleList = {}
        for i = 1, math.min(10, #fileNames) do
            table.insert(sampleList, fileNames[i])
        end
        
        for i = math.max(1, #fileNames - 9), #fileNames do
            table.insert(sampleList, fileNames[i])
        end
        
        -- Create hash from sample files
        for _, name in ipairs(sampleList) do
            hashBase = hashBase .. name:sub(1, 15)
        end
        
        fingerprint.hashValue = hashBase .. "#" .. fingerprint.fileCount .. ":" .. math.floor(totalFileSize / 1024)
        debug("Large directory fingerprint created")
    else
        -- For smaller directories, use more files for better accuracy
        for i, name in ipairs(fileNames) do
            if i <= 30 then -- Use only up to 30 files for hash
                hashBase = hashBase .. name
            end
        end
        
        -- Add total file count to ensure we capture additions/removals
        fingerprint.hashValue = hashBase .. "#" .. fingerprint.fileCount
        debug("Regular directory fingerprint created")
    end
    
    return fingerprint
end


-- Format seconds to MM:SS
function formatTime(seconds)
  if not seconds or seconds <= 0 then return "00:00" end
  local mins = math.floor(seconds / 60)
  local secs = math.floor(seconds % 60)
  return string.format("%02d:%02d", mins, secs)
end

-- Simple case-insensitive string search
function stringContains(str, searchTerm)
  return string.find(string.lower(str), string.lower(searchTerm)) ~= nil
end

-- Enhanced filter function to include genres
function filterSongs(songs, searchTerm, favoritesOnly)
  local filtered = {}
  
  for _, song in ipairs(songs) do
    local matchesSearch = true
    local matchesFavorite = true
    
    -- Apply search term filter if provided
    if searchTerm and searchTerm ~= "" then
      local lowerSearchTerm = string.lower(searchTerm)
      local lowerName = string.lower(song.name)
      local lowerGenre = string.lower(song.genre or "")
      
      -- Search in both name and genre
      matchesSearch = string.find(lowerName, lowerSearchTerm) or string.find(lowerGenre, lowerSearchTerm)
    end
    
    -- Apply favorites filter if requested
    if favoritesOnly then
      matchesFavorite = isFavorite(song.path)
    end
    
    -- Include song only if it passes both filters
    if matchesSearch and matchesFavorite then
      table.insert(filtered, song)
    end
  end
  
  return filtered
end

-- Save queue to ExtState
function saveQueue(queue)
  local queueStr = ""
  for i, song in ipairs(queue) do
    queueStr = queueStr .. song.path
    if i < #queue then queueStr = queueStr .. "|" end
  end
  reaper.SetExtState("ReconTracks", "Queue", queueStr, true)
  debug("Queue saved with " .. #queue .. " items")
end

-- Load queue from ExtState
function loadQueue()
  local queueStr = reaper.GetExtState("ReconTracks", "Queue")
  local queue = {}
  
  if queueStr and queueStr ~= "" then
    for path in queueStr:gmatch("([^|]+)") do
      -- Extract name from path
      local name = path:match("([^/\\]+)$")
      if name then
        local songInfo = { name = name, path = path }
        -- Try to get duration info
        local mediaSource = reaper.PCM_Source_CreateFromFile(path)
        if mediaSource then
          songInfo.duration = reaper.GetMediaSourceLength(mediaSource)
          reaper.PCM_Source_Destroy(mediaSource)
        end
        table.insert(queue, songInfo)
      end
    end
    debug("Loaded queue with " .. #queue .. " items")
  end
  
  return queue
end

-- Add these if not already present
local function initImGuiKeys()
  if reaper.ImGui_Key_Enter and reaper.ImGui_Key_Escape then
    return true
  end
  
  -- Define key constants if not provided by ReaImGui
  if not reaper.ImGui_Key_Enter then
    reaper.ImGui_Key_Enter = function() return 13 end
  end
  
  if not reaper.ImGui_Key_Escape then
    reaper.ImGui_Key_Escape = function() return 27 end
  end
  
  return true
end
-- Create UI to select and queue songs
function showEnhancedUI()
  local songFolder = getSavedFolder()
  local allSongs = getSongList(songFolder)
  
  -- Initialize or restore favorites
  loadFavorites()
  
  -- Initialize or restore queue
  local queue = loadQueue()
  
initImGuiKeys()
  if #allSongs == 0 then
    reaper.ShowMessageBox("No audio files found in " .. songFolder .. "\n\nWould you like to choose a different folder?", "ReconTracks", 4)
    return browseFolderAndShowUI()
  end
  
  -- Create window context
  local ctx = reaper.ImGui_CreateContext('ReconTracks')
  
  -- UI variables
  local open = true
  local selected = nil
  local queueSelected = nil
  local searchText = ""
  local windowWidth = 700
  local windowHeight = 500
  local filteredSongs = allSongs
  local currentTab = 1 -- 1 = Browser, 2 = Queue
  local isMaximized = false
  local originalWindowWidth = windowWidth
  local originalWindowHeight = windowHeight

  
  -- Toggle window maximized state
  function toggleMaximize()
    isMaximized = not isMaximized
    if isMaximized then
      -- Store original size before maximizing
      originalWindowWidth = windowWidth
      originalWindowHeight = windowHeight
      
      -- Get screen size for maximizing
      local viewportWidth = reaper.ImGui_GetMainViewport(ctx)
      local availWidth, availHeight = reaper.ImGui_Viewport_GetWorkSize(viewportWidth)
      
      -- Set to almost full screen size
      windowWidth = availWidth - 40
      windowHeight = availHeight - 40
    else
      -- Restore original size
      windowWidth = originalWindowWidth
      windowHeight = originalWindowHeight
    end
  end
  
  -- Process the queue
  function processQueue()
    -- Load all songs in queue to the track
    if #queue == 0 then
      reaper.ShowMessageBox("Your queue is empty. Add some songs first!", "ReconTracks", 0)
      return
    end
    
    debug("Processing queue with " .. #queue .. " items")
    
    -- Start undo block
    reaper.Undo_BeginBlock()
    
    -- Load the first song without appending
    local position = 0
    if queue[1] then
      local length = loadSong(queue[1].path, 0, false)
      if length then position = length end
    end
    
    -- Load remaining songs with appending
    for i = 2, #queue do
      if queue[i] then
        local length = loadSong(queue[i].path, position, true)
        if length then position = position + length end
      end
    end
    
    -- End undo block
    reaper.Undo_EndBlock("Load ReconTracks queue", -1)
    
    -- Clear the queue after processing
    queue = {}
    saveQueue(queue)
	-- Update last loaded song to the first song in queue
	if queue[1] then
	  lastLoadedSong = {
		name = queue[1].name,
		path = queue[1].path,
		timestamp = os.time()
	  }
	  saveLastLoadedSong(lastLoadedSong)
	end
  end
  
  -- Main UI loop
  function loop()
  -- Exit if window closed
  if not open then
    -- Check if ImGui_DestroyContext exists before calling it
    if reaper.ImGui_DestroyContext then
      reaper.ImGui_DestroyContext(ctx)
    end
    -- Either way, we need to stop the deferred function
    return
  end
  
  checkPlaylistManagerUpdates()
      
  -- If queue was updated from external source, update UI
  if queueUpdated then
    queueUpdated = false
  end

  -- Window flags
  local windowFlags = reaper.ImGui_WindowFlags_NoCollapse()
  
  -- Set window size
  reaper.ImGui_SetNextWindowSize(ctx, windowWidth, windowHeight, reaper.ImGui_Cond_FirstUseEver())
  
  -- Apply styling and display window
  local visible, openState = reaper.ImGui_Begin(ctx, 'ReconTracks v'..scriptVersion..' - Backing Track Manager', true, windowFlags)
  open = openState
    
  if visible then
    -- Toolbar section
    if reaper.ImGui_BeginTable(ctx, "toolbar", 5, reaper.ImGui_TableFlags_None()) then
      reaper.ImGui_TableNextColumn(ctx)
      
      -- Current folder display
      reaper.ImGui_Text(ctx, "Current: " .. songFolder)
      
      reaper.ImGui_TableNextColumn(ctx)
      -- Browse button
      if reaper.ImGui_Button(ctx, "Browse...") then
        browseFolderAndShowUI()
        reaper.ImGui_EndTable(ctx)  -- Make sure table is closed
        reaper.ImGui_End(ctx)       -- Make sure window is closed
        return reaper.defer(loop)
      end
      
      reaper.ImGui_TableNextColumn(ctx)
      -- Toggle console button
      if reaper.ImGui_Button(ctx, isConsoleVisible and "Hide Console" or "Show Console") then
        toggleConsole()
      end
      
      reaper.ImGui_TableNextColumn(ctx)
      -- Maximize button
      if reaper.ImGui_Button(ctx, isMaximized and "Restore Window" or "Maximize Window") then
        toggleMaximize()
      end
      
      reaper.ImGui_TableNextColumn(ctx)
      -- Help button
      if reaper.ImGui_Button(ctx, "Help") then
        reaper.ShowMessageBox(
          "ReconTracks - Backing Track Manager v"..scriptVersion.." by Recontastic\n\n" ..
          "* L= Lyrics tab, Q= Add to Queue, F= Favorites \n" ..
          "* Browse: Change your backing track folder\n" ..
          "* Browser Tab: View and select tracks\n" ..
          "* Queue Tab: Arrange tracks to play in sequence\n" ..
          "* Load Track: Load selected track immediately\n" ..
          "* Add to Queue: Add selected track to queue\n" ..
          "* Process Queue: Load all queued tracks in sequence\n" ..
          "* Clear Queue: Remove all tracks from queue\n\n" ..
          "2025 ©Recontastic",
          "ReconTracks Help", 0)
      end
      
      reaper.ImGui_EndTable(ctx)
    end
    
    reaper.ImGui_Separator(ctx)
    
    -- Check if TabBar is available
    local hasTabBar = pcall(function() return reaper.ImGui_BeginTabBar ~= nil end)
    
    -- Tab bar or alternative layout
    if hasTabBar and reaper.ImGui_BeginTabBar and reaper.ImGui_BeginTabBar(ctx, "TabBar") then
      -- Browser Tab
      local browserTabVisible = reaper.ImGui_BeginTabItem and reaper.ImGui_BeginTabItem(ctx, "Browser")
      if browserTabVisible then
        currentTab = 1
        
        -- Search box with hint about genre search
        reaper.ImGui_Text(ctx, "Search (name or genre):")
  reaper.ImGui_SameLine(ctx)
  reaper.ImGui_SetNextItemWidth(ctx, windowWidth - 350) -- Reduced width to make room for favorites toggle
  local rv, newSearchText = reaper.ImGui_InputText(ctx, "##search", searchText)
  
  if rv then
    searchText = newSearchText
    filteredSongs = filterSongs(allSongs, searchText, showOnlyFavorites)
  end
  
  reaper.ImGui_SameLine(ctx)
  if reaper.ImGui_Button(ctx, "Clear") then
    searchText = ""
    filteredSongs = filterSongs(allSongs, "", showOnlyFavorites)
  end
  
  -- Favorites filter toggle button
  reaper.ImGui_SameLine(ctx)
  local favButtonText = showOnlyFavorites and "All Songs" or "Favorites"
  if reaper.ImGui_Button(ctx, favButtonText) then
    showOnlyFavorites = not showOnlyFavorites
    filteredSongs = filterSongs(allSongs, searchText, showOnlyFavorites)
  end
		
		
		  -- Add Random Loader button
		  if reaper.ImGui_Button(ctx, "Random Loader") then
			openRandomLoader()
		  end
        
        reaper.ImGui_Separator(ctx)
        
        -- Song list with columns
        if #filteredSongs > 0 then
          reaper.ImGui_Text(ctx, "Found " .. #filteredSongs .. " of " .. #allSongs .. " total audio files")
          
          -- Calculate table height
          local tableHeight = windowHeight - 220
          
          -- Create song table
          if reaper.ImGui_BeginTable(ctx, "SongTable", 4, reaper.ImGui_TableFlags_Borders() + reaper.ImGui_TableFlags_RowBg() + reaper.ImGui_TableFlags_ScrollY(), 0, tableHeight) then
            -- Set up columns
            reaper.ImGui_TableSetupColumn(ctx, "Name", reaper.ImGui_TableColumnFlags_WidthStretch())
            reaper.ImGui_TableSetupColumn(ctx, "Duration", reaper.ImGui_TableColumnFlags_WidthFixed(), 80)
            reaper.ImGui_TableSetupColumn(ctx, "Genre", reaper.ImGui_TableColumnFlags_WidthFixed(), 120)
            reaper.ImGui_TableSetupColumn(ctx, "Actions", reaper.ImGui_TableColumnFlags_WidthFixed(), 120)
            reaper.ImGui_TableHeadersRow(ctx)
            
            -- Display songs
            for i, song in ipairs(filteredSongs) do
              reaper.ImGui_TableNextRow(ctx)
              
              -- Name column
              reaper.ImGui_TableNextColumn(ctx)
              local isSelected = selected == song
              if reaper.ImGui_Selectable(ctx, song.name, isSelected) then
                selected = song
              end
              
              -- Duration column
              reaper.ImGui_TableNextColumn(ctx)
              if song.duration then
                reaper.ImGui_Text(ctx, formatTime(song.duration))
              else
                reaper.ImGui_Text(ctx, "--:--")
              end
              
              -- Genre column - Improved dropdown with integrated custom input
              reaper.ImGui_TableNextColumn(ctx)
              local currentGenre = getSongGenre(song.path)
              reaper.ImGui_PushID(ctx, "genre" .. i)

              -- Check if this song is currently being edited with custom genre
              if showCustomGenreInput == i then
                -- Show text input field instead of dropdown
                reaper.ImGui_SetNextItemWidth(ctx, 110)
                local rv, newCustomGenre = reaper.ImGui_InputText(ctx, "##customgenre" .. i, customGenreInput)
                if rv then
                  customGenreInput = newCustomGenre
                end
                
                -- Check if input has lost focus or Enter was pressed
                if reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) or 
                  (reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) and reaper.ImGui_IsItemFocused(ctx)) then
                  -- Save the custom genre if not empty
                  if customGenreInput ~= "" then
                    setSongGenre(song.path, customGenreInput)
                    song.genre = customGenreInput
                    
                    -- Add to genre tags if not already present
                    local found = false
                    for _, g in ipairs(genreTags) do
                      if g == customGenreInput then
                        found = true
                        break
                      end
                    end
                    
                    if not found and customGenreInput ~= "Custom..." then
                      -- Insert before "Custom..." which should be the last entry
                      table.insert(genreTags, #genreTags, customGenreInput)
                    end
                    
                    -- Save genres to ensure they persist
                    saveGenres()
                  end
                  showCustomGenreInput = false
                end
                
                -- Allow user to cancel with Escape key
                if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) and reaper.ImGui_IsItemFocused(ctx) then
                  showCustomGenreInput = false
                end
              else
                -- Show regular dropdown
                if reaper.ImGui_BeginCombo(ctx, "##genre" .. i, currentGenre) then
                  for _, genre in ipairs(genreTags) do
                    local isSelected = (currentGenre == genre)
                    if reaper.ImGui_Selectable(ctx, genre, isSelected) then
                      if genre == "Custom..." then
                        -- Switch to custom input mode
                        showCustomGenreInput = i
                        customGenreInput = currentGenre ~= "Unassigned" and currentGenre or ""
                        -- Focus the input field on the next frame
                        reaper.ImGui_SetKeyboardFocusHere(ctx, 0)
                      else
                        setSongGenre(song.path, genre)
                        song.genre = genre
                      end
                    end
                  end
                  reaper.ImGui_EndCombo(ctx)
                end
              end
              
reaper.ImGui_SameLine(ctx)
if reaper.ImGui_Button(ctx,"L")then
    openLyricsEditor(song.path, song.name)
end
              reaper.ImGui_PopID(ctx)
              
             reaper.ImGui_TableNextColumn(ctx)
reaper.ImGui_PushID(ctx, "buttons" .. i)

local heartIcon = isFavorite(song.path) and "-F" or "+F"
if reaper.ImGui_Button(ctx, heartIcon) then
    toggleFavorite(song.path)
end

reaper.ImGui_SameLine(ctx)

if reaper.ImGui_Button(ctx, "Load") then
    reaper.Undo_BeginBlock()
    loadSong(song.path, 0, false)
    reaper.Undo_EndBlock("Load track: " .. song.name, -1)
end

reaper.ImGui_SameLine(ctx)

if reaper.ImGui_Button(ctx, "+Q") then
    table.insert(queue, song)
    saveQueue(queue)
end
reaper.ImGui_SameLine(ctx)

local playCount = getSongPlayCount(song.path)
reaper.ImGui_Text(ctx, "" .. playCount)
reaper.ImGui_PopID(ctx)
            end
                      
            reaper.ImGui_EndTable(ctx)
          end
        else
          reaper.ImGui_Text(ctx, "No matching audio files found.")
        end
        
        if reaper.ImGui_EndTabItem then reaper.ImGui_EndTabItem(ctx) end
      end
      
      -- Queue Tab
      local queueTabVisible = reaper.ImGui_BeginTabItem and reaper.ImGui_BeginTabItem(ctx, "Queue")
      if queueTabVisible then
        currentTab = 2
        
        reaper.ImGui_Text(ctx, "Playback Queue: " .. #queue .. " tracks")
        
        -- Queue controls
        if reaper.ImGui_Button(ctx, "Process Queue") then
          processQueue()
        end
        
        reaper.ImGui_SameLine(ctx)
        
        if reaper.ImGui_Button(ctx, "Clear Queue") then
          queue = {}
          saveQueue(queue)
        end
        reaper.ImGui_SameLine(ctx)

        -- Add Refresh button
        if reaper.ImGui_Button(ctx, "Refresh Queue") then
          -- Force reload the queue from storage
          queue = loadQueue()
          debug("Queue manually refreshed")
        end
		
		  -- Add Random Loader button
		  if reaper.ImGui_Button(ctx, "Random Loader") then
			openRandomLoader()
		  end
        
        reaper.ImGui_SameLine(ctx)
        
        -- Add Playlist Manager toggle button
        local buttonText = playlistManagerIsOpen and "Close Playlist" or "Open Playlist"
        if reaper.ImGui_Button(ctx, buttonText) then
          togglePlaylistManager()
        end
        reaper.ImGui_Separator(ctx)
        
        -- Queue table
        local queueHeight = windowHeight - 190
        
        if #queue > 0 then
          if reaper.ImGui_BeginTable(ctx, "QueueTable", 4, reaper.ImGui_TableFlags_Borders() + reaper.ImGui_TableFlags_RowBg() + reaper.ImGui_TableFlags_ScrollY(), 0, queueHeight) then
            -- Set up columns
            reaper.ImGui_TableSetupColumn(ctx, "Position", reaper.ImGui_TableColumnFlags_WidthFixed(), 60)
            reaper.ImGui_TableSetupColumn(ctx, "Name", reaper.ImGui_TableColumnFlags_WidthStretch(), 120)
            reaper.ImGui_TableSetupColumn(ctx, "Duration", reaper.ImGui_TableColumnFlags_WidthFixed(), 80)
			reaper.ImGui_TableSetupColumn(ctx, "Actions", reaper.ImGui_TableColumnFlags_WidthFixed(), 200)
            reaper.ImGui_TableHeadersRow(ctx)
            
            -- Display queue items
            for i, song in ipairs(queue) do
              reaper.ImGui_TableNextRow(ctx)
              
              -- Position column
              reaper.ImGui_TableNextColumn(ctx)
              reaper.ImGui_Text(ctx, "#" .. i)
              
              -- Name column
              reaper.ImGui_TableNextColumn(ctx)
              local isSelected = queueSelected == i
              if reaper.ImGui_Selectable(ctx, song.name, isSelected) then
                queueSelected = i
              end
              
              -- Duration column
              reaper.ImGui_TableNextColumn(ctx)
              if song.duration then
                reaper.ImGui_Text(ctx, formatTime(song.duration))
              else
                reaper.ImGui_Text(ctx, "--:--")
              end
              
              -- Actions column
              reaper.ImGui_TableNextColumn(ctx)
              reaper.ImGui_PushID(ctx, "qbuttons" .. i)
              
              if i > 1 and reaper.ImGui_Button(ctx, "^") then
                -- Move up
                local temp = queue[i]
                queue[i] = queue[i-1]
                queue[i-1] = temp
                saveQueue(queue)
              end
              
              reaper.ImGui_SameLine(ctx)
              
              if i < #queue and reaper.ImGui_Button(ctx, "V") then
                -- Move down
                local temp = queue[i]
                queue[i] = queue[i+1]
                queue[i+1] = temp
                saveQueue(queue)
              end
              
              reaper.ImGui_SameLine(ctx)
              
              if reaper.ImGui_Button(ctx, "X") then
                -- Remove from queue
                table.remove(queue, i)
                saveQueue(queue)
                if queueSelected == i then
                  queueSelected = nil
                end
              end
              
              reaper.ImGui_PopID(ctx)
            end
            
            reaper.ImGui_EndTable(ctx)
          end
        else
          reaper.ImGui_Text(ctx, "Your queue is empty. Add tracks from the Browser tab.")
        end
        
        if reaper.ImGui_EndTabItem then reaper.ImGui_EndTabItem(ctx) end
      end
      
      reaper.ImGui_EndTabBar(ctx)
    end
    
    -- Custom footer
    reaper.ImGui_Separator(ctx)

    reaper.ImGui_Spacing(ctx)
    reaper.ImGui_Spacing(ctx)
    -- Display current song in larger text if available
    if lastLoadedSong and lastLoadedSong.name then
      -- Make the "Now Playing" text appear more prominent
      reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFFFFFFFF) -- Bright white text
      reaper.ImGui_Text(ctx, "Now Playing: " .. lastLoadedSong.name)
      reaper.ImGui_PopStyleColor(ctx)
      
      -- Add Video button that opens YouTube search
      if reaper.ImGui_Button(ctx, "Video") then
        -- Get the song name without file extension
        local songNameNoExt = lastLoadedSong.name:gsub("%.%w+$", "")
        -- Append "Official Video" to the search query
        local searchQuery = songNameNoExt .. " Official Video"
        -- Format the search query for URL (replace spaces with +)
        searchQuery = searchQuery:gsub(" ", "+")
        -- Construct YouTube search URL
        local youtubeUrl = "https://www.youtube.com/results?search_query=" .. searchQuery
        -- Open in default browser
        reaper.CF_ShellExecute(youtubeUrl)
      end
	  
		reaper.ImGui_SameLine(ctx)
		reaper.ImGui_Text(ctx, ":" .. getSongPlayCount(lastLoadedSong.path))
      reaper.ImGui_Separator(ctx)
      -- Add a small space between the song info and footer text
      reaper.ImGui_Spacing(ctx)
      reaper.ImGui_Spacing(ctx)
      reaper.ImGui_Spacing(ctx)
    end

    -- Display footer text on its own line
    reaper.ImGui_Text(ctx, "ReconTracks - Backing Track Manager v"..scriptVersion.." - www.twitch.tv/recontastic")
    
    reaper.ImGui_End(ctx)
  end
  
  reaper.defer(loop)
end
  
  reaper.defer(loop)
  return true
end


-- Function to open the Playlist Manager script in its own window
local playlistManagerIsOpen = false
function togglePlaylistManager()
  local scriptPath = reaper.GetResourcePath() .. "\\Scripts\\Recontracks-Playlist.lua"
  
  if playlistManagerIsOpen then
    -- Simply mark as closed since we can't directly close another script's window
    playlistManagerIsOpen = false
    debug("Playlist Manager marked as closed")
    reaper.ShowMessageBox("The Playlist Manager will continue running in its own window. You can close it normally from that window.", "Note", 0)
  else
    -- Check if file exists
    if reaper.file_exists(scriptPath) then
      -- Use ReaScript to run the script in a separate context
      local command = '_SCRIPTNAME:' .. scriptPath
      local commandId = reaper.NamedCommandLookup(command)
      
      if commandId == 0 then
        -- Register the script as an action if it's not already registered
        commandId = reaper.AddRemoveReaScript(true, 0, scriptPath, true)
      end
      
      if commandId ~= 0 then
        -- Run the script as a separate action
        reaper.Main_OnCommand(commandId, 0)
        playlistManagerIsOpen = true
        debug("Playlist Manager opened in separate window")
      else
        debug("Failed to register script as action")
        reaper.ShowMessageBox("Could not run the Playlist Manager script as an action.", "Error", 0)
      end
    else
      -- File not found
      reaper.ShowMessageBox("Could not find Recontracks-Playlist.lua in the Scripts folder.", "Script Not Found", 0)
      debug("Error: Playlist Manager script not found at: " .. scriptPath)
    end
  end
end

-- Function to check for playlist manager updates
function checkPlaylistManagerUpdates()
  -- Check if queue was updated by playlist manager
  local queueUpdateFlag = reaper.GetExtState("ReconTracks", "QueueUpdate")
  local lastCheckedUpdate = reaper.GetExtState("ReconTracks", "LastCheckedQueueUpdate")
  
  if queueUpdateFlag ~= "" and queueUpdateFlag ~= lastCheckedUpdate then
    debug("Queue update detected from Playlist Manager")
    
    -- Update local tracking
    reaper.SetExtState("ReconTracks", "LastCheckedQueueUpdate", queueUpdateFlag, false)
    
    -- Force queue reload
    local newQueue = loadQueue()
    if #newQueue > 0 then
      queue = newQueue  -- Just update the queue variable
      debug("Loaded " .. #queue .. " tracks from external update")
      
      -- Set a flag indicating the queue was updated
      queueUpdated = true
    end
    
    -- Clear the force reload flag
    local forceReloadFlag = reaper.GetExtState("ReconTracks", "ForceReload") 
    if forceReloadFlag ~= "" then
      reaper.SetExtState("ReconTracks", "ForceReload", "", false)
    end
  end
end

-- Browse for a folder and show UI
function browseFolderAndShowUI()
  -- Use standard REAPER file browser
  local lastFolder = getSavedFolder()
  
  -- Browse for a file but extract the folder from it
  local retval, filePath = reaper.GetUserFileNameForRead(lastFolder, "Select ANY file in your backing tracks folder", "")
  
  if retval and filePath then
    -- Extract folder path from file path
    local folder = getFolderFromPath(filePath)
    
    if folder then
      -- Save new folder
      saveFolder(folder)
      -- Return true to signal success
      return true
    end
  end
  
  return false
end

-- Function to open the Random Loader script
function openRandomLoader()
  local scriptPath = reaper.GetResourcePath() .. "\\Scripts\\ReconTracks-RandomLoader.lua"
  
  -- Check if file exists
  if reaper.file_exists(scriptPath) then
    -- Use ReaScript to run the script in a separate context
    local command = '_SCRIPTNAME:' .. scriptPath
    local commandId = reaper.NamedCommandLookup(command)
    
    if commandId == 0 then
      -- Register the script as an action if it's not already registered
      commandId = reaper.AddRemoveReaScript(true, 0, scriptPath, true)
    end
    
    if commandId ~= 0 then
      -- Run the script as a separate action
      reaper.Main_OnCommand(commandId, 0)
      debug("Random Loader opened in separate window")
    else
      debug("Failed to register Random Loader script as action")
      reaper.ShowMessageBox("Could not run the Random Loader script as an action.", "Error", 0)
    end
  else
    -- File not found
    reaper.ShowMessageBox("Could not find Recontracks-RandomLoad.lua in the Scripts folder.", "Script Not Found", 0)
    debug("Error: Random Loader script not found at: " .. scriptPath)
  end
end


  function initPlayCounts()
  loadSongPlayCounts()
end

-- Main function
function main()
  -- Initialize log buffer
  logBuffer = {}
  debug("--- ReconTracks v"..scriptVersion.." Starting ---")
  debug("Disabled console popup by default - use the 'Show Console' button if needed")
  initVolumeMemory()
  loadGenres()
  initPlayCounts()
  -- Check if ImGui is available
  if not reaper.ImGui_CreateContext then
    reaper.ShowMessageBox("This script requires ReaImGui extension.\n\nPlease install it via ReaPack:\n1. Extensions > ReaPack > Browse packages\n2. Search for 'ReaImGui'\n3. Install and restart REAPER", "Missing Dependency", 0)
    
    -- Fall back to standard file browser
    debug("Falling back to standard file browser...")
    local songFolder = getSavedFolder()
    local retval, file = reaper.GetUserFileNameForRead(songFolder, "Select a backing track", "")
    if retval then
      debug("Selected file: " .. file)
      local folderPath = getFolderFromPath(file)
      if folderPath then saveFolder(folderPath) end
      
      reaper.Undo_BeginBlock()
      loadSong(file, 0, false)
      reaper.Undo_EndBlock("Load backing track", -1)
    end
    return
  end
  
  -- Show enhanced UI for song selection
  if not showEnhancedUI() then
    -- If UI failed or was cancelled, fall back to standard file browser
    debug("Falling back to standard file browser...")
    
    -- Get the last used folder or default
    local songFolder = getSavedFolder()
    debug("Opening file browser at: " .. songFolder)
    
    -- Force the file browser to the correct directory (using backslashes for Windows)
    songFolder = songFolder:gsub("/", "\\")
    
    -- Open file browser
    local retval, file = reaper.GetUserFileNameForRead(songFolder, "Select a backing track", "")
    if retval then
      debug("Selected file: " .. file)
      
      -- Save the folder path for next time
      local folderPath = getFolderFromPath(file)
      if folderPath then
        saveFolder(folderPath)
      end
      
      reaper.Undo_BeginBlock()
      if loadSong(file, 0, false) then
        debug("--- ReconTracks Complete ---")
      else
        debug("--- ReconTracks Failed ---")
      end
      reaper.Undo_EndBlock("Load backing track", -1)
    else
      debug("No file selected")
    end
	-- Load previously stored last song info
lastLoadedSong = loadLastLoadedSong()
  end
  
  reaper.UpdateArrange()
end

main()
