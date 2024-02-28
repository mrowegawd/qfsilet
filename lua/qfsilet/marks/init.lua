local Util = require("qfsilet.marks.utils")
local Config = require("qfsilet.config").current_configs
local M = {}

local buffers = {
	opt = Config.marks,
}

local function register_mark(mark, line, col, bufnr)
	col = col or 1
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local buffer = buffers[bufnr]

	if not buffer then
		return
	end

	-- print(vim.inspect(buffers))
	if buffer.placed_marks[mark] then
		-- mark already exists: remove it first
		M.delete_mark(mark, false)
	end

	if buffer.marks_by_line[line] then
		table.insert(buffer.marks_by_line[line], mark)
	else
		buffer.marks_by_line[line] = { mark }
	end
	buffer.placed_marks[mark] = { line = line, col = col, id = -1 }

	-- local display_signs = Util.option_nil(buffers[bufnr].opt.buf_signs[bufnr], buffers[bufnr].opt.signs)
	-- if display_signs then
	-- 	local id = mark:byte() * 100
	-- 	buffer.placed_marks[mark].id = id
	-- 	Util.add_sign(bufnr, mark, line, id)
	-- end

	if not Util.is_lower(mark) or mark:byte() > buffer.lowest_available_mark:byte() then
		return
	end

	while buffers[bufnr].placed_marks[mark] do
		mark = string.char(mark:byte() + 1)
	end
	buffers[bufnr].lowest_available_mark = mark
end

function M.show_config()
	vim.print(vim.inspect(buffers))
end

function M.delete_mark(mark, clear)
	clear = Util.option_nil(clear, true)
	local bufnr = vim.api.nvim_get_current_buf()
	local buffer = buffers[bufnr]

	if (not buffer) or not buffer.placed_marks[mark] then
		return
	end

	if buffer.placed_marks[mark].id ~= -1 then
		Util.remove_sign(bufnr, buffer.placed_marks[mark].id)
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

	if Config.force_write_shada then
		vim.cmd("wshada!")
	end

	-- only adjust lowest_available_mark if it is lowercase
	if not Util.is_lower(mark) then
		return
	end

	if mark:byte() < buffer.lowest_available_mark:byte() then
		buffer.lowest_available_mark = mark
	end
end

function M.delete_buf_marks(clear)
	clear = Util.option_nil(clear, true)
	local bufnr = vim.api.nvim_get_current_buf()
	buffers[bufnr] = { placed_marks = {}, marks_by_line = {}, lowest_available_mark = "a" }

	Util.remove_buf_signs(bufnr)
	if clear then
		vim.cmd("delmarks!")
	end
end

function M.next_mark()
	local bufnr = vim.api.nvim_get_current_buf()

	if not buffers[bufnr] then
		return
	end

	local line = vim.api.nvim_win_get_cursor(0)[1]
	local marks = {}
	for mark, data in pairs(buffers[bufnr].placed_marks) do
		if Util.is_letter(mark) then
			marks[mark] = data
		end
	end

	if vim.tbl_isempty(marks) then
		return
	end

	local function comparator(x, y, _)
		return x.line > y.line
	end

	local next = Util.search(marks, { line = line }, { line = math.huge }, comparator, true)

	if next then
		vim.api.nvim_win_set_cursor(0, { next.line, next.col })
	end
end

function M.prev_mark()
	local bufnr = vim.api.nvim_get_current_buf()

	if not buffers[bufnr] then
		return
	end

	local line = vim.api.nvim_win_get_cursor(0)[1]
	local marks = {}
	for mark, data in pairs(buffers[bufnr].placed_marks) do
		if Util.is_letter(mark) then
			marks[mark] = data
		end
	end

	if vim.tbl_isempty(marks) then
		return
	end

	local function comparator(x, y, _)
		return x.line < y.line
	end
	local prev = Util.search(marks, { line = line }, { line = -1 }, comparator, true)

	if prev then
		vim.api.nvim_win_set_cursor(0, { prev.line, prev.col })
	end
end

