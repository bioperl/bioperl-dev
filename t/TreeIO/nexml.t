use strict;

use lib '../..';
use Bio::Tree::Tree;
use Bio::TreeIO;
use Test::More tests=> 1000;
use Bio::Root::Test;


use_ok('Bio::TreeIO::nexml'); # checks that your module is there and loads ok


 # this passes if $object gets defined without throws by the constructor
 ok( my $TreeStream = Bio::TreeIO->new(-file => test_input_data('trees.nexml.xml'), -format => 'Nexml') );
 

 	

	#checking first tree object
	ok( my $tree_obj = $TreeStream->next_tree() );
	isa_ok($tree_obj, 'Bio::Tree::Tree');
	is( $tree_obj->get_root_node()->id(), 'n1', "root node");
	my @nodes = $tree_obj->get_nodes();
	is( @nodes, 9, "number of nodes");
	ok ( my $node7 = $tree_obj->find_node('n7') );
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
	
	ok( my @leaves = $tree_obj->get_leaf_nodes() );
	is( @leaves, 5, "number of leaf nodes");
	foreach my $leaf (@leaves)
	{
		my $leafID = $leaf->id();
		ok( exists $expected_leaves{$leaf->id()}, "$leafID exists"  );
		is( $leaf->get_tag_values('taxon'), $expected_leaves{$leaf->id()}, "$leafID taxon");
	}
	
	
#Checking ability to write files

	ok( my $outTreeStream = Bio::TreeIO->new(-file => test_output_data('>treesOut.xml'), -format => 'nexml'), 'Begin Tests for writing tree files');;
	ok( $outTreeStream->write_tree($tree_obj));
	
	my $inTreeStream = Bio::TreeIO->new(-file => test_input_data('treesOut.xml'), -format => 'nexml');
	
	#checking first tree object
	ok($tree_obj = $inTreeStream->next_tree() );
	isa_ok($tree_obj, 'Bio::Tree::Tree');
	is( $tree_obj->get_root_node()->id(), 'n1', "root node");
	my @outnodes = $tree_obj->get_nodes();
	is( @outnodes, 9, "number of nodes");
	ok ( $node7 = $tree_obj->find_node('n7') );
	is( $node7->branch_length, 0.3247, "branch length");
	is( $node7->ancestor->id, 'n3');
	is( $node7->ancestor->branch_length, '0.34534');
	
	#Check leaf nodes and taxa
	
	ok( my @outleaves = $tree_obj->get_leaf_nodes() );
	is( @outleaves, 5, "number of leaf nodes");
	foreach my $leaf (@outleaves)
	{
		my $leafID = $leaf->id();
		ok( exists $expected_leaves{$leaf->id()}, "$leafID exists"  );
		is( $leaf->get_tag_values('taxon'), $expected_leaves{$leaf->id()}, "$leafID taxon");
	}
	
	