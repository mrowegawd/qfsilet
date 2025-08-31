local fn = vim.fn

local Config = require("qfsilet.config").current_configs
local Constant = require("qfsilet.constant")
local Utils = require("qfsilet.utils")
local UtilsFzf = require("qfsilet.fzf.utils")
local UtilsNote = require("qfsilet.note.utils")
local Visual = require("qfsilet.marks.visual")

local Ui = require("qfsilet.ui")

local M = {}

local qf_save_file = {
	qf = {
		items = {},
		title = "",
	},
	loc = {
		items = {},
		title = "",
	},
}

local function merge_items_qf(selected, opts, base_path)
	local tbl = {}

	if type(selected) == "table" then
		for _, sel in pairs(selected) do
			local pth = UtilsFzf.strip_string(sel)
			local file_path = base_path .. "/" .. pth .. ".json"

			local fileRead = Utils.get_file_read(file_path)
			local jsonTbl = Utils.json_decode(fileRead)
			if jsonTbl ~= nil then
				if #jsonTbl.qf.items > 0 then
					for _, tblVal in pairs(jsonTbl.qf.items) do
						table.insert(tbl, tblVal)
					end
				end
			end
		end
	else
		Utils.warn("Not implemented yet, abort it", "QF")
		return
	end

	local action = " " -- (a) append, (r) replace, " "
	local tryIdx = "$"

	local what = {
		idx = tryIdx,
		items = Utils.remove_duplicate_item_tbl(tbl),
		title = opts.prefixTitle .. ":Merged",
	}

	if Utils.is_loclist() then
		vim.fn.setloclist(0, {}, " ", {
			nr = "$",
			items = what.items,
			title = what.title,
		})
		vim.cmd(Config.theme_list.quickfix.lopen)
	else
		fn.setqflist({}, action, what)
		vim.cmd(Config.theme_list.quickfix.copen)
	end

	Utils.info("Import has been successfully loaded and merged", "QF")
end

local function edit_qf(selected, base_path)
	local pth = UtilsFzf.strip_string(selected)
	if pth == nil then
		return
	end

	local filePath = base_path .. "/" .. pth .. ".json"

	local fileRead = Utils.get_file_read(filePath)

	local tbl = vim.fn.json_decode(fileRead)
	if not tbl then
		Utils.warn("edit_qf: failed to load or decode JSON file")
		return
	end

	-- if is_loc then
	-- 	Utils.info("save to loc list")
	-- else
	-- 	Utils.info("save to qf list")
	-- end

	-- Utils.info(vim.inspect(tbl))

	-- local cleanedTbl, title = Utils.clean_up_items(tbl)
	-- if #cleanedTbl.qf.items == 0 then
	-- 	return
	-- end
	--
	-- Utils.write_to_file(cleanedTbl, base_path .. "/" .. title .. ".json")
	--
	-- fn.setqflist({}, " ", cleanedTbl)
	-- vim.cmd(Config.theme_list.quickfix.copen)
	--

	local items = {}
	local title = ""

	local open_qf
	local is_loc

	if tbl.qf.items and #tbl.qf.items > 0 then
		items = tbl.qf.items
		title = tbl.qf.title
		open_qf = true
		is_loc = false
	end

	if tbl.loc.items and #tbl.loc.items > 0 then
		items = tbl.loc.items
		title = tbl.loc.title
		open_qf = false
		is_loc = true
	end

	UtilsNote.save_to_qf(items, title, is_loc)

	if open_qf then
		vim.cmd(Config.theme_list.quickfix.copen)
	else
		vim.cmd(Config.theme_list.quickfix.lopen)
	end

	Utils.info((open_qf and "QF" or "LF") .. " items (" .. title .. ") have been loaded")
end

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃                      BULKS ACTIONS                      ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

function M.edit_or_merge_qf(opts, base_path)
	return {
		["default"] = function(selected, _)
			if not selected then
				return
			end

			if #selected > 1 then
				merge_items_qf(selected, opts, base_path)
				return
			end

			local sel = selected[1]
			if sel then
				edit_qf(sel, base_path)
			end
		end,
		["alt-q"] = function(selected, _)
			if not selected then
				return
			end

			if #selected > 1 then
				merge_items_qf(selected, opts, base_path)
			else
				edit_qf(selected[1], base_path)
			end
		end,
	}
