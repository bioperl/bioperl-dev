use strict;

use lib '..';
use Bio::Tree::Tree;
use Bio::TreeIO;
use Test::More tests=> 1000;
use Bio::Root::Test;
use Bio::Nexml;


use_ok('Bio::TreeIO::nexml'); # checks that your module is there and loads ok


 # this passes if $object gets defined without throws by the constructor
 ok( my $TreeStream = Bio::TreeIO->new(-file => test_input_data('trees.nexml.xml'), -format => 'Nexml') );
 
 #load tree
	ok( my $tree_obj = $TreeStream->next_tree() );
	my $tree_obj1 = $TreeStream->next_tree();
	isa_ok($tree_obj, 'Bio::Tree::Tree');
	
	my $nexml_doc = Bio::Nexml->new(-file => test_output_data('>out_nexml.doc'), -format => 'Nexml');
	
	#in progress
	#$nexml_doc->write(-trees => \@trees);