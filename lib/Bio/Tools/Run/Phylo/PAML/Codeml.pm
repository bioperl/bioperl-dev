# $Id$
#
# BioPerl module for Bio::Tools::Run::Phylo::PAML::Codeml
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Jason Stajich <jason-at-bioperl-dot-org>
#
# Copyright Jason Stajich
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Tools::Run::Phylo::PAML::Codeml - Wrapper aroud the PAML program codeml

=head1 SYNOPSIS

  use Bio::Tools::Run::Phylo::PAML::Codeml;
  use Bio::AlignIO;

  my $alignio = Bio::AlignIO->new(-format => 'phylip',
  			         -file   => 't/data/gf-s85.phylip');

  my $aln = $alignio->next_aln;

  my $codeml = Bio::Tools::Run::Phylo::PAML::Codeml->new();
  $codeml->alignment($aln);
  my ($rc,$parser) = $codeml->run();
  my $result = $parser->next_result;
  my $MLmatrix = $result->get_MLmatrix();
  print "Ka = ", $MLmatrix->[0]->[1]->{'dN'},"\n";
  print "Ks = ", $MLmatrix->[0]->[1]->{'dS'},"\n";
  print "Ka/Ks = ", $MLmatrix->[0]->[1]->{'omega'},"\n";

=head1 DESCRIPTION

This is a wrapper around the codeml program of PAML (Phylogenetic
Analysis by Maximum Likelihood) package of Ziheng Yang.  See
http://abacus.gene.ucl.ac.uk/software/paml.html for more information.

This module is more about generating the properl codeml.ctl file and
will run the program in a separate temporary directory to avoid
creating temp files all over the place.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to
the Bioperl mailing list.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 

Please direct usage questions or support issues to the mailing list:

I<bioperl-l@bioperl.org>

rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
of the bugs and their resolution. Bug reports can be submitted via the
web:

  http://bugzilla.open-bio.org/

=head1 AUTHOR - Jason Stajich

Email jason-at-bioperl-dot-org

=head1 CONTRIBUTORS

Additional contributors names and emails here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::Tools::Run::Phylo::PAML::Codeml;
use vars qw(@ISA %VALIDVALUES $MINNAMELEN $PROGRAMNAME $PROGRAM);
use strict;
use Bio::Root::Root;
use Bio::AlignIO;
use Bio::TreeIO;
use Bio::Tools::Run::WrapperBase;
use Bio::Tools::Phylo::PAML;
use Cwd;

@ISA = qw(Bio::Root::Root Bio::Tools::Run::WrapperBase);

=head2 Default Values

Valid and default values for codeml programs are listed below.  The
default values are always the first one listed.  These descriptions
are essentially lifted from the example codeml.ctl file and pamlDOC
documentation provided by the author.

B<CodonFreq> specifies the equilibrium codon frequencies in codon
substitution model. These frequencies can be assumed to be equal (1/61
each for the standard genetic code, B<CodonFreq> = 0), calculated from
the average nucleotide frequencies (B<CodonFreq> = 1), from the average
nucleotide frequencies at the three codon positions (B<CodonFreq> = 2),
or used as free parameters (B<CodonFreq> = 3). The number of parameters
involved in those models of codon frequencies is 0, 3, 9, and 60
(under the universal code), for B<CodonFreq> = 0, 1, 2, and 3
respectively.

B<aaDist> specifies whether equal amino acid distances are assumed (=
0) or Grantham's matrix is used (= 1) (Yang et al. 1998).

B<runmode> = -2 performs ML estimation of dS and dN in pairwise
comparisons. The program will collect estimates of dS and dN into the
files 2ML.dS and 2ML.dN. Since many users seem interested in looking
at dN /dS ratios among lineages, examination of the tree shapes
indicated by branch lengths calculated from the two rates may be
interesting although the analysis is ad hoc. If your species names
have no more than 10 characters, you can use the output distance
matrices as input to Phylip programs such as neighbor without
change. Otherwise you need to edit the files to cut the names short.

