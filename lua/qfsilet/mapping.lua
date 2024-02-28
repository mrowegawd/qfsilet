local Qfsilet_qf = require("qfsilet.qf")
local Qfsilet_marks = require("qfsilet.marks")
local Config = require("qfsilet.config").current_configs

local M = {}

local function set_keymaps(keys_tbl, is_bufnr, is_marks)
	is_marks = is_marks or false
	for _, cmd in ipairs(keys_tbl) do
		if #cmd.keys > 0 then
			local keymap_func = is_marks and Qfsilet_marks[cmd.func] or Qfsilet_qf[cmd.func]
			local keymap_args = { desc = cmd.desc }
			if is_bufnr then
				keymap_args.buffer = vim.api.nvim_get_current_buf()
			end
			vim.keymap.set(cmd.mode, cmd.keys, keymap_func, keymap_args)
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
	local qf_autocmds = {
		{ name = "SaveQfLocal", desc = "Save qflist local", func = "saveqf", mode = "n" },
		{ name = "LoadQfLocal", desc = "Load qflist local", func = "loadqf", mode = "n" },
	}

	local ft_keymaps = {
		{
			desc = "Delete item qf",
			func = "del_itemqf",
			keys = Config.keymap.del_item,
			mode = "n",
		},
		{
			desc = "Clear list of notes on current qf",
			func = "clear_notes",
			keys = Config.keymap.quickfix.clear_notes,
			mode = "n",
		},
		{
			desc = "Clear all items qf",
			func = "clear_qf_list",
			keys = Config.keymap.quickfix.clear_all,
			mode = "n",
		},
	}
	local loc_keymaps = {
		{
			desc = "Toggle loclist",
			func = "toggle_loclist",
			keys = Config.keymap.loclist.toggle_open,
			mode = "n",
		},
	}
	local qf_keymaps = {
		{
			desc = "Toggle qflist",
			func = "toggle_qf",
			keys = Config.keymap.quickfix.toggle_open,
			mode = "n",
		},
		{
			desc = "Insert line to qflist (on cursor)",
			func = "add_item_toqf",
			keys = Config.keymap.quickfix.on_cursor,
			mode = { "n", "v" },
		},
		{
			desc = "Add todo",
			func = "add_todo",
			keys = Config.keymap.quickfix.add_todo,
			mode = { "n", "v" },
		},
		{
			desc = "Add global todo",
			func = "add_todo_global",
			keys = Config.keymap.quickfix.add_todo_global,
			mode = { "n", "v" },
		},
		{
			desc = "Add todo link capture",
			func = "add_todo_capture_link",
			keys = Config.keymap.quickfix.add_link_capture,
			mode = { "n", "v" },
		},
		{
			desc = "Open fzf qf",
			func = "fzf_qf",
			keys = Config.keymap.quickfix.fzf_qf,
			mode = { "n", "v" },
		},
		{
			desc = "Goto link capture",
			func = "goto_link_capture",
			keys = Config.keymap.quickfix.goto_link_capture,
			mode = { "n", "v" },
		},
		{
			desc = "Save to file qf items",
			func = "saveqf",
			keys = Config.keymap.quickfix.save_local,
			mode = { "n", "v" },
		},
		{
			desc = "Load qf file (local)",
			func = "loadqf",
			keys = Config.keymap.quickfix.load_local,
			mode = { "n", "v" },
		},
	}

	local marks_keymaps = {
		{
			desc = "Toggle marks",
			func = "toggle_mark_cursor",
			keys = Config.keymap.marks.toggle_mark,
			mode = "n",
		},
		{
			desc = "Next target marks",
			func = "next_mark",
			keys = Config.keymap.marks.next_mark,
			mode = "n",
		},
		{
			desc = "Prev target marks",
			func = "prev_mark",
			keys = Config.keymap.marks.prev_mark,
			mode = "n",
		},
		{
			desc = "Delete all current marks",
			func = "delete_buf_marks",
			keys = Config.keymap.marks.del_buf_mark,
			mode = "n",
		},
		{
			desc = "Open fzf marks",
			func = "fzf_marks",
			keys = Config.keymap.marks.fzf_marks,
			mode = "n",
		},
		{
			desc = "Delete mark",
			func = "delete",
			keys = Config.keymap.marks.del_mark,
			mode = "n",
		},
		{
			desc = "Show config marks",
			func = "show_config",
			keys = Config.keymap.marks.show_config,
			mode = "n",
		},
	}

	for _, cmd in ipairs(qf_autocmds) do
		vim.api.nvim_create_user_command(cmd.name, Qfsilet_qf[cmd.func], { desc = cmd.desc })
	end

	set_ft_keymaps("QFSiletAuMappings", { "qf" }, ft_keymaps)

	set_keymaps(qf_keymaps, false)
	set_keymaps(loc_keymaps, false)
	set_keymaps(marks_keymaps, false, true)
end

return M
