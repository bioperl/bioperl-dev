#-*-perl-*-
#$Id$
use strict;
BEGIN {
    use lib '.';
    use lib '../..';
    use Bio::Root::Test;
    test_begin(-tests => 6488 );
}

use_ok('Bio::Search::Tiling::MapTiling');
use_ok('Bio::Search::Tiling::MapTileUtils');
use_ok('Bio::SearchIO');
use_ok('Bio::Search::Hit::BlastHit');
use_ok('File::Spec');

my ($blio, $result, $hit, $tiling, $hsp);
my @normal_formats = qw( blast  wublast
                         blastn wublastn
                         blastp wublastp
                         multiblast 
                         megablast
                         rpsblast
                         psiblast );
my @xltd_formats  = qw(  blastx wublastx
                         tblastn wutblastn
                         tblastx wutblastx );
                         
                         
my %test_files = (
    'blast' => [qw(
               ecolitst.bls
               ecolitst.bls
               frac_problems.blast
               frac_problems2.blast
               frac_problems3.blast
               bl2seq.out
               )],
    'multiblast' => [qw(
               multi_blast.bls
               )],
    'blastn' => [qw(
               a_thaliana.blastn
               bl2seq.blastn
               new_blastn.txt
               hsinsulin.blastcl3.blastn
               )],
    'wublastn' =>[qw(
               brassica_ATH.WUBLASTN
               echofilter.wublastn
               )],
    'blastp' => [qw(
               blastp2215.blast
               no_hsps.blastp
               catalase-webblast.BLASTP
               )],
    'wublastp' => [qw(
               dcr1_sp.WUBLASTP
               ecolitst.wublastp
               contig-by-hand.wublastp
               ecolitst.noseqs.wublastp
               )],
    'blastx' => [qw(
               bl2seq.blastx.out
               )],
    'wublastx' => [qw(
               dnaEbsub_ecoli.wublastx
               )],
    'wublast' => [qw(
               tricky.wublast
               )],
    'tblastn' => [qw(
               tblastn.out
               1ZZ19XR301R-Alignment.tblastn
               )],
    'wutblastn' => [qw(
               dnaEbsub_ecoli.wutblastn
               )],
    'tblastx' => [qw(
               bl2seq.tblastx.out
               HUMBETGLOA.tblastx
               )],
    'wutblastx' => [qw(
               dnaEbsub_ecoli.wutblastx
               )],
    'megablast' => [qw(
               503384.MEGABLAST.2
               )],
    'rpsblast' => [qw(
               ecoli_domains.rpsblast
               )],
    'psiblast' => [qw(
               psiblastreport.out
               )]
    );

ok( $blio = new Bio::SearchIO( 
	-file=>test_input_file('dcr1_sp.WUBLASTP'),
	-format=>'blast'), 'parse data file');

$result = $blio->next_result;
while ( $_ = $result->next_hit ) {
    last if $_->name =~ /ASPTN/;
}
ok($hit = $_, 'got test hit');
ok($tiling = Bio::Search::Tiling::MapTiling->new($hit), 'create tiling');


# TilingI compliance

isa_ok($tiling, 'Bio::Search::Tiling::TilingI');
foreach ( qw( next_tiling rewind_tilings identities conserved length ) ) {
    ok( $tiling->$_, "implements '$_'" );
}

# regression test on original calculations

my @orig_id_results = ( 387,388,388,381,382,389 );
my @orig_cn_results = ( 622,619,628,608,611,613 );
my @id_results = (
    $tiling->identities('query', 'exact'),
    $tiling->identities('query', 'est'),
    $tiling->identities('query', 'max'),
    $tiling->identities('subject', 'exact'),
    $tiling->identities('subject', 'est'),
    $tiling->identities('subject', 'max')
    );
my @cn_results = (
    $tiling->conserved('query', 'exact'),
    $tiling->conserved('query', 'est'),
    $tiling->conserved('query', 'max'),
    $tiling->conserved('subject', 'exact'),
    $tiling->conserved('subject', 'est'),
    $tiling->conserved('subject', 'max')
    );
map { $_ = int($_) } @id_results, @cn_results;

is_deeply(\@id_results, \@orig_id_results, 'identities regression test');
is_deeply(\@cn_results, \@orig_cn_results, 'conserved regression test');

# tiling iterator regression tests

