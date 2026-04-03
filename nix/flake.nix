{
  description = "ma.uchida's development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        commonPackages = with pkgs; [
          # Core
          git
          gh
          jq
          wget
          direnv
          just

          # Development
          go
          neovim
          mise          # language version manager (Ruby, Python, Node, etc.)
          openjdk

          # Infrastructure
          terraform
          aws-vault

          # Shell
          starship
          zsh-autosuggestions

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

        # Load secrets from 1Password via op read
        # Usage: opLoad <VAR_NAME> <op://vault/item/field>
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
          else
            echo "[warn] 1Password CLI not signed in — secrets not loaded. Run: eval \$(op signin)"
          fi
        '';

        makeShell = extraSecrets: pkgs.mkShell {
          packages = commonPackages ++ [ pkgs._1password-cli ];

          OBJC_DISABLE_INITIALIZE_FORK_SAFETY = "YES";
          PODMAN_COMPOSE_WARNING_LOGS = "false";
          JAVA_HOME = "${pkgs.openjdk}";

          shellHook = ''
            ${opLoader}
            ${commonSecrets}
            ${extraSecrets}

            # Symlink dotfiles configs



            # Aliases
            alias be='bundle exec'
            alias p-c='podman compose'

            # Init tools
            eval "$(mise activate bash)"
            mise direnv activate
            eval "$(starship init bash)"
            eval "$(direnv hook bash)"
          '';
        };

      in {
        devShells = {
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
      }
    );
}
