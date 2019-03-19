#!/usr/bin/env perl
#
# See usage at end of code
#
use warnings;
no warnings qw(experimental);
use feature qw(:5.14);
use strict;

our $VERSION = '1.03';

use IO::Handle;
use Data::Dumper;
use Carp;
use Getopt::Std;
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
    'debug'                  => 0, # Output debug info
	'separator'              => '-' x 60 . "\n", # What to print between found blocks
    'ignore-case'            => 1, # Case-insensitive pattern match
	'ignore-indent'          => 0, # Ignore indentation changes, only look for block-end-regex
    'invert-match'           => 0, # Invert pattern matching logic, ie. look for lines that dont match
	'print-block-end-indent' => 0,
    'print-block-end-regex'  => 1,
    'print-block-end-eof'    => 1,
    'print-block-start'      => 1,
	'block-end-regex'        => q[(^\I(done\b|end\b|fi\b|\}))|</],
);

sub detect_indent {
	my $str = shift @_;

    unless($str) {
        return 0, '';
    }

	my $count     = 0;
	my $indentStr = $str =~ s/^(\s+)(\S+.*)$/$1/r; # Uses new /r (return) modifier

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
    my ($writer, $block, $line, $cause) = @_ or croak 'end_block requires block,line,cause as params';

    return unless $block;

    if ($options{'block-line-filter'} && $block) {
        $block = filter($block, $options{'block-line-filter'})
            or carp "# Error filtering through $options{'block-line-filter'} : $!";
    }

    $writer->print($block);

    if ($options{'print-block-end-' . $cause}) {
        $writer->print($line . "\n");
    }
    $writer->print($options{separator});
}

sub parse_options {
    GetOptions(\%options,
        'h' => sub { pod2usage(); exit(2); },
        'invert-match|v!',
        'debug!',
        'ignore-case|i!',
        's' => sub { $options{'ignore-case'} = 0; }, # alternative alias for ignore-case
        'ignore-indent|d!',
        'separator|p:s',
        'only-block|O!' => sub {
            $options{'print-block-end-regex'}  = 0;
            $options{'print-block-start'}      = 0;
            $options{'print-block-end-indent'} = 0;
        },
        'print-block-end-regex|endregex|R!',
        'print-block-end-indent|endindent|I!',
        'print-block-start|start|m!',
        'M' => sub { $options{'print-block-start'} = 0; }, # shortcut for --no-print-block-start
        'block-start-regex|rxstart|S:s',
        'block-end-regex|regex|e:s',
        'block-line-filter|filter|f:s',
    ) or croak $!;

    for ($options{separator}) {
        s/\\n/\n/g;
        s/\\0+/\x0/g;
    }

    $options{pattern} = get_pattern($ARGV[0]);
    shift @ARGV;

    if ($options{'block-start-regex'}) {
        $options{'block-start-regex'} = get_pattern($options{'block-start-regex'});
    }
}

sub blockgrep {
    my ($options, $files) = @_
        or croak;

    my $ioDebug;

    if ($options->{debug}) {
        $ioDebug = $options->{ioDebug} || new IO::Handle->fdopen(fileno(STDERR), "w") or croak "Cannot open STDERR $! $?";
    }

    my $io = $options->{writer}       || new IO::Handle->fdopen(fileno(STDOUT), "w") or croak "Cannot open STDOUT $! $?";

    my $block           = '';
    my ($indentSize, $indentAtBlockStart, $indentWithinBlock, $matchIndent);
    my $matchesPattern;
    my $blockStartRx = $options->{'block-start-regex'};
    my $blockEndRx   = $options->{'block-end-regex'};
    my $pattern      = $options->{'pattern'} || $blockStartRx;

    @ARGV=@{$files};

    my $line;

    LINE: while(1) {
        $matchesPattern = 0;

        SEEK_BLOCK_START:
        while ($line = <<>>) {
            if ($line =~ $blockStartRx) {
                $ioDebug->print("Match block start: $line\n") if $options->{debug};
                ($indentSize, $indentAtBlockStart) = detect_indent($line);
                $matchIndent = $indentSize;

                if ($line =~ $pattern) {
                    $matchesPattern = 1;
                    $ioDebug->print("Pattern match! $line\n") if $options->{debug};
                }

                if ($options{'print-block-start'}) {
                    $block .= $line;
                }
                last SEEK_BLOCK_START;
            }
        }
        if (defined($line)) {
            $line = <<>>;
        }
        # If either of last 2 calls to <<>> failed, end now
        if (!defined($line)) {
            last LINE;
        }

        # Replace our custom indent metacharacters with specific text
        ($indentSize, $indentWithinBlock) = detect_indent($line);
        $blockEndRx  = $options->{'block-end-regex'};
        for($blockEndRx) {
            s/\\I/$indentAtBlockStart/g;
            s/\\i/$indentWithinBlock/g;
        }
        $blockEndRx = qr/$blockEndRx/;

        $matchesPattern ||= $line =~ $pattern;
        $ioDebug->print("Pattern match! $line\n") if $matchesPattern && $options->{debug};


        SEEK_END_LINE:
        while(defined($line)) {
            $block .= $line;
            $ioDebug->print("# $line") if $options->{debug};

            if (!$matchesPattern && $line =~ $pattern) {
                $ioDebug->print("Pattern match! $line\n") if $options->{debug};
                $matchesPattern = 1;
            }

            # if ($options->{debug}) {
            #     $ioDebug->print(qq{
            #         indentSize: $indentSize
            #         indentAtBlockStart: |$indentAtBlockStart|
            #         indentWithinBlock: |$indentWithinBlock|
            #     } =~ s/^\s+//r);
            # }

            if ($line =~ $blockEndRx) {
                $ioDebug->print("# Endblock symbol found \n" . $line . "\n") if $options->{debug};
                end_block($io, $block, $line, 'regex') if $matchesPattern;
                $block = '';
                last SEEK_END_LINE;
            }

            if (!$options->{'ignore-indent'} && $indentSize < $matchIndent) {
                $ioDebug->print("# Indent not match\n" . $line . "\n") if $options->{debug};
                end_block($io, $block, $line, 'indentSize') if $matchesPattern;
                $block = '';
                last SEEK_END_LINE;
            }

            $line = <<>>;
        }

        if (!defined($line)) {
            last LINE;
        }
    }

    end_block($io, $block, '', 'eof');
}

sub get_pattern {
    my $pattern = $_[0] or do {
        pod2usage(); #$ARGV[0];
        exit(2);
    };

    if ($pattern !~ /[\^\$\(]/) {
        $pattern = qq(.*$pattern.*);
    }

    if ($options{'ignore-case'}) {
        $pattern = qr/$pattern/i;
    } else {
        $pattern = qr/$pattern/;
    }

    return $pattern;
}

sub main {
    parse_options();

    if ($options{debug}) {
        print "# Seek $options{pattern}\n";
        print "# Options: \n" . Dumper(\%options);
        print "# ARGV:\n" . Dumper(\@ARGV);
    }

    blockgrep(\%options, \@ARGV);
}


if (caller) {
    use Exporter qw(import);
    our @EXPORT_OK = qw/blockgrep/;
} else {
    __PACKAGE__->main(\@ARGV);
}

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