B<model> concerns assumptions about the dN/dS rate ratios among
branches (Yang 1998; Yang and Nielsen 1998). B<model> =0 means a single
dN/dS ratio for all lineages (branches), 1 means one ratio for each
branch (free ratio model), and 2 means arbitrary number of rations
(such as the 2-ratios or 3-ratios models. with B<model> =2, you may
specify the omega ratios for the branches using branch labels (read
about the tree structure file in the document).  This option seems
rather easy to use. Otherwise, the program will ask the user to input
a branch mark for the dN/dS ratio assumed for each branch. This should
be an integral number between 0 to k - 1 if k different dN/dS ratios
(omega_0 - omega_k - 1) are assumed for the branches of the
tree. B<Bioperl> note basically, doing this interactively is not going
to work very well, so this module is really focused around using the 0
or 1 parameters.  Read the program documentation if you'd like some more 
detailed instructions.

B<NSsites> specifies models that allow the dN/dS ratio (omega) to vary
among sites (Nielsen and Yang 1998, Yang et al. 2000) B<Nssites> = m
corresponds to model Mm in Yang et al (2000).  The variable B<ncatG>
is used to specify the number of categories in the omega distribution
under some models.  The values of ncatG() used to perform our
analyses are 3 for M3 (discrete), 5 for M4 (freq), 10 for the
continuous distributions (M5: gamma, M6: 2gamma, M7: beta, M8:beta&amp;w,
M9:beta&amp;gamma, M10: beta&gamma+1, M11:beta&amp;normal&gt;1, and
M12:0&amp;2normal&gt;1, M13:3normal&gt;0). This means M8 will have 11 site
classes (10 from the beta distribution plus 1 additional class). The
posterior probabilities for site classes as well as the expected omega
values for sites are listed in the file rst, which may be useful to
pinpoint sites under positive selection, if they exist. 

To make it easy to run several B<Nssites> models in one go, the
executable L<Bio::Tools::Run::Phylo::PAML::Codemlsites> can be used,
which asks you how many and which models to run at the start of the
program. The number of categories used will then match those used in
Yang et al(2000).

As noted in that paper, some of the models are hard to use, in
particular, M12 and M13. Recommended models are 0 (one-ratio), 1
(neutral), 2 (selection), 3 (discrete), 7 (beta), and 8
(beta&amp;omega ). Some of the models like M2 and M8 are noted to be
prone to the problem of multiple local optima. You are advised to run
the program at least twice, once with a starting omega value E<lt>1 and a
second time with a value E<gt>1, and use the results corresponding to the
highest likelihood. The continuous neutral and selection models of
Nielsen and Yang (1998) are not implemented in the program.


B<icode> for genetic code and these correspond to 1-11 in the genbank 
transl table.
  0:universal code
  1:mamalian mt
  2:yeast mt
  3:mold mt,
  4:invertebrate mt
  5:ciliate nuclear
  6:echinoderm mt
  7:euplotid mt
  8:alternative yeast nu.
  9:ascidian mt
  10:blepharisma nu

B<RateAncestor> For codon sequences, ancestral reconstruction is not
implemented for the models of variable dN/dS ratios among sites. The
output under codon-based models usually shows the encoded amino acid
for each codon. The output under "Prob of best character at each node,
listed by site" has two posterior probabilities for each node at each
codon (amino acid) site. The first is for the best codon. The second,
in parentheses, is for the most likely amino acid under the codon
substitution model. This is a sum of posterior probabilities across
synonymous codons. In theory it is possible although rare for the most
likely amino acid not to match the most likely codon.

B<Output> for codon sequences (seqtype = 1): The codon frequencies in
each sequence are counted and listed in a genetic code table, together
with their sums across species. Each table contains six or fewer
species. For data of multiple genes (option G in the sequence file),
codon frequencies in each gene (summed over species) are also
listed. The nucleotide distributions at the three codon positions are
also listed. The method of Nei and Gojobori (1986) is used to
calculate the number of synonymous substitutions per synonymous site
(dS ) and the number of nonsynonymous substitutions per nonsynonymous
site (dN ) and their ratio (dN /dS ). These are used to construct
initial estimates of branch lengths for the likelihood analysis but
are not MLEs themselves. Note that the estimates of these quantities
for the a- and b-globin genes shown in Table 2 of Goldman and Yang
(1994), calculated using the MEGA package (Kumar et al., 1993), are
not accurate.  

Results of ancestral reconstructions (B<RateAncestor> = 1) are collected 
in the file rst. Under models of variable dN/dS ratios among sites (NSsites models), 
the posterior probabilities for site classes as well as positively 
selected sites are listed in rst.

INCOMPLETE DOCUMENTATION OF ALL METHODS

=cut

BEGIN { 

    $MINNAMELEN = 25;
    $PROGRAMNAME = 'codeml' . ($^O =~ /mswin/i ?'.exe':'');
    if( defined $ENV{'PAMLDIR'} ) {
	$PROGRAM = Bio::Root::IO->catfile($ENV{'PAMLDIR'},$PROGRAMNAME). ($^O =~ /mswin/i ?'.exe':'');;
    }
   
    # valid values for parameters, the default one is always
    # the first one in the array
    # much of the documentation here is lifted directly from the codeml.ctl
    # example file provided with the package
    %VALIDVALUES = ( 
		     'outfile' => 'mlc',
		     'noisy'   => [ 0..3,9],
		     'verbose' => [ 1,0,2], # 0:concise, 1:detailed, 2:too much

                     # (runmode) 0:user tree, 1:semi-autmatic, 2:automatic
		     #           3:stepwise addition, 4,5:PerturbationNNI
		     #           -2:pairwise
		     'runmode' => [ -2, 0..5], 

		     'seqtype' => [ 1..3], # 1:codons, 2:AAs, 3:codons->AAs

		     'CodonFreq' => [ 2, 0,1,3,4,5,6,7], # 0:1/61 each, 1:F1X4, 
		                                # 2:F3X4, 3:codon table

		     # (aaDist) 0:equal, +:geometric, -:linear, 
		     #          1-6:G1974,Miyata, c,p,v,a
		     'aaDist'  => [ 0,'+','-', 1..6], 

                     # (aaRatefile) only used for aa seqs 
		     # with model=empirical(_F)
		     # default is usually 'wag.dat', also
		     # dayhoff.dat, jones.dat, mtmam.dat, or your own
		     'aaRatefile' => 'wag.dat', 

		     # (model) models for codons 
		     # 0: one, 1:b, 2:2 or more dN/dS ratios for branches
		     'model'    => [0..2,7], 
		     
		     # (NSsites) number of S sites
		     # 0: one w;1:neutral;2:selection; 3:discrete;4:freqs;
                     # 5:gamma;6:2gamma;7:beta;8:beta&w;9:beta&gamma;
                     # 10:beta&gamma+1; 11:beta&normal>1; 12:0&2normal>1;
                     # 13:3normal>0
		     'NSsites'  => [0..13],

		     # (icode) genetic code
		     # 0:universal code
		     # 1:mamalian mt
		     # 2:yeast mt
		     # 3:mold mt,
		     # 4:invertebrate mt
		     # 5:ciliate nuclear
		     # 6:echinoderm mt
		     # 7:euplotid mt
		     # 8:alternative yeast nu.
		     # 9:ascidian mt
		     #10:blepharisma nu
		     # these correspond to 1-11 in the genbank transl table
		     
		     'icode'    => [ 0..10], 
		     
		     'Mgene'    => [0,1], # 0:rates, 1:separate
		     
		     'fix_kappa'=> [0,1], # 0:estimate kappa, 1:fix kappa
		     'kappa'    => '2',   # initial or fixed kappa
		     'fix_omega'=> [0,1], # 0: estimate omega, 1: fix omega
		     'omega'    => '1', # initial or fixed omega for 
		                          # codons or codon-base AAs
		     'fix_alpha'=> [1,0], # 0: estimate gamma shape param
		                          # 1: fix it at alpha
		     'alpha'    => '0.', # initial or fixed alpha
		                        # 0: infinity (constant rate)
		     'Malpha'   => [0,1], # different alphas for genes
		     'ncatG'    => [1..10], # number of categories in 
		                        # dG of NSsites models

		     # (clock)
		     # 0: no clock, 1: global clock, 2: local clock
		     # 3: TipDate
		     'clock'    => [0..3],
		     # (getSE) Standard Error: 
		     # 0:don't want them, 1: want S.E.
		     'getSE'    => [0,1], 
		     # (RateAncestor) 
		     # 0,1,2 rates (alpha>0) or
		     # ancestral states (1 or 2)
		     'RateAncestor' => [1,0,2], 
		     'Small_Diff'    => '.5e-6',
                     # (cleandata) remove sites with ambiguity data
		     # 1: yes, 0:no 
		     'cleandata'     => [0,1], 
		     # this is the number of datasets in
		     # the file - we would need to change
		     # our api to allow >1 alignment object
		     # to be referenced at time
		     'ndata'         => 1,
		     # (method) 
		     # 0: simultaneous,1: 1 branch at a time
		     'method'        => [0,1], 

		     # allow branch lengths to be fixed
		     # 0 ignore
		     # -1 use random starting points
		     # 1 use the branch lengths in initial ML iteration
		     # 2 branch lengths are fixed
		     'fix_blength'   => [0,-1,1,2],
		     );
}

=head2 program_name

 Title   : program_name
 Usage   : $factory->program_name()
 Function: holds the program name
 Returns:  string
 Args    : None

=cut

sub program_name {
        return 'codeml';
}

=head2 program_dir

 Title   : program_dir
 Usage   : ->program_dir()
 Function: returns the program directory, obtained from ENV variable.
 Returns:  string
 Args    :

=cut

sub program_dir {
        return Bio::Root::IO->catfile($ENV{PAMLDIR}) if $ENV{PAMLDIR};
}


=head2 new

 Title   : new
 Usage   : my $obj = Bio::Tools::Run::Phylo::PAML::Codeml->new();
 Function: Builds a new Bio::Tools::Run::Phylo::PAML::Codeml object 
 Returns : Bio::Tools::Run::Phylo::PAML::Codeml
 Args    : -alignment => the Bio::Align::AlignI object
           -save_tempfiles => boolean to save the generated tempfiles and
                              NOT cleanup after onesself (default FALSE)
           -tree => the Bio::Tree::TreeI object
           -branchlengths => 0: ignore any branch lengths found on the tree
                             1: use as initial values
                             2: fix branch lengths
           -params => a hashref of PAML parameters (all passed to set_parameter)
           -executable => where the codeml executable resides

See also: L<Bio::Tree::TreeI>, L<Bio::Align::AlignI>

=cut

sub new {
  my($class,@args) = @_;

  my $self = $class->SUPER::new(@args);
  $self->{'_branchLengths'} = 0;
  my ($aln, $tree, $st, $params, $exe, 
      $ubl) = $self->_rearrange([qw(ALIGNMENT TREE SAVE_TEMPFILES 
				    PARAMS EXECUTABLE BRANCHLENGTHS)],
				    @args);
  defined $aln && $self->alignment($aln);
  defined $tree && $self->tree($tree, branchLengths => ($ubl || 0) );
  defined $st  && $self->save_tempfiles($st);
  defined $exe && $self->executable($exe);

  $self->set_default_parameters();
  if( defined $params ) {
      if( ref($params) !~ /HASH/i ) { 
	  $self->warn("Must provide a valid hash ref for parameter -FLAGS");
      } else {
	  map { $self->set_parameter($_, $$params{$_}) } keys %$params;
      }
  }
  return $self;
}


=head2 prepare

 Title   : prepare
 Usage   : my $rundir = $codeml->prepare($aln);
 Function: prepare the codeml analysis using the default or updated parameters
           the alignment parameter must have been set
 Returns : value of rundir
 Args    : L<Bio::Align::AlignI> object,
	   L<Bio::Tree::TreeI> object [optional]

=cut

sub prepare{
   my ($self,$aln,$tree) = @_;
   unless ( $self->save_tempfiles ) {
       # brush so we don't get plaque buildup ;)
       $self->cleanup();
   }
   $tree = $self->tree unless $tree;
   $aln  = $self->alignment unless $aln;
   if( ! $aln ) { 
       $self->warn("must have supplied a valid alignment file in order to run codeml");
       return 0;
   }
   my ($tempdir) = $self->tempdir();
   my ($tempseqFH,$tempseqfile);
   if( ! ref($aln) && -e $aln ) { 
       $tempseqfile = $aln;
   } else { 
       ($tempseqFH,$tempseqfile) = $self->io->tempfile
	   ('-dir' => $tempdir, 
	    UNLINK => ($self->save_tempfiles ? 0 : 1));
       my $alnout = Bio::AlignIO->new('-format'      => 'phylip',
				     '-fh'          => $tempseqFH,
                                     '-interleaved' => 0,
                                     '-idlength'    => $MINNAMELEN > $aln->maxdisplayname_length() ? $MINNAMELEN : $aln->maxdisplayname_length() +1);
       
       $alnout->write_aln($aln);
       $alnout->close();
       undef $alnout;   
       close($tempseqFH);
   }
   # now let's print the codeml.ctl file.
   # many of the these programs are finicky about what the filename is 
   # and won't even run without the properly named file.  Ack
   
   my $codeml_ctl = "$tempdir/codeml.ctl";
   open(CODEML, ">$codeml_ctl") or $self->throw("cannot open $codeml_ctl for writing");
   print CODEML "seqfile = $tempseqfile\n";
   my $outfile = $self->outfile_name;
   print CODEML "outfile = $outfile\n";

   if( $tree ) {
       my ($temptreeFH,$temptreefile);
       if( ! ref($tree) && -e $tree ) { 
	   $temptreefile = $tree;
       } else { 
	   ($temptreeFH,$temptreefile) = $self->io->tempfile
	       ('-dir' => $tempdir, 
		UNLINK => ($self->save_tempfiles ? 0 : 1));
	   
	   my $treeout = Bio::TreeIO->new('-format' => 'newick',
					  '-fh'     => $temptreeFH);
	   $treeout->write_tree($tree);
	   $treeout->close();
	   close($temptreeFH);
       }
       print CODEML "treefile = $temptreefile\n";
   }

   my %params = $self->get_parameters;
   while( my ($param,$val) = each %params ) {
       next if $param eq 'outfile';
       print CODEML "$param = $val\n";
   }
   close(CODEML);
#    my ($rc,$parser) = (1);
#    {
#        my $cwd = cwd();
#        my $exit_status;
#        chdir($tempdir);
#    }
   return $tempdir;
}



=head2 run

 Title   : run
 Usage   : my ($rc,$parser) = $codeml->run($aln,$tree);
 Function: run the codeml analysis using the default or updated parameters
           the alignment parameter must have been set
 Returns : Return code, L<Bio::Tools::Phylo::PAML>
 Args    : L<Bio::Align::AlignI> object,
	   L<Bio::Tree::TreeI> object [optional]


=cut

sub run {
   my ($self) = shift;;
   my $outfile = $self->outfile_name;
   my $tmpdir = $self->prepare(@_);
   
   my ($rc,$parser) = (1);
   {
       my $cwd = cwd();
       my $exit_status;
       chdir($tmpdir);
       my $codemlexe = $self->executable();
       $self->throw("unable to find or run executable for 'codeml'") unless $codemlexe && -e $codemlexe && -x _;
       my $run;
       if( $self->{'_branchLengths'} ) { 
	   open($run, "echo $self->{'_branchLengths'} | $codemlexe |") or $self->throw("Cannot open exe $codemlexe");
       } else {
	   open($run, "$codemlexe |") or $self->throw("Cannot open exe $codemlexe");
       }
       my @output = <$run>;
       $exit_status = close($run);
       $self->error_string(join('',@output));
       if( (grep { /\berr(or)?: /io } @output)  || !$exit_status) {
	   $self->warn("There was an error - see error_string for the program output");
	   $rc = 0;
       }
       eval {
	   $parser = Bio::Tools::Phylo::PAML->new(-file => "$tmpdir/$outfile",
						  -verbose => $self->verbose,
						  -dir => "$tmpdir");
       };
       if( $@ ) {
	   $self->warn($self->error_string);
       }
       chdir($cwd);
   }
   return ($rc,$parser);
}

=head2 error_string

 Title   : error_string
 Usage   : $obj->error_string($newval)
 Function: Where the output from the last analysus run is stored.
 Returns : value of error_string
 Args    : newvalue (optional)


=cut

sub error_string{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'error_string'} = $value;
    }
    return $self->{'error_string'};

}

