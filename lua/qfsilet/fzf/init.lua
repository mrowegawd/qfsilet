local Util = require("qfsilet.utils")

local fzf_ok, _ = pcall(require, "fzf-lua")
if not fzf_ok then
	Util.warn("fzf-lua required as dependency")
	return
end

local Fzf_mappings = require("qfsilet.fzf.mappings")
local Path = require("qfsilet.path")

local M = {}

local function format_title(str, icon, icon_hl)
	return {
		{ " " },
		{ (icon and icon .. " " or ""), icon_hl or "DevIconDefault" },
		{ str, "Bold" },
		{ " " },
	}
end

function M.load(opts, isGlobal)
	local titleMsg = "local"
	if isGlobal then
		titleMsg = "global"
	end

	if not Util.checkjson_onpath(Path.defaults.base_path) then
		Util.warn(
			string.format(
				[[ There is no notes on this [%s] workspaces 
 Try make it one..]],
				titleMsg
			),
			"QFSilet"
		)
		return
	end

	local fzf_opts = {
		prompt = "  ",
		cwd = Path.defaults.base_path,
		cmd = "fd -d 1 -e json | cut -d. -f1",
		cwd_prompt = false,
		cwd_header = false,
		no_header = true, -- hide grep|cwd header?
		no_header_i = true, -- hide interactive header?
		fzf_opts = { ["--header"] = [[Ctrl-x:'delete']] },
		winopts_fn = function()
			local cols = vim.o.columns - 50
			local collss = cols > 80 and cols - 80 or cols / 2
			return { width = 60, height = 15, row = 15, col = collss }
		end,
		winopts = {
			hl = { normal = "Normal" },
			title = format_title(titleMsg:gsub("^%l", string.upper) .. " notes", "", "Boolean"),
			border = "rounded",
			height = 0.4,
			width = 0.30,
			row = 0.40,
			col = 0.55,
			preview = { hidden = "hidden" },
		},

		actions = vim.tbl_extend(
			"keep",
			Fzf_mappings.edit_or_merge_qf(opts, Path.defaults.base_path),
			Fzf_mappings.delete_item(Path.defaults.base_path)
		),
	}

	require("fzf-lua").files(fzf_opts)
end

return M
