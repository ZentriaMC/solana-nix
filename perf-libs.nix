{ stdenv
, lib
, fetchFromGitHub
, cudatoolkit_10_2
, opencl-headers
, ocl-icd
}:

stdenv.mkDerivation rec {
  pname = "solana-perf-libs";
  version = "0.19.3";

  src = fetchFromGitHub {
    owner = "solana-labs";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-5OD+C5YT8UuDbFbZ6u/8HLGqz1m6Ulsjr7juTd4w9zQ=";
  };

  buildInputs = [
    cudatoolkit_10_2
    opencl-headers
    ocl-icd
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    make clean
    make cuda_crypt

    runHook postBuild
  '';

  installFlags = [
    "DESTDIR=$(out)/lib"
  ];

  meta = with lib; {
    description = "C and CUDA libraries to enhance Solana";
    homepage = "https://github.com/solana-labs/solana-perf-libs";
    platforms = platforms.linux;
    license = licenses.asl20;
  };
}
