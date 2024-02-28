local Util = require("qfsilet.utils")
local Config = require("qfsilet.config").current_configs
local Constant = require("qfsilet.constant")

local M = {}

local function init(isGlobal, isLoadJson)
	isGlobal = isGlobal or false
	isLoadJson = isLoadJson or false

	-- Membuat direktori jika belum ada
	local function createDirectoryIfNotExists(directory)
		if not Util.isDir(directory) then
			Util.create_dir(directory)
		end
	end

	-- Inisialisasi konstanta dasar
	Constant.defaults.base_hash = Util.get_hash_note(vim.loop.fs_realpath(vim.loop.cwd()))
	local base_path = Util.get_base_path_root(Config.save_dir, isGlobal)
	Constant.defaults.base_path = base_path .. "_" .. Constant.defaults.base_hash

	-- Membuat nama file
	local fn_name = Config.file_spec.name .. "_" .. Util.root_path_basename()
	if Config.file_spec.ext_file then
		fn_name = fn_name .. "." .. Config.file_spec.ext_file
	end
	Constant.defaults.note_path = Constant.defaults.base_path .. "/" .. fn_name

	-- Memeriksa apakah operasi global
	if isGlobal then
		Constant.defaults.base_path = Config.save_dir .. "/__global_qf"
		Constant.defaults.note_path = Constant.defaults.base_path .. "/todo_qfglobal"
		if Config.file_spec.ext_file then
			Constant.defaults.note_path = Constant.defaults.note_path .. "." .. Config.file_spec.ext_file
		end
		Constant.defaults.global_note_dir = Constant.defaults.note_path
	end

	-- Membuat direktori jika tidak memuat data JSON
	if not isLoadJson then
		createDirectoryIfNotExists(Constant.defaults.base_path)
	end
end

-- Inisialisasi direktori lokal
function M.init_local()
	init()
end

-- Inisialisasi direktori global
function M.init_global()
	init(true)
end

return M
