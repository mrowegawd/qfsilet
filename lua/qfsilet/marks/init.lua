local UtilsMark = require("qfsilet.marks.utils")
local Utils = require("qfsilet.utils")
local Config = require("qfsilet.config")
local Visual = require("qfsilet.marks.visual")
local Path = require("qfsilet.path")
local Constant = require("qfsilet.constant")
local M = {}

M.buffers = {}

local display_signs = true
local current_bookmark_idx = 0

local function exclude_buf(bufnr)
	local config = Config.current_configs

	local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
	if buftype == "prompt" or buftype == "nofile" then
		return false
	end

	if buftype ~= "" and buftype ~= "quickfix" then
		return false
	end

	local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
	if vim.tbl_contains(config.marks.excluded.filetypes, filetype) then
		return false
	end

	return true
end

local function register_mark(id, bufnr, line, col, is_force)
	vim.validate({
		id = { id, "number" },
		bufnr = { bufnr, "number" },
	})

	if not exclude_buf(bufnr) then
		return
	end

	is_force = is_force or false
	col = col or 1
	-- bufnr = bufnr or vim.api.nvim_get_current_buf()

	local filename = vim.api.nvim_buf_get_name(0)
	local buffer = M.buffers.mark

	if not buffer then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if not is_force and (line_count + 1) > line then
		table.insert(buffer.lists, { line = line, col = col, filename = filename, id = id })
	end

	if display_signs then
		M.add_sign(id, bufnr, line)
	end
end

function M.get_current_status_buf()
	local buffer = M.buffers.mark
	if buffer then
		return #buffer.lists
	end
	return 0
end

function M.delete_mark(bufnr, line, clear)
	clear = clear or UtilsMark.option_nil(clear, true)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local buffer = M.buffers.mark

	local filename = vim.api.nvim_buf_get_name(0)
	for i, x in pairs(buffer.lists) do
		if x.line == line and x.filename == filename then
			buffer.lists[i] = nil
			Visual.remove_sign(bufnr, x.id)
		end
	end
end

function M.delete_buf_marks(clear)
	local bufnr = vim.api.nvim_get_current_buf()
	clear = UtilsMark.option_nil(clear, true)
	local buffer = M.buffers.mark

	for _, x in pairs(buffer.lists) do
		local bname = vim.api.nvim_buf_get_name(bufnr)
		if string.match(x.filename, bname) then
			M.delete_mark(bufnr, x.line, clear)
		end
	end

	-- Visual.remove_buf_signs(bufnr)
	if clear then
		vim.cmd("delmarks!")
	end
end

function M.delete_line_marks_builtin()
	-- Delete current marks builtin
	local marks = {}
	for i = string.byte("a"), string.byte("z") do
		local mark = string.char(i)
		local mark_line = vim.fn.line("'" .. mark)
		if mark_line == vim.fn.line(".") then
			table.insert(marks, mark)
		end
	end

	if #marks > 0 then
		vim.cmd("delmarks " .. table.concat(marks, ""))
	end
end

function M.delete_line_marks()
	local bufnr = vim.api.nvim_get_current_buf()
	local pos = vim.api.nvim_win_get_cursor(0)
	M.delete_mark(bufnr, pos[1])
	M.delete_line_marks_builtin()
end

function M.delete()
	M.delete_line_marks()
end

local function jump_to(mark_lists, opts)
	if not opts then
		Utils.info("No marks available", "Marks")
		return
	end

	for _, x in pairs(mark_lists) do
		if x.filename == opts.filename and x.line == opts.line then
			local found_ls = Utils.find_win_ls({ filename = x.filename })
			if found_ls.found then
				vim.cmd("buffer " .. x.filename)
			else
				vim.cmd("e " .. x.filename)
			end
			vim.api.nvim_win_set_cursor(0, { x.line, x.col })
			vim.cmd("norm! zvzz")
		end
	end
end

function M.next_mark()
	local buffer = M.buffers.mark

	if not buffer then
		return
	end

	local next_idx = current_bookmark_idx + 1

	if next_idx > #buffer.lists then
		next_idx = 1
	end

	local next_elem = function()
		return buffer.lists[next_idx]
	end

	current_bookmark_idx = next_idx

	local mark_lists = buffer.lists
	jump_to(mark_lists, next_elem())
end

function M.prev_mark()
	local buffer = M.buffers.mark
	if not buffer then
		return
	end

	local prev_idx = current_bookmark_idx - 1

	if prev_idx == 0 or prev_idx < 0 then
		prev_idx = #buffer.lists
	end

	local prev_elem = function()
		return buffer.lists[prev_idx]
	end

	current_bookmark_idx = prev_idx

	local mark_lists = buffer.lists
	jump_to(mark_lists, prev_elem())
end

function M.fzf_marks()
	local buffer = M.buffers.mark
	if not buffer then
		return
	end

	require("qfsilet.fzf").grep_marks(buffer)
end

function M.place_next_mark(line, col)
	local bufnr = vim.api.nvim_get_current_buf()
	local root = Utils.root_path_basename()

	if M.buffers.root == nil then
		M.buffers.root = root
		M.buffers.mark = {
			lists = {},
		}
	end

	local id = tonumber(line .. bufnr)
	register_mark(id, bufnr, line, col)
