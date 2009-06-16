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

use base qw(Bio::Root::Root);

sub new {
 	my($class,@args) = @_;
 	my $self = $class->SUPER::new(@args);

	my %params = @args;
	
	$self->{'_seqIO'}  = Bio::SeqIO::nexml->new(@args);
 	$self->{'_alnIO'}  = Bio::AlignIO::nexml->new(@args);
 	$self->{'_treeIO'} = Bio::TreeIO::nexml->new(@args);
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

sub next_tree {
	my $self = shift;
	return $self->treeIO->next_tree();
}

sub next_seq {
	my $self = shift;
	return $self->seqIO->next_seq();
}

sub next_aln {
	my $self = shift;
	return $self->alnIO->next_aln();
}

1;