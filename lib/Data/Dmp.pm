package Data::Dmp;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Scalar::Util qw(looks_like_number blessed reftype refaddr);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(dd dmp);

# for when dealing with circular refs
our %_seen_refaddrs;
our %_subscripts;
our @_fixups;

our $OPT_PERL_VERSION;

# BEGIN COPY PASTE FROM Data::Dump
my %esc = (
    "\a" => "\\a",
    "\b" => "\\b",
    "\t" => "\\t",
    "\n" => "\\n",
    "\f" => "\\f",
    "\r" => "\\r",
    "\e" => "\\e",
);

# put a string value in double quotes
sub _double_quote {
    local($_) = $_[0];

    # If there are many '"' we might want to use qq() instead
    s/([\\\"\@\$])/\\$1/g;
    return qq("$_") unless /[^\040-\176]/;  # fast exit

    s/([\a\b\t\n\f\r\e])/$esc{$1}/g;

    # no need for 3 digits in escape for these
    s/([\0-\037])(?!\d)/sprintf('\\%o',ord($1))/eg;

    s/([\0-\037\177-\377])/sprintf('\\x%02X',ord($1))/eg;
    s/([^\040-\176])/sprintf('\\x{%X}',ord($1))/eg;

    return qq("$_");
}
# END COPY PASTE FROM Data::Dump

sub _dump {
    my ($val, $subscript) = @_;

    my $ref = ref($val);
    if ($ref eq '') {
        if (!defined($val)) {
            return "undef";
        } elsif (looks_like_number($val)) {
            return $val;
        } else {
            return _double_quote($val);
        }
    }
    my $refaddr = refaddr($val);
    $_subscripts{$refaddr} //= $subscript;
    if ($_seen_refaddrs{$refaddr}++) {
        push @_fixups, " " if @_fixups;
        push @_fixups, "\$a->$subscript = \$a",
            ($_subscripts{$refaddr} ? "->$_subscripts{$refaddr}" : ""), ";";
        return "'fix'";
    }

    my $class;

    if ($ref eq 'Regexp' || $ref eq 'REGEXP') {
        require Regexp::Stringify;
        return Regexp::Stringify::stringify_regexp(
            regexp=>$val, with_qr=>1, plver=>$OPT_PERL_VERSION);
    }

    if (blessed $val) {
        $class = $ref;
        $ref = reftype($val);
    }

    my $res;
    if ($ref eq 'ARRAY') {
        $res = "[";
        my $i = 0;
        for (@$val) {
            $res .= ", " if $i;
            $res .= _dump($_, "$subscript\[$i]");
            $i++;
        }
        $res .= "]";
    } elsif ($ref eq 'HASH') {
        $res = "{";
        my $i = 0;
        for (sort keys %$val) {
            $res .= ", " if $i++;
            my $k = /\W/ ? _double_quote($_) : $_;
            my $v = _dump($val->{$_}, "$subscript\{$k}");
            $res .= "$k=>$v";
        }
        $res .= "}";
    } elsif ($ref eq 'SCALAR') {
        $res = "\\"._dump($$val, $subscript);
    } elsif ($ref eq 'REF') {
        $res = "\\"._dump($$val, $subscript);
    } elsif ($ref eq 'CODE') {
        $res = "sub{'DUMMY'}";
    } else {
        die "Sorry, I can't dump $val (ref=$ref) yet";
    }

    $res = "bless($res, "._double_quote($class).")" if defined($class);
    $res;
}

our $_is_dd;
sub _dd_or_dmp {
    local %_seen_refaddrs;
    local %_subscripts;
    local @_fixups;

    my $res;
    if (@_ > 1) {
        $res = "(" . join(", ", map {_dump($_, '')} @_) . ")";
    } else {
        $res = _dump($_[0], '');
    }
    if (@_fixups) {
        $res = "do { my \$a = $res; " . join("", @_fixups) . " \$a }";
    }

    if ($_is_dd) {
        say $res;
        return @_;
    } else {
        return $res;
    }
}

sub dd { local $_is_dd=1; _dd_or_dmp(@_) }
sub dmp { goto &_dd_or_dmp }

1;
# ABSTRACT: Dump Perl data structures

=head1 SYNOPSIS

 use Data::Dmp; # exports dd() and dmp()
 dd [1, 2, 3];


=head1 DESCRIPTION

This module, Data::Dmp, is inspired by L<Data::Dump> and is my personal
experiment. I want some of Data::Dump's features which I currently need and
don't need the others that I currently do not need. I also want a smaller code
base so I can easily modify (or subclass) it for custom dumping requirements.

Compared to C<Data::Dump>, C<Data::Dmp> is also pure-Perl, dumps Perl data
structure as runnable Perl code, supports circular/blessed references. Unlike
C<Data::Dump>, C<Data::Dmp> does not identify tied data, does not support globs,
does not support filtering, and mostly does not bother to align hash keys,
identify ranges/repetition pattern. This makes the code simpler.

I originally created C<Data::Dmp> when wanting to write L<Data::Dmp::Org>. At
first I tried to modify C<Data::Dump>, but then got distracted by the extra bits
that I don't need.


=head1 FUNCTIONS

=head2 dd($data, ...) => $data ...

Exported by default. Like C<Data::Dump>'s C<dd> (a.k.a. C<dump>), print one or
more data to STDOUT. Unlike C<Data::Dump>'s C<dd>, it I<always> prints and
return I<the original data> (like L<XXX>), making it convenient to insert into
expressions. This also removes ambiguity and saves one C<wantarray()> call.

=head2 dmp($data, ...) => $str

Exported by default. Return dump result as string. Unlike C<Data::Dump>'s C<dd>
(a.k.a. C<dump>), it I<never> prints and only return the data.


=head1 SETTINGS

=head2 $Data::Dmp::OPT_PERL_VERSION => str

Set target Perl version. Currently this is used when passing to
L<Regexp::Stringify>. If you set this to, say C<5.010>, then the dumped code
will keep compatibility with Perl 5.10.0.


=head1 BENCHMARKS

Because C<Data::Dmp>'s code is simpler than C<Data::Dump> and it does less,
Data::Dmp is significantly faster than Data::Dump (around 5 times for some small
data structures). C<Data::Dmp> is even faster than L<Data::Dumper> for some
small data structures.


=head1 FAQ

=head2 When to use Data::Dmp? How does it compare to other dumper modules?

Data::Dmp might be suitable for you if you want a relatively fast pure-Perl data
structure dumper to eval-able Perl code. It produces compact, single-line Perl
code but offers little/no formatting options. Data::Dmp and Data::Dump module
family usually produce Perl code that is "more eval-able", e.g. it can recreate
circular structure.

Data::Dump produces nicer output (some alignment, use of range operator to
shorten lists, use of base64 for binary data, etc) but no built-in option to
produce compact/single-line output. It's also relatively slow. I usually use its
variant, L<Data::Dump::Color>, for console debugging.

Data::Dumper is core module, offers a lot of formatting options (like disabling
hash key sorting, setting verboseness/indent level, and so on) but you usually
have to configure it quite a bit before it does exactly like you want (that's
why there are modules on CPAN that are just wrapping Data::Dumper with some
configuration, like L<Data::Dumper::Concise> et al). It does not support dumping
Perl code that can recreate circular structures.

Currently Data::Dmp does not support "deparse". As for other features, currently
they are implemented if I personally have the need for them.

Of course, dumping to eval-able Perl code is slow (not to mention the cost of
re-loading the code back to in-memory data, via eval-ing) compared to dumping to
JSON, YAML, Sereal, or other format. So you need to decide first whether this is
the appropriate route you want to take.


=head1 SEE ALSO

L<Data::Dump> and other variations/derivate works in Data::Dump::*.

L<Data::Dumper> and its variants.

L<Data::Printer>.

L<YAML>, L<JSON>, L<Storable>, L<Sereal>, and other serialization formats.

=cut
