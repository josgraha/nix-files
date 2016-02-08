{ stdenv, gawk, fetchurl }:
stdenv.mkDerivation rec {
  name = "ical2org-${version}";
  version = "15r1rq9xpjypij0bb89zrscm1wc5czljfyv47z68vmkhimr579az";

  src = fetchurl {
    url = http://orgmode.org/worg/code/awk/ical2org.awk;
    sha256 = version;
  };

  phases = [ "installPhase" ];

  buildInputs = [ gawk ];

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/ical2org
    chmod +x $out/bin/ical2org
    substituteInPlace $out/bin/ical2org \
      --replace "/usr/bin/awk" "${gawk}/bin/gawk"
  '';

  meta = with stdenv.lib; {
    description = "Convert ical to org";
    homepage = "http://orgmode.org/worg/org-tutorials/org-google-sync.html";
    license = licenses.free;
    platforms = with platforms;  linux ++ darwin ;
    maintainers = with maintainers; [ jb55 ];
  };
}
