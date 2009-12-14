# $Id$
#
# BioPerl module for Bio::Tools::Run::StandAloneBlastPlus
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

Bio::Tools::Run::StandAloneBlastPlus - Compute with NCBI's blast+ suite *CURRENTLY NON-FUNCTIONAL*

=head1 SYNOPSIS

B<NOTE>: This module is related to the
L<Bio::Tools::Run::StandAloneBlast> system in name (and inspiration)
only. You must use this module directly.

=head1 DESCRIPTION

This module allows the user to perform BLAST functions using the
external program suite C<blast+> (available at
L<ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/>), using
BioPerl objects and L<Bio::SearchIO> facilities. This wrapper can
prepare BLAST databases as well as run BLAST searches. It can also be
used to run C<blast+> programs independently.

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


package Bio::Tools::Run::StandAloneBlastPlus;
use strict;
our $AUTOLOAD;

# Object preamble - inherits from Bio::Root::Root

use Bio::Root::Root;
use Bio::Tools::GuessSeqFormat;
use File::Temp;
use IO::String;

use base qw(Bio::Root::Root);
unless ( eval "require Bio::Tools::Run::BlastPlus" ) {
    Bio::Root::Root->throw("This module requires 'Bio::Tools::Run::BlastPlus'");
}

my %AVAILABLE_MASKERS = (
    'windowmasker' => 'nucl',
    'dustmasker'   => 'nucl',
    'segmasker'    => 'prot'
    );

# what's the desire here?
#
# * factory object (created by new())
#   - points to some blast db entity, so all functions run off the
#     the factory (except bl2seq?) use the associated db
# 
# * create a blast formatted database:
#   - specify a file, or an AlignI object
#   - store for later, or store in a tempfile to throw away
#   - object should store its own database pointer
#   - provide masking options based on the maskers provided
#
# * perform database actions via db-oriented blast+ commands
#   via the object
#
# * perform blast searches against the database
#   - blastx, blastp, blastn, tblastx, tblastn
#   - specify Bio::Seq objects or files as queries
#   - output the results as a file or as a Bio::Search::Result::BlastResult
# * perform 'special' (i.e., ones I don't know) searches
#   - psiblast, megablast, rpsblast, rpstblastn
#     some of these are "tasks" under particular programs
#     check out psiblast, why special (special 'iteration' handling in 
#     ...::BlastResult)
#     check out rpsblast, megablast
#
# * perform bl2seq
#   - return the alignment directly as a convenience, using Bio::Search 
#     functions

# lazy db formatting: makeblastdb only on first blast request...
# ParameterBaseI delegation : use AUTOLOAD
#
# 

=head2 new

 Title   : new
 Usage   : my $obj = new Bio::Tools::Run::StandAloneBlastPlus();
 Function: Builds a new Bio::Tools::Run::StandAloneBlastPlus object
 Returns : an instance of Bio::Tools::Run::StandAloneBlastPlus
 Args    : named argument (key => value) pairs:
           -db : blastdb name, fasta file, or Bio::Seq collection

=cut

