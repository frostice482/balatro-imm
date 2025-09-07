--- @alias bmi.Meta.Category 'Content' | 'Joker' | 'Quality of Life' | 'Technical' | 'Miscellaneous' | 'Resource Packs' | 'API'
--- @alias bmi.Meta.Format 'smods' | 'smods-header' | 'thunderstore'

--- @class bmi.MetaInject
--- @field pathname? string May be undefined in case of locally installed mods
--- @field id string
--- @field metafmt bmi.Meta.Format
--- @field provides? string[]

--- @class bmi.Meta: bmi.MetaInject
--- @field title string
--- @field categories bmi.Meta.Category[]
--- @field author string
--- @field version string
--- @field repo? string May be undefined in case of locally installed mods
--- @field downloadURL? string May be undefined in case of locally installed mods