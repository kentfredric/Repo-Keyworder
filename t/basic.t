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
my $mode = "keyword";
$mode = "stable" if 0;

#scan_repo();
keyword_check( 'dev-lang', 'perl' );
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
    keyword_check( $category, $package );
  }
}

sub scan_category_filter {
  my ( $category, $filter ) = @_;
  opendir my $devperl, "${repo}/${category}";
  while ( my $package = readdir $devperl ) {
    next if $package =~ /^..?$/;
    next unless $filter->($package);
    next unless -d "${repo}/${category}/${package}";
    keyword_check( $category, $package );
  }
}

sub keyword_check {
  my ( $category, $package ) = @_;
  my $keywords = $r->get_package_keywords("${category}/${package}");
  my $best     = $r->get_package_best_version("${category}/${package}");
  return unless defined $best;

  my $have = [ $r->get_ebuild_keywords("${category}/${package}/${package}-${best}.ebuild") ];
  my $deps = [ sort keys %{ $r->get_simplified_ebuild_dependencies("${category}/${package}/${package}-${best}.ebuild") } ];

  for my $key ( keys %{$keywords} ) {
    $keywords->{$key} = 'unstable' if $keywords->{$key} eq 'stable';
    delete $keywords->{$key} unless $keywords->{$key} eq 'unstable';
  }
  my $missing = $r->get_ebuild_missing_keywords( "${category}/${package}/${package}-${best}.ebuild", $keywords );
  my $display = 0;
  $display = 1 if keys %{$missing};
  my (@display_extra);

  for my $dep ( @{$deps} ) {
    my $dep_best = $r->get_package_best_version($dep);
    if ( not defined $dep_best ) {

      # warn "No such dependency $dep";
      next;
    }
    my ( $depcat, $deppkg ) = split qr{/}, $dep;
    my $dep_missing = $r->get_ebuild_missing_keywords( "${depcat}/${deppkg}/${deppkg}-${dep_best}.ebuild", $keywords );
    if ( keys %{$dep_missing} ) {
      $display = 1;
      push @display_extra, sprintf " =%s %s\n", "${depcat}/${deppkg}-${dep_best}", join q[ ], map { "~$_" } sort keys %{$dep_missing};
    }
  }
  if ($display) {
    my $keystring = join q[ ],
      map { $missing->{$_} eq 'unstable' ? "~$_" : $missing->{$_} eq 'stable' ? "$_" : $missing->{$_} eq 'blocked' ? "-$_" : "($_)" }
      sort keys %{$missing};

    printf "%s/%s-%s: %s\n", $category, $package, $best, $keystring;
    print "$_" for @display_extra;
  }
}

sub scan_package_terse {
  my ( $category, $package ) = @_;
  my $keywords = $r->get_package_keywords("${category}/${package}");
  my $best     = $r->get_package_best_version("${category}/${package}");
  return unless defined $best;
  my $have = [ $r->get_ebuild_keywords("${category}/${package}/${package}-${best}.ebuild") ];
  my $deps = [ sort keys %{ $r->get_simplified_ebuild_dependencies("${category}/${package}/${package}-${best}.ebuild") } ];

  for my $key ( keys %{$keywords} ) {
    if ( $mode eq 'keyword' ) {
      $keywords->{$key} = 'unstable' if $keywords->{$key} eq 'stable';
      delete $keywords->{$key} unless $keywords->{$key} eq 'unstable';
    }
    if ( $mode eq 'stable' ) {
      delete $keywords->{$key} unless $keywords->{$key} eq 'stable';
    }
  }
  my $missing = $r->get_ebuild_missing_keywords( "${category}/${package}/${package}-${best}.ebuild", $keywords );

  return unless keys %{$missing};

  # print pp { $package => { want => $keywords, missing => $missing, have => $have } };

  # my $versions = join q[ ], @{ $r->get_package_versions("${category}/${package}") };
  #my $keystring = join q[ ],
  #  map { $keywords->{$_} eq 'unstable' ? "~$_" : $keywords->{$_} eq 'stable' ? "$_" : $keywords->{$_} eq 'blocked' ? "-$_" : "($_)" }
  #  sort keys %{$keywords};
  my $keystring = join q[ ],
    map { $missing->{$_} eq 'unstable' ? "~$_" : $missing->{$_} eq 'stable' ? "$_" : $missing->{$_} eq 'blocked' ? "-$_" : "($_)" }
    sort keys %{$missing};

  printf "%s/%s: \e[32m%s\e[0m => %s \e[31m(\e[0m%s\e[31m)\e[0m\n", $category, $package, $best, $keystring, join q[, ], @{$deps};
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

