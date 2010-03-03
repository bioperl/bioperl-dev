# $Id: Primer3.pm 15558 2009-02-21 22:07:57Z maj $
#
# This is the original copyright statement. I have relied on Chad's module
# extensively for this module.
#
# Copyright (c) 1997-2001 bioperl, Chad Matsalla. All Rights Reserved.
#           This module is free software; you can redistribute it and/or
#           modify it under the same terms as Perl itself. 
#
# Copyright Chad Matsalla
#
# You may distribute this module under the same terms as perl itself
# POD documentation - main docs before the code
#
# But I have modified lots of it, so I guess I should add:
#
# Copyright (c) 2003 bioperl, Rob Edwards. All Rights Reserved.
#           This module is free software; you can redistribute it and/or
#           modify it under the same terms as Perl itself. 
#
# Copyright Chris Fields
#
# You may distribute this module under the same terms as perl itself
# POD documentation - main docs before the code

=head1 NAME

Bio::Tools::Run::Primer3Redux - Create input for and work with the output 
from the program primer3

=head1 SYNOPSIS

  # design some primers.
  # the output will be put into temp.out
  use Bio::Tools::Run::Primer3;
  use Bio::SeqIO;

  my $seqio = Bio::SeqIO->new(-file=>'data/dna1.fa');
  my $seq = $seqio->next_seq;

  my $primer3 = Bio::Tools::Run::Primer3->new(-outfile => "temp.out",
                                            -path => "/usr/bin/primer3_core");

  # or after the fact you can change the program_name
  $primer3->program_name('my_superfast_primer3');

  unless ($primer3->executable) {
    print STDERR "primer3 can not be found. Is it installed?\n";
    exit(-1)
  }

  # set the maximum and minimum Tm of the primer
  $primer3->add_targets('PRIMER_MIN_TM'=>56, 'PRIMER_MAX_TM'=>90);

  # design the primers. This runs primer3 and returns a 
  # Bio::Tools::Primer3Parser object with the results
  $results = $primer3->run($seq);

  # see the Bio::Tools::Primer3Parser pod for
  # things that you can get from this. For example:

  print "There were ", $results->number_of_results, " primers\n";

=head1 DESCRIPTION

Bio::Tools::Run::Primer3 creates the input files needed to design primers
using primer3 and provides mechanisms to access data in the primer3
output files.

This module is largely a streamlined refactoring of the original Primer3 module
written by Rob Edwards. See http://primer3.sourceforge.net for details and to
download the software. This module should work for primer3 release 1 and above
but is not guaranteed to work with earlier versions.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://www.bioperl.org/MailList.html             - About the mailing lists

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via the
web:

  http://bugzilla.open-bio.org/

=head1 AUTHOR

Chris Fields cjfields-at-bioperl-dot-org

Refactored from the original Primer3 parser by Rob Edwards, which in turn was
based heavily on work of Chad Matsalla

bioinformatics1@dieselwurks.com

=head1 CONTRIBUTORS

Rob Edwards redwards@utmem.edu
Chad Matsalla bioinformatics1@dieselwurks.com
Shawn Hoon shawnh-at-stanford.edu
Jason Stajich jason-at-bioperl.org
Brian Osborne osborne1-at-optonline.net
Chris Fields cjfields-at-bioperl-dot-org

=head1 SEE ALSO

L<Bio::Tools::Primer3>

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::Tools::Run::Primer3Redux;

use strict;
use Bio::Tools::Primer3Redux;
use File::Spec;
use Data::Dumper;

use base qw(Bio::Root::Root Bio::Tools::Run::WrapperBase);

my $PROGRAMNAME;
my %PARAMS;
my @P1;
my @P2;

