local uv, fn, L = vim.loop, vim.fn, vim.log

-- local async = require("plenary.async")
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
		vim.fn.delete(path, "rf")
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
	local stat = uv.fs_stat(filename)
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

function M.isLocList()
	-- This func will check if current buffer is loclist
	-- if loclist, filewinid will return more than zero (true)
	local location_list = fn.getloclist(0, { filewinid = 0 })
	return location_list.filewinid > 0
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

function M.jsonEncode(tbl)
	return fn.json_encode(tbl)
end

-- function M.jsonDecode(tbl)
-- 	return fn.json_decode(tbl)
-- end

function M.writeToFile(tbl, path_fname)
	local tbl_json = M.jsonEncode(tbl)
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

return M
