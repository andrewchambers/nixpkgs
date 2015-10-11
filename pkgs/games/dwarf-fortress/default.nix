{ stdenv, fetchgit, fetchurl, cmake, glew, ncurses
, SDL, SDL_image, SDL_ttf, gtk2, glib
, mesa, openal, pango, atk, gdk_pixbuf, glibc, libsndfile }:

let
  baseVersion = "40";
  patchVersion = "24";
  srcs = {
    df_unfuck = fetchgit {
      url = "https://github.com/svenstaro/dwarf_fortress_unfuck";
      rev = "39742d64d2886fb594d79e7cc4b98fb917f26811";
      sha256 = "19vwx6kpv1sf93bx5v8x47f7x2cgxsqk82v6j1a72sa3q7m5cpc7";
    };

    df = fetchurl {
      url = "http://www.bay12games.com/dwarves/df_${baseVersion}_${patchVersion}_linux.tar.bz2";
      sha256 = "0d4jrs45qj89vq9mjg7fxxhis7zivvb0vzjpmkk274b778kccdys";
    };
  };

in

assert stdenv.system == "i686-linux";

stdenv.mkDerivation rec {
  name = "dwarf-fortress-0.${baseVersion}.${patchVersion}";

  inherit baseVersion patchVersion;

  buildInputs = [ SDL SDL_image SDL_ttf gtk2 glib glew mesa ncurses openal glibc libsndfile pango atk cmake gdk_pixbuf];
  src = "${srcs.df_unfuck} ${srcs.df}";
  phases = "unpackPhase patchPhase configurePhase buildPhase installPhase";

  sourceRoot = srcs.df_unfuck.name;

  cmakeFlags = [
    "-DGTK2_GLIBCONFIG_INCLUDE_DIR=${glib.out}/lib/glib-2.0/include"
    "-DGTK2_GDKCONFIG_INCLUDE_DIR=${gtk2.out}/lib/gtk-2.0/include"
  ];

  permission = ./df_permission;

  installPhase = ''
    set -x
    mkdir -p $out/bin
    mkdir -p $out/share/df_linux
    cd ../../
    cp -r ./df_linux/* $out/share/df_linux
    rm $out/share/df_linux/libs/lib*

    # Store the original hash for dwarf-therapist 
    echo $(md5sum $out/share/df_linux/libs/Dwarf_Fortress | cut -c1-8) > $out/share/df_linux/hash.md5.orig
    # Fix rpath
    patchelf --set-rpath "${stdenv.lib.makeLibraryPath [ stdenv.cc.cc stdenv.glibc ]}:$out/share/df_linux/libs"  $out/share/df_linux/libs/Dwarf_Fortress
    cp -f ./${srcs.df_unfuck.name}/build/libgraphics.so $out/share/df_linux/libs/libgraphics.so

    cp $permission $out/share/df_linux/nix_permission

    patchelf --set-interpreter ${glibc.out}/lib/ld-linux.so.2 $out/share/df_linux/libs/Dwarf_Fortress

    # Store new hash for dwarf-therapist
    echo $(md5sum $out/share/df_linux/libs/Dwarf_Fortress | cut -c1-8) > $out/share/df_linux/hash.md5.patched

    cat > $out/bin/dwarf-fortress << EOF
      #!${stdenv.shell}
      
      set -ex

      export DF_DIR="\$HOME/.config/df_linux"
      if [ -n "\$XDG_DATA_HOME" ]
       then export DF_DIR="\$XDG_DATA_HOME/df_linux"
      fi

      if [[ ! -d "\$DF_DIR" ]]; then
          mkdir -p "\$DF_DIR"
          ln -s $out/share/df_linux/raw "\$DF_DIR/raw"
          ln -s $out/share/df_linux/libs "\$DF_DIR/libs"
          mkdir -p "\$DF_DIR/data/init"
          cp -rn $out/share/df_linux/data/init "\$DF_DIR/data/"
      fi

      for link in announcement art dipscript help index initial_movies movies shader.fs shader.vs sound speech; do
          cp -r $out/share/df_linux/data/\$link "\$DF_DIR/data/\$link"
          chmod -R u+rw "\$DF_DIR/data/\$link"
      done

      # now run Dwarf Fortress!
      export LD_LIBRARY_PATH='${stdenv.lib.makeLibraryPath
        [ stdenv.cc SDL SDL_image SDL_ttf gtk2 glib mesa openal libsndfile ]
      }':\$DF_DIR/df_linux/libs/

      export SDL_DISABLE_LOCK_KEYS=1 # Work around for bug in Debian/Ubuntu SDL patch.
      #export SDL_VIDEO_CENTERED=1    # Centre the screen.  Messes up resizing.

      cd \$DF_DIR
      $out/share/df_linux/libs/Dwarf_Fortress "$@"
    EOF

    chmod +x $out/bin/dwarf-fortress
  '';

  meta = {
    description = "A single-player fantasy game with a randomly generated adventure world";
    homepage = http://www.bay12games.com/dwarves;
    license = stdenv.lib.licenses.unfreeRedistributable;
    maintainers = with stdenv.lib.maintainers; [ roconnor the-kenny ];
  };
}
