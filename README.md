PmVCF
======
PmVCF is a simple Perl module for parsing and manipulating VCF files

LICENSE
--------
Copyright &copy; 2014-2015

__Author & contributors:__ Shujia Huang
__Contact              :__ huangshujia@genomics.cn

### addformat

	Usage : perl vcfutil.pl addformat -from [vcf] -to [Target vcf] -add 'foo:bar' > OutputVCF

	CAUTION The samples and the order of sample should be the same in [-from [vcf]] and [-to [Target vcf] ] 
