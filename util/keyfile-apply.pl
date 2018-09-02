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

my $repo = "/usr/local/gentoo";

my $atomparse = Repo::Keyworder::AtomParse->new();

open my $fh, '<', $ARGV[0] or die "Can't read $ARGV[0]";
while ( my $line = <$fh> ) {
  chomp $line;
  $line =~ s/[#].*\z//;
  $line =~ s/\A\s*\z//;
  next if not length $line;
  my ( $atom, @keywords ) = split / /, $line;
  my ( $cat, $pn, $ver ) = $atomparse->split_atom($atom);
  my $realpath = "${repo}/${cat}/${pn}/${pn}-${ver}.ebuild";
  system( "ekeyword", @keywords, $realpath ) == 0
    or die "Exited, $! $?";
}

