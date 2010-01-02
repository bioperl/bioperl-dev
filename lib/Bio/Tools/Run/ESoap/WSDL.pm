# $Id$
#
# BioPerl module for Bio::Tools::Run::ESoap::WSDL
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

Bio::Tools::Run::ESoap::WSDL - WSDL parsing for Entrez SOAP EUtilities

=head1 SYNOPSIS

Used by L<Bio::Tools::Run::ESoap>

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

# Let the code begin...


package Bio::Tools::Run::ESoap::WSDL;
use strict;

# Object preamble - inherits from Bio::Root::Root

use Bio::Root::Root;
use XML::Twig;
use LWP::Simple;

use base qw(Bio::Root::Root );

=head2 new

 Title   : new
 Usage   : my $obj = new Bio::Tools::Run::ESoap::WSDL();
 Function: Builds a new Bio::Tools::Run::ESoap::WSDL object
 Returns : an instance of Bio::Tools::Run::ESoap::WSDL
 Args    : named args:
           -URL => $url_of_desired_wsdl -OR-
           -WSDL => $filename_of_local_wsdl_copy
           ( -URL will take precedence if both specified )

=cut

sub new {
    my ($class,@args) = @_;
    my $self = $class->SUPER::new(@args);
    my ($url, $wsdl) = $self->_rearrange( [qw( URL WSDL )], @args );
    my (%sections, %cache);
    my $doc = 'wsdl:definitions';
    $sections{'_message_elts'} = [];
    $sections{'_operation_elts'} = [];
    $self->_sections(\%sections);
    $self->_cache(\%cache);
    $self->_twig(
	XML::Twig->new(
	    twig_handlers => {
		$doc => sub { $self->root($_) },
		"$doc/binding" => sub { $self->_sections->{'_binding_elt'} = $_ },
		"$doc/binding/operation" => sub { push @{$self->_sections->{'_operation_elts'}},$_ },
		"$doc/message" => sub { push @{$self->_sections->{'_message_elts'}}, $_ },
		"$doc/portType" => sub { $self->_sections->{'_portType_elt'} = $_ },
		"$doc/service" => sub { $self->_sections->{'_service_elt'} = $_ },
		"$doc/types" => sub { $self->_sections->{'_types_elt'} = $_ },
	    }
	)
	);
    if ($url || $wsdl ) {
	$self->url($url);
	$self->wsdl($wsdl);
	$self->_parse;
    }
    return $self;
}

=head1 Getters



=head2 request_parameters()

 Title   : request_parameters
 Usage   : @params = $wsdl->request_parameters($operation_name)
 Function: get array of request (input) fields required by 
           specified operation, according to the WSDL
 Returns : array of scalar strings
 Args    : scalar string (operation or action name)

=cut

sub request_parameters {
    my $self = shift;
    my ($operation) = @_;
    my $is_action;
    $self->throw("Operation name must be specified") unless defined $operation;
    my $opn_hash = $self->operations;
    unless ( grep /^$operation$/, keys %$opn_hash ) {
	$is_action = grep /^$operation$/, values %$opn_hash;
	$self->throw("Operation name '$operation' is not recognized")
	    unless ($is_action);
    }
    
    #check the cache here....
    return $self->_cache("request_params_$operation") if
	$self->_cache("request_params_$operation");

    # find the input message type in the portType elt
    if ($is_action) { 
	my @a = grep {$$opn_hash{$_} eq $operation} keys %$opn_hash;
	# note this takes the first match
	$operation = $a[0];
	$self->throw("Whaaa??") unless defined $operation;
    }
    #check the cache once more after translation....
    return $self->_cache("request_params_$operation") if
	$self->_cache("request_params_$operation");

    my $pT_opn = $self->_portType_elt->first_child( 
	qq/ operation[\@name="$operation"] /
	);
    my $imsg_type = $pT_opn->first_child('input')->att('message');

    # now lookup the schema element name from among the message elts
    my $imsg_elt;
    foreach ( @{$self->_message_elts} ) {
	my $msg_name = $_->att('name');
	if ( $imsg_type =~ qr/$msg_name/ ) {
	    $imsg_elt = $_->first_child('part[@name="request"]')->att('element');
	    last;
	}
    }
    $self->throw("Can't find request schema element corresponding to '$operation'") unless $imsg_elt;

    # $imsg_elt has a namespace prefix, to lead us to the correct schema
    # as defined in the wsdl <types> element. Get that schema
    $imsg_elt =~ /(.*?):/;
    my $opn_ns = $self->root->namespace($1);
    my $opn_schema = $self->_types_elt->first_child("xs:schema[\@targetNamespace='$opn_ns']");
    $self->throw("Can't find types schema corresponding to '$operation'") unless defined $opn_schema;

    # find the definition of $imsg_elt in $opn_schema
    $imsg_elt =~ s/.*?://;
    $imsg_elt = $opn_schema->first_child("xs:element[\@name='$imsg_elt']");
    $self->throw("Can't find request element definition in schema corresponding to '$operation'") unless defined $imsg_elt;
        
    # the EUtilities schemata are fairly simple; each element corr. to 
    # an input field name are defined as a simple xs:string; the 
    # request types are a xs:seq of these xs:strings
    # this parsing will assume this structure, and so it could 
    # break if the request schemata become more complicated...

    my @request_params = map 
    { 
	my $r = $_->att('ref');
	$r =~ s/.*?://;
	$r 
    } ($imsg_elt->descendants('xs:sequence'))[0]->descendants('xs:element');
    return $self->_cache("request_params_$operation", \@request_params);
    1;
}

