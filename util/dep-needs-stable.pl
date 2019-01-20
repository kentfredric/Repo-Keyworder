#!perl
use strict;
use warnings;

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

# Identifies any packages where for each keyword
# the newest stable version for that keyword has an *obvious* missing dependency.
#
# This is very naive and simply asserts all *package* stability graphs are consistent
# at a vague level. It does NOT factor for version range restrictions.
#
# Subsequently, only enough to usefully identify the trivial cases to avoid
# a round trip through repoman, but a final repoman check will still be required

keyword_check( $repo, "dev-lang", "perl" );
KENTNL::RepoIter::repo_category_packages(
  $repo => "virtual" => sub {
    return if $_[2] !~ /\Aperl-/;
    keyword_check(@_);
  }
);
KENTNL::RepoIter::repo_category_packages( $repo, "perl-core", \&keyword_check );
KENTNL::RepoIter::repo_category_packages( $repo, "dev-perl",  \&keyword_check );
keyword_check( $repo, 'media-gfx',   'slic3r' );
keyword_check( $repo, 'sys-apps',    'ack' );
keyword_check( $repo, 'app-editors', 'padre' );
keyword_check( $repo, 'www-apache',  'mod_perl' );
keyword_check( $repo, 'app-shells',  'psh' );
keyword_check( $repo, 'dev-lang',    'nqp' );
keyword_check( $repo, 'dev-lang',    'moarvm' );
keyword_check( $repo, 'dev-lang',    'rakudo' );
keyword_check( $repo, 'dev-lang',    'parrot' );
keyword_check( $repo, 'media-libs',  'exiftool' );
keyword_check( $repo, 'app-portage', 'perl-info' );
keyword_check( $repo, 'app-portage', 'genlop' );
keyword_check( $repo, 'app-portage', 'g-cpan' );
keyword_check( $repo, 'app-portage', 'demerge' );
keyword_check( $repo, 'app-admin',   'perl-cleaner' );
keyword_check( $repo, 'app-admin',   'kpcli' );
keyword_check( $repo, 'app-admin',   'gentoo-perl-helpers' );

my (%dep_needed);

for my $package ( sort keys %dep_needed ) {
  my $missing   = $dep_needed{$package};
  my $keystring = join q[ ],
    map { $missing->{$_} eq 'unstable' ? "~$_" : $missing->{$_} eq 'stable' ? "$_" : $missing->{$_} eq 'blocked' ? "-$_" : "($_)" }
    sort keys %{$missing};
  printf "%s %s\n", $package, $keystring;
}

use Data::Dump qw(pp);

sub keyword_check {
  my ( $repo, $category, $package ) = @_;
  my $keywords = $r->get_package_keywords("${category}/${package}");
  for my $key ( keys %{$keywords} ) {
    delete $keywords->{$key} unless $keywords->{$key} eq 'stable';
  }
  return unless keys %{$keywords};

  my %versions;
  for my $arch ( keys %{$keywords} ) {
    my $best = $r->get_package_best_stable_version_arch("${category}/${package}", $arch);
    next unless defined $best;
    push @{$versions{$best}}, $arch;
  }

  verwalk: for my $version ( keys %versions ) {
    my $deps = [ sort keys %{ $r->get_simplified_ebuild_dependencies("${category}/${package}/${package}-${version}.ebuild") } ];
    my (%unsatisfied);
    for my $dep (@{$deps}) {
      my ( $depcat, $deppkg ) = split qr{/}, $dep;
      my $dep_keywords = $r->get_package_keywords($depcat, $deppkg);
      for my $wanted ( @{$versions{$version}} ) {
        next if exists $dep_keywords->{$wanted} and $dep_keywords->{$wanted} eq 'stable';
        next unless exists $dep_keywords->{$wanted};
        push @{$unsatisfied{$dep}}, $wanted;
      }
    }
    if ( not keys %unsatisfied ) {
      #my $arch_str = join q[ ], @{$versions{$version}};
      #STDERR->print("\e[32m${category}/${package}-${version}\e[0m OK \e[35m( $arch_str )\e[0m\n");
      next verwalk;
    }
    for my $dep ( keys %unsatisfied ) {
      my $arch_str = join q[ ], @{$unsatisfied{$dep}};
      STDERR->print("\e[32m${category}/${package}-${version}\e[0m needs \e[33m${dep}\e[0m \e[35m( $arch_str )\e[0m\n");
    }
  }
  return;
}

