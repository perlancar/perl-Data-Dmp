#!perl

use 5.010;
use strict;
use warnings;

use Data::Dmp qw(dmp);
use Test::More 0.98;

# undef
is(dmp(undef), "undef");

# scalar
is(dmp(""), q[""]);
is(dmp("\n "), q["\n "]);
is(dmp("123"), q[123]);
is(dmp("0123"), q["0123"]);
is(dmp("1e2"), q["1e2"]);
is(dmp("Inf"), q["Inf"]);

subtest "OPT_STRINGIFY_NUMBERS=1" => sub {
    local $Data::Dmp::OPT_STRINGIFY_NUMBERS = 1;
    is(dmp("123"), q["123"]);
};

# scalar ref
is(dmp(\1), q[\\1]);

# ref
is(dmp(\\1), q[\\\\1]);

# array
is(dmp([]), q([]));
is(dmp([1,2,3]), q([1,2,3]));

# hash
is(dmp({}), q({}));
is(dmp({"0123"=>3,"1_2"=>4,23=>5,"3000000000"=>6,a=>1,"b c"=>2}),
   q({"0123"=>3,"1_2"=>4,23=>5,"3000000000"=>6,a=>1,"b c"=>2}));
subtest "dumping %+" => sub {
    "abc" =~ /(?<a>a)(?<b>b.*)/;
    is_deeply(dmp(\%+), '{a=>"a",b=>"bc"}');
};

# circular
{
    my $circ = [1]; push @$circ, $circ;
    is(dmp($circ), q(do{my$a=[1,'fix'];$a->[1]=$a;$a}));
    my $circ2 = {a=>$circ}; push @$circ, $circ2;
    is(dmp($circ),
       q(do{my$a=[1,'fix',{a=>'fix'}];$a->[1]=$a;$a->[2]{a}=$a;$a}));
}

# code
like(dmp(sub{my $foo=1}), qr/sub\s*{.*\$foo.*\}/);
subtest "OPT_REMOVE_PRAGMAS=1" => sub {
    local $Data::Dmp::OPT_REMOVE_PRAGMAS = 1;
    is(dmp(sub{}), 'sub{}');
    is(dmp(sub{$_[0]<=>$_[1]}), 'sub{$_[0] <=> $_[1]}');
    is(dmp(sub{ $a = uc($a); $b = uc($b); $a <=> $b; }), 'sub{$a = uc $a;$b = uc $b;$a <=> $b}');
};
subtest "OPT_DEPARSE=0" => sub {
    local $Data::Dmp::OPT_DEPARSE = 0;
    is(dmp(sub{}), 'sub{"DUMMY"}');
};

# XXX test OPT_PERL_VERSION

# object
is(dmp(bless({}, "Foo")), q(bless({},"Foo")));

# regexp
is(dmp(qr/abc/i), q{qr(abc)i});

DONE_TESTING:
done_testing;
