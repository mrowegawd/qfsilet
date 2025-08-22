local Qfsilet_qf = require("qfsilet.qf")
local Qfsilet_marks = require("qfsilet.marks")
local Qfsilet_note = require("qfsilet.note")
local Config = require("qfsilet.config").current_configs

local M = {}

local function set_keymaps(keys_tbl, is_bufnr, is_marks, is_todo_note)
	is_bufnr = is_bufnr or false
	is_marks = is_marks or false
	is_todo_note = is_todo_note or false

	vim.validate({
		keys_tbl = { keys_tbl, "table" },
		is_bufnr = { is_bufnr, "boolean" },
		is_marks = { is_bufnr, "boolean" },
		is_todo_note = { is_todo_note, "boolean" },
	})

	for _, cmd in ipairs(keys_tbl) do
		if #cmd.keys > 0 then
			local keymap_func = is_marks and Qfsilet_marks[cmd.func]
				or is_todo_note and Qfsilet_note[cmd.func]
				or Qfsilet_qf[cmd.func]
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
		{ name = "SaveQf", desc = "Qf: save qflist", func = "saveqf", mode = "n" },
		{ name = "LoadQf", desc = "Qf: load qflist", func = "loadqf", mode = "n" },
	}

	local ft_keymaps = {
		{
			desc = "Qf: delete item quickfix [QFsilet]",
			func = "del_itemqf",
			keys = Config.keymap.quickfix.del_item,
			mode = "n",
		},
		{
			desc = "Qf: clear list of notes on current quickfix [QFsilet]",
			func = "clear_notes",
			keys = Config.keymap.quickfix.clear_notes,
			mode = "n",
		},
		{
			desc = "Qf: clear all items quickfix/loclist [QFsilet]",
			func = "clear_all_item_lists",
			keys = Config.keymap.quickfix.clear_all,
			mode = "n",
		},
	}
	local loc_keymaps = {
		{
			desc = "Qf: toggle loclist [QFsilet]",
			func = "toggle_loclist",
			keys = Config.keymap.quickfix.toggle_open_loclist,
			mode = "n",
		},
	}
	local qf_keymaps = {
		{
			desc = "Qf: move quickfix window to top [QFsilet]",
			func = "move_qf_to_above",
			keys = Config.keymap.quickfix.move_to_above,
			mode = "n",
		},
		{
			desc = "Qf: move quickfix window to bottom [QFsilet]",
			func = "move_qf_to_bottom",
			keys = Config.keymap.quickfix.move_to_bottom,
			mode = "n",
		},

		{
			desc = "Qf: toggle quickfix [QFsilet]",
			func = "toggle_qf",
			keys = Config.keymap.quickfix.toggle_open_qf,
			mode = "n",
		},
		{
			desc = "Qf: rename quickfix/loclist [QFsilet]",
			func = "rename_title",
			keys = Config.keymap.quickfix.rename_title,
			mode = "n",
		},
		{
			desc = "Qf: save quickfix items [QFsilet]",
			func = "saveqf",
			keys = Config.keymap.quickfix.save_local,
			mode = "n",
		},
		{
			desc = "Qf: load quickfix items [QFsilet]",
			func = "loadqf",
			keys = Config.keymap.quickfix.load_local,
			mode = "n",
		},
		{
			desc = "Qf: add an item to qf [QFsilet]",
			func = "add_item_qf",
			keys = Config.keymap.quickfix.add_item_to_qf,
			mode = "n",
		},
		{
			desc = "Qf: add an item to loclist [QFsilet]",
			func = "add_item_loc",
			keys = Config.keymap.quickfix.add_item_to_loc,
			mode = "n",
		},
	}
	local todo_note_keymaps = {

		{
			desc = "Note: open local todo [QFsilet]",
			func = "todo_project",
			keys = Config.keymap.todo.add_local,
			mode = { "n", "v" },
		},
		{
			desc = "Note: open global todo [QFsilet]",
			func = "todo_org",
			keys = Config.keymap.todo.add_global,
			mode = { "n", "v" },
		},
		{
			desc = "Note: open note message [QFsilet]",
			func = "note_message",
			keys = Config.keymap.todo.add_message,
			mode = { "n", "v" },
		},
		{
			desc = "Note: capture link cursor [QFsilet]",
			func = "todo_with_capture_link",
			keys = Config.keymap.todo.add_link_capture,
			mode = "n",
		},

		{
			desc = "Marks: go to link capture [QFsilet]",
			func = "todo_goto_capture_link",
			keys = Config.keymap.todo.goto_link_capture,
			mode = { "n", "v" },
		},
	}
	local marks_keymaps = {
		{
			desc = "Marks: toggle add marks [QFsilet]",
			func = "toggle_mark_cursor",
			keys = Config.keymap.marks.toggle_mark,
			mode = "n",
		},
		{
			desc = "Marks: jump to next [QFsilet]",
			func = "next_mark",
			keys = Config.keymap.marks.next_mark,
			mode = "n",
		},
		{
			desc = "Marks: jump to prev [QFsilet]",
			func = "prev_mark",
			keys = Config.keymap.marks.prev_mark,
			mode = "n",
		},
		{
			desc = "Marks: delete mark [QFsilet]",
			func = "delete",
			keys = Config.keymap.marks.del_mark,
			mode = "n",
		},
		{
			desc = "Marks: delete all current marks [QFsilet]",
			func = "delete_buf_marks",
			keys = Config.keymap.marks.del_buf_mark,
			mode = "n",
		},
		{
			desc = "Marks: select marks with picker [QFsilet]",
			func = "fzf_marks",
			keys = Config.keymap.marks.fzf_marks,
			mode = "n",
		},
		{
			desc = "Marks: show config marks [QFsilet]",
			func = "show_config",
			keys = Config.keymap.marks.show_config,
			mode = "n",
		},
	}

	for _, cmd in ipairs(qf_autocmds) do
		vim.api.nvim_create_user_command(cmd.name, Qfsilet_qf[cmd.func], { desc = cmd.desc })
	end

	set_ft_keymaps("QFSiletMappings", { "qf" }, ft_keymaps)

	set_keymaps(qf_keymaps, false, false, false)
	set_keymaps(todo_note_keymaps, false, false, true)
	set_keymaps(loc_keymaps, false, false, false)
	set_keymaps(marks_keymaps, false, true, false)
end

return M
