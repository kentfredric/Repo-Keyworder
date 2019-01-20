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
use Time::HiRes qw( gettimeofday tv_interval usleep );
use Parallel::ForkManager;
use IPC::Open3 qw( open3 );

my $repo = "/usr/local/gentoo";
my $r    = Repo::Keyworder->new(
  repo            => $repo,
  cache_fallbacks => ["/usr/portage/metadata/md5-cache/"],
);

my $max_threads = 8;
my $max_loadavg = 4;

my $atomparse = Repo::Keyworder::AtomParse->new();

my (%atoms);

sub get_loadavg {
  if ( open my $fh, '<', '/proc/loadavg' ) {
    my ( $one, $five, $fifteen, $sched, $lastpid, @cruft ) = split /\s+/, scalar <$fh>;
    chomp $lastpid;
    return $one + 0.0;
  }
  else {
    warn "Can't open loadavg\n";
    return 1000;
  }
}

my $file = shift @ARGV;
my $pm   = Parallel::ForkManager->new($max_threads);
$pm->set_waitpid_blocking_sleep(0);

open my $fh, '<', $file or die "Can't read $file";
LINES:
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
  my $nprocs = $pm->running_procs();
  if ( $pm->start ) {
    while (1) {
      $pm->reap_finished_children;
      next LINES if $pm->running_procs < 1;
      if ( get_loadavg() < ( $max_loadavg - 1 ) ) {
        select( undef, undef, undef, 1.5 );
        next LINES;
      }
      select( undef, undef, undef, 0.1 );
    }
  }
  # STDERR->printf( "\e[3m Spawning: %s (avg: %s, nprocs: %s)\e[0m\n", "${cat}/${pn}-${v}", get_loadavg(), $nprocs + 1 );

  {
    my $dir   = pushd("${repo}/${cat}/${pn}");
    my $start = [gettimeofday];

    local ( $?, $! );
    my ( $signal, $exit, $ret );

    my $pid = open3 undef, my $fh, undef,
      (
      'repoman',
      '-q',
      '--ignore-default-opts',
      '--include-arches' => $arches,
      '--include-dev',
      '--include-exp-profiles' => q{y},
      '--output-style'         => 'column',
      '--without-mask',
      'full'
      );
    $ret = 0;
    if ( not defined $pid ) {
      $ret = $?;
    }
    ( $signal, $exit ) = ( $ret & 0b11111111, $ret >> 8 );
    $ret == 0 or warn "repoman errored for ${cat}/${pn} : sig $signal exit $exit";
    if ( $exit == 130 ) {
      die "SIGINT detected";
    }

    my $outbuf;
    my $prefix = "";
    my $isbad = 0;
    while ( my $line = <$fh> ) {
      next if $line =~ /\A\s*!!!/;
      if ( $line =~ /\ANo QA Issues found/i ) {
        $outbuf = "\e[32;1m :)\e[0m";
        next;
      }
      if ( $line =~ /QA errors/i ) {
        $isbad = 1;
        next;
      }
      next if $line =~ /\ANumberOf/i;
      $prefix = "\n";
      $line =~ s{(eapi-deprecated|badheader)}{\e[36m$1\e[0m};
      $line =~ s{(KEYWORDS.(?:dropped|unsorted))}{\e[43;30;1m$1\e[0m};

      $line =~ s{(\Q${cat}/${pn}/${pn}-${v}.ebuild\E)}{\e[37;1m$1\e[0m};
      $outbuf .= $line;
    }
    $prefix =  "\e[41;37m###\e[0m\n" if $isbad;
    my $message = sprintf "\e[33;1m> \e[0m\e[33m%s\e[0m (\e[35m%s\e[0m) %s", $atom, $arches, $prefix . $outbuf;

    unless ( close $fh ) {
      $ret = $?;
      my ( $signal, $exit ) = ( $ret & 0b11111111, $ret >> 8 );
      $ret == 0 or warn "repoman errored for ${cat}/${pn} : sig $signal exit $exit";
      if ( $exit == 130 ) {
        die "SIGINT detected";
      }
    }
    my $interval = tv_interval( $start, [gettimeofday] );
    STDERR->printf( "%s\n", $message );
    #   STDERR->printf( "%s\e[1m%8.3fs\e[0m ( %8.3fs per keyword )\n", $message, $interval, $interval / scalar keys %{$decoded_keywords} );
    $pm->finish;
  }

}
$pm->wait_all_children;