end

function M.delete_item(base_path)
	return {
		["ctrl-x"] = function(selected, _)
			if not selected then
				return
			end

			local sel = UtilsFzf.strip_string(selected[1])
			if sel == nil then
				return
			end

			local filePath = base_path .. "/" .. sel .. ".json"

			if Utils.is_file(filePath) then
				local cmd = "silent! !rm"
				vim.cmd(cmd .. " " .. filePath)
				vim.cmd("lua require'fzf-lua'.resume()")
			end
		end,
		["ctrl-r"] = function(selected, _)
			if not selected then
				return
			end

			local sel = UtilsFzf.strip_string(selected[1])
			if sel == nil then
				return
			end

			local old_file_path = base_path .. "/" .. sel .. ".json"

			if Utils.is_file(old_file_path) then
				Ui.input(function(input_msg)
					if #input_msg == 0 or input_msg == "" then
						return
					end

					local file_name = input_msg

					file_name = file_name:gsub("%s", "_")
					file_name = file_name:gsub("%.", "_")

					local new_file_path = base_path .. "/" .. file_name .. ".json"

					local cmds = { "mv", old_file_path, new_file_path }

					local outputs = vim.system(cmds, { text = true }):wait()
					if outputs.code ~= 0 then
						Utils.error("Rename failed, something went wrong!")
						return
					end

					Utils.info("Rename: " .. sel .. " -> " .. file_name)
				end, "Rename file -> " .. sel)
			end
		end,
	}
end

