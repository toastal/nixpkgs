{
  lib,
  stdenv,
  fetchFromGitHub,
  python3Packages,
  unstableGitUpdater,
}:

python3Packages.buildPythonPackage {
  pname = "edl";
  version = "3.52.1-unstable-2026-05-13";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "bkerler";
    repo = "edl";
    rev = "51e11022455d26bcf0b8305b930c474e9b3c81ad";
    fetchSubmodules = true;
    hash = "sha256-0K1GeaVXINhdUua7jgQsZwFfkwO3Q00+obD5TOlVAO4=";
  };

  nativeBuildInputs = with python3Packages; [
    setuptools
  ];

  propagatedBuildInputs = with python3Packages; [
    pyusb
    pyserial
    docopt
    pycryptodome
    lxml
    colorama
    pylzma
    requests
    passlib
  ];

  # No tests set up
  doCheck = false;
  # EDL loaders are ELFs but shouldn't be touched, rest is Python anyways
  dontStrip = true;

  # edl has spurious dependencies on “usb” (added by accident trying to add
  # pyusb) & “Exscript” (only used by auxiliary scripts, not main EDL)
  postPatch = ''
    sed -i '/'usb'/d' pyproject.toml
    sed -i '/'Exscript'/d' pyproject.toml
  '';

  postInstall = ''
    mkdir -p $out/etc/udev/rules.d
    cp $src/Drivers/51-edl.rules $out/etc/udev/rules.d/51-edl.rules
  '';

  passthru.updateScript = unstableGitUpdater { };

  meta = {
    homepage = "https://github.com/bkerler/edl";
    description = "Qualcomm EDL tool (Sahara / Firehose / Diag)";
    # See https://github.com/NixOS/nixpkgs/issues/348931
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [
      lorenz
      xddxdd
    ];
    # Case-sensitive files in 'Loader' submodule
    broken = stdenv.hostPlatform.isDarwin;
  };
}
