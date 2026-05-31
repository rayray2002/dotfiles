{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "rayray2002";
      user.email = "rayray2002.huang@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      side-by-side = true;
    };
  };
}
