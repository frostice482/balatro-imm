local constructor = require('imm.lib.constructor')
local TM = require("imm.lib.texture_moveable")
local ui = require("imm.lib.ui")
local util = require("imm.lib.util")
local imm = require("imm")
local defaultTasks = require("imm.btasks.tasks")()
defaultTasks.queues.available = tonumber(imm.config.mpConcurrentTasks) or 2

--- @class imm.UI.MPList.Funcs
local funcs = {
	activate = 'imm_mpl_activate',
	active = 'imm_mpl_active',
	settings = 'imm_mpl_settings',
	delete = 'imm_mpl_delete',
	deleteConfirm = 'imm_mpl_delconf',
	addnew = 'imm_mpl_addnew',
	init = 'imm_mpl_init',
}

--- @class imm.UI.MPList.Opts
--- @field modpacks? imm.MPList
--- @field tasks? imm.Tasks

--- @class imm.UI.MPList
--- @field list imm.Modpack[]
--- @field cycleOpts imm.UI.CycleOptions
--- @field prioritizeId table<string, boolean>
--- @field uibox? balatro.UIBox
local IUI = {
	search = '',
	searchTimeout = 0.3,
	searchWidth = 8,

	listId = 'list',
	pageSize = 4,

	buttonScale = 0.6,
	buttonGap = 0.2,

	descWidth = 7,
	descLines = 15,

	mpUpdateDelay = 1,
	optWidth = 3.25,

	titleLength = 8,
	iconSize = 1,

	hasChanges = false,
}

local sprites = {
	activate = { x = 0, y = 2 },
	activateNo = { x = 1, y = 2 },
	merge = { x = 0, y = 3 },
	mergeNo = { x = 1, y = 3 },
	settings = { x = 0, y = 4 },
	delete = { x = 0, y = 0 },
}

--- @protected
--- @param opts? imm.UI.MPList.Opts
function IUI:init(opts)
	opts = opts or {}
	self.modpacks = opts.modpacks or require"imm.modpacks"
	self.tasks = opts.tasks or defaultTasks

	self.prioritizeId = {}

	self.list = {}
	self.cycleOpts = {
		func = function (i)
			return self.list[i] and self:renderMpContainer(self.list[i])
		end,
		id = self.listId,
		length = 0,
		pagesize = self.pageSize
	}
	self.colors = {
		header = G.C.BOOSTER,
		cycle = G.C.BOOSTER,
		newButton = G.C.BLUE,
	}

	self.tasks.status:update(
		"Drag and drop a modpack here to install it.",
		"Only install modpacks you trust.",
		true
	)
end

--- @protected
--- @param mp imm.Modpack
function IUI:renderMpInput(mp)
	local x = ui.textInput({
		ref_table = mp,
		ref_value = 'name',
		delay = self.mpUpdateDelay,
		onSet = function (v) mp:save() end,

		max_length = 5 * self.titleLength,
		w = self.titleLength,
		extended_corpus = true,
		prompt_text = 'Modpack title'
	})
	x.nodes[1].config.on_demand_tooltip = { text = self:uiMpDesc(mp) }
	return x
end

--- @protected
function IUI:renderSearch()
	return ui.textInput({
		ref_table = self,
		ref_value = 'search',
		delay = self.searchTimeout,
		onSet = function (v) self:updateList() end,

		w = self.searchWidth,
		max_length = 5 * self.searchWidth,
		prompt_text = 'Search',
		colour = self.colors.header,
	})
end

--- @class _imm.UI.MPList.Button
--- @field btn string
--- @field pos Position
--- @field title? string[]
--- @field ref? any

--- @protected
--- @param opts _imm.UI.MPList.Button
function IUI:renderMpButton(opts)
	local spr = Sprite(0, 0, self.buttonScale, self.buttonScale, G.ASSET_ATLAS.imm_icons, opts.pos)
	return ui.C{
		align = 'cm',
		button = opts.btn,
		tooltip = opts.title and { text = opts.title },
		ref_table = opts.ref,

		ui.O(spr)
	}
end

--- @protected
--- @param mp imm.Modpack
function IUI:uiMpDesc(mp)
	local _, descs = G.LANG.font.FONT:getWrap(mp.description, G.TILESCALE * G.TILESIZE * 20 * self.descWidth)
	for i=self.descLines+1, #descs do descs[i] = nil end
	return descs
end