function M.mark_defaults(buffer)
	return {
		["default"] = function(selected, _)
			if not selected then
				return
			end

			local sel = UtilsFzf.strip_string(selected[1])
			if sel == nil then
				return
			end

			local sel_text = UtilsFzf.strip_string(sel)
			if sel_text then
				local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
				local line = string.match(text, ":(%d+):")
				local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
				for _, x in pairs(buffer.lists) do
					local filename_trim = Utils.format_filename(x.filename)
					if filename and string.match(filename_trim, filename) and tonumber(x.line) == tonumber(line) then
						vim.cmd("e " .. x.filename)
						vim.api.nvim_win_set_cursor(0, { x.line, x.col })
						vim.cmd("normal! zz")
					end
				end
			end
		end,

		["ctrl-v"] = function(selected, _)
			if not selected then
				return
			end

			local sel = UtilsFzf.strip_string(selected[1])
			if sel == nil then
				return
			end

			local sel_text = UtilsFzf.strip_string(sel)
			if sel_text then
				local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
				local line = string.match(text, ":(%d+):")
				local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
				for _, x in pairs(buffer.lists) do
					local filename_trim = Utils.format_filename(x.filename)
					if filename and string.match(filename_trim, filename) and tonumber(x.line) == tonumber(line) then
						vim.cmd("vsplit " .. x.filename)
						vim.api.nvim_win_set_cursor(0, { x.line, x.col })
						vim.cmd("normal! zz")
					end
				end
			end
		end,

		["ctrl-s"] = function(selected, _)
			if not selected then
				return
			end

			local sel = UtilsFzf.strip_string(selected[1])
			if sel == nil then
				return
			end

			local sel_text = UtilsFzf.strip_string(sel)
			if sel_text then
				local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
				local line = string.match(text, ":(%d+):")
				local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
				for _, x in pairs(buffer.lists) do
					local filename_trim = Utils.format_filename(x.filename)
					if filename and string.match(filename_trim, filename) and tonumber(x.line) == tonumber(line) then
						vim.cmd("split " .. x.filename)
						vim.api.nvim_win_set_cursor(0, { x.line, x.col })
						vim.cmd("normal! zz")
					end
				end
			end
		end,

		["ctrl-t"] = function(selected, _)
			if not selected then
				return
			end

			local sel = UtilsFzf.strip_string(selected[1])
			if sel == nil then
				return
			end

			local sel_text = UtilsFzf.strip_string(sel)
			if sel_text then
				local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
				local line = string.match(text, ":(%d+):")
				local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
				for _, x in pairs(buffer.lists) do
					local filename_trim = Utils.format_filename(x.filename)
					if filename and string.match(filename_trim, filename) and tonumber(x.line) == tonumber(line) then
						vim.cmd("tabe " .. x.filename)
						vim.api.nvim_win_set_cursor(0, { x.line, x.col })
						vim.cmd("normal! zz")
					end
				end
			end
		end,

		["ctrl-x"] = function(selected, _)
			if not selected then
				return
			end

			local sel = UtilsFzf.strip_string(selected[1])
			if sel == nil then
				return
			end

			local sel_text = UtilsFzf.strip_string(sel)
			if sel_text then
				local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
				local line = string.match(text, ":(%d+):")
				local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
				for i, x in pairs(buffer.lists) do
					local filename_trim = Utils.format_filename(x.filename)
					if filename and string.match(filename_trim, filename) and tonumber(x.line) == tonumber(line) then
						-- print(vim.inspect(buffer.lists[i]))
						buffer.lists[i] = nil
						Visual.remove_sign(x.bufnr, x.id)
					end
				end
			end

			-- require("fzf-lua").actions.resume()
		end,

		["alt-x"] = function(selected, _)
			if not selected then
				return
			end

			local sel = UtilsFzf.strip_string(selected[1])
			if sel == nil then
				return
			end

			require("qfsilet.marks").clear_all_marks()
			Utils.info("All marks cleared", "Marks")
		end,

		["alt-q"] = function(selected, _)
			local items = {}
			if #selected > 1 then
				for _, item in pairs(selected) do
					local sel_text = UtilsFzf.strip_string(item)
					if sel_text then
						local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
						local line = string.match(text, ":(%d+):")
						local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
						for _, x in pairs(buffer.lists) do
							local filename_trim = Utils.format_filename(x.filename)
							if
								filename
								and string.match(filename_trim, filename)
								and tonumber(x.line) == tonumber(line)
							then
								items[#items + 1] = {
									bufnr = x.buf,
									text = Utils.strip_whitespace(x.text),
									lnum = x.line,
									col = x.col,
									filename = x.filename,
								}
							end
						end
					end
				end
			else
				local sel_text = UtilsFzf.strip_string(selected[1])
				if sel_text then
					local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
					local line = string.match(text, ":(%d+):")
					local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
					for _, x in pairs(buffer.lists) do
						local filename_trim = Utils.format_filename(x.filename)
						if
							filename
							and string.match(filename_trim, filename)
							and tonumber(x.line) == tonumber(line)
						then
							items[#items + 1] = {
								bufnr = x.buf,
								text = Utils.strip_whitespace(x.text),
								lnum = x.line,
								col = x.col,
								filename = x.filename,
							}
						end
					end
				end
			end

			if #items > 0 then
				vim.fn.setqflist({}, "r", { title = "Marks-", items = items })
				vim.cmd(Config.theme_list.quickfix.copen)
			end
		end,

		["alt-Q"] = {
			prefix = "toggle-all",
			fn = function(selected, _)
				if not selected then
					return
				end

				local items = {}
				for _, item in pairs(selected) do
					local sel_text = UtilsFzf.strip_string(item)
					if sel_text then
						local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
						local line = string.match(text, ":(%d+):")
						local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
						for _, x in pairs(buffer.lists) do
							local filename_trim = Utils.format_filename(x.filename)
							if
								filename
								and string.match(filename_trim, filename)
								and tonumber(x.line) == tonumber(line)
							then
								items[#items + 1] = {
									bufnr = x.buf,
									text = Utils.strip_whitespace(x.text),
									lnum = x.line,
									col = x.col,
									filename = x.filename,
								}
							end
						end
					end
				end

				if #items > 0 then
					vim.fn.setqflist({}, "r", { title = "Marks-All", items = items })
					vim.cmd(Config.theme_list.quickfix.copen)
				end
			end,
		},

		["alt-l"] = function(selected, _)
			if not selected then
				return
			end

			local items = {}
			if #selected > 1 then
				for _, item in pairs(selected) do
					local sel_text = UtilsFzf.strip_string(item)
					if sel_text then
						local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
						local line = string.match(text, ":(%d+):")
						local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
						for _, x in pairs(buffer.lists) do
							local filename_trim = Utils.format_filename(x.filename)
							if
								filename
								and string.match(filename_trim, filename)
								and tonumber(x.line) == tonumber(line)
							then
								items[#items + 1] = {
									bufnr = x.buf,
									text = Utils.strip_whitespace(x.text),
									lnum = x.line,
									col = x.col,
									filename = x.filename,
								}
							end
						end
					end
				end
			else
				local sel_text = UtilsFzf.strip_string(selected[1])
				if sel_text then
					local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
					local line = string.match(text, ":(%d+):")
					local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
					for _, x in pairs(buffer.lists) do
						local filename_trim = Utils.format_filename(x.filename)
						if
							filename
							and string.match(filename_trim, filename)
							and tonumber(x.line) == tonumber(line)
						then
							items[#items + 1] = {
								bufnr = x.buf,
								text = Utils.strip_whitespace(x.text),
								lnum = x.line,
								col = x.col,
								filename = x.filename,
							}
						end
					end
				end
			end

			if #items > 0 then
				vim.fn.setloclist(0, {}, " ", {
					nr = "$",
					items = items,
					title = "Marks-",
				})
				vim.cmd(Config.theme_list.quickfix.lopen)
			end
		end,

		["alt-L"] = {
			prefix = "toggle-all",
			fn = function(selected, _)
				if not selected then
					return
				end

				local items = {}
				for _, item in pairs(selected) do
					local sel_text = UtilsFzf.strip_string(item)
					if sel_text then
						local text = sel_text:gsub(Visual.extmarks.qf_sigil .. " ", "")
						local line = string.match(text, ":(%d+):")
						local filename = string.match(sel_text, "([%w_%.%-]+)%:?")
						for _, x in pairs(buffer.lists) do
							local filename_trim = Utils.format_filename(x.filename)
							if
								filename
								and string.match(filename_trim, filename)
								and tonumber(x.line) == tonumber(line)
							then
								items[#items + 1] = {
									bufnr = x.buf,
									text = Utils.strip_whitespace(x.text),
									lnum = x.line,
									col = x.col,
									filename = x.filename,
								}
							end
						end
					end
				end

				if #items > 0 then
					vim.fn.setloclist(0, {}, " ", {
						nr = "$",
						items = items,
						title = "Marks-All",
					})
					vim.cmd(Config.theme_list.quickfix.lopen)
				end
			end,
		},
	}
