-- ============================================================
-- SECTION 6b: LSP — shared by every system
-- Configures and enables the servers in lsp_servers.lua. It does NOT install
-- anything: on NixOS the binaries come from home.nix, elsewhere from Mason
-- (lsp_install.lua). Either way they only need to be on Neovim's PATH.
-- ============================================================
local gh = require("config.util").gh

-- Useful status updates for LSP.
vim.pack.add({ gh("j-hui/fidget.nvim") })
require("fidget").setup({})

--  This function gets run when an LSP attaches to a particular buffer.
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
	callback = function(event)
		local map = function(keys, func, desc, mode)
			mode = mode or "n"
			vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
		end

		-- Rename the variable under your cursor.
		map("grn", vim.lsp.buf.rename, "[R]e[n]ame")

		-- Execute a code action, usually your cursor needs to be on top of an error
		-- or a suggestion from your LSP for this to activate.
		map("gra", vim.lsp.buf.code_action, "[G]oto Code [A]ction", { "n", "x" })

		-- WARN: This is not Goto Definition, this is Goto Declaration.
		--  For example, in C this would take you to the header.
		map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

		-- The following two autocommands are used to highlight references of the
		-- word under your cursor when your cursor rests there for a little while.
		-- When you move your cursor, the highlights will be cleared (the second autocommand).
		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if client and client:supports_method("textDocument/documentHighlight", event.buf) then
			local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
			vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
				buffer = event.buf,
				group = highlight_augroup,
				callback = vim.lsp.buf.document_highlight,
			})

			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				buffer = event.buf,
				group = highlight_augroup,
				callback = vim.lsp.buf.clear_references,
			})

			vim.api.nvim_create_autocmd("LspDetach", {
				group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
				callback = function(event2)
					vim.lsp.buf.clear_references()
					vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = event2.buf })
				end,
			})
		end
	end,
})

-- [LSPs]
-- nvim-lspconfig supplies the default cmd / filetypes / root markers for each
-- server (its lsp/<name>.lua files); the tables in lsp_servers.lua are merged on top.
vim.pack.add({ gh("neovim/nvim-lspconfig") })

for name, server in pairs(require("config.lsp_servers")) do
	vim.lsp.config(name, server)
	vim.lsp.enable(name)
end
