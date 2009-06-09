# $Id:
#
# BioPerl module for Bio::AlignIO::nexml
#
# Copyright Chase Miller
#
# You may distribute this module under the same terms as perl itself
# POD documentation - main docs before the code

=head1 NAME

Bio::AlignIO::nexml - nexml sequence input/output stream

=head1 SYNOPSIS

Do not use this module directly.  Use it via the L<Bio::AlignIO> 
class.

=head1 DESCRIPTION

This object can transform L<Bio::SimpleAlign> objects to and from
nexml files.

=head1 FEEDBACK

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

=head1 AUTHORS

Chase Miller

=head1 CONTRIBUTORS

Mark Jensen, maj@fortinbras.us
Rutger Vos, rutgeraldo@gmail.com

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::AlignIO::nexml;

use strict;
use Bio::Phylo::IO qw(parse unparse);
use Bio::LocatableSeq;
use base qw(Bio::AlignIO);


=head2 next_aln

 Title   : next_aln
 Usage   : $aln = $stream->next_aln
 Function: returns the next alignment in the stream.
 Returns : Bio::Align::AlignI object - returns 0 on end of file
	        or on error
 Args    : 

See L<Bio::Align::AlignI>

=cut

sub next_aln {
	my ($self) = @_;
    unless ( $self->{'_parsed'} ) {
    	#use a parse function to load all the alignment objects found in the nexml file at once
        $self->_parse;
    }
    return $self->{'_alns'}->[ $self->{'_alnsiter'}++ ];
}

#Add sub rewind?

sub _parse {
	my ($self) = @_;

    $self->{'_parsed'}   = 1;
    $self->{'_alnsiter'} = 0;
	
	
	#
	my $proj = parse(
 	'-file'       => $self->{'_file'},
 	'-format'     => 'nexml',
 	'-as_project' => '1'
 	);

	my ($start, $end, $seq, $desc);
	my $aln = Bio::SimpleAlign->new();
	my $taxa = $proj->get_taxa();
 	my $matrices = $proj->get_matrices();
 	
 	foreach my $matrix (@$matrices) 
 	{	
 		

 		#check if mol_type is something that makes sense to be a seq
 		my $mol_type = lc($matrix->get_type());
 		unless ($mol_type eq 'dna' || $mol_type eq 'rna' || $mol_type eq 'protein')
 		{
 			next;
 		}
 		
 		my $basename = $matrix->get_name();
 		
 		my $rows = $matrix->get_entities();
 		my $seqNum = 0;
 		foreach my $row (@$rows)
 		{
 			my $newSeq = $row->get_char();
 			
 			$seqNum++;

# see comments in Bio::SeqIO::nexml regarding this choice of $seqID /maj

 			my $seqID = "$basename.row_$seqNum";

# I would allow the LocatableSeq constructor to handle setting start and end,
# you can leave attrs out -- UNLESS nexml has a slot for these coordinates;
# I would dig around for this. /maj

 			$seq = Bio::LocatableSeq->new(
						  -seq         => $newSeq,
						  -display_id  => "$seqID",
						  -description => $desc,
						  -start       => $start,   #this is currently undefined, not sure if it needs to be mapped or not
						  -end         => $end,     #same as above
						  -alphabet	   => $mol_type,
						  );
			#what other data is appropriate to pull over from bio::phylo::matrices::matrix??
		    $aln->add_seq($seq);
		    $self->debug("Reading r$seqID\n");
 		
 			
 		}
 		push @{ $self->{'_alns'} }, $aln;
 	}
 	if(@{ $self->{'_alns'} } == 0)
 	{
 		self->debug("no seqs in $self->{_file}");
 	}
}

=head2 write_aln

 Title   : write_aln
 Usage   : $stream->write_aln(@aln)
 Function: writes the $aln object into the stream in nexml format
 Returns : 1 for success and 0 for error
 Args    : L<Bio::Align::AlignI> object

See L<Bio::Align::AlignI>

=cut

sub write_aln {
    # not implemented yet
}







1;
