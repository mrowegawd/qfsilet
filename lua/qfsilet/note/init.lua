local fn = vim.fn
local cmd = vim.cmd

local Utils = require("qfsilet.utils")
local UtilsNote = require("qfsilet.note.utils")

local Path = require("qfsilet.path")
local Config = require("qfsilet.config").current_configs
local Constant = require("qfsilet.constant")
local Ui = require("qfsilet.ui")

local M = {}

Path.setup_global_path() -- setup global path for qf and note

local function setup_base_path()
	Path.setup_path()
	Path.create_dir(Constant.defaults.base_path)
end

local __custom_floating_todo = function(isGlobal)
	Path.create_file(Constant.defaults.note_path)

	Ui.popup(Constant.defaults.note_path, isGlobal, Constant.defaults.base_path)

	if Utils.isFile(Constant.defaults.note_path) then
		cmd("0r! cat " .. Constant.defaults.note_path)
		cmd("0") -- Go to top of document
	end

	-- Ensure the note path buffer are not listed
	UtilsNote.delete_buffer_by_name(Constant.defaults.note_path)
end

local __open_orgmode = function()
	local config = require("orgmode.config")
	local refile_path = config.org_default_notes_file
	if #refile_path == 0 then
		Utils.warn("refile_path is empty", "NOTE")
		return
	end

	local orgmode = Utils.check_wins({ "org" })
	if not orgmode.found then
		vim.cmd([[topleft 10split]])
		vim.cmd("e " .. refile_path)
		vim.api.nvim_set_option_value("winfixheight", true, { scope = "local", win = 0 })
		-- vim.api.nvim_set_option_value("winfixbuf", true, { scope = "local", win = 0 })
		return
	end

	UtilsNote.delete_buffer_by_name(refile_path)
end

local function todo(isGlobal, mode_todo)
	vim.validate({ isglobal = { isGlobal, "boolean", mode_todo = { mode_todo, "string" } } })
	setup_base_path()

	local is_default_note = false
	if mode_todo == "default" then
		is_default_note = true
	end

	if is_default_note then
		__custom_floating_todo(isGlobal)
	else
		__open_orgmode()
	end
end

local function saveqflist()
	setup_base_path()

	local lists_qf = UtilsNote.get_current_list()
	if #lists_qf == 0 then
		Utils.warn("QUICKFIX list is empty. Abort it..", "QF")
		return
	end

	require("qfsilet.fzf").sel_qf(Config)
end

local function loadqflist()
	require("qfsilet.fzf").sel_qf(Config, true)
end

-- Get todos if any local todo exists
-- function M.get_todo()
-- 	Path.init_constant_path()
-- 	if Utils.isFile(Constant.defaults.note_path) then
-- 		todo(false)
-- 	end
-- end

function M.todo_local()
	local mode_todo = Config.popup.todo.local_use
	todo(false, mode_todo)
end

function M.todo_global()
	local mode_todo = Config.popup.todo.global_use
	todo(true, mode_todo)
end

function M.saveqf_list()
	saveqflist()
end

function M.loadqf_list()
	loadqflist()
end

function M.todo_with_capture_link()
	fn.setreg("+", UtilsNote.capturelink(), "c")
	Utils.info("Link copied..", "Note")
end

function M.todo_goto_capture_link()
	UtilsNote.gotolink()
end

return M
