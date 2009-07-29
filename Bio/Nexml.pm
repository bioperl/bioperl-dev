# $Id$
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

=head1 AUTHOR - Chase Miller

Email chmille4@gmail.com

=head1 CONTRIBUTORS 

Mark A. Jensen, maj -at- fortinbras -dot- com

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

#' Let the code begin...


package Bio::Nexml;
use strict;
#TODO Change this
use lib '..';

use Bio::SeqIO::nexml;
use Bio::AlignIO::nexml;
use Bio::TreeIO::nexml;
use Bio::Nexml::Util;

use Bio::Phylo::IO;
use Bio::Phylo::Factory;
use Bio::Phylo::Matrices;

use base qw(Bio::Root::IO);

my $nexml_fac = Bio::Nexml::Factory->new();

sub new {
 	my($class,@args) = @_;
 	my $self = $class->SUPER::new(@args);

	my %params = @args;
	my $file_string = $params{'-file'};
	
	$self->{'_seqIO'}  = Bio::SeqIO::nexml->new(@args);
 	$self->{'_alnIO'}  = Bio::AlignIO::nexml->new(@args);
 	$self->{'_treeIO'} = Bio::TreeIO::nexml->new(@args);
 	$self->{'_taxa'}   = my %taxa;
 	
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
    
    $self->{'_treeiter'} = 0;
    $self->{'_seqiter'}  = 0;
    $self->{'_alniter'}  = 0;
    
	$self->{'_trees'} = $nexml_fac->create_bperl_tree($self->doc);
	$self->{'_alns'}  = $nexml_fac->create_bperl_aln($self->doc);
	$self->{'_seqs'}  = $nexml_fac->create_bperl_seq($self->doc);
	
	$self->{'_parsed'}   = 1; #success
}

sub next_tree {
	my $self = shift;
	$self->_parse unless $self->{'_parsed'};

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


sub rewind {
    my $self = shift;
    my $elt = shift;
    $self->{"_${elt}iter"} = 0 if defined $self->{"_${elt}iter"};
    return 1;
}

sub rewind_seq { shift->rewind('seq'); }
sub rewind_aln { shift->rewind('aln'); }
sub rewind_tree { shift->rewind('tree'); }

# you could do something similar with the next_* functions too. Slick.

###

sub to_xml {
	my ($self, @args) = @_;
	
	my %params = @args;
	
	my ($trees, $alns, $seqs) = @params{qw( -trees -alns -seqs )};

	my $proj_doc = Bio::Phylo::Factory->create_project();
	
	#convert trees to bio::Phylo objects
	my $forest = Bio::Phylo::Factory->create_forest();
	my @forests;
	my @taxa_array;
	my $ent;
	my $taxa_o;
	my $phylo_tree_o;
	
	foreach my $tree (@$trees) {
		($phylo_tree_o, $taxa_o) = $nexml_fac->create_bphylo_tree($tree);
		
		#link_taxa($self, $taxa_o, $forest, \@taxa_array);
		
		$forest->insert($phylo_tree_o);
	}

	#convert matrices to Bio::Phylo objects
	my $matrices = Bio::Phylo::Matrices->new();
	my ($phylo_matrix_o, @matrix_taxas);
	
	foreach my $aln (@$alns)
	{
		($phylo_matrix_o, $taxa_o) = $nexml_fac->create_bphylo_aln($aln);
		
		#link_taxa and check for already existing identical taxa
		#link_taxa($self, $taxa_o, $phylo_matrix_o, \@matrix_taxas);
		$matrices->insert($phylo_matrix_o);
	}
	
	#convert sequences to Bio::Phylo objects
	foreach my $seq (@$seqs)
	{
		$matrices->insert($nexml_fac->create_bphylo_seq($seq));
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


# this is hairy--probably can use some tricks to clean it up a bit./maj

sub link_taxa
{
    
	my ($self, $taxa_o, $phylo_cont_o, $taxa_array) = @_;

	my $duplicate_taxa;
	my $new_taxa_ents = $taxa_o->get_entities();
	
	#test if taxa_o is already present

	# how about pushing this loop into a subroutine that 
	# returns $duplicate_taxa, to clean up the code a bit?
	####
	foreach my $taxa (@$taxa_array)
	{
		my $taxa_ents = $taxa->get_entities;
		my $new_num_taxa = @$new_taxa_ents;
		my $num_taxa = @$taxa_ents;
		
		#check if the taxa have same number of elements
		if($new_num_taxa != $num_taxa) {next;}
		
		my %taxa_o = map {($_)->get_name(), 1} @$taxa_ents;
		my @difference = grep {!$taxa_o {($_)->get_name()}} @$new_taxa_ents;
		
		if (!@difference) {
			$duplicate_taxa = $taxa;
			last;
		}
	}
	####
	
	if (!$duplicate_taxa) {
			push @$taxa_array, $taxa_o;
			$phylo_cont_o->set_taxa($taxa_o);
	} 
	else 
	{		
		if ($phylo_cont_o->isa('Bio::Phylo::Matrices::Matrix')) {
			$phylo_cont_o->set_taxa($taxa_o);
		}
	
		my $present_taxa_ents = $duplicate_taxa->get_entities();
		# '=>' means exactly the same as ',' but it makes it clearer
		# that you're producing a hash.../maj
		my %present_taxa_ents = map {($_)->get_name => $_} @$present_taxa_ents;
		
		foreach my $new_taxa_ent (@$new_taxa_ents)
		{
			my $new_label = $new_taxa_ent->get_name();
			#If tree get nodes and change taxa to point to already present ($duplicated_taxa) taxa

			# rearranging with a / /&&do{}; switch structure/maj
			for (ref $phylo_cont_o) {
			    /Bio::Phylo::Forest/ && do {
				my $nodes = $new_taxa_ent->get_nodes();
				foreach my $node (@$nodes)
				{
					$new_taxa_ent->unset_node($node);
					$present_taxa_ents{$new_label}->set_nodes($node);
				}
				last;
			    };
			#If matrix get data and change the taxa to point to already present ($duplicated_taxa) taxa
			    /Bio::Phylo::Matrices::Matrix/ && do {
				my $data = $new_taxa_ent->get_data();
				foreach my $datum (@$data)
				{
					$new_taxa_ent->unset_datum($datum);
					$present_taxa_ents{$new_label}->set_data($datum);
				}
				$phylo_cont_o->set_taxa($duplicate_taxa);
				last;
			    };
			    do { # else 
				$self->throw("Object container must be either Forest or Matrix");
			    };
			}
			$self->throw("taxa conversion error - taxa not identical") unless $present_taxa_ents{$new_label};
		}	
	}
}

1;
