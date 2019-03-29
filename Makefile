VERSION := $(shell git describe --tags)


blockgrep.deb: blockgrep/usr/local/bin/blockgrep blockgrep/usr/local/share/man/man1/blockgrep.1.gz blockgrep/DEBIAN/control
	cp src/blockgrep blockgrep/usr/local/bin/blockgrep
	sed -ri "s/___VERSION___/${VERSION}/g" blockgrep/usr/local/bin/blockgrep
	sed -ri "s/^(Version:).*/\1 ${VERSION}/" blockgrep/DEBIAN/control
	dpkg-deb --build blockgrep

.blockgrep/usr/local/share/man/man1/blockgrep.1.gz: src/blockgrep
	pod2man src/blockgrep | gzip > blockgrep/usr/local/share/man/man1/blockgrep.1.gz

