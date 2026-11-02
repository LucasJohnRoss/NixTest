-- ============================================================
-- SECTION 2: KEYMAPS & AUTOCMDS
-- (Plugin-specific keymaps live with their plugin: Telescope in
--  navigation.lua, LSP in lsp.lua, format in formatting.lua.)
-- ============================================================

-- [[ Basic Keymaps ]]
-- Changes command key from : to ;
vim.keymap.set("n", ";", ":")

-- Diagnostic Config & Keymaps
vim.diagnostic.config({
	update_in_insert = false,
	severity_sort = true,
	float = { border = "rounded", source = "if_many" },
	underline = { severity = { min = vim.diagnostic.severity.WARN } },
	virtual_text = true, -- Text shows up at the end of the line
	virtual_lines = false, -- Text shows up underneath the line, with virtual lines
})

-- Exit terminal mode in the builtin terminal with a shortcut
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Disables arrow keys in normal mode
vim.keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

--[Windows]
-- Create Horizontal and Veritcal Splits
vim.keymap.set("n", "<leader>ws", ":split<CR>", { desc = "Open Horizontal Split" })
vim.keymap.set("n", "<leader>wv", ":vsplit<CR>", { desc = "Open Vertical Split" })
--  Focus Windows
vim.keymap.set("n", "<leader>wh", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<leader>wl", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<leader>wj", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<leader>wk", "<C-w><C-k>", { desc = "Move focus to the upper window" })
-- Move the current split (leader + Shift+W + direction)
vim.keymap.set("n", "<leader>Wh", "<C-w>H", { desc = "Move split left" })
vim.keymap.set("n", "<leader>Wl", "<C-w>L", { desc = "Move split right" })
vim.keymap.set("n", "<leader>Wj", "<C-w>J", { desc = "Move split down" })
vim.keymap.set("n", "<leader>Wk", "<C-w>K", { desc = "Move split up" })
-- Resize the current split
vim.keymap.set("n", "<C-k>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
vim.keymap.set("n", "<C-j>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
vim.keymap.set("n", "<C-h>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
vim.keymap.set("n", "<C-l>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })

--[Tabs]
vim.keymap.set("n", "<leader>tn", ":tabnew<CR>", { desc = "Open New Tab" })
vim.keymap.set("n", "<leader>tq", ":tabclose<CR>", { desc = "Close current Tab" })
vim.keymap.set("n", "<leader>tl", ":tabnext<CR>", { desc = "Open Next Tab" })
vim.keymap.set("n", "<leader>th", ":tabprevious<CR>", { desc = "Open Previous Tab" })
vim.keymap.set("n", "<leader>wt", "<C-w>T", { desc = "Split to new tab" })
vim.keymap.set("n", "<leader>tr", function()
	vim.ui.input({ prompt = "Tab name: " }, function(name)
		if name and name ~= "" then
			vim.cmd("LualineRenameTab " .. name)
		end
	end)
end, { desc = "Rename current tab" })
for i = 1, 9 do
	vim.keymap.set("n", "<leader>t" .. i, i .. "gt", { desc = "Go to tab " .. i })
end

--[Movement]
--In Normal Mode
vim.keymap.set("n", "gl", "$", { desc = "Go to End of Line" })
vim.keymap.set("n", "gh", "0", { desc = "Go to Start of Line" })
vim.keymap.set("n", "gj", "G", { desc = "Go to Bottom Line" })
vim.keymap.set("n", "gk", "gg", { desc = "Go to Top Line" })
--In Visual Mode
vim.keymap.set("x", "gh", "^", { desc = "Start of line" })
vim.keymap.set("x", "gl", "$", { desc = "End of line" })
vim.keymap.set("x", "gj", "G", { desc = "Last line of file" })
vim.keymap.set("x", "gk", "gg", { desc = "First line of file" })

--[Indenting]
vim.keymap.set("n", ">", ">>", { desc = "Indent line right" })
vim.keymap.set("n", "<", "<<", { desc = "Indent line left" })
vim.keymap.set("x", ">", ">gv", { desc = "Indent selection right" })
vim.keymap.set("x", "<", "<gv", { desc = "Indent selection left" })

--[Word and Line Deletion]
vim.keymap.set("i", "<C-h>", "<C-w>", { desc = "Delete previous word (terminal fallback)" })

-- [[ Basic Autocommands ]]
-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.hl.on_yank()
	end,
})
