{ lib, runTest }:
lib.recurseIntoAttrs {
  default = runTest ./default.nix;
}
