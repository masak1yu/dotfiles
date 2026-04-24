{ pkgs, username, homeDir, commonPackages }:

{
  modules = [
    ({ pkgs, ... }: {
      nixpkgs.hostPlatform = "aarch64-darwin";
      nixpkgs.config.allowUnfree = true;
      system.primaryUser = username;

      environment.systemPackages = commonPackages ++ (with pkgs; [
        apacheKafka

        # Ruby build dependencies
        ruby_3_3  # mise が Ruby をビルドする際のホスト Ruby
        autoconf
        automake
        bison
        readline
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

      # PostgreSQL 14 自動起動（初回はデータディレクトリを自動初期化）
      launchd.daemons.postgresql = let
        pgDataDir = "${homeDir}/.postgresql/data";
        pgStartScript = pkgs.writeShellScript "postgresql-start" ''
          if [ ! -d "${pgDataDir}/base" ]; then
            mkdir -p "${pgDataDir}"
            chown ${username} "${homeDir}/.postgresql" "${pgDataDir}"
            ${pkgs.postgresql_14}/bin/initdb -D ${pgDataDir} -U postgres --no-locale -E UTF8
          fi
          exec ${pkgs.postgresql_14}/bin/postgres -D ${pgDataDir} -k /tmp -p 5432
        '';
      in {
        serviceConfig = {
          Label = "com.nix.postgresql";
          ProgramArguments = [ "${pgStartScript}" ];
          RunAtLoad = true;
          KeepAlive = true;
          UserName = username;
          StandardOutPath = "${homeDir}/.postgresql/postgresql.log";
          StandardErrorPath = "${homeDir}/.postgresql/postgresql.error.log";
        };
      };

      environment.variables = {
        RUBY_CONFIGURE_OPTS = "--with-baseruby=/run/current-system/sw/bin/ruby";
      };

      programs.zsh.enable = true;

      system.stateVersion = 5;
    })
  ];
}