sub new {
    my ($class,@args) = @_;
    my $self = $class->SUPER::new(@args);
    my ($db_name, $db_data, $db_dir, $db_make_args,
	$mask_file, $mask_data, $mask_make_args, $masker, 
	$create, $overwrite) 
                 = $self->_rearrange([qw( 
                                          DBNAME
                                          DB_DATA
                                          DB_DIR
                                          DB_MAKE_ARGS
                                          MASK_FILE 
                                          MASK_DATA
                                          MASK_MAKE_ARGS
                                          MASKER
                                          CREATE
                                          OVERWRITE
                                           )], @args);
    # make factory
    $self->{_factory} = Bio::Tools::Run::BlastPlus->new();

    # parm taint checks
    if ($db_name) {
	$self->throw("DB name not valid") unless $db_name =~ /^[a-z0-9_.+-]+$/i;
	$self->{_db} = $db_name;
    }

    if ( $db_dir ) { # or create if not there??
	$self->throw("DB directory (DB_DIR) not valid") unless (-d $db_dir);
	$self->{'_db_dir'} = $db_dir;
    }
    else {
	$self->{'_db_dir'} = '.';
    }

    if ($masker) {
	$self->throw("Masker '$masker' not available") unless 
	    grep /^$masker$/, keys %AVAILABLE_MASKERS;
	$self->{_masker} = $masker;
    }

    $self->set_db_make_args( $db_make_args) if ( $db_make_args );
    $self->set_mask_make_args( $mask_make_args) if ($mask_make_args);
    $self->{'_create'} = $create;
    $self->{'_overwrite'} = $overwrite;
    $self->{'_db_data'} = $db_data;

    # check db
    if ($self->check_db == 0) {
	$self->throw("DB '".$self->db."' can't be found. To create, set -create => 1.") unless $create;
    }
    else {
	$self->throw('No database or db data specified. '.
		     'To create a new database, provide '.
		     '-db_data => [fasta|\@seqs|$seqio_object]')
	    unless $self->db_data;
	# no db specified; create temp db
	$self->{_create} = 1;
	if ($self->db_dir) {
	    my $fh = File::Temp->new(TEMPLATE => 'DBXXXXX',
				     DIR => $self->{_db_dir},
				     UNLINK => 1);
	    $self->{_db} = $fh->filename;
	    $fh->close;
	}
	else {
	    $self->{_db_dir} = File::Temp->newdir('DBDXXXXX');
	    $self->{_db} = 'DBTEMP';
	}
    }

#    $self->{_db} = undef;

    return $self;
}

=head2 db()

 Title   : db
 Usage   : $obj->db($newval)
 Function: contains the basename of the local blast database
 Example : 
 Returns : value of db (a scalar string)
 Args    : readonly

=cut

sub db { shift->{_db} }
sub db_dir { shift->{_db_dir} }
sub db_data { shift->{_db_data} }
sub db_type { shift->{_db_type} }

=head2 factory()

 Title   : factory
 Usage   : $obj->factory($newval)
 Function: attribute containing the Bio::Tools::Run::BlastPlus 
           factory
 Example : 
 Returns : value of factory (Bio::Tools::Run::BlastPlus object)
 Args    : readonly

=cut

sub factory { shift->{_factory} }
sub masker { shift->{_masker} }

=head1 DB methods

=head2 make_db()

 Title   : make_db
 Usage   : 
 Function: create the blast database (if necessary), 
           imposing masking if specified
 Returns : true on success
 Args    : 

=cut

# should also provide facility for creating subdatabases from 
# existing databases (i.e., another format for $data: the name of an
# existing blastdb...)
sub make_db {
    my $self = shift;
    my @args = @_;
    return 1 if $self->check_db; # already there
    $self->throw('No database or db data specified. '.
		 'To create a new database, provide '.
		 '-db_data => [fasta|\@seqs|$seqio_object]') 
	unless $self->db_data;
    # db_data can be: fasta file, array of seqs, Bio::SeqIO object
    my $data = $self->db_data
    $data = $self->_fastize($data);
    my $testio = Bio::SeqIO->new(-file=>$data, -format=>'fasta');
    $self->{_db_type} = ($testio->next_seq->alphabet =~ /.na/) ? 'nucl' : 'prot';
    $testio->close;

    $self->factory->command('makeblastdb');
    my ($v,$d,$name) = File::Spec->splitpath($data);
    $name =~ s/\.fas$//;
    # <#######[
    # deal with creating masks here, 
    # and provide correct parameters to the 
    # makeblastdb ...
    
    # accomodate $self->db_make_args here -- allow them
    # to override defaults, or allow only those args
    # that are not specified here?

    $self->factory->reset_parameters(
	-in => $data,
	-dbtype => $self->db_type,
	-out => $name,
	-title => $name);
    $self->factory->_run or $self->throw("makeblastdb failed : $!");
    return 1;
}

=head2 make_mask()

 Title   : make_mask
 Usage   : 
 Function: create masking data based on specified parameters
 Returns : mask data filename (scalar string)
 Args    : 

=cut

# mask program usage (based on blast+ manual)
# 
# program        dbtype        opn
# windowmasker   nucl          mask overrep data, low-complexity (optional)
# dustmasker     nucl          mask low-complexity
# segmasker      prot  

