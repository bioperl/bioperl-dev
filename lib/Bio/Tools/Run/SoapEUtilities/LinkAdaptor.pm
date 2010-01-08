# $Id$
#
# BioPerl module for Bio::Tools::Run::SoapEUtilities::LinkAdaptor
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

Bio::Tools::Run::SoapEUtilities::LinkAdaptor - Iterator for Entrez SOAP LinkSets

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


package Bio::Tools::Run::SoapEUtilities::LinkAdaptor;
use strict;
use warnings;

# Object preamble - inherits from Bio::Root::Root

use Bio::Root::Root;

use base qw(Bio::Root::Root );

=head2 new

 Title   : new
 Usage   : my $obj = new Bio::Tools::Run::SoapEUtilities::LinkAdaptor();
 Function: Builds a new Bio::Tools::Run::SoapEUtilities::LinkAdaptor object
 Returns : an instance of Bio::Tools::Run::SoapEUtilities::LinkAdaptor
 Args    :

=cut

sub new {
    my ($class,@args) = @_;
    my $self = $class->SUPER::new(@args);
    my ($result) = $self->_rearrange([qw(RESULT)], @args);
    $self->throw("LinkAdaptor requires a SoapEUtilities::Result argument")
	unless $result;
    $self->throw("LinkAdaptor only works with elink results") unless
	$result->util eq 'elink';
    $self->{'_result'} = $result;
    $self->{'_idx'} = 1;
    return $self;
}

sub result { shift->{'_result'} }

=head2 next_linkset()

 Title   : next_linkset
 Usage   : 
 Function: return the next LinkSet from the attached Result
 Returns : 
 Args    : 

=cut

sub next_linkset {
    my $self = shift;
    my $stem = "//Body/".$self->result->result_type."/[".$self->{'_idx'}."]";
    return unless $self->result->som and $self->result->som->valueof($stem);
    my $ret;
    my $get = sub { $self->result->som->valueof("$stem/".shift) };
    my %params;
    
    $params{'-db_from'} = $get->('DbFrom');
    $params{'-db_to'} = $get->('LinkSetDb/DbTo');
    $params{'-link_name'} = $get->('LinkSetDb/LinkName');
    $params{'-submitted_ids'} = [$get->('IdList/*')];
    $params{'-ids'} = [$get->('LinkSetDb/Link/*')];
    my $class = ref($self)."::linkset";
    $ret = $class->new(%params);
    ($self->{'_idx'})++;
    return $ret;
}

sub rewind { shift->{'_idx'} = 1; };

package Bio::Tools::Run::SoapEUtilities::LinkAdaptor::linkset;
use strict;
use warnings;

use base qw(Bio::Root::Root);

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    my %args = @args;
    $self->_set_from_args( \%args,
			   -methods => [map { /^-?(.*)/ } keys %args],
			   -create => 1,
			   -code =>
			   'my $self = shift; 
                            my $d = shift;
                            my $k = \'_\'.$method;
                            $self->{$k} = $d if $d;
                            return (ref $self->{$k} eq \'ARRAY\') ?
                                   @{$self->{$k}} : $self->{$k};'

	);
    return $self;
}

1;
