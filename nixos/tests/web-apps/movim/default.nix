{ recurseIntoAttrs, runTest }:

recurseIntoAttrs {
  ejabberd-h2o = runTest ./prosody-nginx.nix;
  prosody-nginx = runTest ./prosody-nginx.nix;
}
