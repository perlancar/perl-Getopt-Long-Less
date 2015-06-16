#!perl

use 5.010;
use strict;
use warnings;

use Getopt::Long::Less qw(Configure GetOptions GetOptionsFromArray);
use Test::Exception;
use Test::More 0.98;

{
    my $r = {};
    test_getopt(
        name => 'store to scalar ref',
        args => ["foo=s"=>\$r->{foo}],
        argv => ["--foo", "val"],
        success => 1,
        input_res_hash    => $r,
        expected_res_hash => {foo=>"val"},
        remaining => [],
    );
}

test_getopt(
    name => 'store to hashref (in first argument)',
    args => [{}, "foo=s", "bar", "baz=i"],
    argv => ["--foo", "val", "--bar", "--baz", 3],
    success => 1,
    expected_res_hash => {foo=>"val", bar=>1, baz=>3},
    remaining => [],
);

subtest "default value" => sub {
    test_getopt(
        name => 'default value for type=int',
        args => [{}, "foo:i"],
        argv => ["--foo"],
        success => 1,
        expected_res_hash => {foo=>0},
        remaining => [],
    );
    test_getopt(
        name => 'default value for type=float',
        args => [{}, "foo:f"],
        argv => ["--foo"],
        success => 1,
        expected_res_hash => {foo=>0},
        remaining => [],
    );
    test_getopt(
        name => 'default value for type=string',
        args => [{}, "foo:s"],
        argv => ["--foo"],
        success => 1,
        expected_res_hash => {foo=>''},
        remaining => [],
    );
    test_getopt(
        name => 'default value for negatable option (positive)',
        args => [{}, "foo!"],
        argv => ["--foo"],
        success => 1,
        expected_res_hash => {foo=>1},
        remaining => [],
    );
    test_getopt(
        name => 'default value for negatable option (negative 1)',
        args => [{}, "foo!"],
        argv => ["--nofoo"],
        success => 1,
        expected_res_hash => {foo=>0},
        remaining => [],
    );
    test_getopt(
        name => 'default value for negatable option (negative 2)',
        args => [{}, "foo!"],
        argv => ["--no-foo"],
        success => 1,
        expected_res_hash => {foo=>0},
        remaining => [],
    );
};

test_getopt(
    name => 'case sensitive',
    args => [{}, "foo"],
    argv => ["--Foo"],
    success => 0,
);

subtest "bundling" => sub {
    test_getopt(
        name => 'bundling sensitive',
        args => [{}, "foo"],
        argv => ["--Foo"],
        success => 0,
    );
};

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
            # options in (optional if first argument is hashref).
            my $res_hash = $args{input_res_hash} //
                (ref($args{args}[0]) eq 'HASH' ? $args{args}[0] : undef);
            die "BUG: Please specify input_res_hash" unless $res_hash;

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
