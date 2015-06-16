package Getopt::Long::Less;

# DATE
# VERSION

use 5.010001;
use strict 'subs', 'vars';
use warnings; # COMMENT

our @EXPORT   = qw(GetOptions);
our @EXPORT_OK = qw(Configure GetOptionsFromArray);

my $Opts = {permute=>1, pass_through=>0};

sub import {
    my $pkg = shift;
    my $caller = caller;
    my @imp = @_ ? @_ : @EXPORT;
    for my $imp (@imp) {
        if (grep {$_ eq $imp} (@EXPORT, @EXPORT_OK)) {
            *{"$caller\::$imp"} = \&{$imp};
        } else {
            die "$imp is not exported by ".__PACKAGE__;
        }
    }
}

sub Configure {
    my $old_opts = {%$Opts};

    if (ref($_[0]) eq 'HASH') {
        $Opts->{$_} = $_[0]{$_} for keys %{$_[0]};
    } else {
        for (@_) {
            if    ($_ eq 'no_ignore_case') { next }
            elsif ($_ eq 'bundling') { next }
            elsif ($_ eq 'auto_abbrev') { next }
            elsif ($_ eq 'gnu_compat') { next }
            elsif ($_ eq 'permute') { $Opts->{permute} = 1 }
            elsif (/\A(no_?)permute\z/) { $Opts->{permute} = $1 ?0:1 }
            elsif (/\A(no_?)require_order\z/) { $Opts->{permute} = $1 ?1:0 }
            elsif (/\A(no_?)pass_through\z/) { $Opts->{pass_through} = $1 ?0:1 }
            else { die "Unknown or erroneous config parameter \"$_\"\n" }
        }
    }
    $old_opts;
}

sub GetOptionsFromArray {
    my $argv = shift;

    my $vals;
    my $spec;

    # if next argument is a hashref, it means user wants to store values in this
    # hash. and the spec is a list.
    if (ref($_[0]) eq 'HASH') {
        $vals = shift;
        $spec = {map { $_ => sub { $vals->{ $_[0]->name } = $_[1] } } @_};
    } else {
        $spec = {@_};
    }

    # parse option spec
    my %parsed_spec;
    for my $k (keys %$spec) {
        my $parsed = parse_getopt_long_opt_spec($k)
            or die "Error in option spec: $k\n";
        if (defined $parsed->{max_vals}) {
            die "Cannot repeat while bundling: $k\n";
        }
        $parsed->{_orig} = $k;
        $parsed_spec{$parsed->{opts}[0]} = $parsed;
    }
    my @parsed_spec_opts = sort keys %parsed_spec;

    my $success = 1;

    my $code_find_opt = sub {
        my ($wanted, $short_mode) = @_;
        my @candidates;
      OPT_SPEC:
        for my $opt (@parsed_spec_opts) {
            my $s = $parsed_spec{$opt};
            for my $o0 (@{ $s->{opts} }) {
                for my $o ($s->{is_neg} && length($o0) > 1 ?
                               ($o0, "no$o0", "no-$o0") : ($o0)) {
                    my $is_neg = $o0 ne $o;
                    next if $short_mode && length($o) > 1;
                    if ($o eq $wanted) {
                        # perfect match, we immediately go with this one
                        @candidates = ([$opt, $is_neg]);
                        last OPT_SPEC;
                    } elsif (index($o, $wanted) == 0) {
                        # prefix match, collect candidates first
                        push @candidates, [$opt, $is_neg];
                        next OPT_SPEC;
                    }
                }
            }
        }
        if (!@candidates) {
            unless ($Opts->{pass_through}) {
                warn "Unknown option: $wanted\n";
                $success = 0;
            }
            return (undef, undef);
        } elsif (@candidates > 1) {
            unless ($Opts->{pass_through}) {
                warn "Option $wanted is ambiguous (" .
                    join(", ", map {$_->[0]} @candidates) . ")\n";
                $success = 0;
            }
            return (undef, undef);
        }
        return @{ $candidates[0] };
    };

    my $code_set_val = sub {
        my $is_neg = shift;
        my $name   = shift;

        my $parsed   = $parsed_spec{$name};
        my $spec_key = $parsed->{_orig};
        my $handler  = $spec->{$spec_key};
        my $ref      = ref($handler);

        my $val;
        if (@_) {
            $val = shift;
        } else {
            if ($parsed->{is_inc} && $ref eq 'SCALAR') {
                $val = ($$handler // 0) + 1;
            } elsif ($parsed->{type} && $parsed->{type} eq 'i' ||
                         $parsed->{opttype} && $parsed->{opttype} eq 'i') {
                $val = 0;
            } elsif ($parsed->{type} && $parsed->{type} eq 'f' ||
                         $parsed->{opttype} && $parsed->{opttype} eq 'f') {
                $val = 0;
            } elsif ($parsed->{type} && $parsed->{type} eq 's' ||
                         $parsed->{opttype} && $parsed->{opttype} eq 's') {
                $val = '';
            } else {
                $val = $is_neg ? 0 : 1;
            }
        }

        if ($ref eq 'CODE') {
            my $cb = Getopt::Long::Less::Callback->new(
                name => $name,
            );
            $handler->($cb, $val);
        } elsif ($ref eq 'SCALAR') {
            $$handler = $val;
        } elsif ($ref eq 'ARRAY') {
            # XXX
        } else {
            # no nothing
        }
    };

    my $i = -1;
    my @remaining;
  ELEM:
    while (++$i < @$argv) {
        if ($argv->[$i] eq '--') {

            if ($Opts->{permute}) { next } else { last ELEM }

        } elsif ($argv->[$i] =~ /\A--(.+?)(?:=(.*))?\z/) {

            my $used_name = $1;
            my ($opt, $is_neg) = $code_find_opt->($used_name);
            unless (defined $opt) {
                push @remaining, $argv->[$i];
                next ELEM;
            }

            my $spec = $parsed_spec{$opt};
            # check whether option requires an argument
            if ($spec->{type} ||
                    $spec->{opttype} && $i+1 < @$argv && $argv->[$i+1] !~ /\A-/) {
                # we are the last element
                if ($i+1 >= @$argv) {
                    unless ($Opts->{pass_through}) {
                        warn "Option $used_name requires an argument\n";
                        $success = 0;
                    }
                    last ELEM;
                }
                # take the next element as argument
                if ($spec->{type} || $argv->[$i+1] !~ /\A-/) {
                    $i++;
                    $code_set_val->($is_neg, $opt, $argv->[$i]);
                }
            } else {
                $code_set_val->($is_neg, $opt);
            }

        } elsif ($argv->[$i] =~ /\A-(.*)/) {

            my $str = $1;
            while ($str =~ s/(.)//) {
                my ($opt, $is_neg) = $code_find_opt->($1, 'short');
                next ELEM unless defined $opt;
            }

        } else { # argument

            if ($Opts->{permute}) { next } else { last ELEM }

        }
    }

  RETURN:
    splice @$argv, 0, ~~@$argv, @remaining; # replace with remaining elements
    return $success;
}

sub GetOptions {
    GetOptionsFromArray(\@ARGV, @_);
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
