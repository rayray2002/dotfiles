# Neovim: the editor, its plugins and the language servers all come from Nix,
# so every machine (including rootless snoopy) gets the same setup with
# nothing downloaded at runtime. The Lua config is nvim/lua/dots/ (docs:
# docs/neovim.md); per-project Python envs are in nvim/lua/dots/projects.lua.
{ lib, pkgs, ... }:
let
  treesitter = pkgs.vimPlugins.nvim-treesitter.withPlugins (p: with p; [
    python yaml json toml markdown markdown_inline latex bibtex xml bash
    lua luadoc vim vimdoc query cmake c cpp cuda dockerfile make nix ini csv
    gitcommit git_rebase diff regex
    commonlisp # also used for PDDL
  ]);
  # Debug adapter; the debugged program runs in the project's own env.
  debugpy = pkgs.python3.withPackages (ps: [ ps.debugpy ]);
in
{
  programs.neovim = {
    enable = true;
    package = pkgs.neovim-unwrapped;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withPython3 = false;
    withRuby = false;
    withNodeJs = false;

    plugins = with pkgs.vimPlugins; [
      tokyonight-nvim
      treesitter
      nvim-treesitter-textobjects # queries for mini.ai's function/class objects
      nvim-lspconfig              # server defaults for vim.lsp.enable
      blink-cmp
      friendly-snippets
      conform-nvim
      snacks-nvim
      mini-nvim
      oil-nvim
      which-key-nvim
      gitsigns-nvim
      diffview-nvim
      nvim-dap
      nvim-dap-python
      nvim-dap-view
      iron-nvim
      render-markdown-nvim
      claudecode-nvim
    ];

    # On Neovim's PATH only
    extraPackages = with pkgs; [
      basedpyright ruff
      yaml-language-server vscode-langservers-extracted taplo lemminx
      marksman texlab
      bash-language-server shellcheck shfmt
      lua-language-server stylua
      nixd
      jq ripgrep fd lazygit
    ];

    initLua = ''
      vim.g.dots_debugpy_python = "${debugpy}/bin/python"
      require("dots")
    '';
  };

  xdg.configFile."nvim/lua/dots".source = ../nvim/lua/dots;
}
