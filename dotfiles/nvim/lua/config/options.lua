-- ============================================================
-- SECTION 1: OPTIONS
-- (vim.loader.enable() moved to the top of init.lua)
-- ============================================================

vim.cmd("set shortmess+=I")

-- Set <space> as the leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

--Enables nerd font
vim.g.have_nerd_font = true

-- Enables line numbers, relative line numbers, displays them both
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.statuscolumn = "%s %{v:lnum} %{v:relnum}"

-- Enable mouse mode
vim.o.mouse = "a"

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

-- Sync clipboard between OS and Neovim.
vim.schedule(function()
	vim.o.clipboard = "unnamedplus"
end)

-- Enable break indent, wrapped lines align to identation
vim.o.breakindent = true

-- Enable undo/redo changes even after closing and reopening a file
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = "no"

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Preview substitutions live, as they're typed
vim.o.inccommand = "split"

-- Highlights the active line
vim.o.cursorline = true

-- Confirm unsaved changes when exiting
vim.o.confirm = true

-- Sets indent size
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