my ($qn, $sn)=(0,0);
while ($tiling->next_tiling('query')) {$qn++};
while ($tiling->next_tiling('subject')) {$sn++};
is ($qn, 8, 'tiling iterator regression test(1)');
is ($sn, 128, 'tiling iterator regression test(2)');
$tiling->rewind('subject');
while ($tiling->next_tiling('subject')) {$sn++};
is ($sn, 256, 'tiling iterator regression test(3, rewind)');

# test the filters and filter checking
# arrays are of the form
# [$format, $file, \@living_filters, \@dying_filters]
# @filters = ($qstrand, $hstrand, $qframe, $hframe)


# my %examples = (
#     'BLASTN' => ['blast', 'AE003528_ecoli.bls'],
#     'BLASTP' => ['blast', 'catalase-webblast.BLASTP'],
#     'BLASTX' => ['blast', 'dnaEbsub_ecoli.wublastx'],
#     'TBLASTN'=> ['blast', 'dnaEbsub_ecoli.wutblastn'],
#     'TBLASTX'=> ['blast', 'dnaEbsub_ecoli.wutblastx'],
#     'FASTA'  => ['fasta', 'cysprot_vs_gadfly.FASTA'],
#     'FASTXY'  => ['fasta', '5X_1895.FASTXY'],
#     'MEGABLAST' => ['blast', '503384.MEGABLAST.2'],
#     'TFASTA' => undef,
#     'TFASTX' => undef
#     );

# my %results;

# foreach (keys %examples) {
#     next unless $examples{$_};
#     ok( $blio = Bio::SearchIO->new( -format=>$examples{$_}[0],
# 				       -file  =>test_input_file($examples{$_}[1])), 
# 	"$_ data file");
#     my $hit = ($results{$_} = $blio->next_result)->next_hit;
# }

diag("Old blast.t tiling tests");

ok($blio = Bio::SearchIO->new(
    '-format' => 'blast',
    '-file'   => test_input_file('ecolitst.wublastp')
   ), "ecolitst.wublastp");
$result = $blio->next_result;
$result->next_hit;
$hit = $result->next_hit;
$tiling = Bio::Search::Tiling::MapTiling->new($hit);
# Test HSP contig data returned by SearchUtils::tile_hsps()
# Second hit has two hsps that overlap.

# compare with the contig made by hand for these two contigs
# in t/data/contig-by-hand.wublastp
# (in this made-up file, the hsps from ecolitst.wublastp
#  were aligned and contiged, and Length, Identities, Positives 
#  were counted, by a human (maj) )
	
my $hand_hit = Bio::SearchIO->new(
    -format=>'blast', 
    -file=>test_input_file('contig-by-hand.wublastp')
    )->next_result->next_hit;
my $hand_hsp = $hand_hit->next_hsp;
my @hand_qrng = $hand_hsp->range('query');
my @hand_srng = $hand_hsp->range('hit');
my @hand_matches = $hand_hit->matches;

is(($tiling->range('query'))[0], $hand_qrng[0]);
is(($tiling->range('query'))[1], $hand_qrng[1]);
is(sprintf("%d",$tiling->identities('query')), $hand_matches[0]);
is(sprintf("%d",$tiling->conserved('query')), $hand_matches[1]);
is(($tiling->range('hit'))[0], $hand_srng[0]);
is(($tiling->range('hit'))[1], $hand_srng[1]);
is(sprintf("%d",$tiling->identities('hit')), $hand_matches[0]);
is(sprintf("%d",$tiling->conserved('hit')), $hand_matches[1]);

ok( $blio = Bio::SearchIO->new(
	'-format' => 'blast',
	'-file'   => test_input_file('dnaEbsub_ecoli.wublastx')
    ), "dnaEbsub_ecoli.wublastx");

$hit = $blio->next_result->next_hit;
my $tiling = Bio::Search::Tiling::MapTiling->new($hit);
is(sprintf("%.3f",$tiling->frac_identical(-type=>'query',-denom=>'aligned',-context=>'p2')), '0.364');
is(sprintf("%.3f",$tiling->frac_identical(-type=>'hit',-denom=>'aligned',-context=>'all')), '0.366');
is(sprintf("%.3f",$tiling->frac_conserved(-type=>'query',-denom=>'aligned',-context=>'p2')), '0.537');
is(sprintf("%.3f",$tiling->frac_conserved(-type=>'hit',-denom=>'aligned',-context=>'all')), '0.540');
is(sprintf("%.2f",$tiling->frac_aligned_query(-context=>'p2')), '0.62');
is(sprintf("%.2f",$tiling->frac_aligned_hit(-context=>'all')), '0.71');

