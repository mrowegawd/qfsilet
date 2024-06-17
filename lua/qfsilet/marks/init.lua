local UtilsMark = require("qfsilet.marks.utils")
local Utils = require("qfsilet.utils")
local Config = require("qfsilet.config")
local Visual = require("qfsilet.marks.visual")
local Path = require("qfsilet.path")
local Constant = require("qfsilet.constant")
local M = {}

M.buffers = {}

local display_signs = true

local function register_mark(mark, line, col, bufnr)
	col = col or 1
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(0)
	local buffer = M.buffers[bufnr]

	if not buffer then
		return
	end

	if buffer.placed_marks[mark] then
		-- mark already exists: remove it first
		M.delete_mark(mark, false)
	end

	if buffer.marks_by_line[line] then
		table.insert(buffer.marks_by_line[line], mark)
	else
		buffer.marks_by_line[line] = { mark }
	end
	buffer.placed_marks[mark] = { line = line, col = col, id = -1, filename = filename, bufnr = bufnr }

	if display_signs then
		local id = mark:byte() * 100
		buffer.placed_marks[mark].id = id
		M.add_sign(bufnr, mark, line, id)
	end

	if not UtilsMark.is_lower(mark) or mark:byte() > buffer.lowest_available_mark:byte() then
		return
	end

	while buffer.placed_marks[mark] do
		mark = string.char(mark:byte() + 1)
	end
	buffer.lowest_available_mark = mark
end

function M.get_current_status_buf()
	local bufnr = vim.api.nvim_get_current_buf()
	local buffer = M.buffers[bufnr]
	if buffer then
		return UtilsMark.tablelength(buffer.placed_marks)
	end
	return 0
end

function M.delete_mark(mark, clear)
	local conf = Config.current_configs
	clear = UtilsMark.option_nil(clear, true)
	local bufnr = vim.api.nvim_get_current_buf()
	local buffer = M.buffers[bufnr]

	if (not buffer) or not buffer.placed_marks[mark] then
		return
	end

	if buffer.placed_marks[mark].id ~= -1 then
		Visual.remove_sign(bufnr, buffer.placed_marks[mark].id)
	end

	local line = buffer.placed_marks[mark].line
	for key, tmp_mark in pairs(buffer.marks_by_line[line]) do
		if tmp_mark == mark then
			buffer.marks_by_line[line][key] = nil
			break
		end
	end

	if vim.tbl_isempty(buffer.marks_by_line[line]) then
		buffer.marks_by_line[line] = nil
	end

	buffer.placed_marks[mark] = nil

	if clear then
		vim.cmd("delmark " .. mark)
	end

	if conf.marks.force_write_shada then
		vim.cmd("wshada!")
	end

	-- only adjust lowest_available_mark if it is lowercase
	if not UtilsMark.is_lower(mark) then
		return
	end

	if mark:byte() < buffer.lowest_available_mark:byte() then
		buffer.lowest_available_mark = mark
	end
end

function M.delete_buf_marks(clear)
	clear = UtilsMark.option_nil(clear, true)
	local bufnr = vim.api.nvim_get_current_buf()
	M.buffers[bufnr] = {
		placed_marks = {},
		marks_by_line = {},
		lowest_available_mark = "a",
	}

	-- UtilsMark.remove_buf_signs(bufnr)
	Visual.remove_buf_signs(bufnr)
	if clear then
		vim.cmd("delmarks!")
	end

	vim.fn.setqflist({})

	vim.cmd.cclose()

	-- if require("qfsilet.trouble").open then
	-- 	require("qfsilet.trouble").open = false
	-- 	vim.fn.setloclist(vim.fn.win_getid(), {})
	-- 	vim.cmd([[TroubleToggle]])
	-- end
end

