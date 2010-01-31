# $Id$
#
# BioPerl module for Bio::Tools::WrapperMaker
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

Bio::Tools::WrapperMaker - Build BioPerl wrapper classes for external pgms

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

Discuss security issues here.

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


package Bio::Tools::WrapperMaker;
use strict;

# Object preamble - inherits from Bio::Root::Root

use Bio::Root::Root;
use XML::Twig;

use base qw(Bio::Root::Root );

# to turn off validation, have to work for it...
our $WRAPPER_VALIDATE = 1;

# config globals for export to specified namespace:
@export_symbols = 
    qw(
             $defs_version
             $version
             $program_name
             $use_dash
             $join
             @program_commands
             @program_params
             @program_switches
             %command_executables
             %command_prefixes
             %composite_commands
             %incompat_options
             %corequisite_options
             %param_translation
             %command_files
             %accepted_types
            );
our ( $defs_version,
      $version,
      $program_name,
      $use_dash,
      $join,
      @program_commands,
      %command_executables,
      %command_prefixes,
      %composite_commands,
      @program_params,
      @program_switches,
      %incompat_options,
      %corequisite_options,
      %param_translation,
      %command_files,
      %accepted_types );


=head2 new

 Title   : new
 Usage   : my $obj = new Bio::Tools::WrapperMaker();
 Function: Builds a new Bio::Tools::WrapperMaker object
 Returns : an instance of Bio::Tools::WrapperMaker
 Args    :

=cut

sub new {
    my ($class,@args) = @_;
    my $self = $class->SUPER::new(@args);
    my ($ns, $def) = $self->_rearrange( [qw(NAMESPACE DEF)], @args );
    # perl namespace to inject
    $ns && $self->namespace($ns);
    # xml defs file or xml string?
    $WRAPPER_VALIDATE && $self->validate_defs($def);

    return $self;
}


# validate_defs validates input xml against the WrapperMaker xsd

sub validate_defs {
    my $self = shift;
    my $def = shift;
    return 1;
}

# associate a Perl-compliant namespace with this wrapper:
sub namespace {
    my $self = shift;
    my $ns = shift;
    return $self->{_namespace} unless $ns;
    # check syntax
    $self->throw("Bad namespace syntax in arg ('$ns')") unless
	$ns =~ /^([a-z0-9_]+:{2})*[a-z0-9_]+/i;
    # check namespace collision someday...
    return $self->{_namespace} = $ns;
}

=head2 is_pseudo()

 Title   : is_pseudo
 Usage   : $obj->is_pseudo($newval)
 Function: flag "is pseudo-program" (commands are collection of separate 
           executables) or not (program name is executable)
 Example : 
 Returns : value of is_pseudo (a scalar)
 Args    : on set, new value (a scalar or undef, optional)

=cut

sub is_pseudo {
    my $self = shift;
    return $self->{'is_pseudo'} = shift if @_;
    return $self->{'is_pseudo'};
}


# export to the desired namespace
sub export {
    my $self = shift;
    # don't export undef variables--
    return;
}

### XML handlers = config var loaders

# going to (try to) assume that xsd validation has
# caught malformed/invalid entries...

sub program {
    my ($twig, $elt) = @_;
    $program_name = $elt->att('name');
    if ($elt->att("is-pseudo")) {
	__PACKAGE__->is_pseudo(1);
	$program_name = "*$program_name";
    }
    $use_dash = $elt->att('dash-policy');
    $join = $elt->att('join-char') || ' ';
    $version = $elt->att('prog-version');
    $elt->flush;
}

sub defs_version {
    my ($twig, $elt) = @_;
    $defs_version = $elt->text;
    $elt->flush;
}

sub perlns {
    my ($twig, $elt) = @_;
    __PACKAGE__->namespace($elt->text);
    $elt->flush;
}

sub commands {
    my ($twig, $elt) = @_;
    $elt->flush;
}

sub composite_commands {
    my ($twig, $elt) = @_;
    $elt->flush;
}

sub lookups {
    my ($twig, $elt) = @_;
    $elt->flush;
}
1;
