{ ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = true;
      command_timeout = 1000;
      # Directory scan default (30ms) is too low for large/slow dirs and logs a
      # "Scanning current directory timed out" warning; give it more headroom.
      scan_timeout = 50;

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      directory.truncation_length = 4;
      git_branch.symbol = " ";

      # The SDKMAN `current` java shim is slow (>1s) and times out the prompt;
      # skip the java version module entirely.
      java.disabled = true;
    };
  };
}
