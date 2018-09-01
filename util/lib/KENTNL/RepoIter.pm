use 5.006;    # our
use strict;
use warnings;

package KENTNL::RepoIter;

our $VERSION = '0.001000';

# ABSTRACT: Tools for iterating gentoo repositories

# AUTHORITY

sub repo_category_packages {
  my ( $repo, $category, $callback ) = @_;
  local ( $!, $? );
  opendir my $catdir, "${repo}/${category}" or die "can't opendir $repo/$category, $? $!";
  while ( my $package = readdir $catdir ) {
    next if $package =~ /^..?$/;
    next unless -d "${repo}/${category}/${package}";
    $callback->( $repo, $category, $package );
  }
}

sub repo_packages {
  my ( $repo, $callback ) = @_;
  local ( $!, $? );
  opendir my $repodir, $repo or die "Can't opendir $repo, $? $!";
  while ( my $category = readdir $repodir ) {
    next if $category =~ /\A(..?|metadata|profiles|\.git)\z/;
    next unless -d "${repo}/${category}";
    repo_category_packages( $repo, $category, $callback );
  }
}

1;