# 2.0 is still in alpha (3/3/10), so fallback to v1 for determining parameters
my $DEFAULT_VERSION = '1.1.4'; 
BEGIN {
    # $ct assigns order of parameter building
@P1 = qw(
    PRIMER_SEQUENCE_ID
    SEQUENCE
    TARGET   
    EXCLUDED_REGION
    INCLUDED_REGION
    PRIMER_COMMENT
    PRIMER_DNA_CONC
    PRIMER_EXPLAIN_FLAG
    PRIMER_FILE_FLAG
    PRIMER_FIRST_BASE_INDEX
    PRIMER_GC_CLAMP
    PRIMER_DIVALENT_CONC
    PRIMER_DNTP_CONC
    PRIMER_LOWERCASE_MASKING
    PRIMER_SALT_CORRECTIONS
    PRIMER_INTERNAL_OLIGO_DNTP_CONC                 PRIMER_INTERNAL_OLIGO_DIVALENT_CONC
    PRIMER_INTERNAL_OLIGO_DNA_CONC                  PRIMER_INTERNAL_OLIGO_EXCLUDED_REGION
    PRIMER_INTERNAL_OLIGO_INPUT                     PRIMER_INTERNAL_OLIGO_MAX_GC
    PRIMER_INTERNAL_OLIGO_MAX_MISHYB                PRIMER_INTERNAL_OLIGO_MAX_POLY_X
    PRIMER_INTERNAL_OLIGO_MAX_SIZE                  PRIMER_INTERNAL_OLIGO_MAX_TM
    PRIMER_INTERNAL_OLIGO_MIN_GC                    PRIMER_INTERNAL_OLIGO_MIN_QUALITY
    PRIMER_INTERNAL_OLIGO_MIN_SIZE                  PRIMER_INTERNAL_OLIGO_MIN_TM
    PRIMER_INTERNAL_OLIGO_MISHYB_LIBRARY            PRIMER_INTERNAL_OLIGO_OPT_GC_PERCENT
    PRIMER_INTERNAL_OLIGO_OPT_SIZE                  PRIMER_INTERNAL_OLIGO_OPT_TM
    PRIMER_INTERNAL_OLIGO_SALT_CONC                 PRIMER_INTERNAL_OLIGO_SELF_ANY
    PRIMER_INTERNAL_OLIGO_SELF_END
    PRIMER_IO_WT_COMPL_ANY
    PRIMER_IO_WT_COMPL_END                          PRIMER_IO_WT_END_QUAL
    PRIMER_IO_WT_GC_PERCENT_GT                      PRIMER_IO_WT_GC_PERCENT_LT
    PRIMER_IO_WT_NUM_NS                             PRIMER_IO_WT_REP_SIM
    PRIMER_IO_WT_SEQ_QUAL                           PRIMER_IO_WT_SIZE_GT
    PRIMER_IO_WT_SIZE_LT                            PRIMER_IO_WT_TM_GT
    PRIMER_IO_WT_TM_LT
    PRIMER_LEFT_INPUT                               PRIMER_RIGHT_INPUT
    PRIMER_LIBERAL_BASE
    PRIMER_MAX_DIFF_TM                              PRIMER_MAX_END_STABILITY
    PRIMER_MAX_GC                                   PRIMER_MAX_MISPRIMING
    PRIMER_MAX_POLY_X                               PRIMER_MAX_SIZE
    PRIMER_MAX_TM
    PRIMER_MIN_END_QUALITY                          PRIMER_MIN_GC
    PRIMER_MIN_QUALITY                              PRIMER_MIN_SIZE
    PRIMER_MIN_TM
    PRIMER_MISPRIMING_LIBRARY
    PRIMER_NUM_NS_ACCEPTED                          PRIMER_NUM_RETURN
    PRIMER_OPT_GC_PERCENT                           PRIMER_OPT_SIZE
    PRIMER_OPT_TM
    PRIMER_PAIR_MAX_MISPRIMING                      PRIMER_PAIR_WT_COMPL_ANY
    PRIMER_PAIR_WT_COMPL_END                        PRIMER_PAIR_WT_DIFF_TM
    PRIMER_PAIR_WT_IO_PENALTY                       PRIMER_PAIR_WT_PRODUCT_SIZE_GT
    PRIMER_PAIR_WT_PRODUCT_SIZE_LT                  PRIMER_PAIR_WT_PRODUCT_TM_GT
    PRIMER_PAIR_WT_PRODUCT_TM_LT                    PRIMER_PAIR_WT_PR_PENALTY
    PRIMER_PAIR_WT_REP_SIM
    PRIMER_PICK_ANYWAY                              PRIMER_PICK_INTERNAL_OLIGO
    PRIMER_PRODUCT_MAX_TM                           PRIMER_PRODUCT_MIN_TM
    PRIMER_PRODUCT_OPT_SIZE                         PRIMER_PRODUCT_OPT_TM
    PRIMER_PRODUCT_SIZE_RANGE
    PRIMER_QUALITY_RANGE_MAX                        PRIMER_QUALITY_RANGE_MIN
    PRIMER_SALT_CONC
    PRIMER_SELF_ANY                                 PRIMER_SELF_END
    PRIMER_SEQUENCE_QUALITY
    PRIMER_START_CODON_POSITION
    PRIMER_TASK
    PRIMER_TM_SANTALUCIA
    PRIMER_WT_COMPL_ANY                             PRIMER_WT_COMPL_END
    PRIMER_WT_END_QUAL                              PRIMER_WT_END_STABILITY
    PRIMER_WT_GC_PERCENT_GT                         PRIMER_WT_GC_PERCENT_LT
    PRIMER_WT_NUM_NS                                PRIMER_WT_POS_PENALTY
    PRIMER_WT_REP_SIM                               PRIMER_WT_SEQ_QUAL
    PRIMER_WT_SIZE_GT                               PRIMER_WT_SIZE_LT
    PRIMER_WT_TM_GT                                 PRIMER_WT_TM_LT
    PRIMER_WT_TEMPLATE_MISPRIMING
    PRIMER_DEFAULT_PRODUCT                          PRIMER_DEFAULT_SIZE
    PRIMER_INSIDE_PENALTY
    PRIMER_INTERNAL_OLIGO_MAX_TEMPLATE_MISHYB
    PRIMER_OUTSIDE_PENALTY
    PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS
    PRIMER_MAX_TEMPLATE_MISPRIMING
    PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING             PRIMER_PAIR_WT_TEMPLATE_MISPRIMING
);
@P2 = qw(
    SEQUENCE_EXCLUDED_REGION
    SEQUENCE_INCLUDED_REGION
    SEQUENCE_QUALITY
    SEQUENCE_FORCE_LEFT_END
    SEQUENCE_INTERNAL_EXCLUDED_REGION
    SEQUENCE_START_CODON_POSITION
    SEQUENCE_FORCE_LEFT_START
    SEQUENCE_INTERNAL_OLIGO
    SEQUENCE_TARGET
    SEQUENCE_FORCE_RIGHT_END
    SEQUENCE_PRIMER
    SEQUENCE_TEMPLATE
    SEQUENCE_FORCE_RIGHT_START
    SEQUENCE_PRIMER_OVERLAP_POS
    SEQUENCE_ID
    SEQUENCE_PRIMER_REVCOMP

    PRIMER_DNA_CONC
    PRIMER_LIBERAL_BASE
    PRIMER_PAIR_WT_PR_PENALTY
    PRIMER_DNTP_CONC
    PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS
    PRIMER_PAIR_WT_TEMPLATE_MISPRIMING
    PRIMER_EXPLAIN_FLAG
    PRIMER_LOWERCASE_MASKING
    PRIMER_PICK_ANYWAY
    PRIMER_FIRST_BASE_INDEX
    PRIMER_MAX_END_GC
    PRIMER_PICK_INTERNAL_OLIGO
    PRIMER_GC_CLAMP
    PRIMER_MAX_END_STABILITY
    PRIMER_PICK_LEFT_PRIMER
    PRIMER_INSIDE_PENALTY
    PRIMER_MAX_GC
    PRIMER_PICK_RIGHT_PRIMER
    PRIMER_INTERNAL_DNA_CONC
    PRIMER_MAX_LIBRARY_MISPRIMING
    PRIMER_POS_OVERLAP_TO_END_DIST
    PRIMER_INTERNAL_DNTP_CONC
    PRIMER_MAX_NS_ACCEPTED
    PRIMER_PRODUCT_MAX_TM
    PRIMER_INTERNAL_MAX_GC
    PRIMER_MAX_POLY_X
    PRIMER_PRODUCT_MIN_TM
    PRIMER_INTERNAL_MAX_LIBRARY_MISHYB
    PRIMER_MAX_SELF_ANY
    PRIMER_PRODUCT_OPT_SIZE
    PRIMER_INTERNAL_MAX_NS_ACCEPTED
    PRIMER_MAX_SELF_END
    PRIMER_PRODUCT_OPT_TM
    PRIMER_INTERNAL_MAX_POLY_X
    PRIMER_MAX_SIZE
    PRIMER_PRODUCT_SIZE_RANGE
    PRIMER_INTERNAL_MAX_SELF_ANY
    PRIMER_MAX_TEMPLATE_MISPRIMING
    PRIMER_QUALITY_RANGE_MAX
    PRIMER_INTERNAL_MAX_SELF_END
    PRIMER_MAX_TM
    PRIMER_QUALITY_RANGE_MIN
    PRIMER_INTERNAL_MAX_SIZE
    PRIMER_MIN_END_QUALITY
    PRIMER_SALT_CORRECTIONS
    PRIMER_INTERNAL_MAX_TEMPLATE_MISHYB
    PRIMER_MIN_GC
    PRIMER_SALT_DIVALENT
    PRIMER_INTERNAL_MAX_TM
    PRIMER_MIN_QUALITY
    PRIMER_SALT_MONOVALENT
    PRIMER_INTERNAL_MIN_GC
    PRIMER_MIN_SIZE
    PRIMER_SEQUENCING_ACCURACY
    PRIMER_INTERNAL_MIN_QUALITY
    PRIMER_MIN_THREE_PRIME_DISTANCE
    PRIMER_SEQUENCING_INTERVAL
    PRIMER_INTERNAL_MIN_SIZE
    PRIMER_MIN_TM
    PRIMER_SEQUENCING_LEAD
    PRIMER_INTERNAL_MIN_TM
    PRIMER_MISPRIMING_LIBRARY
    PRIMER_SEQUENCING_SPACING
    PRIMER_INTERNAL_MISHYB_LIBRARY
    PRIMER_NUM_RETURN
    PRIMER_TASK
    PRIMER_INTERNAL_OPT_GC_PERCENT
    PRIMER_OPT_GC_PERCENT
    PRIMER_TM_FORMULA
    PRIMER_INTERNAL_OPT_SIZE
    PRIMER_OPT_SIZE
    PRIMER_WT_END_QUAL
    PRIMER_INTERNAL_OPT_TM
    PRIMER_OPT_TM
    PRIMER_WT_END_STABILITY
    PRIMER_INTERNAL_SALT_DIVALENT
    PRIMER_OUTSIDE_PENALTY
    PRIMER_WT_GC_PERCENT_GT
    PRIMER_INTERNAL_SALT_MONOVALENT
    PRIMER_PAIR_MAX_COMPL_ANY
    PRIMER_WT_GC_PERCENT_LT
    PRIMER_INTERNAL_WT_END_QUAL
    PRIMER_PAIR_MAX_COMPL_END
    PRIMER_WT_LIBRARY_MISPRIMING
    PRIMER_INTERNAL_WT_GC_PERCENT_GT
    PRIMER_PAIR_MAX_DIFF_TM
    PRIMER_WT_NUM_NS
    PRIMER_INTERNAL_WT_GC_PERCENT_LT
    PRIMER_PAIR_MAX_LIBRARY_MISPRIMING
    PRIMER_WT_POS_PENALTY
    PRIMER_INTERNAL_WT_LIBRARY_MISHYB
    PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING
    PRIMER_WT_SELF_ANY
    PRIMER_INTERNAL_WT_NUM_NS
    PRIMER_PAIR_WT_COMPL_ANY
    PRIMER_WT_SELF_END
    PRIMER_INTERNAL_WT_SELF_ANY
    PRIMER_PAIR_WT_COMPL_END
    PRIMER_WT_SEQ_QUAL
    PRIMER_INTERNAL_WT_SELF_END
    PRIMER_PAIR_WT_DIFF_TM
    PRIMER_WT_SIZE_GT
    PRIMER_INTERNAL_WT_SEQ_QUAL
    PRIMER_PAIR_WT_IO_PENALTY
    PRIMER_WT_SIZE_LT
    PRIMER_INTERNAL_WT_SIZE_GT
    PRIMER_PAIR_WT_LIBRARY_MISPRIMING
    PRIMER_WT_TEMPLATE_MISPRIMING
    PRIMER_INTERNAL_WT_SIZE_LT
    PRIMER_PAIR_WT_PRODUCT_SIZE_GT
    PRIMER_WT_TM_GT
    PRIMER_INTERNAL_WT_TEMPLATE_MISHYB
    PRIMER_PAIR_WT_PRODUCT_SIZE_LT
    PRIMER_WT_TM_LT
    PRIMER_INTERNAL_WT_TM_GT
    PRIMER_PAIR_WT_PRODUCT_TM_GT
    PRIMER_INTERNAL_WT_TM_LT
    PRIMER_PAIR_WT_PRODUCT_TM_LT

    P3_FILE_ID
    P3_FILE_FLAG
    P3_COMMENT
);
}

