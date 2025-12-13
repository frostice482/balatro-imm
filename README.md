# imm

The ingame mod browser, manager, and modpack manager for Balatro.

## Installation

1.  Install [lovely](https://github.com/ethangreen-dev/lovely-injector?tab=readme-ov-file#manual-installation).

3.  Download [inmodman.zip](https://github.com/frostice482/balatro-imm/releases/latest/download/inmodman.zip)

4.  Extract the zip to `Mods/imm`.
    The `Mods/imm` folder should now contain `manifest.json`.

    If you cannot find the mods folder, see [this section](#finding-mods-folder).

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

## Features

- **Modpacks**
- Disabling, enabling, updating all mods
- Automatic problematic mod disabling on startup
- Automatic installation of missing dependencies
- Dependency / Conflict management
- Caching
- Manage multiple installation versions

## Config

See [config.md](doc/config.md).

## Socials

- [Balatro Discord thread](https://discord.com/channels/1116389027176787968/1413687995378176021)

## Credits

### Font: Quintessential

Copyright (c) 2012, Brian J. Bonislawsky DBA Astigmatic (AOETI) (astigma@astigmatic.com), with Reserved Font Names 'Quintessential'
This Font Software is licensed under the SIL Open Font License, Version 1.1. This license also available with a FAQ at: https://openfontlicense.org
