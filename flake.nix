{
  description = "Starknet and Cairo Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Versions for Scarb and Starknet Foundry
        scarbVersion = "2.18.0"; # Update to the latest version required
        snFoundryVersion = "0.61.0"; # Update to the latest version required
        devnetVersion = "0.8.1"; # Latest stable release
        uscVersion = "2.8.0"; # Latest stable USC version

        # Fetch and patch Scarb pre-compiled binary for Linux
        scarb = pkgs.stdenv.mkDerivation {
          pname = "scarb";
          version = scarbVersion;

          src = pkgs.fetchurl {
            # FIX: Restored the proper upstream download link for Scarb
            url = "https://github.com/software-mansion/scarb/releases/download/v${scarbVersion}/scarb-v${scarbVersion}-x86_64-unknown-linux-gnu.tar.gz";
            # sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
            sha256 = "sha256-joDEAX/tgEdWkkdDH7UiOPTIfjSAjftPR17RS/DprTk=";
          };

          nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper ];
          buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.openssl ];

          installPhase = ''
            mkdir -p $out/bin
            cp -r * $out/
            mv $out/bin/scarb $out/bin/.scarb-wrapped

            # Create a wrapper to ensure core tools like git are available to Scarb
            makeWrapper $out/bin/.scarb-wrapped $out/bin/scarb \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.git pkgs.curl ]}
          '';
        };

        # Fetch and patch Starknet Foundry (snforge & sncast)
        starknet-foundry = pkgs.stdenv.mkDerivation {
          pname = "starknet-foundry";
          version = snFoundryVersion;

          src = pkgs.fetchurl {
            # FIX: Changed '-env.tar.gz' to '-gnu.tar.gz' at the end of the URL
            url = "https://github.com/foundry-rs/starknet-foundry/releases/download/v${snFoundryVersion}/starknet-foundry-v${snFoundryVersion}-x86_64-unknown-linux-gnu.tar.gz";
            # Dummy hash so Nix can pull it and throw the real hash error we need
            # sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
            sha256 = "sha256-/dO12bWpJ6McpFCIscmoIFGfiy0syTGT15C81ezpNZs=";

          };

          nativeBuildInputs = [ pkgs.autoPatchelfHook ];
          buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.openssl pkgs.curl ];

          # The archive extracts into a root folder, copy the binaries from its bin directory
          installPhase = ''
            mkdir -p $out/bin
            cp -r bin/* $out/bin/
          '';
        };

        # Fetch and patch starknet-devnet
        starknet-devnet = pkgs.stdenv.mkDerivation {
          pname = "starknet-devnet";
          version = devnetVersion;
          src = pkgs.fetchurl {
            url = "https://github.com/0xSpaceShard/starknet-devnet/releases/download/v${devnetVersion}/starknet-devnet-x86_64-unknown-linux-gnu.tar.gz";
            sha256 = "sha256-fCWeo+fE6iMn2HyBlxgqj1xW5sFI1n3I/8qQthE8zW4=";
          };

          # FIX: Prevents Nix from complaining about no root directory in the tarball
          sourceRoot = ".";

          nativeBuildInputs = [ pkgs.autoPatchelfHook ];
          buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.openssl ];

          installPhase = ''
            mkdir -p $out/bin
            # Copies the binary from the top-level extract location
            cp starknet-devnet $out/bin/
          '';
        };

        # Compile universal-sierra-compiler from source
        universal-sierra-compiler = pkgs.rustPlatform.buildRustPackage {
          pname = "universal-sierra-compiler";
          version = uscVersion;

          # Pull the actual source code repository instead of a compiled asset
          src = pkgs.fetchFromGitHub {
            owner = "software-mansion";
            repo = "universal-sierra-compiler";
            rev = "v${uscVersion}";
            # Cryptographic hash of the source code archive for v2.8.0
            sha256 = "sha256-t4Y+dd0CzJZP/O+DI4jJGMnNwh+s7gftCBim9NyCJuM=";
          };

          # Nix requires a separate hash for the isolated Cargo dependencies
          cargoHash = "sha256-KQI05ePOld6E7lOztoAg7pCvfBTIQB4hQeczeLhXKlg=";

          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = [ pkgs.openssl ];

          # buildRustPackage automatically handles the cargo build,
          # testing phases, and binary generation/linking out-of-the-box!
        };

        in
      {
        devShells.default = pkgs.mkShell {
          name = "starknet-dev-shell";

          # Packages placed here will be available in your path
          buildInputs = with pkgs; [
            # Core dependencies for Cairo/Starknet tools
            scarb
            starknet-foundry
            starknet-devnet
            universal-sierra-compiler
            git
            curl
            openssl
            pkg-config

            # Node.js (often needed for starknet.js or deployment scripts)
            nodejs_latest
          ];

          shellHook = ''
            echo "⚡ Welcome to the Starknet & Cairo Development Environment ⚡"
            echo "Scarb version:   $(scarb --version | head -n 1)"
            echo "Forge version:   $(snforge --version 2>/dev/null || echo 'Loading...')"
            echo "Devnet version:  $(starknet-devnet --version 2>/dev/null || echo 'Loading...')"

            export SCARB_CACHE_HOME="$PWD/.cache/scarb"
          '';
        };
      });
}
