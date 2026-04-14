{ pkgs, commonPackages }:

{
  modules = [
    ({ pkgs, ... }: {
      nixpkgs.hostPlatform = "x86_64-linux";
      nixpkgs.config.allowUnfree = true;

      environment.systemPackages = commonPackages;

      programs.zsh.enable = true;

      system.stateVersion = "25.05";
    })
  ];
}
