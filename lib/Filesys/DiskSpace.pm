# -*- Mode: Perl -*-

package Filesys::DiskSpace;

use strict;
use vars qw(@ISA @EXPORT $VERSION $DEBUG);
use Exporter;
use Config;
use Carp;
require 5.003;

@ISA = qw(Exporter);
@EXPORT = qw(df);
$VERSION = "0.02";

my %fs_type = (
     0			=>	"4.2",				# 0x0
     256		=>	"ufs",				# 0x100
     2560		=>	"ADVFS",			# 0xA00
     4989		=>	"EXT_SUPER_MAGIC",		# 0x137D
     4991		=>	"MINIX_SUPER_MAGIC",		# 0x137F
     5007		=>	"MINIX_SUPER_MAGIC2",		# 0x138F
     9320		=>	"NEW_MINIX_SUPER_MAGIC",	# 0x2468
     19780		=>	"MSDOS_SUPER_MAGIC",		# 0x4d44
     26985		=>	"NFS_SUPER_MAGIC",		# 0x6969
     38496		=>	"ISOFS_SUPER_MAGIC",		# 0x9660
     40864		=>	"PROC_SUPER_MAGIC",		# 0x9fa0
     61265		=>	"EXT2_OLD_SUPER_MAGIC",		# 0xEF51
     61267		=>	"EXT2_SUPER_MAGIC",		# 0xEF53
     19911021		=>	"_XIAFS_SUPER_MAGIC",		# 0x012FD16D
);

sub df ($) {
  my $dir = shift;

  my ($fmt, $res, $type, $flags, $osvers, $w);

  # struct fields for statfs or statvfs....
  my ($bsize, $frsize, $blocks, $bfree, $bavail, $files, $ffree, $favail);

  Carp::croak "Usage: df '\$dir'" unless $dir;
  Carp::croak "Error: $dir is not a directory" unless -d $dir;

  # try with statvfs..
  eval {  # will works for Solaris 2.*, OSF1 v3.2, OSF1 v4.0 and HP-UX 10.*.
    {
      package main;
      require "sys/syscall.ph";
    }
    $fmt = "\0" x 512;
    $res = syscall (&main::SYS_statvfs, $dir, $fmt) ;
    ($bsize, $frsize, $blocks, $bfree, $bavail, $files, $ffree, $favail) =
      unpack "L8", $fmt;

    # to stay ok with statfs..
    $type = 0;
    $ffree = $favail;
    $bsize = $frsize;
    $blocks -= $bfree - $bavail;
    print "res=$res type=$type\n";
    $res == 0 && $fs_type{$type};
  }
  # try with statfs..
  || eval { # will work for SunOS 4, Linux 2.0.* and 2.2.*
    {
      package main;
      require "sys/syscall.ph";
    }
    $fmt = "\0" x 512;
    $res = syscall (&main::SYS_statfs, $dir, $fmt);
    # statfs...

    ($type, $bsize, $blocks, $bfree, $bavail, $files, $ffree) =
      unpack "L7", $fmt;

    $res == 0 && $fs_type{$type};
  }
  || eval {
    {
      package main;
      require "sys/syscall.ph";
    }
    # The previous try gives an unknown fs type, it must be a different
    # structure format..
    $fmt = "\0" x 512;
    # Try this : n2i7L119
    $res = syscall (&main::SYS_statfs, $dir, $fmt);
    ($type, $flags, $bsize, $frsize, $blocks,
     $bfree, $bavail, $files, $ffree) = unpack "n2i7", $fmt;
    $res == 0 && $fs_type{$type};
  }
  # Neither statfs nor statvfs.. too bad.
  || eval {
    $osvers = $Config{'osvers'};
    $w = 0;
    # These system normaly works but there was a problem...
    # Trying to inform the user...
    if ($^O eq 'solaris' || $^O eq 'dec_osf') {
      # Tested. No problem if syscall.ph is present.
      warn "An error occured. statvfs failed. Did you run h2ph?\n";
      $w = 2;
    }
    if ($^O eq 'linux') {
      # Tested with $osvers = 2.0.0 and 2.2.2
      # No problem if syscall.ph is present.
      warn "An error occured. statfs failed. Did you run h2ph?\n";
    }
    if ($^O eq 'hpux') {
      if ($osvers == 9) {
	# Tested. You have to change a line in syscall.ph.
	warn "An error occured. statfs failed. Did you run h2ph?\n";
	warn "If you are using a hp9000s700, see the Df documentation\n";
      }
      elsif ($osvers == 10) {
	# Tested. No problem if syscall.ph is present.
	warn "An error occured. statvfs failed. Did you run h2ph?\n";
      }
      else {
	# Untested
	warn "An error occured. df failed.\n";
      }
      $w = 3;
    }
    $w;
  }
  || Carp::croak "Cannot use df on this machine (untested or unsupported).";

  exit if defined $w && $w > 0;

  $blocks -= $bfree - $bavail;

  if ($files == $ffree) {
    $files = 1;
    $ffree = 0;
  }

  warn "Warning : type $fs_type{$type} untested.. results may be incorrect\n"
    unless $type != 2560  && defined $fs_type{$type};

  if ($DEBUG) {
    warn "Fs type : [$type] $fs_type{$type}\n" .
      "total space : ", $blocks * $bsize / 1024, " Kb\n" .
      "available space : ", $bavail * $bsize / 1024, " Kb\n\n";
    if ($files == 1 && $ffree == 0) {
      warn "inodes : no information available\n";
    }
    else {
      warn "inodes : $files\nfree inodes : $ffree\n" .
	"used inodes : ", $files - $ffree, "\n";
    }
  }

  ($type, $fs_type{$type}, ($blocks - $bavail) * $bsize / 1024,
   $bavail * $bsize / 1024, $files - $ffree, $ffree);
}

1;

=head1 NAME

Filesys::DiskSpace - Perl df

=head1 SYNOPSYS

    use Filesys::DiskSpace;
    ($fs_type, $fs_desc, $used, $avail, $fused, $favail) = df $dir;

=head1 DESCRIPTION

This routine displays information on a file system such as its type, the
amount of disk space occupied, the total disk space and the number of inodes.
It tries C<syscall(SYS_statfs)> and C<syscall(SYS_statvfs)> in several ways.
If all fails, it C<croak>s.

=head1 OPTIONS

=over 4

=item $fs_type

[number] type of the filesystem.

=item $fs_desc

[string] description of this fs.

=item $used

[number] size used (in Kb).

=item $avail

[number] size available (in Kb).

=item $ffree

[number] free inodes.

=item $fused

[number] inodes used.

=back

=head1 Installation

See the INSTALL file.

=head1 COPYRIGHT

Copyright (c) 1996-1999 Fabien Tassin. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 AUTHOR

Fabien Tassin E<lt>fta@oleane.netE<gt>

=head1 NOTES

This module was formerly called File::Df. It has been renamed into
Filesys::DiskSpace. It could have be Filesys::Df but unfortunatly
another module created in the meantime uses this name.

Tested with Perl 5.003 under these systems :

           - Solaris 2.[4/5]
           - SunOS 4.1.[2/3/4]
           - HP-UX 9.05, 10.[1/20] (see below)
           - OSF1 3.2, 4.0
           - Linux 2.0.*, 2.2.*

Note for HP-UX users :

   if you got this message :
   "Undefined subroutine &main::SYS_statfs called at File/Df.pm line XXX"
   and if you are using a hp9000s700, then edit the syscall.ph file
   (in the Perl lib tree) and copy the line containing "SYS_statfs {196;}"
   outside the "if (defined &__hp9000s800)" block (around line 356).

=cut
