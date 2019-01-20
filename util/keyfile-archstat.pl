#!perl
use strict;
use warnings;

# keyfile-archstat.pl FILE
# where FILE is lines of <cat/pn-pv> <keyword> <keyword>
# decodes keywords into simplified forms and correlates
# their frequency against their keyword, and maps to known CC maintainers
# for that keyword, gives arch-maintainer stats, and also
# extracts email addresses from metadata.xml and _also_ gives stats on those
#
# Thus, providing a nice list of contact addresses for a gentoo bug cc field
# with statistics of how much work is left to be done.

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";
use KENTNL::RepoIter;
use Repo::Keyworder::AtomParse;

my $repo = "/usr/local/gentoo";

my $atomparse = Repo::Keyworder::AtomParse->new();

my (%arch_email) = (
  'alpha'           => 'alpha@gentoo.org',
  'amd64'           => 'amd64@gentoo.org',
  'amd64-fbsd'      => 'bsd@gentoo.org',
  'amd64-linux'     => 'prefix@gentoo.org',
  'arm'             => 'arm@gentoo.org',
  'arm64'           => 'arm64@gentoo.org',
  'hppa'            => 'hppa@gentoo.org',
  'ia64'            => 'ia64@gentoo.org',
  'm68k'            => 'm68k@gentoo.org',
  'm68k-mint'       => 'prefix@gentoo.org',
  'mips'            => 'mips@gentoo.org',
  'ppc'             => 'ppc@gentoo.org',
  'ppc-aix'         => 'prefix@gentoo.org',
  'ppc-macos'       => 'prefix@gentoo.org',
  'ppc64'           => 'ppc64@gentoo.org',
  's390'            => 's390@gentoo.org',
  'sh'              => 'sh@gentoo.org',
  'sparc'           => 'sparc@gentoo.org',
  'sparc-solaris'   => 'prefix@gentoo.org',
  'sparc64-solaris' => 'prefix@gentoo.org',
  'x64-cygwin'      => 'prefix@gentoo.org',
  'x64-macos'       => 'prefix@gentoo.org',
  'x64-solaris'     => 'prefix@gentoo.org',
  'x86'             => 'x86@gentoo.org',
  'x86-fbsd'        => 'bsd@gentoo.org',
  'x86-linux'       => 'prefix@gentoo.org',
  'x86-macos'       => 'prefix@gentoo.org',
  'x86-solaris'     => 'prefix@gentoo.org',
);

my (%arches);
my (%emails);
my (%email_keywords);
my (%cc_emails);

for my $file (@ARGV) {
  open my $fh, '<', $file or die "Can't read $file";
  while ( my $line = <$fh> ) {
    chomp $line;
    $line =~ s/[#].*\z//;
    $line =~ s/\A\s*\z//;
    next if not length $line;
    my ( $atom, @keywords ) = split / /, $line;
    my (%emap);
    for my $keyword (@keywords) {
      $arches{$keyword}++;
      if ( $keyword =~ /\A[~-]?([^~-].*)\z/ ) {
        if ( not exists $arch_email{$1} ) {
          warn "$1 not mapped";
          next;
        }
        my $email = $arch_email{$1};
        $email_keywords{$email}++;
        if ( not exists $emap{$email} ) {
          $emap{$email} = 1;
          $emails{$email}++;
        }
      }
    }
    my ( $cat, $pn, $v ) = $atomparse->split_atom($atom);
    my $xml = "${repo}/${cat}/${pn}/metadata.xml";
    open my $fh, '<', $xml or die "Can't read $xml, $! $?";
    while ( my $line = <$fh> ) {
      chomp $line;
      next unless $line =~ />\s*(\S[^<@]*[@][^<]*\S)\s*</;
      $cc_emails{$1}++;
    }
  }
}

for my $keyword ( sort { $arches{$a} <=> $arches{$b} || $a cmp $b } keys %arches ) {
  printf "%30s : %5d packages\n", $keyword, $arches{$keyword};
}

print "---\n";
for my $email ( sort { $emails{$a} <=> $emails{$b} || $a cmp $b } keys %emails ) {
  my $suffix = "";
  if ( $emails{$email} != $email_keywords{$email} ) {
    $suffix = sprintf " ( %5d distinct keywordings )", $email_keywords{$email};
  }
  printf "%30s : %5d packages%s\n", $email, $emails{$email}, $suffix;
}

print "---\n";

for my $email ( sort { $cc_emails{$a} <=> $cc_emails{$b} || $a cmp $b } keys %cc_emails ) {
  printf "%30s : %5d packages\n", $email, $cc_emails{$email};
}

print "---\n";

printf "%s\n", join q[,], sort keys %emails;

