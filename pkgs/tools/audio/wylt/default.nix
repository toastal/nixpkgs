{ lib, buildGoPackage, fetchFromGitHub }:

buildGoPackage rec {
  pname = "wylt";
  version = "unstable-2020-01-25";

  goPackagePath = "github.com/kodi/wylt";

  src = fetchFromGitHub {
    owner = "kori";
    repo = "wylt";
    rev = "069bed0497a40e822cbb12088d072db30450753f";
    sha256 = "sha256-R5snXUV1DPPEA8A36cKz/r7Qg6A4SPs+SZNsCia+z/U=";
  };

  goDeps = ./deps.nix;

  meta = with lib; {
    description = "mpd listen submitter for ListenBrainz (formerly libra)";
    homepage = "https://github.com/kodi/wylt";
    license = with licenses; [ gpl3 ];
    platforms = platforms.unix;
    maintainers = with maintainers; [ toastal ];
  };
}
