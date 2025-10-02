--- @meta imm.config

--- @class imm.ParsedConfig: { [string]: string }
--- Determines what mod to load at the next loading.\
--- The entry is mod ID and version separated by `=` (includes surrounding whitespaces).\
--- The list is separated by `==` (includes surrounding whitespaces).\
--- e.g. `Steamodded=1.0.0~beta-0827c == Cryptid=0.5.12a`
---
--- Changes won't be applied with the next restart.
---
--- Useful for when Balatro crashes at loading and it disables all mods.
--- This config can be used to re-enable all disabled mods during loading crash.
--- @field nextEnable string
---
--- Allows users to specify the GitHub API token
--- @field githubToken string

--- @class imm.Config

--- @class imm.Resbundle
--- @field assets table
--- @field https_thread string

--- @class imm.Base
--- Where the IMM is located at
--- @field path string
--- Lovely version
--- @field lovelyver? string
--- Where the mods directory is located at.
--- Similar to lovely's mod_dir
--- @field modsDir string
--- Where the config file should be saved / read at.
--- @field configFile string
--- Parsed configs.
--- Config should be in `key=value` pair. Leading `#` will ignore the line.
--- @field config imm.ParsedConfig
--- Bundles resources.
--- Only available when run bundled
--- @field resbundle? imm.Resbundle
local c = {}

--- @type imm.Base
return c
