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

function M.get_file_read(fname)
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

function M.is_dir(filename)
	return M.exists(filename) == "directory"
end

function M.is_file(filename)
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

-- ┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐
-- ╎                           LIST                           ╎
-- └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘

function M.getCurrentList(items, is_loclist)
	local cur_list
	if is_loclist then
		cur_list = fn.getloclist(0)
	else
		cur_list = fn.getqflist()
	end

	if items ~= nil and #items > 0 then
		cur_list = vim.list_extend(cur_list, items)
	end

	return cur_list
end

function M.is_loclist(buf)
	buf = buf or 0
	return vim.fn.getloclist(buf, { filewinid = 1 }).filewinid ~= 0
end

function M.clean_up_items(items)
	local items_qf

	for _, x in pairs(items) do
		items_qf[#items_qf + 1] = {
			lnum = x.lnum,
			text = x.text,
			type = x.type,
			col = x.col,
		}
	end

	return items_qf
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

function M.write_to_file(tbl, path_fname)
	local tbl_json = M.json_encode(tbl)
	fn.writefile({ tbl_json }, path_fname)
end

function M.is_json_path_exists(path)
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
	vim.notify(msg, L.levels.INFO, { title = name or "Notify" })
end

function M.debug_info(msg)
	M.info(msg, "DEBUG QFSILET")
end

function M.warn(msg, name)
	vim.notify(msg, L.levels.WARN, { title = name or "Notify" })
end

function M.remove_duplicate_item_tbl(arr)
	local new_tbl = {}
	local dump_tbl = {}
	for _, element in ipairs(arr) do
		if not element.col or not element.filename then
			M.error("Element doesn't have the requested element")
			return
		end

		if not dump_tbl[element] then
			dump_tbl[element.filename] = element.col
			table.insert(new_tbl, element)
		end
	end
	return new_tbl
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

function M.get_lowercase(str)
	return str:lower()
end

function M.get_uppercase_first_letter(str)
	str = M.get_lowercase(str)
	return (str:gsub("^%l", string.upper))
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

local rstrip_whitespace = function(str)
	str = string.gsub(str, "%s+$", "")
	return str
end

local lstrip_whitespace = function(str, limit)
	if limit ~= nil then
		local num_found = 0
		while num_found < limit do
			str = string.gsub(str, "^%s", "")
			num_found = num_found + 1
		end
	else
		str = string.gsub(str, "^%s+", "")
	end
	return str
end

function M.strip_whitespace(str)
	if str then
		return rstrip_whitespace(lstrip_whitespace(str))
	end
	return ""
end

return M
