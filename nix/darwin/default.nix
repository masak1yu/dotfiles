{ pkgs, username, homeDir, commonPackages }:

{
  modules = [
    ({ pkgs, ... }:
    let
      # clang 18+ で追加された -Wdefault-const-init-field-unsafe が Ruby 3.2 ヘッダーで
      # エラーになる。thrift 等の extconf.rb は $CFLAGS を上書きするため CC/CFLAGS 環境変数
      # では回避できない。clang/clang++ という名前の wrapper を PATH 先頭に置いて全ての
      # native gem ビルドで透過的にフラグを抑制する。
      clangWrapper = pkgs.writeShellScriptBin "clang" ''
        exec ${pkgs.llvmPackages.clang}/bin/clang "$@" -Wno-default-const-init-field-unsafe -Wno-error=implicit-function-declaration -Wno-format-security
      '';
      clangppWrapper = pkgs.writeShellScriptBin "clang++" ''
        exec ${pkgs.llvmPackages.clang}/bin/clang++ "$@" -Wno-default-const-init-field-unsafe -Wno-error=implicit-function-declaration -Wno-format-security
      '';
      # extconf.rb は CC 変数または PATH 上の cc を使う。clang wrapper と同じフラグを透過的に渡す。
      ccWrapper = pkgs.writeShellScriptBin "cc" ''
        exec ${pkgs.llvmPackages.clang}/bin/clang "$@" -Wno-default-const-init-field-unsafe -Wno-error=implicit-function-declaration -Wno-format-security
      '';
    in {
      nixpkgs.hostPlatform = "aarch64-darwin";
      nixpkgs.config.allowUnfree = true;
      system.primaryUser = username;

      environment.systemPackages = commonPackages ++ [ clangWrapper clangppWrapper ccWrapper ] ++ (with pkgs; [
        apacheKafka

        # Ruby build dependencies
        ruby_3_3  # mise が Ruby をビルドする際のホスト Ruby
        autoconf
        automake
        bison
        readline

        # karafka-rdkafka が OpenSSL 3.x と互換性のない ENGINE API を使う librdkafka を
        # ソースからコンパイルしようとして失敗するため、Nix 管理の librdkafka を使う。
        # RDKAFKA_EXT_PATH を設定することでコンパイルをスキップできる。
        rdkafka
      ]);

      homebrew.enable = false;

      fonts.packages = with pkgs.nerd-fonts; [
        jetbrains-mono
        hack
        fira-code
      ];

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
          exec ${pkgs.mysql80}/bin/mysqld --user=${username} --datadir=${mysqlDataDir} --socket=/tmp/mysql.sock --port=3306 --mysqlx=0
        '';
      in {
        serviceConfig = {
          Label = "com.nix.mysql";
          ProgramArguments = [ "${mysqlStartScript}" ];
          RunAtLoad = true;
          KeepAlive = true;
          UserName = username;
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
        EDITOR = "vim";
        VISUAL = "vim";
        RUBY_CONFIGURE_OPTS = "--with-baseruby=/run/current-system/sw/bin/ruby";
        # Ruby 3.2+ の静的リンク時に -lresolv が要求されるが macOS 14.4+ で削除された。
        # Nix の libresolv を LIBRARY_PATH に追加して解決する。
        LIBRARY_PATH = "${pkgs.darwin.libresolv}/lib";
        # karafka-rdkafka が librdkafka をソースからコンパイルする際に OpenSSL 3.x の
        # ENGINE API 非互換でビルドが失敗する。Nix 管理の librdkafka を指定してコンパイルをスキップ。
        RDKAFKA_EXT_PATH = "${pkgs.rdkafka}";
      };

      # clang/clang++ wrapper を PATH 先頭に挿入する。
      # extconf.rb が $CFLAGS を上書きしても、clang 実行時に末尾フラグが追加されるため有効。
      # environment.systemPath は /etc/zshenv 経由で全シェル（非インタラクティブ含む）に適用される。
      environment.systemPath = [ "${clangWrapper}/bin" "${clangppWrapper}/bin" "${ccWrapper}/bin" ];

      programs.zsh.enable = true;

      system.stateVersion = 5;
    })
  ];
}
