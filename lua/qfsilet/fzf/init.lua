local Utils = require("qfsilet.utils")
local Visual = require("qfsilet.marks.visual")
local UtilsFzf = require("qfsilet.fzf.utils")
local fzf_ok, Fzflua = pcall(require, "fzf-lua")

if not fzf_ok then
	Utils.warn("fzf-lua diperlukan sebagai dependensi")
	return
end

local FzfMappings = require("qfsilet.fzf.mappings")
local Constant = require("qfsilet.constant")
local Ui = require("qfsilet.ui")
local UtilsNote = require("qfsilet.note.utils")

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

local function h(name)
	return vim.api.nvim_get_hl(0, { name = name })
end

-- set hl-groups
vim.api.nvim_set_hl(0, "QFSiletPreviewTitle", { fg = h("Normal").fg, bg = h("Normal").fg, italic = true, bold = true })
vim.api.nvim_set_hl(0, "QFSiletNormal", { fg = h("Normal").bg, bg = h("Normal").fg, italic = true, bold = true })

local function formatTitle(str, icon, iconHl)
	return {
		{ " ", "QFSiletNormal" },
		{ (icon and icon .. " " or ""), iconHl or "QFSiletPreviewTitle" },
		{ str, "QFSiletNormal" },
		{ " ", "QFSiletNormal" },
	}
end

function M.load(opts, isGlobal)
	local titleMsg = "local"
	if isGlobal then
		titleMsg = "global"
	end

	if not Utils.checkJSONPath(Constant.defaults.base_path) then
		Utils.warn(string.format([[No %s list qf items on this cwd. Cobalah untuk membuatnya..]], titleMsg), "QFSilet")
		return
	end

	Fzflua.files({
		cwd = Constant.defaults.base_path,
		previewer = false,
		fzf_opts = { ["--header"] = [[ctrl-x:delete]] },
		cmd = "fd -d 1 -e json | cut -d. -f1",
		no_header_i = true,
		no_header = true,
		winopts = function()
			local cols = vim.o.columns - 50
			local collss = cols > 80 and cols - 80 or cols / 2

			local win_height = math.ceil(Utils.get_option("lines") * 0.5 - 10)
			local win_width = math.ceil(Utils.get_option("columns") * 0.5 - 20)
			return {
				hls = { normal = "Normal" },
				border = "rounded",
				title = formatTitle(string.format("Load (%s) Quickfix items", titleMsg), ""),
				preview = { hidden = "hidden" },
				width = win_width,
				height = win_height,
				row = 20,
				col = collss,
				backdrop = 60,
			}
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

	local prompt_prefix = "Save Quickfix Items"
	if isLoad then
		prompt_prefix = "Load Quickfix Items"
	end

	FzfLua.fzf_exec({ "global", "local" }, {
		prompt = "  ",
		winopts = function()
			local cols = vim.o.columns - 50
			local collss = cols > 80 and cols - 80 or cols / 2

			local win_height = math.ceil(Utils.get_option("lines") * 0.5 - 10)
			local win_width = math.ceil(Utils.get_option("columns") * 0.5 - 20)
			return {
				width = win_width,
				height = win_height,
				row = 20,
				col = collss,
				backdrop = 60,
				hls = { normal = "Normal" },
				border = "rounded",
				title = formatTitle("QF-" .. prompt_prefix, ""),
				preview = { hidden = "hidden" },
			}
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
						local lists_qf = UtilsNote.get_current_list()

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

							UtilsNote.save_list_to_file(Constant.defaults.base_path, stat_fname_todo, inputMsg, true)
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

function M.grep_marks(buffer)
	local marks = {}

	for _, x in pairs(buffer.lists) do
		local filename = Utils.format_filename(x.filename)
		local col = x.col
		local line = x.line
		marks[#marks + 1] = filename .. ":" .. line .. ":" .. col
	end

	if #marks == 0 then
		Utils.info("No marks available", "Marks")
		return
	end

	local builtin = require("fzf-lua.previewer.builtin")
	local Markpreviewer = builtin.buffer_or_file:extend()

	function Markpreviewer:new(o, opts, fzf_win)
		Markpreviewer.super.new(self, o, opts, fzf_win)
		setmetatable(self, Markpreviewer)
		return self
	end

	function Markpreviewer:parse_entry(entry_str)
		entry_str = UtilsFzf.stripString(entry_str)

		if entry_str then
			local sel_text = entry_str:gsub(Visual.extmarks.qf_sigil .. " ", "")
			local line = string.match(sel_text, ":(%d+):")
			local filename = string.match(sel_text, "([%w+]+%.%w+):")

			if filename == nil then
				return {}
			end

			local data

			for _, x in pairs(buffer.lists) do
				local filename_trim = Utils.format_filename(x.filename)
				if string.match(filename_trim, filename) and tonumber(x.line) == tonumber(line) then
					data = {
						path = x.filename,
						line = x.line,
						col = x.col,
					}
				end
			end

			if data then
				return data
			end
		end

		return {}
	end

	FzfLua.fzf_exec(marks, {
		previewer = {
			_ctor = function()
				return Markpreviewer
			end,
		},
		prompt = "  ",
		actions = FzfMappings.mark_defaults(buffer),
		fzf_opts = { ["--header"] = [[ctrl-x:delete  alt-x:delete-all]] },
		winopts = function()
			return {
				width = 0.80,
				height = 0.80,
				row = 0.55,
				col = 0.55,
				title = formatTitle("QF-Marks", Visual.extmarks.qf_sigil),
				border = "rounded",
				preview = {
					vertical = "up:45%", -- up|down:size
					horizontal = "right:70%", -- right|left:size
				},
			}
		end,
	})
end

return M
