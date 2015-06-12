#!perl

use 5.010;
use strict;
use warnings;

use Getopt::Long::Less qw(Configure GetOptions GetOptionsFromArray);
use Test::Exception;
use Test::More 0.98;

test_getopt(
    args => ["foo"=>sub{}],
    argv => [],
    success => 1,
    remaining => [],
);

sub test_getopt {
    my %args = @_;

    my $res_hash;
    $res_hash = $args{args}[0] if ref($args{args}[0]) eq 'HASH';

    my $name = $args{name} // do {
        my $name = '';
        if (ref($args{args}[0]) eq 'HASH') {
            $name .= "spec:[".join(", ", @{ $args{args} }[1..@{$args{args}}-1])."]";
        } else {
            my %spec = @{ $args{args} };
            $name .= "spec:[".join(", ", sort keys %spec)."]";
        }
        $name .= " argv:[".join("", @{$args{argv}})."]";
        $name;
    };

    subtest $name => sub {
        my $old_opts;
        $old_opts = Configure(@{ $args{configure} }) if $args{configure};

        my @argv = @{ $args{argv} };
        my $res;
        eval { $res = GetOptionsFromArray(\@argv, @{ $args{args} }) };

        if ($args{dies}) {
            ok($@, "dies") or goto RETURN;
        } else {
            ok(!$@, "doesn't die") or do {
                diag explain "err=$@";
                goto RETURN;
            };
        }

        if (defined($args{success})) {
            is(!!$res, !!$args{success}, "success=$args{success}");
        }

        if (defined($args{remaining})) {
            is_deeply(\@argv, $args{remaining}, "remaining");
        }

      RETURN:
        Configure($old_opts) if $old_opts;
    };
}

done_testing;
