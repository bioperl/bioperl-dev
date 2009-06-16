# $Id: nexml.pm
#
# BioPerl module for Bio::TreeIO::nexml
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Chase Miller <chmille4@gmail.com>
#
# Copyright Chase Miller
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::TreeIO::nexml - A TreeIO driver module for parsing Nexml tree files

=head1 SYNOPSIS

  use Bio::TreeIO;
  my $in = Bio::TreeIO->new(-file => 'data.nexml' -format => 'Nexml');
  while( my $tree = $in->next_tree ) {
  }

=head1 DESCRIPTION

This is a driver module for parsing tree data in a Nexml format.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to
the Bioperl mailing list.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
of the bugs and their resolution. Bug reports can be submitted via
the web:

  http://bugzilla.open-bio.org/

=head1 AUTHOR - Chase Miller

Email chmille4@gmail.com

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::TreeIO::nexml;
use strict;

use Bio::Event::EventGeneratorI;
use IO::String;
use Bio::Phylo::IO qw (parse unparse);

use base qw(Bio::TreeIO);

=head2 new

 Title   : new
 Args    : -header    => boolean  default is true 
                         print/do not print #NEXUS header
           -translate => boolean default is true
                         print/do not print Node Id translation to a number

=cut

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
}

=head2 next_tree

 Title   : next_tree
 Usage   : my $tree = $treeio->next_tree
 Function: Gets the next tree in the stream
 Returns : Bio::Tree::TreeI
 Args    : none


=cut

sub next_tree {
    my ($self) = @_;
    unless ( $self->{'_parsed'} ) {
        $self->_parse;
    }
    return $self->{'_trees'}->[ $self->{'_treeiter'}++ ];
}

sub rewind {
    shift->{'_treeiter'} = 0;
}

sub _parse {
    my ($self) = @_;

    $self->{'_parsed'}   = 1;
    $self->{'_treeiter'} = 0;
    
    
    my $proj = parse(
 	'-file'       => $self->{'_file'},
 	'-format'     => 'nexml',
 	'-as_project' => '1'
 	);
 	
 	my $taxa = $proj->get_taxa();
 	my $forests = $proj->get_forests();
 	
 	foreach my $forest (@$forests) 
 	{	
 	my $basename = $forest->get_name();
 	my $trees = $forest->get_entities();
 		
 
 		foreach my $t (@$trees)
 		{
 			my %created_nodes;
 			my $tree_id = $t->get_name();
 			my $tree = Bio::Tree::Tree->new(-id => "$basename.$tree_id");
 			
# this is good -- now really need some tests for this code; have a look 
# at the distribution tests in t/Tree for some data/ideas... /maj
#just noticed these comments when I went to commit. I'll address these asap. /Chase

 			
 			
 			#process terminals only removing terminals as they get processed 
 			#which inturn creates new terminals to process until the entire tree has been processed
 			my $terminals = $t->get_terminals();
 			for(my $i=0; $i<@$terminals; $i++)
 			{
 				my $terminal = $$terminals[$i];
 				my $new_node_id = $terminal->get_name();
 				my $newNode;
 				
 				if(exists $created_nodes{$new_node_id})
 				{
 					$newNode = $created_nodes{$new_node_id};
 				}
 				else
 				{
 					$newNode = Bio::Tree::Node->new(-id => $new_node_id);
 					$created_nodes{$new_node_id} = $newNode;
 				}
 				
 				#transfer attributes that apply to all nodes
 				#check if taxa data exists for the current node ($terminal)
 				if(my $taxon = $terminal->get_taxon()) {
 					$newNode->add_tag_value("taxon", $taxon->get_name());
 				}
 				
 				#check if you've reached the root of the tree and if so, stop.
 				if($terminal->is_root()) {
 					$tree->set_root_node($newNode);
 					last;
 				}
 				
 				#transfer attributes that apply to non-root only nodes
 				$newNode->branch_length($terminal->get_branch_length());
 				
 				my $parent = $terminal->get_parent();
 				my $parentID = $parent->get_name();
 				if(exists $created_nodes{$parentID})
 				{
 					$created_nodes{$parentID}->add_Descendent($newNode);
 				}
 				else
 				{
 					my $parent_node = Bio::Tree::Node->new(-id => $parentID);
 					$parent_node->add_Descendent($newNode);
 					$created_nodes{$parentID} = $parent_node; 
 				}
 				#remove processed node from tree
 				$parent->prune_child($terminal);
 				
 				#check if the parent of the removed node is now a terminal node and should be added for processing
 				if($parent->is_terminal())
 				{
 					push(@$terminals, $terminal->get_parent());
 				}
 			}
			push @{ $self->{'_trees'} }, $tree;
 		}
 	}
}

=head2 write_tree

 Title   : write_tree
 Usage   : $treeio->write_tree($tree);
 Function: Writes a tree onto the stream
 Returns : none
 Args    : Bio::Tree::TreeI


=cut

sub write_tree {
	my ($self, $bptree) = @_;
	#most of the code below ripped form Bio::Phylo::Forest::Tree::new_from_bioperl()d
	my $fac = Bio::Phylo::Factory->new();
	my $tree = $fac->create_tree;
	my $class = 'Bio::Phylo::Forest::Tree';
	if ( Scalar::Util::blessed $bptree && $bptree->isa('Bio::Tree::TreeI') ) {
		bless $tree, $class;
		$tree = $tree->_recurse( $bptree->get_root_node );
			
		# copy name
		my $name = $bptree->id;
		$tree->set_name( $name ) if defined $name;
			
		# copy score
		my $score = $bptree->score;
		$tree->set_score( $score ) if defined $score;
	}
	else {
		#TODO need to convert to Bioperl debugging
		#throw 'ObjectMismatch' => 'Not a bioperl tree!';
	}
	
	$self->_print($tree->to_xml());
	return $tree;
}


1;