=head2 new()

 Title   : new()
 Usage   : my $primer3 = Bio::Tools::Run::Primer3->new(-file=>$file) to read 
           a primer3 output file.
           my $primer3 = Bio::Tools::Run::Primer3->new(-seq=>sequence object) 
           design primers against sequence
 Function: Start primer3 working and adds a sequence. At the moment it 
           will not clear out the old sequence, but I suppose it should.
 Returns : Does not return anything. If called with a filename will allow 
           you to retrieve the results
 Args    : -outfile : file name send output results to 
	       -path    : path to primer3 executable

=cut

sub new {
	my($class,@args) = @_;
	my $self = $class->SUPER::new(@args);
	$self->io->_initialize_io();

    my ($program, $outfile, $path) = $self->_rearrange(
        [qw(PROGRAM OUTFILE PATH)], @args);

	$program    &&      $self->program_name($program);
    
	if ($outfile) {
        $self->outfile_name($outfile);
    }
	if ($path) {
		my (undef,$path,$prog) = File::Spec->splitpath($path);
		$self->program_dir($path);
		$self->program_name($prog);
	}

    # determine the correct set of parameters to use (v1 vs v2)
    my $v = ($self->executable) ?  $self->version : $DEFAULT_VERSION;
    
    my $ct = 0;
    
    %PARAMS = ($v && $v =~ /^2/) ? map {$_ => $ct++} @P2 :
                map {$_ => $ct++} @P1;
    
    $self->_set_from_args(\@args,
        -methods => [sort keys %PARAMS],
        -create => 1
       );
    
	return $self;
}

