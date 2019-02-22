# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl t/blockgrep.t'

#########################

use strict;
use warnings;

use Test::More;

BEGIN {
	require './src/blockgrep';
};

use FindBin qw/$Bin/;


my $results = blockgrep(qr/test/, {}, [ $Bin . '/example.pl']);

done_testing();