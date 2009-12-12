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

Bio::Tools::Run::StandAloneBlastPlus - Compute with NCBI's blast+ suite

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
use File::Temp;
use IO::String;

use base qw(Bio::Root::Root);
unless ( eval "require Bio::Tools::Run::BlastPlus" ) {
    Bio::Root::Root->throw("This module requires 'Bio::Tools::Run::BlastPlus'");
}

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
    my ($istemp) = $self->_rearrange([qw( TEMPDB
                                          DBNAME
                                          DB_DATA
                                          DB_MAKE_ARGS
                                          MASK_FILE 
                                          MASK_DATA
                                          MASK_MAKE_ARGS
                                          MASKER
                                           )], @args);

    $self->is_tempdb(1) if $istemp;
    $self->{_factory} = Bio::Tools::Run::BlastPlus->new();
    $self->{_db} = undef;

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

sub db {
    my $self = shift;
    return $self->{'db'};
}

=head2 factory()

 Title   : factory
 Usage   : $obj->factory($newval)
 Function: attribute containing the Bio::Tools::Run::BlastPlus 
           factory
 Example : 
 Returns : value of factory (Bio::Tools::Run::BlastPlus object)
 Args    : readonly

=cut

sub factory {
    my $self = shift;
    return $self->{'factory'};
}


=head1 DB methods

=head2 make_db()

 Title   : make_db
 Usage   : 
 Function: create the blast database (if necessary), 
           imposing masking if specified
 Returns : true on success
 Args    : 

=cut

sub make_db {
    my $self = shift;
    my @args = @_;
    # check if db_name already points to a existing db
    # db_data can be: fasta file, array of seqs, Bio::SeqIO object
}

=head2 make_mask()

 Title   : make_mask
 Usage   : 
 Function: create masking data based on specified parameters
 Returns : mask data filename (scalar string)
 Args    : 

=cut

sub make_mask {
    my $self = shift;
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
    my %attrs;
    while (<$infh>) {
	/Database: (.*)/ && do {
	    $attrs{db_info_name} = $1;
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
	return $self->{_db_info} = \%attrs;
}

=head2 is_tempdb()

 Title   : is_tempdb
 Usage   : 
 Function: predicate indicating whether the attached db is
           temporary
 Returns : boolean
 Args    : [option] boolean to set/clear

=cut

sub is_tempdb {
    my $self = shift;
    return $self->{_is_tempdb} = shift if @_;
    return $self->{_is_tempdb};
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
