use 5.006;    # our
use strict;
use warnings;

package Repo::Keyworder::VersionSort;

our $VERSION = '0.001000';

# ABSTRACT: Cache/wrap calls to qatom for version sorting

# AUTHORITY

sub new {
  my ( $class, $args ) = ( $_[0], ( ref $_[1] ? { %{ $_[1] } } : { @_[ 1 .. $#_ ] } ) );
  my $self = bless { _init_args => $args }, $class;
  return $self;
}

sub vcmp {
  my ( $self, $left, $right ) = @_;
  if ( exists $self->{cmp_cache}->{$left}->{$right} ) {
    return $self->{cmp_cache}->{$left}->{$right};
  }
  open my $fh, "-|", "qatom", "-c", "foo/foo-$left", "foo/foo-$right" or die "Can't invoke qatom";
  my (@lines) = <$fh>;
  chomp $lines[0];
  my ( $rleft, $op, $rright ) = split / /, $lines[0];
  if ( $op eq '<' ) {
    $self->{cmp_cache}->{$left}->{$right} = -1;
    $self->{cmp_cache}->{$right}->{$left} = 1;
    return -1;
  }
  if ( $op eq '>' ) {
    $self->{cmp_cache}->{$left}->{$right} = 1;
    $self->{cmp_cache}->{$right}->{$left} = -1;
    return 1;
  }
  if ( $op eq '==' ) {
    $self->{cmp_cache}->{$left}->{$right} = 0;
    $self->{cmp_cache}->{$right}->{$left} = 0;
    return 0;
  }
  warn "unhandled qatom op $op";
  return 0;
}

1;

