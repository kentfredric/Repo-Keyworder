#!perl
use strict;
use warnings;

# Finds packages that 
# a) have existing keyworded versions
# b) have all dependencies satisfied for the given keyword on the latest version
# such as typically seen when you
# 1. Go to bump a package and find it needs a new dependency
# 2. Add the dependency to tree with minimal keywords
# 3. Drop the keywords in the new version of the original package
# and therefor, are equivalent to (modulo time travel)
# 1. dependencies were bumped and keyword
# 2. package was bumped with the dependency added
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

sub keyword_check {
  my ( $repo, $category, $package ) = @_;
  my $keywords = $r->get_package_keywords("${category}/${package}");
  my $best     = $r->get_package_best_version("${category}/${package}");
  return unless defined $best;

  my $have = [ $r->get_ebuild_keywords("${category}/${package}/${package}-${best}.ebuild") ];

  for my $key ( keys %{$keywords} ) {
    $keywords->{$key} = 'unstable' if $keywords->{$key} eq 'stable';
    delete $keywords->{$key} unless $keywords->{$key} eq 'unstable';
  }

  my $missing = $r->get_ebuild_missing_keywords( "${category}/${package}/${package}-${best}.ebuild", $keywords );
  return unless keys %{$missing};

  my $keystring = join q[ ],
    map { $missing->{$_} eq 'unstable' ? "~$_" : $missing->{$_} eq 'stable' ? "$_" : $missing->{$_} eq 'blocked' ? "-$_" : "($_)" }
    sort keys %{$missing};

  my $deps = [ sort keys %{ $r->get_simplified_ebuild_dependencies("${category}/${package}/${package}-${best}.ebuild") } ];

  my ($broken) = {};
dep_chck: for my $dep ( @{$deps} ) {
    my $dep_best = $r->get_package_best_version($dep);
    if ( not defined $dep_best ) {

      # warn "No such dependency $dep";
      next;
    }
    my ( $depcat, $deppkg ) = split qr{/}, $dep;
    my $dep_missing = $r->get_ebuild_missing_keywords( "${depcat}/${deppkg}/${deppkg}-${dep_best}.ebuild", $missing );
    if ( keys %{$dep_missing} ) {
      $broken->{$_} = $dep_missing->{$_} for keys %{$dep_missing};
    }
  }
  for my $key ( sort keys %{$missing} ) {
    next if exists $broken->{$key};
    STDERR->print("\e[32m${category}/${package}\e[0m auto-ok for \e[35m$key\e[0m\n");
  }

}

