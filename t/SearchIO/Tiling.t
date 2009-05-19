#-*-perl-*-
#$Id: t.pl 420 2009-05-18 04:11:18Z maj $
use strict;
BEGIN {
    use lib '.';
    use Bio::Root::Test;
    test_begin(-tests => 19);
}

use_ok('Bio::Search::Tiling::MapTiling');
use_ok('Bio::Search::Tiling::MapTileUtils');
use_ok('Bio::SearchIO');
use_ok('Bio::Search::Hit::BlastHit');
use_ok('File::Spec');


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

# more to come

