-- ReconTracks Playlist - Playlist manager addon for ReconTracks
-- Version 1.0

-- Settings
local scriptVersion = "1.0"
local playlists = {}
local currentPlaylistName = ""
local isConsoleVisible = false
local logBuffer = {}

-- Debug helper - only shows in console if explicitly toggled
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
    reaper.ShowConsoleMsg("\n--- ReconTracks Playlist Console Enabled ---\n")
    -- Show all buffered messages
    for _, msg in ipairs(logBuffer) do
      reaper.ShowConsoleMsg(msg .. "\n")
    end
    reaper.ShowConsoleMsg("\n")
  else
    reaper.ClearConsole()
  end
end

-- Load playlists from ExtState
function loadPlaylists()
  local playlistsData = reaper.GetExtState("ReconTracksPlaylist", "Playlists")
  playlists = {}
  
  if playlistsData and playlistsData ~= "" then
    debug("Loading saved playlists")
    
    for playlistEntry in playlistsData:gmatch("([^;]+)") do
      local playlistName, songPaths = playlistEntry:match("^(.-)=(.+)$")
      
      if playlistName and songPaths then
        local songList = {}
        
        for path in songPaths:gmatch("([^|]+)") do
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
            table.insert(songList, songInfo)
          end
        end
        
        playlists[playlistName] = songList
        debug("Loaded playlist: " .. playlistName .. " with " .. #songList .. " tracks")
      end
    end
  end
  
  return playlists
end

-- Save playlists to ExtState
function savePlaylists()
  local playlistsData = ""
  local playlistNames = {}
  
  -- Get list of all playlist names
  for name, _ in pairs(playlists) do
    table.insert(playlistNames, name)
  end
  
  -- Sort playlist names alphabetically
  table.sort(playlistNames)
  
  -- Serialize each playlist
  for i, name in ipairs(playlistNames) do
    local songList = playlists[name]
    local songPaths = ""
    
    for j, song in ipairs(songList) do
      songPaths = songPaths .. song.path
      if j < #songList then songPaths = songPaths .. "|" end
    end
    
    playlistsData = playlistsData .. name .. "=" .. songPaths
    if i < #playlistNames then playlistsData = playlistsData .. ";" end
  end
  
  reaper.SetExtState("ReconTracksPlaylist", "Playlists", playlistsData, true)
  debug("Saved " .. #playlistNames .. " playlists")
end

-- Get current queue from ReconTracks
function getCurrentQueue()
  local queueStr = reaper.GetExtState("ReconTracks", "Queue")
  local queue = {}
  
  if queueStr and queueStr ~= "" then
    debug("Raw queue string: " .. (queueStr:sub(1, 100) .. (queueStr:len() > 100 and "..." or "")))
    
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
    debug("Retrieved current queue with " .. #queue .. " items")
  else
    debug("Current queue is empty")
  end
  
  return queue
end

-- Set current queue for ReconTracks
function setCurrentQueue(queue)
  local queueStr = ""
  for i, song in ipairs(queue) do
    queueStr = queueStr .. song.path
    if i < #queue then queueStr = queueStr .. "|" end
  end
  
  -- Show some debug info about what we're setting
  debug("Setting queue with " .. #queue .. " items")
  
  -- Set the ext state with the new queue
  reaper.SetExtState("ReconTracks", "Queue", queueStr, true)
  
  -- Notify ReconTracks of the change with a timestamp
  local timestamp = tostring(os.time())
  reaper.SetExtState("ReconTracks", "QueueUpdate", timestamp, false)
  reaper.SetExtState("ReconTracks", "ForceReload", "1", false)
  
  -- Also write a temporary file as a backup communication method
  local resourcePath = reaper.GetResourcePath()
  local triggerPath = resourcePath .. "/Scripts/ReconTracks_trigger.tmp"
  local file = io.open(triggerPath, "w")
  if file then
    file:write(timestamp)
    file:close()
    debug("Wrote trigger file at: " .. triggerPath)
  end
end 

-- Format seconds to MM:SS
function formatTime(seconds)
  if not seconds or seconds <= 0 then return "00:00" end
  local mins = math.floor(seconds / 60)
  local secs = math.floor(seconds % 60)
  return string.format("%02d:%02d", mins, secs)
end

-- Calculate total playlist duration
function calculatePlaylistDuration(songList)
  local total = 0
  for _, song in ipairs(songList) do
    if song.duration then
      total = total + song.duration
    end
  end
  return total
end

-- Generate a unique default playlist name
function generatePlaylistName()
  local base = "Playlist"
  local index = 1
  local name = base .. " " .. index
  
  while playlists[name] do
    index = index + 1
    name = base .. " " .. index
  end
  
  return name
end

-- Get total number of songs across all playlists
function getTotalSongCount()
  local count = 0
  for _, songList in pairs(playlists) do
    count = count + #songList
  end
  return count
end

-- Main playlist manager UI
function showPlaylistManagerUI()
  debug("Opening playlist manager UI")
  
  -- Load saved playlists
  loadPlaylists()
  
  -- Create window context
  local ctx = reaper.ImGui_CreateContext('ReconTracks Playlist')
  
  -- UI variables
  local open = true
  local selectedPlaylist = nil
  local selectedPlaylistName = nil
  local selectedSongIndex = nil
  local windowWidth = 700
  local windowHeight = 500
  local newPlaylistName = ""
  local renamePlaylistName = ""
  local isRenaming = false
  local confirmDelete = false
  local confirmDeleteName = nil
  local showExportWindow = false
  local showImportWindow = false
  local exportFilename = "playlist.txt"
  local importFilename = ""
  
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
    local visible, openState = reaper.ImGui_Begin(ctx, 'ReconTracks Playlist Manager v'..scriptVersion, true, windowFlags)
    open = openState
    
    if visible then
      -- Toolbar section
      if reaper.ImGui_BeginTable(ctx, "toolbar", 4, reaper.ImGui_TableFlags_None()) then
        reaper.ImGui_TableNextColumn(ctx)
        
        -- Toggle console button
        if reaper.ImGui_Button(ctx, isConsoleVisible and "Hide Console" or "Show Console") then
          toggleConsole()
        end
        
        reaper.ImGui_TableNextColumn(ctx)
        -- Export playlists button
        if reaper.ImGui_Button(ctx, "Export Playlists") then
          showExportWindow = true
        end
        
        reaper.ImGui_TableNextColumn(ctx)
        -- Import playlists button
        if reaper.ImGui_Button(ctx, "Import Playlists") then
          showImportWindow = true
        end
        
        reaper.ImGui_TableNextColumn(ctx)
        -- Help button
        if reaper.ImGui_Button(ctx, "Help") then
          reaper.ShowMessageBox(
            "ReconTracks Playlist Manager v"..scriptVersion.."\n\n" ..
            "- Create Playlist: Save current queue as a playlist\n" ..
            "- Load to Queue: Replace current queue with selected playlist\n" ..
            "- Append to Queue: Add playlist songs to current queue\n" ..
            "- Rename: Change playlist name\n" ..
            "- Delete: Remove playlist\n" ..
            "- Export: Save playlists to a file\n" ..
            "- Import: Load playlists from a file\n\n" ..
            "This addon works with ReconTracks v2.0+",
            "ReconTracks Playlist Help", 0)
        end
        
        reaper.ImGui_EndTable(ctx)
      end
      
      reaper.ImGui_Separator(ctx)
      
      -- Main content area - split into left and right panes
      if reaper.ImGui_BeginTable(ctx, "mainSplit", 2, reaper.ImGui_TableFlags_None()) then
        -- Left pane - Playlist list
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_BeginChild(ctx, "PlaylistsPane", windowWidth * 0.3, windowHeight - 150)
        
        reaper.ImGui_Text(ctx, "Playlists")
        reaper.ImGui_Separator(ctx)
        
        -- Get count of playlists
        local playlistCount = 0
        for _ in pairs(playlists) do playlistCount = playlistCount + 1 end
        
        if playlistCount > 0 then
          -- Create playlist table
          local playlistNames = {}
          for name, _ in pairs(playlists) do
            table.insert(playlistNames, name)
          end
          
          -- Sort alphabetically
          table.sort(playlistNames)
          
          -- Display each playlist
          for _, name in ipairs(playlistNames) do
            local songList = playlists[name]
            local isSelected = selectedPlaylistName == name
            
            -- Playlist entry with song count
            if reaper.ImGui_Selectable(ctx, name .. " (" .. #songList .. ")", isSelected) then
              selectedPlaylistName = name
              selectedPlaylist = songList
              selectedSongIndex = nil
            end
          end
        else
          reaper.ImGui_Text(ctx, "No playlists yet")
        end
        
        reaper.ImGui_EndChild(ctx)
        
        -- Create playlist controls
        if reaper.ImGui_Button(ctx, "Create From Queue") then
  local queue = getCurrentQueue()
  if #queue > 0 then
    -- Generate a default name
    newPlaylistName = generatePlaylistName()
    
    -- Directly create the playlist without popup (simpler approach)
    playlists[newPlaylistName] = queue
    savePlaylists()
    selectedPlaylistName = newPlaylistName
    selectedPlaylist = playlists[newPlaylistName]
    
    reaper.ShowMessageBox("Created new playlist '" .. newPlaylistName .. "' with " .. #queue .. " tracks.", "ReconTracks Playlist", 0)
  else
    reaper.ShowMessageBox("Current queue is empty. Add tracks to queue first.", "ReconTracks Playlist", 0)
  end
end

reaper.ImGui_SameLine(ctx)

-- Delete playlist button
if selectedPlaylistName and reaper.ImGui_Button(ctx, "Delete") then
  confirmDeleteName = selectedPlaylistName
  confirmDelete = true
  reaper.ImGui_OpenPopup(ctx, "ConfirmDeletePopup")
end
        
        -- Right pane - Selected playlist content
        reaper.ImGui_TableNextColumn(ctx)
        reaper.ImGui_BeginChild(ctx, "PlaylistContentPane", 0, windowHeight - 150)
        
        if selectedPlaylistName and selectedPlaylist then
          -- Playlist header with info
          reaper.ImGui_Text(ctx, "Playlist: " .. selectedPlaylistName)
          local totalDuration = calculatePlaylistDuration(selectedPlaylist)
          reaper.ImGui_SameLine(ctx)
          reaper.ImGui_Text(ctx, "(" .. #selectedPlaylist .. " tracks, " .. formatTime(totalDuration) .. ")")
          
          -- Playlist action buttons
         -- Load to Queue button
if reaper.ImGui_Button(ctx, "Load to Queue") then
  -- Save the playlist to the queue
  setCurrentQueue(selectedPlaylist)
  
  -- Try to run a ReconTracks action if available
  local command_id = reaper.NamedCommandLookup("_RS4cd7885a3e4e4a94c4ab0f1b79f98469815ec6f0")
  if command_id > 0 then
    -- This would be a custom action in ReconTracks to refresh the queue
    reaper.Main_OnCommand(command_id, 0)
    debug("Triggered ReconTracks refresh action")
  end
  
  -- Show confirmation
  reaper.ShowMessageBox("Playlist '" .. selectedPlaylistName .. "' loaded to queue. You may need to refresh ReconTracks.", "ReconTracks Playlist", 0)
end

reaper.ImGui_SameLine(ctx)

-- Append to Queue button
if reaper.ImGui_Button(ctx, "Append to Queue") then
  -- Get current queue paths
  local currentQueue = getCurrentQueue()
  local originalSize = #currentQueue
  
  -- Add each song from the playlist
  for _, song in ipairs(selectedPlaylist) do
    table.insert(currentQueue, song)
  end
  
  -- Set the updated queue
  setCurrentQueue(currentQueue)
  
  -- Try to run a ReconTracks action if available
  local command_id = reaper.NamedCommandLookup("_RS4cd7885a3e4e4a94c4ab0f1b79f98469815ec6f0")
  if command_id > 0 then
    -- This would be a custom action in ReconTracks to refresh the queue
    reaper.Main_OnCommand(command_id, 0)
    debug("Triggered ReconTracks refresh action")
  end
  
  -- Show confirmation
  reaper.ShowMessageBox("Playlist '" .. selectedPlaylistName .. "' appended to queue. Added " .. 
                       #selectedPlaylist .. " tracks. You may need to refresh ReconTracks.", "ReconTracks Playlist", 0)
end

reaper.ImGui_SameLine(ctx)


if reaper.ImGui_Button(ctx, "Rename") then
  renamePlaylistName = selectedPlaylistName
  isRenaming = true
  reaper.ImGui_OpenPopup(ctx, "RenamePlaylistPopup")
end
          
          reaper.ImGui_Separator(ctx)
          
          -- Playlist content table
          if #selectedPlaylist > 0 then
            -- Calculate remaining height for song table
            local tableHeight = windowHeight - 200
            
            if reaper.ImGui_BeginTable(ctx, "SongTable", 3, reaper.ImGui_TableFlags_Borders() + reaper.ImGui_TableFlags_RowBg() + reaper.ImGui_TableFlags_ScrollY(), 0, tableHeight) then
              -- Set up columns
              reaper.ImGui_TableSetupColumn(ctx, "#", reaper.ImGui_TableColumnFlags_WidthFixed(), 40)
              reaper.ImGui_TableSetupColumn(ctx, "Track Name", reaper.ImGui_TableColumnFlags_WidthStretch())
              reaper.ImGui_TableSetupColumn(ctx, "Duration", reaper.ImGui_TableColumnFlags_WidthFixed(), 80)
              reaper.ImGui_TableHeadersRow(ctx)
              
              -- Display songs
              for i, song in ipairs(selectedPlaylist) do
                reaper.ImGui_TableNextRow(ctx)
                
                -- Position column
                reaper.ImGui_TableNextColumn(ctx)
                reaper.ImGui_Text(ctx, tostring(i))
                
                -- Name column
                reaper.ImGui_TableNextColumn(ctx)
                local isSelected = selectedSongIndex == i
                if reaper.ImGui_Selectable(ctx, song.name, isSelected) then
                  selectedSongIndex = i
                end
                
                -- Duration column
                reaper.ImGui_TableNextColumn(ctx)
                if song.duration then
                  reaper.ImGui_Text(ctx, formatTime(song.duration))
                else
                  reaper.ImGui_Text(ctx, "--:--")
                end
              end
              
              reaper.ImGui_EndTable(ctx)
            end
          else
            reaper.ImGui_Text(ctx, "Playlist is empty")
          end
        else
          reaper.ImGui_Text(ctx, "Select a playlist from the list on the left")
        end
        
        reaper.ImGui_EndChild(ctx)
        
        reaper.ImGui_EndTable(ctx)
      end
      
      -- Status bar
      reaper.ImGui_Separator(ctx)
      local totalPlaylists = 0
      for _ in pairs(playlists) do totalPlaylists = totalPlaylists + 1 end
      local totalSongs = getTotalSongCount()
      reaper.ImGui_Text(ctx, "Total: " .. totalPlaylists .. " playlists, " .. totalSongs .. " tracks")
      
      -- Footer
      reaper.ImGui_Spacing(ctx)
      reaper.ImGui_Text(ctx, "ReconTracks Playlist Manager v" .. scriptVersion .. " - Companion for ReconTracks")
      
      -- Modal popups
	   
  -- Confirm delete popup
if confirmDelete then
  reaper.ImGui_OpenPopup(ctx, "ConfirmDeletePopup")
  confirmDelete = false
end

if reaper.ImGui_BeginPopupModal(ctx, "ConfirmDeletePopup", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
  reaper.ImGui_Text(ctx, "Delete playlist '" .. (confirmDeleteName or "") .. "'?")
  reaper.ImGui_Text(ctx, "This action cannot be undone.")
  
  reaper.ImGui_Separator(ctx)
  
  if reaper.ImGui_Button(ctx, "Delete", 120, 0) then
    -- Remove the playlist
    playlists[confirmDeleteName] = nil
    savePlaylists()
    
    -- Clear selection if deleted playlist was selected
    if selectedPlaylistName == confirmDeleteName then
      selectedPlaylistName = nil
      selectedPlaylist = nil
      selectedSongIndex = nil
    end
    
    -- Show confirmation
    reaper.ShowMessageBox("Playlist '" .. confirmDeleteName .. "' has been deleted.", "ReconTracks Playlist", 0)
    confirmDeleteName = nil
    reaper.ImGui_CloseCurrentPopup(ctx)
  end
  
  reaper.ImGui_SameLine(ctx)
  
  if reaper.ImGui_Button(ctx, "Cancel", 120, 0) then
    confirmDeleteName = nil
    reaper.ImGui_CloseCurrentPopup(ctx)
  end
  
  reaper.ImGui_EndPopup(ctx)
end
      -- Create playlist popup
      if reaper.ImGui_BeginPopupModal(ctx, "CreatePlaylistPopup", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
  reaper.ImGui_Text(ctx, "Enter playlist name:")
  local rv, new_name = reaper.ImGui_InputText(ctx, "##playlistname", newPlaylistName)
  if rv then newPlaylistName = new_name end
  
  reaper.ImGui_Separator(ctx)
 

  if reaper.ImGui_Button(ctx, "Save", 120, 0) then
    if newPlaylistName ~= "" then
      -- Check if name already exists
      if playlists[newPlaylistName] then
        -- Append a number if name exists
        local baseName = newPlaylistName
        local index = 1
        while playlists[newPlaylistName] do
          index = index + 1
          newPlaylistName = baseName .. " " .. index
        end
      end
      
      -- Save current queue as playlist
      playlists[newPlaylistName] = getCurrentQueue()
      savePlaylists()
      selectedPlaylistName = newPlaylistName
      selectedPlaylist = playlists[newPlaylistName]
      reaper.ImGui_CloseCurrentPopup(ctx)
    end
  end
  
  reaper.ImGui_SameLine(ctx)
  
  if reaper.ImGui_Button(ctx, "Cancel", 120, 0) then
    reaper.ImGui_CloseCurrentPopup(ctx)
  end
  
  
  reaper.ImGui_EndPopup(ctx)
end
      
      -- Rename playlist popup
if isRenaming then
  reaper.ImGui_OpenPopup(ctx, "RenamePlaylistPopup")
end

if reaper.ImGui_BeginPopupModal(ctx, "RenamePlaylistPopup", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
  reaper.ImGui_Text(ctx, "Enter new name for playlist:")
  local rv, new_name = reaper.ImGui_InputText(ctx, "##newplaylistname", renamePlaylistName)
  if rv then renamePlaylistName = new_name end
  
  reaper.ImGui_Separator(ctx)
  
  if reaper.ImGui_Button(ctx, "Rename", 120, 0) then
    if renamePlaylistName ~= "" and renamePlaylistName ~= selectedPlaylistName then
      -- Only rename if new name doesn't exist
      if not playlists[renamePlaylistName] then
        playlists[renamePlaylistName] = playlists[selectedPlaylistName]
        playlists[selectedPlaylistName] = nil
        selectedPlaylistName = renamePlaylistName
        selectedPlaylist = playlists[renamePlaylistName]
        savePlaylists()
        isRenaming = false
        reaper.ImGui_CloseCurrentPopup(ctx)
      else
        reaper.ShowMessageBox("A playlist with this name already exists.", "ReconTracks Playlist", 0)
      end
    else
      isRenaming = false
      reaper.ImGui_CloseCurrentPopup(ctx)
    end
  end
  
  reaper.ImGui_SameLine(ctx)
  
  if reaper.ImGui_Button(ctx, "Cancel", 120, 0) then
    isRenaming = false
    reaper.ImGui_CloseCurrentPopup(ctx)
  end
  
  reaper.ImGui_EndPopup(ctx)
end
      
      -- Export playlists popup
      -- Replace this function in your code:

-- Export playlists popup
if showExportWindow then
  reaper.ImGui_OpenPopup(ctx, "Export Playlists")
  showExportWindow = false
end

if reaper.ImGui_BeginPopupModal(ctx, "Export Playlists", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
  reaper.ImGui_Text(ctx, "Export playlists to file:")
  reaper.ImGui_InputText(ctx, "##exportfilename", exportFilename)
  
  reaper.ImGui_Separator(ctx)
  
  if reaper.ImGui_Button(ctx, "Export", 120, 0) then
    -- Use a simple input dialog instead of file browser
    local filename = exportFilename
    if not filename:match("%.txt$") then
      filename = filename .. ".txt"
    end
    
    -- Create path in REAPER resource directory
    local resourcePath = reaper.GetResourcePath()
    local filePath = resourcePath .. "/Scripts/" .. filename
    
    -- Export playlists to file
    local success = exportPlaylistsToFile(filePath)
    if success then
      reaper.ShowMessageBox("Playlists exported successfully to:\n" .. filePath, "ReconTracks Playlist", 0)
    else
      reaper.ShowMessageBox("Failed to export playlists.", "ReconTracks Playlist", 0)
    end
    
    reaper.ImGui_CloseCurrentPopup(ctx)
  end
  
  reaper.ImGui_SameLine(ctx)
  
  if reaper.ImGui_Button(ctx, "Cancel", 120, 0) then
    reaper.ImGui_CloseCurrentPopup(ctx)
  end
  
  reaper.ImGui_EndPopup(ctx)
end

      
      -- Import playlists popup
      if showImportWindow then
  reaper.ImGui_OpenPopup(ctx, "Import Playlists")
  showImportWindow = false
end

if reaper.ImGui_BeginPopupModal(ctx, "Import Playlists", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
  reaper.ImGui_Text(ctx, "Enter the playlist filename to import:")
  reaper.ImGui_InputText(ctx, "##importfilename", importFilename)
  reaper.ImGui_Text(ctx, "(File should be in REAPER/Scripts folder)")
  
  reaper.ImGui_Separator(ctx)
  
  if reaper.ImGui_Button(ctx, "Import", 120, 0) then
    local filename = importFilename
    if not filename:match("%.txt$") then
      filename = filename .. ".txt"
    end
    
    -- Create path in REAPER resource directory
    local resourcePath = reaper.GetResourcePath()
    local filePath = resourcePath .. "/Scripts/" .. filename
    
    -- Import playlists from file
    local success, count = importPlaylistsFromFile(filePath)
    
    if success then
      reaper.ShowMessageBox("Imported " .. count .. " playlists successfully.", "ReconTracks Playlist", 0)
      -- Reload playlists
      loadPlaylists()
      selectedPlaylist = nil
      selectedPlaylistName = nil
      reaper.ImGui_CloseCurrentPopup(ctx)
    else
      reaper.ShowMessageBox("Failed to import playlists or file format is invalid.", "ReconTracks Playlist", 0)
    end
  end
  
  reaper.ImGui_SameLine(ctx)
  
  if reaper.ImGui_Button(ctx, "Cancel", 120, 0) then
    reaper.ImGui_CloseCurrentPopup(ctx)
  end
  
  reaper.ImGui_EndPopup(ctx)
end
      
      reaper.ImGui_End(ctx)
    end
    
    reaper.defer(loop)
  end
  
  reaper.defer(loop)
end

-- Export playlists to a file
function exportPlaylistsToFile(filePath)
  local file = io.open(filePath, "w")
  if not file then
    debug("Failed to open file for export: " .. filePath)
    return false
  end
  
  -- Write a header
  file:write("ReconTracks Playlist File v" .. scriptVersion .. "\n")
  file:write("Created: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
  
  -- Get playlist names sorted
  local playlistNames = {}
  for name, _ in pairs(playlists) do
    table.insert(playlistNames, name)
  end
  table.sort(playlistNames)
  
  -- Write each playlist
  for _, name in ipairs(playlistNames) do
    local songList = playlists[name]
    file:write("[PLAYLIST:" .. name .. "]\n")
    
    for _, song in ipairs(songList) do
      file:write(song.path .. "\n")
    end
    
    file:write("\n")
  end
  
  file:close()
  debug("Exported " .. #playlistNames .. " playlists to: " .. filePath)
  return true
end

-- Import playlists from a file
function importPlaylistsFromFile(filePath)
  local file = io.open(filePath, "r")
  if not file then
    debug("Failed to open import file: " .. filePath)
    return false, 0
  end
  
  local content = file:read("*all")
  file:close()
  
  -- Parse the file
  local currentPlaylist = nil
  local currentSongs = {}
  local importedCount = 0
  
  -- Make a copy of existing playlists to modify
  local newPlaylists = {}
  for name, songs in pairs(playlists) do
    newPlaylists[name] = songs
  end
  
  for line in content:gmatch("[^\r\n]+") do
    -- Check for playlist header
    local playlistName = line:match("%[PLAYLIST:(.-)%]")
    if playlistName then
      -- Save previous playlist if exists
      if currentPlaylist then
        newPlaylists[currentPlaylist] = currentSongs
        importedCount = importedCount + 1
      end
      
      -- Start new playlist
      currentPlaylist = playlistName
      currentSongs = {}
    elseif currentPlaylist and line:find("\\") then
      -- Assume it's a file path if it contains backslash
      local songPath = line:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
      if songPath ~= "" then
        -- Extract name from path
        local name = songPath:match("([^/\\]+)$")
        if name then
          local songInfo = { name = name, path = songPath }
          -- Try to get duration info (if file exists)
          local mediaSource = reaper.PCM_Source_CreateFromFile(songPath)
          if mediaSource then
            songInfo.duration = reaper.GetMediaSourceLength(mediaSource)
            reaper.PCM_Source_Destroy(mediaSource)
          end
          table.insert(currentSongs, songInfo)
        end
      end
    end
  end
  
  -- Add last playlist if exists
  if currentPlaylist and #currentSongs > 0 then
    newPlaylists[currentPlaylist] = currentSongs
    importedCount = importedCount + 1
  end
  
  -- Replace playlists with new set and save
  if importedCount > 0 then
    playlists = newPlaylists
    savePlaylists()
    debug("Imported " .. importedCount .. " playlists")
    return true, importedCount
  end
  
  debug("No valid playlists found in import file")
  return false, 0
end

-- Main function
function main()
  -- Initialize log buffer
  logBuffer = {}
  debug("--- ReconTracks Playlist v"..scriptVersion.." Starting ---")
  
  -- Check if ImGui is available
  if not reaper.ImGui_CreateContext then
    reaper.ShowMessageBox("This script requires ReaImGui extension.\n\nPlease install it via ReaPack:\n1. Extensions > ReaPack > Browse packages\n2. Search for 'ReaImGui'\n3. Install and restart REAPER", "Missing Dependency", 0)
    return
  end
  
  -- Load playlists and show manager UI
  loadPlaylists()
  showPlaylistManagerUI()
end

main()



