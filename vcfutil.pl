# Author : Shujia Huang
# Date   : 2014-06-21 16:33:23
#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

#use lib "/home/siyang/USER/huangshujia/iCodeSpace/perl/My/PmVCF";
use VCF;

die qq/
Usage   : perl $0 <command> [<arguments>]\n
Command : 

/ if @ARGV < 1;
my $command = shift @ARGV;
my %func    = ( 'addformat' => \&AddFORMAT, 'addinfo' => \&AddInfo );
die "Unknown command $command\n" if !defined($func{$command}) ;
&{$func{$command}};

print STDERR "\n************************** Processing $command DONE **************************\n";
#####################

sub AddFORMAT {
	my ( $fromVcfInfile, $toVcfInfile, $import );
	GetOptions (
		"from=s"=> \$fromVcfInfile,  # Get same FORMAT from this VCF file
		"to=s"  => \$toVcfInfile,    # Target VCF. Insert to this VCF file
		"add=s" => \$add,            # FORMAT.   should looks like : 'foo:bar'
	);

	print STDERR "[ERROR] User ERROR. Missing '-from' parameter.\n" if @ARGV > 1 and !defined $fromVcfInfile;
	print STDERR "[ERROR] User ERROR. Missing '-to'   parameter.\n" if @ARGV > 1 and !defined $toVcfInfile;
	print STDERR "[ERROR] User ERROR. Missing '-add'  parameter.\n" if @ARGV > 1 and !defined $add;

	die qq/ \nUsage : perl $0 addformat -from [vcf] -to [Target vcf] -add 'foo:bar' > OutputVCF\n/ 
		if !defined $add or !defined $fromVcfInFile or !$toVcfInfile;

	my @add        = split /:/, $add;
	my %toheader   = VCF::VcfHeader( $toVcfInfile   );
	my %fromheader = VCF::VcfHeader( $fromVcfInfile );

	# Load New format into the VCF Header
	for my $k ( @add ) {
		my $key = "FORMAT:$k";
		die "[ERROR] The '$k' is not in the FORMAT fields of $fromVcfInfile\n" if !exists $fromheader{$key};
		print STDERR "[WARNING] $key is already in $toVcfInfile, perhaps you should use 'UpdateValueInFORMAT'\n" 
			if exists $toheader{$key};
		$toheader{$key} = $fromheader{$key};
	}

	# Get new format for per positions
	my %newFormatValue;
	GetFormatValue( $fromVcfInfile, \%newFormatValue, @add )

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
		if (/#CHROM/) { for (my $i = 9; $i < @col; ++$i){ $sample{$i} = $col[$i]; } }
		next if /^#/;

		my @format = split /:/, $col[8];
		my %fmat; for (my $i = 0; $i < @format; ++$i ) { $fmat{ $format[$i] } = $i; }

		my $key = "$col[0]:$col[1]";
		for ( my $i = 9; $i < @col; ++$i ) {
			$$formatValue{}
		}
		
	}
	close I;
}





















