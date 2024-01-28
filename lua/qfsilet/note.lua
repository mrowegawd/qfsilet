local fn, fmt, api, cmd = vim.fn, string.format, vim.api, vim.cmd

local Util = require("qfsilet.utils")
local Ui = require("qfsilet.ui")
local Path = require("qfsilet.path")
local Config = require("qfsilet.config").current_configs
local Constant = require("qfsilet.constant")

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

local function todo(isGlobal)
	isGlobal = isGlobal or false

	-- Set path init first before doing something..
	if isGlobal then
		Path.init_global()
	else
		Path.init_local()
	end

	if not Util.is_file(Constant.defaults.note_path) then
		Util.create_file(Constant.defaults.note_path)
	end

	Ui.popup(Constant.defaults.note_path, isGlobal, Constant.defaults.base_path)

	if Util.is_file(Constant.defaults.note_path) then
		cmd("0r! cat " .. Constant.defaults.note_path)
		cmd("0") -- Go to top of document
	end
end

local function __save_list_to_file(base_path, tbl, title, is_notify)
	title = title or fn.getqflist({ title = 0 })

	local fname_path = base_path .. "/" .. title .. ".json"
	local success_msg = "Success saving"

	if is_notify then
		if Util.is_file(fname_path) then
			Ui.input(function(input)
				if input ~= nil and input == "y" or #input < 1 then
					Util.write_to_file(tbl, fname_path)
				else
					success_msg = "Cancel save"
				end

				Util.info(fmt("%s file %s.json", success_msg, title))
			end, fmt("File %s exists, rewrite it? [y/n]", title))
		else
			Util.write_to_file(tbl, fname_path)
		end
	else
		Util.write_to_file(tbl, fname_path)
	end
end
local function __get_current_list(items, isGlobal)
	local cur_list

	if isGlobal then
		cur_list = fn.getloclist(0)
	else
		cur_list = fn.getqflist()
	end

	if items ~= nil and #items > 0 then
		cur_list = vim.list_extend(cur_list, items)
	end

	return cur_list
end

local function __capturelink()
	-- return string.format("[[file:%s +%s]]", Util.current_file_path(), vim.api.nvim_win_get_cursor(0)[1])
	return string.format(
		"[[File:%s+%s:%s]]",
		Util.current_file_path(),
		vim.api.nvim_win_get_cursor(0)[1],
		vim.api.nvim_win_get_cursor(0)[2]
	)
end

local function __gotolink()
	local str_file = vim.fn.expand("<cWORD>")

	if not str_file:match("File:") then
		return
	end

	local filename = str_file:match("File.(.*)+")
	local lnum_lcol = vim.fn.split(string.gsub(str_file:match("File.*+(.*)]"), "]", ""), ":")
	local row = tonumber(lnum_lcol[1])
	local col = tonumber(lnum_lcol[2])

	vim.cmd("e " .. filename)
	vim.api.nvim_win_set_cursor(0, { row, col })
end

local function saveqflist(isGlobal)
	isGlobal = isGlobal or false

	-- Set path init first before doing something..
	if isGlobal then
		Path.init_global()
	else
		Path.init_local()
	end

	local input_msg = "Projet"

	if isGlobal then
		input_msg = "Global"
	end

	local lists_qf = __get_current_list()
	if #lists_qf == 0 then
		Util.warn("Quickfix is empty..", "QFSilet")
		return
	end

	Ui.input(function(title)
		-- If `value` contains spaces, concat it them with underscore
		if title == "" then
			return
		end

		title = title:gsub("%s", "_")
		title = title:gsub("%.", "_")

		for _, tbl in ipairs(lists_qf) do
			local jbl = {
				filename = api.nvim_buf_get_name(tbl.bufnr),
				lnum = tbl.lnum,
				col = tbl.col,
				text = tbl.text,
				type = tbl.type,
			}

			table.insert(stat_fname_todo.qf.items, jbl)
		end

		stat_fname_todo.qf.idx = "$"
		stat_fname_todo.qf.title = title

		stat_fname_todo.cwd_root = Constant.defaults.base_path

		__save_list_to_file(Constant.defaults.base_path, stat_fname_todo, title, true)
	end, input_msg .. " Save")

	for _, fname in pairs(stat_fname_todo.deleted) do
		table.insert(stat_fname_todo.saved, fname)
	end

	stat_fname_todo.deleted = {}
end
local function loadqflist(isGlobal)
	isGlobal = isGlobal or false

	if isGlobal then
		Path.init_global()
	else
		Path.init_local()
	end

	require("qfsilet.fzf").load(Config, isGlobal)
end

function M.todo_local()
	todo()
end
function M.todo_global()
	todo(true)
end

function M.saveqflist_local()
	saveqflist()
end
function M.saveqflist_global()
	saveqflist(true)
end

function M.loadqflist_local()
	loadqflist()
end
function M.loadqflist_global()
	loadqflist(true)
end

function M.todo_with_capture_link()
	Util.info("Copied to system clipboard", "Link capture")
	vim.fn.setreg("+", __capturelink(), "c")
	todo()
end

function M.todo_goto_capture_link()
	__gotolink()
end

return M
