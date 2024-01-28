local fn = vim.fn

local Visual = require("qfsilet.visual")
local Utils = require("qfsilet.utils")

local M = {}

local default_settings = {
	save_dir = fn.stdpath("data") .. "/qfsilet",
	prefix_title = "QFSilet",
	hl_group = "Comment",
	extmarks = false,
	theme_list = {
		enabled = true,
		maxheight = 5,
		minheight = 3,
	},
	signs = {
		qflist = "",
		priority = 10,
	},
	notify = {
		enabled = true,
		notif_plugin = "noice",
	},
	file_spec = {
		name = "todo",
		filetype = "org",
		ext_file = "org",
	},
	popup = {
		winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
		icon_note = " ",
		border = "",
		filetype = "org",
	},
	keymap = {
		del_item = "dd",
		del_note = "DD",
		quickfix = {
			clear_all = "C",
			clear_notes = "cc",
			toggle_open = "<leader>q",
			-- toggle_open = nil,
			on_cursor = "<localleader>qq",
			add_todo = "<localleader>qt",
			add_link_capture = "<localleader>qc",
			goto_link_capture = "g<cr>",
			add_todo_global = "<localleader>qT",
		},
		loclist = {
			toggle_open = "<leader>Q",
		},
	},
}

M.current_configs = {}

local function merge_settings(cfg_tbl, opts)
	opts = opts or {}
	local settings = vim.tbl_deep_extend("force", cfg_tbl, opts)
	return settings
end

local function setup_highlight_groups()
	local names = {
		qf_sign_hl = Visual.extmarks.qf_sign_hl_group,
		qf_ext_hl = Visual.extmarks.qf_ext_hl_group,
		-- local_sign_hl = visual.extmarks.local_sign_hl_group,
		-- local_ext_hl = visual.extmarks.local_ext_hl_group,
	}
	for id, name in pairs(names) do
		---@diagnostic disable-next-line: undefined-field
		local ok = pcall(vim.api.nvim_get_hl_by_name, name, true)
		if not ok then
			vim.validate({
				opt = { Visual.extmarks[id], "t" },
			})

			---@diagnostic disable-next-line: param-type-mismatch
			vim.api.nvim_set_hl(0, name, Visual.extmarks[id])
		end
	end
end

function M.update_settings(opts)
	local settings = merge_settings(default_settings, opts)

	if settings.theme_list.enabled then
		vim.o.qftf = "{info -> v:lua.qftf(info)}"

		local augroup = vim.api.nvim_create_augroup("QFSiletAdjustHWQf", { clear = true })
		vim.api.nvim_create_autocmd("FileType", {
			pattern = { "qf" },
			group = augroup,
			callback = function()
				require("qfsilet.qf").addjustWindowHWQf(settings.theme_list.maxheight, settings.theme_list.minheight)
			end,
		})
	end

	Visual.extmarks.set_extmarks = settings.extmarks
	Visual.extmarks.set_signs = true
	Visual.extmarks.qf_sigil = settings.signs.qflist
	Visual.extmarks.priority = settings.signs.priority

	-- Set highlight first before define sign function
	setup_highlight_groups()
	vim.fn.sign_define(
		Visual.extmarks.qf_sigil,
		{ text = Visual.extmarks.qf_sigil, texthl = Visual.extmarks.qf_sign_hl_group }
	)

	return settings
end

function M.init()
	if not Utils.is_dir(M.current_configs.save_dir) then
		print(M.current_configs.save_dir)
		Utils.create_dir(M.current_configs.save_dir)
	end
end

return M
