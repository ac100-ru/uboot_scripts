#!/usr/bin/perl
######################################################################
#
#   Script to parse android boot.img file and print variables for u-boot
#   loading 
#
#   Based on      : split_bootimg.pl by William Enck <enck@cse.psu.edu>
#
######################################################################

use strict;
use warnings;

# Turn on print flushing
$|++;

######################################################################
## Global Variables and Constants

my $SCRIPT = __FILE__;
my $IMAGE_FN = undef;

# Constants (from bootimg.h)
use constant BOOT_MAGIC => 'ANDROID!';
use constant BOOT_MAGIC_SIZE => 8;
use constant BOOT_NAME_SIZE => 16;
use constant BOOT_ARGS_SIZE => 512;

# Unsigned integers are 4 bytes
use constant UNSIGNED_SIZE => 4;

# Parsed Values
my $PAGE_SIZE = undef;
my $KERNEL_SIZE = undef;
my $RAMDISK_SIZE = undef;
my $SECOND_SIZE = undef;

######################################################################
## Main Code

&parse_cmdline();
&parse_header($IMAGE_FN);

=format (from bootimg.h)
** +-----------------+
** | boot header     | 1 page
** +-----------------+
** | kernel          | n pages
** +-----------------+
** | ramdisk         | m pages
** +-----------------+
** | second stage    | o pages
** +-----------------+
**
** n = (kernel_size + page_size - 1) / page_size
** m = (ramdisk_size + page_size - 1) / page_size
** o = (second_size + page_size - 1) / page_size
=cut

my $n = int(($KERNEL_SIZE + $PAGE_SIZE - 1) / $PAGE_SIZE);
my $m = int(($RAMDISK_SIZE + $PAGE_SIZE - 1) / $PAGE_SIZE);
my $o = int(($SECOND_SIZE + $PAGE_SIZE - 1) / $PAGE_SIZE);


my $n_512 = int ($n * 4);
my $m_512 = int ($m * 4);
my $o_512 = int ($o * 4);

print "\n";
printf "Kernel size: %d (0x%08x) sectors\n", $n_512, $n_512;
printf "Initrd size: %d (0x%08x) sectors\n", $m_512, $m_512;
printf "Second initrd size: %d (0x%08x) sectors\n", $o_512, $o_512; 

my $kernel_start = int (13316);

print "\n";
printf "U-boot kernel read command is: mmc read 0x1000000 0x%08x 0x%08x \n", $kernel_start, $n_512; 

my $initrd_offset = int (13316 + $n_512);

printf "U-boot initrd read command is: mmc read 0x2200000 0x%08x 0x%08x \n", $initrd_offset, $m_512;

print "U-boot boot command is: bootz 0x1000000 0x2200000 \n"; 

print "\n";
my $k_offset = $PAGE_SIZE;
my $r_offset = $k_offset + ($n * $PAGE_SIZE);
my $s_offset = $r_offset + ($m * $PAGE_SIZE);

printf "K_OFFSET: %d \n", $k_offset;
printf "R_OFFSET: %d \n", $r_offset;
printf "S_OFFSET: %d \n", $s_offset;

######################################################################
## Supporting Subroutines

=header_format (from bootimg.h)
struct boot_img_hdr
{
    unsigned char magic[BOOT_MAGIC_SIZE];

    unsigned kernel_size;  /* size in bytes */
    unsigned kernel_addr;  /* physical load addr */

    unsigned ramdisk_size; /* size in bytes */
    unsigned ramdisk_addr; /* physical load addr */

    unsigned second_size;  /* size in bytes */
    unsigned second_addr;  /* physical load addr */

    unsigned tags_addr;    /* physical addr for kernel tags */
    unsigned page_size;    /* flash page size we assume */
    unsigned unused[2];    /* future expansion: should be 0 */

    unsigned char name[BOOT_NAME_SIZE]; /* asciiz product name */

    unsigned char cmdline[BOOT_ARGS_SIZE];

    unsigned id[8]; /* timestamp / checksum / sha1 / etc */
};
=cut
sub parse_header {
    my ($fn) = @_;
    my $buf = undef;

    open INF, $fn or die "Could not open $fn: $!\n";
    binmode INF;

    # Read the Magic
    read(INF, $buf, BOOT_MAGIC_SIZE);
    unless ($buf eq BOOT_MAGIC) {
	die "Android Magic not found in $fn. Giving up.\n";
    }

    # Read kernel size and address (assume little-endian)
    read(INF, $buf, UNSIGNED_SIZE * 2);
    my ($k_size, $k_addr) = unpack("VV", $buf);

    # Read ramdisk size and address (assume little-endian)
    read(INF, $buf, UNSIGNED_SIZE * 2);
    my ($r_size, $r_addr) = unpack("VV", $buf);

    # Read second size and address (assume little-endian)
    read(INF, $buf, UNSIGNED_SIZE * 2);
    my ($s_size, $s_addr) = unpack("VV", $buf);

    # Ignore tags_addr
    read(INF, $buf, UNSIGNED_SIZE);

    # get the page size (assume little-endian)
    read(INF, $buf, UNSIGNED_SIZE);
    my ($p_size) = unpack("V", $buf);

    # Ignore unused
    read(INF, $buf, UNSIGNED_SIZE * 2);

    # Read the name (board name)
    read(INF, $buf, BOOT_NAME_SIZE);
    my $name = $buf;

    # Read the command line
    read(INF, $buf, BOOT_ARGS_SIZE);
    my $cmdline = $buf;

    # Ignore the id
    read(INF, $buf, UNSIGNED_SIZE * 8);

    # Close the file
    close INF;

    # Print important values
    printf "Page size: %d (0x%08x)\n", $p_size, $p_size;
    printf "Kernel size: %d (0x%08x)\n", $k_size, $k_size;
    printf "Ramdisk size: %d (0x%08x)\n", $r_size, $r_size;
    printf "Second size: %d (0x%08x)\n", $s_size, $s_size;
    printf "Board name: $name\n";
    printf "Command line: $cmdline\n";

    # Save the values
    $PAGE_SIZE = $p_size;
    $KERNEL_SIZE = $k_size;
    $RAMDISK_SIZE = $r_size;
    $SECOND_SIZE = $s_size;
}

######################################################################
## Configuration Subroutines

sub parse_cmdline {
    unless ($#ARGV == 0) {
	die "Usage: $SCRIPT boot.img\n";
    }
    $IMAGE_FN = $ARGV[0];
}


