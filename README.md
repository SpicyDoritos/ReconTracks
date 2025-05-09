# 🎸 ReconTracks for REAPER

**ReconTracks** is a REAPER extension designed to streamline loading, organizing, and playing your backing tracks so you can control backtrack volume and guitar/vocal volume — perfect for live performance, practice, or studio sessions. Developed with musicians in mind, it features a sleek UI, persistent folder memory, and playlist management.

> Version: 2.0+  
> Author: Recontastic  
> Requires: REAPER 6.8+ and [ReaImGui](https://github.com/cfillion/reaimgui) extension installed (via [ReaPack](https://reapack.com/)). (for UI functionality)
---

## 🚀 Features

### 🔊 Main App – ReconTracks

- **Enhanced Backing Track Loader**: Quickly browse and load audio files into a dedicated "ReconTracks" REAPER track.
- **Persistent Folder Memory**: Remembers your preferred song folder.
- **Queue System**: Build and preview a queue of songs to load in order.
- **Flexible Insertion**: Append or replace current tracks with one click.
- **Track Management**: Automatically finds or creates a dedicated ReconTracks track.
- **Audio Format Support**: Compatible with `.wav`, `.mp3`, `.flac`, `.ogg`, `.m4a`, `.aiff`, `.wma`, and even video like `.mp4`!

### 🧠 Smart Behavior

- Remembers your last loaded track.
- Automatically sets playback position and track volume.
- Displays helpful debug logs (optional console mode).

---

## 🎤 Why ReconTracks Exists

As a live-streaming musician, my audio setup looks like this:

**Guitar → Interface → REAPER**  
**Mic → Interface → REAPER**

In REAPER, I run two channels — one for **guitar**, one for **mic** — and send that mix to **OBS via ReaStream**. Meanwhile, my backing tracks (from **Moises**, **Spotify**, etc.) play through **desktop audio**.

### 🎧 The Problem:
What I heard in my headphones **wasn’t** what my audience heard in OBS.

My guitar might sound great in my headphones, but on stream it would be buried — or the opposite: I couldn’t hear it at all while the audience heard it just fine. Sometimes the backing track would overpower everything in my ears, and other times it would seem nearly silent, even though OBS showed a perfectly balanced mix. I had no reliable way to monitor what the audience was actually hearing.

This turned every performance into a guessing game. I’d find myself constantly adjusting levels mid-song, trying to fix problems I couldn’t even verify in real time — hoping the mix wasn’t a total mess for the viewers.

### ✅ The Solution:
**ReconTracks** brings backing tracks **directly into REAPER**, so I can balance guitar, vocals, and backing audio all in one place — **before** the mix hits OBS.

This gives me consistent monitoring, better control, and way less guesswork and now with reapers video support you can use mp4 videos as well! I eventually want to add real-time normalization, but for now, this approach works beautifully — and I wanted to share it for others in the same boat.

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

![Main Recontrack UI](https://i.imgur.com/Nb4lNPy.jpeg)
- Tabbed interface: Song Browser / Queue View
- Search & filter functionality
- Double-click to add songs to queue
- Load queue directly to timeline
![playlist](https://i.imgur.com/9h8rUzC.jpeg)
---

## ⚙️ Installation

1. Make sure REAPER has the [ReaImGui](https://github.com/cfillion/reaimgui) extension installed (via [ReaPack](https://reapack.com/)).
2. Copy `ReconTracks.lua` and `Recontracks-Playlist.lua` into your REAPER Scripts folder.
3. In REAPER:
    - Open the Actions List (`?`)
    - Click “New Action” then ”Load ReaScript” to import `ReconTracks.lua`
    - Assign shortcuts or add it to a toolbar for quick access.
    - **Note:** You do not need to import or assign a hotkey for `Recontracks-Playlist.lua` — it can be accessed via the **Queue** tab inside ReconTracks so long as the file is in the reaper scripts folder.
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
