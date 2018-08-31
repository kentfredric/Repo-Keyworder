## Please see file perltidy.ERR

use strict;
use warnings;

use Test::More;
use Repo::Keyworder;
use Data::Dump qw(pp);

my $repo = "/usr/local/gentoo";
my $r    = Repo::Keyworder->new($repo);

scan_package('dev-lang', 'perl');
scan_category_filter("virtual", sub { $_[0] =~ /^perl-/ });
scan_category('perl-core');
scan_category('dev-perl');

sub scan_category {
  my ($category) = @_;
  opendir my $devperl, "${repo}/${category}";
  while ( my $package = readdir $devperl ) {
    next if $package =~ /^..?$/;
    next unless -d "${repo}/${category}/${package}";
    scan_package( $category, $package );
  }
}
sub scan_category_filter {
  my ($category, $filter) = @_;
  opendir my $devperl, "${repo}/${category}";
  while ( my $package = readdir $devperl ) {
    next if $package =~ /^..?$/;
    next unless $filter->( $package );
    next unless -d "${repo}/${category}/${package}";
    scan_package( $category, $package );
  }
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

