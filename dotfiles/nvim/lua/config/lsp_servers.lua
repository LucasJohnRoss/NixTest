-- ============================================================
-- LSP SERVER LIST — the single source of truth
-- Read by lsp.lua (configures + enables each one, on every system) and by
-- lsp_install.lua (asks Mason to install each one, non-NixOS only).
--
-- Keys are nvim-lspconfig names. On NixOS, each server you enable here also
-- needs its package in home.nix → programs.neovim.extraPackages.
-- ============================================================

---@type table<string, vim.lsp.Config>
return {
	clangd = {}, -- home.nix: clang-tools
	basedpyright = {}, -- home.nix: basedpyright (was `pyright`; switched to match home.nix)
	rust_analyzer = {}, -- home.nix: rust-analyzer (currently commented out there!)
	--bashls = {}, -- home.nix: bash-language-server
	--yamlls = {}, -- home.nix: yaml-language-server
	marksman = {}, -- home.nix: marksman
	--jsonls = {}, -- home.nix: vscode-langservers-extracted
	terraformls = {}, -- home.nix: terraform-ls
	--sqlls = {},
	stylua = {}, -- Used to format Lua code (home.nix: stylua)

	-- Special Lua Config, as recommended by neovim help docs
	lua_ls = { -- home.nix: lua-language-server
		settings = {
			Lua = {
				diagnostics = {
					globals = { "hl" },
				},
				runtime = { version = "LuaJIT" },
				workspace = {
					checkThirdParty = false,
					library = { vim.env.VIMRUNTIME },
				},
			},
		},
	},
}
