# $Id: fasta.pm 15549 2009-02-21 00:48:48Z maj $
# BioPerl module for Bio::SeqIO::nexml
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Chase Miller <chmille4@gmail.com>
#
# Copyright Chase Miller
#
# You may distribute this module under the same terms as perl itself
# _history
# May, 2009  Largely written by Chase Miller

# POD documentation - main docs before the code

=head1 NAME

Bio::SeqIO::nexml - nexml sequence input/output stream

=head1 SYNOPSIS

Do not use this module directly.  Use it via the Bio::SeqIO class.

=head1 DESCRIPTION

This object can transform Bio::Seq objects to and from nexml xml files.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

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

=head1 AUTHORS - Chase Miller

Email: chmille4@gmail.com

=head1 CONTRIBUTORS

Mark Jensen, maj@fortinbras.us
Rutger Vos, rutgeraldo@gmail.com

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::SeqIO::nexml;

use strict;

use lib '../..';
use Bio::Phylo::Matrices::Datum;
use Bio::Phylo::IO qw (parse unparse);
use Bio::Seq;
use Bio::Seq::SeqFactory;
use Bio::Nexml::Util;

use base qw(Bio::SeqIO);

sub _initialize {
  my($self,@args) = @_;
  $self->SUPER::_initialize(@args);  
}

=head2 next_seq

 Title   : next_seq
 Usage   : $seq = $stream->next_seq()
 Function: returns the next sequence in the stream
 Returns : Bio::Seq object
 Args    : NONE

=cut

sub next_seq {
	my ($self) = @_;
    unless ( $self->{'_parsed'} ) {
    	#use a parse function to load all the sequence objects found in the nexml file at once
        $self->_parse;
    }
    return $self->{'_seqs'}->[ $self->{'_seqiter'}++ ];
}

#add sub rewind?

sub _parse {
	my ($self) = @_;

    $self->{'_parsed'}   = 1;
    $self->{'_seqiter'} = 0;
	
	
	#
	my $proj = parse(
 	'-file'       => $self->{'_file'},
 	'-format'     => 'nexml',
 	'-as_project' => '1'
 	);
 
 	
 		
 	$self->{'_seqs'} = Bio::Nexml::Util->_make_seq($proj);
 		
 	
 	unless(@{ $self->{'_seqs'} } == 0)
 	{
# 		self->debug("no seqs in $self->{_file}");
 	}
 }
 
 
 

=head2 write_seq

 Title   : write_seq
 Usage   : $stream->write_seq(@seq)
 Function: Writes the $seq object into the stream
 Returns : 1 for success and 0 for error
 Args    : Array of 1 or more Bio::PrimarySeqI objects

=cut

sub write_seq { #in progress
 	my ($self,$ seq, @args) = @_;
	my $type 	= $seq->alphabet || $seq->_guess_alphabet || 'dna';
   	my $dat 	= Bio::Phylo::Matrices::Datum->new( '-type' => $type);
        
	# copy seq string
    my $seqstring = $seq->seq;
    if ( $seqstring and $seqstring =~ /\S/ ) {
        eval { $dat->set_char( $seqstring ) };
        #TODO convert to Bioperl debugging
        if ( $@ and UNIVERSAL::isa($@,'Bio::Phylo::Util::Exceptions::InvalidData') ) {
        	#$logger->error(
        	#	"\nAn exception of type Bio::Phylo::Util::Exceptions::InvalidData was caught\n\n".
        	#	$@->description                                                                  .
        	#	"\n\nThe BioPerl sequence object contains invalid data ($seqstring)\n"           .
        	#	"I cannot store this string, I will continue instantiating an empty object.\n"   .
        	#	"---------------------------------- STACK ----------------------------------\n"  .
        	#	$@->trace->as_string                                                             .
        	#	"\n--------------------------------------------------------------------------"
        	#);
        }
	}                
        
	# copy name
	my $name = $seq->display_id;
	$dat->set_name( $name ) if defined $name;
                
	# copy desc
	my $desc = $seq->desc;   
	$dat->set_desc( $desc ) if defined $desc; 
	
	#get features from SeqFeatureI
	#TODO test SeqFeatures
	if (my $feat = $seq->get_SeqFeatures()) {
		
		my $start = $feat->start;
		$dat->start($start) if defined $start;
		
		my $end = $feat->end;
		$dat->end($start) if defined $end;
		
		my $strand = $feat->strand;
		$dat->strand($start) if defined $strand;
	}
		
	
	$self->_print( $dat->to_xml );
        
	return 1;
}






1;
