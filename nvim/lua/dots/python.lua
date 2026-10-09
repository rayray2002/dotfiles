-- Which Python a buffer belongs to, for basedpyright, debugging and the REPL.
-- Order: the project table (dots.projects) > an activated env ($VIRTUAL_ENV,
-- or $CONDA_PREFIX unless it is the base) > <root>/.venv > nothing.
local M = {}

local function expand(p)
  return vim.fs.normalize(vim.fn.expand(p))
end

local function env_python(name)
  local root = vim.env.MAMBA_ROOT_PREFIX or expand("~/miniforge3")
  return root .. "/envs/" .. name .. "/bin/python"
end

-- Settings for a directory: { python, extraPaths, typeChecking, source }
function M.for_root(root)
  root = expand(root or vim.fn.getcwd())
  local best, best_len = nil, -1
  for _, p in ipairs(require("dots.projects")) do
    local r = expand(p.root)
    if (root == r or vim.startswith(root, r .. "/")) and #r > best_len then
      best, best_len = p, #r
    end
  end

  local out = { extraPaths = {}, typeChecking = "standard" }
  if best then
    out.python = best.python or (best.env and env_python(best.env))
    out.typeChecking = best.typeChecking or out.typeChecking
    out.source = "project " .. best.root
    for _, e in ipairs(best.extraPaths or {}) do
      table.insert(out.extraPaths, vim.startswith(e, "/") and e or vim.fs.normalize(root .. "/" .. e))
    end
  end
  if not out.python then
    local conda = vim.env.CONDA_PREFIX
    if vim.env.VIRTUAL_ENV then
      out.python, out.source = vim.env.VIRTUAL_ENV .. "/bin/python", "$VIRTUAL_ENV"
    elseif conda and conda ~= (vim.env.MAMBA_ROOT_PREFIX or "") and conda:match("/envs/") then
      out.python, out.source = conda .. "/bin/python", "$CONDA_PREFIX"
    elseif vim.uv.fs_stat(root .. "/.venv/bin/python") then
      out.python, out.source = root .. "/.venv/bin/python", ".venv"
    end
  end
  if out.python and not vim.uv.fs_stat(out.python) then
    out.missing = out.python
    out.python = nil
  end
  return out
end

-- For the current buffer: its LSP root if attached, else the cwd.
function M.current()
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    if (c.name == "basedpyright" or c.name == "ruff") and c.root_dir then
      return M.for_root(c.root_dir)
    end
  end
  return M.for_root(vim.fn.getcwd())
end

vim.api.nvim_create_user_command("DotsPython", function()
  local p = M.current()
  local lines = {
    "python: " .. (p.python or "(none; system default)") .. (p.source and ("  [" .. p.source .. "]") or ""),
    "extraPaths: " .. (#p.extraPaths > 0 and table.concat(p.extraPaths, ", ") or "-"),
    "typeChecking: " .. p.typeChecking,
  }
  if p.missing then table.insert(lines, "configured but missing: " .. p.missing) end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Python for this buffer" })
end, { desc = "Show the Python interpreter used for this buffer" })

return M
