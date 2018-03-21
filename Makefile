blockgrep.deb: blockgrep/usr/local/bin/blockgrep blockgrep/usr/local/share/man/man1/blockgrep.1.gz blockgrep/DEBIAN/control
	dpkg-deb --build blockgrep

src/blockgrep: ~/bin/blockgrep
	cp ~/bin/blockgrep src/blockgrep

blockgrep/usr/local/bin/blockgrep: src/blockgrep
	cp src/blockgrep blockgrep/usr/local/bin/blockgrep

.blockgrep/usr/local/share/man/man1/blockgrep.1.gz: src/blockgrep
	pod2man src/blockgrep | gzip > blockgrep/usr/local/share/man/man1/blockgrep.1.gz

