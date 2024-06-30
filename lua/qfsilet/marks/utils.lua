local M = {}

local builtin_marks = {
	["."] = true,
	["^"] = true,
	["`"] = true,
	["'"] = true,
	['"'] = true,
	["<"] = true,
	[">"] = true,
	["["] = true,
	["]"] = true,
}
for i = 0, 9 do
	builtin_marks[tostring(i)] = true
end

-- function M.remove_buf_signs(bufnr, group)
-- 	group = group or "MarkSigns"
-- 	vim.fn.sign_unplace(group, { buffer = bufnr })
-- end

function M.search(marks, start_data, init_values, cmp, cyclic)
	local min_next = init_values
	local min_next_set = false
	-- if we need to wrap around
	local min = init_values

	for mark, data in pairs(marks) do
		if cmp(data, start_data, mark) and not cmp(data, min_next, mark) then
			min_next = data
			min_next_set = true
		end
		if cyclic and not cmp(data, min, mark) then
			min = data
		end
	end
	if not cyclic then
		return min_next_set and min_next or nil
	end
	return min_next_set and min_next or min
end

function M.is_valid_mark(char)
	return M.is_letter(char) or builtin_marks[char]
end

function M.is_special(char)
	return builtin_marks[char] ~= nil
end

function M.is_letter(char)
	return M.is_upper(char) or M.is_lower(char)
end

function M.is_upper(char)
	return (65 <= char:byte() and char:byte() <= 90)
end

function M.is_lower(char)
	return (97 <= char:byte() and char:byte() <= 122)
end

function M.option_nil(option, default)
	if option == nil then
		return default
	else
		return option
	end
end

function M.choose_list(list_type)
	local list_fn
	if list_type == "loclist" then
		list_fn = function(items, flags)
			vim.fn.setloclist(0, items, flags)
		end
	elseif list_type == "quickfixlist" then
		list_fn = vim.fn.setqflist
	end
	return list_fn
end

function M.tablelength(T)
	local count = 0
	for _ in pairs(T) do
		count = count + 1
	end
	return count
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

return M
