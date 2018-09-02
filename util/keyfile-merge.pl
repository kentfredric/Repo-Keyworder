#!perl
use strict;
use warnings;

# keyfile-merge.pl <FILE> <FILE> <FILE>
#
# Merges multiple keyfiles to emit a single keywording list
# per atom.
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use KENTNL::RepoIter;
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
    for my $keyword (@keywords) {
      $atoms{$atom}->{$keyword} = 1;
    }
  }
}
for my $package ( sort keys %atoms ) {
  printf "%s %s\n", $package, join q[ ], sort keys %{ $atoms{$package} };
}