=head2 program_name

 Title   : program_name
 Usage   : $primer3->program_name()
 Function: holds the program name
 Returns:  string
 Args    : None

=cut

sub program_name {
	my $self = shift;
    # if explicitly set, use that
	return $self->{'program_name'} = shift @_ if @_;
    # then if previously set, use that    
    return $self->{'program_name'} if $self->{'program_name'};
    # run a quick check to look for programm set class attribute if found
    if (!$PROGRAMNAME) {
        for (qw(primer3 primer3_core)) {
            if ($self->io->exists_exe($_)) {
                $PROGRAMNAME = $_;
                last;
            }
        }
    }
    # don't set permanently, use global
    return $PROGRAMNAME;
}

=head2 program_dir

 Title   : program_dir
 Usage   : $primer3->program_dir($dir)
 Function: returns the program directory, which may also be obtained from ENV variable.
 Returns :  string
 Args    :

=cut

sub program_dir {
    my ($self, $dir) = @_;
    if ($dir) {
       $self->{'program_dir'}=$dir;
    } 
    
    # we need to stop here if we know what the answer is, otherwise we can 
    # never set it and then call it later
    return $self->{'program_dir'} if $self->{'program_dir'};
    
    if ($ENV{PRIMER3}) {
        $self->{'program_dir'} = Bio::Root::IO->catfile($ENV{PRIMER3});
    } else {
        $self->{'program_dir'} = Bio::Root::IO->catfile('usr','local','bin');
    }
    
    return $self->{'program_dir'}
}

