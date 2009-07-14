use strict;

use lib '../..';
use Bio::AlignIO::Nexml;
use Test::More tests=> 1000;

use_ok('Bio::AlignIO::nexml'); # checks that your module is there and loads ok


 # this passes if $object gets defined without throws by the constructor
 	# use when droppeded into bioperl
 ok( my $inAlnStream = Bio::AlignIO->new(-file => test_input_file("../../code/data_sets/characters.nexml.xml"), -format => 'nexml'));
 	

 

	
	ok( my $aln_obj = $inAlnStream->next_aln() );
	isa_ok($aln_obj, 'Bio::SimpleAlign');
	is ($aln_obj->id,	'DNA sequences', 		"id");
	my $num =0;
	my @expected_seqs = ('ACGCTCGCATCGCATC', 'ACGCTCGCATCGCATT', 'ACGCTCGCATCGCATG');
	#checking sequence objects
	foreach my $seq_obj ($aln_obj->each_seq()) {
		$num++;
		
		is( $seq_obj->alphabet,			'dna',					"alphabet" );
		is( $seq_obj->display_id,	"DNA sequences.row_$num",	"display_id");
		is( $seq_obj->seq,			$expected_seqs[$num-1],		"sequence");
	}
	
	
#tests for writing nexml alignments
	ok( my $outAlnStream = Bio::AlignIO->new(-file => test_output_data('>../../code/data_sets/charactersOut.xml'), -format => 'nexml'), 'Begin Tests for writing files');;
	
	ok( $outAlnStream->write_aln($aln_obj));
	
	ok( my $inAlnStream2 = Bio::AlignIO->new(-file => test_input_data('../../code/data_sets/charactersOut.xml'), -format => 'nexml'), 'Begin Tests for writing files');;
	
	ok( my $aln_obj2 = $inAlnStream2->next_aln() );
	isa_ok($aln_obj2, 'Bio::SimpleAlign');
	is ($aln_obj2->id,	'DNA sequences', 		"id");
	$num =0;
	@expected_seqs = ('ACGCTCGCATCGCATC', 'ACGCTCGCATCGCATT', 'ACGCTCGCATCGCATG');
	#checking sequence objects
	foreach my $seq_obj ($aln_obj2->each_seq()) {
		$num++;
		
		is( $seq_obj->alphabet,			'dna',					"alphabet" );
		is( $seq_obj->display_id,	"DNA sequences.row_$num",	"display_id");
		is( $seq_obj->seq,			$expected_seqs[$num-1],		"sequence");
	}