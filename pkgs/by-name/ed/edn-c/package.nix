{
  lib,
  stdenv,
  fetchFromGitHub,
  closureExtension ? false,
  experimentalExtension ? false,
}:

stdenv.mkDerivation {
  pname = "edn.c";
  version = "0-unstable-2026-11-02";
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "DotFox";
    repo = "edn.c";
    rev = "50a584b6ad688be6ceec89ca2c18a71548c00508";
    hash = "sha256-YrEyaqoZdg7XXhnUQJbFuSdo8X/gV+2LM9PGnJNE4AE=";
  };

  strictDeps = true;

  outputs = [
    "out"
    "dev"
    "lib"
  ];

  makeFlags = [
    # https://github.com/DotFox/edn.c/issues/25
    "ARCH_FLAGS=${lib.optionalString stdenv.hostPlatform.sse4_2Support "-msse4.2"}"
  ]
  ++ lib.optional closureExtension "CLOJURE_EXTENSION=1"
  ++ lib.optional experimentalExtension "EXPERIMENTAL_EXTENSION=1";

  # `all` builds libedn.a; `shared` builds libedn.so (so `all` isn’t “all”)
  buildFlags = [
    "all"
    "shared"
  ];

  doCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;

  checkTarget = "test";

  installPhase = ''
    runHook preInstall

    install -m444 -Dt "$lib/lib" libedn.so
    install -m444 -Dt "$lib/lib" libedn.a
    install -m444 -Dt "$dev/include" include/edn.h
    install -m444 -Dt "$out/share/licenses/edn.c" LICENSE

    runHook postInstall
  '';

  meta = {
    description = "Fast, zero-copy EDN (Extensible Data Notation) reader and writer written in C11 with SIMD acceleration";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    # https://github.com/DotFox/edn.c/issues/26
    broken = [ "aarch64-linux" "aarch64-darwin" ];
    maintainers = with lib.maintainers; [ toastal ];
  };
}
