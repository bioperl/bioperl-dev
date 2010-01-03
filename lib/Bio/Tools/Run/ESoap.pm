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

use base qw(Bio::Root::Root Bio::ParameterBaseI);

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
    my ($util, $fetch_db, $wsdl) = $self->_rearrange( [qw( UTIL FETCH_DB WSDL_FILE )], @args );
    $self->throw("Argument -util must be specified") unless $util;
    $fetch_db ||= 'seq';
    my $url = ($util =~ /fetch/ ? 'f_'.$fetch_db : 'eutils');
    $url = $NCBI_BASEURL.$WSDL{$url};
    $self->_wsdl(Bio::Tools::Run::ESoap::WSDL->new(-url => $url));
    $self->_operation($util);
    
    return $self;
}

=head2 _wsdl()

 Title   : _wsdl
 Usage   : $obj->_wsdl($newval)
 Function: Bio::Tools::Run::ESoap::WSDL object associated with 
           this factory
 Example : 
 Returns : value of _wsdl (object)
 Args    : on set, new value (object or undef, optional)

=cut

sub _wsdl {
    my $self = shift;
    
    return $self->{'_wsdl'} = shift if @_;
    return $self->{'_wsdl'};
}

=head2 _operation()

 Title   : _operation
 Usage   : 
 Function: check and convert the requested operation based on the wsdl
 Returns : 
 Args    : operation (scalar string)

=cut

sub _operation {
    my $self = shift;
    my $util = shift;
    return $self->{'_operation'} unless $util;
    $self->throw("WSDL not yet initialized") unless $self->_wsdl;
    my $opn = $self->_wsdl->operations;
    if ( grep /^$util$/, keys %$opn ) {
	return $self->{'_operation'} = $util;
    }
    elsif ( grep /^$util$/, values %$opn ) {
	@a = grep { $$opn_hash{$_} eq $util } keys %$opn;
	return $self->{'_operation'} = $a[0];
    }
    else {
	$self->throw("Utility '$util' is not recognized");
    }
}

=head2 Bio::ParameterBaseI compliance

=cut 

sub available_parameters {
    my $self = shift;
}

sub set_parameters {
    my $self = shift;
}

sub get_parameters {
    my $self = shift;
}

sub reset_parameters {
    my $self = shift;
}
