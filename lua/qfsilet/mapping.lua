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
		{ name = "SaveQf", desc = "Marks: save qflist local", func = "saveqf", mode = "n" },
		{ name = "LoadQf", desc = "Marks: load qflist local", func = "loadqf", mode = "n" },
	}

	local ft_keymaps = {
		{
			desc = "Marks: delete item quickfix",
			func = "del_itemqf",
			keys = Config.keymap.del_item,
			mode = "n",
		},
		{
			desc = "Marks: clear list of notes on current quickfix",
			func = "clear_notes",
			keys = Config.keymap.quickfix.clear_notes,
			mode = "n",
		},
		{
			desc = "Marks: clear all items quickfix",
			func = "clear_qf_list",
			keys = Config.keymap.quickfix.clear_all,
			mode = "n",
		},
	}
	local loc_keymaps = {
		{
			desc = "Marks: toggle location list",
			func = "toggle_loclist",
			keys = Config.keymap.loclist.toggle_open,
			mode = "n",
		},
	}
	local qf_keymaps = {
		{
			desc = "Marks: toggle quickfix list",
			func = "toggle_qf",
			keys = Config.keymap.quickfix.toggle_open,
			mode = "n",
		},
		{
			desc = "Marks: insert sign mark (on cursor)",
			func = "add_item_toqf",
			keys = Config.keymap.quickfix.on_cursor,
			mode = "n",
		},
		{
			desc = "Marks: open local todo window",
			func = "add_todo",
			keys = Config.keymap.quickfix.add_todo,
			mode = { "n", "v" },
		},
		{
			desc = "Marks: open global todo window",
			func = "add_todo_global",
			keys = Config.keymap.quickfix.add_todo_global,
			mode = { "n", "v" },
		},
		{
			desc = "Marks: set cursor link capture todo",
			func = "add_todo_capture_link",
			keys = Config.keymap.quickfix.add_link_capture,
			mode = "n",
		},
		{
			desc = "Marks: open todo cursor and collect with quickfix",
			func = "fzf_qf",
			keys = Config.keymap.quickfix.fzf_qf,
			mode = "n",
		},
		{
			desc = "Marks: goto link capture",
			func = "goto_link_capture",
			keys = Config.keymap.quickfix.goto_link_capture,
			mode = { "n", "v" },
		},
		{
			desc = "Marks: save quickfix items",
			func = "saveqf",
			keys = Config.keymap.quickfix.save_local,
			mode = "n",
		},
		{
			desc = "Marks: load quickfix items",
			func = "loadqf",
			keys = Config.keymap.quickfix.load_local,
			mode = "n",
		},
	}

	local marks_keymaps = {
		{
			desc = "Marks: toggle marks",
			func = "toggle_mark_cursor",
			keys = Config.keymap.marks.toggle_mark,
			mode = "n",
		},
		{
			desc = "Marks: jump to next",
			func = "next_mark",
			keys = Config.keymap.marks.next_mark,
			mode = "n",
		},
		{
			desc = "Marks: jump to prev",
			func = "prev_mark",
			keys = Config.keymap.marks.prev_mark,
			mode = "n",
		},
		{
			desc = "Marks: delete all current marks",
			func = "delete_buf_marks",
			keys = Config.keymap.marks.del_buf_mark,
			mode = "n",
		},
		{
			desc = "Marks: open marks with fzf",
			func = "fzf_marks",
			keys = Config.keymap.marks.fzf_marks,
			mode = "n",
		},
		{
			desc = "Marks: collect marks and send to quickfix list",
			func = "marks_send_to_ll",
			keys = Config.keymap.marks.fzf_send_qf_marks,
			mode = "n",
		},
		{
			desc = "Marks: delete mark",
			func = "delete",
			keys = Config.keymap.marks.del_mark,
			mode = "n",
		},
		{
			desc = "Marks: show config marks",
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