=head2 alignment

 Title   : alignment
 Usage   : $codeml->align($aln);
 Function: Get/Set the L<Bio::Align::AlignI> object
 Returns : L<Bio::Align::AlignI> object
 Args    : [optional] L<Bio::Align::AlignI>
 Comment : We could potentially add support for running directly on a file
           but we shall keep it simple
 See also: L<Bio::SimpleAlign>

=cut

sub alignment{
   my ($self,$aln) = @_;

   if( defined $aln ) { 
       if( -e $aln ) { 
	   $self->{'_alignment'} = $aln;
       } elsif( !ref($aln) || ! $aln->isa('Bio::Align::AlignI') ) { 
	   $self->warn("Must specify a valid Bio::Align::AlignI object to the alignment function not $aln");
	   return undef;
       } else {
	   $self->{'_alignment'} = $aln;
       }
   }
   return  $self->{'_alignment'};
}

=head2 tree

 Title   : tree
 Usage   : $codeml->tree($tree, %params);
 Function: Get/Set the L<Bio::Tree::TreeI> object
 Returns : L<Bio::Tree::TreeI> 
 Args    : [optional] $tree => L<Bio::Tree::TreeI>,
           [optional] %parameters => hash of tree-specific parameters:
                  branchLengths: 0, 1 or 2
                  out

 Comment : We could potentially add support for running directly on a file
           but we shall keep it simple
 See also: L<Bio::Tree::Tree>

