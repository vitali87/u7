{
    description = "Universal 7 - an intuitive cli for a human and AI";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
        flake-utils.url = "github:numtide/flake-utils";
    };

    outputs = { self, nixpkgs, flake-utils}:
        flake-utils.lib.eachDefaultSystem (
            system:
                let
                    pkgs = nixpkgs.legacyPackages.${system};

                    runtimeDeps = [
                        pkgs.curl
                        pkgs.jq
                        pkgs.ripgrep
                        pkgs.fd
                        pkgs.qsv

                        pkgs.coreutils
                        pkgs.gnused
                        pkgs.gawk
                        pkgs.findutils
                        pkgs.gnugrep

                        pkgs.bc
                        pkgs.ffmpeg
                        pkgs.imagemagick
                        pkgs.gnutar
                        pkgs.gzip
                        pkgs.bzip2
                        pkgs.xz
                        pkgs.p7zip
                        pkgs.unzip

                        pkgs.rsync

                        pkgs.bash

                        pkgs.openssl
                        pkgs.yq-go
                        pkgs.git

                        pkgs.libwebp
                        pkgs.gifsicle
                        pkgs.rename
                    ];
                in
                {
                    packages.default = pkgs.stdenv.mkDerivation {
                        pname = "u7";
                        version = "0.1.0";
                        src = pkgs.lib.cleanSource ./.;
                        dontBuild = true;

                        buildInputs = runtimeDeps;
                        nativeBuildInputs = [ pkgs.makeWrapper ];

                        installPhase = ''
                            mkdir -p $out/share/u7 $out/bin
                            cp utility.sh $out/share/u7/utility.sh

                            makeWrapper ${pkgs.bash}/bin/bash $out/bin/u7 \
                                --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps} \
                                --add-flags '-c "source ${placeholder "out"}/share/u7/utility.sh; u7 \"\$@\"" --'

                            makeWrapper ${pkgs.bash}/bin/bash $out/bin/u7-init \
                                --add-flags '-c "echo ${placeholder "out"}/share/u7/utility.sh"'
                        '';
                    };

                    devShells.default = pkgs.mkShell {
                        buildInputs = runtimeDeps ++ [ pkgs.bash-completion ];

                        shellHook = ''
                            source ${pkgs.bash-completion}/etc/profile.d/bash_completion.sh
                            source ./utility.sh
                            echo "u7 - Universal 7 CLI"
                            echo "Verbs: show make drop convert move set run"
                        '';
                    };
                }
        );
}
