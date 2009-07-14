use strict;

use lib '..';
use Bio::Tree::Tree;
use Bio::TreeIO;
use Test::More tests=> 1000;
use Bio::Root::Test;
use Bio::Nexml;


use_ok('Bio::Nexml'); # checks that your module is there and loads ok


 # this passes if $object gets defined without throws by the constructor
 ok( my $TreeStream = Bio::TreeIO->new(-file => test_input_data('../code/data_sets/trees.nexml.xml'), -format => 'Nexml') );
 ok( my $AlnStream = Bio::AlignIO->new(-file => test_input_data('../code/data_sets/characters.nexml.xml'), -format => 'Nexml'));
 
  	#load tree
	ok( my $tree_obj1 = $TreeStream->next_tree() );
	my $tree_obj2 = $TreeStream->next_tree();
	isa_ok($tree_obj1, 'Bio::Tree::Tree');
	isa_ok($tree_obj2, 'Bio::Tree::Tree');
	
	my @trees;
	push @trees, $tree_obj1;
	push @trees, $tree_obj2;
	
	#load aln
	ok (my $aln_obj1 = $AlnStream->next_aln() );
	my $aln_obj2 = $AlnStream->next_aln();
	
	my @alns;
	push @alns, $aln_obj1;
	push @alns, $aln_obj2;
	
	my $nexml_doc = Bio::Nexml->new(-file => test_output_data('>../code/data_sets/out_nexml_doc.xml'), -format => 'Nexml');
	
	
	ok( $nexml_doc->write_doc(-trees => \@trees, -alns => \@alns) );
	
	my $in_nexml_doc = Bio::Nexml->new(-file => test_input_data('../code/data_sets/out_nexml_doc.xml'), -format => 'Nexml');
	
	ok ( my $bptree1 = $in_nexml_doc->next_tree() );
	
	isa_ok($bptree1, 'Bio::Tree::Tree');
	is( $bptree1->get_root_node()->id(), 'n1', "root node");
	my @nodes = $bptree1->get_nodes();
	is( @nodes, 9, "number of nodes");
	ok ( my $node7 = $bptree1->find_node('n7') );
	is( $node7->branch_length, 0.3247, "branch length");
	is( $node7->ancestor->id, 'n3');
	is( $node7->ancestor->branch_length, '0.34534');
	
	#Check leaf nodes and taxa
	my %expected_leaves = (
							'n8'	=>	'bird',
							'n9'	=>	'worm',
							'n5'	=>	'dog',
							'n6'	=>	'mouse',
							'n2'	=>	'human'
	);
	
	ok( my @leaves = $bptree1->get_leaf_nodes() );
	is( @leaves, 5, "number of leaf nodes");
	foreach my $leaf (@leaves)
	{
		my $leafID = $leaf->id();
		ok( exists $expected_leaves{$leaf->id()}, "$leafID exists"  );
		is( $leaf->get_tag_values('taxon'), $expected_leaves{$leaf->id()}, "$leafID taxon");
	}
	
	my $bptree2 = $in_nexml_doc->next_tree();
	