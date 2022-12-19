{ pkgs ? import <nixpkgs> { }, ... }:
let
  linuxPkgs = with pkgs; lib.optional stdenv.isLinux (
    inotifyTools
  );
  macosPkgs = with pkgs; lib.optional stdenv.isDarwin (
    with darwin.apple_sdk.frameworks; [
      # macOS file watcher support
      CoreFoundation
      CoreServices
    ]
  );
in
with pkgs;
mkShell {
  buildInputs = [
    # report generation toolkit
    asciidoctor

    # language checking
    aspell

    # for watching files for changes
    entr

    # for generating diagrams
    plantuml

    # custom pkg groups
    macosPkgs
    linuxPkgs
  ];
}
