{
  description = "A collection of Nix flake templates for Rust projects.";

  outputs = { self, nixpkgs }: {

    # Useful when composing with other flakes:
    overlays.default = import ./overlay.nix;

    templates.default = self.templates.cross-arch;

    templates = {
      cross-arch = {
        description = "Basic Rust project with cross-compilation support.";
        path =
          builtins.filterSource (path: type: baseNameOf path == "flake.nix")
            ./templates/cross-arch;
      };
    };
  };
}
