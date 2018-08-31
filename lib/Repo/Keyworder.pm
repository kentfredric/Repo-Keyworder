use 5.006;  # our
use strict;
use warnings;

package Repo::Keyworder;

our $VERSION = '0.001000';

# ABSTRACT: Transform keywords

# AUTHORITY

use Repo::Keyworder::Cache;

sub new {
  my ( $self, $repo ) = @_;
  return bless {
    repo => $repo,
    cache => Repo::Keyworder::Cache->new(
      repo => $repo,
    ),
  }, $self;
}
use Data::Dump qw(pp);
sub get_ebuild_keywords {
  my ( $self, $ebuild_rel ) = @_;
  my $path = $self->{repo} . '/' . $ebuild_rel;
  if ( !-e $path or -d $path ) {
    die "$path is not a file";
  }
  # Convert path to atom
  my ( $cat, $pkg, $version ) = $ebuild_rel =~ qr{
    ^
      ([^/]+) /
      ([^/]+) /
      \2-(.*?)\.ebuild
    $
  }x;
  return $self->{cache}->get_keywords($cat,$pkg, $version);
}





1;

