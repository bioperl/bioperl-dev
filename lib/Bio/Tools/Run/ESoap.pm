# $Id$
#
# BioPerl module for Bio::Tools::Run::ESoap
#
# Please direct questions and support issues to <bioperl-l@bioperl.org>
#
# Cared for by Mark A. Jensen <maj -at- fortinbras -dot- us>
#
# Copyright Mark A. Jensen
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Tools::Run::ESoap - Client for the NCBI Entrez EUtilities SOAP server

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

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

Email maj -at- fortinbras -dot- us

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

# Let the code begin...


package Bio::Tools::Run::ESoap;
use strict;
use warnings;

use lib '../../..'; # remove later
use Bio::Root::Root;
use Bio::Tools::Run::ESoap::WSDL;

use base qw(Bio::Root::Root );

=head2 new

 Title   : new
 Usage   : my $obj = new Bio::Tools::Run::ESoap();
 Function: Builds a new Bio::Tools::Run::ESoap factory
 Returns : an instance of Bio::Tools::Run::ESoap
 Args    :

=cut

sub new {
    my ($class,@args) = @_;
    
    my $self = $class->SUPER::new(@args);
    return $self;
}

1;
