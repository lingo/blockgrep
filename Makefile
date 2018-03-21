blockgrep/usr/local/bin/blockgrep: src/blockgrep
	cp src/blockgrep blockgrep/usr/local/bin/blockgrep:

blockgrep/usr/local/share/man/man1/blockgrep.1.gz: src/blockgrep
	pod2man src/blockgrep | gzip > usr/local/share/man/man1/blockgrep.1.gz

blockgrep.deb: blockgrep/usr/local/bin/blockgrep
	dpkg-deb --build blockgrep


all: blockgrep.deb
	;