ok( $blio = Bio::SearchIO->new(
	'-format' => 'blast',
	'-file'   => test_input_file('tricky.wublast')
    ), "tricky.wublast");

$hit = $blio->next_result->next_hit;
$tiling = Bio::Search::Tiling::MapTiling->new($hit);
cmp_ok sprintf("%.3f",$tiling->frac_identical(-denom => 'aligned')), '>', 0.2, 'tricky.wublast(1)';
cmp_ok sprintf("%.3f",$tiling->frac_conserved(-denom => 'aligned')), '<=', 1, 'tricky.wublast(2)';
is(sprintf("%.2f",$tiling->frac_aligned_query), '0.92', 'tricky.wublast(3)');
is(sprintf("%.2f",$tiling->frac_aligned_hit), '0.91','tricky.wublast(4)');

diag("New tiling tests");

foreach my $alg (@normal_formats) {
    diag("*******$alg files*******");
    foreach my $tf (@{$test_files{$alg}}) {
	ok( $blio = Bio::SearchIO->new( -format=>'blast', 
					-file=>test_input_file($tf)
	    ), "$tf" );
	$result = $blio->next_result;
	my $hit_count = 0;
	# compare the per-aligned-base identity avg over hsps
	# with frac_identical (bzw, conserved)

      HIT:
	while ( $hit = $result->next_hit ) {
	    ++$hit_count;
	    # quiet the "No HSPs" warning with -verbose => -1
	    ok( $tiling = Bio::Search::Tiling::MapTiling->new(-hit=>$hit,-verbose=>-1), "tile $tf hit $hit_count #hsps ".scalar $tiling->hsps );
	    my @hsps = $tiling->hsps;

	    unless (@hsps) {
		diag( "--no hsps for $tf hit $hit_count");
		next HIT;
	    }
	    my ($dpct, $est, $fast,$exact, $max);
	    my $tol = 0.10; # % difference accepted as approx. equal

	    if (@hsps == 1) {
		# equality
		($dpct, $est, $fast) = $tiling->cmp_frac('query','identical','aligned', 'est', 'fast');
		is( $est,$fast, "q id: est ($est) = fast ($fast)");
		($dpct, $est, $fast) = $tiling->cmp_frac('hit','identical','aligned', 'est', 'fast');
		is( $est,$fast, "h id: est ($est) = fast ($fast)");
		($dpct, $est, $fast) = $tiling->cmp_frac('query','conserved','aligned', 'est', 'fast');
		is( $est,$fast, "q cn: est ($est) = fast ($fast)");
		($dpct, $est, $fast) = $tiling->cmp_frac('hit','conserved','aligned', 'est', 'fast');
		is( $est,$fast, "h cn: est ($est) = fast ($fast)");
	    }
	    else {
		# comparisons
		($dpct, $est, $fast) = $tiling->cmp_frac('query','identical','aligned', 'est', 'fast');
#		cmp_ok( $dpct, "<", $tol, "q id: est ($est) ~ fast ($fast)");
		($dpct, $exact, $max) = $tiling->cmp_frac('query','identical','aligned', 'exact', 'max');
		cmp_ok( abs($exact-$est)/$exact, "<" , $tol, "q id: exact ($exact) ~ est ($est)");
		cmp_ok( $exact, "<=" , $max, "q id: exact ($exact) <= max ($max)");

		($dpct, $est, $fast) = $tiling->cmp_frac('hit','identical','aligned', 'est', 'fast');
#		cmp_ok( $dpct, "<", $tol, "h id: est ($est) ~ fast ($fast)");
		($dpct, $exact, $max) = $tiling->cmp_frac('hit','identical','aligned', 'exact', 'max');
		cmp_ok(  abs($exact-$est)/$exact, "<" , $tol, "h id: exact ($exact) ~ est ($est)");
		cmp_ok( $exact, "<=" , $max, "h id: exact ($exact) <= max ($max)");

		($dpct, $est, $fast) = $tiling->cmp_frac('query','conserved','aligned', 'est', 'fast');
#		cmp_ok( $dpct, "<", $tol, "q cn: est ($est) ~ fast ($fast)");
		($dpct, $exact, $max) = $tiling->cmp_frac('query','conserved','aligned', 'exact', 'max');
		cmp_ok(  abs($exact-$est)/$exact, "<" , $tol, "q cn: exact ($exact) ~ est ($est)");
		cmp_ok( $exact, "<=" , $max, "q cn: exact ($exact) <= max ($max)");

		($dpct, $est, $fast) = $tiling->cmp_frac('hit','conserved','aligned', 'est', 'fast');
#		cmp_ok( $dpct, "<", $tol, "h cn: est ($est) ~ fast ($fast)");
		($dpct, $exact, $max) = $tiling->cmp_frac('hit', 'conserved','aligned', 'exact', 'max');
		cmp_ok(  abs($exact-$est)/$exact, "<=" , $tol, "h cn: exact ($exact) ~ est ($est)");
		cmp_ok( $exact, "<=" , $max, "h cn: exact ($exact) <= max ($max)");
	    }
	}
    }
}

