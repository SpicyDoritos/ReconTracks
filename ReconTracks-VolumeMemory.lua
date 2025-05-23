-- ReconTracks-VolumeMemory.lua
local volumeMemory = {}

-- Configuration
local VOLUME_DATA_FILE = reaper.GetResourcePath() .. "\\Scripts\\ReconTracks\\volume_memory.json"
local DEBUG = true  -- Set to true to enable debug messages
local MAX_RETRIES = 5  -- Maximum number of retry attempts for setting volume
local RETRY_DELAY = 0.1  -- Delay between retries in seconds
local currentSongPath = nil

-- Initialize module
function volumeMemory.init()
  log("Volume Memory module initialized")
  ensureDirectoryExists(VOLUME_DATA_FILE)
  return true
end

-- Helper function to log debug messages
function log(message)
  if DEBUG then
    reaper.ShowConsoleMsg("[VolumeMemory] " .. message .. "\n")
  end
end

-- Ensure the directory exists for our data file
function ensureDirectoryExists(path)
  local dir = path:match("(.*[/\\])")
  if dir then
    local exists = reaper.file_exists(dir)
    if not exists then
      local success = reaper.RecursiveCreateDirectory(dir, 0)
      if not success then
        log("Failed to create directory: " .. dir)
      else
        log("Created directory: " .. dir)
      end
    end
  end
end

-- Load volume data from JSON file
function loadVolumeData()
  log("Loading volume data from: " .. VOLUME_DATA_FILE)
  local file = io.open(VOLUME_DATA_FILE, "r")
  if not file then
    log("No volume data file found, starting with empty data")
    return {}
  end
  
  local content = file:read("*all")
  file:close()
  
  local data = {}
  for songPath, volume in content:gmatch('"([^"]+)"%s*:%s*([-0-9.]+)') do
    songPath = songPath:gsub('\\\\', '\\'):gsub('\\"', '"')
    data[songPath] = tonumber(volume)
  end
  
  log("Loaded volume data for " .. getTableSize(data) .. " songs")
  return data
end

-- Save volume data to JSON file
function saveVolumeData(data)
  ensureDirectoryExists(VOLUME_DATA_FILE)
  log("Saving volume data to: " .. VOLUME_DATA_FILE)
  
  local file = io.open(VOLUME_DATA_FILE, "w")
  if not file then
    log("ERROR: Failed to open volume data file for writing: " .. VOLUME_DATA_FILE)
    return false
  end
  
  file:write('{\n')
  local songCount = 0
  for songPath, volume in pairs(data) do
    if songCount > 0 then file:write(',\n') end
    local escapedPath = songPath:gsub("\\", "\\\\"):gsub('"', '\\"')
    file:write('  "' .. escapedPath .. '": ' .. volume)
    songCount = songCount + 1
  end
  file:write('\n}')
  file:close()
  
  log("Successfully saved volume data for " .. songCount .. " songs")
  return true
end

-- Get the number of items in a table
function getTableSize(tbl)
  local count = 0
  for _ in pairs(tbl) do count = count + 1 end
  return count
end

-- Find the ReconTracks track
function findReconTrack()
  for i = 0, reaper.CountTracks(0) - 1 do
    local track = reaper.GetTrack(0, i)
    local _, name = reaper.GetTrackName(track)
    if name and (name:match("^ReconTracks") or name == "ReconTracks") then
      log("Found ReconTracks track: " .. name)
      return track
    end
  end
  log("ReconTracks track not found")
  return nil
end

-- Called before loading a new song
function volumeMemory.onBeforeSongLoad()
  log("Before song load - saving current volumes")
  
  -- Get the current song path
  local lastLoadedSong = reaper.GetExtState("ReconTracks", "LastSongPath")
  if lastLoadedSong and lastLoadedSong ~= "" then
    currentSongPath = lastLoadedSong
    log("Current song: " .. currentSongPath)
    
    -- Save the current volumes
    local data = loadVolumeData()
    
    local mainTrack = findReconTrack()
    if mainTrack then
      -- Get track volume
      local volume = reaper.GetMediaTrackInfo_Value(mainTrack, "D_VOL")
      data[currentSongPath] = volume
      log("Saved track volume: " .. volume)
      
      saveVolumeData(data)
    else
      log("No ReconTracks track found to save volumes")
    end
  else
    log("No current song path available")
  end
end

-- Called after loading a new song
function volumeMemory.onAfterSongLoad(songPath)
  log("After song load - restoring volumes for: " .. (songPath or "unknown"))
  currentSongPath = songPath
  
  -- Create a deferred function to handle retries
  local function restoreVolumesWithRetry(attempt)
    -- Find the track and restore volumes
    local mainTrack = findReconTrack()
    if not mainTrack then
      if attempt < MAX_RETRIES then
        log("ReconTracks track not found, retry " .. attempt .. "/" .. MAX_RETRIES)
        reaper.defer(function() restoreVolumesWithRetry(attempt + 1) end)
      else
        log("Failed to find ReconTracks track after " .. MAX_RETRIES .. " attempts")
      end
      return
    end
    
    -- Load saved volume data
    local data = loadVolumeData()
    if not data[songPath] then
      log("No saved volumes found for this song")
      return
    end
    
    -- Set track volume
    local volume = data[songPath]
    log("Restoring track volume to: " .. volume)
    reaper.SetMediaTrackInfo_Value(mainTrack, "D_VOL", volume)
    
    log("Volume restoration complete")
  end
  
  -- Start the restore process after a short delay to ensure track is ready
  reaper.defer(function() restoreVolumesWithRetry(1) end)
end

return volumeMemory