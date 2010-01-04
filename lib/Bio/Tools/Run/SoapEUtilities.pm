# $Id$
#
# BioPerl module for Bio::Tools::Run::SoapEUtilities
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

Bio::Tools::Run::SoapEUtilities - Interface to NCBI Entrez web service

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

Describe contact details here

=head1 CONTRIBUTORS

Additional contributors names and emails here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::Tools::Run::SoapEUtilities;
use strict;

use lib '../../..'; # remove later
use Bio::Root::Root;
use Bio::Tools::Run::ESoap;
use Bio::Tools::Run::ESoap::FetchAdaptor;

use base qw(Bio::Root::Root Bio::ParameterBaseI );

our $AUTOLOAD;

=head2 new

 Title   : new
 Usage   : my $eutil = new Bio::Tools::Run::SoapEUtilities();
 Function: Builds a new Bio::Tools::Run::SoapEUtilities object
 Returns : an instance of Bio::Tools::Run::SoapEUtilities
 Args    :

=cut

sub new {
    my ($class,@args) = @_;
    my $self = $class->SUPER::new(@args);


    return $self;
}

=head2 run()

 Title   : run
 Usage   : $fac->$eutility->run(@args)
 Function: Execute the EUtility
 Returns : true on success, false on fault or error
           (reason in errstr(), for more detail check the SOAP message
            in last_result() )
 Args    : named params appropriate to utility
           -autofetch => boolean ( run efetch appropriate to util )

=cut

sub run {
    my $self = shift;
    my @args = @_;
    $self->throw("run method requires named arguments") if @args % 2;
    $self->throw("call run method like '\$fac->\$eutility->run(\@args)") unless
	$self->_caller_util;
    my %args = @args;
    my $autofetch ||= $args{'-autofetch'} || $args{'-AUTOFETCH'};
    delete $args{'-autofetch'};
    delete $args{'-AUTOFETCH'};
    my $util = $self->_caller_util;
    $self->set_parameters(%args) if %args;
    
    my $som = $self->{'_response_message'} = $self->_soap_facs($util)->_run;
    # check response status
    if ($som->fault) {
	$self->{'errstr'} = $som->faultstring;
	return 0;
    }
    # elsif non-fault error
    if (my $err = $som->valueof("//ErrorList")) {
	while ( my ($key, $val) = each %$err ) {
	    $self->{'errstr'} .= join( " : ", $key, $val )."\n";
	};
	$self->{'errstr'} =~ s/\n$//;
	return 0;
    }
    # success, parse it out
    if ($autofetch) {
	# do an efetch with the same db and a returned list of ids...
    }
    
    
}

=head2 Bio::ParameterBaseI compliance

=head2 set_parameters()

 Title   : set_parameters
 Usage   : 
 Function: 
 Returns : none
 Args    : -util => $desired_utility [optional, default is 
            caller utility],
           named utility arguments

=cut

sub set_parameters {
    my $self = shift;
    my @args = @_;
    my %args = @args;
    my $util = $args{'-util'} || $args{'-UTIL'} || $self->_caller_util;
    return unless $self->_soap_facs($util);
    delete $args{'-util'};
    delete $args{'-UTIL'};
    $self->_soap_facs($util)->set_parameters(%args);
}

=head2 get_parameters()

 Title   : get_parameters
 Usage   : 
 Function: 
 Returns : array of named parameters
 Args    : utility (scalar string) [optional]
           (default is caller utility)

=cut

sub get_parameters {
    my $self = shift;
    my $util = shift;
    $util ||= $self->_caller_util;
    return unless $self->_soap_facs($util);
    return $self->_soap_facs($util)->get_parameters;
}

=head2 reset_parameters()

 Title   : reset_parameters
 Usage   : 
 Function: 
 Returns : none
 Args    : -util => $desired_utility [optional, default is 
            caller utility],
           named utility arguments

=cut

