-- Helper functions for UI
  local function calculateTotalTime(songs)
    local total = 0
    for _, song in ipairs(songs) do
      total = total + (song.duration or 0)
    end
    return total
end
 -- ReconTracks-RandomLoad - Random genre-based track loader
-- Version 1.0
-- To be used alongside ReconTracks main script

-- SETTINGS
local scriptVersion = "1.0"
local isConsoleVisible = false -- Set to false to hide console output by default
local logBuffer = {}

-- Function variables
local selectedGenres = {}
local availableGenres = {}
local loadingMode = 1 -- 1 = By Count, 2 = By Time
local trackCount = 5 -- Default number of tracks to load
local totalTime = 600 -- Default time in seconds (10 minutes)
local randomizeQueue = true -- Whether to randomize the order of the queue

-- Debug helper - only shows in console if explicitly toggled
function debug(message)
  table.insert(logBuffer, message)
  -- Only output to console if console is visible AND this isn't a repetitive message
  if isConsoleVisible and not (message:match("^Found %d+ matching songs$") or 
                               message:match("^Selected %d+ random songs") or
                               message:match("^Loading songs from:") or
                               message:match("^Scanning directory:")) then
    reaper.ShowConsoleMsg(message .. "\n")
  end
end

-- Toggle console visibility function
function toggleConsole()
  isConsoleVisible = not isConsoleVisible
  if isConsoleVisible then
    reaper.ShowConsoleMsg("\n--- ReconTracks RandomLoad Console Enabled ---\n")
    -- Show all buffered messages
    for _, msg in ipairs(logBuffer) do
      reaper.ShowConsoleMsg(msg .. "\n")
    end
    reaper.ShowConsoleMsg("\n")
  else
    reaper.ClearConsole()
  end
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

-- Load genres from JSON file
function loadGenres()
  local genreFilePath = reaper.GetResourcePath() .. "\\Scripts\\ReconTracks\\song_genres.json"
  debug("Loading genres from: " .. genreFilePath)
  local file = io.open(genreFilePath, "r")
  if not file then
    debug("No genres file found, nothing to load")
    return false
  end
  
  local content = file:read("*all")
  file:close()
  
  -- Clear existing data
  local songGenres = {}
  
  -- More robust JSON parsing
  -- Look for "path": "genre" patterns
  for path, genre in content:gmatch('"([^"]+)"%s*:%s*"([^"]+)"') do
    -- Unescape path
    path = path:gsub('\\\\', '\\'):gsub('\\"', '"')
    
    -- Add to collection
    songGenres[path] = genre
    
    -- Add to available genres if not already in the list
    local genreFound = false
    for _, g in ipairs(availableGenres) do
      if g == genre then
        genreFound = true
        break
      end
    end
    
    if not genreFound and genre ~= "Unassigned" then
      table.insert(availableGenres, genre)
    end
  end
  
  -- Sort genres alphabetically
  table.sort(availableGenres)
  
  debug("Loaded genres: " .. table.concat(availableGenres, ", "))
  
  return songGenres
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