=cut

sub tree {
   my ($self, $tree, %params) = @_;
   if( defined $tree ) { 
       if( ! ref($tree) || ! $tree->isa('Bio::Tree::TreeI') ) { 
	   $self->warn("Must specify a valid Bio::Tree::TreeI object to the alignment function");
       }
       $self->{'_tree'} = $tree;
       if ( defined $params{'_branchLengths'} ) {
	 my $ubl = $params{'_branchLengths'};
	 if ($ubl !~ m/^(0|1|2)$/) {
	   $self->throw("The branchLengths parameter to tree() must be 0 (ignore), 1 (initial values) or 2 (fixed values) only");
	 }
	 $self->{'_branchLengths'} = $ubl;
       }
   }
   return $self->{'_tree'};
}

=head2 get_parameters

 Title   : get_parameters
 Usage   : my %params = $self->get_parameters();
 Function: returns the list of parameters as a hash
 Returns : associative array keyed on parameter names
 Args    : none


=cut

sub get_parameters{
   my ($self) = @_;
   # we're returning a copy of this
   return %{ $self->{'_codemlparams'} };
}


=head2 set_parameter

 Title   : set_parameter
 Usage   : $codeml->set_parameter($param,$val);
 Function: Sets a codeml parameter, will be validated against
           the valid values as set in the %VALIDVALUES class variable.  
           The checks can be ignored if one turns off param checks like this:
             $codeml->no_param_checks(1)
 Returns : boolean if set was success, if verbose is set to -1
           then no warning will be reported
 Args    : $param => name of the parameter
           $value => value to set the parameter to
 See also: L<no_param_checks()>

