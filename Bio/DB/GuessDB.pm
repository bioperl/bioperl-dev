# BioPerl module for Bio::DB::GuessDB
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Hans-Rudolf Hotz <hans-rudolf.hotz@fmi.ch>
#
# Copyright Hans-Rudolf Hotz, Chase Miller
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
# 

=head1 NAME

Bio::DB::GuessDB - guesses source database of an accession number

=head1 SYNOPSIS

  # ...To be added!

=head1 DESCRIPTION

This is a simple module that tries to analyze an accesion number 
and determine which database it belongs to

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the 
evolution of this and other Bioperl modules. Send
your comments and suggestions preferably to one
of the Bioperl mailing lists. Your participation
is much appreciated.

  bioperl-l@lists.open-bio.org               - General discussion
  http://www.bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 

Please direct usage questions or support issues to the mailing list:

I<bioperl-l@bioperl.org>

rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to
help us keep track the bugs and their resolution.
Bug reports can be submitted via the web.

  http://bugzilla.open-bio.org/

=head1 AUTHORS

Hans-Rudolf Hotz
hans-rudolf.hotz@fmi.ch

Chase Miller
Email chmille4 at gmail dot com


=head1 APPENDIX

The rest of the documentation details each of the
object methods. Internal methods are usually
preceded with a _

=cut

# Let the code begin...


package Bio::DB::GuessDB;
use strict;

sub guessDB {
	my ($accession) = @_;

	my %database;
	$database{'id_type'} = "accession";
	if ($accession =~ /^(.+)\.\d+$/) {
		$database{'id_type'} = "sequence_version";
		$accession = $1;
	}	
	
	# test for RefSeq based on http://www.ncbi.nlm.nih.gov/RefSeq/key.html#accession
	if ($accession =~ /^[ANXY]P_\d{6}$/ || $accession =~ /^ZP_\d{8}$/ || $accession =~ /^[NXY]P_\d{9}$/ ) {
		$database{'name'} = "RefSeq";
		$database{'type'} = "protein";
	}
	elsif ($accession =~ /^AC_\d{6}$/ || $accession =~ /^N[CGMRTWS]_\d{6}$/ || $accession =~ /^X[MR]_\d{6}$/ ) {
		$database{'name'} = "RefSeq";
		$database{'type'} = "nucleotide";
	}
	elsif ($accession =~ /^N[MW]_\d{9}$/ || $accession =~ /^NZ_\w{4}\d{8}$/ ||$accession =~ /^XM_\d{9}$/ ) {
		$database{'name'} = "RefSeq";
		$database{'type'} = "nucleotide";
	}		

	# test for UniProtKB based on http://www.uniprot.org/manual/accession_numbers
	elsif ($accession =~ /^[A-N][0-9][A-Z][A-Z0-9][A-Z0-9][0-9]$/ ) {
		$database{'name'} = "UniProtKB";
		$database{'type'} = "protein";
	}
	elsif ($accession =~ /^[R-Z][0-9][A-Z][A-Z0-9][A-Z0-9][0-9]$/ ) {
		$database{'name'} = "UniProtKB";
		$database{'type'} = "protein";
	}
	elsif ($accession =~ /^[OPQ][0-9][A-Z0-9][A-Z0-9][A-Z0-9][0-9]$/ ) {
		$database{'name'} = "UniProtKB";
		$database{'type'} = "protein";
	}
	# test for UniProtKB entry name based on http://www.uniprot.org/manual/entry_name
	elsif ($accession =~ /^[A-Z0-9]{1,5}_[A-Z0-9]{1,5}$/ ) {
		$database{'name'} = "UniProtKB";
		$database{'type'} = "protein";
		$database{'id_type'} = "entry_name";
	}
	
	# test for Genbank accession format based on the release notes (section  3.4.6): ftp://ftp.ncbi.nih.gov/genbank/gbrel.txt
	elsif ($accession =~ /^[A-Z]\d{5}$/ || $accession =~ /^[A-Z][A-Z]\d{6}$/ ) {
		$database{'name'} = "GenBank";
		$database{'type'} = "nucleotide";
	}	
		
	# test for ensembl  (waiting for confirmation from ensembl, also a real validation of those organism triplets would be nice)
	elsif ($accession =~ /^ENS([A-Z]{3})?G\d{11}$/ ) {
		$database{'name'} = "Ensembl";
		$database{'type'} = "gene";
	}
	elsif ($accession =~ /^ENS([A-Z]{3})?T\d{11}$/ ) {
		$database{'name'} = "Ensembl";
		$database{'type'} = "nucleotide";
	}
	elsif ($accession =~ /^ENS([A-Z]{3})?P\d{11}$/ ) {
		$database{'name'} = "Ensembl";
		$database{'type'} = "protein";
	}
	
	# a functional test for Entrez Gene
	elsif ($accession =~ /^\d+$/ ) {
		my $foo = get("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=gene&id=$accession&retmode=xml");
		if ($foo =~ /Empty id list/ ) {
			$database{'name'} = "notrecognized";
			$database{'type'} = "unknown";
			$database{'id_type'} = "unknown";
		}
		else {
			$database{'name'} = "Gene";
			$database{'type'} = "gene";
		}	
		# just to be nice with the NCBI server
		sleep(2)
		# call to NCBI should be replaced wit a call to our local Gene database, once we have it.....
	}
	
	
	else {
		$database{'name'} = "notrecognized";
		$database{'type'} = "unknown";
		$database{'id_type'} = "unknown";
	}	
		
	return \%database;
}

