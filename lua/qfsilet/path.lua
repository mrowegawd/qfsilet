local Util = require("qfsilet.utils")
local Config = require("qfsilet.config").current_configs

local M = {}

M.defaults = {
	base_path = "",
	base_hash = "",
	note_path = "",
	global_note_dir = "",
}

local function init(isGlobal, isLoadJson)
	isGlobal = isGlobal or false
	isLoadJson = isLoadJson or false

	if not Util.is_dir(Config.save_dir) then
		Util.create_dir(Config.save_dir)
	end

	M.defaults.base_hash = Util.get_hash_note(vim.loop.fs_realpath(vim.loop.cwd()))
	local base_path = Util.get_base_path_root(Config.save_dir, isGlobal)

	M.defaults.base_path = base_path .. "_" .. M.defaults.base_hash
	M.defaults.note_path = M.defaults.base_path .. "/todo"
	if isGlobal then
		M.defaults.base_path = Config.save_dir .. "/__global_qf"
		M.defaults.note_path = M.defaults.base_path .. "/todo"
		M.defaults.global_note_dir = M.defaults.note_path
	end

	-- Do not create any dir path when calling `note/loadqflist()`
	if not isLoadJson then
		if not Util.is_dir(M.defaults.base_path) then
			Util.create_dir(M.defaults.base_path)
		end
	end
end

-- Create path local dir path for todo
function M.init_local()
	init()
end

-- Create path global dir path for todo
function M.init_global()
	init(true)
end

return M
