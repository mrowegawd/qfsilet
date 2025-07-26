local fn, L = vim.fn, vim.log

local SHA = require("qfsilet.sha")
local Plenary_path = require("plenary.path")

local M = {}

-- ┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐
-- ╎                           PATH                           ╎
-- └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘

local function __get_cwd_root()
	local HAVE_GITSIGNS = pcall(require, "gitsigns")

	---@diagnostic disable-next-line: undefined-field
	local status = vim.b.gitsigns_status_dict or nil

	local root_path = ""
	if not HAVE_GITSIGNS or status == nil or status["root"] == nil then
		root_path = fn.getcwd()
	else
		root_path = status["root"]
	end

	if #root_path > 0 then
		root_path = vim.fs.basename(root_path)
	end

	return root_path
end

function M.root_path_basename()
	return __get_cwd_root()
end

function M.get_hash_note(filePath)
	return SHA.sha1(filePath)
end

function M.rmdir(path)
	local p = Plenary_path.new(path)
	if p:exists() then
		vim.system({ "rm", "-rf", path })
	end
end

function M.get_option(name_opt)
	return vim.api.nvim_get_option_value(name_opt, { scope = "local" })
end

function M.create_dir(path)
	local p = Plenary_path.new(path)
	if not p:exists() then
		p:mkdir()
	end
end

function M.create_file(path)
	local p = Plenary_path.new(path)
	if not p:exists() then
		p:touch()
	end
end

function M.getFileRead(fname)
	local file_read = fn.readfile(fname)
	return file_read
end

function M.get_base_path_root(path, isGlobal)
	local full_path = path

	if not isGlobal then
		local root_path = __get_cwd_root()
		full_path = full_path .. "/" .. root_path
	end
	return full_path
end

function M.exists(filename)
	local stat
	if filename then
		stat = vim.loop.fs_stat(filename)
	end

	return stat and stat.type or false
end

function M.isDir(filename)
	return M.exists(filename) == "directory"
end

function M.isFile(filename)
	return M.exists(filename) == "file"
end

function M.current_file_path()
	return vim.api.nvim_buf_get_name(0)
end

---@return string
local function norm(path)
	if path:sub(1, 1) == "~" then
		local home = vim.uv.os_homedir()
		if home then
			if home:sub(-1) == "\\" or home:sub(-1) == "/" then
				home = home:sub(1, -2)
			end
			path = home .. path:sub(2)
		end
	end
	path = path:gsub("\\", "/"):gsub("/+", "/")
	return path:sub(-1) == "/" and path:sub(1, -2) or path
end

local function realpath(path)
	if path == "" or path == nil then
		return nil
	end
	path = vim.uv.fs_realpath(path) or path
	return norm(path)
end

local function cwd()
	return realpath(vim.uv.cwd()) or ""
end

