#!perl

use 5.010;
use strict;
use warnings;

use Getopt::Long::Less qw(Configure GetOptions GetOptionsFromArray);
use Test::Exception;
use Test::More 0.98;

my $Res_Hash;

{
    my $val;
    test_getopt(
        name => 'store to scalar ref',
        args => ["foo=s"=>\$val],
        argv => ["--foo", "bar"],
        success => 1,
        input_res_hash    => {foo=>$val},
        expected_res_hash => {foo=>"bar"},
        remaining => [],
    );
}

# XXX test that we are case sensitive
# XXX test bundling ...
# XXX opt: test pass_through
# XXX opt: test permute
# XXX test dies when we specify repeat (not supported with bundling)
# XXX test gnu_compat (--foo val, --foo=val, --foo=)
# XXX test only -- is accepted
# XXX test required argument (--reqarg, --reqarg val, --reqarg --unknown, --reqarg --other)
# XXX test optional argument (--optarg, --optarg val, --optarg --unknown, --optarg --other)
# XXX test type checking for i
# XXX test type checking for f
# XXX test bool (--nofoo, --no-foo, --foo --nofoo --foo ...)
# XXX test + (--more --more)
# XXX test set scalar -> noop
# XXX test set array ref
# XXX test set subref
# XXX test set scalar ref
# XXX test hashref as first arg

sub test_getopt {
    my %args = @_;

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
        $Res_Hash = {};

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

        if ($args{expected_res_hash}) {
            # in 'input_res_hash', user supplies the hash she uses to store the
            # options in (or if unspecified, defaults to $Res_Hash). then, it
            # supplies the expected hash in 'expected_res_hash'.
            my $res_hash = $args{input_res_hash} // $Res_Hash;

            is_deeply($res_hash, $args{expected_res_hash}, "res_hash")
                or diag explain $res_hash;
        }

        if ($args{remaining}) {
            is_deeply(\@argv, $args{remaining}, "remaining");
        }

      RETURN:
        Configure($old_opts) if $old_opts;
    };
}

done_testing;
