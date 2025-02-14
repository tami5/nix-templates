{
  description = "Basic Setup C setup";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    utils.url =
      "github:numtide/flake-utils?rev=3cecb5b042f7f209c56ffd8371b2711a290ec797";
    flake-compat = {
      url =
        "github:edolstra/flake-compat?rev=b7547d3eed6f32d06102ead8991ec52ab0a4f1a7";
      flake = false;
    };
    devshell.url =
      "github:numtide/devshell?rev=7033f64dd9ef8d9d8644c5030c73913351d2b660";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    (inputs.utils.lib.eachDefaultSystem (system:
      let
        inherit (inputs.utils.lib) flattenTree mkApp;
        inherit (pkgs.stdenv) mkDerivation;
        name = "MYNAME";
        src = ./.;
        overlays = [ inputs.devshell.overlay ];
        pkgs = import nixpkgs { inherit system overlays; };
        version = builtins.substring 0 8 self.lastModifiedDate;
        common = {
          buildInputs = [ ];
          nativeBuildInputs = [ pkgs.autoreconfHook ];
        };
        checkscript = ''
          echo 'running some integration tests'
          [[ $(MYNAME) = 'Hello Nixers!' ]]
        '';
      in with pkgs; {
        defaultPackage = mkDerivation ({ inherit name src version; } // common);
        devShell = devshell.mkShell {
          imports = [ (devshell.importTOML ./devshell.toml) ];
          packages = common.buildInputs ++ common.nativeBuildInputs;
          env = [ ];
        };
        packages = flattenTree { ${name} = self.defaultPackage.${system}; };
        defaultApp = mkApp { drv = self.defaultPackage.${system}; };
        nixosModules = flattenTree {
          ${name} = { pkgs, ... }: {
            nixpkgs.overlays = [ ];
            environment.systemPackages = [ self.defaultPackage.${system} ];
            # systemd.services = { ... };
          };
        };
        checks = {
          # Additional tests, if applicable.
          test = stdenv.mkDerivation {
            name = "${name}-test-${version}";
            buildInputs = [ self.packages.${system}.${name} ];
            unpackPhase = "true";
            buildPhase = checkscript;
            installPhase = "mkdir -p $out";
          };
        };
        # │ error: attribute 'MYNAME' missing
        # // lib.optionalAttrs stdenv.isLinux {
        #   # A VM test of the NixOS module.
        #   vmTest = with import (nixpkgs + "/nixos/lib/testing-python.nix") { inherit system; };
        #     makeTest {
        #      nodes = { client = { ... }: { imports = [ self.nixosModules.${system}.${name} ]; }; };
        #       testScript = ''
        #         start_all()
        #         client.wait_for_unit("multi-user.target")
        #         client.succeed("MYNAME")
        #       '';
        #     };
        # };
      }));
}