#needs some thought
# want to be able to create mask and db in one go (say on object construction)
# also want to be able to create a mask from given data as a separate
# task using the factory.
# so this method should be independent, and also called by make_db
# if masking is specified.
# question then is arguments: do this: 
# must specify mask data (a seq collection),
# allow specification of mask program, mask pgm args,
# but if either of these not present, default to the object attribute


sub make_mask {
    my $self = shift;
    my @args = @_;
    my ($data, $make_args, $masker) = $self->_rearrange([qw(DATA,
                                                            MAKE_ARGS,
                                                            MASKER)], @args);
    $self->throw("make_mask requires -data argument") unless $data;
    $masker ||= $self->masker;
    $self->throw("no masker specified and no masker default set in object") 
	unless $masker;
    $make_args ||= $self->mask_make_args;
    # now, need to provide reasonable default masker arg settings, 
    # and override these with $make_args as necessary

}

=head2 db_info()

 Title   : db_info
 Usage   : 
 Function: get info for currently attached database
           (via blastdbcmd -info); add factory attributes
 Returns : hash of database attributes
 Args    : none

=cut

sub db_info {
    my $self = shift;
    my @args = @_;
    unless ($self->db) {
	$self->warn("db_info: database not attached yet");
	return;
    }
    $self->factory->command('blastdbcmd');
    unless ($self->reset_parameters(-info => 1, -db => $self->db )) {
	$self->warn("db_info: blastdbcmd failed");
	return;
    }
    $self->{_db_info_text} = $self->factory->stdout;
    # parse info into attributes
    my $infh = IO::String->new($self->{_db_info_text});
    my %attr;
    while (<$infh>) {
	/Database: (.*)/ && do {
	    $attr{db_info_name} = $1;
	    next;
	};
	/([0-9,]+) sequences; ([0-9,]+) total/ && do {
	    $attr{db_num_sequences} = $1;
	    $attr{db_total_bases} = $2;
	    $attr{db_num_sequences} =~ s/,//g;
	    $attr{db_total_bases} =~ s/,//g;
	    next;
	};
	/Date: (.*?)\s+Longest sequence: ([0-9,]+)/ && do {
	    $attr{db_date} = $1; # convert to more usable date object
	    $attr{db_longest_sequence} = $2;
	    $attr{db_longest_sequence} =~ s/,//g;
	    next;
	};
	/Algorithm ID/ && do {
	    my $alg = $attr{db_filter_algorithms} = [];
	    while (<$infh>) {
		if (/\s+([0-9]+)\s+([a-z0-9_]+)\s+(.*)/i) {
		    push @$alg, { algorithm_id => $1,
				  algorithm_name => $2,
				  algorithm_opts => $3 };
		}
		else {
		    last;
		}
	    }
	    next;
	};
    }
    return $self->{_db_info} = \%attr;
}

=head2 set_db_make_args()

 Title   : set_db_make_args
 Usage   : 
 Function: set the DB make arguments attribute 
           with checking
 Returns : true on success
 Args    : arrayref or hashref of named arguments

=cut

sub set_db_make_args {
    my $self = shift;
    my $args = shift;
    $self->throw("Arrayref or hashref required at DB_MAKE_ARGS") unless 
	ref($args) =~ /^ARRAY|HASH$/;
    if (ref($args) eq 'HASH') {
	my @a = %$args;
	$args = \@a;
    }
    $self->throw("Named args required for DB_MAKE_ARGS") unless !(@$args % 2);
    $self->{'_db_make_args'} = $args;
    return 1;
}

sub db_make_args { shift->{_db_make_args} }

=head2 set_mask_make_args()

 Title   : set_mask_make_args
 Usage   : 
 Function: set the masker make arguments attribute
           with checking
 Returns : true on success
 Args    : arrayref or hasref of named arguments

=cut

sub set_mask_make_args {
    my $self = shift;
    my $args = shift;
    $self->throw("Arrayref or hashref required at MASK_MAKE_ARGS") unless 
	ref($args) =~ /^ARRAY|HASH$/;
    if (ref($args) eq 'HASH') {
	my @a = %$args;
	$args = \@a;
    }
    $self->throw("Named args required at MASK_MAKE_ARGS") unless !(@$args % 2);
    $self->{'_mask_make_args'} = $args;
    return 1;
}

