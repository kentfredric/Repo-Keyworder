use 5.006;    # our
use strict;
use warnings;

package Repo::Keyworder::Cache;

our $VERSION = '0.001000';

# ABSTRACT: Interface to keyword metadata for packages

# AUTHORITY

sub new {
  my ( $class, %args ) = ( $_[0], ( ref $_[1] ) ? %{ $_[1] } : @_[ 1 .. $#_ ] );
  my $self = bless { _init_args => \%args }, $class;
}

sub repo {
  exists $_[0]->{repo} or $_[0]->_init_repo;
  return $_[0]->{repo};
}

sub cache_dir {
  exists $_[0]->{cache_dir} or $_[0]->_init_cache_dir;
  return $_[0]->{cache_dir};
}

sub digester {
  exists $_[0]->{digester} or $_[0]->_init_digester;
  return $_[0]->{digester};
}

sub get_cache_info {
  my ( $self, $category, $package, $version ) = @_;
  my $cache_key = "${category}/${package}-${version}";
  if ( exists $self->{internal_cache}->{$cache_key} ) {
    return { %{ $self->{internal_cache}->{$cache_key} } };
  }
  my $cache_info = $self->_get_cache( $category, $package, $version );
  if ( ref $cache_info ) {
    $self->{internal_cache}->{$cache_key} = $cache_info;
    return { %{$cache_info} };
  }
  return;
}

sub get_keywords {
  my ( $self, $category, $package, $version ) = @_;
  my $cache_info = $self->get_cache_info( $category, $package, $version );
  return unless exists $cache_info->{KEYWORDS};
  return split /\s+/, $cache_info->{KEYWORDS};
}

sub _init_repo {
  my ( $self, ) = @_;
  my $args = $self->{_init_args};

  die "Required argument 'repo' not specified" unless exists $args->{repo};
  die "Argument 'repo' is either undefined or has no length" unless defined $args->{repo} and length $args->{repo};

  local $!;
  die "'repo' path '$args->{repo}' does not exist: $!"     unless -e $args->{repo};
  die "'repo' path '$args->{repo}' is not a directory: $!" unless -d $args->{repo};

  $self->{repo} = delete $args->{repo};
  return;
}

sub _init_cache_dir {
  my ( $self, ) = @_;
  my $args = $self->{_init_args};
  my $cache_dir = exists $args->{cache_dir} ? delete $args->{cache_dir} : $self->repo . '/metadata/md5-cache/';

  die "'cache_dir' is either undefined or has no length" unless defined $cache_dir and length $cache_dir;

  local $!;
  die "'cache_dir' path '$cache_dir' does not exist: $!"     unless -e $cache_dir;
  die "'cache_dir' path '$cache_dir' is not a directory: $!" unless -d $cache_dir;

  $self->{cache_dir} = $cache_dir;
  return;
}

sub _init_digester {
  my ( $self, ) = @_;
  if ( exists $self->{_init_args}->{digester} ) {
    $self->{digester} = delete $self->{_init_args}->{digester};
    return;
  }
  require Digest::MD5;
  $self->{digester} = Digest::MD5->new();
}

sub _digest_file {
  my ( $self, $file ) = @_;
  my $digester = $self->digester;

  local $!;
  open my $fh, '<', $file or die "Can't open '$file', $!";
  $digester->addfile($fh);
  my $digest = $digester->hexdigest;
  $digester->reset;
  return $digest;
}

sub _regenerate_cache {
  my ( $self, $category, $package ) = @_;
  STDERR->printf( "\e[35;1mregeneraing cache for %s/%s\e[0m\n", $category, $package );
  my $repo         = $self->repo;
  my $cache_config = <<"EOF";
[DEFAULT]
main-repo = gentoo

[gentoo]
location = $repo
sync-type = rsync
sync-uri = rsync://invalid
EOF

  local $?;
  my $exit_code = system(
    "egencache",
    "--repo"                       => "gentoo",
    "--repositories-configuration" => $cache_config,
    "--cache-dir"                  => $self->cache_dir,
    "--tolerant"                   =>,
    "--jobs"                       => 3,
    "--update"                     => "${category}/${package}"
  );
  if ( $exit_code != 0 ) {
    if ( $exit_code < 0 ) {
      warn "egencache failed to start, $! $?";
      return;
    }

    my $return = $? >> 8;
    my $signal = $? & 0b11111111;
    warn "egencache exited with (ret: $return, sig: $signal)";
    if ( $return == 130 ) {
      die "SIGINT detected";
    }
    return;
  }
  return 1;
}

sub _cache_path {
  my ( $self, $category, $package, $version ) = @_;
  return $self->cache_dir . "/${category}/${package}-${version}";
}

sub _ebuild_path {
  my ( $self, $category, $package, $version ) = @_;
  return $self->repo . "/${category}/${package}/${package}-${version}.ebuild";
}

sub _eclass_path {
  my ( $self, $eclass ) = @_;
  return $self->repo . "/eclass/${eclass}.eclass";
}

sub _cache_exists {
  my ( $self, $category, $package, $version ) = @_;
  my ($cache_path) = $self->_cache_path( $category, $package, $version );

  local $!;
  if ( !-e $cache_path or -d $cache_path ) {
    return;
  }
  return 1;
}

sub _ebuild_exists {
  my ( $self, $category, $package, $version ) = @_;
  my ($ebuild_path) = $self->_ebuild_path( $category, $package, $version );

  local $!;
  if ( !-e $ebuild_path or -d $ebuild_path ) {
    return;
  }
  return 1;
}

sub _ebuild_digest {
  my ( $self, $category, $package, $version ) = @_;
  my $cache_key = "${category}/${package}-${version}";
  if ( exists $self->{ebuild_digest_cache}->{$cache_key} ) {
    return $self->{ebuild_digest_cache}->{$cache_key};
  }
  my $ebuild_path = $self->_ebuild_path( $category, $package, $version );
  my $ebuild_md5 = $self->_digest_file($ebuild_path);
  return unless defined $ebuild_md5 and length $ebuild_md5;
  $self->{ebuild_digest_cache}->{$cache_key} = $ebuild_md5;
  return $ebuild_md5;
}

sub _eclass_digest {
  my ( $self, $eclass ) = @_;
  if ( exists $self->{eclass_digest_cache}->{$eclass} ) {
    return $self->{eclass_digest_cache}->{$eclass};
  }
  my $eclass_path = $self->_eclass_path($eclass);
  if ( !-e $eclass_path or -d $eclass_path ) {
    warn "eclass ${eclass} no longer exists, lots of regeneration will be needed";
    return;
  }
  my $eclass_md5 = $self->_digest_file($eclass_path);
  return unless defined $eclass_md5 and length $eclass_md5;
  $self->{eclass_digest_cache}->{$eclass} = $eclass_md5;
  return $eclass_md5;
}

sub _read_cache {
  my ( $self, $category, $package, $version ) = @_;
  my ($cache_path) = $self->_cache_path( $category, $package, $version );
  local $!;
  open my $fh, "<", $cache_path or die "Can't read $cache_path, $!";
  my (%info);
  while ( my $line = <$fh> ) {
    chomp $line;
    my ( $key, $value ) = split /=/, $line, 2;
    $info{$key} = $value;
  }
  close $fh or warn "error closing $cache_path, $!";
  return \%info;
}

sub _cache_valid {
  my ( $self, $category, $package, $version, $info ) = @_;
  if ( not exists $info->{_md5_} or not defined $info->{_md5_} or not length $info->{_md5_} ) {
    return;
  }
  my $ebuild_md5 = $self->_ebuild_digest( $category, $package, $version );
  if ( $ebuild_md5 ne $info->{_md5_} ) {
    return;
  }
  if ( exists $info->{_eclasses_} ) {
    my (%eclasses) = split /\s+/, $info->{_eclasses_};
    for my $eclass ( sort keys %eclasses ) {
      my $eclass_digest = $self->_eclass_digest($eclass);
      if ( $eclass_digest ne $eclasses{$eclass} ) {
        warn "eclass ${eclass} has changed ( $eclass_digest vs $eclasses{$eclass} ), lots of regeneration will be needed";
        return;
      }
    }
  }
  return 1;
}

sub _get_cache {
  my ( $self, $category, $package, $version ) = @_;
  if ( not $self->_ebuild_exists( $category, $package, $version ) ) {
    warn "no such ebuild for ${category}/${package} version ${version}";
  }
  my $regened = 0;
flow: {
    if ( $self->_cache_exists( $category, $package, $version ) ) {
      my $cache_info = $self->_read_cache( $category, $package, $version );
      if ( $self->_cache_valid( $category, $package, $version, $cache_info ) ) {
        return $cache_info;
      }

    }
    last flow if $regened;
    $self->_regenerate_cache( $category, $package, $version );
    $regened = 1;
    redo flow;
  }
  warn "can't regenerate cache for ${category}/${package} version ${version}";
  return;
}

1;

