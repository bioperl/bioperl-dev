#-*-perl-*-
# $Id$
use strict;

#chdir('../..'); # hack to allow run from t
use lib 't/lib';
use lib '../..';
use Bio::Root::Test;
test_begin( -tests => 1000 );
use_ok('Bio::PopGen::IO');
use_ok('Bio::PopGen::IO::nexml');
use_ok('Bio::Annotation::Collection');

# read
# ok( my $nexmlio = Bio::PopGen::IO(-format=>'nexml', -file=>test_input_file('01_basic.xml')) );
ok my $nexmlio = Bio::PopGen::IO->new(-format=>'nexml', -file=>'../data/01_basic.xml') ;
warning_like { $nexmlio->next_individual } qr/nexml/i ;
warning_like { $nexmlio->write_individual } qr/nexml/i ; 
warning_like { $nexmlio->write_population } qr/not open/i;
ok my $popn = $nexmlio->next_population;

my @inds = $popn->get_Individuals;
is_deeply( [map { ($_->get_Genotypes(-marker => 'c1'))[0]->get_Alleles } @inds],
	   [0, 2, 2, 0, 1, 0] );

# write

ok my $csvio = Bio::PopGen::IO->new(-format=>'csv',-fh=>\*DATA);
ok $popn = $csvio->next_population;
my $tf = test_output_file;
ok $nexmlio = Bio::PopGen::IO->new(-format=>'nexml',-file=>">$tf");

warning_like { $nexmlio->next_population } qr/not open/;

$nexmlio->write_population($popn);

1;

__DATA__
Species,locA,locB,locC,locD
Biggus dicus, A a, B B, C c, d d
Terra parvum, A A, b b, c c, D D
Acidophilus rex, a a, b b, c c, D d
Tempus fugit, a a, B b, C C, D d
Pax romanum, A a, b b, C c, d d
