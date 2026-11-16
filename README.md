# FGO save file puller

Pulls a handful of small Fate/Grand Order save files off an Android phone via `adb`. Based on [this](https://www.reddit.com/r/grandorder/comments/hfbz0h/fgo_save_files_for_na_and_jp_play_on_multiple/) guide

| File | Size |
|---|---|
| `54cc*` | 250 B |
| `969b4` | 250 B |
| `644b*` | 22 B |
| `e1a9*` | 10 B |

They are content-hashed by the game, so **keep the filenames exactly as they are** when copying or
restoring them.

---

## Requirements

1. **A phone with USB debugging enabled** (see below).
2. **adb (Android Platform-Tools) installed.** If the scripts can't find `adb`, they print the
   official download link and offer to open it:

   ```
   https://developer.android.com/tools/releases/platform-tools
   ```

   Download *SDK Platform-Tools for Windows*, unzip it, then either:
   - add that folder to your `PATH`, or
   - drop `adb.exe` next to these scripts.

3. **USB cable** and the phone unlocked.

### Enabling USB debugging

1. Settings → About phone → tap **Build number** 7 times.
2. Settings → System → Developer options → turn on **USB debugging**.
3. Plug the phone in. Accept the **"Allow USB debugging?"** RSA prompt on the phone screen

Verify it worked:

```bash
adb devices
```

You should see a device listed as `device`. If it says `unauthorized`, look at your phone and accept
the prompt.

---

## Usage

### Windows

Double-click **`pull_fgo.bat`**, or run it from a terminal:

```bat
pull_fgo.bat                    :: -> .\fgo_android_data\
pull_fgo.bat mybackup           :: -> .\mybackup\
pull_fgo.bat mybackup aaa bbb   :: -> specific files only
```

### macOS / Linux / Git Bash

```bash
./pull_fgo.sh                   # -> ./fgo_android_data/
./pull_fgo.sh mybackup          # -> ./mybackup/
./pull_fgo.sh mybackup aaa bbb  # specific files only
```

Both scripts accept the same arguments. With no arguments they pull the four default files into
`fgo_android_data/files/data/`.

### What you'll see

```
List of devices attached
976de6                 device product:CPH2773 model:CPH2773 device:OP5B16L1

  ok: 54cc*
  ok: 969b*
  ok: 644b*
  ok: e1a9*

pulled 4 file(s), 0 missing -> fgo_android_data/files/data/
```

Missing files are reported as `missing: <name>` and skipped rather than aborting the run. Both
scripts exit with code `1` if any file was missing, `0` otherwise, so they behave sensibly in a
scheduled task or a bigger script.

---

## Notes and troubleshooting

**`MSYS_NO_PATHCONV=1` in the shell script.** On Git Bash, a path like `/sdcard/...` gets rewritten
into `C:/Program Files/Git/sdcard/...` before `adb` sees it. The script sets this itself — don't
remove it.

**`no authorized device (state: unauthorized)`.** The scripts wait up to 60 seconds for you to tap
*Allow* on the phone. If they give up, unlock the phone, accept the prompt, and re-run.

**Output lands relative to your current directory.** Both scripts write to the folder you name. Pass
an absolute path if you're running them from somewhere unexpected.

**Android 11+ and `/Android/data`.** Some phones restrict access to this folder even with USB
debugging. If pulls return permission errors, try `adb shell` and check whether you can `ls` the
folder at all; a few OEM ROMs need the restriction lifted in Developer options.