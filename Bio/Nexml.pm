# BioPerl module for Bio::Nexml
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Chase Miller <chmille4@gmail.com>
#
# Copyright Chase Miller
#
# You may distribute this module under the same terms as perl itself
#
# _history
# June 16, 2009  Largely rewritten by Chase Miller

# POD documentation - main docs before the code

=head1 NAME

Bio::Nexml - Nexml document handler

=head1 SYNOPSIS

    #TODO FILL THIS IN


=head1 DESCRIPTION

	Bio::Nexml is a handler for a Nexml document.  A Nexml document can represent three
	different data types: simple sequences, alignments, and trees. So.....FILL THIS IN


=head1 CONSTRUCTORS

=head2 Bio::Nexml-E<gt>new()

   $seqIO = Bio::Nexml->new(-file => 'filename');
   $seqIO = Bio::Nexml->new(-fh   => \*FILEHANDLE, -format=>$format); # this should work sense it's being passed through to SeqIO->new
   

=back



=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.

Your participation is much appreciated.

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
the bugs and their resolution.  Bug reports can be submitted via the
web:

  http://bugzilla.open-bio.org/

=head1 AUTHOR - Chase Miller, Mark A. Jensen

Email chmille4@gmail.com
      maj@fortinbras.us

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

#' Let the code begin...


package Bio::Nexml;
use strict;
#TODO Change this
use lib '..';
use Bio::SeqIO::Nexml;
use Bio::AlignIO::Nexml;
use Bio::TreeIO::Nexml;
use Bio::Phylo::IO;
use Bio::Nexml::Util;
use Bio::Phylo::Factory;
use Bio::Phylo::Matrices;

use base qw(Bio::Root::IO);

sub new {
 	my($class,@args) = @_;
 	my $self = $class->SUPER::new(@args);

	my %params = @args;
	my $file_string = $params{'-file'};
	
	
	$self->{'_seqIO'}  = Bio::SeqIO::nexml->new(@args);
 	$self->{'_alnIO'}  = Bio::AlignIO::nexml->new(@args);
 	$self->{'_treeIO'} = Bio::TreeIO::nexml->new(@args);
 	unless ($file_string =~ m/^\>/) {
 		$self->{'_doc'} = Bio::Phylo::IO->parse('-file' => $params{'-file'}, '-format' => 'nexml', '-as_project' => '1');
 	}
 	
 	
 	return $self;
}


sub treeIO {
	my $self = shift;
	return $self->{'_treeIO'};
}

sub seqIO {
	my $self = shift;
	return $self->{'_seqIO'};
}

sub alnIO {
	my $self = shift;
	return $self->{'_alnIO'};	
}

sub doc {
	my $self = shift;
	return $self->{'_doc'};
}

sub _parse {
	my ($self) = @_;
    
    $self->{'_parsed'}   = 1;
    $self->{'_treeiter'} = 0;
    $self->{'_seqiter'} = 0;
    $self->{'_alniter'} = 0;
    
	$self->{'_trees'} = Bio::Nexml::Util->_make_tree($self->doc);
	$self->{'_alns'}  = Bio::Nexml::Util->_make_aln($self->doc);
	$self->{'_seqs'}  = Bio::Nexml::Util->_make_seq($self->doc);
}

sub next_tree {
	my $self = shift;
	unless ( $self->{'_parsed'} ) {
        $self->_parse;
    }
	return $self->{'_trees'}->[ $self->{'_treeiter'}++ ];
}

sub next_seq {
	my $self = shift;
	unless ( $self->{'_parsed'} ) {
        $self->_parse;
    }
	return $self->{'_seqs'}->[ $self->{'_seqiter'}++ ];
}

sub next_aln {
	my $self = shift;
	unless ( $self->{'_parsed'} ) {
        $self->_parse;
    }
	return $self->{'_alns'}->[ $self->{'_alniter'}++ ];
}


sub write_doc {
	my ($self, @args) = @_;
	
	my %params = @args;
	
	my $trees = $params{'-trees'};
	my $alns  = $params{'-alns'};
	my $seqs  = $params{'-seqs'};
	
	my $proj_doc = Bio::Phylo::Factory->create_project();
	
	#convert trees to bio::Phylo objects
	my $forest = Bio::Phylo::Factory->create_forest();
	my @forests;
	my @taxas;
	my $ent;
	my $taxa_o;
	my $phylo_tree_o;
	my $first_taxa;
	
	foreach my $tree (@$trees) {
		($phylo_tree_o, $taxa_o) = Bio::Nexml::Util->create_bphylo_tree($tree);
		#check if taxa exists
		if (!$first_taxa) {
			$first_taxa = $taxa_o;
		}
		link_taxa($self, $taxa_o, $forest, \@taxas, $first_taxa);
		
		$forest->insert($phylo_tree_o);
	}

	#converts matrices to Bio::Phylo objects
	my $matrices = Bio::Phylo::Matrices->new();
	my ($phylo_matrix_o, @matrix_taxas);
	
	foreach my $aln (@$alns)
	{
		($phylo_matrix_o, $taxa_o) = Bio::Nexml::Util->create_bphylo_aln($aln);
		#check if taxa exists
		link_taxa($self, $taxa_o, $phylo_matrix_o, \@matrix_taxas, $first_taxa);
		$matrices->insert($phylo_matrix_o);
	}
	
	#convert sequences to Bio::Phylo objects
	foreach my $seq (@$seqs)
	{
		$matrices->insert(Bio::Nexml::Util->create_bphylo_seq($seq));
	}
	
	#Add matrices and forest objects to project object which represents a complete nexml document
	if($forest->first) {
		$proj_doc->insert($forest);
	}
	while(my $curr_matrix = $matrices->next) {
		$proj_doc->insert($curr_matrix);
	}
	
	#write nexml document to stream
	
	$self->_print($proj_doc->to_xml());
}

sub link_taxa
{
	
	my ($self, $taxa_o, $phylo_cont_o, $taxas, $first_taxa) = @_;
	
	
	if ($taxa_o->first() && !exists $taxas->[ get_taxa_labels($taxa_o) ]) {
			$phylo_cont_o->set_taxa($taxa_o);
			push @$taxas, get_taxa_labels($taxa_o);
		} 
		else #TODO make this work for multiple forests with different taxa
		{
			my $ents = $taxa_o->get_entities();
	
			my $main_taxa = $first_taxa->get_entities();
			for (my $i = 0; $i < @$ents; $i++)
			{
				my $new_label = $ents->[$i]->get_name();
				my $old_label = $main_taxa->[$i]->get_name();
				if( $new_label != $old_label) {
					$self->throw("taxa conversion error - taxa not identical");
				}
				my $id = $ents->[$i]->get_xml_id();
				my $mid = $main_taxa->[$i]->get_xml_id();
				$ents->[$i]->set_xml_id($mid);
			}
		}
}

sub get_taxa_labels
{
	my $taxa = shift(@_);
	my $ents = $taxa->get_entities();
	
	my $label_str = undef;
	
	foreach my $ent (@$ents)
	{
		$label_str .= $ent->get_name();
	}
	return $label_str;
}

1;