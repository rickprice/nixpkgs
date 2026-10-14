{
  lib,
  fetchzip,
  python3,
  qt6,
  libreoffice-unwrapped,
  nix-update-script,
  presentationSupport ? false,
  odbcSupport ? false,
  postgresqlSupport ? false,
  spellcheckSupport ? false,
}:

let
  python3Packages = python3.pkgs;

  # OpenLP uses PySide6, but nixpkgs' qtawesome hard-depends on PyQt6. Both
  # bindings can be imported at once, but qtpy (which qtawesome uses
  # internally) then picks PyQt6 over PySide6, producing QIcon/QPixmap
  # objects from the wrong binding for the rest of the (PySide6) application.
  # qtawesome itself only ever goes through qtpy, so it's safe to swap its
  # Qt binding dependency instead.
  qtawesome-pyside6 = python3Packages.qtawesome.overridePythonAttrs (_: {
    propagatedBuildInputs = [
      python3Packages.pyside6
      python3Packages.qtpy
    ];
  });

  libreofficePath = "${libreoffice-unwrapped}/lib/libreoffice/program";
in
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "openlp";
  version = "4.0a2";
  pyproject = true;

  __structuredAttrs = true;

  # Not fetchFromGitLab: that goes through the GitLab API archive endpoint,
  # which is far more aggressively rate-limited than the CDN-backed
  # `-/archive` URL used here (the same one GitLab's own "Download" button
  # links to).
  src = fetchzip {
    url = "https://gitlab.com/openlp/openlp/-/archive/${finalAttrs.version}/openlp-${finalAttrs.version}.tar.gz";
    hash = "sha256-loiY6ANcEnw1XZP2uz6M1v/GoSKZ4nfco+6Dc/IgCiM=";
  };

  # Upstream's update-check code assumes the minor-version component of
  # self.current_version['version'] is purely numeric (e.g. "4.0" ->
  # int("0")), which crashes shortly after startup on any alpha/beta/rc tag
  # like "4.0a2" (int("0a2") raises ValueError). Use packaging.version,
  # already imported in this file, to parse it properly instead.
  patches = [ ./fix-prerelease-update-check-crash.patch ];

  # OpenLP's version is normally derived from git tags via hatch-vcs, which
  # needs a .git checkout that this archive doesn't provide.
  env.SETUPTOOLS_SCM_PRETEND_VERSION = finalAttrs.version;

  build-system = with python3Packages; [
    hatchling
    hatch-vcs
  ];

  nativeBuildInputs = [
    qt6.wrapQtAppsHook
  ];

  buildInputs = with qt6; [
    qtbase
    qtsvg
    qtmultimedia
    qtwayland
  ];

  dependencies =
    with python3Packages;
    [
      alembic
      beautifulsoup4
      chardet
      distro
      flask
      flask-cors
      lxml
      mako
      packaging
      pillow
      platformdirs
      pymysql
      pysword
      pyicu
      pyside6
      qdarkstyle
      qrcode
      qtawesome-pyside6
      requests
      sqlalchemy
      waitress
      websocket-client
      websockets
    ]
    ++ lib.optional odbcSupport pyodbc
    ++ lib.optional postgresqlSupport psycopg2
    ++ lib.optional spellcheckSupport pyenchant;

  # Only used to talk to a running LibreOffice over the UNO bridge for
  # Impress/PowerPoint presentation support; needs the same environment as
  # LibreOffice's own bundled Python scripting provider.
  makeWrapperArgs = lib.optionals presentationSupport [
    "--prefix"
    "PATH"
    ":"
    "${libreoffice-unwrapped}/bin"
    "--prefix"
    "PYTHONPATH"
    ":"
    libreofficePath
    "--set"
    "URE_BOOTSTRAP"
    "vnd.sun.star.pathname:${libreofficePath}/fundamentalrc"
    "--set"
    "UNO_PATH"
    libreofficePath
    "--prefix"
    "LD_LIBRARY_PATH"
    ":"
    libreofficePath
    "--set"
    "JAVA_HOME"
    libreoffice-unwrapped.jdk.home
  ];

  # The desktop file and icons live in /resources upstream, which is part of
  # the sdist but not of the wheel pypaBuildPhase produces, so they have to
  # be installed from the unpacked source tree by hand.
  postInstall = ''
    install -Dm444 resources/openlp.desktop -t $out/share/applications
    install -Dm444 resources/images/openlp.svg \
      $out/share/icons/hicolor/scalable/apps/openlp.svg
    for size in 16 32 48 64 128 256; do
      install -Dm444 "resources/images/openlp-logo-''${size}x''${size}.png" \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/openlp.png"
    done
  '';

  pythonImportsCheck = [ "openlp" ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Free church presentation and lyrics projection application";
    longDescription = ''
      OpenLP is free church presentation software, used to display slides of
      songs, Bible verses, videos, images and presentations for worship
      using a computer and a projector or other display.

      This package only supports SQLite song/Bible databases by default;
      pass `postgresqlSupport` or `odbcSupport` to enable other database
      backends, `spellcheckSupport` for spell-checking in the song editor,
      and `presentationSupport` to import/control PowerPoint and
      LibreOffice Impress presentations (requires a working LibreOffice
      UNO bridge).
    '';
    homepage = "https://openlp.org/";
    downloadPage = "https://openlp.org/#downloads";
    changelog = "https://gitlab.com/openlp/openlp/-/blob/${finalAttrs.version}/CHANGELOG.rst";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "openlp";
    maintainers = with lib.maintainers; [ rickprice ];
  };
})
