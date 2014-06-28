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
    addformat       Add new fields to 'FORMAT' for each samples.
    extractformat   Extract the specific fields in 'FORMAT' for each samples
/ if @ARGV < 1;
my $command = shift @ARGV;
my %func    = ( 'addformat' => \&AddFORMAT, 'extractformat' => \&ExtractFORMAT );
die "Unknown command $command\n" if !defined($func{$command}) ;
&{$func{$command}};

print STDERR "\n************************** Processing $command DONE **************************\n";
#####################

sub ExtractFORMAT {

	my $ext = '';
	GetOptions ( "ext=s" => \$ext );

	die qq/
perl $0 extractformat [Option] <inVcffile> > Output

    Options :

        -ext  [str]  Extract format fields. e.g. 'foo:bar'. [NULL]

                     Caution : 
                     You should mind this order of format field. This progrom will just output the order
                     as you input by parameter -ext. If your paramter is -ext 'bar:foo', then the output order is 
                     still 'bar:foo'. And you'd better alaways extract 'GT' and make it to be the first field.
\n/ if @ARGV != 1;
	print STDERR "[INFO] perl $0 extractformat -ext $ext @ARGV \n\n" if @ARGV;
	
	my $vcfInfile = shift @ARGV;
	my @getformat = split /:/, $ext;
	my $linenum   = 0;
	open  I, $vcfInfile =~ /\.gz$/ ? "gzip -dc $vcfInfile |" :$vcfInfile or die "Cannot open file $vcfInfile\n";
	print STDERR "[INFO] Extracting From $vcfInfile\n";
	while ( <I> ) {
		chomp;
		if (/^#/) { print "$_\n"; next; }
		my @col = split;

		++$linenum; print STDERR "\t-- have loaded $linenum lines\n" if $linenum % 100000 == 0;
		if (length($ext) == 0) { print join "\t", @col[0..7]; print "\n"; next; } # Don't get any foramt fields

		my @format = split /:/, $col[8];
        die "$_\n@col\n" if @col < 10;
        die "[ERROR] The first field in FORMAT should be 'GT' in $col[8]\n@col\n" if $format[0] ne 'GT';

        my %fmat2Indx; for (my $i = 0; $i < @format; ++$i ) { $fmat2Indx{ $format[$i] } = $i; }
		for my $f ( @getformat ) { die "[ERROR] '$f' is not in $col[8]\n$_\n" if !exists $fmat2Indx{$f}; }
        for ( my $i = 9; $i < @col; ++$i ) {

            my @data = split /:/, $col[$i];
            $col[$i] = join ":", @data[ (map {$fmat2Indx{$_}} @getformat) ]; # Re-new the data 
        }
        $col[8] = join ":",@getformat;
        print join "\t", @col; print "\n";
	
	}
	close I;
	
	print STDERR "[INFO] FORMAT Extracting done. Total lines are $linenum\n";

}

sub AddFORMAT {
	my ( $fromVcfInfile, $toVcfInfile, $add );
	my $refId = "ALL";
	GetOptions (
		"from=s"=> \$fromVcfInfile,  # Get same FORMAT from this VCF file
		"to=s"  => \$toVcfInfile,    # Target VCF. Insert to this VCF file
		"add=s" => \$add,            # FORMAT.   should looks like : 'foo:bar'
		"id=s"	=> \$refId,          # The reference chromosome id. [ALL]
	);

	print STDERR "[ERROR] User ERROR. Missing '-from' parameter.\n" if @ARGV > 1 and !defined $fromVcfInfile;
	print STDERR "[ERROR] User ERROR. Missing '-to'   parameter.\n" if @ARGV > 1 and !defined $toVcfInfile;
	print STDERR "[ERROR] User ERROR. Missing '-add'  parameter.\n" if @ARGV > 1 and !defined $add;

	die qq/
Usage : perl $0 addformat [Option] -from [vcf] -to [Target vcf] -add 'foo:bar' > OutputVCF

    Option :
        -id  [str]  The reference chromosome id. [ALL]

Caution:  
    * The samples and the order of sample should be the same in [-from [vcf]] and [-to [Target vcf] ] 
\n/ if !defined $add or !defined $fromVcfInfile or !$toVcfInfile;
	print STDERR "[INFO] perl $0 addformat\n\t-from $fromVcfInfile\n\t-to $toVcfInfile\n\t-add $add\n\t-id $refId\n";

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

	print STDERR "[INFO] Loading the FORMAT $add fields from $fromVcfInfile\n";
	my %newFormatValue; GetFormatValue( $fromVcfInfile, $refId, \%newFormatValue, @add ); # Get new format for per positions
	print STDERR "[INFO] FORMAT $add fields loading done\n";
	print STDERR "[INFO] Adding $add fields to $toVcfInfile and outputting to a new vcf file\n";

	### Output 
	for my $k ( sort {$a cmp $b} keys %toheader ) { print "$toheader{$k}\n"; }

	open I, $toVcfInfile=~/\.gz$/ ? "gzip -dc $toVcfInfile|" :$toVcfInfile or die "Cannot open file $toVcfInfile\n";

	my $linenum = 0;
	while ( <I> ) {
		chomp;
		next if /^#/;
		my @col = split /\s+/, $_;
		next if ( ($refId ne "ALL") and ($refId ne $col[0]) );

		++$linenum; print STDERR "\t-- have loaded $linenum lines\n" if $linenum % 100000 == 0;

		my @format = split /:/, $col[8];
		die "$_\n@col\n" if @col < 10;
        die "[ERROR] The first field in FORMAT should be 'GT' in $col[8]\n@col\n" if $format[0] ne 'GT';

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
		if (!exists $newFormatValue{$pos}){ print STDERR "$_\n"; next;} # ignore the position not in newFormatValue.
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
	print STDERR "[INFO] FORMAT adding done. Total lines are $linenum\n";
}

sub UpdateValueInFORMAT {}

sub AddInfo {}

#####################################################################################
############################## The Common Sub functions #############################
#####################################################################################

sub GetFormatValue {
	my ( $vcfInfile, $refId, $formatValue, @field) = @_;

	my %sample;
	my $linenum = 0;

	open I,$vcfInfile =~ /\.gz$/ ? "gzip -dc $vcfInfile|" : $vcfInfile or die "Cannot open file $vcfInfile\n";
	while ( <I> ) {

		chomp;
		next if /^#/;
		my @col = split;
		next if $refId ne "ALL" and $refId ne $col[0];		

		++$linenum; print STDERR "\t-- have loaded $linenum lines\n" if $linenum % 100000 == 0;

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
				$data[$fmat2Indx{$f}] = "." if !defined $data[$fmat2Indx{$f}]; 
				$$formatValue{$key}->[$i-9]->{$f} = $data[$fmat2Indx{$f}];
			}
		}
	}
	close I;
}





















