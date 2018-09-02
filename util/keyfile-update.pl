#!perl
use strict;
use warnings;

# keyfile-update.pl <FILE>
#
# Determines if entries in a keyfile are out-of-date due to being
# already performed, to reduce package list for arch testers,
# and to make it obvious what work is still left "to be done"
#
# This is best run on a clean tree, _before_ running keyfile-apply.pl

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use KENTNL::RepoIter;
use Repo::Keyworder;
use Repo::Keyworder::AtomParse;

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
  my $key_missing = $r->get_ebuild_missing_keywords( "${cat}/${pn}/${pn}-${v}.ebuild", $decoded_keywords );
  if ( not keys %{$key_missing} ) {
    STDERR->printf( "\e[33m%s\e[0m \e[32;1m complete :)\e[0m\n", $atom );
    next;
  }
  my (%done);
  for my $key ( sort keys %{$decoded_keywords} ) {
    if ( not exists $key_missing->{$key} ) {
      $done{$key} = $decoded_keywords->{$key};
      next;
    }
  }
  my $done_str = join q[ ], map { $done{$_} eq 'unstable' ? "~$_" : $done{$_} eq 'stable' ? "$_" : $done{$_} eq 'blocked' ? "-$_" : "($_)" }
    sort keys %done;
  my $todo_str = join q[ ], map {
        $key_missing->{$_} eq 'unstable' ? "~$_"
      : $key_missing->{$_} eq 'stable'   ? "$_"
      : $key_missing->{$_} eq 'blocked'  ? "-$_"
      : "($_)"
    }
    sort keys %{$key_missing};

  my $out = "";
  if ( keys %done ) {
    $out .= sprintf "\e[35mdone: \e[1m%s\e[0m", $done_str;
  }
  STDERR->printf( "\e[33m%s\e[0m %s \e[36mtodo: \e[1m%s\e[0m\n", $atom, $done_str, $todo_str );
  STDOUT->printf( "%s %s\n", $atom, $todo_str );
}
