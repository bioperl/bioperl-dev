# $Id: Nexml.pm 15889 2009-07-29 13:35:29Z chmille4 $
# BioPerl module for Bio::NexmlIO
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

Bio::NexmlIO - stream handler for nexml documents

=head1 SYNOPSIS

    #Instantiate a Bio::Nexml object and link it to a file
    my $in_nexml = Bio::Nexml->new(-file => 'nexml_doc.xml', -format => 'Nexml');

	#Read in some data
	my $bptree1 = $in_nexml->next_tree();
	my $bpaln1  = $in_nexml->next_aln();
	my $bpseq1  = $in_nexml->next_seq();

	#Use/manipulate data
	...

	#Write data to nexml file
	my $out_nexml = Bio::Nexml->new(-file => '>new_nexml_doc.xml', -format => 'Nexml');
	$out_nexml->to_xml();
    


=head1 DESCRIPTION

	Bio::NexmlIO is a handler for a Nexml document.  A Nexml document can represent three
	different data types: simple sequences, alignments, and trees. NexmlIO has four main 
	methods next_tree, next_seq, next_aln, and write. NexmlIO returns bioperl seq, tree, and aln 
	objects which can be manipulated then passed to the write method of a new NexmlIO instance 
	to allow the creation of a nexml document.

Each bioperl object contains all the information to recreate a Bio::Phylo::Taxa object, so each time a bioperl object is converted to a biophylo object I check to see if it's assocaited taxa has already been created (with a hash using the NexmlIO_ID and Taxa_ID to create a unique string). If  not I create it, If so, I just use that taxa object to link the Bio::Phylo tree or matrix to.


=head1 CONSTRUCTORS

=head2 Bio::NexmlIO-E<gt>new()

   $seqIO = Bio::NexmlIO->new(-file => 'filename');
   $seqIO = Bio::NexmlIO->new(-fh   => \*FILEHANDLE, -format=>$format); # this should work sense it's being passed through to SeqIO->new
   

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


package Bio::NexmlIO;
use strict;
#TODO Change this
use lib '..';

use Bio::SeqIO::nexml;
use Bio::AlignIO::nexml;
use Bio::TreeIO::nexml;
use Bio::Nexml::Factory;
use Bio::Phylo::IO;
use Bio::Phylo::Factory;
use Bio::Phylo::Matrices;

use base qw(Bio::Root::IO);

my $nexml_fac = Bio::Nexml::Factory->new();

=head2 new

 Title   : new
 Usage   : my $in_nexmlIO = Bio::NexmlIO->new(-file => 'data.nexml.xml');
 Function: Creates a L<Bio::NexmlIO> object linked to a stream
 Returns : a L<Bio::NexmlIO> object
 Args    : file name
 
 See L<Bio::Root::IO>
 
=cut
sub new {
 	my($class,@args) = @_;
 	my $self = $class->SUPER::new(@args);

	my %params = @args;
	my $file_string = $params{'-file'};
 	
 	#create unique ID by creating a scalar and using the memory address
 	my $ID = bless \(my $dummy), "UniqueID";
 	$self->{'_ID'} = $ID;
 	
 	unless ($file_string =~ m/^\>/) {
 		$self->{'_doc'} = Bio::Phylo::IO->parse('-file' => $params{'-file'}, '-format' => 'nexml', '-as_project' => '1');
 	}
 	
 	
 	return $self;
}

=head2 new

 Title   : doc
 Usage   : my $nexml_doc = $in_nexmlIO->doc();
 Function: returns a L<Bio::Phylo::Project> object that contains all the Bio::Phylo data objects parsed from the stream
 Returns : a L<Bio::Phylo::Project> object
 Args    : none
 
=cut
sub doc {
	my $self = shift;
	return $self->{'_doc'};
}

