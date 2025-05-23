# 🎸 ReconTracks for REAPER

**ReconTracks**  is a REAPER Lua script designed to streamline loading, organizing, and playing backing tracks for practice or live streaming—all within one app for simplified monitoring and playback. Once installed Just point it to your backing track folder and away you go!

> Current Version: 2.4 
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
- **Caching System**:  Speeds up future loads by saving a JSON cache of songs in /Scripts/ReconTracks/song_cache.json
- **Persistent Folder Memory**: Remembers your preferred song folder
- **Queue System**: Build and preview a queue of songs to load in order
- **Flexible Insertion**: Append or replace current tracks with one click
- **Track Management**: Automatically finds or creates a dedicated ReconTracks track
- **Audio Format Support**: Compatible with `.wav`, `.mp3`, `.flac`, `.ogg`, `.m4a`, `.aiff`, `.wma`, and even video like `.mp4`
- **UI Integration**: Tabbed interface with Song Browser and Queue View
- **Search & Filter**: Quickly find tracks in your library
- **Smart Behavior**: Remembers last loaded track and settings
- **Lyric/Chord/Note System**: Each song has its own text area that can be opened with the `L` button
- **Playcount**: Keep track with how many times you have loaded a song with the Counter that automatically updates
- **Video Quick Search**: One-click button to search for the current loaded song's official video on YouTube

### 🎚️ Volume Memory System
- **Per-Song Volume Settings**: Automatically remembers and restores volume levels for each song
- **Seamless Transitions**: Helps to Maintain consistent db across different backing tracks
- **Persistent Storage**: Saves volume data to `volume_memory.json` for retrieval across sessions
- **Intelligent Retry Logic**: Ensures volume settings are properly applied even during complex operations

### 🏷️ Genre Tagging System
- Uses naming format `Artist Name – Song Title` for consistent tagging with this system
- Tag each track with a **Genre**
- Automatically saves metadata to `song_genres.json`
- The meta will include **song directory**, **Artist Name**, **Song Title**, and **Genre**
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

## 📁 Additional Tools

### ReconTracks JSON Converter
Convert your `song_genres.json` into a CSV for use with services like StreamerSongList:

1. Load ReconTracks Json Convertor with your favorite browser
2. Upload your `song_genres.json` file from `C:\Users\<YourName>\AppData\Roaming\REAPER\Scripts\ReconTracks`
3. The converter extracts Artist, Song Name, and Genre from each entry
4. Review the parsed data in a table
5. Download the CSV and import it into your song request service

---

## 🖥️ UI Examples

![Main Recontrack UI](https://i.imgur.com/b6C7joc.jpeg)

*ReconTracks main interface*

![Playlist Manager](https://i.imgur.com/fnzXogR.jpeg)

*Playlist management interface*

![Playlist Manager](https://i.imgur.com/tBPjkIt.png)

*Random Player interface*

---

## ⚙️ Installation

1. Make sure REAPER has the [ReaImGui](https://github.com/cfillion/reaimgui) extension installed (via [ReaPack](https://reapack.com/))
2. Copy `ReconTracks.lua`, `Recontracks-Playlist.lua`, `ReconTracks-RandomLoader.lua`, and `ReconTracks-VolumeMemory.lua` into your REAPER Scripts folder
3. In REAPER:
   - Open the Actions List (`?`)
   - Click "New Action" then "Load ReaScript" to import `ReconTracks.lua`
   - Assign shortcuts or add it to a toolbar for quick access
   - **Note:** You don't need to import the companion scripts separately—they are automatically loaded by the main ReconTracks script
4. (Optional) Edit the default folder path in the script if needed

---

## 🧠 Technical Notes

- Written in Lua using REAPER's API and ReaImGui for UI
- Stores state persistently via `SetExtState` / `GetExtState`
- Genre data saved to: `C:\Users\<YourName>\AppData\Roaming\REAPER\Scripts\ReconTracks\song_genres.json`
- Volume memory data saved to: `C:\Users\<YourName>\AppData\Roaming\REAPER\Scripts\ReconTracks\volume_memory.json`
- Uses naming format `Artist Name – Song Title` for consistent tagging
- Volume memory system includes intelligent retry logic to ensure proper application of volume settings
- Debug mode available in volume memory module for troubleshooting

---

## 🤘 About

Created by **[Recontastic](https://twitch.tv/recontastic)** — guitarist and streamer passionate about integrating smooth workflows into musical creation and performance. Whether you're jamming on stream or prepping your next gig, ReconTracks keeps your setup tight and effortless.

## 📥 License

MIT License – free for personal and professional use. Attribution appreciated, but not required.