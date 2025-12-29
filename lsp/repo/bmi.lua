--- @alias bmi.Meta.Category 'Content' | 'Joker' | 'Quality of Life' | 'Technical' | 'Miscellaneous' | 'Resource Packs' | 'API'
--- @alias bmi.Meta.Format 'smods' | 'smods-header' | 'thunderstore'

--- @class bmi.MetaInject
--- @field pathname? string May be undefined in case of locally installed mods
--- @field id string
--- @field provides? string[]
--- @field description? string
--- @field badge_colour? string
--- @field badge_text_colour? string
-- @field metafmt bmi.Meta.Format

--- @class bmi.Meta: bmi.MetaInject
--- @field name string
--- @field categories bmi.Meta.Category[]
--- @field owner string
--- @field version? string
--- @field download_url? string May be undefined in case of locally installed mods
--- @field repo? string May be undefined in case of locally installed mods