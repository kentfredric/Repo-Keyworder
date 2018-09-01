use 5.006;    # our
use strict;
use warnings;

package Repo::Keyworder;

our $VERSION = '0.001000';

# ABSTRACT: Transform keywords

# AUTHORITY

use Repo::Keyworder::Cache;
use Repo::Keyworder::VersionSort;

sub new {
  my ( $self, %opts ) = @_;

  return bless {
    repo  => $opts{repo},
    cache => Repo::Keyworder::Cache->new(
      repo => $opts{repo},
      ( exists $opts{cache_fallbacks} ? ( cache_fallbacks => $opts{cache_fallbacks} ) : () ),
    ),
    vsort => Repo::Keyworder::VersionSort->new(),
  }, $self;
}

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
  return $self->{cache}->get_keywords( $cat, $pkg, $version );
}

sub get_ebuild_missing_keywords {
  my ( $self, $ebuild_rel, $wanted ) = @_;
  my (%current) = %{ $self->_decode_keywords( $ebuild_rel, {}, $self->get_ebuild_keywords($ebuild_rel) ) };
  my (%missing);
  for my $key ( sort keys %{$wanted} ) {
    if ( not exists $current{$key} ) {
      $missing{$key} = 'unstable';
      next;
    }
    next if $current{$key} eq $wanted->{$key};
    if ( $current{$key} eq 'unstable' and $wanted->{$key} eq 'stable' ) {
      $missing{$key} = 'stable';
    }
  }
  return \%missing;
}

sub get_package_versions {
  my ( $self, $catpn ) = @_;
  my $path = $self->{repo} . '/' . $catpn;
  if ( !-e $path or !-d $path ) {
    die "$path is not a package";
  }
  my ( $cat, $pkg ) = $catpn =~ qr{
  ^
    ([^/]+) /
    ([^/]+)
  $
  }x;
  local ( $!, $? );
  opendir my $pkdir, $path or die "can't opendir $path, $! $?";
  my @versions;
  while ( my $ebuild = readdir $pkdir ) {
    next unless $ebuild =~ /\.ebuild$/;
    next if -d "${path}/${ebuild}";
    my ($version) = $ebuild =~ qr{
    ^
      \Q${pkg}\E-
      (.+)
      \.ebuild
     $
    }x;
    push @versions, $version;
  }
  return [ sort { $self->{vsort}->vcmp( $a, $b ) } @versions ];
}

sub get_package_best_version {
  my ( $self, $catpn ) = @_;
  my (@versions) = @{ $self->get_package_versions($catpn) };
  my ( $cat, $pkg ) = $catpn =~ qr{
  ^
    ([^/]+) /
    ([^/]+)
  $
  }x;

  while (@versions) {
    my $best = pop @versions;
    my (@keywords) = $self->get_ebuild_keywords("${cat}/${pkg}/${pkg}-${best}.ebuild");
    next unless @keywords;
    return $best;
  }
  return;
}

sub get_package_keywords {
  my ( $self, $catpn ) = @_;
  my $path = $self->{repo} . '/' . $catpn;
  my ( $cat, $pkg ) = $catpn =~ qr{
  ^
    ([^/]+) /
    ([^/]+)
  $
  }x;
  my %keywords;
  for my $version ( @{ $self->get_package_versions($catpn) } ) {
    (%keywords) =
      %{ $self->_decode_keywords( "$catpn version $version", \%keywords, $self->{cache}->get_keywords( $cat, $pkg, $version ) ) };
  }
  return \%keywords;
}

sub _decode_keywords {
  my ( $self, $context, $store, @keywords ) = @_;
  my (%keywords) = %{$store};
  for my $keyword (@keywords) {
    if ( $keyword =~ /^~(.*)$/ ) {
      if ( not exists $keywords{$1} ) {
        $keywords{$1} = 'unstable';
        next;
      }
      next;
    }
    if ( $keyword =~ /^([^~-].*)$/ ) {
      if ( not exists $keywords{$1} ) {
        $keywords{$1} = 'stable';
        next;
      }
      next if $keywords{$1} eq 'stable';
      if ( $keywords{$1} eq 'unstable' ) {
        $keywords{$1} = 'stable';
        next;
      }
    }
    if ( $keyword =~ /^-(.*)$/ ) {
      $keywords{$1} = 'blocked';
      next;
    }
    warn "Unhandled keyword $keyword for $context";
  }
  return \%keywords;
}

1;

