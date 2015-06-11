package Getopt::Long::Less;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT   = qw(GetOptions);
our @EXPORT_OK = qw(Configure GetOptionsFromArray);

sub GetOptionsFromArray {
    my $argv = shift;

    my $vals;
    my $spec;

    # if next argument is a hashref, it means user wants to store values in this
    # hash. and the spec is a list.
    if (ref($_[0]) eq 'HASH') {
        $vals = shift;
        $spec = map { $_ => sub { $vals->{ $_[0]->name } = $_[1] } } @_;
    } else {
        $spec = {@_};
    }

    # parse option spec
    my %parsed_spec;
    for my $k (keys %$spec) {
        my $parsed = parse_getopt_long_opt_spec($k)
            or die "Error in option spec: $k\n";
        $parsed_spec{$k} = $parsed;
    }

    my $i = 0;
    my $success = 0;
    while ($i < @$argv) {
        $i++;
    }

    use DD; dd \%parsed_spec;
}

sub GetOptions {
    GetOptionsFromArray(\@ARGV, @_);
}

sub Configure {
}

require Getopt::Long::Util; *parse_getopt_long_opt_spec = \&Getopt::Long::Util::parse_getopt_long_opt_spec; # COMMENT

# INSERT_BLOCK: Getopt::Long::Util parse_getopt_long_opt_spec

package Getopt::Long::Less::Callback;

sub new {
    my $class = shift;
    bless {@_}, $class;
}

sub name {
    shift->{name};
}

1;
#ABSTRACT: Utilities for Getopt::Long

=head1 DESCRIPTION

This module is a reimplementation of L<Getopt::Long>, with less
features/configurability. Only the subset which I'm currently using (which I
think already serves a lot of common use cases for a lot of people too) is
implemented.

Only three functions are implemented: GetOptions, GetOptionsFromArray, and
Configure.

No configuring from C<use> statement. No OO interface.

Much much less modes/configuration. No support for POSIXLY_CORRECT. We always do
bundling (I<this is not Getopt::Long's default>), we never ignore case (I<this
is not Getopt::Long's default>), we always autoabbreviate, we always do GNU
compatibility (allow C<--opt=VAL> in addition to C<--opt VAL>). Basically the
only modes you can configure are: pass_through, permute.

No autoversion, no autohelp. No support to configure prefix pattern, No argument
callback support.

Also, this module requires 5.010.

So what's good about this module? Slightly less compile time overhead, due to
less code. This should not matter for most people. I just like squeezing out
milliseconds from startup overhead of my CLI scripts. That's it :-)


=head1 SEE ALSO

L<Getopt::Long>

=cut
