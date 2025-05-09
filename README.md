# 🎸 ReconTracks for REAPER

**ReconTracks** is a REAPER extension designed to streamline loading, organizing, and playing your backing tracks so you can control backtrack volume and guitar/vocal volume — perfect for live performance, practice, or studio sessions. Developed with musicians in mind, it features a sleek UI, persistent track memory, and playlist management.

> Version: 2.0+  
> Author: Recontastic  
> Requires: REAPER 6.8+ and ReaImGui (for UI functionality)

---

## 🚀 Features

### 🔊 Main App – ReconTracks

- **Enhanced Backing Track Loader**: Quickly browse and load audio files into a dedicated "ReconTracks" REAPER track.
- **Persistent Folder Memory**: Remembers your preferred song folder.
- **Queue System**: Build and preview a queue of songs to load in order.
- **Flexible Insertion**: Append or replace current tracks with one click.
- **Track Management**: Automatically finds or creates a dedicated ReconTracks track.
- **Audio Format Support**: Compatible with `.wav`, `.mp3`, `.flac`, `.ogg`, `.m4a`, `.aiff`, `.wma`, and even Video like .mp4!.

### 🧠 Smart Behavior

- Remembers your last loaded track.
- Automatically sets playback position and track volume.
- Displays helpful debug logs (optional console mode).

---

## 📂 Playlist Manager (Companion Script)

The **Playlist Manager** expands ReconTracks with playlist-saving functionality — perfect for setlists or recurring sessions.

### 📜 Actions:

- **Create Playlist**: Save your current queue as a named playlist.
- **Load to Queue**: Replace your current queue with a saved playlist.
- **Append to Queue**: Add a playlist's contents to your current queue.
- **Rename**: Rename existing playlists.
- **Delete**: Remove unwanted playlists.
- **Export/Import**: Backup and restore playlists via external files.

> Requires: ReconTracks v2.0+

---

## 🖥 UI Example (via ReaImGui)

- Tabbed interface: Song Browser / Queue View
- Search & filter functionality
- Double-click to add songs to queue
- Load queue directly to timeline

---

## ⚙️ Installation

1. Make sure REAPER has the [ReaImGui](https://github.com/cfillion/reaimgui) extension installed.
2. Copy `ReconTracks.lua` and `ReconTracks Playlist Manager.lua` into your REAPER Scripts folder.
3. In REAPER:
    - Open the Actions List (`?`)
    - Click “New Action” then ”Load ReaScript” to import `ReconTracks.lua` script 
    - Assign shortcuts or add them to a toolbar for quick access.
	- NOTE: you do not need to import(`ReconTracks Playlist Manager.lua`)and assign a hotkey it can be opened and access via the ReconTracks queue Tab
4. (Optional) Edit the default folder path in the script if needed.

---

## 🛠 Development Notes

- Written in Lua using REAPER's API and ReaImGui for UI.
- Stores state persistently via `SetExtState` / `GetExtState`.
- Designed for live and stream-ready performance workflows.

---

## 🤘 About

Created by **[Recontastic](https://twitch.tv/recontastic)** — guitarist and streamer passionate about integrating smooth workflows into musical creation and performance. Whether you're jamming on stream or prepping your next gig, ReconTracks keeps your setup tight and effortless.

---

## 📥 License

MIT License – free for personal and professional use. Attribution appreciated, but not required.

