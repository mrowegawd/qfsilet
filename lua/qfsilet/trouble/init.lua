local fn = vim.fn
local Config = require("qfsilet.config")

local M = {
	open = false,
}

local entry_to_qf = function(text, entry)
	return {
		bufnr = vim.api.nvim_get_current_buf(),
		-- filename = from_entry.path(entry, false, false),
		lnum = entry.line,
		col = entry.col,
		text = text,
		-- type = entry.qf_type,
	}
end
local set_current_list = function(items, is_local, win_id)
	win_id = fn.win_getid() or win_id
	is_local = false or is_local

	if is_local then
		fn.setloclist(win_id, items)
	else
		local what = {
			idx = "$",
			items = items,
			-- title = fn.getqflist({ title = 0 }),
			title = "Marks: " .. win_id,
		}

		fn.setqflist({}, "r", what)
	end
end

function M.qfmarks(item_marks, path)
	item_marks = item_marks or {}
	path = path or {}

	local items_tbl = {}

	local keys = {}
	for k, _ in pairs(item_marks.placed_marks) do
		table.insert(keys, k)
	end

	table.sort(keys, function(a, b)
		return a > b
	end)

	for i = #keys, 1, -1 do
		local key = keys[i]
		local value = item_marks.placed_marks[key]
		table.insert(items_tbl, entry_to_qf(key, value))
	end

	set_current_list(items_tbl)

	M.open = true

	vim.cmd(Config.theme_list.quickfix.copen)
end
function M.get_signs()
	return ""
end

return M
