local fn = vim.fn
local cmd = vim.cmd

local QfUtil = require("qfsilet.utils")
local Util = require("qfsilet.note.util")

local Path = require("qfsilet.path")
local Config = require("qfsilet.config").current_configs
local Constant = require("qfsilet.constant")
local Ui = require("qfsilet.ui")

local M = {}

Path.init_global()
Path.init_local()

local function todo(isGlobal)
	isGlobal = isGlobal or false

	-- Set path init first before doing something..
	if isGlobal then
		Path.init_global()
	else
		Path.init_local()
	end

	if not QfUtil.isFile(Constant.defaults.note_path) then
		QfUtil.create_file(Constant.defaults.note_path)
	end

	Ui.popup(Constant.defaults.note_path, isGlobal, Constant.defaults.base_path)

	if QfUtil.isFile(Constant.defaults.note_path) then
		-- cmd("set foldtext=")

		-- vim.schedule(function()
		cmd("0r! cat " .. Constant.defaults.note_path)
		-- cmd(":edit " .. Constant.defaults.note_path)
		cmd("0") -- Go to top of document
		-- end)
	end
end

local function saveqflist(isGlobal)
	isGlobal = isGlobal or false

	local lists_qf = Util.get_current_list()
	if #lists_qf == 0 then
		QfUtil.warn("Current quickfix list is empty\nWe abort it..", "QFSilet")
		return
	end

	require("qfsilet.fzf").sel_qf(Config)

	-- Set path init first before doing something..
	-- if isGlobal then
	-- 	Path.init_global()
	-- else
	-- 	Path.init_local()
	-- end

	-- local input_msg = "Projet"
	--
	-- if isGlobal then
	-- 	input_msg = "Global"
	-- end

	-- Ui.input(function(title)
	-- 	-- If `value` contains spaces, concat it them with underscore
	-- 	if title == "" then
	-- 		return
	-- 	end
	--
	-- 	title = title:gsub("%s", "_")
	-- 	title = title:gsub("%.", "_")
	--
	-- 	for _, tbl in ipairs(lists_qf) do
	-- 		local jbl = {
	-- 			filename = api.nvim_buf_get_name(tbl.bufnr),
	-- 			lnum = tbl.lnum,
	-- 			col = tbl.col,
	-- 			text = tbl.text,
	-- 			type = tbl.type,
	-- 		}
	--
	-- 		table.insert(stat_fname_todo.qf.items, jbl)
	-- 	end
	--
	-- 	stat_fname_todo.qf.idx = "$"
	-- 	stat_fname_todo.qf.title = title
	--
	-- 	stat_fname_todo.cwd_root = Constant.defaults.base_path
	--
	-- 	__save_list_to_file(Constant.defaults.base_path, stat_fname_todo, title, true)
	-- end, input_msg .. " Save")
	--
	-- for _, fname in pairs(stat_fname_todo.deleted) do
	-- 	table.insert(stat_fname_todo.saved, fname)
	-- end

	-- stat_fname_todo.deleted = {}
end

local function loadqflist(isGlobal)
	isGlobal = isGlobal or false

	require("qfsilet.fzf").sel_qf(Config, true)
end

function M.todo_local()
	todo()
end

function M.todo_global()
	todo(true)
end

function M.saveqf_list()
	saveqflist()
end

function M.loadqf_list()
	loadqflist()
end

function M.todo_with_capture_link()
	QfUtil.info("Copied to system clipboard", "Link capture")
	fn.setreg("+", Util.capturelink(), "c")
	todo()
end

function M.todo_goto_capture_link()
	Util.gotolink()
end

return M
