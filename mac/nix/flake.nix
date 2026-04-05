{
  description = "ma.uchida's development environment";

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

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      commonPackages = with pkgs; [
        # Core
        claude-code
        git
        gh
        jq
        wget
        direnv
        just

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

        # DB clients / servers
        mysql80
        postgresql_14
        redis
        apacheKafka

        # Media / graphics
        imagemagick
        graphviz

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
          _op_load AWS_ASSUME_ROLE_TTL  "op://Personal/dotfiles-env/AWS_ASSUME_ROLE_TTL"
          _op_load KAFKA_HEAP_OPTS      "op://Personal/dotfiles-env/KAFKA_HEAP_OPTS"
          _op_load BOOTSTRAP_SERVER_270 "op://Personal/dotfiles-env/BOOTSTRAP_SERVER_270"
          _op_load BOOTSTRAP_SERVER_351 "op://Personal/dotfiles-env/BOOTSTRAP_SERVER_351"
          _op_load DATADOG_ENABLED      "op://Personal/dotfiles-env/DATADOG_ENABLED"
          _op_load AWS_ACCESS_KEY_ID    "op://Personal/dotfiles-env/AWS_ACCESS_KEY_ID"
          _op_load AWS_SECRET_ACCESS_KEY "op://Personal/dotfiles-env/AWS_SECRET_ACCESS_KEY"
          _op_load AWS_DEFAULT_REGION   "op://Personal/dotfiles-env/AWS_DEFAULT_REGION"
          _op_load AWS_MFA_SERIAL       "op://Personal/dotfiles-env/AWS_MFA_SERIAL"
        fi
      '';

      makeShell = extraSecrets: pkgs.mkShell {
        # devShell の依存に含めることで nix が確実にビルド/ダウンロードする
        packages = with pkgs; [
          _1password-cli
          postgresql_14.pg_config
          mysql80
          libyaml
          libyaml.dev
          libffi
          libffi.dev
          zstd
        ];

        OBJC_DISABLE_INITIALIZE_FORK_SAFETY = "YES";
        PODMAN_COMPOSE_WARNING_LOGS = "false";
        JAVA_HOME = "${pkgs.openjdk}";

        # Ruby native extensions のビルドパス（nix evaluation 時に解決）
        BUNDLE_BUILD__PG = "--with-pg-config=${pkgs.postgresql_14.pg_config}/bin/pg_config";
        BUNDLE_BUILD__MYSQL2 = "--with-mysql-config=${pkgs.mysql80}/bin/mysql_config";
        BUNDLE_BUILD__PSYCH = "--with-libyaml-include=${pkgs.libyaml.dev}/include --with-libyaml-lib=${pkgs.libyaml.out}/lib";
        BUNDLE_BUILD__FFI = "--with-libffi-dir=${pkgs.libffi.dev}";
        LDFLAGS = "-L${pkgs.zstd.out}/lib";

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
                "filezilla"
                "karabiner-elements"
              ];
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