-- Load song list from folder and filter by genres
function loadSongsFilteredByGenres(songFolder, songGenres, selectedGenres)
  if #selectedGenres == 0 then
    debug("No genres selected, returning empty list")
    return {}
  end
  
  debug("Loading songs from: " .. songFolder)
  
  -- Create a set for faster lookups of selected genres
  local genreSet = {}
  for _, genre in ipairs(selectedGenres) do
    genreSet[genre] = true
  end
  
  local songs = {}
  local i = 0
  
  debug("Scanning directory: " .. songFolder)
  repeat
    -- Get next file in directory
    local fileName = reaper.EnumerateFiles(songFolder, i)
    if fileName and isAudioFile(fileName) then
      -- Get full path
      local fullPath = songFolder .. "\\" .. fileName
      
      -- Check if the file's genre is in the selected genres
      local songGenre = songGenres[fullPath] or "Unassigned"
      
      if genreSet[songGenre] then
        local songInfo = { name = fileName, path = fullPath, genre = songGenre }
        
        -- Try to get duration info for the file
        local mediaSource = reaper.PCM_Source_CreateFromFile(fullPath)
        if mediaSource then
          songInfo.duration = reaper.GetMediaSourceLength(mediaSource)
          reaper.PCM_Source_Destroy(mediaSource)
        else
          songInfo.duration = 0
        end
        
        table.insert(songs, songInfo)
        debug("Found matching audio file: " .. fileName .. " [" .. songGenre .. "]")
      end
    end
    i = i + 1
  until not fileName
  
  debug("Found " .. #songs .. " matching songs")
  return songs
end

-- Fisher-Yates shuffle algorithm to randomize array
function shuffleArray(array)
  local randomIndex
  local currentIndex = #array
  
  while currentIndex > 1 do
    randomIndex = math.random(currentIndex)
    array[currentIndex], array[randomIndex] = array[randomIndex], array[currentIndex]
    currentIndex = currentIndex - 1
  end
  
  return array
end

-- Select random songs by count
function selectRandomSongsByCount(songs, count)
  if #songs == 0 then
    debug("No matching songs found")
    return {}
  end
  
  -- Create a copy of the array to shuffle
  local shuffledSongs = {}
  for i = 1, #songs do
    shuffledSongs[i] = songs[i]
  end
  
  -- Shuffle the array
  shuffleArray(shuffledSongs)
  
  -- Take the first 'count' elements or all if there are fewer
  local selectedCount = math.min(count, #shuffledSongs)
  local selectedSongs = {}
  
  for i = 1, selectedCount do
    table.insert(selectedSongs, shuffledSongs[i])
  end
  
  debug("Selected " .. #selectedSongs .. " random songs by count")
  return selectedSongs
end

-- Select random songs by total time
function selectRandomSongsByTime(songs, maxTime)
  if #songs == 0 then
    debug("No matching songs found")
    return {}
  end
  
  -- Create a copy of the array to shuffle
  local shuffledSongs = {}
  for i = 1, #songs do
    shuffledSongs[i] = songs[i]
  end
  
  -- Shuffle the array
  shuffleArray(shuffledSongs)
  
  local selectedSongs = {}
  local totalDuration = 0
  
  for i = 1, #shuffledSongs do
    local song = shuffledSongs[i]
    local duration = song.duration or 0
    
    if (totalDuration + duration) <= maxTime then
      table.insert(selectedSongs, song)
      totalDuration = totalDuration + duration
    end
  end
  
  debug("Selected " .. #selectedSongs .. " random songs with total time: " .. totalDuration .. "s (max: " .. maxTime .. "s)")
  return selectedSongs
end

-- Format seconds to MM:SS
function formatTime(seconds)
  if not seconds or seconds <= 0 then return "00:00" end
  local mins = math.floor(seconds / 60)
  local secs = math.floor(seconds % 60)
  return string.format("%02d:%02d", mins, secs)
end

-- Get folder from ReconTracks storage
function getSongFolder()
  local lastFolder = reaper.GetExtState("ReconTracks", "LastFolder")
  if lastFolder and lastFolder ~= "" then
    debug("Using ReconTracks folder: " .. lastFolder)
    return lastFolder
  else
    -- Return a default folder if not found
    local desktop = reaper.GetResourcePath():match("(.+)[/\\]"):match("(.+)[/\\]") .. "\\Desktop"
    debug("No folder found in ReconTracks storage, using desktop: " .. desktop)
    return desktop
  end
end

-- Save queue to ReconTracks storage
function saveToQueue(songs)
  local queueStr = ""
  for i, song in ipairs(songs) do
    queueStr = queueStr .. song.path
    if i < #songs then queueStr = queueStr .. "|" end
  end
  
  -- Save to ReconTracks queue storage
  reaper.SetExtState("ReconTracks", "Queue", queueStr, true)
  
  -- Set a flag for ReconTracks to detect the change
  reaper.SetExtState("ReconTracks", "QueueUpdate", tostring(os.time()), false)
  
  debug("Saved " .. #songs .. " tracks to ReconTracks queue")
end

-- Main UI function
function showRandomLoaderUI()
  -- Make sure ImGui is available
  if not reaper.ImGui_CreateContext then
    reaper.ShowMessageBox("This script requires ReaImGui extension.\n\nPlease install it via ReaPack:\n1. Extensions > ReaPack > Browse packages\n2. Search for 'ReaImGui'\n3. Install and restart REAPER", "Missing Dependency", 0)
    return false
  end
  
  -- Initialize random seed
  math.randomseed(os.time())
  
  -- Load genres and song metadata
  local songGenres = loadGenres()
  if not songGenres or next(songGenres) == nil then
    reaper.ShowMessageBox("No genre information found.\nPlease use ReconTracks to tag some songs with genres first.", "No Genre Data", 0)
    return false
  end
  
  -- Initialize ImGui context
  local ctx = reaper.ImGui_CreateContext('ReconTracks Random Loader')
  initImGuiKeys()
  
  local open = true
  local windowWidth = 600
  local windowHeight = 400
  
  -- Variables to store calculation results (to avoid recalculating every frame)
  local cachedFilteredSongs = {}
  local cachedPreviewSongCount = 0
  local cachedPreviewTime = 0
  local needsRecalculation = true
  local lastCalculationParams = {
    selectedGenres = {},
    loadingMode = loadingMode,
    trackCount = trackCount,
    totalTime = totalTime
  }
  
  -- Function to check if we need to recalculate
  local function checkNeedsRecalculation()
    -- Check if selected genres have changed
    if #selectedGenres ~= #lastCalculationParams.selectedGenres then
      return true
    end
    
    for i, genre in ipairs(selectedGenres) do
      if lastCalculationParams.selectedGenres[i] ~= genre then
        return true
      end
    end
    
    -- Check if other parameters have changed
    if lastCalculationParams.loadingMode ~= loadingMode or
       lastCalculationParams.trackCount ~= trackCount or
       lastCalculationParams.totalTime ~= totalTime then
      return true
    end
    
    return false
  end
  
  -- Function to update calculation cache
  local function updateCalculationCache()
    -- Update the lastCalculationParams
    lastCalculationParams = {
      selectedGenres = {},
      loadingMode = loadingMode,
      trackCount = trackCount,
      totalTime = totalTime
    }
    
    for _, genre in ipairs(selectedGenres) do
      table.insert(lastCalculationParams.selectedGenres, genre)
    end
    
    -- Get folder and filtered songs
    local songFolder = getSongFolder()
    cachedFilteredSongs = loadSongsFilteredByGenres(songFolder, songGenres, selectedGenres)
    
    -- Calculate preview info based on mode
    if loadingMode == 0 then -- By Count
      cachedPreviewSongCount = math.min(trackCount, #cachedFilteredSongs)
      local previewSongs = selectRandomSongsByCount(cachedFilteredSongs, cachedPreviewSongCount)
      cachedPreviewTime = calculateTotalTime(previewSongs)
    else -- By Time
      local previewSongs = selectRandomSongsByTime(cachedFilteredSongs, totalTime)
      cachedPreviewSongCount = #previewSongs
      cachedPreviewTime = calculateTotalTime(previewSongs)
    end
    
    needsRecalculation = false
  end
  
  -- Main UI loop
  function loop()
    -- Exit if window closed
    if not open then
      if reaper.ImGui_DestroyContext then
        reaper.ImGui_DestroyContext(ctx)
      end
      return
    end
    
    -- Window flags
    local windowFlags = reaper.ImGui_WindowFlags_NoCollapse()
    
    -- Set window size
    reaper.ImGui_SetNextWindowSize(ctx, windowWidth, windowHeight, reaper.ImGui_Cond_FirstUseEver())
    
    -- Display window
    local visible, openState = reaper.ImGui_Begin(ctx, 'ReconTracks Random Loader v' .. scriptVersion, true, windowFlags)
    open = openState
    
    if visible then
      -- Top toolbar
      if reaper.ImGui_BeginTable(ctx, "toolbar", 3, reaper.ImGui_TableFlags_None()) then
        reaper.ImGui_TableNextColumn(ctx)
        
        -- Toggle console button
        if reaper.ImGui_Button(ctx, isConsoleVisible and "Hide Console" or "Show Console") then
          toggleConsole()
        end
        
        reaper.ImGui_TableNextColumn(ctx)
        
        -- Help button
        if reaper.ImGui_Button(ctx, "Help") then
          reaper.ShowMessageBox(
            "ReconTracks Random Loader v" .. scriptVersion .. "\n\n" ..
            "This tool lets you randomly load tracks by genre into your ReconTracks queue.\n\n" ..
            "1. Select one or more genres from the list\n" ..
            "2. Choose to load by count or by total time\n" ..
            "3. Set your desired count or time\n" ..
            "4. Click 'Load Random Tracks' to add to queue\n" ..
            "5. Go back to ReconTracks and process the queue\n\n" ..
            "For best results, tag your tracks with genres in ReconTracks first.",
            "Random Loader Help", 0)
        end
        
        reaper.ImGui_TableNextColumn(ctx)
        
        -- Mode selection
        reaper.ImGui_Text(ctx, "Loading Mode:")
        reaper.ImGui_SameLine(ctx)
        
        reaper.ImGui_SetNextItemWidth(ctx, 150)
        -- FIX: Properly null-terminate the combo items string
        local modeItems = "By Count\0By Time\0\0"  -- Double null at the end
        local rv, newMode = reaper.ImGui_Combo(ctx, "##mode", loadingMode, modeItems)
        if rv then 
          loadingMode = newMode 
          needsRecalculation = true
        end
        
        reaper.ImGui_EndTable(ctx)
      end
      
      reaper.ImGui_Separator(ctx)
      
      -- Main content area
      -- Use a table for layout instead of columns
      if reaper.ImGui_BeginTable(ctx, "layout", 2, reaper.ImGui_TableFlags_None()) then
        reaper.ImGui_TableNextColumn(ctx)
        
        -- Left column - Genre selection
        reaper.ImGui_Text(ctx, "Select Genres:")
        
        -- Calculate available height for genre list
        local genreListHeight = windowHeight - 200
        
        if reaper.ImGui_BeginChild(ctx, "GenreList", 0, genreListHeight) then
          for i, genre in ipairs(availableGenres) do
            local isSelected = false
            for _, selectedGenre in ipairs(selectedGenres) do
              if selectedGenre == genre then
                isSelected = true
                break
              end
            end
            
            reaper.ImGui_PushID(ctx, "genre" .. i)
            local rv, checked = reaper.ImGui_Checkbox(ctx, genre, isSelected)
            
            if rv then
              if checked then
                table.insert(selectedGenres, genre)
              else
                for j = #selectedGenres, 1, -1 do
                  if selectedGenres[j] == genre then
                    table.remove(selectedGenres, j)
                    break
                  end
                end
              end
            end
            reaper.ImGui_PopID(ctx)
          end
          reaper.ImGui_EndChild(ctx)
        end
        
        -- Select/Clear all buttons
        if reaper.ImGui_Button(ctx, "Select All") then
          selectedGenres = {}
          for _, genre in ipairs(availableGenres) do
            table.insert(selectedGenres, genre)
          end
        end
        
        reaper.ImGui_SameLine(ctx)
        
        if reaper.ImGui_Button(ctx, "Clear All") then
          selectedGenres = {}
        end
        
        -- Right column - Settings
        reaper.ImGui_TableNextColumn(ctx)
      
      -- Settings based on mode
      if loadingMode == 0 then -- By Count
        reaper.ImGui_Text(ctx, "Number of tracks to load:")
        reaper.ImGui_SetNextItemWidth(ctx, 150)  -- INCREASED WIDTH
        local rv, newCount = reaper.ImGui_InputInt(ctx, "##count", trackCount, 1)
        if rv then
          trackCount = math.max(1, newCount) -- Ensure at least 1 track
          needsRecalculation = true
        end
      else -- By Time
        reaper.ImGui_Text(ctx, "Maximum time (minutes:seconds):")
        
        -- Convert total seconds to minutes and seconds for UI
        local minutes = math.floor(totalTime / 60)
        local seconds = totalTime % 60
        
        -- Display minutes input - INCREASED WIDTH
        reaper.ImGui_SetNextItemWidth(ctx, 120)
        local rv1, newMinutes = reaper.ImGui_InputInt(ctx, "Minutes##min", minutes, 1)
        
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Text(ctx, ":")
        reaper.ImGui_SameLine(ctx)
        
        -- Display seconds input - INCREASED WIDTH
        reaper.ImGui_SetNextItemWidth(ctx, 120)
        local rv2, newSeconds = reaper.ImGui_InputInt(ctx, "Seconds##sec", seconds, 5)
        
        -- Update total time if either input changed
        if rv1 or rv2 then
          newMinutes = math.max(0, newMinutes)
          newSeconds = math.min(59, math.max(0, newSeconds))
          totalTime = (newMinutes * 60) + newSeconds
          needsRecalculation = true
        end
      end
      
      -- Randomize order option
      local rv, newRandomize = reaper.ImGui_Checkbox(ctx, "Randomize Queue Order", randomizeQueue)
      if rv then randomizeQueue = newRandomize end
      
      -- Preview calculation
      reaper.ImGui_Spacing(ctx)
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Spacing(ctx)
      
      -- Check if we need to recalculate
      if needsRecalculation or checkNeedsRecalculation() then
        updateCalculationCache()
      end
      
      -- Display info using cached values to avoid UI jumping
      reaper.ImGui_Text(ctx, "Found " .. #cachedFilteredSongs .. " tracks matching selected genres")
      
      if loadingMode == 0 then -- By Count
        reaper.ImGui_Text(ctx, "Will load " .. cachedPreviewSongCount .. " random tracks")
        reaper.ImGui_Text(ctx, "Estimated total time: " .. formatTime(cachedPreviewTime))
      else -- By Time
        reaper.ImGui_Text(ctx, "Will load approximately " .. cachedPreviewSongCount .. " tracks")
        reaper.ImGui_Text(ctx, "Estimated total time: " .. formatTime(cachedPreviewTime))
      end
      
      reaper.ImGui_Spacing(ctx)
      
      -- Main action button
      if reaper.ImGui_Button(ctx, "Load Random Tracks", 0, 40) then
        if #selectedGenres == 0 then
          reaper.ShowMessageBox("Please select at least one genre first.", "No Genres Selected", 0)
        elseif #cachedFilteredSongs == 0 then
          reaper.ShowMessageBox("No tracks found with the selected genres.\nTry selecting different genres.", "No Matching Tracks", 0)
        else
          -- Select random songs based on mode
          local selectedSongs
          if loadingMode == 0 then -- By Count
            selectedSongs = selectRandomSongsByCount(cachedFilteredSongs, trackCount)
          else -- By Time
            selectedSongs = selectRandomSongsByTime(cachedFilteredSongs, totalTime)
          end
          
          if #selectedSongs > 0 then
            -- Randomize order if needed
            if not randomizeQueue then
              -- Sort by name if not randomizing
              table.sort(selectedSongs, function(a, b) return a.name < b.name end)
            end
            
            -- Save to ReconTracks queue
            saveToQueue(selectedSongs)
            
            -- Show success message
            local totalTimeLoaded = calculateTotalTime(selectedSongs)
            reaper.ShowMessageBox(
              "Successfully added " .. #selectedSongs .. " random tracks to ReconTracks queue.\n" ..
              "Total time: " .. formatTime(totalTimeLoaded) .. "\n\n" ..
              "Go back to ReconTracks and use 'Process Queue' to load them.",
              "Success", 0)
          else
            reaper.ShowMessageBox("Failed to select any tracks. Try different settings.", "No Tracks Selected", 0)
          end
        end
      end
      
        -- Reset table layout
        reaper.ImGui_EndTable(ctx)
      end
      
      -- Bottom status bar
      reaper.ImGui_Separator(ctx)
      reaper.ImGui_Text(ctx, "ReconTracks Random Loader v" .. scriptVersion .. " - Selected " .. #selectedGenres .. " genres")
      
      reaper.ImGui_End(ctx)
    end
    
    reaper.defer(loop)
  end
  
  reaper.defer(loop)
  return true
end

-- Main function
function main()
  -- Initialize log buffer
  logBuffer = {}
  debug("--- ReconTracks Random Loader v" .. scriptVersion .. " Starting ---")
  
  showRandomLoaderUI()
end

main()