function M.format_filename(filename)
	local cwds = cwd()
	if filename:find(cwds, 1, true) == 1 then
		filename = filename:sub(#cwds + 2)
	end
	local sep = package.config:sub(1, 1)
	local parts = vim.split(filename, "[\\/]")
	if #parts > 3 then
		parts = { parts[1], "…", parts[#parts - 1], parts[#parts] }
	end

	return " " .. table.concat(parts, sep)
end

function M.save_table_to_file(table, filename)
	local file = io.open(filename, "w")
	if file then
		file:write("return ")
		file:write(tostring(vim.inspect(table)))
		file:close()
	else
		print("Failed to save data table to file")
	end
end

function M.win_is_valid(opts)
	return opts.winid
		and vim.api.nvim_win_is_valid(opts.winid)
		and opts.bufnr
		and vim.api.nvim_buf_is_valid(opts.bufnr)
		and vim.api.nvim_win_get_buf(opts.winid) == opts.bufnr
end

function M._valid(win, buf)
	if not win or not buf then
		return false
	end
	if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then
		return false
	end
	if vim.api.nvim_win_get_buf(win) ~= buf then
		return false
	end
	-- if Preview.is_win(win) or vim.w[win].trouble then
	-- 	return false
	-- end
	if vim.api.nvim_win_get_config(win).relative ~= "" then
		return false
	end
	if vim.bo[buf].buftype ~= "" then
		return false
	end
	return true
end

function M.find_win_ls(opts)
	vim.validate({
		bufnr = { opts, "table" },
	})
	local found_ls = { found = false, winid = 0 }

	local wins = vim.api.nvim_list_wins()
	for _, winid in ipairs(wins) do
		local b = vim.api.nvim_win_get_buf(winid)
		if M._valid(winid, b) then
			local bufnr = vim.api.nvim_win_get_buf(winid)

			if opts.bufnr and opts.bufnr > 0 then
				if bufnr == opts.bufnr then
					found_ls = { found = true, winid = winid, bufnr = bufnr, winnr = winid }
				end
			elseif opts.filename and #opts.filename > 0 then
				local winid_fn = vim.api.nvim_buf_get_name(bufnr)
				if string.match(opts.filename, winid_fn) then
					found_ls = { found = true, winid = winid, bufnr = bufnr, winnr = winid }
					break
				end
			end
		end
	end
	return found_ls
end

-- ┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐
-- ╎                           LIST                           ╎
-- └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘

function M.getCurrentList(items, isLocationlist)
	local cur_list
	if isLocationlist then
		cur_list = fn.getloclist(0)
	else
		cur_list = fn.getqflist()
	end

	if items ~= nil and #items > 0 then
		cur_list = vim.list_extend(cur_list, items)
	end

	return cur_list
end

function M.isLocList(buf)
	buf = buf or 0
	return vim.fn.getloclist(buf, { filewinid = 1 }).filewinid ~= 0
end

function M.cleanupItems(items)
	local _tbl = items.qf.items

	local tbl_stay = {}
	for i = 1, #_tbl do
		table.insert(tbl_stay, _tbl[i])
	end

	items.qf.items = tbl_stay
	local title = items.qf.title

	return items, title
end

-- ┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐
-- ╎                           JSON                           ╎
-- └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘

function M.json_encode(tbl)
	return vim.json.encode(tbl)
end

function M.json_decode(tbl)
	return vim.json.decode(tbl)
end

function M.writeToFile(tbl, path_fname)
	local tbl_json = M.json_encode(tbl)
	fn.writefile({ tbl_json }, path_fname)
end

function M.checkJSONPath(path)
	local scripts = vim.api.nvim_exec2(string.format([[!find %s -type f -name "*.json"]], path), { output = true })
	if scripts.output ~= nil then
		local res = vim.split(scripts.output, "\n")
		local found = false
		for index = 2, #res do
			local item = res[index]
			if #item > 0 then
				found = true
			end
		end

		return found
	end
end

-- ┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐
-- ╎                           MISC                           ╎
-- └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘

function M.feedkey(mode, motion, special)
	local sequence = vim.api.nvim_replace_termcodes(motion, true, false, special or false)
	vim.api.nvim_feedkeys(sequence, mode, true)
end

function M.info(msg, name)
	vim.notify(msg, L.levels.INFO, { title = name or "QFSilet" })
end

function M.debug_info(msg)
	M.info(msg, "DEBUG QFSILET")
end

function M.warn(msg, name)
	vim.notify(msg, L.levels.WARN, { title = name or "QFSilet" })
end

function M.removeDuplicates(arr)
	local newArray = {}
	local checkerTbl = {}
	for _, element in ipairs(arr) do
		if not checkerTbl[element] then
			checkerTbl[element.filename] = element.col
			table.insert(newArray, element)
		end
	end
	return newArray
end

function M.key_to_tbl(marks_opts)
	local keyset = {}
	local n = 0
	for k, _ in pairs(marks_opts) do
		n = n + 1
		keyset[n] = k
	end
	return keyset
end

function M.check_wins(wins)
	wins = wins or {}
	vim.validate({ wins = { wins, "table" } })

	local win_tbl = { found = false, winbufnr = 0, winnr = 0, winid = 0 }

	local ft_wins = { "incline" }
	if #wins > 0 then
		for _, x in pairs(wins) do
			ft_wins[#ft_wins + 1] = x
		end
	end

	for _, winnr in ipairs(vim.fn.range(1, vim.fn.winnr("$"))) do
		local winbufnr = vim.fn.winbufnr(winnr)
		if
			winbufnr > 0
			and (
				vim.tbl_contains(ft_wins, vim.api.nvim_get_option_value("filetype", { buf = winbufnr }))
				or vim.tbl_contains(ft_wins, vim.api.nvim_get_option_value("buftype", { buf = winbufnr }))
			)
		then
			local winid = vim.fn.win_findbuf(winbufnr)[1] -- example winid: 1004, 1005
			win_tbl = { found = true, winbufnr = winbufnr, winnr = winnr, winid = winid }
		end
	end
	return win_tbl
end

return M
