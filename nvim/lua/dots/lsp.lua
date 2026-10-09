-- Language servers, all from Nix (modules/neovim.nix). Server defaults come
-- from nvim-lspconfig's lsp/*.lua; only what differs is set here.

-- Folders that hold data, runs, checkpoints, vendored code or agent
-- worktrees in these projects (hundreds of GB): never analysed.
local big_dirs = {
  "**/.git", "**/.claude", "**/.superpowers", "**/__pycache__", "**/node_modules",
  "**/data", "**/old_data", "**/runs", "**/runs_server", "**/results", "**/output",
  "**/legacy", "**/scratch", "**/third-party", "**/third_party", "**/build", "**/install", "**/log",
}

vim.lsp.config("*", {
  capabilities = require("blink.cmp").get_lsp_capabilities(),
})

vim.lsp.config("basedpyright", {
  -- package.xml first, so a ROS package inside a repo is its own root
  root_markers = { "package.xml", "pyrightconfig.json", "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
  -- Per-project interpreter and import paths (dots.python). Set on the live
  -- client and pushed to the server: basedpyright asks the client for its
  -- settings, and the client's copy is made before before_init would run.
  on_init = function(client)
    local p = require("dots.python").for_root(client.root_dir)
    client.settings = vim.tbl_deep_extend("force", client.settings or {}, {
      python = p.python and { pythonPath = p.python } or nil,
      basedpyright = { analysis = { extraPaths = p.extraPaths, typeCheckingMode = p.typeChecking } },
    })
    client:notify("workspace/didChangeConfiguration", { settings = client.settings })
  end,
  settings = {
    basedpyright = {
      disableOrganizeImports = true, -- ruff does it
      analysis = {
        diagnosticMode = "openFilesOnly",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        exclude = big_dirs,
        -- ruff owns lint (unused imports/variables, style) per each project's
        -- ruff config; basedpyright keeps types and undefined names, without
        -- the "unknown type" noise of lightly typed code
        disableTaggedHints = true,
        diagnosticSeverityOverrides = {
          reportUnusedImport = "none", reportUnusedVariable = "none",
          reportUnknownArgumentType = "none", reportUnknownMemberType = "none",
          reportUnknownVariableType = "none", reportUnknownParameterType = "none",
          reportUnknownLambdaType = "none", reportMissingTypeStubs = "none",
          reportMissingParameterType = "none", reportAny = "none", reportExplicitAny = "none",
        },
        inlayHints = { variableTypes = false, callArgumentNames = false, functionReturnTypes = false },
      },
    },
  },
})

-- ruff: lint + fixes + import sorting, using each project's own pyproject.toml.
vim.lsp.config("ruff", {
  on_attach = function(client) client.server_capabilities.hoverProvider = false end,
})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
      diagnostics = { globals = { "vim", "Snacks", "MiniIcons" } },
      telemetry = { enable = false },
    },
  },
})

vim.lsp.config("yamlls", { settings = { yaml = { keyOrdering = false } } })

vim.lsp.enable({
  "basedpyright", "ruff",    -- Python
  "yamlls", "jsonls", "taplo", -- configs (YAML calibrations, JSON, TOML)
  "lemminx",                 -- XML: URDF / xacro / MJCF / launch
  "marksman", "texlab",      -- Markdown reports, LaTeX papers
  "bashls", "lua_ls", "nixd", -- scripts, this config, the dotfiles
})

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = { spacing = 2, source = "if_many" },
  float = { border = "rounded", source = true },
  signs = true,
})

-- Neovim's defaults stay: K hover, grn rename, gra code action, grr
-- references, gri implementation, gO symbols, [d ]d diagnostics.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local function m(lhs, rhs, desc) vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc }) end
    m("gd", function() Snacks.picker.lsp_definitions() end, "definition")
    m("gD", vim.lsp.buf.declaration, "declaration")
    m("gr", function() Snacks.picker.lsp_references() end, "references")
    m("<leader>ca", vim.lsp.buf.code_action, "code action")
    m("<leader>cr", vim.lsp.buf.rename, "rename")
    m("<leader>cd", vim.diagnostic.open_float, "line diagnostics")
    m("<leader>cs", function() Snacks.picker.lsp_symbols() end, "symbols in file")
    m("<leader>cS", function() Snacks.picker.lsp_workspace_symbols() end, "symbols in project")
    m("<leader>cp", "<cmd>DotsPython<cr>", "which Python")
  end,
})
