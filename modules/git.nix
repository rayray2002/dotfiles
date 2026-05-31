{ ... }:
{
  programs.git = {
    enable = true;
    userName = "rayray2002";
    userEmail = "rayray2002.huang@gmail.com";

    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
        side-by-side = true;
      };
    };

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };
}
