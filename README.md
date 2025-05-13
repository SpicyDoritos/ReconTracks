# 🎸 ReconTracks for REAPER

**ReconTracks** is a REAPER extension designed to streamline loading, organizing, and playing backing tracks for live performance, practice, or studio sessions. Developed with musicians in mind, it features a sleek UI, persistent folder memory, and playlist management.

> Current Version: 2.1  
> Author: Recontastic  
> Requires: REAPER 6.8+ and [ReaImGui](https://github.com/cfillion/reaimgui) extension installed (via [ReaPack](https://reapack.com/))

---

## 🎤 Why ReconTracks Exists

As a live-streaming musician, I created ReconTracks to solve a common problem: what I heard in my headphones wasn't what my audience heard in OBS.

**The Problem:**  
With a setup of Guitar/Mic → Interface → REAPER → OBS (via ReaStream) and backing tracks playing through desktop audio, there was a disconnect between my monitoring mix and the audience mix. This made it impossible to reliably balance guitar, vocals, and backing tracks.

**The Solution:**  
ReconTracks brings backing tracks directly into REAPER, so you can balance guitar, vocals, and backing audio all in one place before the mix hits OBS. This gives you consistent monitoring, better control, and eliminates guesswork.

---

## 🚀 Features

### 🔊 Main App – ReconTracks
- **Enhanced Track Loader**: Quickly browse and load audio files into a dedicated "ReconTracks" track
- **Persistent Folder Memory**: Remembers your preferred song folder
- **Queue System**: Build and preview a queue of songs to load in order
- **Flexible Insertion**: Append or replace current tracks with one click
- **Track Management**: Automatically finds or creates a dedicated ReconTracks track
- **Audio Format Support**: Compatible with `.wav`, `.mp3`, `.flac`, `.ogg`, `.m4a`, `.aiff`, `.wma`, and even video like `.mp4`
- **UI Integration**: Tabbed interface with Song Browser and Queue View
- **Search & Filter**: Quickly find tracks in your library
- **Smart Behavior**: Remembers last loaded track and settings

### 🏷️ Genre Tagging System
- Tag each track with **Artist Name**, **Song Title**, and **Genre**
- Automatically saves metadata to `song_genres.json`
- Filter tracks by genre for random selection or setlists
- Export metadata to CSV for other platforms

### 📜 Playlist Manager
- Create named playlists for setlists or recurring sessions
- Load or append playlists to your current queue
- Rename and delete existing playlists
- Export/import playlists via external files

### 🔀 Random Song Loader Utility
- Randomly load tracks by genre
- Choose to load by number of tracks or total duration
- Perfect for spontaneous jam sessions or setlist variety

---

## 🖥️ UI Examples

![Main Recontrack UI](https://i.imgur.com/Nb4lNPy.jpeg)
*ReconTracks main interface with tabbed browser/queue view*

![Playlist Manager](https://i.imgur.com/9h8rUzC.jpeg)
*Playlist management interface*

---

## ⚙️ Installation

1. Make sure REAPER has the [ReaImGui](https://github.com/cfillion/reaimgui) extension installed (via [ReaPack](https://reapack.com/))
2. Copy `ReconTracks.lua`, `Recontracks-Playlist.lua` and `ReconTracks-RandomLoader.lua` into your REAPER Scripts folder
3. In REAPER:
   - Open the Actions List (`?`)
   - Click "New Action" then "Load ReaScript" to import `ReconTracks.lua`
   - Assign shortcuts or add it to a toolbar for quick access
   - **Note:** You don't need to import `Recontracks-Playlist.lua` separately—it can be accessed via the **Queue** tab inside ReconTracks
4. (Optional) Edit the default folder path in the script if needed

---

## 📁 Additional Tools

### ReconTracks JSON Converter
Convert your `song_genres.json` into a CSV for use with services like StreamerSongList:

1. Upload your `song_genres.json` file from `C:\Users\<YourName>\AppData\Roaming\REAPER\Scripts\ReconTracks`
2. The converter extracts Artist, Song Name, and Genre from each entry
3. Review the parsed data in a table
4. Download the CSV and import it into your song request service

---

## 🧠 Technical Notes

- Written in Lua using REAPER's API and ReaImGui for UI
- Stores state persistently via `SetExtState` / `GetExtState`
- Genre data saved to: `C:\Users\<YourName>\AppData\Roaming\REAPER\Scripts\ReconTracks\song_genres.json`
- Uses naming format `Artist Name – Song Title` for consistent tagging

---

## 🤘 About

Created by **[Recontastic](https://twitch.tv/recontastic)** — guitarist and streamer passionate about integrating smooth workflows into musical creation and performance. Whether you're jamming on stream or prepping your next gig, ReconTracks keeps your setup tight and effortless.

## 📥 License

MIT License – free for personal and professional use. Attribution appreciated, but not required.