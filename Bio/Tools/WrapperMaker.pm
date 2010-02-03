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

Bio::Tools::WrapperMaker - DIY BioPerl wrapper classes for external pgms

=head1 SYNOPSIS

 $samt = Bio::Tools::WrapperMaker->compile( -defs => "samtools.xml" );
 $samt->set_parameters( -sam_input => 1, -bam_output => 1);
 $samt->run( -bam => 'my.sam', -out => 'my_bam' );

 $samt = Bio::Tools::WrapperMaker->compile( -defs => $xml_string,
                                            -xsd => 'maker_tweaked.xsd' );
 
 Bio::Tools::WrapperMaker->compile( -defs => "samtools.xml",
                                    -namespace => "My::Samtools" );
 $viewfac = My::Samtools->new_view( -sam_input => 1, -bam_output => 1);
 
 $viewfac->run( -bam => 'my.sam', -out => 'my_bam');

=head1 DESCRIPTION

C<Bio::Tools::WrapperMaker> will produce a fully-functional BioPerl run
wrapper for any command-line program, based on a wrapper definition
file written in XML. 

=head1 USAGE

=head2 WRAPPER DEFINITION FILE

The wrapper definition file is an XML document that validates against
the schema C<maker.xsd>, found in the local installation directory
C<$YOUR_INSTALL_ROOT/Bio/Tools/Wrapper> or at (currently)
L<http://fortinbras.us/wrappermaker/1.0>. 

The definition file defines:

=over

=item * the program name

=item * the commands (if any) that the program supports 

=item * the parameters and switches associated with the program and/or 
individual commands

=item * the other items (typically filenames, but not always) that
appear at the end of the command line.

=back

Other useful elements can appear in the definitions file; see the
documentation in C<maker.xsd> itself for more detail.

Here is a brief overview of these components based on a simple example.

I<Example wrapper def for a familiar program>:

 1  <defs xmlns="http://www.bioperl.org/wrappermaker/1.0">
 2    <program name="ls" dash-policy="mixed"/>
 3    <self name="_self">
 4      <options>
 5        <option name="all" type="switch"/>
 6        <option name="sort_by_size" type="switch" translation="S"/>
 7        <option name="sort_by_time" type="switch" translation="t"/>
 8        <option name="one_line_each" type="switch" translation="1"/>
 9      </options>
 10    <filespecs>
 11      <filespec token="pth" use="optional-multiple"/>
 12      <filespec token="out" use="optional-single" redirect="stdout"/>
 13    </filespecs>
 14  </self>
 15 </defs>

The root element of the schema is the C<defs> element. The namespace
definition as given is required.

The C<program> element (line 2) defines the name of the program as
typed on the command line. The C<dash-policy> attribute indicates
whether C<single> or C<double> dashes are used to set off the program
parameters or switches. C<mixed> indicates that single character
options are set off with single dashes, and long options with a double
dash.

The C<self> element (line 3) encompasses the options and filespecs
associated with the program itself, and not with program commands (for
example, in

 svn --version

C<version> is a "self option", while in 

 svn update -r 16784

C<r> is a command option, for the command C<update>). Program
commands, their options and filespecs are specified in a C<commands>
element.

The C<options> element (line 4) specifies the options to make
available to the wrapper, and can be used to create human-readable
aliases to these options. If the C<name> specified is an alias, the
C<translation> attribute indicates the command-line equivalent (B<sans
dashes>); compare lines 5 and 6. The C<type> attribute specifies
either C<parameter>, meaning the option takes a value (as in the C<r>
option in the Subversion client, above), or C<switch>, meaning the
option indicates a boolean state indicated by the option's presence or
absence on the command line.

The C<filespecs> element (line 10) defines how files or paths are
aliased, and also specifies stdin/stdout/stderr redirection. Each
C<filespec> element (lines 11 and 12) must be included in the
definition file in the order they would appear on the command
line. The C<token> attribute becomes the wrapper parameter for this
path. The C<use> attribute indicates whether this filespec is optional
or required, and whether multiple files or just a single file is
allowed on the command line (C<required-single, required-multiple,
optional-single, optional-multiple>).

This is a basic overview. The C<WrapperMaker/CommandExts> system is
designed to support complex programs and groups of programs, and
provides many other features. See
L<Bio::Tools::WrapperMaker::DefinitionFile> [to appear, one day] for
more complex examples involving programs with multiple commands, and
the representation of a group of related programs in a single wrapper.

=head2 MAKING A WRAPPER

To produce a run wrapper factory, use the C<compile> method:

 $lsfac = Bio::Tools::WrapperMaker->compile( -defs => 'ls.xml' );

or

 $lsfac = Bio::Tools::WrapperMaker->compile( -defs => $ls_xml_string );

The wrapper definition XML will be validated each time a factory is
compiled (if L<XML::LibXML> is installed). To inhibit the validation
step, set

 $Bio::Tools::WrapperMaker::VALIDATE_DEFS = 0;

and to turn off all validation warnings, set

 $Bio::Tools::WrapperMaker::VALIDATE_DEFS = -1;

The run wrapper factory is placed in the Perl namespace C<MyWrapper>
by default. This namespace can be used to run any class method in
C<Bio::Tools::Run::WrapperBase> and
C<Bio::Tools::Run::WrapperBase::CommandExts>, and to set up any
package globals you may desire. For example, the following code works:

 Bio::Tools::WrapperMaker->compile( -defs => 'ls.xml' );
 
 $lsfac = MyWrapper->new( -all => 1 );

Magic!

To create the wrapper in a different namespace, specify it with the
C<-namespace> parameter:

 Bio::Tools::WrapperMaker->compile( -defs => 'ls.xml',
                                    -namespace => 'LinuxWrap::LS' );
 $lsfac = LinuxWrap::LS->new();

