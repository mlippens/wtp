{
  description = "wtp: a CLI that simplifies git worktree workflows";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        version = self.shortRev or self.dirtyShortRev or "dev";
      in
      {
        packages.default = pkgs.buildGoModule {
          pname = "wtp";
          inherit version;
          src = self;
          vendorHash = "sha256-46gmkf5LYMivS0h3WeDF/QEJyjWlapJcbki0utBZiKk=";
          subPackages = [ "cmd/wtp" ];
          env.CGO_ENABLED = 0;
          ldflags = [
            "-s"
            "-w"
            "-X main.version=${version}"
            "-X main.commit=${self.rev or self.dirtyRev or "none"}"
          ];
          nativeCheckInputs = [ pkgs.git ];
          meta = {
            description = "A CLI that simplifies git worktree workflows";
            homepage = "https://github.com/satococoa/wtp";
            license = pkgs.lib.licenses.mit;
            mainProgram = "wtp";
          };
        };

        apps.default = flake-utils.lib.mkApp { drv = self.packages.${system}.default; };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.go
            pkgs.git
          ];
        };
      }
    );
}
