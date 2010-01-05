# $Id$
#
# BioPerl module for Bio::Tools::Run::SoapEUtilities::Result
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

Bio::Tools::Run::SoapEUtilities::Result - Accessor object for SoapEUtilities results

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


package Bio::Tools::Run::SoapEUtilities::Result;
use strict;
use warnings;

use Bio::Root::Root;

use base qw(Bio::Root::Root );

our $AUTOLOAD;

# an object of accessors

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my $eutil_obj = shift;
    my $alias_hash = shift;
    $self->throw("Result constructor requires Bio::Tools::Run::SoapEUtilities ".
		 "argument") 
	unless ($eutil_obj and 
		ref($eutil_obj) eq 'Bio::Tools::Run::SoapEUtilities');
    $self->{'_util'} = $eutil_obj->_caller_util;
    my $som = $self->{'_som'} = $eutil_obj->last_result;
    return unless ( $som and ref($som) eq 'SOAP::SOM' );
    $self->{'_result_type'} = $eutil_obj->_soap_facs($eutil_obj->_caller_util)->_result_elt_name;
    $self->{'_accessors'} = [];
    my @methods = keys %{$som->method};
    my %methods;
    foreach my $m (@methods) {
	_traverse_methods($m, '', $som, \%methods, $self->{'_accessors'});
    }
    $self->_set_from_args( \%methods, 
			   -methods => $self->{'_accessors'}, 
			   -create => 1 );
    return $self;
}

=head2 util()

 Title   : util
 Usage   : 
 Function: Name of the utility producing this result object.
 Returns : scalar string
 Args    : 

=cut

sub util { shift->{'_util'} }

=head2 som()

 Title   : som
 Usage   : 
 Function: get the original SOAP::SOM object
 Returns : a SOAP::SOM object
 Args    : none

=cut

sub som { shift->{'_som'} }

sub _traverse_methods {
    my ($m, $key, $som, $hash, $acc) = @_;
    my $val = $som->valueof("//$m");
    for (ref $val) {
	/^$/ && do {
	    my @a = $som->valueof("//$m");
	    my $k = ($key ? "$key\_" : "").$m;
	    push @{$acc}, $k;
	    if (@a == 1) {
		$$hash{$k} = $a[0];
	    }
	    else {
		$$hash{$k} = \@a;
	    }
	    return;
	};
	/HASH/ && do {
	    foreach my $k (keys %$val) {
		_traverse_methods( $k, ($key ? "$key\_" : "").$m,
				   $som, $hash, $acc );
	    }
	    return;
	};
	do { #else, huh?
	    $DB::single=1;
	};
    }
}

sub AUTOLOAD {
    my $self = shift;
    return unless @{$self->{'_accessors'}};
    $DB::single=1;
    my $accessor = $AUTOLOAD;
    $accessor =~ s/.*:://;
    my @list = grep /^${accessor}_/, @{$self->{'_accessors'}};
    $self->throw("Can't locate method '$accessor' in module ".__PACKAGE__) 
	unless @list;
    my @ret;
    foreach (@list) {
	push @ret, $self->$_;
    }
    return @ret;
}
    
1;