=head2  version

 Title   : version
 Usage   : $v = $prog->version();
 Function: Determine the version number of the program
 Example :
 Returns : float or undef
 Args    : none

=cut

sub version {
    my ($self) = @_;
    return unless my $exe = $self->executable;
    if (!defined $self->{'_progversion'}) {
        my $string = `$exe -about 2>&1`;
        my $v;
        if ($string =~ m{primer3\s+release\s+([\d\.]+)}) {
            $self->{'_progversion'} = $1;
        }
    }
    return $self->{'_progversion'} || undef;
}

=head2 set_parameters()

 Title   : set_parameters()
 Usage   : $primer3->set_parameters(key=>value)
 Function: Sets parameters for the input file
 Returns : Returns the number of arguments added
 Args    : See the primer3 docs.
 Notes   : To set individual parameters use the associated method:
           $primer3->PRIMER_MAX_TM(40)

=cut

sub set_parameters {
	my ($self, %args)=@_;
    # hack around _rearrange issue to deal with lack of '-'
    my ($seq) = map {
            $args{$_}
            }
        grep { uc $_ eq 'SEQ' } keys %args;
    if (defined $seq) {
        my @seqs = (UNIVERSAL::isa($seq, 'ARRAY')) ? @$seq : ($seq);
        for my $s (@seqs) {
            $self->throw("-seq must be a single or array reference of Bio::SeqI") unless (ref $seq &&
                UNIVERSAL::isa($seq, 'Bio::SeqI'));
        }
        $self->{seq_cache} = \@seqs;
    }
    
    my $added_args = 0;
    
    # add this back in
    unless ($self->{'no_param_checks'}) {
        for my $key (sort keys %args) {
            my $method = uc $key; # consistency
            $method =~ s/^-//;    # remove possible hanging bp-like parameter prefix
            if (!$self->can($method)) {
                next if $method eq 'SEQ';
                $self->warn("Parameter $key is not a valid Primer3 parameter"); 
                next
            }
            $self->$method($args{$key});
            $added_args++;
        }
    }
	return $added_args;
}

