package Getopt::Long::Less;

# DATE
# VERSION

use 5.010001;
use strict 'subs', 'vars';
# IFUNBUILT
use warnings;
# END IFUNBUILT

our @EXPORT   = qw(GetOptions);
our @EXPORT_OK = qw(Configure GetOptionsFromArray);

my $Opts = {};

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
            elsif ($_ eq 'no_getopt_compat') { next }
            elsif ($_ eq 'permute') { next }
            elsif (/\Ano_?require_order\z/) { next }
            #elsif (/\A(no_?)?pass_through\z/) { $Opts->{pass_through} = $1 ?0:1 }
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
            warn "Unknown option: $wanted\n";
            $success = 0;
            return (undef, undef);
        } elsif (@candidates > 1) {
            warn "Option $wanted is ambiguous (" .
                join(", ", map {$_->[0]} @candidates) . ")\n";
            $success = 0;
            return (undef, undef, 1);
        }
        return @{ $candidates[0] };
    };

    my $code_set_val = sub {
        my $is_neg = shift;
        my $name   = shift;

        my $parsed   = $parsed_spec{$name};
        my $spec_key = $parsed->{_orig};
        my $destination = $spec->{$spec_key};
        my $ref      = ref $destination;

        my $val;
        if (@_) {
            $val = shift;
        } else {
            if ($parsed->{is_inc} && $ref eq 'SCALAR') {
                $val = ($$destination // 0) + 1;
            } elsif ($parsed->{is_inc} && $vals) {
                $val = ($vals->{$name} // 0) + 1;
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

        # type checking
        if ($parsed->{type} && $parsed->{type} eq 'i' ||
                $parsed->{opttype} && $parsed->{opttype} eq 'i') {
            unless ($val =~ /\A[+-]?\d+\z/) {
                warn qq|Value "$val" invalid for option $name (number expected)\n|;
                return 0;
            }
        } elsif ($parsed->{type} && $parsed->{type} eq 'f' ||
                $parsed->{opttype} && $parsed->{opttype} eq 'f') {
            unless ($val =~ /\A[+-]?(\d+(\.\d+)?|\.\d+)([Ee][+-]?\d+)?\z/) {
                warn qq|Value "$val" invalid for option $name (number expected)\n|;
                return 0;
            }
        }

        if ($ref eq 'CODE') {
            my $cb = Getopt::Long::Less::Callback->new(
                name => $name,
            );
            $destination->($cb, $val);
        } elsif ($ref eq 'SCALAR') {
            $$destination = $val;
        } else {
            # no nothing
        }
        1;
    };

    my $i = -1;
    my @remaining;
  ELEM:
    while (++$i < @$argv) {
        if ($argv->[$i] eq '--') {

            push @remaining, @{$argv}[$i+1 .. @$argv-1];
            last ELEM;

        } elsif ($argv->[$i] =~ /\A--(.+?)(?:=(.*))?\z/) {

            my ($used_name, $val_in_opt) = ($1, $2);
            my ($opt, $is_neg, $is_ambig) = $code_find_opt->($used_name);
            unless (defined $opt) {
                push @remaining, $argv->[$i] unless $is_ambig;
                next ELEM;
            }

            my $spec = $parsed_spec{$opt};
            # check whether option requires an argument
            if ($spec->{type} ||
                    $spec->{opttype} &&
                    (defined($val_in_opt) && length($val_in_opt) || ($i+1 < @$argv && $argv->[$i+1] !~ /\A-/))) {
                if (defined($val_in_opt)) {
                    # argument is taken after =
                    unless ($code_set_val->($is_neg, $opt, $val_in_opt)) {
                        $success = 0;
                        next ELEM;
                    }
                } else {
                    if ($i+1 >= @$argv) {
                        # we are the last element
                        warn "Option $used_name requires an argument\n";
                        $success = 0;
                        last ELEM;
                    }
                    # take the next element as argument
                    if ($spec->{type} || $argv->[$i+1] !~ /\A-/) {
                        $i++;
                        unless ($code_set_val->($is_neg, $opt, $argv->[$i])) {
                            $success = 0;
                            next ELEM;
                        }
                    }
                }
            } else {
                unless ($code_set_val->($is_neg, $opt)) {
                    $success = 0;
                    next ELEM;
                }
            }

        } elsif ($argv->[$i] =~ /\A-(.*)/) {

            my $str = $1;
          SHORT_OPT:
            while ($str =~ s/(.)//) {
                my $used_name = $1;
                my ($opt, $is_neg) = $code_find_opt->($1, 'short');
                next SHORT_OPT unless defined $opt;

                my $spec = $parsed_spec{$opt};
                # check whether option requires an argument
                if ($spec->{type} ||
                        $spec->{opttype} &&
                        (length($str) || ($i+1 < @$argv && $argv->[$i+1] !~ /\A-/))) {
                    if (length $str) {
                        # argument is taken from $str
                        if ($code_set_val->($is_neg, $opt, $str)) {
                            next ELEM;
                        } else {
                            $success = 0;
                            next SHORT_OPT;
                        }
                    } else {
                        if ($i+1 >= @$argv) {
                            # we are the last element
                            warn "Option $used_name requires an argument\n";
                            $success = 0;
                            last ELEM;
                        }
                        # take the next element as argument
                        if ($spec->{type} || $argv->[$i+1] !~ /\A-/) {
                            $i++;
                            unless ($code_set_val->($is_neg, $opt, $argv->[$i])) {
                                $success = 0;
                                next ELEM;
                            }
                        }
                    }
                } else {
                    unless ($code_set_val->($is_neg, $opt)) {
                        $success = 0;
                        next SHORT_OPT;
                    }
                }
            }

        } else { # argument

            push @remaining, $argv->[$i];
            next;

        }
    }

  RETURN:
    splice @$argv, 0, ~~@$argv, @remaining; # replace with remaining elements
    return $success;
}

sub GetOptions {
    GetOptionsFromArray(\@ARGV, @_);
}

# IFBUILT
# # INSERT_BLOCK: Getopt::Long::Util parse_getopt_long_opt_spec
# END IFBUILT
# IFUNBUILT
require Getopt::Long::Util; *parse_getopt_long_opt_spec = \&Getopt::Long::Util::parse_getopt_long_opt_spec;
# END IFUNBUILT

package Getopt::Long::Less::Callback;

sub new {
    my $class = shift;
    bless {@_}, $class;
}

sub name {
    shift->{name};
}

1;
#ABSTRACT: Like Getopt::Long, but with less features

=for Pod::Coverage .+

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
is not Getopt::Long's default>), we always permute, we always autoabbreviate, we
always do GNU compatibility (allow C<--opt=VAL> in addition to C<--opt VAL>
including allowing C<--opt=>), we never do getopt_compat. Basically currently
there's no mode you can configure (although pass_through might be added in the
future).

No autoversion, no autohelp. No support to configure prefix pattern.

No support for GetOptions' "hash storage mode" (where the first argument is a
hashref) nor "classic mode" (where destination is not explicitly specified).
Basically, the arguments need to be pairs of option specifications and
destinations.

Currently no support for arrayref destination (e.g. C<< "foo=s" => \@ary >>). No
support for array desttype (C<< 'foo=s@' => ... >>).

Also, this module requires 5.010.

So what's good about this module? Slightly less compile time overhead, due to
less code. This should not matter for most people. I just like squeezing out
milliseconds from startup overhead of my CLI scripts. That's it :-)

Sample startup overhead benchmark:

# COMMAND: perl devscripts/bench-startup 2>&1


=head1 SEE ALSO

L<Getopt::Long>

If you want I<more> features intead of less, try L<Getopt::Long::More>.

=cut
