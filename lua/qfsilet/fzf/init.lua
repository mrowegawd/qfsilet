local Util = require("qfsilet.utils")
local fzf_ok, _ = pcall(require, "fzf-lua")

if not fzf_ok then
	Util.warn("fzf-lua diperlukan sebagai dependensi")
	return
end

local FzfMappings = require("qfsilet.fzf.mappings")
local Constant = require("qfsilet.constant")
local Ui = require("qfsilet.ui")
local NoteUtil = require("qfsilet.note.util")

local M = {}

local stat_fname_todo = {
	deleted = {},
	saved = {},
	cwd_root = "",
	note_dirpath = "",
	qf = {
		idx = "",
		items = {},
		title = "",
	},
	loclist = {
		idx = "",
		items = {},
		title = "",
	},
}

local function formatTitle(str, icon, iconHl)
	return {
		{ " " },
		{ (icon and icon .. " " or ""), iconHl or "Keyword" },
		{ str, "Bold" },
		{ " " },
	}
end

function M.load(opts, isGlobal)
	local titleMsg = "local"
	if isGlobal then
		titleMsg = "global"
	end

	if not Util.checkJSONPath(Constant.defaults.base_path) then
		Util.warn(
			string.format([[Tidak ada %s note pada path project ini. Cobalah untuk membuatnya..]], titleMsg),
			"QFSilet"
		)
		return
	end

	require("fzf-lua").files({
		cwd = Constant.defaults.base_path,
		previewer = false,
		fzf_opts = { ["--header"] = [[Ctrl-x:'delete']] },
		cmd = "fd -d 1 -e json | cut -d. -f1",
		no_header_i = true,
		no_header = true,
		winopts = {
			hl = { normal = "Normal" },
			border = "rounded",
			height = 0.4,
			-- title = formatTitle(titleMsg:gsub("^%l", string.upper) .. " Qf items", "", "Boolean"),
			title = formatTitle(string.format("Load (%s) qf items", titleMsg), "", "Boolean"),
			width = 0.30,
			row = 0.40,
			col = 0.55,
			preview = { hidden = "hidden" },
		},
		winopts_fn = function()
			local cols = vim.o.columns - 50
			local collss = cols > 80 and cols - 80 or cols / 2

			local win_height = math.ceil(Util.get_option("lines") * 0.5 - 10)
			local win_width = math.ceil(Util.get_option("columns") * 0.5 - 20)
			return { width = win_width, height = win_height, row = 20, col = collss }
		end,
		actions = vim.tbl_extend(
			"keep",
			FzfMappings.editOrMergeQuickFix(opts, Constant.defaults.base_path),
			FzfMappings.deleteItem(Constant.defaults.base_path)
		),
	})
end

function M.sel_qf(opts, isLoad)
	isLoad = isLoad or false

	local prompt_prefix = "Save"
	if isLoad then
		prompt_prefix = "Load"
	end

	require("fzf-lua").fzf_exec({ "global", "local" }, {
		prompt = prompt_prefix .. " quickfix items? ",
		winopts = {
			hl = { normal = "Normal" },
			border = "rounded",
			height = 0.4,
			-- title = formatTitle(titleMsg:gsub("^%l", string.upper) .. " Qf items", "", "Boolean"),
			width = 0.30,
			row = 0.40,
			col = 0.55,
			preview = { hidden = "hidden" },
		},
		winopts_fn = function()
			local cols = vim.o.columns - 50
			local collss = cols > 80 and cols - 80 or cols / 2

			local win_height = math.ceil(Util.get_option("lines") * 0.5 - 10)
			local win_width = math.ceil(Util.get_option("columns") * 0.5 - 20)
			return { width = win_width, height = win_height, row = 20, col = collss }
		end,

		actions = {
			["default"] = function(selected, _)
				if selected[1] then
					if isLoad then
						local checkGlobal = false
						if selected[1] == "global" then
							checkGlobal = true
						end
						M.load(opts, checkGlobal)
					else
						local lists_qf = NoteUtil.get_current_list()

						Ui.input(function(inputMsg)
							-- If `value` contains spaces, concat it them with underscore
							if inputMsg == "" then
								return
							end

							inputMsg = inputMsg:gsub("%s", "_")
							inputMsg = inputMsg:gsub("%.", "_")

							for _, tbl in ipairs(lists_qf) do
								local jbl = {
									filename = vim.api.nvim_buf_get_name(tbl.bufnr),
									lnum = tbl.lnum,
									col = tbl.col,
									text = tbl.text,
									type = tbl.type,
								}

								table.insert(stat_fname_todo.qf.items, jbl)
							end

							stat_fname_todo.qf.idx = "$"
							stat_fname_todo.qf.title = inputMsg

							stat_fname_todo.cwd_root = Constant.defaults.base_path

							NoteUtil.save_list_to_file(Constant.defaults.base_path, stat_fname_todo, inputMsg, true)
						end, selected[1] .. " Save")

						for _, fname in pairs(stat_fname_todo.deleted) do
							table.insert(stat_fname_todo.saved, fname)
						end
					end
				end
			end,
		},
	})
end

function M.grep_marks(marks_opts, path)
	local keyset = Util.key_to_tbl(marks_opts)

	-- Create custom previewer fzf
	local builtin = require("fzf-lua.previewer.builtin")
	local marks_previewer = builtin.buffer_or_file:extend()

	function marks_previewer:new(o, opts, fzf_win)
		marks_previewer.super.new(self, o, opts, fzf_win)
		setmetatable(self, marks_previewer)
		return self
	end

	function marks_previewer:parse_entry(entry_str)
		-- local path, line = entry_str:match("([^:]+):?(.*)")
		return {
			path = path,
			line = marks_opts[entry_str].line,
			col = marks_opts[entry_str].col,
		}
	end

	require("fzf-lua").fzf_exec(keyset, {
		previewer = marks_previewer,
		prompt = "Select mark> ",
		actions = FzfMappings.mark_defaults(marks_opts),
		winopts = {
			hl = { normal = "Normal" },
			title = formatTitle("Marks ", "X", "Boolean"),
			border = "rounded",
			preview = {
				vertical = "up:45%", -- up|down:size
				horizontal = "left:60%", -- right|left:size
			},
		},
		winopts_fn = function()
			local cols = vim.o.columns - 50
			local collss = cols > 80 and cols - 80 or cols / 2

			local win_height = math.ceil(Util.get_option("lines") * 0.5)
			local win_width = math.ceil(Util.get_option("columns") * 1)

			local row = math.ceil((Util.get_option("lines") - win_height) * 1 + 5)
			return { width = win_width, height = win_height, row = row, col = collss }
		end,
	})
end

return M
