-- ============================================================
-- Shared helpers used by several modules
-- ============================================================
local M = {}

---GitHub Macro Function: "owner/repo" -> full GitHub URL
---@param repo string
---@return string
function M.gh(repo)
	return "https://github.com/" .. repo
end

return M
