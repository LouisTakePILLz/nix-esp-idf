{ nixpkgs ? import <nixpkgs> {} }:

let
  inherit (nixpkgs) pkgs;

  sources = pkgs.callPackage ./sources.nix {};

  # esp-idf as of Nov 2019 requires pyparsing < 2.4
  python2 = let
    packageOverrides = self: super: {
      pyparsing = super.pyparsing.overridePythonAttrs (old: rec {
        version = "2.3.1";
        src = super.fetchPypi {
          pname = "pyparsing";
          inherit version;
          sha256 = "66c9268862641abcac4a96ba74506e594c884e3f57690a696d21ad8210ed667a";
        };
      });
    };
  in (pkgs.python2.override {
    inherit packageOverrides;
    self = python2;
  }).overrideAttrs (oldAttrs: {
    doCheck = false;
  });

  fhsEnv = pkgs.buildFHSUserEnv {
    name = "esp32-toolchain-env";
    targetPkgs = pkgs: with pkgs; [
      stdenv.cc.cc.lib  # libstdc++.so.6
      zlib
    ];
    runScript = "";
  };

  esp32-toolchain = pkgs.stdenv.mkDerivation rec {
    pname = "esp32-toolchain";

    inherit (sources.esp-idf) version src;

    dontConfigure = true;
    dontBuild = true;

    nativeBuildInputs = with pkgs; [
      file
      coreutils
      makeWrapper
    ];

    buildInputs = with pkgs; [
      (python2.withPackages (ppkgs: with ppkgs; [
        pip
      ]))
    ];

    depsArray = map pkgs.fetchurl (pkgs.lib.attrValues (import ./deps.nix));

    installPhase = ''
      mkdir -p $out/bin

      depsArray=($depsArray)
      for dep in "''${depsArray[@]}"; do
        tmp="$(mktemp -d)"
        tar -xf "$dep" -C $tmp
        echo "installing $(ls $tmp)"
        for d in "$tmp"/*/{bin,include,lib,libexec,share}; do
          [[ ! -d "$d" ]] && continue
          cp -r $d $out
        done
      done
    '';

    preFixup = ''
      for f in "$out/bin/"*; do
        [[ -z "$f" ]] && continue
        [[ ! -f "$f" ]] && continue # Skip non-files
        [[ ! -x "$f" ]] && continue # Skip non-executable files
        [[ -L "$f" ]] && continue # Skip symlinks

        # Skip non-ELF binaries
        [[ "$(file -b "$f")" != "ELF"* ]] && continue

        uwf="$out/bin/.$(basename "$f")-unwrapped"
        mv "$f" "$uwf"

        makeWrapper ${fhsEnv}/bin/esp32-toolchain-env "$f" \
          --add-flags "$uwf"
      done
    '';

    meta = with pkgs.stdenv.lib; {
      description = "ESP32 toolchain";
      homepage = "https://docs.espressif.com/projects/esp-idf/en/stable/get-started/linux-setup.html";
      license = licenses.gpl3;
    };
  };
in

pkgs.stdenv.mkDerivation {
  name = "esp-idf-env"; 
  inherit (sources.esp-idf) src;
  dontBuild = true;
  dontConfigure = true;
  buildInputs = with pkgs; [
    gawk gperf gettext automake bison flex texinfo help2man libtool autoconf ncurses5 cmake glibcLocales
    (python2.withPackages (ppkgs: with ppkgs; [ pyserial future cryptography setuptools pyelftools pyparsing click ]))
    esp32-toolchain
  ];
  shellHook = ''
    export NIX_CFLAGS_LINK=-lncurses
    export IDF_PATH=${sources.esp-idf.src}
    export IDF_TOOLS_PATH=${esp32-toolchain}
  '';
}
