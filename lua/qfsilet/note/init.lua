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

local __get_note_path = function(is_org, isGlobal)
	isGlobal = isGlobal or false
	local refile_path

	if is_org then
		local config = require("orgmode.config")
		refile_path = config.org_default_notes_file
	else
		if isGlobal then
			Path.create_dir(Constant.defaults.global_note_dir)
			Path.create_file(Constant.defaults.global_note_dir .. "/note")
			refile_path = Constant.defaults.global_note_dir .. "/note"
		else
			Path.create_file(Constant.defaults.note_path)
			refile_path = Constant.defaults.note_path
		end
	end

	if refile_path then
		return refile_path
	end

	Utils.warn("__get_note_path: refile_path is empty", "NOTE")
end

local __open_floating = function(isGlobal)
	local note_path = __get_note_path(false, isGlobal)

	Ui.popup(note_path, isGlobal, Constant.defaults.global_note_dir)

	if Utils.isFile(note_path) then
		cmd("0r! cat " .. note_path)
		cmd("0") -- Go to top of document
		-- cmd(":startinsert") -- Go to top of document
	end

	-- Ensure the note path buffer are not listed
	UtilsNote.delete_buffer_by_name(note_path)
end

local __open = function(is_org)
	local note_path = __get_note_path(is_org)

	local orgmode = Utils.check_wins({ "org" })
	if not orgmode.found then
		vim.cmd([[topleft 10split]])
		vim.cmd("e " .. note_path)
		vim.api.nvim_set_option_value("winfixheight", true, { scope = "local", win = 0 })
		return
	end

	UtilsNote.delete_buffer_by_name(note_path)
end

local function todo(isGlobal, mode_todo, is_org)
	vim.validate({
		isGlobal = { isGlobal, "boolean" },
		mode_todo = { mode_todo, "string" },
		is_org = { is_org, "boolean" },
	})

	setup_base_path()

	if mode_todo == "orgmode" then
		__open(is_org)
	end

	if mode_todo == "default" then
		__open_floating(isGlobal)
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

function M.todo_org()
	local mode_todo = Config.popup.todo.global
	todo(false, mode_todo, true)
end

function M.todo_project()
	local mode_todo = Config.popup.todo.project
	todo(true, mode_todo, false)
end

function M.note_message()
	local mode_todo = Config.popup.todo.message
	todo(true, mode_todo, true)
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