end

function M.toggle_mark_cursor()
	local pos = vim.api.nvim_win_get_cursor(0)

	local config = Config.current_configs

	if UtilsMark.is_current_line_got_mark(M.buffers, pos[1]) then
		M.delete_line_marks()
		Utils.info(config.extmarks.qf_crosssign .. " Mark Removed", "Marks")
	else
		M.place_next_mark(pos[1], pos[2])
		Utils.info(config.extmarks.qf_sigil .. " Mark Added", "Marks")
	end
end

function M.refresh_deforce(force)
	force = force or false
	local root = Utils.root_path_basename()
	local buffer = M.buffers

	if buffer.root == nil then
		M.buffers.root = root
		M.buffers.mark = {
			lists = {},
		}
	end

	local separator = function()
		return "/"
	end

	local function remove_trailing(path)
		local p, _ = path:gsub(separator() .. "$", "")
		return p
	end

	local function basename(path)
		path = remove_trailing(path)
		local i = path:match("^.*()" .. separator())
		if not i then
			return path
		end
		return path:sub(i + 1, #path)
	end

	if #buffer.mark.lists > 0 then
		for _, x in ipairs(buffer.mark.lists) do
			local bufnr = vim.api.nvim_get_current_buf()
			local winnr_fn = vim.api.nvim_buf_get_name(bufnr)

			local basename_winnr_fn = basename(winnr_fn):gsub("([%-%^%$%(%)%.%[%]%+%-%?%*])", "%%%1")
			if winnr_fn ~= "" and basename(x.filename):match(basename_winnr_fn) then
				register_mark(tonumber(x.id), bufnr, x.line, x.col, force)
			end
		end
	end
end

function M.add_sign(id, bufnr, line)
	local buffer = M.buffers.mark
	if not buffer then
		return
	end

	if not exclude_buf(bufnr) then
		return
	end

	local text = "abc"
	local config = Config.current_configs
	Visual.insert_signs(id, bufnr, line, text, config)
end

function M.refresh(force_reregister)
	-- if M.excluded_fts[vim.bo.ft] or M.excluded_bts[vim.bo.bt] then
	-- 	return
	-- end

	-- Utils.info("Yay force to refres them")
	force_reregister = force_reregister or false
	M.refresh_deforce(force_reregister)
end

local function __save_marks()
	local buffer = M.buffers.mark
	if not buffer then
		return
	end

	Path.setup_path()
	local fn_name = Constant.defaults.base_path .. "/mark.lua"

	if #buffer.lists > 0 then
		if not Utils.isDir(Constant.defaults.base_path) then
			Utils.create_dir(Constant.defaults.base_path)
		end
		Utils.create_file(fn_name)
		Utils.save_table_to_file(buffer, fn_name)
	else
		if Utils.isFile(fn_name) then
			Utils.rmdir(fn_name)
		end
	end
end

local function __load_marks()
	Path.setup_path()
	local fn_name = Constant.defaults.base_path .. "/mark.lua"

	if Utils.isDir(Constant.defaults.base_path) then
		if Utils.isFile(fn_name) then
			M.buffers.mark = dofile(fn_name)
		end
	end
end

local is_unset_augroup = false
local function unset_augroup(name)
	vim.validate({ name = { name, "string" } })
	pcall(vim.api.nvim_del_augroup_by_name, name)
end

local function setup_commands()
	local function augroup(name)
		return vim.api.nvim_create_augroup("QFSilet" .. name, { clear = true })
	end

	vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
		group = augroup("RefreshMark"),
		callback = function()
			if is_unset_augroup then
				unset_augroup("QFSiletLoadMark")
				is_unset_augroup = false
			end
			-- Utils.info("Yay refresh them")
			M.refresh(true)
		end,
	})

	vim.api.nvim_create_autocmd({ "ExitPre", "BufWritePost" }, {
		group = augroup("SaveMark"),
		callback = function()
			__save_marks()
		end,
	})

	vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
		group = augroup("LoadMark"),
		once = true,
		callback = function()
			-- Utils.info("Yay load them")
			__load_marks()
			is_unset_augroup = true
		end,
	})
end

function M.show_config()
	vim.print(vim.inspect(M.buffers))
	-- vim.print("current bookmark idx: " .. current_bookmark_idx)
	-- print("======================================")
	-- print("======================================")
	-- print("======================================")
	-- print("======================================")
end

function M.setup(timer_setup)
	setup_commands()

	-- how often (in ms) to redraw signs/recompute mark positions.
	-- higher values will have better performance but may cause visual lag,
	-- while lower values may cause performance penalties. default 150.
	local refresh_interval = UtilsMark.option_nil(timer_setup, 150)

	local timer = vim.loop.new_timer()
	timer:start(
		0,
		refresh_interval,
		vim.schedule_wrap(function()
			M.refresh(true)
		end)
	)
end

function M.clear_all_marks()
	local buffer = M.buffers.mark

	for _, x in pairs(buffer.lists) do
		for _, b in pairs(vim.api.nvim_list_bufs()) do
			local bname = vim.api.nvim_buf_get_name(b)
			if string.match(x.filename, bname) then
				Visual.remove_sign(b, x.id)
			end
		end
	end

	M.buffers = {}
end

return M