# Takes the Bio::Phylo::Project object and creats BioPerl trees, alns, and seqs from it
sub _parse {
	my ($self) = @_;
    
    $self->{'_treeiter'} = 0;
    $self->{'_seqiter'}  = 0;
    $self->{'_alniter'}  = 0;
    
	$self->{_trees} = $nexml_fac->create_bperl_tree($self);
	$self->{_alns}  = $nexml_fac->create_bperl_aln($self);
	$self->{_seqs}  = $nexml_fac->create_bperl_seq($self);
	my $taxa_array = $self->doc->get_taxa();
	
	#my $nexml_doc = Bio::Nexml->new('-trees' => $trees, '-alns' => $alns, '-seqs' => $seqs, '-taxa_array' => $taxa_array);
	
	$self->{'_parsed'}   = 1; #success
}

=head2 next_tree

 Title   : next_tree
 Usage   : $tree = $stream->next_tree
 Function: Reads the next tree object from the stream and returns it.
 Returns : a L<Bio::Tree::Tree> object
 Args    : none

See L<Bio::Root::IO>, L<Bio::Tree::Tree>

=cut
sub next_tree {
	my $self = shift;
	$self->_parse unless $self->{'_parsed'};

	return $self->{'_trees'}->[ $self->{'_treeiter'}++ ];
}

=head2 next_seq

 Title   : next_seq
 Usage   : $seq = $stream->next_seq
 Function: Reads the next seq object from the stream and returns it.
 Returns : a L<Bio::Seq> object
 Args    : none

See L<Bio::Root::IO>, L<Bio::Seq>

=cut
sub next_seq {
	my $self = shift;
	unless ( $self->{'_parsed'} ) {
        $self->_parse;
    }
	return $self->{'_seqs'}->[ $self->{'_seqiter'}++ ];
}

=head2 next_aln

 Title   : next_aln
 Usage   : $aln = $stream->next_aln
 Function: Reads the next aln object from the stream and returns it.
 Returns : a L<Bio::SimpleAlign> object
 Args    : none

See L<Bio::Root::IO>, L<Bio::SimpleAlign>

=cut
sub next_aln {
	my $self = shift;
	unless ( $self->{'_parsed'} ) {
        $self->_parse;
    }
	return $self->{'_alns'}->[ $self->{'_alniter'}++ ];
}


sub _rewind {
    my $self = shift;
    my $elt = shift;
    $self->{"_${elt}iter"} = 0 if defined $self->{"_${elt}iter"};
    return 1;
}

=head2 rewind_seq

 Title   : rewind_seq
 Usage   : $stream->rewind_seq
 Function: Resets the stream for seqs
 Returns : none
 Args    : none

See L<Bio::Root::IO>, L<Bio::Seq>

=cut
sub rewind_seq { shift->_rewind('seq'); }

=head2 rewind_aln

 Title   : rewind_aln
 Usage   : $stream->rewind_aln
 Function: Resets the stream for alns
 Returns : none
 Args    : none

See L<Bio::Root::IO>, L<Bio::Simple::Align>

=cut
sub rewind_aln { shift->_rewind('aln'); }

=head2 rewind_tree

 Title   : rewind_tree
 Usage   : $stream->rewind_tree
 Function: Resets the stream for trees
 Returns : none
 Args    : none

See L<Bio::Root::IO>, L<Bio::tree::tree>

=cut
sub rewind_tree { shift->_rewind('tree'); }



=head2 write

 Title   : write
 Usage   : $stream->write(-alns => $alns, -seqs => $seqs, -trees => $trees)
 Function: converts BioPerl seq, tree, and aln objects into Bio::Phylo
 		   seq, tree, and aln objects, constructs a Bio::Phylo::Project object
 		   made up of the newly created Bio::Phylo objects, and writes the
 		   Bio::Phylo:Project object to the stream as a valid nexml document
 Returns : none
 Args    : \@L<Bio::Seq>, \@L<Bio::SimpleAlign>, \@L<Bio::Tree::Tree>

See L<Bio::Root::IO>, L<Bio::tree::tree>, L<Bio::Seq>, L<Bio::SimpleAlign>