=cut

sub set_parameter{
   my ($self,$param,$value) = @_;
   unless (defined $self->{'no_param_checks'} && $self->{'no_param_checks'} == 1) {
       if ( ! defined $VALIDVALUES{$param} ) { 
           $self->warn("unknown parameter $param will not be set unless you force by setting no_param_checks to true");
           return 0;
       } 
       if ( ref( $VALIDVALUES{$param}) =~ /ARRAY/i &&
            scalar @{$VALIDVALUES{$param}} > 0 ) {
       
           unless ( grep { $value eq $_ } @{ $VALIDVALUES{$param} } ) {
               $self->warn("parameter $param specified value $value is not recognized, please see the documentation and the code for this module or set the no_param_checks to a true value");
               return 0;
           }
       }
   }
   $self->{'_codemlparams'}->{$param} = $value;
   return 1;
}

=head2 set_default_parameters

 Title   : set_default_parameters
 Usage   : $codeml->set_default_parameters(0);
 Function: (Re)set the default parameters from the defaults
           (the first value in each array in the 
	    %VALIDVALUES class variable)
 Returns : none
 Args    : boolean: keep existing parameter values


=cut

sub set_default_parameters{
   my ($self,$keepold) = @_;
   $keepold = 0 unless defined $keepold;
   
   while( my ($param,$val) = each %VALIDVALUES ) {
       # skip if we want to keep old values and it is already set
       next if( defined $self->{'_codemlparams'}->{$param} && $keepold);
       if(ref($val)=~/ARRAY/i ) {
	   $self->{'_codemlparams'}->{$param} = $val->[0];
       }  else { 
	   $self->{'_codemlparams'}->{$param} = $val;
       }
   }
}


