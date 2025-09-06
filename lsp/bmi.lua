--- @alias bmi.Meta.Category 'Content' | 'Joker' | 'Quality of Life' | 'Technical' | 'Miscellaneous' | 'Resource Packs' | 'API'
--- @alias bmi.Meta.Format 'smods' | 'smods-header' | 'thunderstore'

--- @class bmi.MetaInject
--- @field pathname string
--- @field id string
--- @field version string
--- @field metafmt bmi.Meta.Format
--- @field deps? string[]
--- @field conflicts? string[]

--- @class bmi.Meta: bmi.MetaInject
--- @field title string
--- @field categories bmi.Meta.Category[]
--- @field author string
--- @field repo string
--- @field downloadURL string