#-*-perl-*-
# $Id$
use strict;

chdir('../..'); # hack to allow run from t
#use lib '.';
use lib 't/lib';

#use Test::More tests=> 1000;
use Bio::Root::Test;

test_begin( -tests => 1000 );

use_ok('Bio::AlignIO::nexml'); # checks that your module is there and loads ok


# this passes if $object gets defined without throws by the constructor
# use when droppeded into bioperl
 ok( my $inAlnStream = Bio::AlignIO->new(-file => test_input_file("characters.nexml.xml"), -format => 'nexml'), 'make stream');
 	

 

	
	ok( my $aln_obj = $inAlnStream->next_aln(), 'nexml matrix to aln' );
	isa_ok($aln_obj, 'Bio::SimpleAlign', 'obj ok');
	is ($aln_obj->id,	'DNA sequences', 'aln id');
	my $num =0;
	my @expected_seqs = ('ACGCTCGCATCGCATC', 'ACGCTCGCATCGCATT', 'ACGCTCGCATCGCATG');
	#checking sequence objects
	foreach my $seq_obj ($aln_obj->each_seq()) {
		$num++;
		
		is( $seq_obj->alphabet, 'dna', "alphabet" );
		is( $seq_obj->display_id, "DNA sequences.row_$num", "display_id");
		is( $seq_obj->seq, $expected_seqs[$num-1], "sequence correct");
	}
	
	
#tests for writing nexml alignments
diag('Begin tests for write/read roundtrip');
my $outdata = test_output_file();
	ok( my $outAlnStream = Bio::AlignIO->new(-file =>$outdata, -format => 'nexml'), 'out stream ok');;
	
	ok( $outAlnStream->write_aln($aln_obj), 'write nexml');
close($outdata);
	ok( my $inAlnStream2 = Bio::AlignIO->new(-file => $outdata, -format => 'nexml'), 'reopen');;
	
	ok( my $aln_obj2 = $inAlnStream2->next_aln(),'get aln (rt)' );
	isa_ok($aln_obj2, 'Bio::SimpleAlign', 'aln obj (rt)');
	is ($aln_obj2->id, 'DNA sequences', "aln id (rt)");
	$num =0;
	@expected_seqs = ('ACGCTCGCATCGCATC', 'ACGCTCGCATCGCATT', 'ACGCTCGCATCGCATG');
	#checking sequence objects
	foreach my $seq_obj ($aln_obj2->each_seq()) {
		$num++;
		
		is( $seq_obj->alphabet, 'dna', "alphabet (rt)" );
		is( $seq_obj->display_id, "DNA sequences.row_$num", "display_id (rt)");
		is( $seq_obj->seq, $expected_seqs[$num-1], "sequence (rt)");
	}
