local Utils = require("qfsilet.utils")
local Visual = require("qfsilet.marks.visual")
local UtilsFzf = require("qfsilet.fzf.utils")
local fzf_ok, Fzflua = pcall(require, "fzf-lua")
local UtilsNote = require("qfsilet.note.utils")

if not fzf_ok then
	Utils.warn("fzf-lua diperlukan sebagai dependensi")
	return
end

local FzfMappings = require("qfsilet.fzf.mappings")
local Constant = require("qfsilet.constant")

local M = {}

local function h(name)
	return vim.api.nvim_get_hl(0, { name = name })
end

-- set hl-groups
vim.api.nvim_set_hl(0, "QFSiletPreviewTitle", { fg = h("Normal").bg, bg = h("Normal").fg, italic = true, bold = true })
vim.api.nvim_set_hl(0, "QFSiletNormal", { fg = h("Normal").bg, bg = h("Normal").fg, italic = true, bold = true })

local function title_format(str, icon, icon_hl)
	return {
		{ " ", "QFSiletNormal" },
		{ (icon and icon .. " " or ""), icon_hl or "QFSiletPreviewTitle" },
		{ str, "QFSiletNormal" },
		{ " ", "QFSiletNormal" },
	}
end

local opts_fzf = {
	winopts = {
		width = 0.50,
		height = 0.50,
		row = 0.50,
		col = 0.50,
		backdrop = 100,
		preview = { hidden = true },
	},
}

function M.load_items_qf(opts, is_global, is_loc)
	is_loc = is_loc or false

	local title_msg = "local"
	local path_qf = Constant.defaults.base_path

	if is_global then
		title_msg = "global"
		path_qf = Constant.defaults.global_qf_dir
	end

	title_msg = Utils.get_uppercase_first_letter(title_msg)

	if not Utils.is_json_path_exists(path_qf) then
		local warn_message = string.format([[No file found at '%s'. Please create one]], title_msg)
		Utils.warn(warn_message, "QF")
		return
	end

	local title_prompt = title_format(string.format("Load %s", title_msg), "")

	Fzflua.files(vim.tbl_deep_extend("keep", {
		cwd = path_qf,
		no_header = true,
		no_header_i = true, -- hide interactive header?
		fzf_opts = { ["--header"] = [[^x:delete  ^r:rename]] },
		cmd = "fd -d 1 -e json --exec stat --format '%Z %n' {} | sort -nr | cut -d' ' -f2- | sed 's/.json$//' | sed 's/\\.\\///'",
		winopts = { title = title_prompt },
		actions = vim.tbl_extend("keep", FzfMappings.edit_or_merge_qf(opts, path_qf), FzfMappings.delete_item(path_qf)),
	}, opts_fzf))
end

function M.sel_qf(opts, is_load)
	is_load = is_load or false

	local prompt_prefix = "Save"
	if is_load then
		prompt_prefix = "Load"
	end

	local ft_before_popup = vim.bo.filetype

	local is_loc = Utils.is_loclist()

	local qf_items = UtilsNote.get_current_list({}, is_loc) or {}
	local qf_title = UtilsNote.get_current_list_title(is_loc) or ""

	if prompt_prefix == "Save" and ft_before_popup ~= "qf" then
		Utils.warn("Your are not inside qf window")
		return
	end

	local selection_data = { "global", "local" }

	local title_prompt = title_format(prompt_prefix .. (is_loc and " Loclist" or " Quickfix"), "")

	Fzflua.fzf_exec(
		selection_data,
		vim.tbl_deep_extend("keep", {
			prompt = "  ",
			winopts = {
				title = title_prompt,
				width = 0.30,
				height = 0.20,
			},
			actions = {
				["default"] = FzfMappings.default_sel_qf(opts, is_load, qf_items, qf_title, is_loc),
			},
		}, opts_fzf)
	)
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
		entry_str = UtilsFzf.strip_string(entry_str)

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

	FzfLua.fzf_exec(
		marks,
		vim.tbl_deep_extend("keep", {
			previewer = {
				_ctor = function()
					return Markpreviewer
				end,
			},
			winopts = {
				title = title_format("QF-Marks", Visual.extmarks.qf_sigil),
				width = 0.85,
				height = 0.80,
				preview = {
					hidden = false,
					layout = "horizontal",
					horizontal = "right:60%",
				},
			},
			fzf_opts = { ["--header"] = [[^x:delete  a-x:delete-all]] },
			actions = FzfMappings.mark_defaults(buffer),
		}, opts_fzf)
	)
end

return M
