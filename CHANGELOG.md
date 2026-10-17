# UHF Server - Changelog

## 2.2.1

### Fixes

- More recovery improvements when the server unexpectedly finishes a stream.
- Deleting a recording while its commercial detection was still running left an orphan folder behind (the server logged "Directory not empty") and, a little later, a notification about a recording that no longer existed. The analysis is now stopped before the files are removed, and the folder is deleted completely.

## 2.2.0

### New: recordings that survive bad streams

- Recordings no longer fail when the stream drops. If the source stops sending data, closes the connection or returns an error, the server restarts ffmpeg and continues into the same recording, up to ten times per programme, with a growing pause between attempts. A short gap is marked where this happened, and the apps are notified the first time a recording recovers.
- Late starts and resumes. A recording whose start time passed while the server was down (or that was in progress when the server stopped) now records what is left of the programme instead of being marked as missed. The part captured before a restart is kept.
- Gentler stops. ffmpeg is now asked to finish cleanly, so the last seconds of a recording are kept and the playlist is always complete.
- Every recording folder now contains an ffmpeg.log with the exact command line and output of each attempt (capped at 5 MB). Attach it to bug reports.

### New: save each recording as a single file

- A new option, --single-file-recordings (SINGLE_FILE_RECORDINGS=true for Docker, or "Save each recording as a single file" in the desktop app settings), merges the segments of a finished recording into one index.ts file. The playlist is kept and points at that file, so playback in the apps, in the browser, casting and downloads work exactly as before. The merge briefly needs twice the recording's space on disk, which is why it is optional. Existing recordings are left as they are.

### Fixes

- Recordings in progress could not be watched with ffmpeg 7.1 or newer: segments without a file extension were rejected. They play again, from the start, while still recording.
- Playlist connection limits are now reported as such. When a recording fails because the account's simultaneous connections are all in use (typically a device still playing a channel from that playlist), the recording says so, in the apps, in the web app and in the push notification, instead of a bare "ffmpeg exited with code 8".
- Streams that resume with a different timestamp base after a drop (the playlist restarted its stream) produced a playlist that players refused, with a target duration of several hours and a 26-hour timeline. The offending segment is now detected and dropped when the recording is finalised, the dates are corrected, and such a recording can no longer be mistaken for complete before the programme ends.
- Recurring series: when the first occurrence of a series was created while its programme was already on air, the shortened duration was repeated for every following occurrence. The series now repeats the slot that was asked for.

## 2.1.0

### New: web app for managing the server

- The server now hosts a web page at http://server-address:port/. In the desktop app, open it from Manage Library... in the menu bar. Other devices on your network can use the address shown in that menu.
- Sign in with the server password, or open straight in if no password is set. No UHF account is needed. Sessions last 30 days and end when the password changes. After five wrong passwords in a minute, that address is paused for a minute.
- Scheduled: see recordings in progress (with how much has been captured so far) and upcoming ones. Edit name, start time, duration and weekdays, cancel recordings or whole series, and stop recordings in progress.
- Library: browse finished, stopped and failed recordings with their details, download them as a single file (resumable), or delete them.
- Watch: play recordings in the browser, including recordings still in progress with a seekable timeline that keeps growing. Commercial breaks found by Comskip show as markers on the timeline and get a Skip button, like in the apps. Safari plays everything natively. Other browsers play H.264/AAC only and show a notice for other formats.
- Logs: follow the server log live, with level and text filters. Session tokens are hidden from logged URLs.

### Fixes

- Recurring recordings on the wrong day. Weekdays were matched in UTC, so in the evening in the Americas, or the morning in Asia and Oceania, a series could record a day early or late. The server now uses the time zone of the device that scheduled the recording, and series keep their local time across daylight-saving changes. Recordings scheduled from older app versions still use UTC.
- Cancelling recurring recordings. Stopping a series now also removes the recording itself if it hasn't started yet. It's safe to do mid-recording: the current recording finishes and no new one is scheduled.
- HLS recordings that never started. For HLS/DASH streams the server kept reconnecting at the end of each file instead of moving on. Some playlists then started returning error 509. Streams where the URL doesn't match the actuau8 links that redirect to a plain MPEG-TS stream) are now detectedcorrectly too.
- Seeking in recordings still in progress. The server now reports hoo far, so the apps can show a growing, seekable timeline.
- Leftover processes after quitting (desktop app). Quitting now stops the server and everything it started (ffmpeg, Comskip, sleep prevention) instead of leaving
  them running.

## 2.0.0

- The macOS and Windows apps have been rebuilt on top of Tauri, replacing the previous
Electron shell. The apps are now dramatically smaller and lighter.
- Recordings are now served as HLS streams.
- The recording engine has been overhauled for reliability, and commercial detection now
reads the recording playlist directly, making the analysis faster and more robust.
- The server now notifies UHF with a push notification when the commercial detection of a
recording completes.
- Recurring recordings now share a group identifier, so a whole series can be managed and
cancelled together.
- Fixed a bug that shut the server down after roughly 10,000 requests had been served,
interrupting in-progress recordings.

## 1.6.0

- Added support for recurring recordings (requires UHF 1.87.0).
- Improved retry mechanism and added support for more video formats.
- Server no longer preventing a server screen from going off.

## 1.5.1

- More HLS compatibility fixes.

## 1.5.0

- Fixed the recording of HLS and DASH streams.
- Improved the logging of ffmpeg errors.
- Made a Docker image available in Docker Hub (`swapplications/uhf-server`) and improved the Dockerfile.
- The GUI now offers a quick access to the logs file from the contextual menu of the status bar app.

## 1.4.0

- UHF Server can now detect commercials. Set the `--enable-commercial-detection` argument when invoking the
command line tool or enable the commercial detection checkbox in the macOS or Windows GUI. This commercial 
detection takes place when a scheduled recording finishes and it can take several minutes to complete. This
functionality is compatible with UHF 1.67.0 (iOS) and 1.55.0 (tvOS).

## 1.3.0

- The GUI for Windows and macOS now includes an option to automatically launch the server at system startup.
- Improved error reporting when starting the server in the Windows and macOS apps.
- The server now starts automatically when launching the Windows and macOS apps.
- Recordings now use the program name and date as the file name.
- Fixed a performance issue in the server that caused degraded performance when multiple recordings finished.

## 1.2.0

- The GUI for Windows and macOS now display the IP address the server is running on.
- The GUI now informs about new updates available.
- Prevented FFmpeg from opening a blank window in Windows while recording.
- Prevented machine from going idle while the server is running.
- Fixed detection of FFmpeg errors.
- Fixed error notifications.
- Improved ffmpeg retry logic.

## 1.1.0

- Fixed macOS permissions issue.
- Improved performance while recording a stream.

## 1.0.0

- Initial release.
- Configurable recordings directory, port and server password.
- GUI compatibility: macOS arm64, Windows x64.
- CLI compatibility: Linux x64, Linux arm64.
