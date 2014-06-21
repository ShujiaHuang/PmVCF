package vcf;
# This is a package for statistic
$VERSION = '0.0.1';
$DATE    = '2014-06-21';
$AUTHOR  = 'Shujia Huang';

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = ();

our @EXPORT_OK = qw ( VcfHeader );

sub VcfHeader {
	my $vcffile = shift @_;
	my %header;
	open  I, $vcffile =~ /\.gz$/ ? "gzip -dc $vcffile |" : $vcffile or die "Cannot open file $vcffile\n";
	while ( <I> ) {
		chomp;
		last if !/^#/;
		# Use 'A', 'r' and '~' is just for order keeping.
		if (/^##fileformat/) { $header{'A'} = $_; next; }
		if (/##reference=/ ) { $header{'r'} = $_; next; }
		if (/^#CHROM/      ) { $header{'~'} = $_; next; }
		my ( $mark, $id ) = /##([^=]+)=<ID=([^,]+),/;
		my $key           = "$mark:$id"; # The key format is looks like : 'FORMAT:GT' or 'INFO:AC'
		$header{$key}     = $_;
	}
	close I;

	# Should I check the format ? Not now!
	return %header;
}

# Get the name of samples
sub Samples {

	my $vcffile = shift @_;

	my @sample;
	open  I, $vcffile =~ /\.gz$/ ? "gzip -dc $vcffile |" : $vcffile or die "Cannot open file $vcffile\n";
	while ( <I> ) { 
		chomp;
		last if !/^#/;
		
		if (/#CHROM/) { my @col = split; for (my $i = 9; $i < @col; ++$i){ push @sample, $col[$i]; } }
	}
	close I;

	return @sample;
}