end

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃                     SINGLE ACTIONS                      ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

function M.default_sel_qf(opts, is_load, qf_items, qf_title, is_loc)
	qf_items = qf_items or {}
	qf_title = qf_title or ""
	is_loc = is_loc or false

	return function(selected, _)
		if not selected then
			return
		end

		local sel = selected[1]
		if not sel then
			return
		end

		local is_global = sel == "global" and true or false

		if is_load then
			require("qfsilet.fzf").load_items_qf(opts, is_global, is_loc)
			return
		end

		Ui.input(function(input_msg)
			vim.cmd("startinsert!")
			-- If `value` contains spaces, concat it them with underscore
			if #input_msg == 0 or input_msg == "" then
				return
			end

			local title = input_msg

			title = title:gsub("%s", "_")
			title = title:gsub("%.", "_")

			if is_loc then
				qf_save_file.loc.title = title
				qf_save_file.loc.items = qf_items
			else
				qf_save_file.qf.title = title
				qf_save_file.qf.items = qf_items
			end

			local path_qf = Constant.defaults.base_path
			if is_global then
				path_qf = Constant.defaults.global_qf_dir
			end

			UtilsNote.save_list_to_file(path_qf, qf_save_file, title)

			vim.cmd("stopinsert")
		end, sel .. " Save " .. (is_loc and "Loclist" or "Quickfix"))
	end
end

return M
