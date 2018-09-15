#!perl
use strict;
use warnings;

# Identifies all packages on a system, and their keywording
# and determines which of their dependencies are perl deps
# and then checks keywording consistency, therein, identifying
# broken keywording graphs eminating outside the perl universe
# and reaching into it.
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use KENTNL::RepoIter;
use Repo::Keyworder;

my $repo = "/usr/local/gentoo";
my $r    = Repo::Keyworder->new(
  repo            => $repo,
  cache_fallbacks => ["/usr/portage/metadata/md5-cache/"],
);

KENTNL::RepoIter::repo_packages(
  $repo,
  sub {
    return if $_[1] eq 'dev-perl';
    keyword_check(@_);
  }
);
STDERR->autoflush(1);
my (%dep_needed);

for my $package ( sort keys %dep_needed ) {
  my $missing   = $dep_needed{$package};
  my $keystring = join q[ ],
    map { $missing->{$_} eq 'unstable' ? "~$_" : $missing->{$_} eq 'stable' ? "$_" : $missing->{$_} eq 'blocked' ? "-$_" : "($_)" }
    sort keys %{$missing};
  printf "%s %s\n", $package, $keystring;
}

use Term::ANSIColor qw( colorstrip );
my $last_statline;

sub statline {
  if ($last_statline) {
    STDERR->printf( "\r%s\r", ( " " x length colorstrip($last_statline) ) );
  }
  STDERR->printf( "%s\r", $_[0] );
  $last_statline = $_[0];
}

sub keyword_check {
  my ( $repo, $category, $package ) = @_;
  my $keywords = $r->get_package_keywords("${category}/${package}");
  my $best     = $r->get_package_best_version("${category}/${package}");
  return unless defined $best;
  statline("\e[32m${category}/${package}\e[0m");
  my $have = [ $r->get_ebuild_keywords("${category}/${package}/${package}-${best}.ebuild") ];
  my $deps = [ sort keys %{ $r->get_simplified_ebuild_dependencies("${category}/${package}/${package}-${best}.ebuild") } ];

  for my $key ( keys %{$keywords} ) {
    $keywords->{$key} = 'unstable' if $keywords->{$key} eq 'stable';
    delete $keywords->{$key} unless $keywords->{$key} eq 'unstable';
  }
  my $i   = 1;
  my $max = scalar @{$deps};
  for my $dep ( @{$deps} ) {
    my ( $depcat, $deppkg ) = split qr{/}, $dep;
    statline("\e[32m${category}/${package}-${best}\e[0m -> ($i/$max) \e[33m${depcat}/${deppkg}\e[0m");
    $i++;
    next unless $depcat =~ qr{\A(dev-perl|virtual|perl-core)\z};
    if ( $depcat eq 'virtual' ) {
      next unless $deppkg =~ qr{\Aperl-};
    }
    my $dep_best = $r->get_package_best_version($dep);
    if ( not defined $dep_best ) {

      # warn "No such dependency $dep";
      next;
    }

    # STDERR->print("        -> \e[32m${depcat}/${deppkg}\e[0m\n");
    my $dep_missing = $r->get_ebuild_missing_keywords( "${depcat}/${deppkg}/${deppkg}-${dep_best}.ebuild", $keywords );
    if ( keys %{$dep_missing} ) {
      STDERR->print( "\r\e[32m${category}/${package}\e[0m needs \e[33m${depcat}/${deppkg} (\e[35m"
          . ( join q{ }, keys %{$dep_missing} )
          . "\e[0m)\e[0m\n" );
    }
    for my $keyword ( keys %{$dep_missing} ) {
      if ( not exists $dep_needed{"$depcat/$deppkg-$dep_best"}->{$keyword} ) {
        $dep_needed{"$depcat/$deppkg-$dep_best"}->{$keyword} = $dep_missing->{$keyword};
        next;
      }
    }
  }

}

