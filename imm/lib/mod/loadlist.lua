local constructor = require('imm.lib.constructor')
local ProvidedList = require('imm.lib.mod.providedlist')
local logger = require('imm.logger')

--- @alias imm.LoadList.ModList table<string, table<imm.Mod, imm.Dependency.Rule[]>>

--- @class imm.LoadList.ModAction
--- @field action 'enable' | 'disable' | 'switch'
--- @field enableRules imm.Dependency.Rule[] AND
--- @field disableRules imm.Dependency.Rule[][] OR
--- @field impossible? boolean
--- @field mod imm.Mod
--- @field cause? imm.Mod
--- @field update? boolean
--- @field update2? boolean

--- @class imm.LoadList
--- @field loadedMods table<string, imm.Mod>
--- @field loadedModDeps table<string,  string[]>
--- @field dependents imm.LoadList.ModList
--- @field conflicts imm.LoadList.ModList
--- @field provideds imm.ProvidedList
--- @field ctrl imm.ModController
--- @field actions table<string, imm.LoadList.ModAction>
--- @field missingDeps imm.LoadList.ModList
local ILoadList = {
    hasActionUpdate = false
}

--- @protected
--- @param ctrl imm.ModController
function ILoadList:init(ctrl)
    self.loadedMods = {}
    self.loadedModDeps = {}
    self.dependents = {}
    self.conflicts = {}
    self.actions = {}
    self.missingDeps = {}
    self.provideds = ProvidedList()
    self.ctrl = ctrl
end

--- @param other imm.LoadList
function ILoadList:simpleCopyFrom(other)
    for id, mod in pairs(other.loadedMods) do self:enable(mod) end

    for k,v in pairs(other.dependents) do
        self.dependents[k] = {}
        for l, w in pairs(v) do
            self.dependents[k][l] = w
        end
    end

    for k,v in pairs(other.loadedModDeps) do
        self.loadedModDeps[k] = {}
        for l, w in pairs(v) do
            self.loadedModDeps[k][l] = w
        end
    end
end

--- @param mod imm.Mod
--- @param autoAddDeps? boolean
--- @return boolean ok, string? err
function ILoadList:enable(mod, autoAddDeps)
    local id = mod.mod
    local loaded = self.loadedMods[id]
    if loaded then return false, string.format('Mod %s is already loaded (loaded %s, loading %s)', id, loaded.version, mod.version) end

    for i, conflict in ipairs(mod.conflicts) do
        if not self.conflicts[conflict.mod] then self.conflicts[conflict.mod] = {} end
        self.conflicts[conflict.mod][mod] = conflict.rules
    end

    self.loadedMods[id] = mod
    self.provideds:add(mod)

    if autoAddDeps then
        self:addModDeps(mod)
    end

    return true
end

--- @param mod imm.Mod
--- @return boolean ok, string? err
function ILoadList:disable(mod)
    local id = mod.mod
    local loaded = self.loadedMods[id]
    if not loaded then return false, string.format('Mod %s is not loaded', id) end
    if loaded ~= mod then return false, string.format('Mod %s to unload is not equal (loaded %s, unloading %s)', id, loaded.version, mod.version) end

    for i, id in ipairs(self.loadedModDeps or {}) do
        if self.dependents[id] then self.dependents[id][mod] = nil end
    end

    for i, conflict in ipairs(mod.conflicts) do
        local conflictList = self.conflicts[conflict.mod]
        if conflictList then
            conflictList[mod] = nil
            if not next(conflictList) then
                self.conflicts[conflict.mod] = nil
            end
        end
    end

    self.loadedMods[id] = nil
    self.loadedModDeps[id] = nil
    self.provideds:remove(mod)

    return true
end

--- @param mod string
--- @param rules imm.Dependency.Rule[]
--- @param excludesOr? imm.Dependency.Mod[][]
--- @return imm.Mod?
function ILoadList:getModVersionSatisfies(mod, rules, excludesOr)
    local alreadyLoaded = self.loadedMods[mod]
    if alreadyLoaded
        and alreadyLoaded.versionParsed:satisfiesAll(rules)
        and not (excludesOr and alreadyLoaded.versionParsed:satisfiesAllAny(excludesOr))
    then
        return alreadyLoaded
    end

    local other = self.ctrl:findModSatisfies(mod, rules, excludesOr)
    if other then
        return other
    end
