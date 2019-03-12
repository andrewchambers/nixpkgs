{ stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  name = "janet-${version}";

  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "janet-lang";
    repo = "janet";
    rev = "v${version}";
    sha256 = "1590f1fxb6qfhf1vp2xhbvdn2jfrgipn5572cckk1ma7f13jnkpy";
  };

  JANET_BUILD=''\"release\"'';

  buildPhase = ''
    PREFIX="$out" make
  '';

  installPhase = ''
    mkdir "$out"
    PREFIX="$out" make install
  '';

  meta = with stdenv.lib; {
    description = "Janet programming language";
    homepage = https://janet-lang.org/;
    license = stdenv.lib.licenses.mit;
    platforms = platforms.all;
    maintainers = with stdenv.lib.maintainers; [ andrewchambers ];
  };
}
