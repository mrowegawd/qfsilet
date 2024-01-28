local Input = require("nui.input")
local Popup = require("nui.popup")
local Util = require("qfsilet.utils")
local Event = require("nui.utils.autocmd").event
local Config = require("qfsilet.config").current_configs

local fmt, cmd = string.format, vim.cmd

local M = {}

local function __get_cur_size()
	local height = vim.o.lines - vim.o.cmdheight
	if vim.o.laststatus ~= 0 then
		height = height - 1
	end

	local vim_width = vim.o.columns
	local vim_height = height

	return vim_width, vim_height
end

local function __get_ui_size()
	local total_width = 0.95 -- from 0 to 1, total width of popup
	local total_height = 0.4 -- from 0 to 1, total height of popup ui

	local vim_width, vim_height = __get_cur_size()

	total_width = math.floor(vim_width * total_width + 0.3)
	total_height = math.floor(vim_height * total_height + 0.3)
	local initial_col = math.floor((vim_width - total_width) / 2 + 0.3) + 8
	local initial_row = math.floor((vim_height - total_height) / 2 + 0.3) - 5

	return initial_col, initial_row
end

local function __get_popup_size()
	local vim_width, vim_height = __get_cur_size()

	local widthc = math.floor(vim_width / 2 + 4)
	local heightc = math.floor(vim_height / 2 - 5)

	return widthc, heightc
end

function M.input(func, text_top_msg)
	if vim.bo.filetype == "qf" then
		cmd.wincmd("p")
	end
	local input_opts = {
		position = "50%",
		relative = "editor",
		size = {
			width = 60,
			height = 20,
		},
		border = {
			style = "single",
			padding = {
				top = 1,
				bottom = 1,
				left = 1,
				right = 1,
			},
			text = {
				top = fmt(" [%s %s: %s] ", Config.popup.icon_note, Config.prefix_title, text_top_msg),
				top_align = "center",
			},
		},
		win_options = {
			winhighlight = Config.popup.winhighlight,
		},
	}

	local input = Input(input_opts, {
		prompt = "> ",
		default_value = "",
		on_close = function() end,
		on_submit = function(value)
			func(value)
		end,
	})

	-- mount/open the component
	input:mount()

	-- unmount component when cursor leaves buffer
	input:on(Event.BufLeave, function()
		input:unmount()
	end)
	input:map("n", "<Esc>", function()
		input:unmount()
	end, { noremap = true })
	input:map("n", "<c-c>", function()
		input:unmount()
	end, { noremap = true })
end

function M.popup(fname_path, IsGlobal, base_path)
	IsGlobal = IsGlobal or false

	local top_ext_msg = "Todo"
	if IsGlobal then
		top_ext_msg = "Todo global"
	end

	local col, row = __get_ui_size()
	local width, height = __get_popup_size()

	local pop_opts = {
		position = {
			row = row,
			col = col,
		},
		size = {
			width = width,
			height = height,
		},
		relative = "cursor",
		enter = true,
		focusable = true,
		zindex = 50,
		win_options = {
			winhighlight = Config.popup.winhighlight,
			scrolloff = 0,
		},
		buf_options = {
			filetype = Config.popup.filetype,
		},
		border = {
			padding = {
				top = 2,
				bottom = 2,
				left = 3,
				right = 3,
			},
			style = "rounded",
			text = {
				top = fmt(" [%s %s: %s] ", Config.popup.icon_note, Config.prefix_title, top_ext_msg),
				top_align = "center",
			},
		},
	}

	local popup = Popup(pop_opts)
	popup:mount()
	popup:on(Event.BufLeave, function()
		vim.cmd("silent! wq! " .. fname_path)

		-- No file todos or no file json, remove it
		if vim.fn.getfsize(fname_path) == 0 or vim.fn.getfsize(fname_path) == 1 then
			if not Util.checkjson_onpath(base_path) then
				Util.rmdir(base_path)
			end
		end

		popup:unmount()
	end)

	local trim = function(pattern)
		local save = vim.fn.winsaveview()
		cmd(string.format("keepjumps keeppatterns silent! %s", pattern))
		vim.fn.winrestview(save)
	end

	popup:map("n", { "<Esc>", "q" }, function()
		trim([[%s/\($\n\s*\)\+\%$//]])
		trim([[%s/\s\+$//e]])

		popup:unmount()
	end, { noremap = true })
end

return M