sub reset_parameters {
    my $self = shift;
    my @args = @_;
    my %args = @args;
    my $util = $args{'-util'} || $args{'-UTIL'} || $self->_caller_util;
    return unless $self->_soap_facs($util);
    delete $args{'-util'};
    delete $args{'-UTIL'};
    $self->_soap_facs($util)->reset_parameters(%args);
}

=head2 parameters_changed()

 Title   : parameters_changed
 Usage   : 
 Function: 
 Returns : boolean
 Args    : utility (scalar string) [optional]
           (default is caller utility)

=cut

sub parameters_changed {
    my $self = shift;
    my $util = shift;
    $util ||= $self->_caller_util;
    return unless $self->_soap_facs($util);
    return $self->_soap_facs($util)->parameters_changed;
}


# idea behind using autoload: attempt to buffer the module
# against additions of new eutilities, and (of course) to 
# reduce work (laziness, not Laziness)

sub AUTOLOAD {
    my $self = shift;
    my $util = $AUTOLOAD;
    my @args = @_;
    $util =~ s/.*:://;
    unless ( $util =~ /^e/ ) {
	$self->throw("Can't locate method '$util' in module __PACKAGE__");
    }
    # create an ESoap factory for this utility
    my $fac = $self->_soap_facs($util); # check cache
    eval {
        $fac ||= Bio::Tools::Run::ESoap->new( -util => $util );
    };
    for ($@) {
	/^$/ && do {
	    $self->_soap_facs($util,$fac); # put in cache
	    last;
	};
	/Utility .* not recognized/ && do {
	    my $err = (ref $@ ? $@->text : $@);
	    $self->throw($err);
	};
	do { #else 
	    my $err = (ref $@ ? $@->text : $@);
	    die $err;
	    $self->throw("Problem creating ESoap client : $err");
	};
    }
    # arg setting 
    $self->throw("Named arguments required") if @args % 2;
    $fac->set_parameters(@args) if @args;
    $self->_caller_util($util);
    return $self; # now, can do $obj->esearch()->run, etc, with methods in 
                  # this package, with an appropriate low-level factory 
                  # set up in the background.
    1;
}


=head2 _soap_facs()

 Title   : _soap_facs
 Usage   : $self->_soap_facs($util, $fac)
 Function: caches Bio::Tools::Run::ESoap factories for the 
           eutils in use by this instance
 Example : 
 Returns : Bio::Tools::Run::ESoap object
 Args    : $eutility, [optional on set] $esoap_factory_object

=cut

sub _soap_facs {
    my $self = shift;
    my ($util, $fac) = @_;
    $self->throw("Utility must be specified") unless $util;
    $self->{'_soap_facs'} ||= {};
    if ($fac) {
	return $self->{'_soap_facs'}->{$util} = $fac;
    }
    return $self->{'_soap_facs'}->{$util};
}

=head2 _caller_util()

 Title   : _caller_util
 Usage   : $self->_caller_util($newval)
 Function: the utility requested off the main SoapEUtilities 
           object
 Example : 
 Returns : value of _caller_util (a scalar string, a valid eutility)
 Args    : on set, new value (a scalar string [optional])

=cut

sub _caller_util {
    my $self = shift;
    return $self->{'_caller_util'} = shift if @_;
    return $self->{'_caller_util'};
}

=head2 response_message()

 Title   : response_message
 Aliases : last_response, last_result
 Usage   : $som = $fac->response_message
 Function: get the last response message
 Returns : a SOAP::SOM object
 Args    : none

=cut

sub response_message { shift->{'_response_message'} }
sub last_response { shift->{'_response_message'} }
sub last_result { shift->{'_response_message'} }

=head2 errstr()

 Title   : errstr
 Usage   : $fac->errstr
 Function: get the last error, if any
 Example : 
 Returns : value of errstr (a scalar)
 Args    : none

=cut

sub errstr { shift->{'errstr'} }

1;