=head2 get_parameters

 Title    : get_parameters
 Usage    : $obj->get_parameters
 Function : 
 Returns  : 
 Args     : 

=cut

sub get_parameters {
    my $self = shift;
    my %args = map {$_->[0] => $_->[1]}
        grep { defined $_->[1] } 
        map { [$_, $self->$_] } sort keys %PARAMS;
    return %args;
}

=head2 reset_parameters()

 Title   : reset_parameters()
 Usage   : $primer3->reset_parameters()
 Function: Resets all parameters to be undef
 Returns : none
 Args    : none; to reset specific targets call the specific method for that
           target (i.e. $primer3->PRIMER_MAX_TM(undef))

=cut

sub reset_parameters {
    my $self = shift;
    my %args = map {$_ => undef} sort keys %PARAMS;
    $self->_set_from_args(\%args, -methods => [sort keys %PARAMS]);    
}

=head2 run

 Title   : run
 Usage   : $primer3->run;
 Function: Run the primer3 program with the arguments that you have supplied.
 Returns : A Bio::Tools::Primer3 object containing the results.
           See the Bio::Tools::Primer3 documentation for those functions.
 Args    : Same as for add_targets() (these are just delegated to that
           method prior creating the input file on the fly)
 Note    : 
        

=cut

sub run {
	my($self, @seqs) = @_;
	my $executable = $self->executable;
    my $out = $self->outfile_name;
	unless ($executable && -e $executable) {
		$self->throw("Executable was not found. Do not know where primer3 is!") if !$executable;
		$self->throw("$executable was not found. Do not know where primer3 is!");
		exit(-1);
	}

    my %params = $self->get_parameters;
    
    my $file = $self->_generate_input_file(\%params, \@seqs);

    my $str = "$executable < $file";
    
    my $obj = Bio::Tools::Primer3Redux->new(-verbose => $self->verbose);
    my @args;
    # file output
    if ($out) {
        $str .= " > $out";
        my $status = system($str);
        if($status || !-e $out || -z $out ) {
            my $error = ($!) ? "$! Status: $status" : "Status: $status";
            $self->throw( "Primer3 call crashed: $error \n[command $str]\n");
            return undef;
        }
        if ($obj && ref($obj)) {
            $obj->file($out);
            @args = (-file => $out);
        }
    # fh-based (no outfile)
    } else {
        open(my $fh,"$str |") || $self->throw("Primer3 call ($str) crashed: $?\n");
        if ($obj && ref($obj)) {
            $obj->fh($fh);
            @args = (-fh => $fh);
        } else {
            # dump to debugging
            my $io;
            while(<$fh>) {$io .= $_;}
            close($fh);
            $self->debug($io);
            return 1;
        }
    }
    $obj->_initialize_io(@args) if $obj && ref($obj);
    return $obj;
}

