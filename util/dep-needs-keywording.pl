## Please see file perltidy.ERR
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

sub keyword_check {
  my ( $repo, $category, $package ) = @_;
  my $keywords = $r->get_package_keywords("${category}/${package}");
  my $best     = $r->get_package_best_version("${category}/${package}");
  return unless defined $best;

  my $have = [ $r->get_ebuild_keywords("${category}/${package}/${package}-${best}.ebuild") ];
  my $deps = [ sort keys %{ $r->get_simplified_ebuild_dependencies("${category}/${package}/${package}-${best}.ebuild") } ];

  for my $key ( keys %{$keywords} ) {
    $keywords->{$key} = 'unstable' if $keywords->{$key} eq 'stable';
    delete $keywords->{$key} unless $keywords->{$key} eq 'unstable';
  }
  for my $dep ( @{$deps} ) {
    my $dep_best = $r->get_package_best_version($dep);
    if ( not defined $dep_best ) {

      # warn "No such dependency $dep";
      next;
    }
    my ( $depcat, $deppkg ) = split qr{/}, $dep;
    my $dep_missing = $r->get_ebuild_missing_keywords( "${depcat}/${deppkg}/${deppkg}-${dep_best}.ebuild", $keywords );
    if ( keys %{$dep_missing} ) {
      STDERR->print("\e[32m${category}/${package}\e[0m needs \e[33m${depcat}/${deppkg}\e[0m\n");
    }
    for my $keyword ( keys %{$dep_missing} ) {
      if ( not exists $dep_needed{"$depcat/$deppkg-$dep_best"}->{$keyword} ) {
        $dep_needed{"$depcat/$deppkg-$dep_best"}->{$keyword} = $dep_missing->{$keyword};
        next;
      }
    }
  }

}

