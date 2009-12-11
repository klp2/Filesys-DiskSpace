# -*- Mode: Perl -*-

BEGIN { unshift @INC, "lib", "../lib" }
use strict;
use Filesys::DiskSpace;

local $^W = 1;

my $t = 1;

unless ($^O eq 'linux') {
  print "1..1\nok 1\n";
  exit;
}

my $bindf  = '/bin/df';
my $mnttab = '/etc/mtab';

my ($data, $dirs);
open (MOUNT, $mnttab) || die "Error: $!\n";
while (defined (my $d = <MOUNT>)) {
  my @tab = split / /, $d;
  push @$dirs, $tab[1] if $tab[2] eq 'ext2';
}
close MOUNT;
open (DF, "$bindf -k @$dirs |") || die "Error: $!\n";
while (defined (my $d = <DF>)) {
  my @tab = split /\s+/, $d;
  next if $tab[0] eq 'Filesystem';
  $$data{$tab[5]}{'used'}  = $tab[2];
  $$data{$tab[5]}{'avail'} = $tab[3];
}
close DF;
open (DF, "$bindf -i @$dirs |") || die "Error: $!\n";
while (defined (my $d = <DF>)) {
  my @tab = split /\s+/, $d;
  next if $tab[0] eq 'Filesystem';
  $$data{$tab[5]}{'fused'}  = $tab[2];
  $$data{$tab[5]}{'favail'} = $tab[3];
}
close DF;

print "1..", scalar keys %$data, "\n";

# ($fs_type, $fs_desc, $used, $avail, $fused, $favail) = df $dir;
for my $part (keys %$data) {
  my ($fs_type, $fs_desc, $used, $avail, $fused, $favail) = df $part;
  my $res = $fs_type == 61267 &&
    $$data{$part}{'used'} == $used &&
    $$data{$part}{'avail'} == $avail &&
    $$data{$part}{'fused'} == $fused &&
    $$data{$part}{'favail'} == $favail;
  print $res ? "" : "not ", "ok ", $t++, "\n";
}
