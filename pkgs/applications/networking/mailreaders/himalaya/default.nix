{ lib
, rustPlatform
, fetchFromGitHub
, stdenv
, pkg-config
, installShellFiles
, installShellCompletions ? stdenv.hostPlatform == stdenv.buildPlatform
, installManPages ? stdenv.hostPlatform == stdenv.buildPlatform
, notmuch
, gpgme
, buildNoDefaultFeatures ? false
, buildFeatures ? []
}:

let
  pname = "himalaya";
  version = "1.0.0-beta.2";
in
rustPlatform.buildRustPackage {
  pname = pname;
  version = version;

  src = fetchFromGitHub {
    owner = "soywod";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-dLj/bEPz3SD1v54yXbtVdUJKQsyw0OJxmQh10ql+3iI=";
  };

  cargoSha256 = "0IYpuKq5amAcYtsDMzJGghbxkuldAulsgUmChTl2DIg=";

  buildNoDefaultFeatures = buildNoDefaultFeatures;
  buildFeatures = buildFeatures;

  nativeBuildInputs = [ ]
    ++ lib.lists.optional (lib.lists.elem "pgp-gpg" buildFeatures) pkg-config
    ++ lib.lists.optional (installManPages || installShellCompletions) installShellFiles;

  buildInputs = [ ]
    ++ lib.lists.optional (lib.lists.elem "notmuch" buildFeatures) notmuch
    ++ lib.lists.optional (lib.lists.elem "pgp-gpg" buildFeatures) gpgme;

  postInstall = lib.strings.optionalString installManPages ''
    mkdir -p $out/man
    $out/bin/himalaya man $out/man
    installManPage $out/man/*
  '' + lib.strings.optionalString installShellCompletions ''
    installShellCompletion --cmd himalaya \
      --bash <($out/bin/himalaya completion bash) \
      --fish <($out/bin/himalaya completion fish) \
      --zsh <($out/bin/himalaya completion zsh)
  '';

  meta = with lib; {
    description = "CLI to manage emails";
    homepage = "https://pimalaya.org/himalaya/cli/latest/";
    changelog = "https://github.com/soywod/himalaya/blob/v${version}/CHANGELOG.md";
    license = licenses.mit;
    maintainers = with maintainers; [ soywod toastal yanganto ];
  };
}
