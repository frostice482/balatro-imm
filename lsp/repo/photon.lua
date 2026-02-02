--- @class photon.PackageBase
--- @field key string
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
--- @field readme string
--- @field badge_colour? string
--- @field dependencies? string[]
--- @field conflicts? string[]
--- @field provides? string[]
---
--- @field git_owner? string
--- @field git_repo? string
--- @field mod_path? string
--- @field subpath? string
--- @field download_suffix? string
--- @field update_mandatory? boolean
--- @field target_version? boolean
---
--- @field versionHistory? photon.Version[]
--- @field versionHistoryLastCheck? string?

--- @class photon.Modpack: photon.PackageBase
--- @field type 'Modpack'
--- @field author string
--- @field updated_at string
--- @field modCount number
--- @field mods photon.Modpack.Mod[]

--- @class photon.Modpack.Mod
--- @field key string
--- @field version string

--- @class photon.Version.Success
--- @field success boolean
--- @field versionHistory photon.Version[]

--- @class photon.Version
--- @field tag string
--- @field name string
--- @field body? string
--- @field publishedAt string
--- @field htmlUrl string
--- @field prerelease boolean
--- @field draft boolean
--- @field assets photon.Version.Assets

--- @class photon.Version.Assets
--- @field name string
--- @field size number
--- @field downloadUrl string