=cut
sub write {
	my ($self, @args) = @_;
	
	my %params = @args;
	
	my ($trees, $alns, $seqs) = @params{qw( -trees -alns -seqs )};
	my %taxa_hash = ();
	my %seq_matrices = ();

	my $proj_doc = Bio::Phylo::Factory->create_project();
	
	#convert trees to bio::Phylo objects
	my $forest = Bio::Phylo::Factory->create_forest();
	my @forests;
	my @taxa_array;
	my $ent;
	my $taxa_o;
	my $phylo_tree_o;
	
	foreach my $tree (@$trees) {
		my $nexml_id = $tree->get_tag_values('_NexmlIO_ID');
		$taxa_o = undef;
		if ( defined $taxa_hash{$nexml_id} ) {
			$taxa_o = $taxa_hash{$nexml_id};
		}
		else {
			($taxa_o) = $nexml_fac->create_bphylo_taxa($tree);
			$forest->set_taxa($taxa_o) if defined $taxa_o;
			$taxa_hash{$nexml_id} = $taxa_o;
		}
		
		($phylo_tree_o) = $nexml_fac->create_bphylo_tree($tree,  $taxa_o);
		
		$forest->insert($phylo_tree_o);
	}

	#convert matrices to Bio::Phylo objects
	my $matrices = Bio::Phylo::Matrices->new();
	my $phylo_matrix_o;
	
	foreach my $aln (@$alns)
	{
		$taxa_o = undef;
		if (defined $taxa_hash{ $aln->{_Nexml_ID} }) {
			$taxa_o = $taxa_hash{$aln->{_Nexml_ID}};
		}
		else {
			($taxa_o) = $nexml_fac->create_bphylo_taxa($aln);
			$taxa_hash{$aln->{_Nexml_ID}} = $taxa_o;
		}
		
		($phylo_matrix_o) = $nexml_fac->create_bphylo_aln($aln,  $taxa_o);
		
		$phylo_matrix_o->set_taxa($taxa_o) if defined $taxa_o;
		$matrices->insert($phylo_matrix_o);	
	}
	
	my $seq_matrix_o;
	my $datum;
	#convert sequences to Bio::Phylo objects
	foreach my $seq (@$seqs)
	{
		$taxa_o = undef;
		#check if this Bio::Phylo::Taxa obj has already been created
		if (defined $taxa_hash{ $seq->{_Nexml_ID} }) {
			$taxa_o = $taxa_hash{$seq->{_Nexml_ID}};
		}
		else {
			($taxa_o) = $nexml_fac->create_bphylo_taxa($seq);
			$taxa_hash{$seq->{_Nexml_ID}} = $taxa_o;
		}
		$datum = $nexml_fac->create_bphylo_seq($seq, $taxa_o);
		#check if this Bio::Phylo::Matrices::Matrix obj has already been created
		if (defined $seq_matrices{ $seq->{_Nexml_matrix_ID} }) {
			$seq_matrix_o = $seq_matrices{$seq->{_Nexml_matrix_ID}};
			my $taxon_name = $datum->get_taxon()->get_name();
			$datum->unset_taxon();
			$seq_matrix_o->insert($datum);
			$datum->set_taxon($seq_matrix_o->get_taxa()->get_by_name($taxon_name));
		}
		else {
			$seq_matrix_o = Bio::Phylo::Factory->create_matrix('-type' => $datum->moltype);
			$seq_matrices{$seq->{_Nexml_matrix_ID}} = $seq_matrix_o;
			$seq_matrix_o->set_taxa($taxa_o) if defined $taxa_o;
			$seq_matrix_o->insert($datum);
			
			#get matrix label
			my $feat = ($seq->get_SeqFeatures())[0];
			my $matrix_label = ($feat->get_tag_values('matrix_label'))[0] if $feat->has_tag('id');
			$seq_matrix_o->set_name($matrix_label);
			
			$matrices->insert($seq_matrix_o);
		}
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

1;

