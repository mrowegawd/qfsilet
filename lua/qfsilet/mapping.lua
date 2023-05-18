local qfsilet_qf = require("qfsilet.qf")
local config = require("qfsilet.config").current_configs

local M = {}

local function set_keymaps(keys_tbl, is_set_bufnr)
	for _, cmd in ipairs(keys_tbl) do
		if is_set_bufnr then
			vim.keymap.set(
				cmd.mode,
				cmd.keys,
				qfsilet_qf[cmd.func],
				{ desc = cmd.desc, buffer = vim.api.nvim_get_current_buf() }
			)
		else
			vim.keymap.set(cmd.mode, cmd.keys, qfsilet_qf[cmd.func], { desc = cmd.desc })
		end
	end
end

local function set_ft_keymaps(name_au, pattern, keymaps)
	local augroup = vim.api.nvim_create_augroup(name_au, { clear = true })
	vim.api.nvim_create_autocmd("FileType", {
		pattern = pattern,
		group = augroup,
		callback = function()
			set_keymaps(keymaps, true)
		end,
	})
end

function M.setup_keymaps_and_autocmds()
	local commands = {
		{
			name = "SaveQfLocal",
			desc = "Save qflist local",
			func = "saveqf_local",
			mode = "n",
		},
		{
			name = "SaveQfGlobal",
			desc = "Save qflist global",
			func = "saveqf_global",
			mode = "n",
		},
		{
			name = "LoadQfLocal",
			desc = "Load qflist local",
			func = "loadqf_local",
			mode = "n",
		},
		{
			name = "LoadQfGlobal",
			desc = "Load qflist global",
			func = "loadqf_global",
			mode = "n",
		},
		-- {
		-- 	name = "QFSiletTestFunc",
		-- 	desc = "Test func of QFSilet",
		-- 	func = "check_saved",
		-- 	mode = "n",
		-- },
	}
	local ft_keymaps = {
		{
			desc = "Delete item qf",
			func = "del_itemqf",
			keys = config.keymap.del_item,
			mode = "n",
		},
		{
			desc = "Clear list of notes on current qf",
			func = "clear_notes",
			keys = config.keymap.quickfix.clear_notes,
			mode = "n",
		},
		{
			desc = "Clear all items qf",
			func = "clear_qf_list",
			keys = config.keymap.quickfix.clear_all,
			mode = "n",
		},
	}
	local loc_keymaps = {
		{
			desc = "Toggle loclist",
			func = "toggle_loclist",
			keys = config.keymap.loclist.toggle_open,
			mode = "n",
		},
	}
	local qf_keymaps = {
		{
			desc = "Toggle qflist",
			func = "toggle_qf",
			keys = config.keymap.quickfix.toggle_open,
			mode = "n",
		},
		{
			desc = "Insert line to qflist (on cursor)",
			func = "add_item_toqf",
			keys = config.keymap.quickfix.on_cursor,
			mode = "n",
		},
		{
			desc = "Add todo",
			func = "add_todo",
			keys = config.keymap.quickfix.add_todo,
			mode = { "n", "v" },
		},
		{
			desc = "Add global todo",
			func = "add_todo_global",
			keys = config.keymap.quickfix.add_todo_global,
			mode = { "n", "v" },
		},
	}

	for _, cmd in ipairs(commands) do
		vim.api.nvim_create_user_command(cmd.name, qfsilet_qf[cmd.func], { desc = cmd.desc })
	end

	set_ft_keymaps("QFSiletAuMappings", { "qf" }, ft_keymaps)
	set_keymaps(qf_keymaps, false)
	set_keymaps(loc_keymaps, false)
end

return M
