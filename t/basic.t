## Please see file perltidy.ERR

use strict;
use warnings;

use Test::More;
use Repo::Keyworder;
use Data::Dump qw(pp);

my $repo = "/usr/local/gentoo";
my $r    = Repo::Keyworder->new(
  repo            => $repo,
  cache_fallbacks => ["/usr/portage/metadata/md5-cache/"],
);

#scan_repo();
scan_package_terse( 'dev-lang', 'perl' );
scan_category_filter( "virtual", sub { $_[0] =~ /^perl-/ } );
scan_category('perl-core');
scan_category('dev-perl');

sub scan_repo {
  opendir my $repdir, "${repo}";
  while ( my $category = readdir $repdir ) {
    next if $category =~ /^..?$/;
    next if $category =~ /^(metadata|profiles|\.git)$/;
    next unless -d "${repo}/${category}";
    scan_category($category);
  }
}

sub scan_category {
  my ($category) = @_;
  opendir my $devperl, "${repo}/${category}";
  while ( my $package = readdir $devperl ) {
    next if $package =~ /^..?$/;
    next unless -d "${repo}/${category}/${package}";
    scan_package_terse( $category, $package );
  }
}

sub scan_category_filter {
  my ( $category, $filter ) = @_;
  opendir my $devperl, "${repo}/${category}";
  while ( my $package = readdir $devperl ) {
    next if $package =~ /^..?$/;
    next unless $filter->($package);
    next unless -d "${repo}/${category}/${package}";
    scan_package_terse( $category, $package );
  }
}

sub scan_package_terse {
  my ( $category, $package ) = @_;
  my $keywords = $r->get_package_keywords("${category}/${package}");
  printf "%s/%s: (%s) %s\n", $category, $package, ( join q[ ], @{ $r->get_package_versions("${category}/${package}") } ),
    (
    join q[ ],
    map { $keywords->{$_} eq 'unstable' ? "~$_" : $keywords->{$_} eq 'stable' ? "$_" : $keywords->{$_} eq 'blocked' ? "-$_" : "($_)" }
      sort keys %{$keywords}
    );
}

sub scan_package {
  my ( $category, $package ) = @_;
  opendir my $packagedir, "${repo}/${category}/${package}";

  #    printf "\e[31m%s\e[0m\n", "dev-perl/$package";
  while ( my $file = readdir $packagedir ) {
    next unless $file =~ /\.ebuild$/;
    my ($nn) = $file;
    $nn =~ s/\.ebuild$//;
    $nn =~ s/^\Q${package}\E-//;
    printf "%s/%s-%s: %s\n", $category, $package, $nn, join q[, ], $r->get_ebuild_keywords("${category}/${package}/${file}");
  }

}

done_testing;

