#!perl
use strict;
use warnings;

# keyfile-repomanify.pl <FILE>
#
# Uses a keyfile to instrument calls to repoman to san-check all packages mentioned in the keyfile
# using the arch-keywords mentioned in the keyfile as the included arches.
#
# You want to run keyfile-apply.pl <FILE> first if you want to san-check keywording changes.

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use KENTNL::RepoIter;
use Repo::Keyworder;
use Repo::Keyworder::AtomParse;
use File::pushd qw( pushd );
use Time::HiRes qw( gettimeofday tv_interval );

my $repo = "/usr/local/gentoo";
my $r    = Repo::Keyworder->new(
  repo            => $repo,
  cache_fallbacks => ["/usr/portage/metadata/md5-cache/"],
);

my $atomparse = Repo::Keyworder::AtomParse->new();

my (%atoms);

my $file = shift @ARGV;

open my $fh, '<', $file or die "Can't read $file";
while ( my $line = <$fh> ) {
  chomp $line;
  $line =~ s/[#].*\z//;
  $line =~ s/\A\s*\z//;
  next if not length $line;
  my ( $atom, @keywords ) = split / /, $line;
  my ( $cat, $pn, $v ) = $atomparse->split_atom($atom);
  my ($ebuild) = "${repo}/${cat}/${pn}/${pn}-${v}.ebuild";
  if ( not -e $ebuild ) {
    STDERR->printf( "\e[33m%s\e[0m \e[31;1mno longer exists :(\e[0m\n", $atom );
    next;
  }
  my $decoded_keywords = $r->_decode_keywords( "${cat}/${pn} version ${v}", {}, @keywords );
  my $arches = join q[ ], sort keys %{$decoded_keywords};
  STDERR->printf( "\e[33m%s\e[0m (\e[35m%s\e[0m)\n", $atom, $arches );

  {
    my $dir   = pushd("${repo}/${cat}/${pn}");
    my $start = [gettimeofday];
    my $ret   = system(
      'repoman',
      '-q',
      '--ignore-default-opts',
      '--include-arches' => $arches,
      '--include-dev',
      '--include-exp-profiles' => q{y},
      '--output-style'         => 'column',
      'full'
    );
    my ( $signal, $exit ) = ( $ret & 0b11111111, $ret >> 8 );
    $ret == 0 or warn "repoman errored for ${cat}/${pn} : sig $signal exit $exit";
    if ( $exit == 130 ) {
      die "SIGINT detected";
    }
    my $interval = tv_interval( $start, [gettimeofday] );
    printf "\e[1m%8.3fs\e[0m ( %8.3fs per keyword )\n", $interval, $interval / scalar keys %{$decoded_keywords};
  }

}
