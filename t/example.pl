#!/usr/bin/env perl
#
# See usage at end of code
#
use warnings;
no warnings qw(experimental);

use strict;
use Data::Dumper;
use Carp;
use Getopt::Std;
use feature qw(:5.14);
use Getopt::Long qw(:config no_ignore_case bundling auto_version auto_help);
use Pod::Usage;
use IPC::Filter qw(filter);

$SIG{'PIPE'} = sub {
    print "Got sigterm in pipe \n";
    croak $!;
};

use constant MODE_MATCH_PATTERN => 0;
use constant MODE_SEEK_BLOCK_END => 1;

# declare the perl command line flags/options we want to allow
my %options=(
    'debug'                  => 0,
	'separator'              => '-' x 60 . "\n",
    'ignore-case'            => 1,
	'ignore-indent'          => 0,
    # 'invert-match'         => 0,
    'block-head-lines'       => 0,
    'block-tail-lines'       => 0,
	'print-block-end-indent' => 0,
    'print-block-end-regex'  => 1,
    'print-block-end-eof'    => 1,
    'print-block-start'      => 1,
	'block-end-regex'        => q[(^__START_INDENT__(done\b|end\b|fi\b|\}))|</],
);


sub get_pattern {
    my $pattern = $_->[0]; #$ARGV[0];

    if ($pattern !~ /[\^\$\(]/) {
        $pattern = qq(.*$pattern.*);
    }

    if ($options{'ignore-case'}) {
        $pattern = qr/.*$pattern.*/i;
    } else {
        $pattern = qr/.*$pattern.*/;
    }

    return $pattern;
}


sub detect_indent {
	my $str = shift @_;

    unless($str) {
        return 0, '';
    }

	my $count     = 0;
	my $indentStr = $str =~ s/^(\s+).*/$1/r;

	unless($indentStr =~ /^\s+$/) {
		return 0, '';
	}

	if ($indentStr =~ /^\t+$/) { # Tabs
		$count =()= $indentStr =~ /\t/g;
	} elsif ($indentStr =~ /^[ ]+$/) { # Spaces
		$count =()= $indentStr =~ /[ ]/g;
	} else { # Mixed, *ick!*
		print "# mixed indent: |$indentStr|\n" if $options{debug};
		my $tabCount   =()= $indentStr =~ /\t+/g;
		my $spaceCount =()= $indentStr =~ /[ ]+/g;

		return ($tabCount || $spaceCount, $indentStr);
	}
	#print "# count is |$count|\n" if $options{debug};
	return ($count, $indentStr);
}

sub end_block {
    my ($block, $line, $cause) = @_ or croak 'end_block requires block,line,cause as params';

    if ($options{'block-line-filter'} && $block) {
        $block = filter($block, $options{'block-line-filter'}) or carp "# Error filtering through $options{'block-line-filter'} : $!";
    }
    print $block;

    my $optionKey = 'print-block-end-' . $cause;
    # print $optionKey . ' => ' . $options{$optionKey} ."\n";
    if ($options{$optionKey}) {
        print $line . "\n";
    }
    for ($options{separator}) {
        s/\\n/\n/g;
        s/\\0+/\x0/g;
    }
    print $options{separator}
}

sub parse_options {
    GetOptions(\%options,
        'h' => sub { pod2usage(); exit(2); },
        # 'invert-match|v!',
        'debug!',
        'ignore-case|i!',
        # another alias for ignore-case
        's' => sub { $options{'ignore-case'} = 0; },
        'ignore-indent|d!',
        'separator|p:s',
        'only-block|O!' => sub {
            $options{'print-block-end-regex'} =
            $options{'print-block-start'} =
            $options{'print-block-end-indent'} = 0;
        },
        'print-block-end-regex|endregex|R!',
        'print-block-end-indent|endindent|I!',
        'print-block-start|start|m!',
        'block-end-regex|regex|e:s',
        'M' => sub { $options{'print-block-start'} = 0; },
        'block-head-lines|head:n',
        'block-tail-lines|tail:n',
        'block-line-filter|filter|f:s',
    ) or croak $!;
}

sub main {
    parse_options();
    my $pattern = get_pattern(\@ARGV);
    shift @ARGV;

    if ($options{debug}) {
        print "# Seek $pattern\n";
        print "# Options: \n" . Dumper(\%options);
        print "# ARGV:\n" . Dumper(\@ARGV);
    }

    my $mode = MODE_MATCH_PATTERN;
    my $matchIndent = -1;
    my $indent = 0;

    my $block = '';
    my $blockEndRx;
    my $indentStr = '';
    my $skipCount = 0;
    my $startIndentStr;

    LINE: while(<>) {
        chomp;
        my $line = $_;

        ($indent, $indentStr) = detect_indent($line);

        if ($mode == MODE_MATCH_PATTERN && $line =~ $pattern) {
            $startIndentStr = $indentStr;
            $skipCount      = 0;
            $mode           = MODE_SEEK_BLOCK_END;
            $matchIndent    = -1;

            if ($options{'print-block-start'}) {
                print $line . "\n";
            }
            next;
        }

        if ($mode == MODE_SEEK_BLOCK_END) {
            while ($skipCount < $options{'block-head-lines'}) {
                $skipCount++;
                print "Skipped 1, $skipCount\n" if $options{debug};
                next LINE;
            }

            print "# Indent count is $indent, |$indentStr| match string is |$startIndentStr|\n" if $options{debug};

            if ($matchIndent < 0) {
                $matchIndent = $indent;
                $blockEndRx  = $options{'block-end-regex'};

                for($blockEndRx) {
                    s/__START_INDENT__/$startIndentStr/g;
                    s/__INDENT__/$indentStr/g;
                }

                print '|' . $blockEndRx . "|\n" if $options{debug};
                print "$line\n" if $options{debug};

                $blockEndRx = qr/$blockEndRx/;

            } elsif ($line =~ $blockEndRx) {
                print "# Endblock symbol found \n" . $line . "\n" if $options{debug};
                $mode  = MODE_MATCH_PATTERN;
                end_block($block, $line, 'regex');
                $block = '';
                next LINE;
            }

            if (!$options{'ignore-indent'} && $indent < $matchIndent) {
                print "# Indent not match\n" . $line . "\n" if $options{debug};
                $mode = MODE_MATCH_PATTERN;
                end_block($block, $line, 'indent');
                $block = '';
                next LINE;
            }

            $block .= $line . "\n";
        }
    }
    end_block($block, '', 'eof');
}


main(\@ARGV);

#print "# EOF\n";
__END__

=head1 Blockgrep

Grep for a given pattern, then print lines until end of block.

The end of a block is defined by a change of indent, or certain keywords
or symbols, such as 'end', 'done', 'fi', or '}'


=head1 SYNOPSIS

blockgrep [options] <PATTERN> [<FILES>]

Greps FILES or STIND for PATTERN, outputting blocks.

  Options ([*] marks defaults)

    -h|--help                      Help on usage
    -i|--ignore-case               [*] Case-insensitive matching
    -s|--no-ignore-case            Case sensitive matching
    -m|--print-block-start         [*] Print matching line that start blockgrep
    -M|--no-print-block-start      Don't print line that starts block
    -I|--print-block-end-indent    Print line that ends block by indent change
    -R|--print-block-end-regex     [*] Print line that ends block matching/regex
    -e|--block-end-regex <REGEX>   Supply a (PCRE) regex to match block endings
    -d|--ignore-indent             Ignore indentation and only look at end-regex
    --separator <SEPARATOR>        Text used to separate output blocks
    --block-line-filter <COMMAND>  Filter block contents through this command

=head1 OPTIONS


=over 4

=item B<-help>

Print a brief help message and exits.

=item B<-print-block-start>

Print the line matching <pattern> that starts the block.  This is true by default.

=item B<--print-block-end-indent>

If a block is ended because of a change of indentation, then print the line
that ends the block (default is false)

=item B<--print-block-end-regex>

If a block is ended because matching a regular expression then print the line
that ends the block (default is true).
The default regex should match 'fi|done|end|\}'.  You can change this with
--block-end-regex

=item B<--block-end-regex> <REGEX>

Supply a custom (PCRE) regular expression to match block endings

=item B<--separator> <SEPARATOR>

Provide custom text to be printed between blocks in program output.
The default separator is a line of dashes, 60 characters long

=item B<--block-line-filter> <COMMAND>

Using this option you can filter block content (not the starting or ending lines)
through an external command.

=back

=head1 DESCRIPTION

B<blockgrep> will acts like grep, but will print the block that follows each match.
A block is defined by default as the text following the match, up til the first change of indentation, or matching keyword or symbol.
By default the keywords 'end', 'done', 'fi', and the symbol '}' are counted as block enders.

The default behaviour is to print all matching lines from the start of a matching block, until the end, including any block ending symbols/keywords.
If a block is ended by a change of indentation, then by default the line that changes indentation is not printed.
This can be changed using the --print-block-end-indent option.

=head1 EXAMPLES

blockgrep function file.c

pacmd --list-cards | blockgrep profile --no-print-block-start --block-line-filter='cut -d: -f2'


=cut
