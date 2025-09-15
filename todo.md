- Add mod profiles

    - Ability to store what mods is loaded to a mod profile (maybe together with a save)
    - Ability to load a mod profile

- Add config files

    - `nextEnable`

        Determines what mod to load at the next loading, though the changes won't be applied with the next restart.
        Useful for when Balatro crashes at loading and it disables all mods.
        This config can be used to re-enable all disabled mods during loading crash.

    - `githubToken`

        Allows users to dpecify the GitHub API token, to bypass the 60/hour ratelimit.

- Auto-update detection (Thunderstore)

- Auto-update detection (BMI)

    - Method 1: check for version / download URL change
    - Method 2: check for releases change