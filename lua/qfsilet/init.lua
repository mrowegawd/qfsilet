local config = require("qfsilet.config")

local function setup(opts)
	config.current_configs = config.update_settings(opts)

	if not config.current_configs.loaded then
		config.current_configs.loaded = true

		config.init()
		require("qfsilet.mapping").setup_keymaps_and_autocmds()
	end
end

return {
	setup = setup,
}
