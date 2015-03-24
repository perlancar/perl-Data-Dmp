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

# scalar ref
is(dmp(\1), q[\\1]);

# ref
is(dmp(\\1), q[\\\\1]);

# array
is(dmp([]), q([]));
is(dmp([1,2,3]), q([1,2,3]));

# hash
is(dmp({}), q({}));
is(dmp({a=>1,"b c"=>2}), q({a=>1,"b c"=>2}));

# circular
{
    my $circ = [1]; push @$circ, $circ;
    is(dmp($circ), q(do{my$a=[1,'fix'];$a->[1]=$a;$a}));
    my $circ2 = {a=>$circ}; push @$circ, $circ2;
    is(dmp($circ),
       q(do{my$a=[1,'fix',{a=>'fix'}];$a->[1]=$a;$a->[2]{a}=$a;$a}));
}

# code
is(dmp(sub{}), q(sub{'DUMMY'}));

# object
is(dmp(bless({}, "Foo")), q(bless({},"Foo")));

# regexp
is(dmp(qr/abc/i), q{qr(abc)i});

DONE_TESTING:
done_testing;
