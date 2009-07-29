# $Id$
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
# may want to call these directly off the class below, for ease of 
# reading later - /maj
use Bio::Phylo::IO qw (parse unparse);
use Bio::Seq;
use Bio::Seq::SeqFactory;
use Bio::Nexml::Factory;

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

sub benchmark_test {
	my $seq = next_seq(@_);
	my $self = shift;
	$self->{'_parsed'} = 0;
	return $seq;
}

sub _parse {
	my ($self) = @_;
	my $fac = Bio::Nexml::Factory->new();
	
    $self->{'_parsed'}   = 1;
    $self->{'_seqiter'} = 0;
	
	# i.e., my $proj = Bio::Phylo::IO->parse(...); /maj
	
	my $proj = parse(
 	'-file'       => $self->{'_file'},
 	'-format'     => 'nexml',
 	'-as_project' => '1'
 	);
 
 	
 		
 	$self->{'_seqs'} = $fac->create_bperl_seq($proj);
 		
 	
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

sub write_seq {
	
	my $self = shift(@_);
	my ($matrix, $taxa) = Bio::Nexml::Util->create_bphylo_seq(@_);
	$matrix->set_taxa($taxa);
	
	my $nexml_doc = Bio::Phylo::Factory->create_project();
	
	$nexml_doc->insert($matrix);
	
	$self->_print($nexml_doc->to_xml());
}


1;
