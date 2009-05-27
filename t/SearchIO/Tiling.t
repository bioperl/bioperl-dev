#-*-perl-*-
#$Id$
use strict;
BEGIN {
    use lib '.';
    use lib '../..';
    use Bio::Root::Test;
    test_begin(-tests => 1000 );
}

use_ok('Bio::Search::Tiling::MapTiling');
use_ok('Bio::Search::Tiling::MapTileUtils');
use_ok('Bio::SearchIO');
use_ok('Bio::Search::Hit::BlastHit');
use_ok('File::Spec');

chdir('../..');

ok( my $parser = new Bio::SearchIO( 
	-file=>test_input_file('dcr1_sp.WUBLASTP'),
	-format=>'blast'), 'parse data file');

my $result = $parser->next_result;
while ( $_ = $result->next_hit ) {
    last if $_->name =~ /ASPTN/;
}
ok(my $test_hit = $_, 'got test hit');
ok(my $tiling = Bio::Search::Tiling::MapTiling->new($test_hit), 'create tiling');


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


my %examples = (
    'BLASTN' => ['blast', 'AE003528_ecoli.bls',
		 [1,-1, undef, undef],
		 [1,-1, 1, 1]],
    'BLASTP' => ['blast', 'catalase-webblast.BLASTP',
		 [undef, undef, undef, undef],
		 [1, undef, undef, undef]],
    'BLASTX' => ['blast', 'dnaEbsub_ecoli.wublastx',
		 [1, undef, undef, undef],
		 [undef, 1, undef, 1]],
    'TBLASTN'=> ['blast', 'dnaEbsub_ecoli.wutblastn',
		 [undef, 1, undef, 1],
		 [1, undef, 1, undef]],
    'TBLASTX'=> ['blast', 'dnaEbsub_ecoli.wutblastx',
		 [1, 1, 0, 1],
		 [1, -2, 3, 3]],
    'FASTA'  => ['fasta', 'cysprot_vs_gadfly.FASTA',
		 [undef, undef, undef, undef],
		 [1, undef, undef, undef]],
    'FASTXY'  => ['fasta', '5X_1895.FASTXY',
		 [1, undef, undef, undef],
		 [undef, 1, undef, 1]],
    'MEGABLAST' => ['blast', '503384.MEGABLAST.2',
		 [1,-1, undef, undef],
		 [1,-1, 1, 1]],
    'TFASTA' => undef,
    'TFASTX' => undef
    );

my %results;

foreach (keys %examples) {
    next unless $examples{$_};
    ok( my $blio = Bio::SearchIO->new( -format=>$examples{$_}[0],
				       -file  =>test_input_file($examples{$_}[1])), 
	"$_ data file");
    my $hit = ($results{$_} = $blio->next_result)->next_hit;
    ok( $tiling = Bio::Search::Tiling::MapTiling->new($hit, @{$examples{$_}[2]}), "tiling object created for $_ hit");
    dies_ok { Bio::Search::Tiling::MapTiling->new($hit, @{$examples{$_}[3]}) } "tiling object arg exception check for $_ hit";
    1;
}

# tricky wu-blast
ok (my $blio = Bio::SearchIO->new( -format=>'blast', 
			       -file=>test_input_file('tricky.wublast')),
    'tricky.wublast')
ok( $tiling = Bio::Search::Tiling::MapTiling->new($blio->next_result->next_hit), 'tricky tiling');
my @map = $tiling->coverage_map_as_text('query',1);
@map = $tiling->coverage_map_as_text('hit',1);

ok (my $blio = Bio::SearchIO->new( -format=>'blast', 
			       -file=>test_input_file('frac_problems.blast')),
    'frac_problems.blast')
ok( $tiling = Bio::Search::Tiling::MapTiling->new($blio->next_result->next_hit), 'frac_problems tiling');

ok (my $blio = Bio::SearchIO->new( -format=>'blast', 
			       -file=>test_input_file('frac_problems.blast')),
    'frac_problems2.blast')
ok( $tiling = Bio::Search::Tiling::MapTiling->new($blio->next_result->next_hit), 'frac_problems2 tiling');

ok (my $blio = Bio::SearchIO->new( -format=>'blast', 
			       -file=>test_input_file('frac_problems.blast')),
    'frac_problems3.blast')
ok( $tiling = Bio::Search::Tiling::MapTiling->new($blio->next_result->next_hit), 'frac_problems3 tiling');

# old blast.t tiling tests


1;

    