=head1 Bio::Tools::Run::WrapperBase methods

=cut

=head2 no_param_checks

 Title   : no_param_checks
 Usage   : $obj->no_param_checks($newval)
 Function: Boolean flag as to whether or not we should
           trust the sanity checks for parameter values  
 Returns : value of no_param_checks
 Args    : newvalue (optional)


=cut

sub no_param_checks{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'no_param_checks'} = $value;
    }
    return $self->{'no_param_checks'};
}


=head2 save_tempfiles

 Title   : save_tempfiles
 Usage   : $obj->save_tempfiles($newval)
 Function: 
 Returns : value of save_tempfiles
 Args    : newvalue (optional)


=cut

=head2 outfile_name

 Title   : outfile_name
 Usage   : my $outfile = $codeml->outfile_name();
 Function: Get/Set the name of the output file for this run
           (if you wanted to do something special)
 Returns : string
 Args    : [optional] string to set value to


=cut

sub outfile_name {
    my $self = shift;
    if( @_ ) {
	return $self->{'_codemlparams'}->{'outfile'} = shift @_;
    }
    unless (defined $self->{'_codemlparams'}->{'outfile'}) {
        $self->{'_codemlparams'}->{'outfile'} = 'mlc';
    }
    return $self->{'_codemlparams'}->{'outfile'};    
}

=head2 tempdir

 Title   : tempdir
 Usage   : my $tmpdir = $self->tempdir();
 Function: Retrieve a temporary directory name (which is created)
 Returns : string which is the name of the temporary directory
 Args    : none


=cut

=head2 cleanup

 Title   : cleanup
 Usage   : $codeml->cleanup();
 Function: Will cleanup the tempdir directory after a PAML run
 Returns : none
 Args    : none


=cut

=head2 io

 Title   : io
 Usage   : $obj->io($newval)
 Function:  Gets a L<Bio::Root::IO> object
 Returns : L<Bio::Root::IO>
 Args    : none


=cut

sub DESTROY {
    my $self= shift;
    unless ( $self->save_tempfiles ) {
	$self->cleanup();
    }
    $self->SUPER::DESTROY();
}

1;
