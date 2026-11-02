-- ============================================================
-- init.lua — entry point
-- Every section of the old single-file config now lives in its own module
-- under lua/config/. This file only decides what to load, and in what order.
-- ============================================================

-- Cache compiled Lua modules. Must run before the first require() to help.
vim.loader.enable()

-- ------------------------------------------------------------
-- Where do language servers come from on this machine?
--   NixOS     → home.nix (programs.neovim.extraPackages); skip Mason
--   elsewhere → Mason installs them (lua/config/lsp_install.lua)
-- /etc/NIXOS exists on every NixOS system. Override the detection with
-- the NVIM_MASON environment variable: NVIM_MASON=1 forces Mason on,
-- NVIM_MASON=0 forces it off (e.g. standalone Home Manager on another distro).
-- ------------------------------------------------------------
local function want_mason()
	if vim.env.NVIM_MASON == "1" then
		return true
	elseif vim.env.NVIM_MASON == "0" then
		return false
	end
	return vim.uv.fs_stat("/etc/NIXOS") == nil
end

-- True only if lsp_install.lua is present, so the file can also just be deleted
local function has_lsp_installer()
	return #vim.api.nvim_get_runtime_file("lua/config/lsp_install.lua", false) > 0
end

-- ------------------------------------------------------------
-- Load order matters:
--   options first (sets <leader> before any mapping is made),
--   pack before any vim.pack.add (so the build hooks fire on first install).
-- ------------------------------------------------------------
require("config.options") -- Section 1: options
require("config.keymaps") -- Section 2: keymaps & autocmds
require("config.pack") -- Section 3: vim.pack build hooks
require("config.ui") -- Section 4: UI / core UX plugins
require("config.navigation") -- Section 5: Telescope + Neo-tree

if want_mason() and has_lsp_installer() then
	require("config.lsp_install") -- Section 6a: Mason (non-NixOS only)
end
require("config.lsp") -- Section 6b: LSP setup (all systems)

require("config.formatting") -- Section 7: conform.nvim
require("config.completion") -- Section 8: LuaSnip + blink.cmp
require("config.treesitter") -- Section 9: Treesitter
