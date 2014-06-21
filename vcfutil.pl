# Author : Shujia Huang
# Date   : 2014-06-21 16:33:23
#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

use lib "/home/siyang/USER/huangshujia/iCodeSpace/perl/My/PmVCF";
use vcf;

die qq/
Usage   : perl $0 <command> [<arguments>]\n
Command : 
    addformat    Add new fields to 'FORMAT' for each samples.
/ if @ARGV < 1;
my $command = shift @ARGV;
my %func    = ( 'addformat' => \&AddFORMAT, 'addinfo' => \&AddInfo );
die "Unknown command $command\n" if !defined($func{$command}) ;
&{$func{$command}};

print STDERR "\n************************** Processing $command DONE **************************\n";
#####################

sub AddFORMAT {
	my ( $fromVcfInfile, $toVcfInfile, $add );
	GetOptions (
		"from=s"=> \$fromVcfInfile,  # Get same FORMAT from this VCF file
		"to=s"  => \$toVcfInfile,    # Target VCF. Insert to this VCF file
		"add=s" => \$add,            # FORMAT.   should looks like : 'foo:bar'
	);

	print STDERR "[ERROR] User ERROR. Missing '-from' parameter.\n" if @ARGV > 1 and !defined $fromVcfInfile;
	print STDERR "[ERROR] User ERROR. Missing '-to'   parameter.\n" if @ARGV > 1 and !defined $toVcfInfile;
	print STDERR "[ERROR] User ERROR. Missing '-add'  parameter.\n" if @ARGV > 1 and !defined $add;

	die qq/
Usage : perl $0 addformat -from [vcf] -to [Target vcf] -add 'foo:bar' > OutputVCF

Caution:  
    * The samples and the order of sample should be the same in [-from [vcf]] and [-to [Target vcf] ] 
\n/ if !defined $add or !defined $fromVcfInfile or !$toVcfInfile;

	my $fromSample = join ",", vcf::Samples( $fromVcfInfile );
	my $toSample   = join ",", vcf::Samples( $toVcfInfile   );

	die "[ERROR] The samples' ID or the samples' order in $fromVcfInfile are not match the ID in $toVcfInfile\n" 
		if $fromSample ne $toSample;

	my %toheader   = vcf::VcfHeader( $toVcfInfile   );
	my %fromheader = vcf::VcfHeader( $fromVcfInfile );

	# Load New format into the VCF Header
	my @add        = split /:/, $add;
	for my $k ( @add ) {
		my $key = "FORMAT:$k";
		die "[ERROR] The '$k' is not in the FORMAT fields of $fromVcfInfile\n" if !exists $fromheader{$key};
		print STDERR "[WARNING] $key is already in $toVcfInfile, perhaps you should use 'UpdateValueInFORMAT'\n" 
			if exists $toheader{$key};
		$toheader{$key} = $fromheader{$key};
	}

	my %newFormatValue; GetFormatValue( $fromVcfInfile, \%newFormatValue, @add ); # Get new format for per positions

	### Output 
	for my $k ( sort {$a cmp $b} keys %toheader ) { print "$toheader{$k}\n"; }
	open  I,$toVcfInfile=~/\.gz$/ ? "gzip -dc $toVcfInfile |":$toVcfInfile or die "Cannot open file $toVcfInfile\n";
	while ( <I> ) {
		chomp;
		next if /^#/;
		my @col = split;

		my @format = split /:/, $col[8];
        die "[ERROR] The first field in FORMAT should be 'GT'\n" if $format[0] ne 'GT';

		my %fmat2Indx; for (my $i = 0; $i < @format; ++$i ) { $fmat2Indx{ $format[$i] } = $i; }
		my $endIndx = $#format;
		for my $f (@add) {
			next if exists $fmat2Indx{$f};
			++$endIndx;
			$fmat2Indx{$f} = $endIndx; # initial the format indx
		}

		my $pos = "$col[0]:$col[1]";
		my %tmp = %fmat2Indx; delete $tmp{'GT'};
		my @key = sort {$a cmp $b} keys %tmp;
		for ( my $i = 9; $i < @col; ++$i ) {
			
			my @data = split /:/, $col[$i];
			for my $f ( @add ) { # New format
				$data[ $fmat2Indx{$f} ] = $newFormatValue{$pos}->[$i-9]->{$f};
			}
			$col[$i] = join ":", @data[ $fmat2Indx{'GT'}, (map {$fmat2Indx{$_}} @key) ]; # Re-new the data 
		}
		$col[8] = join ":", "GT",@key;
		print join "\t", @col; print "\n";
	}
	close I;
}

sub UpdateValueInFORMAT {}

sub AddInfo {}

#####################################################################################
############################## The Common Sub functions #############################
#####################################################################################

sub GetFormatValue {
	my ( $vcfInfile, $formatValue, @field) = @_;

	my %sample;
	open  I, $vcfInfile =~ /\.gz$/ ? "gzip -dc $vcfInfile |" : $vcfInfile or die "Cannot open file $vcfInfile\n";
	while ( <I> ) {

		chomp;
		my @col = split;
		next if /^#/;

		my @format = split /:/, $col[8];
		die "[ERROR] The first field in FORMAT should be 'GT'\n" if $format[0] ne 'GT';
		my %fmat2Indx; for (my $i = 0; $i < @format; ++$i ) { $fmat2Indx{ $format[$i] } = $i; }
		for my $f ( @field) { 
			die "[ERROR] The '$f' is not in the FORMAT fields of $vcfInfile\n" if !exists $fmat2Indx{$f}; 
		}

		my $key = "$col[0]:$col[1]";
		for ( my $i = 9; $i < @col; ++$i ) {
			my @data = split /:/, $col[$i];
			for my $f (@field) {
				$$formatValue{$key}->[$i-9]->{$f} = $data[$fmat2Indx{$f}];
			}
		}
	}
	close I;
}




