function M.delete_line_marks()
	local bufnr = vim.api.nvim_get_current_buf()
	local pos = vim.api.nvim_win_get_cursor(0)

	if not buffers[bufnr].marks_by_line[pos[1]] then
		return
	end

	-- delete_mark modifies the table, so make a copy
	local copy = vim.tbl_values(buffers[bufnr].marks_by_line[pos[1]])
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

	if Util.is_valid_mark(input) then
		M.delete_mark(input)
		return
	end
end

function M.fzf_marks(col, bufnr)
	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
	col = col or 1
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local buffer = buffers[bufnr]

	if not buffer then
		return
	end

	if Util.tablelength(buffer.marks_by_line) then
		require("qfsilet.fzf").grep_marks(buffer.placed_marks, path)
	end
end

function M.place_next_mark(line, col)
	local bufnr = vim.api.nvim_get_current_buf()
	if not buffers[bufnr] then
		buffers[bufnr] = { placed_marks = {}, marks_by_line = {}, lowest_available_mark = "a" }
	end

	local mark = buffers[bufnr].lowest_available_mark
	register_mark(mark, line, col, bufnr)

	vim.cmd("normal! m" .. mark)
end

function M.toggle_mark_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local pos = vim.api.nvim_win_get_cursor(0)

	if buffers[bufnr].marks_by_line[pos[1]] then
		-- print("yes delete line marks")
		M.delete_line_marks()
	else
		-- print("yes place next marks")
		M.place_next_mark(pos[1], pos[2])
	end
end

function M.refresh_deforce(bufnr, force)
	force = force or false
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	if not buffers[bufnr] then
		buffers[bufnr] = { placed_marks = {}, marks_by_line = {}, lowest_available_mark = "a" }
	end

	-- first, remove all marks that were deleted
	for mark, _ in pairs(buffers[bufnr].placed_marks) do
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
		cached_mark = buffers[bufnr].placed_marks[mark]

		if Util.is_upper(mark) and pos[1] == bufnr and (force or not cached_mark or pos[2] ~= cached_mark.line) then
			register_mark(mark, pos[2], pos[3], bufnr)
		end
	end

	-- lowercase
	for _, data in ipairs(vim.fn.getmarklist("%")) do
		mark = data.mark:sub(2, 3)
		pos = data.pos
		cached_mark = buffers[bufnr].placed_marks[mark]

		if Util.is_lower(mark) and (force or not cached_mark or pos[2] ~= cached_mark.line) then
			register_mark(mark, pos[2], pos[3], bufnr)
		end
	end

	-- builtin marks
	-- for _, char in pairs(buffers[bufnr].opt.builtin_marks) do
	-- 	pos = vim.fn.getpos("'" .. char)
	-- 	cached_mark = buffers[bufnr].placed_marks[char]
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
	local priority
	if Util.is_lower(text) then
		priority = Config.marks.priority[1]
	elseif Util.is_upper(text) then
		priority = Config.marks.priority[2]
	else -- builtin
		priority = Config.marks.priority[3]
	end
	Util.add_sign(bufnr, text, line, id, "MarkSigns", priority)
end

function M.refresh(force_reregister)
	-- if M.excluded_fts[vim.bo.ft] or M.excluded_bts[vim.bo.bt] then
	-- 	return
	-- end

	force_reregister = force_reregister or false
	M.refresh_deforce(nil, force_reregister)
	-- M.bookmark_state:refresh()
end

local function setup_commands()
	vim.cmd([[augroup Qfsilet_marks_autocmds
    autocmd!
    autocmd BufReadPost * lua require'qfsilet.marks'.refresh(true)
    " autocmd BufDelete * lua require'marks'._on_delete()
  augroup end]])
end

function M.setup(timer_setup)
	setup_commands()

	-- local bufnr = vim.api.nvim_get_current_buf()
	-- how often (in ms) to redraw signs/recompute mark positions.
	-- higher values will have better performance but may cause visual lag,
	-- while lower values may cause performance penalties. default 150.
	local refresh_interval = Util.option_nil(timer_setup, 150)

	local timer = vim.loop.new_timer()
	timer:start(0, refresh_interval, vim.schedule_wrap(M.refresh))
end

return M