function M.next_mark()
	local bufnr = vim.api.nvim_get_current_buf()

	if not M.buffers[bufnr] then
		return
	end

	local line = vim.api.nvim_win_get_cursor(0)[1]
	local marks = {}

	-- avoid adding twice to `marks`
	local function check_duplicate_line(tbl)
		for _, x in pairs(marks) do
			if x.line == tbl.line then
				return false
			end
		end
		return true
	end

	for _, dat in pairs(M.buffers) do
		if UtilsMark.tablelength(dat.placed_marks) > 0 then
			for _, table_mark in pairs(dat.placed_marks) do
				if check_duplicate_line(table_mark) then
					marks[#marks + 1] = table_mark
				end
			end
		end
	end

	if vim.tbl_isempty(marks) then
		return
	end

	local function comparator(x, y, _)
		return x.line > y.line
	end

	local next = UtilsMark.search(marks, { line = line }, { line = math.huge }, comparator, true)

	if next then
		local found_ls = Utils.find_win_ls(next.bufnr)

		if next.bufnr == bufnr then
			vim.api.nvim_win_set_cursor(0, { next.line, next.col })
			vim.cmd("normal! zz")
		else
			if found_ls.found then
				vim.api.nvim_set_current_win(found_ls.winid)
			else
				local bufname = vim.api.nvim_buf_get_name(next.bufnr)
				vim.cmd("e " .. bufname)
			end
			vim.api.nvim_win_set_cursor(0, { next.line, next.col })
			vim.cmd("normal! zz")
		end
	end
end

function M.prev_mark()
	local bufnr = vim.api.nvim_get_current_buf()

	if not M.buffers[bufnr] then
		return
	end

	local line = vim.api.nvim_win_get_cursor(0)[1]
	local marks = {}

	local function check_duplicate_line(tbl)
		for _, x in pairs(marks) do
			if x.line == tbl.line then
				return false
			end
		end
		return true
	end

	for _, dat in pairs(M.buffers) do
		if UtilsMark.tablelength(dat.placed_marks) > 0 then
			for _, table_mark in pairs(dat.placed_marks) do
				if check_duplicate_line(table_mark) then
					marks[#marks + 1] = table_mark
				end
			end
		end
	end

	-- for mark, data in pairs(M.buffers[bufnr].placed_marks) do
	-- 	if UtilsMark.is_letter(mark) then
	-- 		marks[mark] = data
	-- 	end
	-- end

	if vim.tbl_isempty(marks) then
		return
	end

	local function comparator(x, y, _)
		return x.line < y.line
	end

	local prev = UtilsMark.search(marks, { line = line }, { line = -1 }, comparator, true)

	if prev then
		local found_ls = Utils.find_win_ls(prev.bufnr)

		if prev.bufnr == bufnr then
			vim.api.nvim_win_set_cursor(0, { prev.line, prev.col })
			vim.cmd("normal! zz")
		else
			if found_ls.found then
				vim.api.nvim_set_current_win(found_ls.winid)
			else
				local bufname = vim.api.nvim_buf_get_name(prev.bufnr)
				vim.cmd("e " .. bufname)
			end
			vim.api.nvim_win_set_cursor(0, { prev.line, prev.col })
			vim.cmd("normal! zz")
		end
	end
end

function M.delete_line_marks()
	local bufnr = vim.api.nvim_get_current_buf()
	local pos = vim.api.nvim_win_get_cursor(0)

	if not M.buffers[bufnr].marks_by_line[pos[1]] then
		return
	end

	local copy = vim.tbl_values(M.buffers[bufnr].marks_by_line[pos[1]])
	for _, mark in pairs(copy) do
		M.delete_mark(mark)
	end
end

function M.delete()
	local err, input = pcall(function()
		return string.char(vim.fn.getchar())
	end)
	if not err then
		return
	end

	if UtilsMark.is_valid_mark(input) then
		M.delete_mark(input)
		return
	end
end

function M.fzf_marks()
	local buffer = M.buffers
	if not buffer then
		return
	end

	require("qfsilet.fzf").grep_marks(buffer)
end

function M.marks_send_to_ll(col, bufnr)
	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
	col = col or 1
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local buffer = M.buffers[bufnr]

	if not buffer then
		return
	end

	if UtilsMark.tablelength(buffer.placed_marks) > 0 then
		require("qfsilet.trouble").qfmarks(buffer, path)
	end
end

function M.place_next_mark(line, col)
	local bufnr = vim.api.nvim_get_current_buf()
	if not M.buffers[bufnr] then
		M.buffers[bufnr] = {
			placed_marks = {},
			marks_by_line = {},
			lowest_available_mark = "a",
		}
	end

	local mark = M.buffers[bufnr].lowest_available_mark
	register_mark(mark, line, col, bufnr)
	vim.cmd("normal! m" .. mark)
end

function M.toggle_mark_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local pos = vim.api.nvim_win_get_cursor(0)

	if M.buffers[bufnr].marks_by_line[pos[1]] then
		M.delete_line_marks()
	else
		M.place_next_mark(pos[1], pos[2])
	end
end

function M.refresh_deforce(bufnr, force)
	force = force or false
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if not M.buffers[bufnr] then
		M.buffers[bufnr] = {
			placed_marks = {},
			marks_by_line = {},
			lowest_available_mark = "a",
		}
	end

	-- first, remove all marks that were deleted
	for mark, _ in pairs(M.buffers[bufnr].placed_marks) do
		if vim.api.nvim_buf_get_mark(bufnr, mark)[1] == 0 then
			M.delete_mark(mark, false)
		end
	end

	local mark
	local pos
	local cached_mark

	-- uppercase marks
	for _, data in ipairs(vim.fn.getmarklist()) do
		mark = data.mark:sub(2, 3)
		pos = data.pos
		cached_mark = M.buffers[bufnr].placed_marks[mark]

		if
			UtilsMark.is_upper(mark)
			and pos[1] == bufnr
			and (force or not cached_mark or pos[2] ~= cached_mark.line)
		then
			register_mark(mark, pos[2], pos[3], bufnr)
		end
	end

	-- lowercase
	for _, data in ipairs(vim.fn.getmarklist("%")) do
		mark = data.mark:sub(2, 3)
		pos = data.pos
		cached_mark = M.buffers[bufnr].placed_marks[mark]

		if UtilsMark.is_lower(mark) and (force or not cached_mark or pos[2] ~= cached_mark.line) then
			register_mark(mark, pos[2], pos[3], bufnr)
		end
	end

	-- builtin marks
	-- for _, char in pairs(M.buffers[bufnr].opt.builtin_marks) do
	-- 	pos = vim.fn.getpos("'" .. char)
	-- 	cached_mark = M.buffers[bufnr].placed_marks[char]
	-- 	-- check:
	-- 	-- mark located in current buffer? (0-9 marks return absolute bufnr instead of 0)
	-- 	-- valid (lnum != 0)
	-- 	-- force is true, or first time seeing mark, or mark line position has changed
	-- 	if
	-- 		(pos[1] == 0 or pos[1] == bufnr)
	-- 		and pos[2] ~= 0
	-- 		and (force or not cached_mark or pos[2] ~= cached_mark.line)
	-- 	then
	-- 		register_mark(char, pos[2], pos[3], bufnr)
	-- 	end
	-- end
end

function M.add_sign(bufnr, text, line, id)
	local conf = Config.current_configs
	if #conf.marks.excluded.filetypes > 0 and vim.tbl_contains(conf.marks.excluded.filetypes, vim.bo[0].filetype) then
		return
	end
	if vim.bo.filetype == "" and (vim.bo.buftype == "terminal" or vim.bo.filetype == "toggleterm") then
		return
	end

	local buffer = M.buffers[bufnr]

	if not buffer then
		return
	end

	Visual.insert_signs(bufnr, text, line, id)
end

function M.refresh(force_reregister)
	-- if M.excluded_fts[vim.bo.ft] or M.excluded_bts[vim.bo.bt] then
	-- 	return
	-- end

	force_reregister = force_reregister or false
	M.refresh_deforce(nil, force_reregister)
	-- M.bookmark_state:refresh()
end

local function __save_marks()
	local buffer = M.buffers
	if not buffer then
		return
	end

	Path.setup_path()

	if Utils.isDir(Constant.defaults.base_path) then
		local fn_name = Constant.defaults.base_path .. "/mark.lua"
		Utils.save_table_to_file(buffer, fn_name)
	end
end

local function __load_marks()
	Path.setup_path()
	local fn_name = Constant.defaults.base_path .. "/mark.lua"
	if Utils.isDir(Constant.defaults.base_path) then
		if Utils.isFile(fn_name) then
			M.buffers = dofile(fn_name)
		end
	end
end

local function setup_commands()
	-- vim.cmd([[augroup Qfsilet_marks_autocmds
	--    autocmd!
	--    autocmd BufReadPost,InsertLeave * lua require'qfsilet.marks'.refresh(true)
	--    " autocmd BufDelete * lua require'qfsilet.marks'._on_delete()
	--  augroup end]])

	local function augroup(name)
		return vim.api.nvim_create_augroup("QFSiletMarks" .. name, { clear = true })
	end

	-- Check if we need to reload the file when it changed
	vim.api.nvim_create_autocmd({ "BufReadPost", "FocusGained", "BufWritePost" }, {
		group = augroup("Refresh"),
		callback = function()
			require("qfsilet.marks").refresh(true)
		end,
	})

	-- vim.api.nvim_create_autocmd({ "VimLeave" }, {
	-- 	group = augroup("SaveMark"),
	-- 	callback = function()
	-- 		__save_marks()
	-- 	end,
	-- })
	--
	-- vim.api.nvim_create_autocmd({ "VimEnter" }, {
	-- 	group = augroup("LoadMark"),
	-- 	callback = function()
	-- 		__load_marks()
	-- 	end,
	-- })
end

function M.show_config()
	vim.print(vim.inspect(M.buffers))
	-- print("======================================")
	-- print("======================================")
	-- print("======================================")
	-- print("======================================")
	-- __save_marks()
	--
	-- __load_marks()
end

function M.setup(timer_setup)
	setup_commands()

	-- local bufnr = vim.api.nvim_get_current_buf()
	-- how often (in ms) to redraw signs/recompute mark positions.
	-- higher values will have better performance but may cause visual lag,
	-- while lower values may cause performance penalties. default 150.
	local refresh_interval = UtilsMark.option_nil(timer_setup, 150)

	local timer = vim.loop.new_timer()
	timer:start(0, refresh_interval, vim.schedule_wrap(M.refresh))
end

return M