--- @protected
--- @param mp imm.Modpack
--- @param diff imm.Modpack.Diff
function IUI:renderMpActions(mp, diff)
	--- @type balatro.UIElement.Definition[]
	return {
		self:renderMpButton(diff.empty and {
			title = {'Nothing to change'},
			btn = funcs.active,
			pos = sprites.activateNo,
		} or {
			title = {'Apply'},
			btn = funcs.activate,
			pos = sprites.activate,
			ref = { ses = self, mp = mp, diff = diff, merge = false }
		}),
		self:renderMpButton(diff.mergeEmpty and {
			title = {'Nothing to merge'},
			btn = funcs.active,
			pos = sprites.mergeNo,
		} or {
			title = {'Merge'},
			btn = funcs.activate,
			pos = sprites.merge,
			ref = { ses = self, mp = mp, diff = diff, merge = true }
		}),
		self:renderMpButton({
			title = {'Settings'},
			btn = funcs.settings,
			pos = sprites.settings,
			ref = { ses = self, mp = mp }
		}),
		self:renderMpButton({
			title = {'Delete'},
			btn = funcs.delete,
			pos = sprites.delete,
			ref = { ses = self, mp = mp }
		})
	}
end

--- @protected
--- @param mp imm.Modpack
function IUI:renderMpRows(mp)
	local diff = mp:diff()
	local icon = TM(mp:getIcon(), 0, 0, self.iconSize, self.iconSize)

	--- @type balatro.UIElement.Definition[]
	return {
		ui.C{ui.O(icon)},
		self:renderMpInput(mp),
		ui.C{ align = 'cm', ui.R{ align = 'cm', nodes = ui.gapList('C', self.buttonGap, self:renderMpActions(mp, diff)) } }
	}
end

--- @protected
--- @param mp imm.Modpack
function IUI:renderMpContainer(mp)
	return ui.R{
		padding = 0.1,
		ui.R{
			colour = G.C.BOOSTER,
			padding = 0.2,
			r = true,
			nodes = self:renderMpRows(mp)
		}
	}
end

function IUI:getList()
	--- @type imm.Modpack[]
	local list = {}
	--- @type imm.Modpack[]
	local prioritized = {}

	for i, mp in ipairs(self.modpacks:list()) do
		if self.search == "" or mp.name:lower():find(self.search:lower(), 1, true) then
			table.insert(self.prioritizeId[mp.id] and prioritized or list, mp)
		end
	end

	util.insertBatch(prioritized, list)
	return prioritized
end

function IUI:updateList()
	self.list = self:getList()
	return self:updateCycle()
end

--- @protected
function IUI:renderCycleOpts()
	--- @type balatro.UI.OptionCycleParam
	return {
		colour = self.colors.cycle
	}
end

function IUI:updateCycle()
	self.cycleOpts.length = #self.list
	return ui.cycleUpdate(self.cycleOpts, self:renderCycleOpts())
end

--- @protected
function IUI:renderCycle()
	self:updateList()
	return ui.cycle(self.cycleOpts, self:renderCycleOpts())
end

--- @protected
function IUI:renderAddNew()
	return UIBox_button({
		label = {'+'},
		button = funcs.addnew,
		ref_table = self,
		scale = 0.5,
		minw = 0.8,
		colour = self.colors.newButton,
	})
end

--- @protected
function IUI:renderOptLeft()
	--- @type balatro.UIElement.Definition[]
	return {
		self:renderAddNew()
	}
end

--- @protected
function IUI:renderOptRight()
	--- @type balatro.UIElement.Definition[]
	return {
	}
end

--- @protected
function IUI:renderCycleRow()
	--- @type balatro.UIElement.Definition[]
	return {
		ui.C{ minw = self.optWidth, align = 'cl', ui.R(self:renderOptLeft()) },
		ui.C{self:renderCycle()},
		ui.C{ minw = self.optWidth, align = 'cr', ui.R(self:renderOptRight()) },
	}
end

--- @protected
function IUI:renderListContainer()
	local x = ui.container(self.listId, true)
	x.config.func = funcs.init
	x.config.ref_table = self
	return x
end

--- @protected
function IUI:renderCols()
	--- @type balatro.UIElement.Definition[]
	return {
		ui.R{align = 'cm', self:renderSearch()},
		self:renderListContainer(),
		ui.R{align = 'cm', nodes = self:renderCycleRow()},
		ui.R{self.tasks.status:render()}
	}
end

function IUI:render()
	self.uibox = nil
	ui.cycleReset(self.cycleOpts)
	return create_UIBox_generic_options({
		contents = self:renderCols()
	})
end

function IUI:showOverlay()
	return ui.overlay(self:render())
end

--- @alias imm.UI.MPList.C imm.UI.MPList.S | p.Constructor<imm.UI.MPList, nil> | fun(opts?: imm.UI.MPList.Opts): imm.UI.MPList
--- @type imm.UI.MPList.C
local UI = constructor(IUI)

--- @class imm.UI.MPList.S
local UIS = UI

UIS.funcs = funcs

return UI
