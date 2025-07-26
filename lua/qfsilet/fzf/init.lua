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
vim.api.nvim_set_hl(0, "QFSiletPreviewTitle", { fg = h("Normal").bg, bg = h("Normal").fg, italic = true, bold = true })
vim.api.nvim_set_hl(0, "QFSiletNormal", { fg = h("Normal").bg, bg = h("Normal").fg, italic = true, bold = true })

local function formatTitle(str, icon, iconHl)
	return {
		{ " ", "QFSiletNormal" },
		{ (icon and icon .. " " or ""), iconHl or "QFSiletPreviewTitle" },
		{ str, "QFSiletNormal" },
		{ " ", "QFSiletNormal" },
	}
end

function M.load_items_qf(opts, isGlobal)
	local titleMsg = "local"
	local path_qf = Constant.defaults.base_path
	if isGlobal then
		titleMsg = "global"
		path_qf = Constant.defaults.global_qf_dir
	end

	if not Utils.checkJSONPath(path_qf) then
		local warn_message =
			string.format([[There is no saved QUICKFIX list at the '%s' path. Try creating one.]], titleMsg)
		Utils.warn(warn_message, "QF")
		return
	end

	Fzflua.files({
		cwd = path_qf,
		previewer = false,
		fzf_opts = { ["--header"] = [[^x:delete]] },
		cmd = "fd -d 1 -e json | cut -d. -f1",
		no_header_i = true,
		no_header = true,
		winopts = function()
			local win_height = math.ceil(Utils.get_option("lines") * 0.5 - 10)
			local win_width = math.ceil(Utils.get_option("columns") * 0.5 - 20)
			return {
				hls = { normal = "Normal" },
				border = "rounded",
				title = formatTitle(string.format("Load (%s) Quickfix items", titleMsg), ""),
				preview = { hidden = "hidden" },
				width = win_width,
				height = win_height,
				row = 0.50,
				col = 0.50,
				backdrop = 60,
			}
		end,
		actions = vim.tbl_extend(
			"keep",
			FzfMappings.editOrMergeQuickFix(opts, path_qf),
			FzfMappings.deleteItem(path_qf)
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
		winopts = {
			width = 0.30,
			height = 0.15,
			row = 0.50,
			col = 0.50,
			backdrop = 60,
			hls = { normal = "Normal" },
			title = formatTitle("QF-" .. prompt_prefix, ""),
			preview = { hidden = "hidden" },
		},

		actions = {
			["default"] = function(selected, _)
				if selected[1] then
					if isLoad then
						local checkGlobal = false
						if selected[1] == "global" then
							checkGlobal = true
						end
						M.load_items_qf(opts, checkGlobal)
					else
						local lists_qf = UtilsNote.get_current_list()

						Ui.input(function(inputMsg)
							vim.cmd("startinsert!")
							-- If `value` contains spaces, concat it them with underscore
							if inputMsg == "" then
								return
							end

							local title = inputMsg

							title = title:gsub("%s", "_")
							title = title:gsub("%.", "_")

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
							stat_fname_todo.qf.title = title

							local path_qf = Constant.defaults.base_path
							if selected[1] == "global" then
								path_qf = Constant.defaults.global_qf_dir
							end
							stat_fname_todo.cwd_root = path_qf

							UtilsNote.save_list_to_file(path_qf, stat_fname_todo, title)
						end, selected[1] .. " Save Quickfix")

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
		fzf_opts = { ["--header"] = [[^x:delete  A-x:delete-all]] },
		winopts = {
			width = 0.85,
			height = 0.80,
			row = 0.55,
			col = 0.55,
			title = formatTitle("QF-Marks", Visual.extmarks.qf_sigil),
			fullscreen = false,
			title_pos = "center",
			---@diagnostic disable-next-line: missing-fields
			preview = {
				layout = "horizontal",
				vertical = "up:55%", -- up|down:size
				horizontal = "right:45%", -- right|left:size
				border = "rounded",
			},
		},
	})
end

return M
