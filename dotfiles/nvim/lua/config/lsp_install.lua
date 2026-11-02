-- ============================================================
-- SECTION 6a: LSP INSTALLER (Mason) — NON-NixOS SYSTEMS ONLY
--
-- On NixOS the servers come from home.nix (programs.neovim.extraPackages),
-- and init.lua skips this file automatically (it checks for /etc/NIXOS).
-- Mason's prebuilt binaries expect a normal FHS Linux layout, so on NixOS
-- they would usually fail to run anyway.
--
-- You can also simply delete this file on any machine: init.lua checks it
-- exists before loading it. Nothing else in the config depends on it.
--
--    :Mason   — open the Mason UI
-- ============================================================
local gh = require("config.util").gh
local servers = require("config.lsp_servers")

vim.pack.add({
	gh("neovim/nvim-lspconfig"), -- also added in lsp.lua; vim.pack ignores the repeat
	gh("mason-org/mason.nvim"),
	gh("mason-org/mason-lspconfig.nvim"),
	gh("WhoIsSethDaniel/mason-tool-installer.nvim"),
})

-- Automatically install LSPs and related tools to stdpath for Neovim.
-- setup() also prepends Mason's bin folder to PATH, which is how Neovim
-- finds the servers it installs.
require("mason").setup({})

-- Translates between nvim-lspconfig server names and mason.nvim package names (e.g. lua_ls <-> lua-language-server)
require("mason-lspconfig").setup({
	automatic_enable = true, -- Also enable servers installed manually via :Mason / :MasonInstall
})

-- Everything in lsp_servers.lua, plus any extra (non-LSP) tools below
local ensure_installed = vim.tbl_keys(servers)
vim.list_extend(ensure_installed, {
	-- Formatters / linters you want Mason to install, e.g.
	-- "prettierd", "shfmt", "ruff",
})

require("mason-tool-installer").setup({ ensure_installed = ensure_installed })
