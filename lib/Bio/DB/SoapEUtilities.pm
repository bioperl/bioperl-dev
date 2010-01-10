# $Id$
#
# BioPerl module for Bio::DB::SoapEUtilities
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

Bio::DB::SoapEUtilities - Interface to NCBI Entrez web service

=head1 SYNOPSIS

 # factory construction

 # executing a utility call

 # parsing the results

 # iterating over result objects

=head1 DESCRIPTION

This module allows the user to query the NCBI Entrez database via its
SOAP (Simple Object Access Protocol) web service (described at
L<http://eutils.ncbi.nlm.nih.gov/entrez/eutils/soap/v2.0/DOC/esoap_help.html>).
The basic tools (C<einfo, esearch, elink, efetch, espell, epost>) are
available as methods off a C<SoapEUtilities> factory
object. Parameters for each tool can be queried, set and reset for
each method through the L<Bio::ParameterBaseI> standard calls
(C<available_parameters(), set_parameters(), get_parameters(),
reset_parameters()>). Returned data can be retrieved, accessed and
parsed in several ways, according to user preference. Adaptors and
object iterators are availabe for C<efetch>, C<elink>, and C<esummary>
results.

=head1 USAGE

=over

=item C<efetch>, Fetch Adaptors, and BioPerl object iterators

=item C<elink>, the Link adaptor, and the C<linkset> iterator

=item C<esummary>, the DocSum adaptor, and the C<docsum> iterator

=back

=head1 SEE ALSO

L<Bio::DB::EUtilities>, L<Bio::DB::SoapEUtilities::Result>,
L<Bio::DB::ESoap>.

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

package Bio::DB::SoapEUtilities;
use strict;

use lib '../..'; # remove later
use Bio::Root::Root;
use Bio::DB::ESoap;
use Bio::DB::SoapEUtilities::DocSumAdaptor;
use Bio::DB::SoapEUtilities::FetchAdaptor;
use Bio::DB::SoapEUtilities::LinkAdaptor;
use Bio::DB::SoapEUtilities::Result;

use base qw(Bio::Root::Root Bio::ParameterBaseI );

our $AUTOLOAD;

=head2 new

 Title   : new
 Usage   : my $eutil = new Bio::DB::SoapEUtilities();
 Function: Builds a new Bio::DB::SoapEUtilities object
 Returns : an instance of Bio::DB::SoapEUtilities
 Args    :

=cut

sub new {
    my ($class,@args) = @_;
    my $self = $class->SUPER::new(@args);
    my ($db) = $self->_rearrange( [qw( DB )], @args );
    $self->{db} = $db;

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
           -auto_adapt => boolean ( return an iterator over results as 
                                    appropriate to util if true)
           -raw_xml => boolean ( return raw xml result; no processing )
           Bio::DB::SoapEUtilities::Result constructor parms

=cut

sub run {
    my $self = shift;
    my @args = @_;
    $self->throw("run method requires named arguments") if @args % 2;
    $self->throw("call run method like '\$fac->\$eutility->run(\@args)") unless
	$self->_caller_util;
    my ($autofetch, $raw_xml) = $self->_rearrange( [qw( ADAPTOR RAW_XML)],
						   @args );
    my ($adaptor);
    my %args = @args;
    # add tool argument for NCBI records
    $args{tool} = "SoapEUtilities(BioPerl)";
    my $util = $self->_caller_util;
    $self->set_parameters(%args) if %args;
    # kludge for elink : make sure to-ids and from-ids are associated
    if ( $util eq 'elink' ) {
	my $es = $self->_soap_facs($util);
	my $ids = $es->id;
	if (ref $ids eq 'ARRAY') {
	    my %ids;
	    @ids{@$ids} = (1) x scalar @$ids;
	    $es->id(\%ids);
	}
    }
    $self->_soap_facs($util)->_client->outputxml($raw_xml);
    my $som = $self->{'_response_message'} = $self->_soap_facs($util)->run;
    # raw xml only...
    if ($raw_xml) {
	return $som; 
    }
    # SOAP::SOM parsing...
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
    # attach some key properties to the factory
    $self->{'_WebEnv'} = $som->valueof("//WebEnv");
    my $result = Bio::DB::SoapEUtilities::Result->new($self, @args);

    # success, parse it out
    if ($autofetch) {
	for ($self->_caller_util) {
	    $_ eq 'esearch' && do {
		# do an efetch with the same db and a returned list of ids...
		# reentering here!
		$DB::single =1;
		my $ids = $result->ids;
		if (!$result->count) {
		    $self->warn("Can't fetch; no records returned");
		    return $result;
		}
		if (!$result->ids) {
		    $self->warn("Can't fetch; no id list returned");
		    return $result;
		}
		if ( !$self->db ) {
		    my %h = $self->get_parameters;
		    $self->{db} = $h{db} || $h{DB};
		}
		my $fetched = $self->efetch( -db => $self->db,
					     -id => $ids )->run(-no_parse => 1, @args);
		$adaptor = Bio::DB::SoapEUtilities::FetchAdaptor->new(
		    -result => $fetched
		    );
		last
	    };
	    $_ eq 'elink' && do {
		$adaptor = Bio::DB::SoapEUtilities::LinkAdaptor->new(
		    -result => $result
		    );
		last;
	    };
	    $_ eq 'esummary' && do {
		$adaptor = Bio::DB::SoapEUtilities::DocSumAdaptor->new(
		    -result => $result
		    );
		last;
	    };
	    # else, ignore
	}
	return $adaptor || $result;
    }
    else {
	return $result;
	1;
    }
}

=head2 Useful Accessors

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

=head2 webenv()

 Title   : webenv
 Usage   : 
 Function: contains WebEnv key referencing the session
           (set after run() )
 Returns : scalar
 Args    : none

=cut

sub webenv { shift->{'_WebEnv'} }

=head2 errstr()

 Title   : errstr
 Usage   : $fac->errstr
 Function: get the last error, if any
 Example : 
 Returns : value of errstr (a scalar)
 Args    : none

=cut

sub errstr { shift->{'errstr'} }

=head2 Bio::ParameterBaseI compliance

=head2 available_parameters()

 Title   : available_parameters
 Usage   : 
 Function: get available request parameters for calling
           utility
 Returns : 
 Args    : -util => $desired_utility [optional, default is
           caller utility]

=cut

sub available_parameters {
    my $self = shift;
    my @args = @_;
    my %args = @args;
    my $util = $args{'-util'} || $args{'-UTIL'} || $self->_caller_util;
    return unless $self->_soap_facs($util);
    delete $args{'-util'};
    delete $args{'-UTIL'};
    $self->_soap_facs($util)->available_parameters(%args);
}

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
    my @args = @_;
    my %args = @args;
    my $util = $args{'-util'} || $args{'-UTIL'} || $self->_caller_util;
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
    my @args = @_;
    my %args = @args;
    my $util = $args{'-util'} || $args{'-UTIL'} || $self->_caller_util;
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

    if ( $util =~ /^e/ ) { # this will bite me someday
	# create an ESoap factory for this utility
	my $fac = $self->_soap_facs($util); # check cache
	eval {
	    $fac ||= Bio::DB::ESoap->new( -util => $util );
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
    }
    elsif ($self->_caller_util) {
	# delegate to the appropriate soap factory
	my $method = $util;
	$util = $self->_caller_util;
	my $soapfac = $self->_soap_facs($util);
	if ( $soapfac && $soapfac->can($method) ) {
	    return $soapfac->$method(@args);
	}
    }
    else {
	$self->throw("Can't locate method '$util' in module ".
		     __PACKAGE__);
    }
    1;
}

=head2 _soap_facs()

 Title   : _soap_facs
 Usage   : $self->_soap_facs($util, $fac)
 Function: caches Bio::DB::ESoap factories for the 
           eutils in use by this instance
 Example : 
 Returns : Bio::DB::ESoap object
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
1;

