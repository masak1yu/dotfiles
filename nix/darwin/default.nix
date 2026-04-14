{ pkgs, username, homeDir, commonPackages }:

{
  modules = [
    ({ pkgs, ... }: {
      nixpkgs.hostPlatform = "aarch64-darwin";
      nixpkgs.config.allowUnfree = true;
      system.primaryUser = username;

      environment.systemPackages = commonPackages ++ (with pkgs; [
        apacheKafka
      ]);

      homebrew = {
        enable = true;
        onActivation.cleanup = "uninstall";
        casks = [
          "firefox"
          "google-chrome"
          "slack"
          "visual-studio-code"
          "ghostty"
          "zed"
          "vivaldi"
          "karabiner-elements"
        ];
      };

      nix.enable = false;

      # MySQL 8.0 自動起動（初回はデータディレクトリを自動初期化）
      launchd.daemons.mysql = let
        mysqlDataDir = "${homeDir}/.mysql/data";
        mysqlStartScript = pkgs.writeShellScript "mysql-start" ''
          if [ ! -d "${mysqlDataDir}/mysql" ]; then
            mkdir -p "${mysqlDataDir}"
            chown ${username} "${homeDir}/.mysql" "${mysqlDataDir}"
            ${pkgs.mysql80}/bin/mysqld --initialize-insecure --user=${username} --datadir=${mysqlDataDir}
          fi
          exec ${pkgs.mysql80}/bin/mysqld --user=${username} --datadir=${mysqlDataDir} --socket=/tmp/mysql.sock --port=3306
        '';
      in {
        serviceConfig = {
          Label = "com.nix.mysql";
          ProgramArguments = [ "${mysqlStartScript}" ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "${homeDir}/.mysql/mysql.log";
          StandardErrorPath = "${homeDir}/.mysql/mysql.error.log";
        };
      };

      programs.zsh.enable = true;

      system.stateVersion = 5;
    })
  ];
}
