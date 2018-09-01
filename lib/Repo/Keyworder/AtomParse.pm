use 5.006;    # our
use strict;
use warnings;

package Repo::Keyworder::AtomParse;

our $VERSION = '0.001000';

# ABSTRACT: Translate dependency specs to other formats

# AUTHORITY

sub new {
  my ( $class, $args ) = ( $_[0], ( ref $_[1] ? { %{ $_[1] } } : { @_[ 1 .. $#_ ] } ) );
  return bless { _init_args => $args }, $class;
}

sub to_catpn {
  my ( $self, $depspec ) = @_;
  if ( exists $self->{catpn_cache}->{$depspec} ) {
    return $self->{catpn_cache}->{$depspec};
  }
  $depspec =~ s/\[.*\]//g;
  local ( $!, $? );
  open my $fh, '-|', 'qatom', '-F', '%{CATEGORY}/%{PN}', $depspec or die "Can't invoke qatom, $! $?";
  my (@lines) = <$fh>;
  close $fh or warn "error closing qatom, $! $?";
  chomp $lines[0];

  return if not length $lines[0];
  $self->{catpn_cache}->{$depspec} = $lines[0];
  return $lines[0];
}

sub split_atom {
  my ( $self, $depspec ) = @_;
  if ( exists $self->{split_atom_cache}->{$depspec} ) {
    return @{ $self->{split_atom_cache}->{$depspec} };
  }
  $depspec =~ s/\[.*\]//g;
  local ( $!, $? );
  open my $fh, '-|', 'qatom', '-F', '%{CATEGORY} %{PN} %{PV} %[PR]', $depspec or die "Can't invoke qatom, $! $?";
  my (@lines) = <$fh>;
  close $fh or warn "error closing qatom, $! $?";
  chomp $lines[0];

  return if not length $lines[0];
  my ( $category, $pn, $pv, $pr ) = split / /, $lines[0];
  $pv .= "-" . $pr if defined $pr and length $pr;
  $self->{split_atom_cache}->{$depspec} = [ $category, $pn, $pv ];
  return ( $category, $pn, $pv );
}

1;

