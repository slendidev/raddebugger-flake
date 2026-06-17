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
						version = "v0.9.27-alpha";
						src = pkgs.fetchFromGitHub {
							owner = "EpicGames";
							repo = "raddebugger";
							rev = "v0.9.27-alpha";
							hash = "sha256-qJVRnoETV3aZzvlsOIBbiIWNMJutxzVxz7X8jylLki0=";
						};

						strictDeps = true;

						nativeBuildInputs = with pkgs; [
							bash coreutils gnugrep gnused clang makeWrapper
						];

						buildInputs = with pkgs; [
							freetype libx11 libxext libGL llvm
						];

						NIX_CFLAGS_COMPILE = "-I${pkgs.freetype.dev}/include/freetype2";

						patches = [
							./raddebugger-thread-context.patch
							./raddebugger-log-active.patch
							./raddebugger-crash-symbolizer.patch
						];
						patchFlags = [ "-p1" "--binary" ];

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
							wrapProgram "$out/bin/raddbg" \
								--prefix PATH : ${lib.makeBinPath [ pkgs.llvm ]} \
								--set ASAN_SYMBOLIZER_PATH "${pkgs.llvm}/bin/llvm-symbolizer"
							runHook postInstall
						'';

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
