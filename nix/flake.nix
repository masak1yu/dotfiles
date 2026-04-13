{
  description = "msky's development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin }:
    let
      system = "aarch64-darwin";
      username = let u = builtins.getEnv "SUDO_USER"; in if u != "" then u else builtins.getEnv "USER";
      homeDir = "/Users/${username}";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (final: prev: {
            # Poppler: GObject Introspection typelib を有効にする（Ruby poppler gem 用）
            poppler = prev.poppler.override {
              introspectionSupport = true;
              gobject-introspection = prev.gobject-introspection;
            };
          })
        ];
      };

      commonPackages = with pkgs; [
        # Core
        git
        gh
        jq
        wget
        direnv
        just
        lazygit

        # Development
        go
        neovim
        mise
        openjdk

        # Infrastructure
        terraform
        aws-vault

        # Shell
        starship
        zsh-autosuggestions

        # Libraries
        libyaml
        zstd
        libffi
        openssl
        openssl.dev
        curl

        # DB clients / servers
        mysql80
        postgresql_14
        redis
        apacheKafka

        # Media / graphics
        imagemagick
        graphviz
        librsvg
        poppler
        cairo
        pango
        gdk-pixbuf

        # GUI / rendering
        gobject-introspection
        qt6.qtbase
        pkg-config

        # TLS / certs
        mkcert

        # Build / release
        goreleaser

        # Build tools
        cmake

        # Test / browser
        chromedriver

      ];

      opLoader = ''
        _op_load() {
          local var="$1" ref="$2"
          local val
          if val=$(op read "$ref" 2>/dev/null); then
            export "$var=$val"
          fi
        }
      '';

      commonSecrets = ''
        if command -v op &>/dev/null && op whoami &>/dev/null 2>&1; then
          _op_load GITHUB_TOKEN         "op://Personal/dotfiles-env/GITHUB_TOKEN"
          _op_load BUNDLE_GITHUB__COM   "op://Personal/dotfiles-env/BUNDLE_GITHUB__COM"
          _op_load AWS_ASSUME_ROLE_TTL  "op://RAKSUL/dotfiles-env/AWS_ASSUME_ROLE_TTL"
          _op_load KAFKA_HEAP_OPTS      "op://RAKSUL/dotfiles-env/KAFKA_HEAP_OPTS"
          _op_load BOOTSTRAP_SERVER_270 "op://RAKSUL/dotfiles-env/BOOTSTRAP_SERVER_270"
          _op_load BOOTSTRAP_SERVER_351 "op://RAKSUL/dotfiles-env/BOOTSTRAP_SERVER_351"
          _op_load DATADOG_ENABLED      "op://RAKSUL/dotfiles-env/DATADOG_ENABLED"
          _op_load AWS_ACCESS_KEY_ID    "op://RAKSUL/dotfiles-env/AWS_ACCESS_KEY_ID"
          _op_load AWS_SECRET_ACCESS_KEY "op://RAKSUL/dotfiles-env/AWS_SECRET_ACCESS_KEY"
          _op_load AWS_DEFAULT_REGION   "op://RAKSUL/dotfiles-env/AWS_DEFAULT_REGION"
          _op_load AWS_MFA_SERIAL       "op://RAKSUL/dotfiles-env/AWS_MFA_SERIAL"
        fi
      '';

      # librdkafka 2.5.3 は OpenSSL 3.6 と非互換（ENGINE API 削除 + rand.h 暗黙 include 削除）
      # devShell のビルド用に OpenSSL 3.0 LTS を使う
      opensslBuild = pkgs.openssl_3;

      # macOS Nix Qt6 はフレームワーク形式のため、ruby-qt6 の extconf が
      # 期待する -lQt6Core / include/QtCore/QEvent が見つからない。
      # フレームワーク→通常形式のシンボリックリンクで橋渡しする。
      qt6Compat = pkgs.runCommand "qt6-compat" {} ''
        mkdir -p $out/lib $out/include
        for fw in ${pkgs.qt6.qtbase.out}/lib/Qt*.framework; do
          name=$(basename "$fw" .framework)
          ln -s "$fw/$name" "$out/lib/lib''${name/Qt/Qt6}.dylib"
          ln -s "$fw/Headers" "$out/include/$name"
        done
      '';

      makeShell = extraSecrets: pkgs.mkShell {
        # ビルドツール（pkg-config の setup hook が buildInputs の
        # lib/pkgconfig を自動的に PKG_CONFIG_PATH へ追加する）
        nativeBuildInputs = with pkgs; [
          _1password-cli
          pkg-config
        ];

        # ライブラリ — pkg-config が .pc を自動検出する
        buildInputs = with pkgs; [
          # DB
          postgresql_14.pg_config
          mysql80

          # 汎用ライブラリ
          libyaml
          libyaml.dev
          libffi
          libffi.dev
          zstd
          curl

          # Ruby-GNOME (cairo / pango / gdk-pixbuf)
          cairo
          pango
          gdk-pixbuf
          glib
          gobject-introspection
          librsvg
          poppler

          # Ruby-GNOME の .pc Requires.private 推移的依存
          # （Ruby pkg-config gem がシステム pkg-config と違い全ツリーを解決するため必要）
          freetype
          fontconfig
          libpng
          pixman
          zlib
          harfbuzz
          expat
          pcre2
          fribidi
          libthai
          libdatrie
          libsysprof-capture

          # cairo.pc Requires.private: X11（ビルド時のみ、実行時不使用）
          libX11
          libXext
          libXrender
          libxcb
          libXdmcp
          libXau
          xorgproto

          # Qt6
          qt6.qtbase
        ];

        OBJC_DISABLE_INITIALIZE_FORK_SAFETY = "YES";
        PODMAN_COMPOSE_WARNING_LOGS = "false";
        JAVA_HOME = "${pkgs.openjdk}";

        # Ruby native extensions のビルドパス
        BUNDLE_BUILD__PG = "--with-pg-config=${pkgs.postgresql_14.pg_config}/bin/pg_config";
        BUNDLE_BUILD__MYSQL2 = "--with-mysql-config=${pkgs.mysql80}/bin/mysql_config";
        BUNDLE_BUILD__PSYCH = "--with-libyaml-include=${pkgs.libyaml.dev}/include --with-libyaml-lib=${pkgs.libyaml.out}/lib";
        BUNDLE_BUILD__FFI = "--with-libffi-dir=${pkgs.libffi.dev}";

        # ruby-qt6 extconf 用: フレームワーク形式→通常形式シンボリックリンク
        QT_INSTALL_HEADERS = "${qt6Compat}/include";
        QT_INSTALL_LIBS = "${qt6Compat}/lib";

        # OpenSSL 3.0 ヘッダーパス（librdkafka 2.5.3 互換）
        CPPFLAGS = "-I${opensslBuild.dev}/include";

        # リンカフラグ（zstd + openssl + Qt6 フレームワーク検索パス）
        # リンカフラグ（openssl_3 は rpath で直接埋め込み、他パッケージの 3.6 と衝突させない）
        LDFLAGS = "-L${pkgs.zstd.out}/lib -L${opensslBuild.out}/lib -Wl,-rpath,${opensslBuild.out}/lib -L${pkgs.curl.out}/lib -F${pkgs.qt6.qtbase.out}/lib";

        # Fontconfig 設定ファイル（Nix 環境ではシステムデフォルトが見つからない）
        FONTCONFIG_FILE = "${pkgs.fontconfig.out}/etc/fonts/fonts.conf";

        # GObject Introspection typelib 検索パス（Ruby poppler/rsvg2 gem 用）
        GI_TYPELIB_PATH = builtins.concatStringsSep ":" [
          "${pkgs.poppler.out}/lib/girepository-1.0"
          "${pkgs.gobject-introspection}/lib/girepository-1.0"
        ];

        # ランタイムライブラリパス
        DYLD_LIBRARY_PATH = builtins.concatStringsSep ":" [
          "${pkgs.libyaml.out}/lib"
          "${pkgs.libffi.out}/lib"
          "${pkgs.zstd.out}/lib"
          "${pkgs.cairo.out}/lib"
          "${pkgs.pango.out}/lib"
          "${pkgs.gdk-pixbuf.out}/lib"
          "${pkgs.glib.out}/lib"
          "${pkgs.gobject-introspection}/lib"
          "${pkgs.librsvg.out}/lib"
          "${pkgs.poppler.out}/lib"
          "${pkgs.qt6.qtbase.out}/lib"
          "${pkgs.openssl.out}/lib"
          "${pkgs.curl.out}/lib"
        ];

        shellHook = ''
          ${opLoader}
          ${commonSecrets}
          ${extraSecrets}

          # Aliases
          alias be='bundle exec'
          alias p-c='podman compose'

        '';
      };

    in {
      darwinConfigurations.macbook = nix-darwin.lib.darwinSystem {
        modules = [
          ({ pkgs, ... }: {
            nixpkgs.hostPlatform = system;
            nixpkgs.config.allowUnfree = true;
            system.primaryUser = username;

            environment.systemPackages = commonPackages;

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

            # MySQL 8.0 自動起動
            launchd.daemons.mysql = {
              serviceConfig = {
                Label = "com.nix.mysql";
                ProgramArguments = [
                  "${pkgs.mysql80}/bin/mysqld"
                  "--user=${username}"
                  "--datadir=${homeDir}/.mysql/data"
                  "--socket=/tmp/mysql.sock"
                  "--port=3306"
                ];
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
      };

      devShells.${system} = {
        # Default shell — no Datadog keys
        default = makeShell "";

        # QA environment with Datadog QA keys
        datadog-qa = makeShell ''
          if command -v op &>/dev/null && op whoami &>/dev/null 2>&1; then
            _op_load TF_VAR_datadog_api_key "op://Personal/datadog-qa/TF_VAR_datadog_api_key"
            _op_load TF_VAR_datadog_app_key "op://Personal/datadog-qa/TF_VAR_datadog_app_key"
          fi
        '';

        # Production environment with Datadog prod keys
        datadog-prod = makeShell ''
          if command -v op &>/dev/null && op whoami &>/dev/null 2>&1; then
            _op_load TF_VAR_datadog_api_key "op://Personal/datadog-prod/TF_VAR_datadog_api_key"
            _op_load TF_VAR_datadog_app_key "op://Personal/datadog-prod/TF_VAR_datadog_app_key"
          fi
        '';
      };
    };
}
