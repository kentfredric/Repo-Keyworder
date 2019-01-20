#!perl
use strict;
use warnings;

# keyfile-gitlog.pl FILE
#
# where FILE is in form <cat/pn-pv> <keyword> <keyword>
#
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use KENTNL::RepoIter;
use Repo::Keyworder::AtomParse;
use Parallel::ForkManager;
use PerlIO::buffersize;

my $repo = "/usr/local/gentoo";

my $atomparse = Repo::Keyworder::AtomParse->new();
my $pm        = Parallel::ForkManager->new(6);
$pm->set_waitpid_blocking_sleep(0);

open my $fh, '<', $ARGV[0] or die "Can't read $ARGV[0]";
LINES:
while ( my $line = <$fh> ) {
  chomp $line;
  $line =~ s/[#].*\z//;
  $line =~ s/\A\s*\z//;
  next if not length $line;
  my ( $atom, @keywords ) = split / /, $line;
  my ( $cat, $pn, $ver ) = $atomparse->split_atom($atom);
  my $realpath = "${repo}/${cat}/${pn}/${pn}-${ver}.ebuild";
  if ( $pm->start ) {
    select( undef, undef, undef, 0.5 );
    next LINES;
  }
  local ( $!, $? );
  open my $fh, '-|',  'git', '-C', $repo, '--no-pager', 'log',
    q{--format=%h %Cgreen%<(10,trunc)%aN%Creset %<(60,trunc)%s %Cblue%ai ~ %C(yellow)%ar%C(reset) %d},
    '--color=always',
    '--date-order', $realpath
    or die "Exited, $! $?";

  STDOUT->printf( "\e[31;1m> \e[0m%s\n%s\n", $atom, join qq{}, <$fh> );
  close $fh or die "Exited $! $?";

  $pm->finish;
}
$pm->wait_all_children;
