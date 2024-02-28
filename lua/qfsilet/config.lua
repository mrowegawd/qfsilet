local fn, fmt = vim.fn, string.format

local Visual = require("qfsilet.visual")
local Utils = require("qfsilet.utils")

local M = {}

local default_settings = {
	save_dir = fn.stdpath("data") .. "/qfsilet",
	prefix_title = "QFSilet",
	hl_group = "Comment",
	extmarks = false,
	set_signs = true,
	marks = {
		enabled = true,
		default_mappings = false,
		builtin_marks = false,
		cyclic = true,
		force_write_shada = false,
		refresh_interval = 250,
		signs = {
			enabled = false,
			icon = "",
		},
		sign_priority = { lower = 10, upper = 15, builtin = 8, bookmark = 20 },
		excluded_filetypes = {},
	},
	theme_list = {
		enabled = true,
		maxheight = 8,
		minheight = 5,
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
		filetype = "norg",
	},
	keymap = {
		del_item = "dd",
		del_note = "DD",
		quickfix = {
			clear_all = "C",
			clear_notes = "cc",
			toggle_open = "<leader>q",
			on_cursor = "mq",
			add_todo = "mt",
			add_link_capture = "mc",
			goto_link_capture = "g<cr>",
			add_todo_global = "mT",
			fzf_qf = "mF",
			save_local = "mgs",
			save_global = "mgS",
			load_local = "mgl",
			load_global = "mgL",
		},
		loclist = {
			toggle_open = "<leader>Q",
		},
		marks = {
			toggle_mark = "m``",
			show_config = "mr",
			next_mark = "sn",
			prev_mark = "sp",
			del_buf_mark = "dM",
			del_mark = "dm",
			fzf_marks = "mff",
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
	}
	for id, name in pairs(names) do
		local ok = pcall(vim.api.nvim_get_hl_by_name, name, true)
		if not ok then
			vim.validate({
				opt = { Visual.extmarks[id], "t" },
			})
			vim.api.nvim_set_hl(0, name, Visual.extmarks[id])
		end
	end
end

function M.update_settings(opts)
	local settings = merge_settings(default_settings, opts)

	-- Makes the quickfix and local list prettier. Borrowed from nvim-bqf.
	function _G.qftf(info)
		local items
		local ret = {}
		if info.quickfix == 1 then
			items = fn.getqflist({ id = info.id, items = 0 }).items
		else
			items = fn.getloclist(info.winid, { id = info.id, items = 0 }).items
		end
		local limit = 60
		local fname_fmt1, fname_fmt2 = "%-" .. limit .. "s", "…%." .. (limit - 1) .. "s"
		local valid_fmt = "%s │%5d:%-3d│%s %s"
		for i = info.start_idx, info.end_idx do
			local e = items[i]
			local fname = ""
			local str
			if e.valid == 1 then
				if e.bufnr > 0 then
					fname = fn.bufname(e.bufnr)
					if fname == "" then
						fname = "[No Name]"
					else
						fname = fname:gsub("^" .. vim.env.HOME, "~")
					end
					if #fname <= limit then
						fname = fname_fmt1:format(fname)
					else
						fname = fname_fmt2:format(fname:sub(1 - limit))
					end
				end
				local lnum = e.lnum > 99999 and -1 or e.lnum
				local col = e.col > 999 and -1 or e.col
				local qtype = e.type == "" and "" or " " .. e.type:sub(1, 1):upper()
				str = valid_fmt:format(fname, lnum, col, qtype, e.text)
			else
				str = e.text
			end
			table.insert(ret, str)
		end
		return ret
	end

	local function addjustWindowHWQf(maxheight, minheight)
		maxheight = maxheight or 7
		minheight = minheight or 4
		local l = 1
		local n_lines = 0
		local w_width = fn.winwidth(vim.api.nvim_get_current_win())

		for i = l, fn.line("$") do
			local l_len = fn.strlen(fn.getline(l)) + 0.0
			local line_width = l_len / w_width
			n_lines = n_lines + fn.float2nr(fn.ceil(line_width))
			i = i + 1
		end

		local getheight = fn.max({ fn.min({ n_lines, maxheight }), minheight })
		if getheight > maxheight then
			vim.cmd(fmt("%swincmd _", tostring(maxheight)))
		else
			vim.cmd(fmt("%swincmd _", getheight))
		end
	end

	if settings.theme_list.enabled then
		vim.o.qftf = "{info -> v:lua.qftf(info)}"
		local augroup = vim.api.nvim_create_augroup("QFSiletAdjustHWQf", { clear = true })
		vim.api.nvim_create_autocmd("FileType", {
			pattern = { "qf" },
			group = augroup,
			callback = function()
				addjustWindowHWQf(settings.theme_list.maxheight, settings.theme_list.minheight)
			end,
		})
	end

	if settings.marks.enabled then
		require("qfsilet.marks").setup(settings.marks.refresh_interval)
	end

	Visual.extmarks.set_extmarks = settings.extmarks
	Visual.extmarks.set_signs = settings.set_signs
	Visual.extmarks.qf_sigil = settings.signs.qflist
	Visual.extmarks.priority = settings.signs.priority

	setup_highlight_groups()
	vim.fn.sign_define(
		Visual.extmarks.qf_sigil,
		{ text = Visual.extmarks.qf_sigil, texthl = Visual.extmarks.qf_sign_hl_group }
	)

	return settings
end

function M.init()
	if not Utils.isDir(M.current_configs.save_dir) then
		Utils.create_dir(M.current_configs.save_dir)
	end
end

return M
