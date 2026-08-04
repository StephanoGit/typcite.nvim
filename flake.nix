{
  description = "Capture a citation from anything, in one keystroke";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      overlays.default = final: prev: {
        vimPlugins = prev.vimPlugins // {
          typcite-nvim = final.vimUtils.buildVimPlugin {
            pname = "typcite.nvim";
            version = "0.1.0";
            src = self;

            # fails the build if `require("typcite")` does not load
            nvimRequireCheck = "typcite";

            meta = {
              description = "Capture a citation from anything, in one keystroke";
              homepage = "https://github.com/stephanogit/typcite.nvim";
              license = final.lib.licenses.mit;
              platforms = final.lib.platforms.all;
            };
          };
        };
      };

      packages = forAllSystems (pkgs: rec {
        typcite-nvim =
          (pkgs.extend self.overlays.default).vimPlugins.typcite-nvim;
        default = typcite-nvim;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.neovim
            pkgs.lua51Packages.lua
            pkgs.stylua
            pkgs.lua-language-server
            pkgs.curl
            pkgs.python3Packages.pdf2doi
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt);
    };
}
