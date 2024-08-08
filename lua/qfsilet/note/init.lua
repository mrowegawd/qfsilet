local fn = vim.fn
local cmd = vim.cmd

local Utils = require("qfsilet.utils")
local UtilsNote = require("qfsilet.note.utils")

local Path = require("qfsilet.path")
local Config = require("qfsilet.config").current_configs
local Constant = require("qfsilet.constant")
local Ui = require("qfsilet.ui")

local M = {}

local function todo(isGlobal)
	isGlobal = isGlobal or false

	Path.setup_path(isGlobal)
	if not Utils.isDir(Constant.defaults.base_path) then
		Utils.create_dir(Constant.defaults.base_path)
	end

	Path.create_file(Constant.defaults.note_path)

	Ui.popup(Constant.defaults.note_path, isGlobal, Constant.defaults.base_path)

	if Utils.isFile(Constant.defaults.note_path) then
		cmd("0r! cat " .. Constant.defaults.note_path)
		cmd("0") -- Go to top of document
	end
end

local function saveqflist(isGlobal)
	isGlobal = isGlobal or false

	local lists_qf = UtilsNote.get_current_list()
	if #lists_qf == 0 then
		Utils.warn("Current quickfix list is empty\nWe abort it..", "QFSilet")
		return
	end

	require("qfsilet.fzf").sel_qf(Config)
end

local function loadqflist(isGlobal)
	isGlobal = isGlobal or false

	require("qfsilet.fzf").sel_qf(Config, true)
end

-- Get todos if any local todo exists
function M.get_todo()
	Path.init_constant_path(false)
	if Utils.isFile(Constant.defaults.note_path) then
		todo(false)
	end
end

function M.todo_local()
	todo(false)
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
	Utils.info("Copied to system clipboard", "Link capture")
	fn.setreg("+", UtilsNote.capturelink(), "c")
	todo()
end

function M.todo_goto_capture_link()
	UtilsNote.gotolink()
end

return M
