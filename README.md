The ingame mod browser for Balatro.

## Installation

### Normal Installation

1.  Install [lovely](https://github.com/ethangreen-dev/lovely-injector?tab=readme-ov-file#manual-installation).

3.  Download [inmodman.zip](https://github.com/frostice482/balatro-imm/releases/latest/download/inmodman.zip)

4.  Extract the zip to `Mods/imm`.
    The `Mods/imm` folder should now contain `manifest.json`.

    If you cannot find the mods folder, see [this section](#finding-mods-folder).

### Bundled Installation

This is meant as a quick way to install imm, and does not require lovely installation.
Be noted that this method will cause issues with some mods, and will just not work in all platform.

Windows:
```sh
curl -SL "https://github.com/frostice482/balatro-imm/releases/latest/download/bundle.lua" -o "%appdata%\Balatro\main.lua" && start "" "steam://launch/2379780"
```

### Finding Mods Folder

Windows: `%appdata%\Balatro\Mods`

Mac: `~/Library/Application Support/Balatro/Mods`

Linux with Steam Proton:

-   Find your Steam installation path

    - `~/.local/share/Steam`
    - Snap installation: `~/snap/steam/common/.local/share/Steam`
    - Flatpak installation: `~/.var/app/com.valvesoftware.Steam/.local/share/Steam`
    - Other installation: `~/.steam/steam`

    Then, from the Steam folder, navigate to `steamapps/compatdata/2379780/pfx/drive_c/users/steamuser/AppData/Roaming/Balatro/Mods`

## Sources

- [balatro-mod-index](https://github.com/skyline69/balatro-mod-index), [modified](https://github.com/frostice482/balatro-mod-index-tiny)
- [Thunderstore](https://thunderstore.io/c/balatro/)
- [Photon](https://photonmodmanager.onrender.com)

## Features

- Disabling, enabling, updating all mods
- Automatic problematic mod disabling on startup
- Automatic installation of missing dependencies
- Dependency / Conflict management
- Caching
- Manage multiple installation versions

## Config

Make a configuration file in `<Balatro>/config/imm.txt`.
Config is formatted in a `key=value` pair.

### `enforceCurl`

If present, forces imm to use curl bindings to do HTTPS request.

### `handleEarlyError`

Disables imm's early crash handing.
- `ignore`: Disables imm's early error handling
- `nodisable`: Only list detected mods

### `disableFlavor`

Disables flavor text.

### `disableSafetyWarning`

Disables safety warning.

### `noUpdateUnreleasedMods`

If a mod does not have any release, don't update it from latest commit.

### `noAutoDownloadUnreleasedMods`

If a mod does not have any release, don't automatically download it as a dependency from latest commit.

### `httpsThreads`

Specifies maximum number of HTTPS thread to create. Defaults to 6

### `concurrentTasks`

Specifies maximum number of running tasks at once. Defaults to 4.

Tasks are:
- Downloading a mod release

### `githubToken`

Allows player to specify the GitHub API token.
This is used to increase the 60/hour ratelimit, when getting mod releases in Balatro Mod Index.

### `nextEnable`

Internally used when Balatro crashes at loading and it disables all mods.

Determines what mod to enable at the next loading.
The entry is mod ID and version separated by `=` (includes surrounding whitespaces).
The list is separated by `==` (includes surrounding whitespaces).
e.g. `Steamodded=1.0.0~beta-0827c == Cryptid=0.5.12a`

### `init`

Internally used to mark for non-first game launch.

## Developers

If your mod is not included, make sure your mod exists in `balatro-mod-index` and that your repo contains a valid metadata file.
See [here](https://github.com/frostice482/balatro-mod-index-tiny?tab=readme-ov-file#why-is-my-mod-not-included) for details.

For mod releases, please make sure to use the Github Releases.
I recommend that you name your tags based on your mod version, with some conversion:
- Mod version `~` is converted to `-` (e.g. `1.0.0~alpha-1` -> `1.0.0-alpha-5`)
- Tag version with leading `v` is ignored (e.g. `v1.0.0` -> `1.0.0`)

## Socials

- [The official Balatro Discord server modding thread](https://discord.com/channels/1116389027176787968/1413687995378176021)

## Credits

### Logo

- Font: Amaranth (Gesine Todt), SIL Open Font License
- Icons: [gear](https://www.svgrepo.com/svg/509956/gear) (zest), MIT License
