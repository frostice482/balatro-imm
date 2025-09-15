local constructor = require('imm.lib.constructor')
local UIVersion = require('imm.ui.version')
local ui = require('imm.lib.ui')

--- @class imm.UI.VerDel
local IUIVerDel = {}

--- @param ses imm.UI.Browser
--- @param mod string
--- @param ver string
function IUIVerDel:init(ses, mod, ver)
    self.ses = ses
    self.mod = mod
    self.ver = ver
end

function IUIVerDel:uiDeleteVersionMessage()
    local mod = self.ses.ctrl:getMod(self.mod, self.ver)
    local stat = mod and NFS.getInfo(mod.path)

    local cols = {}

    local main = ui.simpleTextRow(string.format('Really delete %s %s?', mod.name, self.ver), self.ses.fontscale)
    main.config = {align = 'cm'}
    table.insert(cols, main)

    if stat and stat.type == 'symlink' then
        local sub = ui.simpleTextRow('This mod is symlinked', self.ses.fontscale, G.C.ORANGE)
        sub.config = {align = 'cm'}
        table.insert(cols, sub)
    end

    --- @type balatro.UIElement.Definition
    return {
        n = G.UIT.R,
        config = {align = 'cm'},
        nodes = {{
            n = G.UIT.C,
            config = {align = 'cm'},
            nodes = cols
        }}
    }
end

function IUIVerDel:render()
    return ui.confirm(
        self:uiDeleteVersionMessage(),
        UIVersion.funcs.deleteConfirm,
        { ses = self }
    )
end


--- @class imm.UI.VerDel.Static

--- @alias imm.UI.VerDel.C imm.UI.VerDel.Static | p.Constructor<imm.UI.VerDel, nil> | fun(ses: imm.UI.Browser, mod: string, ver: string): imm.UI.VerDel
--- @type imm.UI.VerDel.C
local UIModSes = constructor(IUIVerDel)
return UIModSes

