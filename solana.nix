{ stdenv
, lib
, fetchFromGitHub
, rustPlatform
, hidapi
, libclang
, llvmPackages
, openssl
, pkg-config
, protobuf
, udev
, zlib
, AppKit
, CoreFoundation
, IOKit
, MacOSX-SDK
, Security
, System
, validatorOnly ? false
}:

let
  # See https://github.com/solana-labs/solana/blob/v1.10.0/scripts/cargo-install-all.sh#L87
  bins = [
    "solana"
    "solana-bench-tps"
    "solana-faucet"
    "solana-gossip"
    "solana-install"
    "solana-keygen"
    "solana-ledger-tool"
    "solana-log-analyzer"
    "solana-net-shaper"
    "solana-sys-tuner"
    "solana-validator"
    "rbpf-cli"
  ] ++ lib.optionals (!validatorOnly) [
    "cargo-build-bpf"
    "cargo-test-bpf"
    "solana-dos"
    "solana-install-init"
    "solana-stake-accounts"
    "solana-test-validator"
    "solana-tokens"
    "solana-watchtower"
  ] ++ [
    # Needs to be built last, see https://github.com/solana-labs/solana/issues/5826
    "solana-genesis"
  ];
in
rustPlatform.buildRustPackage rec {
  pname = "solana${lib.optionalString validatorOnly "-validator-only"}";
  version = "1.10.0";

  src = fetchFromGitHub {
    owner = "solana-labs";
    repo = "solana";
    rev = "v${version}";
    sha256 = "sha256-4XKvhHEr/eo+jZd0ElBDI0/tYBnQBGr3pgNk5mdVAaI=";
  };

  cargoSha256 = "sha256-MuLC1rqWTbC10tz647SkXXQRB/EI37qDdqYn10KjjTk=";

  buildInputs = [
    hidapi
    llvmPackages.libclang
    openssl
    zlib
  ] ++ lib.optionals stdenv.isLinux [
    udev
  ] ++ lib.optionals stdenv.isDarwin [
    AppKit
    CoreFoundation
    IOKit
    Security
    System
  ];

  nativeBuildInputs = [
    llvmPackages.llvm
    llvmPackages.clang
    protobuf
    pkg-config
  ];

  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  LLVM_CONFIG_PATH = "${llvmPackages.llvm}/bin/llvm-config";
  OPENSSL_NO_VENDOR = 1; # we want to link to OpenSSL provided by Nix

  NIX_LDFLAGS = if (!stdenv.isDarwin || MacOSX-SDK == null) then null else [
    # XXX: as System framework is broken, use MacOSX-SDK directly instead
    "-F${MacOSX-SDK}/System/Library/Frameworks"
  ];

  doCheck = false;

  # https://hoverbear.org/blog/rust-bindgen-in-nix/
  preBuild = ''
    # From: https://github.com/NixOS/nixpkgs/blob/1fab95f5190d087e66a3502481e34e15d62090aa/pkgs/applications/networking/browsers/firefox/common.nix#L247-L253
    # Set C flags for Rust's bindgen program. Unlike ordinary C
    # compilation, bindgen does not invoke $CC directly. Instead it
    # uses LLVM's libclang. To make sure all necessary flags are
    # included we need to look in a few places.
    export BINDGEN_EXTRA_CLANG_ARGS="$(< ${stdenv.cc}/nix-support/libc-crt1-cflags) \
      $(< ${stdenv.cc}/nix-support/libc-cflags) \
      $(< ${stdenv.cc}/nix-support/cc-cflags) \
      $(< ${stdenv.cc}/nix-support/libcxx-cxxflags) \
      ${lib.optionalString stdenv.cc.isClang "-idirafter ${stdenv.cc.cc}/lib/clang/${lib.getVersion stdenv.cc.cc}/include"} \
      ${lib.optionalString stdenv.cc.isGNU "-isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc} -isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc}/${stdenv.hostPlatform.config} -idirafter ${stdenv.cc.cc}/lib/gcc/${stdenv.hostPlatform.config}/${lib.getVersion stdenv.cc.cc}/include"} \
    "
  '';

  cargoBuildFlags = map (n: "--bin=${n}") bins;

  meta = with lib; {
    homepage = "https://solana.com/";
    description = "Solana is a decentralized blockchain built to enable scalable, user-friendly apps for the world.";
    platforms = platforms.linux ++ platforms.darwin;
    # Requires >=11.0 SDK
    broken = stdenv.isDarwin && stdenv.isx86_64;
  };
}