sub _generate_input_file {
	# note that I write this to a temp file because we need both read 
	# and write access to primer3, therefore,
	# we can't use a simple pipe.
    my ($self, $args, $seqs) = @_;
    my ($tmpfh, $tmpfile) = $self->io->tempfile();

    # this is a hack to get around interface issues and conflicts when passing
    # in raw sequence via PRIMER_SEQUENCE_ID and SEQUENCE (one can potentially
    # have both).  For now, push any explicitly set parameters on last
    
    my ($id_tag, $seq_tag) = $self->version =~ /^2/ ? # v2 differs from v1
                            qw(SEQUENCE_ID SEQUENCE_TEMPLATE) :  #v2
                            qw(PRIMER_SEQUENCE_ID SEQUENCE);   #v1
    my @seqdata;
    for my $seq (@$seqs) {
        $self->throw("Arguments to run() must be a single or array ref of Bio::SeqI")
            if !UNIVERSAL::isa($seq, 'Bio::SeqI');
        push @seqdata, {$id_tag     => $seq->id,
                        $seq_tag    => $seq->seq};
    }

    if (exists $args->{$id_tag} || exists $args->{$seq_tag}) {
        push @seqdata, {$id_tag     => $args->{$id_tag},
                        $seq_tag    => $args->{$seq_tag}};
        delete $args->{$id_tag};
        delete $args->{$seq_tag};
    }
    
    # generate the common BoulderIO string to be used for each sequence
    my $string = '';
    
    for my $param (sort keys %$args) {
        my $tmp = $self->$param;
        my @data = UNIVERSAL::isa($tmp, 'ARRAY') ? @$tmp : $tmp;
        for my $d (@data) {
            $string .= "$param=$d\n";
        }
    }
    
    $string .= "=\n";
    
    for my $data (@seqdata) {
        my $str = join("\n", map { "$_=".$data->{$_}} sort keys %$data)."\n$string";
        $self->debug("TRYING\n$str");
        print $tmpfh $str;
    }
    
	close($tmpfh);
    return $tmpfile;
}

1;