sub mask_make_args { shift->{_mask_make_args} }

=head2 check_db()

 Title   : check_db
 Usage   : 
 Function: determine if database with registered name and dir
           exists
 Returns : 1 if db present, 0 if not present, undef if name/dir not
           set
 Args    : none

=cut

sub check_db {
    my $self = shift;
    if ( $self->{db} && $self->{_db_dir} ) {
	my $ckdb = File::Spec->catfile($self->{_db_dir}, $self->{db});
	$self->factory->command('blastdbcmd');
	$self->factory->set_parameters( -db => $ckdb,
					-info => 1 );
	$self->_run();
	return 0 if ($self->factory->stderr =~ /No alias or index file found/);
	return 1;
    }
    return;
}

=head1 Internals

=head2 _fastize()

 Title   : _fastize
 Usage   : 
 Function: convert a sequence collection to a temporary
           fasta file
 Returns : fasta filename (scalar string)
 Args    : sequence collection 

=cut

sub fastize {
    my $self = shift;
    my $data = shift;
    for ($data) {
	!ref && do {
	    # suppose a fasta file name
	    $self->throw('Sequence file not found') unless -e $data;
	    my $guesser = Bio::Tools::GuessSeqFormat->new(-file => $data);
	    $self->throw('Sequence file not in FASTA format') unless
		$guesser->guess eq 'fasta';
	    last;
	};
	(ref eq 'ARRAY') && (ref $$data[0]) &&
	    ($$data[0]->isa('Bio::Seq') || $$data[0]->isa('Bio::PrimarySeq'))
	    && do {
		my $fh = File::Temp->new(TEMPLATE => 'DBDXXXXX', SUFFIX => '.fas');
		my $fname = $fh->filename;
		$fh->close;
		my $fasio = Bio::SeqIO->new(-file=>">$fname", -format=>"fasta")
		   or $self->throw("Can't create temp fasta file");
		$fasio->write_seq($_) for @$data;
		$fasio->close;
		$data = $fname;
		last;
	};
	ref && do { # some kind of object
	    my $fmt = ref($data) =~ /.*::(.*)/;
	    if ($fmt eq 'fasta') {
		$data = $data->file; # use the fasta file directly
	    }
	    else {
		# convert
		my $fh = File::Temp->new(TEMPLATE => 'DBDXXXXX', SUFFIX => '.fas');
		my $fname = $fh->filename;
		$fh->close;
		my $fasio = Bio::SeqIO->new(-file=>">$fname", -format=>"fasta") 
		    or $self->throw("Can't create temp fasta file");
		if ($data->isa('Bio::AlignIO')) {
		    my $aln = $data->next_aln;
		    $fasio->write_seq($_) for $aln->each_seq;
		}
		elsif ($data->isa('Bio::SeqIO')) {
		    while (<$data>) {
			$fasio->write_seq($_);
		    }
		}
		elsif ($data->isa('Bio::Align::AlignI')) {
		    $fasio->write_seq($_) for $data->each_seq;
		}
		else {
		    $self->throw("Can't handle sequence container object ".
				 "of type '".ref($data)."'");
		}
		$fasio->close;
		$data = $fname;
	    }
	    last;
	};
    }
    return $data;
}
    

=head2 AUTOLOAD

In this module, C<AUTOLOAD()> delegates L<Bio::Tools::Run::WrapperBase> and
L<Bio::Tools::Run::WrapperBase::CommandExts> methods (including those
of L<Bio::ParamterBaseI>) to the C<factory()> attribute.

=cut 

sub AUTOLOAD {
    my $self = shift;
    my @args = @_;
    my $method = $AUTOLOAD;
    $method = s/.*:://;
    my $ret;
    eval {
	if ($self->factory) {
	    $ret = $self->factory->$method(@args);
	}
	else {
	    die "BlastPlus factory not initialized";
	}
    };
    if ($@) {
	$self->throw("Unrecognized method '$method'") if $@ =~ /Can't locate/;
	$self->throw($@);
    }
    return $ret
}


1;
