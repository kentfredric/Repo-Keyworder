#!perl
use strict;
use warnings;

# keyfile-diff.pl <OLDFILE> <NEWFILE>
#
# Itemize changes between keyfiles
use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use KENTNL::RepoIter;
use Repo::Keyworder::AtomParse;

my $repo = "/usr/local/gentoo";

my $atomparse = Repo::Keyworder::AtomParse->new();

my $old = parse_file( $ARGV[0] );
my $new = parse_file( $ARGV[1] );

my $all = {
  map { $_ => 1 }
    keys %{$old}, keys %{$new},
};

for my $atom ( sort keys %{$all} ) {
  if ( exists $old->{$atom} and not exists $new->{$atom} ) {
    printf "\e[31m D %s\e[0m\n", $old->{$atom}->{line};
    next;
  }
  if ( not exists $old->{$atom} and exists $new->{$atom} ) {
    printf "\e[32m A %s\n", $new->{$atom}->{line};
    next;
  }
  next if _sorted_keylist( $old->{$atom}->{keywords} ) eq 
          _sorted_keylist( $new->{$atom}->{keywords} );

  my $all_kw = {
    map { $_ => 1 }
      keys %{ $old->{$atom}->{keywords} }, keys %{ $new->{$atom}->{keywords} },
  };

  my (@dl);
  for my $kw ( sort keys %{$all_kw} ) {
    if (  exists $old->{$atom}->{keywords}->{$kw}
      and exists $new->{$atom}->{keywords}->{$kw} )
    {
      push @dl, $kw;
      next;
    }
    if ( exists $old->{$atom}->{keywords}->{$kw} ) {
      push @dl, sprintf "\e[31m<%s>\e[0m", $kw;
      next;
    }
    if ( exists $new->{$atom}->{keywords}->{$kw} ) {
      push @dl, sprintf "\e[32m[%s]\e[0m", $kw;
      next;
    }
  }
  printf "\e[33m M\e[0m %s %s\n", $atom, join q[ ], @dl;
}

sub parse_file {
  my ($file) = @_;
  my %atoms;
  open my $fh, '<', $file or die "Can't read $file";
  while ( my $line = <$fh> ) {
    chomp $line;
    $line =~ s/[#].*\z//;
    $line =~ s/\A\s*\z//;
    next if not length $line;
    my ( $atom, @keywords ) = split / /, $line;
    $atoms{$atom}->{line} = $line;
    for my $keyword (@keywords) {
      $atoms{$atom}->{keywords}->{$keyword} = 1;
    }
  }
  return \%atoms;

}

sub _sorted_keylist {
  my ( $hash ) = @_;
  join q[ ], sort keys %{ $hash };
}
