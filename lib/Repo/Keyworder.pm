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
  return $self->{cache}->get_keywords( $self->_split_ebuild($ebuild_rel) );
}

sub get_ebuild_missing_keywords {
  my ( $self, $ebuild_rel, $wanted ) = @_;
  my (%current) = %{ $self->_decode_keywords( $ebuild_rel, {}, $self->get_ebuild_keywords($ebuild_rel) ) };
  my (%missing);
  for my $key ( sort keys %{$wanted} ) {
    if ( not exists $current{$key} ) {
      $missing{$key} = $wanted->{$key};
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
  my ( $cat, $pkg ) = $self->_split_package($catpn);
  local ( $!, $? );
  opendir my $pkdir, $path or die "can't opendir $path, $! $?";
  my @versions;
  while ( my $ebuild = readdir $pkdir ) {
    next unless $ebuild =~ /\.ebuild$/;
    next if -d "${path}/${ebuild}";
    push @versions, $self->_extract_ebuild_version( $pkg, $ebuild );
  }
  return [ sort { $self->{vsort}->vcmp( $a, $b ) } @versions ];
}

sub get_package_best_version {
  my ( $self, $catpn ) = @_;
  my (@versions) = @{ $self->get_package_versions($catpn) };
  my ( $cat, $pkg ) = $self->_split_package($catpn);
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
  my %keywords;
  for my $version ( @{ $self->get_package_versions($catpn) } ) {
    (%keywords) = %{
      $self->_decode_keywords( "$catpn version $version",
        \%keywords, $self->{cache}->get_keywords( $self->_split_package($catpn), $version ) )
    };
  }
  return \%keywords;
}

sub get_ebuild_dependencies {
  my ( $self, $ebuild_rel ) = @_;
  my $path = $self->{repo} . '/' . $ebuild_rel;
  if ( !-e $path or -d $path ) {
    die "$path is not a file";
  }
  my $info = $self->{cache}->get_cache_info( $self->_split_ebuild($ebuild_rel) );
  my (%alldepend);
  for my $depend ( sort keys %{$info} ) {
    next unless $depend =~ /DEPEND$/;
    for my $dep ( $self->_parse_depend( $info->{$depend} ) ) {
      $alldepend{$dep} = undef;
    }
  }
  return \%alldepend;
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

sub _split_ebuild {
  my ( $self, $ebuild_rel ) = @_;

  # Convert path to atom
  my ( $cat, $pkg, $version ) = $ebuild_rel =~ qr{
    ^
      ([^/]+) /
      ([^/]+) /
      \2-(.*?)\.ebuild
    $
  }x;
  return ( $cat, $pkg, $version );
}

sub _split_package {
  my ( $self, $catpn ) = @_;
  my ( $cat,  $pkg )   = $catpn =~ qr{
  ^
    ([^/]+) /
    ([^/]+)
  $
  }x;
  return ( $cat, $pkg );
}

sub _extract_ebuild_version {
  my ( $self, $package, $ebuild ) = @_;
  my ($version) = $ebuild =~ qr{
    ^
      \Q${package}\E-
      (.+)
      \.ebuild
     $
    }x;
  return $version;
}

sub _extract_paren {
  my ( $self, $string ) = @_;
  my $out    = "";
  my $pdepth = 0;
  if ( $string =~ /\A([^(]*\()/ms ) {

    #warn "opening[$pdepth]: <$1>, $string";

    $out .= $1;
    substr $string, 0, length $1, "";
    $pdepth++;
  }
  while ( $pdepth > 0 ) {
    if ( $string =~ /\A([^()]*\()/ms ) {

      # warn "opening[$pdepth]: <$1>, $string";
      $out .= $1;
      substr $string, 0, length $1, "";
      $pdepth++;
      next;
    }
    if ( $string =~ /\A([^()]*\))/ms ) {

      #warn "closing[$pdepth]: <$1>, $string";

      $out .= $1;
      substr $string, 0, length $1, "";
      $pdepth--;
      next;
    }
    die "unbalanced () pair: $string + $pdepth";
  }
  return $out;
}

sub _parse_depend {
  my ( $self, $depstring ) = @_;
  my (@out);
  while ( length $depstring ) {
    if ( $depstring =~ /\A(\s+)/ms ) {
      substr $depstring, 0, length $1, "";
      next;
    }
    my ( $token, $rest ) = $depstring =~ /\A(\S+)(.*?)\z/ms;

    # handle USE flags
    if ( $token =~ /[?]\z/ms ) {
      my $paren_string = $self->_extract_paren($rest);
      substr $depstring, 0, length "${token}${paren_string}", "";
      $paren_string =~ s/\A[^(]*?\(//;
      $paren_string =~ s/\)[^)]*?\z//;
      push @out, $self->_parse_depend($paren_string);
      next;
    }

    # handle cond groups
    if ( $token =~ /(\|\||\?\?|\^\^)\z/ms ) {
      my $paren_string = $self->_extract_paren($rest);
      substr $depstring, 0, length "${token}${paren_string}", "";
      $paren_string =~ s/\A[^(]*?\(//ms;
      $paren_string =~ s/\)[^)]*?\z//ms;
      push @out, $self->_parse_depend($paren_string);
      next;
    }

    # handle cond groups
    if ( $token =~ /\A\(\z/ms ) {

      # opening paren included as that's the starting condition for extraction
      my $paren_string = $self->_extract_paren("${token}${rest}");

      substr $depstring, 0, length $paren_string, "";
      $paren_string =~ s/\A[^(]*?\(//ms;
      $paren_string =~ s/\)[^)]*?\z//ms;
      push @out, $self->_parse_depend($paren_string);
      next;
    }

    # By now we should only have pure deps
    push @out, $token;
    substr $depstring, 0, length $token, "";
    next;
  }
  return @out;
}
1;

