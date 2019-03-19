# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl t/blockgrep.t'

#########################

use strict;
use warnings;

use Test::More tests => 2;

BEGIN {
    require './src/blockgrep';
}

use FindBin qw/$Bin/;
use lib "$Bin";

use StringBuffer;

my @files = ( $Bin . '/example.pl' );
my $fh    = StringBuffer->new();

blockgrep(
    {
        pattern => qr/.*parse.*/i,
        # 'ignore-indent' => 1,
        writer          => $fh,
        separator => '--FNARG!'
    },
    \@files
);

ok($fh->get() =~ /^sub parse_options\s+\{/, "Top line extracted ok");
ok($fh->get() =~ /\}\s*\n--FNARG!+$/s, "Last line extracted ok");

blockgrep(
    {
        pattern => qr/.*parse.*/i,
        writer          => $fh,
    },
    \@files
);

# done_testing();

