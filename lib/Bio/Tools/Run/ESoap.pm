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
    $self->_init_parameters;
    
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
 Alias   : util
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
	my @a = grep { $$opn{$_} eq $util } keys %$opn;
	return $self->{'_operation'} = $a[0];
    }
    else {
	$self->throw("Utility '$util' is not recognized");
    }
}

sub util { shift->_operation(@_) }

=head2 Bio::ParameterBaseI compliance

=cut 

sub available_parameters {
    my $self = shift;
    my @args = @_;
    return @{$self->_init_parameters};
}

sub set_parameters {
    my $self = shift;
    my @args = @_;
    $self->throw("set_parameters requires named args") if @args % 2;
    my %args = @args;
    $self->_set_from_args(\%args, -methods=>$self->_init_parameters);
    $self->parameters_changed(1);
    return;
}

sub get_parameters {
    my $self = shift;
    my @ret;
    foreach (@{$self->_init_parameters}) {
	push @ret, ($_, $self->$_());
    }
    return @ret;
}

sub reset_parameters {
    my $self = shift;
    my @args = @_;
    $self->throw("reset_parameters requires named args") if @args % 2;
    my %args = @args;
    my %reset;
    @reset{@{$self->_init_parameters}} = (undef) x @{$self->_init_parameters};
    $reset{$_} = $args{$_} for keys %args;
    $self->_set_from_args( \%reset, -methods => $self->_init_parameters );
    return;
}

=head2 parameters_changed()

 Title   : parameters_changed
 Usage   : $obj->parameters_changed($newval)
 Function: flag to indicate, well, you know
 Example : 
 Returns : value of parameters_changed (a scalar)
 Args    : on set, new value (a scalar or undef, optional)

=cut

sub parameters_changed {
    my $self = shift;
    return $self->{'parameters_changed'} = shift if @_;
    return $self->{'parameters_changed'};
}

=head2 _init_parameters()

 Title   : _init_parameters
 Usage   : $fac->_init_parameters
 Function: identify the available input parameters
           using the wsdl object
 Returns : arrayref of parameter names (scalar strings)
 Args    : none

=cut

sub _init_parameters {
    my $self = shift;
    return $self->{_params} if $self->{_params};
    $self->throw("WSDL not yet initialized") unless $self->_wsdl;
    my $phash = {};
    $$phash{$_} = undef for map { keys %$_ } @{$self->_wsdl->request_parameters($self->util)};
    my $params =$self->{_params} = [sort keys %$phash];
    # create parm accessors
    $self->_set_from_args( $phash, 
			   -methods => $params,
			   -create => 1,
			   -code => 
			   'my $self = shift; 
                            $self->parameters_changed(0);
                            return $self->{\'_\'.$method} = shift if @_;
                            return $self->{\'_\'.$method};' );
    $self->parameters_changed(1);
    return $self->{_params};
}

1;
