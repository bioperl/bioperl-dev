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

our $HAVE_LIBXML = eval "require XML::LibXML; 1";
# to turn off validation, have to work for it...
our $VALIDATE_DEFS = 1;
our $SCHEMA_URL = "http://fortinbras.us/wrappermaker/1.0/maker.xsd";

# config globals for export to specified namespace:
my @export_symbols = 
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

our %lookups; # container for arbitrary lookup tables

#create the run factory and deliver : class or instance method
# main user access; validation and parse happens here...

sub compile { 
    my $class = shift;
    my @args = @_;
    my $self = ref $class ? $class : $class->new(@args);
    if ( $self->_defs !~ /<[^>]+>/ ) { # else, is xml string
	unless (ref $self->_defs) { # is a filename
	    open my $fh, "<", $self->_defs;
	    $self->{_defs} = $fh;
	}
	# otherwise, assume a(n open) filehandle...
    }
    $self->_twig->parse($self->_defs);
    $self->_export_globals; # get the globals (now loaded) into the 
                            # desired namespace
    return; # $an_instance_of_the_desired_namespace;
}

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
    my ($ns, $defs, $xsd) = $self->_rearrange( [qw(NAMESPACE DEFS XSD)], @args );
    # perl namespace to inject
    if ($ns) {
	unless ($ns =~ /^([a-z0-9_]+::)*[a-z0-9_]+$/i) {
	    $self->throw( "Invalid Perl namespace '$ns' specified" );
	}
	$self->namespace($ns);
    }
    unless ($defs) {
	$self->throw( "Definitions arg DEFS is required" );
    }
    $self->{_defs} = $defs;
    $self->validate_defs($xsd);
    
    # generate the twig that will parse the xml 
    # (but parse in compile() )
    $self->{_twig} = XML::Twig->new( twig_handlers =>
				     { 'program' => \&program,
				       'defs-version' => \&defs_version,
				       'perl-namespace' => \&perlns,
				       'commands' => \&commands,
				       'composite-commands' => \&composite_commands,
				       'lookups' => \&lookups } );
					   
    return $self;
}

# validate_defs validates input xml against the WrapperMaker xsd

sub validate_defs {
    my $self = shift;
    my $schema_file = shift;
    my $defs = $self->_defs;
    unless ($HAVE_LIBXML) {
	$self->warn("XML::LibXML not present; can't validate. Beware!");
	return 1;
    }
    unless ($VALIDATE_DEFS) {
	$self->warn("Validation turned off; won't validate. Beware!");
	return 1;
    }
    my @args = ( ($defs =~ /<[^>]+>/) ? 
		 ( string => $defs ) :
		 ( location => $defs ) );
    my $doc = XML::LibXML->new->load_xml(@args);
    my $schema = XML::LibXML::Schema->new( location => $schema_file ||
					   $SCHEMA_URL );
    unless ($schema) {
	$self->throw("Schema unavailable; can't validate");
    }
    eval {
	$schema->validate( $doc );
    };
    if ($@) {
	$self->throw( "Defs not valid against schema : $@ " );
    }
    return 1;
}

# do the export; should be fun
sub _export_globals {
    my $self = shift;
    no strict qw(refs);
    no strict qw(subs); ###
    my $ns = $self->namespace;
    $ns ||= "MyWrapper";
    foreach (@export_symbols) {
	# export only if symbol defined...
	if ( defined(eval) ) {
	    /(.)(.*)/;
	    my $sigil = $1;
	    my $token = $2;
	    eval "$sigil$ns\::$token = $_";
	}
    }
    return;
}

### properties/accessors

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

# twig accessor
sub _twig {shift->{_twig}}

# defs accessor
sub _defs {shift->{_defs}}

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
}

sub defs_version {
    my ($twig, $elt) = @_;
    $defs_version = $elt->text;
}

sub perlns {
    my ($twig, $elt) = @_;
    __PACKAGE__->namespace($elt->text) unless __PACKAGE__->namespace;
}

sub commands {
    my ($twig, $elt) = @_;
    foreach my $cmd ($elt->children) {
	# looping over commandType elements
	push @program_commands, $cmd->att('name');
	$command_prefixes{$cmd->att('name')} = $cmd->att('prefix') 
	    if $cmd->att('prefix');
	# handle options
	my $opts = $cmd->first_child('options');
	if ($opts) {
	    foreach my $opt ($opts->children) {
		# looping over option specs
		handle_option($opt);
	    }
	}
	# handle filespecs
	my $fspecs = $cmd->first_child('filespecs');
	if ($fspecs) {
	    my $ar = [];
	    $command_files{$cmd->att('name')} = $ar;
	    foreach my $spc ($fspecs->children) {
		handle_filespec($spc, $ar);
	    }
	}
    }
}

sub composite_commands {
    my ($twig, $elt) = @_;
    foreach my $cmd ($elt->children) {
	my @subcmds;
	foreach my $subcmd ($cmd->children) {
	    push @subcmds, $cmd->att('name');
	}
	$composite_commands{$cmd->att('name')} = \@subcmds;
    }
}

sub lookups {
    my ($twig, $elt) = @_;
    foreach my $lkup ($elt->children) {
	my %tbl;
	foreach my $pr ($lkup->children) {
	    $tbl{$pr->att('key')} = $pr->att('value');
	}
	$lookups{$lkup->att('name')} = \%tbl;
    }
}

sub handle_option {
    my $opt = shift;
    my $pfx = $opt->parent('command')->att('prefix');
    my $nm = $opt->att('name');
    $nm = join('|', $pfx, $nm) if $pfx;
    for  ($opt->att('type')) {
	m/parameter/ && do { push @program_params, $nm; };
	m/switch/ && do { push @program_switches, $nm; };
    }
    if ($opt->att('translation')) {
	$param_translation{$nm} = $opt->att('translation');
    }
    if ($opt->first_child('incompatibles')) {
	foreach ($opt->first_child('incompatibles')->children) {
	    # note here that no prefix is added to the command name
	    $incompat_options{$opt->att('name')} =$_->att('name');
	}
    }
    if ($opt->first_child('corequisites')) {
	foreach ($opt->first_child('corequisites')->children) {
	    $corequisite_options{$opt->att('name')} = $_->att('name');
	}
    }
}

sub handle_filespec {
    my ($spc,$ar) = @_;
    my $tok = $spc->att('token');
    for ($spc->att('use')) {
	last if !defined;
	m/required-single/ && do {
	    last;
	};
	m/required-multiple/ && do {
	    $tok = "*$tok";
	};
	m/optional-single/ && do {
	    $tok = "#$tok";
	};
	m/optional-multiple/ && do {
	    $tok = "#*$tok";
	};
    }
    for ($spc->att('redirect')) {
	last if !defined;
	m/stdout/ && do {
	    $tok = ">$tok";
	};
	m/stderr/ && do {
	    $tok = "2>$tok";
	};
	m/stdin/ && do {
	    $tok = "<$tok";
	};
    }
#### need something for Dan's file switches here...
    for ($spc->att('fileswitch')) {
	last if !defined;
	m/.+/ && do {
	    $tok = "$_$tok"; # stub
	};
    }
}

1;
