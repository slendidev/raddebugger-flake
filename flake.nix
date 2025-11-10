{
	description = "My flake";

	inputs = {
		nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
		flake-utils.url = "github:numtide/flake-utils";
		raddebuggerSrc = {
			url = "github:EpicGamesExt/raddebugger";
			flake = false;
		};
	};

	outputs = { self, nixpkgs, flake-utils, raddebuggerSrc }:
		flake-utils.lib.eachDefaultSystem (system:
			let
				pkgs = import nixpkgs { inherit system; };
				lib = pkgs.lib;
			in {
				packages = rec {
					raddebugger = pkgs.stdenv.mkDerivation {
						pname = "raddebugger";
						version = "unstable";
						src = raddebuggerSrc;

						strictDeps = true;

						nativeBuildInputs = with pkgs; [
							bash coreutils gnugrep gnused clang
						];

						buildInputs = with pkgs; [
							freetype xorg.libX11 xorg.libXext libGL
						];

						makeWrapperArgs = [
							"--prefix PATH: ${
								lib.makeBinPath [
									pkgs.llvm
								]
							}"
						];

						NIX_CFLAGS_COMPILE = "-I${pkgs.freetype.dev}/include/freetype2";

						postPatch = ''
							substituteInPlace build.sh \
								--replace 'git_hash=$(git describe --always --dirty)' 'git_hash=''${GIT_HASH:-unknown}' \
								--replace 'git_hash_full=$(git rev-parse HEAD)' 'git_hash_full=''${GIT_HASH_FULL:-unknown}'
							substituteInPlace src/third_party/radsort/radsort.h \
								--replace '#define RSFORCEINLINE __attribute__((always_inline))' '#define RSFORCEINLINE'
							chmod +x build.sh
						'';

						buildPhase = ''
							runHook preBuild
							bash ./build.sh gcc debug raddbg
							runHook postBuild
						'';

						installPhase = ''
							runHook preInstall
							mkdir -p "$out/bin"
							install -Dm755 build/raddbg "$out/bin/raddbg"
							runHook postInstall
						'';

						patches = [ ./fix-black-screen.patch ];

						meta = with lib; {
							description = "RAD Debugger";
							homepage = "https://github.com/EpicGamesExt/raddebugger";
							license = licenses.mit;
							platforms = platforms.linux;
							mainProgram = "raddbg";
						};
					};

					default = raddebugger;
				};
			});
}