end

--- @param rules imm.Dependency.Mod[]
function ILoadList:getModDepMods(rules)
    for i, rule3 in ipairs(rules) do
        local mod = self:getModVersionSatisfies(rule3.mod, rule3.rules)
        if mod then return mod, rule3.rules end
    end
end

--- @param mod imm.Mod
--- @param rule2 imm.Dependency.Mod[]
--- @param addMissing? boolean
function ILoadList:addModDep(mod, rule2, addMissing)
    local match, mrule = self:getModDepMods(rule2)
    if not match then
        if addMissing then
            for i, rule3 in ipairs(rule2) do
                local missingid = rule3.mod
                if not self.missingDeps[missingid] then self.missingDeps[missingid] = {} end
                self.missingDeps[missingid][mod] = rule3.rules
            end
        end
        return
    end

    if not self.loadedModDeps[mod.mod] then self.loadedModDeps[mod.mod] = {} end
    table.insert(self.loadedModDeps[mod.mod], match)

    if not self.dependents[match.mod] then self.dependents[match.mod] = {} end
    self.dependents[match.mod][mod] = mrule

    return match, mrule
end

--- @param mod imm.Mod
--- @param addMissing? boolean
function ILoadList:addModDeps(mod, addMissing)
    --- @type [imm.Mod, imm.Dependency.Rule[]][]
    local list = {}
    for i, rule2 in ipairs(mod.deps) do
        local m, r = self:addModDep(mod, rule2, addMissing)
        if m then table.insert(list, {m, r}) end
    end
    return list
end

--- Used when switching to specific version of already loaded mod
--- @param mod imm.Mod
function ILoadList:getDependentsConflicts(mod)
    --- @type table<imm.Mod, imm.Dependency.Rule[]>
    local problematics = {}
    local depList = self.dependents[mod.mod]
    if depList then
        for other, rules in pairs(depList) do
            if not mod.versionParsed:satisfiesAll(rules) then
                problematics[other] = rules
            end
        end
    end
    return problematics
end

--- @protected
--- @param mod imm.Mod
--- @param rules? imm.Dependency.Rule[]
--- @param cause? imm.Mod
function ILoadList:_tryDisable(mod, rules, cause)
    logger.fmt('debug', 'Disable %s %s', mod.mod, mod.version)
    local id = mod.mod

    local a = self.actions[id]
    if a then
        if a.impossible then return end
        table.insert(a.disableRules, rules)

        -- disabling from enabled - do not disable, just change the mod to enable
        if a.action == 'enable' and a.mod.versionParsed:satisfiesAllAny(a.disableRules) then
            local m = self:getModVersionSatisfies(mod.mod, a.enableRules)
            if not m then a.impossible = true
            else self:_tryEnable(m) end
            return
        end

        a.action = 'disable'
        a.mod = mod
        a.cause = cause or a.cause
    else
        a = { action = 'disable', mod = mod, cause = cause, enableRules = {}, disableRules = {rules} }
        self.actions[id] = a
    end

    -- already disabled?
    if not self.loadedMods[id] then
        logger.dbg('Early return')
        return
    end

    a.update = true
    self.hasActionUpdate = true
    assert(self:disable(mod))
end

