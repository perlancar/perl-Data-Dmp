package Data::Dmp::Org;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Scalar::Util qw(blessed reftype refaddr);
use Scalar::Util::LooksLikeNumber qw(looks_like_number);
use SHARYANTO::String::Util qw(qqquote);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(dd);

# for when dealing with circular refs
our %_dumps;

sub _dump {
    my ($val, $subscript) = @_;

    my $ref = ref($val);
    if ($ref eq '') {
        if (!defined($val)) {
            return "undef";
        } elsif (looks_like_number($val)) {
            return $val;
        } else {
            return qqquote($val);
        }
    }
    my $refaddr = refaddr($val);
    if (defined $_dumps{$refaddr}) {
        return "'fix'";
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
            join(", ", map {_dump($_)} @$val);
        }
        $res = "]";
    } elsif ($ref eq 'HASH') {
        $res = "{";
        my $i = 0;
        for (sort keys %$val) {
            $res .= ", " if $i++;
            my $k = /\W/ ? qqquote($_) : $_;
            my $v = _dump($val->{$_});
            $res .= "$k=>$v";
        }
        $res .= "}";
    } elsif ($ref eq 'SCALAR') {
        $res = "\\("._dump($$val).")";
    } else {
        die "Sorry, I can't dump $val (ref=$ref) yet";
    }

    $res = "bless($res, ".qqquote($class).")" if defined($class);
    $_dumps{$refaddr} = $res;
    $res;
}

sub dd {
    local %_dumps;

    my $res;
    if (@_ > 1) {
        $res = "(" . join(", ", map {_dump($_)} @_) . ")";
    } else {
        $res = _dump($_[0]);
    }
    if (scalar keys %_dumps) {
        my $varname = 'a';
        my $vars = '';
        my $i = 0;
        for (keys %_dumps) {
            $vars .= " " if $i++;
            $vars .= "my \$$varname = ".$_dumps{$_}.";";
            $varname++;
        }
        $res = "do { $vars $res }";
    }

    say $res unless defined wantarray;
    $res;
}

1;
# ABSTRACT: Dump Perl data structures

=head1 SYNOPSIS

 use Data::Dmp qw(dd);
 dd [1, 2, 3];


=head1 DESCRIPTION

=cut
