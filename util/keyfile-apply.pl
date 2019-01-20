#!perl
use strict;
use warnings;

# keyfile-apply.pl FILE
#
# where FILE is in form <cat/pn-pv> <keyword> <keyword>
#
# Actions keywords stated in file to $repo

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use KENTNL::RepoIter;
use Repo::Keyworder::AtomParse;
use Parallel::ForkManager;

my $repo = "/usr/local/gentoo";

my $atomparse = Repo::Keyworder::AtomParse->new();
my $pm        = Parallel::ForkManager->new(4);
$pm->set_waitpid_blocking_sleep(0);

while ( my $file = shift @ARGV ) {
  open my $fh, '<', $file or die "Can't read $file";
LINES:
  while ( my $line = <$fh> ) {
    chomp $line;
    $line =~ s/[#].*\z//;
    $line =~ s/\A\s*\z//;
    next if not length $line;
    my ( $atom, @keywords ) = split / /, $line;
    my ( $cat, $pn, $ver ) = $atomparse->split_atom($atom);
    my $realpath = "${repo}/${cat}/${pn}/${pn}-${ver}.ebuild";
    if ( not -e $realpath ) {
      warn "\e[31mDoes not exist: \e[0m$realpath\n";
      next LINES;
    }
    $pm->start and next LINES;
    local ( $!, $? );
    system( "ekeyword", @keywords, $realpath ) == 0
      or die "Exited, $! $? Keywords: [ @keywords ] Path: $realpath";
    $pm->finish;
  }
}
$pm->wait_all_children;
