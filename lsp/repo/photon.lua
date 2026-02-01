--- @class photon.PackageBase
--- @field id string
--- @field name string
--- @field description string
--- @field tags? string[]
--- @field favourites number
--- @field published_at string
--- @field analytics? photon.Analytics

--- @class photon.Analytics
--- @field views number
--- @field lastViewed string

--- @class photon.Package: photon.PackageBase
--- @field type 'Mod'
--- @field author string[]
--- @field dependencies string[]
--- @field conflicts string[]
--- @field readme string
--- @field badge_colour string
---
--- @field git_owner? string
--- @field git_repo? string
--- @field mod_path? string
--- @field subpath? string
--- @field download_suffix? string
--- @field update_mandatory? boolean
--- @field target_version? boolean

--- @class photon.Modpack: photon.PackageBase
--- @field type 'Modpack'
--- @field author string
--- @field updated_at string
--- @field modCount number
--- @field mods photon.Modpack.Mod

--- @class photon.Modpack.Mod
--- @field key string
--- @field version string