# translated formats: deal with strand/frame context...

foreach my $alg (@xltd_formats) {
    diag("*******$alg files*******");
    foreach my $tf (@{$test_files{$alg}}) {
	ok( $blio = Bio::SearchIO->new( -format=>'blast', 
					-file=>test_input_file($tf)
	    ), "$tf" );
	$result = $blio->next_result;
	my $hit_count = 0;
	# compare the per-aligned-base identity avg over hsps
	# with frac_identical (bzw, conserved)
	
      HIT:
	while ( $hit = $result->next_hit ) {
	    ++$hit_count;
	    # quiet the "No HSPs" warning with -verbose => -1
	    ok( $tiling = Bio::Search::Tiling::MapTiling->new(-hit=>$hit,-verbose=>-1), "tile $tf hit $hit_count #hsps ".scalar $tiling->hsps );
	    my @hsps = $tiling->hsps;
	    
	    unless (@hsps) {
		diag( "--no hsps for $tf hit $hit_count");
		next HIT;
	    }
	    my ($dpct, $est, $fast,$exact, $max);
	    my $tol = 0.10; # % difference accepted as approx. equal
	    
	    ## loop through contexts:
	    for my $type qw( query hit ) {
		for my $context ($tiling->contexts($type)) {
		    diag(" --- $type $context ---");
		    if (scalar($tiling->contexts($type, $context)) == 1) {
			# equality
			($dpct, $est, $fast) = $tiling->cmp_frac($type,'identical','aligned', 'est', 'fast', $context);
			is( $est,$fast, substr($type,0,1)." id: est ($est) = fast ($fast)");
			($dpct, $est, $fast) = $tiling->cmp_frac($type,'conserved','aligned', 'est', 'fast', $context);
			is( $est,$fast, substr($type,0,1)." cn: est ($est) = fast ($fast)");
		    }
		    else {
			# comparisons
			($dpct, $est, $fast) = $tiling->cmp_frac($type,'identical','aligned', 'est', 'fast', $context);
#			cmp_ok( $dpct, "<", $tol, 
#				substr($type,0,1)." id: est ($est) ~ fast ($fast)");
			($dpct, $exact, $max) = $tiling->cmp_frac($type,'identical','aligned', 'exact', 'max', $context);
			cmp_ok( abs($exact-$est)/$exact, "<" , $tol, 
				substr($type,0,1)." id: exact ($exact) ~ est ($est)");
			cmp_ok( $exact, "<=" , $max, 
				substr($type,0,1)." id: exact ($exact) <= max ($max)");
			
			($dpct, $est, $fast) = $tiling->cmp_frac($type,'conserved','aligned', 'est', 'fast', $context);
#			cmp_ok( $dpct, "<", $tol, 
#				substr($type,0,1)." cn: est ($est) ~ fast ($fast)");
			($dpct, $exact, $max) = $tiling->cmp_frac($type,'conserved','aligned', 'exact', 'max', $context);
			cmp_ok(  abs($exact-$est)/$exact, "<" , $tol, 
				 substr($type,0,1)." cn: exact ($exact) ~ est ($est)");
			cmp_ok( $exact, "<=" , $max, 
				substr($type,0,1)." cn: exact ($exact) <= max ($max)");
		    }
		}
	    }
	}
    }
}

package Bio::Search::Tiling::MapTiling;

sub cmp_frac {
    my ($tiling, $type, $method, $denom, @actions) = @_;
    my ($a, $b);
    my $context = ($actions[2] ? $actions[2] : 'all');
    $a = $tiling->frac(-type=>$type, 
		       -method=>$method, 
		       -denom=>$denom,
		       -action=>$actions[0],
		       -context=>$context);
    $b = $tiling->frac(-type=>$type, 
		       -method=>$method, 
		       -denom=>$denom,
		       -action=>$actions[1],
		       -context=>$context);
    return ( abs($a-$b)/$a, f(5,$a), f(5,$b) );
}

sub f { my ($d,$val) = @_; sprintf("%.${d}f",$val) }       

    
1;