--- @protected
--- @param mod imm.Mod
--- @param rules? imm.Dependency.Rule[]
--- @param cause? imm.Mod
function ILoadList:_tryEnable(mod, rules, cause)
    if mod.list.native then return end

    logger.fmt('debug', 'Enable %s %s', mod.mod, mod.version)
    local id = mod.mod

    local a = self.actions[id]
    if a then
        if a.impossible then return end
        if rules then for i, rule in ipairs(rules) do table.insert(a.enableRules, rule) end end -- concat rules

        -- enabling from disabled
        if a.action == 'disable' then
            logger.dbg('Enabling from disabled')
            if mod.versionParsed:satisfiesAllAny(a.disableRules) then
                local m = self:getModVersionSatisfies(mod.mod, a.enableRules, a.disableRules)
                if m then
                    logger.fmt('debug', 'Found %s %s', m.name, m.version)
                else
                    logger.dbg('Triggered impossible')
                    a.impossible = true
                    return
                end
                mod = m
            else
                logger.dbg('No need')
            end
        end

        -- is updating not necessary?
        if a.action == 'enable'
            and a.mod.versionParsed >= mod.versionParsed
            and a.mod.versionParsed:satisfiesAll(a.enableRules)
            and not a.mod.versionParsed:satisfiesAllAny(a.disableRules)
        then
            logger.dbg('No need to update')
            return
        end

        a.action = 'enable'
        a.mod = mod
        a.cause = cause or a.cause
    else
        a = { action = 'enable', mod = mod, cause = cause, enableRules = rules or {}, disableRules = {} }
        self.actions[id] = a
    end

    -- already enabled?
    if self.loadedMods[id] == mod or self.ctrl.mods[id] and self.ctrl.mods[id].active == mod then return end

    -- check if version sastisfies
    if not mod.versionParsed:satisfiesAllAll(a.enableRules) then
        logger.dbg('Triggered impossible')
        a.impossible = true
        return
    end

    a.update = true
    self.hasActionUpdate = true

    -- switching version
    local prevLoaded = self.loadedMods[id]
    if prevLoaded then
        local problematics = self:getDependentsConflicts(mod)
        for other, rules in pairs(problematics) do
            self:_tryDisable(other, rules, mod)
        end
        assert(self:disable(prevLoaded))
    end

    assert(self:enable(mod))

    -- check for conflicts by other
    local conflicts = self.conflicts[id]
    if conflicts then
        for other, orule in pairs(conflicts) do
            if mod.versionParsed:satisfiesAll(orule) then
                self:_tryDisable(other, orule, mod)
            end
        end
    end

    -- check for conflicts by this mod
    for i, entry in ipairs(mod.conflicts) do
        local other = self.ctrl:findModSatisfies(entry.mod, {})
        if other then self:_tryDisable(other, entry.rules, mod) end
    end

    -- add dependencies
    local depList = self:addModDeps(mod, true)
    for i, otherEntry in ipairs(depList) do
        self:_tryEnable(otherEntry[1], otherEntry[2], mod)
    end
end

--- @protected
--- @param act imm.LoadList.ModAction
function ILoadList:_finalizeAction1(act)
    act.update = false
end

--- @protected
--- @param act imm.LoadList.ModAction
function ILoadList:_finalizeAction2(act)
    local mod = act.mod
    act.update2 = false
    if act.action == 'disable' then
        local depList = self.dependents[mod.mod]
        if depList then
            for other, rules in pairs(depList) do
                self:_tryDisable(other, rules, mod)
            end
        end
    elseif act.action == 'enable' then
    end
end

--- @protected
function ILoadList:_finalize()
    while self.hasActionUpdate do
        self.hasActionUpdate = false
        --[[
        while self.hasActionUpdate do
            self.hasActionUpdate = false
            for k,act in pairs(self.actions) do
                if act.update then
                    act.update2 = true
                    self:_finalizeAction1(act)
                end
            end
        end
        if not self.hasActionUpdate then
            for k,act in pairs(self.actions) do
                if act.update2 then
                    self:_finalizeAction2(act)
                end
            end
        end
        ]]
        for k,act in pairs(self.actions) do
            if act.update then
                act.update = false
                act.update2 = true
                self:_finalizeAction2(act)
            end
        end
    end

    --- @type table<string, imm.LoadList.ModAction>
    local nactions = {}
    local actualLoadded = self.ctrl.loadlist.loadedMods
    for k,act in pairs(self.actions) do
        if act.action == 'enable' and actualLoadded[k] then act.action = 'switch' end

        if act.impossible then nactions[k] = act
        elseif act.action == 'disable' and actualLoadded[k] then nactions[k] = act
        elseif (act.action == 'enable' or act.action == 'switch') and actualLoadded[k] ~= act.mod then nactions[k] = act
        end
    end
    self.actions = nactions
end

--- @param mod imm.Mod
function ILoadList:tryEnable(mod)
    self:_tryEnable(mod, {{ op = '==', version = mod.versionParsed }})
    return self:_finalize()
end

--- @param mod imm.Mod
function ILoadList:tryDisable(mod)
    self:_tryDisable(mod, {{ op = '==', version = mod.versionParsed }})
    return self:_finalize()
end

--- @alias imm.LoadList.C p.Constructor<imm.LoadList, nil> | fun(ctrl: imm.ModController): imm.LoadList
--- @type imm.LoadList.C
local LoadList = constructor(ILoadList)
return LoadList
