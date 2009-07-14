use strict;

use lib '../..';
use Bio::PrimarySeq;
use Bio::SeqIO::Nexml;
use Test::More tests=> 1000;


use_ok('Bio::SeqIO::nexml'); # checks that your module is there and loads ok


 # this passes if $object gets defined without throws by the constructor
 	# use when droppeded into bioperl
 ok( my $SeqStream = Bio::SeqIO->new(-file => test_input_file("../../code/data_sets/characters.nexml.xml"), -format => 'nexml'));
 

 

	#checking first sequence object
	ok( my $seq_obj = $SeqStream->next_seq() );
	isa_ok($seq_obj, 'Bio::Seq');
	is( $seq_obj->alphabet,		'dna',					"alphabet" );
	is( $seq_obj->primary_id,	'DNA sequences.seq_1',	"primary_id");
	is( $seq_obj->display_id,	'dna_seq_1',			"display_id");
	is( $seq_obj->seq,			'ACGCTCGCATCGCATC',		"sequence");

	#checking second sequence object
	ok( $seq_obj = $SeqStream->next_seq() );
	is( $seq_obj->alphabet,		'dna',					"alphabet" );
	is( $seq_obj->primary_id,	'DNA sequences.seq_2',	"primary_id");
	is( $seq_obj->display_id,	'dna_seq_2',			"display_id");
	is( $seq_obj->seq,			'ACGCTCGCATCGCATT',		"sequence");
	
	$SeqStream->next_seq();
	$SeqStream->next_seq();
	
	
	#checking fifth sequence object
	ok( $seq_obj = $SeqStream->next_seq() );
	is( $seq_obj->alphabet,		'rna',					"alphabet" );
	is( $seq_obj->primary_id,	'RNA sequences.seq_2',	"primary_id");
	is( $seq_obj->display_id, 	'RNA sequences.seq_2',	"display_id defaults to primary");
	is( $seq_obj->seq,			'ACGCUCGCAUCGCAUC',		"sequence");
	
	
#Start tests for writing to a file
	
 	ok( my $outSeqStream = Bio::SeqIO->new(-file => test_output_data('>../../code/data_sets/charactersSeqsOut.xml'), -format => 'nexml'), 'Begin Tests for writing tree files');;
	ok( $outSeqStream->write_seq($seq_obj));
	
	my $inSeqStream = Bio::SeqIO->new(-file => test_input_data('../../code/data_sets/charactersSeqsOut.xml'), -format => 'nexml');
	
	#TODO when writing multiple seqs works this will be useful
=head not done yet
	#checking first tree object
	ok($seq_obj = $inSeqStream->next_seq() );
	
	isa_ok($seq_obj, 'Bio::Seq');
	is( $seq_obj->alphabet,		'dna',					"alphabet" );
	is( $seq_obj->primary_id,	'DNA sequences.seq_1',	"primary_id");
	is( $seq_obj->display_id,	'dna_seq_1',			"display_id");
	is( $seq_obj->seq,			'ACGCTCGCATCGCATC',		"sequence");

	#checking second sequence object
	ok( $seq_obj = $SeqStream->next_seq() );
	is( $seq_obj->alphabet,		'dna',					"alphabet" );
	is( $seq_obj->primary_id,	'DNA sequences.seq_2',	"primary_id");
	is( $seq_obj->display_id,	'dna_seq_2',			"display_id");
	is( $seq_obj->seq,			'ACGCTCGCATCGCATT',		"sequence");
	
	$SeqStream->next_seq();
	$SeqStream->next_seq();
=cut
	
	#checking fifth sequence object
	ok( $seq_obj = $inSeqStream->next_seq() );
	is( $seq_obj->alphabet,		'rna',					"alphabet" );
	is( $seq_obj->primary_id,	'RNA sequences.seq_2.seq_1',	"primary_id");
	is( $seq_obj->display_id, 	'RNA sequences.seq_2.seq_1',	"display_id defaults to primary");
	is( $seq_obj->seq,			'ACGCUCGCAUCGCAUC',		"sequence");
	