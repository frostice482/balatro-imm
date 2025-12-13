# Config

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
