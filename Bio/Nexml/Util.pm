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

Bio::Nexml::Util - A utility module for parsing nexml documents

=head1 SYNOPSIS

  Do not use this module directly. It shoulde be used through 
  Bio::Nexml, Bio::SeqIO::nexml, Bio::AlignIO::nexml, or 
  Bio::TreeIO::nexml
  

=head1 DESCRIPTION

This is a utility module in the nexml namespace.  It contains methods
that are needed by multiple modules.

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


#Let the code begin

package Bio::Nexml::Util;

use strict;

#not sure that it needs to inerhit from Bio::Nexml
use base qw(Bio::Nexml);


sub _make_aln {
	my ($self, $proj) = @_;
	my ($start, $end, $seq, $desc);
	my $taxa = $proj->get_taxa();
 	my $matrices = $proj->get_matrices();
 	my @alns;
 	
 	foreach my $matrix (@$matrices) 
 	{	
		my $aln = Bio::SimpleAlign->new();
		
 		#check if mol_type is something that makes sense to be a seq
 		my $mol_type = lc($matrix->get_type());
 		unless ($mol_type eq 'dna' || $mol_type eq 'rna' || $mol_type eq 'protein')
 		{
 			next;
 		}
 		
 		my $basename = $matrix->get_name();
 		$aln->id($basename);
 		
 		my $rows = $matrix->get_entities();
 		my $seqNum = 0;
 		foreach my $row (@$rows)
 		{
 			my $newSeq = $row->get_char();
 			my $rowlabel;
 			$seqNum++;
 			
 			#constuct seqID based on matrix label and row id
 			my $seqID = "$basename.row_$seqNum";
 			
 			#Check if theres a row label and if not default to seqID
 			if( !defined($rowlabel = $row->get_name())) {$rowlabel = $seqID;}
 			
 			

 			

# I would allow the LocatableSeq constructor to handle setting start and end,
# you can leave attrs out -- UNLESS nexml has a slot for these coordinates;
# I would dig around for this. /maj

 			$seq = Bio::LocatableSeq->new(
						  -seq         => $newSeq,
						  -display_id  => "$seqID",
						  #-description => $desc,
						  -alphabet	   => $mol_type,
						  );
			#what other data is appropriate to pull over from bio::phylo::matrices::matrix??
		    $aln->add_seq($seq);
		    $self->debug("Reading r$seqID\n");
 		
 			
 		}
 		push (@alns, $aln);
 	}
 	return \@alns;
}

sub _make_tree {
	my($self, $proj) = @_;
	my @trees;
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

 			
 			
 			#process terminals only, removing terminals as they get processed 
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
			push @trees, $tree;
 		}
 	}
 	return \@trees;
}

sub _make_seq {
	my($self, $proj) = @_;
	my $matrices = $proj->get_matrices();
	my @seqs;
 	
 	foreach my $matrix (@$matrices) 
 	{	
 		#check if mol_type is something that makes sense to be a seq
 		my $mol_type = lc($matrix->get_type());
 		unless ($mol_type eq 'dna' || $mol_type eq 'rna' || $mol_type eq 'protein')
 		{
 			next;
 		}
 		
 		my $rows = $matrix->get_entities();
 		my $seqnum = 0;
 		my $basename = $matrix->get_name();
 		foreach my $row (@$rows)
 		{
 			my $newSeq = $row->get_char();
 			
 			$seqnum++;
 			#construct full sequence id by using bio::phylo "matrix label" and "row id"
 			my $seqID = "$basename.seq_$seqnum";
 			my $rowlabel;
 			#check if there is a label for the row, if not default to seqID
 			if (!defined ($rowlabel = $row->get_name())) {$rowlabel = $seqID;}
 			
 		
 			#build the seq object using the factory create method
 			#not sure if this is the preferred way, but couldn't get it to work
 			#my $seq = $self->sequence_factory->create(
			#		   -seq         => $newSeq,
			#		   -id          => $rowlabel,
			#		   -primary_id  => $seqID,
			#		   #-desc        => $fulldesc,
			#		   -alphabet    => $mol_type,
			#		   -direct      => 1,
			#		   );
 			#did this instead
 			my $seqbuilder = new Bio::Seq::SeqFactory('-type' => 'Bio::Seq');
 			
 			my $seq = $seqbuilder->create(
					   -seq         => $newSeq,
					   -id          => $rowlabel,
					   -primary_id  => $seqID,
					   #-desc        => $fulldesc,
					   -alphabet    => $mol_type,
					   -direct      => 1,
					   );
 			
 			push (@seqs, $seq);
 			#what other data is appropriate to pull over from bio::phylo::matrices::matrix??
 		}
 	}
 	return \@seqs;
}

1;

