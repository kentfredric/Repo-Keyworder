#!perl
use strict;
use warnings;

# keyfile-check.pl <FILE> <FILE>
#
# Validates contents of <FILE> where <FILE> is a standard package list file
# and makes sure the atom exists, and cries when it doesn't.

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use KENTNL::RepoIter;
use Repo::Keyworder;
use Repo::Keyworder::AtomParse;

my $repo = "/usr/local/gentoo";

my $atomparse = Repo::Keyworder::AtomParse->new();

my (%atoms);

for my $file (@ARGV) {
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
    }
    else {
      STDERR->printf( "\e[33m%s\e[0m \e[32;1mOK :)\e[0m\n", $atom );
    }
  }
}
