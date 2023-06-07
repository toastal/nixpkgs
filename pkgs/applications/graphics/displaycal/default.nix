{ lib
, python311
, fetchFromGitHub
, fetchPypi
, wrapGAppsHook
, gtk3
, librsvg
, xorg
, argyllcms
}:

python311.pkgs.buildPythonApplication rec {
  pname = "displaycal";
  version = "3.9.11";
  format = "setuptools";
  #format = "wheel";
  #format = "other";

  #src = fetchPypi {
  #  pname = "DisplayCAL";
  #  inherit version;
  #  sha256 = "zAZW2eMjwRYevlz8KEzTxzGO8vx5AydfY3vGTapNo1c=";
  #};
  src = fetchFromGitHub {
    owner = "eoyilmaz";
    repo = "displaycal-py3";
    rev = "refs/tags/${version}";
    sha256 = "HwU/Rz+kxyZ8CuPC0ZNzwXegRAQOlLWhm1FqZW/lzXA=";
  };

  nativeBuildInputs = [
    #python311.pkgs.setuptools
    wrapGAppsHook
    gtk3
  ];

  propagatedBuildInputs = with python311.pkgs; [
    build
    certifi
    wxPython_4_2
    dbus-python
    distro
    pychromecast
    send2trash
  ];

  buildInputs = [
    gtk3
    librsvg
  ] ++ (with xorg; [
    libX11
    libXxf86vm
    libXext
    libXinerama
    libXrandr
  ]);

  doCheck = false; # Tests try to access an X11 session and dbus in weird locations.

  pythonImportsCheck = [ "DisplayCAL" ];

  dontWrapGApps = true;

  preFixup = ''
    makeWrapperArgs+=(
      ''${gappsWrapperArgs[@]}
      --prefix PATH : ${lib.makeBinPath [ argyllcms ]}
      --prefix PYTHONPATH : $PYTHONPATH
    )
  '';

  meta = with lib; {
    description = "Display calibration and characterization powered by Argyll CMS (Migrated to Python 3)";
    homepage = "https://github.com/eoyilmaz/displaycal-py3";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [ toastal ];
  };
}
