#-*-perl-*-
#$Id$
# testing StandAloneBlastPlus.pm

use strict;
use warnings;
our $home;
BEGIN {
    use Bio::Root::Test;
#    use lib '../../live';
    $home = '../lib'; # set to '.' for Build use,
                     # '../lib' for debugging from .t file
    unshift @INC, $home;
    test_begin(-tests => 100,
	       -requires_modules => [qw( 
                                      Bio::Tools::Run::BlastPlus
                                      )]);
}

use_ok( 'Bio::Tools::Run::StandAloneBlastPlus' );
use_ok( 'Bio::Tools::Run::WrapperBase' );
use_ok( 'Bio::Tools::Run::WrapperBase::CommandExts' );
use Bio::SeqIO;
use Bio::AlignIO;

## for testing; remove following line for production....
$ENV{BLASTPLUSDIR} = "C:\\Program\ Files\\NCBI\\blast-2.2.22+\\bin";

ok my $bpfac = Bio::Tools::Run::BlastPlus->new(-command => 'makeblastdb'), 
    "BlastPlus factory";

SKIP : {
    test_skip( -tests => 1,
	       -requires_env => 'BLASTPLUSDIR',
	       -requires_executable => $bpfac);
    diag('DB and mask make tests');
# to test:
# make a db - from fasta file, array of seq, seqio, alnio objects
# make a db with mask data
# make temp db, make sticky db
# check tempfile cleanup
# db attribute/info tests
# check correct db type
# exceptions/warnings

# testing using fasta files as input...
    ok my $fac = Bio::Tools::Run::StandAloneBlastPlus->new(
	-db_data => test_input_file('test-spa.fas'),
	-create => 1
	), "make factory";
    ok $fac->make_db, "test db made with fasta";
    like $fac->db, qr/DB.{5}/, "temp db";
    is ($fac->db_type, 'nucl', "right type");
    $fac->cleanup;
if (0) {    
    ok $fac = Bio::Tools::Run::StandAloneBlastPlus->new(
	-db_name => 'test', 
	-db_data => test_input_file('test-spa.fas'),
	-create => 1
	);
    
    ok $fac->make_db, "named db made";
    ok $fac->check_db, "check_db";
    is $fac->db, 'test', "correct name";
    is ref $fac->db_info, 'HASH', "dbinfo hash returned";
    is $fac->db_type, 'nucl', "correct type";
    
    ok $fac->make_mask(
	-data=>test_input_file('test-spa.fas'), 
	-masker=>'windowmasker'), "windowmasker mask made";
    ok $fac->make_mask(
	-data=>test_input_file('test-spa.fas'), 
	-masker=>'dustmasker'), "dustmasker mask made";

    $fac = Bio::Tools::Run::StandAloneBlastPlus->new(
	-db_data => test_input_file('test-spa-p.fas'),
	-create => 1
	);
    ok $fac->check_db('test'), "check_db with arg";
    is $fac->db_info('test')->{_db_type}, 'nucl', "db_info with arg";
    ok $fac->make_db, "protein db made";
    is $fac->db_type, 'prot', "correct type";
    ok $fac->make_mask(-data=>$fac->db, -masker=>'segmasker'), "segmasker mask made";
    ok $fac->make_mask(
	-data=>$fac->db, 
	-masker=>'segmasker'), "segmasker mask made; blastdb as data";
    
    $fac->cleanup;
    
    ok $fac = Bio::Tools::Run::StandAloneBlastPlus->new(
	-db_data => test_input_file('test-spa-p.fas'),
	-mask_file => test_input_file('segmask_data.asn'),
	-create => 1
	);
    ok $fac->make_db, "protein db made with pre-built mask";
    is $fac->db_filter_algorithms->[0]{algorithm_name}, 'seg', "db_info records mask info";
    $fac->cleanup;
    

    ok $fac = Bio::Tools::Run::StandAloneBlastPlus->new(
	-db_data => test_input_file('test-spa.fas'),
	-masker=>'windowmasker',
	-mask_data => test_input_file('test-spa.fas'),
	-create => 1
	);
    $fac->no_throw_on_crash(1);

    ok $fac->make_db, "mask built and db made on construction (windowmasker)";
    $fac->cleanup;
    
    ok $fac = Bio::Tools::Run::StandAloneBlastPlus->new(
	-db_data => test_input_file('test-spa-p.fas'),
	-masker=>'segmasker',
	-mask_data => test_input_file('test-spa-p.fas'),
	-create => 1
	);
    $fac->no_throw_on_crash(1);
    ok $fac->make_db, "mask built and db made on construction (segmasker)";
    $fac->cleanup;
    
    ok $fac = Bio::Tools::Run::StandAloneBlastPlus->new(
	-db_data => test_input_file('test-spa.fas'),
	-masker=>'dustmasker',
	-mask_data => test_input_file('test-spa.fas'),
	-create => 1
	);
    $fac->no_throw_on_crash(1);
    ok $fac->make_db, "mask built and db made on construction (dustmasker)";
    $fac->cleanup;
    $fac->_register_temp_for_cleanup('test');
    $fac->cleanup;
    # tests with Bio:: objects as input
}
    ok my $sio = Bio::SeqIO->new(-file => test_input_file('test-spa.fas'));
    ok my $aio = Bio::AlignIO->new(-file => test_input_file('test-spa-p.fas'));

    ok $fac = Bio::Tools::Run::StandAloneBlastPlus->new(
	-db_name => 'siodb',
	-db_data => $sio,
	-create => 1
	);
    ok $fac->make_db, "make db from Bio::SeqIO";
    $fac->cleanup;
    ok $fac = Bio::Tools::Run::StandAloneBlastPlus->new(
	-db_name => 'aiodb',
	-db_data => $aio,
	-create => 1
	);
    ok $fac->make_db, "make db from Bio::AlignIO";
    $fac->cleanup;
    $DB::single=1;
    $aio = Bio::AlignIO->new(-file=>test_input_file('test-aln.msf'));
    my @seqs = $aio->next_aln->each_seq;
    ok $fac = Bio::Tools::Run::StandAloneBlastPlus->new(
	-db_name => 'aiodb',
	-db_data => \@seqs,
	-create => 1
	);
    ok $fac->make_db, 'make db from \@seqs';

    $fac->_register_temp_for_cleanup( 'aiodb', 'siodb' );
    $fac->cleanup;

    # exception tests here someday.

} # SKIP to here

sub test_input_file { "data/".shift }
1;
