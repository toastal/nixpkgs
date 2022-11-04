{ lib
, buildPythonApplication
, fetchPypi
, xorg
, certifi
, dbus-python
, build
, wxPython_4_1
, send2trash
, PyChromecast
, distro
, makeWrapper
, argyllcms
, gtk3
, gsettings-desktop-schemas
}:

buildPythonApplication rec {
  pname = "displaycal";
  version = "3.9.10";

  src = fetchPypi {
    pname = "DisplayCAL";
    inherit version;
    sha256 = "sha256-oDHDVb0zuAC49yPfmNe7xuFKaA1BRZGr75XwsLqugHs=";
  };

  propagatedBuildInputs = [
    certifi
    dbus-python
    build
    wxPython_4_1
    send2trash
    PyChromecast
    distro
  ];

  buildInputs = with xorg; [
    libX11
    libXxf86vm
    libXext
    libXinerama
    libXrandr
  ];

  pythonImportsCheck = [ "DisplayCAL" ];

  doCheck = false; # Tests try to access an X11 session.

  # no idea why it looks there - symlink .json lang (everything)
  postInstall = ''
    for x in $out/share/DisplayCAL/*; do
      ln -s $x $out/lib/python3.10/site-packages/DisplayCAL
    done

    for binary in "$out/bin/"*; do
      wrapProgram "$binary" \
        --prefix PATH : "${lib.makeBinPath [ argyllcms ]}" \
        --prefix PYTHONPATH : "$PYTHONPATH" \
        --prefix XDG_DATA_DIRS : "${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}"
    done
  '';

  meta = with lib; {
    description = "DisplayCAL Modernization Project (Migrated to Python 3)";
    homepage = "https://github.com/eoyilmaz/displaycal-py3";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ kranzes ];
  };
}
