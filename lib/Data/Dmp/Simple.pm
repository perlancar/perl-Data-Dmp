package Data::Dmp::Simple;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Data::Dmp ();
use Scalar::Util qw(looks_like_number blessed reftype refaddr);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(dd dmp);

# for when dealing with circular refs
our %_seen_refaddrs;
our %_subscripts;

*_double_quote = \&Data::Dmp::_double_quote;

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
        return "...";
    }

    my $class;
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

    my $res;
    if (@_ > 1) {
        $res = "(" . join(", ", map {_dump($_, '')} @_) . ")";
    } else {
        $res = _dump($_[0], '');
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
# ABSTRACT: Dump Perl data structures (simpler version)

=head1 SYNOPSIS

 use Data::Dmp::Simple; # exports dd() and dmp()
 my $data = [1, 2]; push @$data, $data; # circular
 dd $data; # => "[1, 2, ...]"


=head1 DESCRIPTION

This module is like L<Data::Dmp> except it does I<not> necessarily produce a
valid Perl code. In the case of circular references, it just dumps as C<"...">
(like in Python or Ruby).


=head1 FUNCTIONS

=head2 dd($data, ...) => $data ...

Exported by default. Like Data::Dump's dd, print one or more data to STDOUT.
Unlike Data::Dump's dd, it I<always> prints and return I<the original data>
(like L<XXX>), making it convenient to insert into expressions.

=head2 dmp($data, ...) => $str

Exported by default. Return dump result as string.


=head1 SEE ALSO

L<Data::Dmp>

=cut