=head2 operations()

 Title   : operations
 Usage   : @opns = $wsdl->operations;
 Function: get a hashref with elts ( $operation_name => $soapAction )
           for all operations defined by this WSDL 
 Returns : array of scalar strings
 Args    : none

=cut

sub operations {
    my $self = shift;
    return $self->_cache('operations') if $self->_cache('operations');
    my %opns;
    foreach (@{$self->_parse->_operation_elts}) {
	$opns{$_->att('name')} = 
	    ($_->descendants('soap:operation'))[0]->att('soapAction');
    }
    return $self->_cache('operations', \%opns);
}

=head2 service()

 Title   : service
 Usage   : $wsdl->service
 Function: gets the SOAP service url associated with this WSDL
 Returns : scalar string
 Args    : none

=cut

sub service {
    my $self = shift;
    return $self->_cache('service') || 
	$self->_cache('service', ($self->_parse->_service_elt->descendants('soap:address'))[0]->att('location'));
}

=head2 _parse()

 Title   : _parse
 Usage   : $wsdl->_parse
 Function: parse the wsdl at url and create accessors for 
           section twig elts
 Returns : self
 Args    : 

=cut

sub _parse {
    my $self = shift;
    my @args = @_;
    return $self if $self->_parsed; # already done
    $self->throw("Neither URL nor WSDL set in object") unless $self->url || $self->wsdl;
    eval {
	if ($self->url) {
	    $self->_twig->parse(LWP::Simple::get($self->url));
	}
	else {
	    $self->_twig->parsefile($self->wsdl);
	}
    };
#    $self->throw("Parser issue : $@") if $@;
    die $@ if $@;
    $self->_set_from_args( $self->_sections, 
			  -methods => [qw(_types_elt _message_elts 
                                          _portType_elt _binding_elt
                                          _operation_elts _service_elt)],
			  -create => 1 );
    $self->_parsed(1);
    return $self;
}

=head2 root()

 Title   : root
 Usage   : $obj->root($newval)
 Function: holds the root Twig elt of the parsed WSDL
 Example : 
 Returns : value of root (an XML::Twig::Elt)
 Args    : on set, new value (an XML::Twig::Elt or undef, optional)

=cut

sub root {
    my $self = shift;
    
    return $self->{'root'} = shift if @_;
    return $self->{'root'};
}

=head2 url()

 Title   : url
 Usage   : $obj->url($newval)
 Function: get/set the WSDL url
 Example : 
 Returns : value of url (a scalar string)
 Args    : on set, new value (a scalar or undef, optional)

=cut

sub url {
    my $self = shift;
    
    return $self->{'url'} = shift if @_;
    return $self->{'url'};
}

=head2 wsdl()

 Title   : wsdl
 Usage   : $obj->wsdl($newval)
 Function: get/set wsdl XML filename
 Example : 
 Returns : value of wsdl (a scalar string)
 Args    : on set, new value (a scalar string or undef, optional)

=cut

sub wsdl {
    my $self = shift;
    if (@_) {
	$self->throw("File not found") unless -e $_[0];
	return $self->{'wsdl'} = shift;
    }
    return $self->{'wsdl'};
}

=head2 _twig()

 Title   : _twig
 Usage   : $obj->_twig($newval)
 Function: XML::Twig object for handling the wsdl
 Example : 
 Returns : value of _twig (a scalar)
 Args    : on set, new value (a scalar or undef, optional)

=cut

sub _twig {
    my $self = shift;
    
    return $self->{'_twig'} = shift if @_;
    return $self->{'_twig'};
}

=head2 _sections()

 Title   : _sections
 Usage   : $obj->_sections($newval)
 Function: holds hashref of twigs corresponding to main wsdl 
           elements; filled by _parse()
 Example : 
 Returns : value of _sections (a scalar)
 Args    : on set, new value (a scalar or undef, optional)

=cut

sub _sections {
    my $self = shift;
    
    return $self->{'_sections'} = shift if @_;
    return $self->{'_sections'};
}

=head2 _cache()

 Title   : _cache
 Usage   : $wsdl->_cache($newval)
 Function: holds the wsdl info cache
 Example : 
 Returns : value of _cache (a scalar)
 Args    : on set, new value (a scalar or undef, optional)

=cut

sub _cache {
    my $self = shift;
    my ($name, $value) = @_;
    unless (@_) {
	return $self->{'_cache'} = {};
    }
    if (defined $value) {
	return $self->{'_cache'}->{$name} = $value;
    }
    return $self->{'_cache'}->{$name};
}

sub clear_cache { shift->_cache() }


=head2 _parsed()

 Title   : _parsed
 Usage   : $obj->_parsed($newval)
 Function: flag to indicate wsdl already parsed
 Example : 
 Returns : value of _parsed (a scalar)
 Args    : on set, new value (a scalar or undef, optional)

=cut

sub _parsed {
    my $self = shift;
    
    return $self->{'_parsed'} = shift if @_;
    return $self->{'_parsed'};
}


1;
