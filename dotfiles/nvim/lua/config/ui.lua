-- ============================================================
-- SECTION 4: UI / CORE UX PLUGINS
-- ============================================================
local gh = require("config.util").gh

-- Plugin for automatically detecting and setting the indentation.
vim.pack.add({ gh("NMAC427/guess-indent.nvim") })
require("guess-indent").setup({})

-- Adds git related signs to the gutter, as well as utilities for managing changes
vim.pack.add({ gh("lewis6991/gitsigns.nvim") })
require("gitsigns").setup({
	signs = {
		add = { text = "+" }, ---@diagnostic disable-line: missing-fields
		change = { text = "~" }, ---@diagnostic disable-line: missing-fields
		delete = { text = "_" }, ---@diagnostic disable-line: missing-fields
		topdelete = { text = "‾" }, ---@diagnostic disable-line: missing-fields
		changedelete = { text = "~" }, ---@diagnostic disable-line: missing-fields
	},
})

-- Useful plugin to show you pending keybinds.
vim.pack.add({ gh("folke/which-key.nvim") })
require("which-key").setup({
	delay = 0,
	icons = { mappings = vim.g.have_nerd_font },
	spec = {
		{ "<leader>s", group = "[S]earch", mode = { "n", "v" } },
		{ "<leader>h", group = "Git [H]unk", mode = { "n", "v" } },
		{ "gr", group = "LSP Actions", mode = { "n" } },
	},
})

-- Adds indentation guides even on blank lines
vim.pack.add({ gh("lukas-reineke/indent-blankline.nvim") })
require("ibl").setup({})

-- [[ Colorscheme ]]
-- Load the colorscheme here. (Lives in colors/cyberpunk.* in this config folder.)
-- vim.cmd.colorscheme("cyberpunk")

vim.pack.add({ gh("folke/snacks.nvim") })
require("snacks").setup({
	picker = { enabled = true }, -- the default dashboard keys call Snacks.dashboard.pick()
	dashboard = {
		enabled = true,
		preset = {
			header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
		},
		sections = {
			{ section = "header" },
			{ section = "keys", gap = 1, padding = 1 },
			{ icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
			{ icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
		},
	},
})

--  A collection of various small independent plugins/modules
vim.pack.add({ gh("nvim-mini/mini.nvim") })

-- If a nerd font is available, load the icons module for pretty icons in various plugins.
if vim.g.have_nerd_font then
	require("mini.icons").setup()
	-- Used for backwards compatibility with plugins that require `nvim-web-devicons` (e.g. telescope.nvim)
	MiniIcons.mock_nvim_web_devicons()
end

-- Better Around/Inside textobjects
require("mini.ai").setup({
	mappings = {
		around_next = "aa",
		inside_next = "ii",
	},
	n_lines = 500,
})

vim.pack.add({ gh("nvim-lualine/lualine.nvim") })
require("lualine").setup({
	options = {
		theme = "auto",
		--Filetypes to disable lueline for, Status Line doesn't appear on file tree window
		disabled_filetypes = {
			statusline = { "neo-tree" },
		},
	},
	--Sections that are shown on the status line of the active window
	sections = {
		lualine_a = { "mode" },
		lualine_b = { { "filename", path = 3 } },
		lualine_c = { "branch", "diff", "diagnostics" },
		lualine_x = { "filetype" },
		lualine_y = { "filesize" },
		lualine_z = { "location" },
	},
	--Sections that are shown on the status line of inactive windows
	inactive_sections = {
		lualine_a = { { "filename", path = 3 } },
		lualine_b = { "branch" },
		lualine_c = {},
		lualine_x = { "filetype" },
		lualine_y = { "filesize" },
		lualine_z = { "location" },
	},
	--Tabline that shows Tab Number and Name
	tabline = {
		lualine_a = {
			{
				"tabs",
				mode = 2,
				use_mode_colors = true,
			},
		},
	},
})
