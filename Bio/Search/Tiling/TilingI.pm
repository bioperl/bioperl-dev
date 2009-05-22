# $Id$
#
# BioPerl module for Bio::Search::Tiling::TilingI
#
# Please direct questions and support issues to <bioperl-l@bioperl.org>
#
# Cared for by Mark A. Jensen <maj@fortinbras.us>
#
# Copyright Mark A. Jensen
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Search::Tiling::TilingI - Abstract interface for an HSP tiling module

=head1 SYNOPSIS

Not used directly.

=head1 DESCRIPTION

This module provides strong suggestions for any intended HSP tiling
object implementation. An object subclassing TilingI should override
the methods defined here according to their descriptions below.

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

=head1 AUTHOR - Mark A. Jensen

Email maj@fortinbras.us

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::Search::Tiling::TilingI;
use strict;
use warnings;

# Object preamble - inherits from Bio::Root::Root

use Bio::Root::Root;

use base qw(Bio::Root::Root);

=head2 next_tiling

 Title   : next_tiling
 Usage   : @hsps = $self->next_tiling($type);
 Function: Obtain a tiling of HSPs over the $type ('hit', 'subject',
           'query') sequence
 Example :
 Returns : an array of HSPI objects
 Args    : scalar $type: one of 'hit', 'subject', 'query', with
           'subject' an alias for 'hit'

=cut

sub next_tiling{
    my ($self,$type,@args) = @_;
    $self->throw_not_implemented;
}

=head2 rewind_tilings

 Title   : rewind_tilings
 Usage   : $self->rewind_tilings($type)
 Function: Reset the next_tilings($type) iterator
 Example :
 Returns : True on success
 Args    : scalar $type: one of 'hit', 'subject', 'query', with
           'subject' an alias for 'hit'

=cut

sub rewind_tilings{
    my ($self, $type, @args) = @_;
    $self->throw_not_implemented;
}

#alias
sub rewind { shift->rewind_tilings(@_) }

=head2 identities

 Title   : identities
 Usage   : $num_identities = $tiling->identities()
 Function: Return the estimated or exact number of identities in the
           tiling, accounting for overlapping HSPs
 Example : 
 Returns : number of identical residue pairs
 Args    :

=cut

sub identities{
    my ($self,@args) = @_;
    $self->throw_not_implemented;
}

=head2 conserved

 Title   : conserved
 Usage   : $num_conserved = $tiling->conserved()
 Function: Return the estimated or exact number of conserved sites in the 
           tiling, accounting for overlapping HSPs
 Example : 
 Returns : number of conserved residue pairs
 Args    :

=cut

sub conserved{
    my ($self,@args) = @_;
    $self->throw_not_implemented;
}

=head2 length

 Title   : length
 Usage   : $max_length = $tiling->length($type)
 Function: Return the total number of residues of the subject or query
           sequence covered by the tiling
 Example :
 Returns : 
 Args    : scalar $type, one of 'hit', 'subject', 'query'

=cut

sub length{
    my ($self, $type, @args) = @_;
    $self->throw_not_implemented;
}


#
# more desired methods here as nec
# 

1;