The namespace can also be specified in the definitions file:

 <defs> 
 ...
   <perl-namespace>
     Linux::LS
   </perl-namespace>
 ...
 </defs>

The C<-namespace> parameter in C<compile()> overrides any XML file
definition.


=head2 FINDING THE EXECUTABLE

If the actual program executable does not appear in your C<$PATH>, you
can specify its location in an environment variable: the program name
in upper case followed by 'DIR'. If the example above didn't work out
of the box, you might do

 $ export LSDIR=/usr/bin

or

 #!/usr/bin/perl
 $ENV{LSDIR} = "/usr/bin";
 ...

(Or you might have little heart-to-heart with your sysadmin.)

=head2 USING THE WRAPPER OBJECT

The wrapper object will manage the program according to the facilities
in C<Bio::Tools::Run::WrapperBase::CommandExts>. It will automatically
be L<Bio::ParameterBaseI> compliant, possessing C<set_parameters(),
get_parameters(), reset_parameters(), available_parameters(),> and
C<parameters_changed()>. The C<run()> method will execute the program,
unless a command named "run" was defined in the definitions file, in
which case C<_run()> will do the trick. 

Some examples based on the definition in L</WRAPPER DEFINITION FILE>:

 $lsfac = Bio::Tools::WrapperMaker->compile( -defs => 'ls.xml');

 # list pwd and output to file
 $lsfac->run( -out => "listing.txt" );

 # list home directory, and collect output with stdout() 
 # ( provided by CommandExts...)
 $lsfac->set_parameters( -one_line_each => 1 );
 $lsfac->run( -pth => "~" );
 @myfiles = split("\n", $lsfac->stdout);
 
=head1 SECURITY NOTES

Because this module is designed to run commands outside Perl as directed
by an external file, attention has been paid to taint-checking and
input verification. Of course, we can't (and don't try to) keep you
from overriding the checks or making wrappers for nasty programs.

Basic security is provided by validation of wrapper definition files
against an XML Schema definition. Taint checks are built in to
the XSD to protect your command line against injections by naughty
defs. C<WrapperMaker> will validate for you if you have the
L<XML::LibXML> module installed, against either a local copy of the
XSD, or a hosted version at C<$SCHEMA_URL>. If you are missing
C<XML::LibXML>, a warning will be emitted. The warning can be turned
of by setting C<$Bio::Tools::WrapperMaker::VALIDATE_DEFS = -1>.
Wrapper def files can be validated "by hand" at
L<http://fortinbras.us/bioperl/wrappermaker> [someday].

The L<IPC::Run> module is used to execute all processes, and
three-argument C<open> to open all files. Backticks and C<qx> are
not used.

=head1 SEE ALSO

L<Bio::Tools::Run::WrapperBase>,
L<Bio::Tools::Run::WrapperBase::CommandExts>

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
use Bio::Tools::Run::WrapperBase;
use Bio::Tools::Run::WrapperBase::CommandExts;
use File::Spec;

use base qw(Bio::Root::Root );

our $HAVE_LIBXML = eval "require XML::LibXML; 1";
# to turn off validation, have to work for it...
our $VALIDATE_DEFS = 1;
our $SCHEMA_URL = "http://fortinbras.us/wrappermaker/1.0/maker.xsd";
my $where_i_am = (File::Spec->splitpath( File::Spec->rel2abs(__FILE__) ))[1];
our $LOCAL_XSD = File::Spec->catfile($where_i_am, "WrapperMaker","maker.xsd");

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
      $program_dir,
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

@program_commands = qw(command);

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
    my $ns = $self->namespace;
    # namespace additions
    eval "\@$ns\::ISA = qw(Bio::Tools::Run::WrapperBase
                           Bio::Root::Root)";
    # if no explicit 'run' command, export an alias to 
    # _run
    unless ( grep /^run$/, @program_commands ) {
	eval "sub $ns\::run \{ shift->_run(\@_); \}";
    }
    my $wrapper = $ns->new();
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
    $xsd ||= $LOCAL_XSD;
    # perl namespace to inject
    if ($ns) {
	unless ($ns =~ /^([a-z0-9_]+::)*[a-z0-9_]+$/i) {
	    $self->throw( "Invalid Perl namespace '$ns' specified" );
	}
	$self->namespace($ns);
    }
    else {
	$self->namespace('MyWrapper');
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
				       'self' => \&commands,
				       'composite-commands' => \&composite_commands,
				       'lookups' => \&lookups } );
					   
    return $self;
}

# validate_defs validates input xml against the WrapperMaker xsd

sub validate_defs {
    my $self = shift;
    my $schema_file = shift;
    my $defs = $self->_defs;
    unless ($schema_file && -e $schema_file || ($VALIDATE_DEFS <= 0) ) {
	$self->throw("Schema file missing but validation requested; can't continue");
    }

    unless ($HAVE_LIBXML) {
	$self->warn("XML::LibXML not present; can't validate. Beware!");
	return 1;
    }
    unless ($VALIDATE_DEFS) {
	$self->warn("Validation turned off; won't validate. Beware!");
	return 1;
    }
    return 1 if ($VALIDATE_DEFS < 0); # quiet non-val
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

    foreach my $cmd ($elt->gi eq 'self' ? $elt : $elt->children) {
	# looping over commandType elements
	push @program_commands, ($cmd->att('default') ? '*' : '').
	    $cmd->att('name');
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
    my $parent = $opt->parent('command') || $opt->parent('self');
    my $pfx = $parent->att('prefix');
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
    push @$ar, $tok;
}

1;
