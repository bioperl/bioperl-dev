#-*-perl-*-
#$Id$
#testing SoapEUtilities with network queries
# idea: reproduce the examples at
# http://www.bioperl.org/wiki/HOWTO:EUtilities_Cookbook

use strict;
use warnings;
our $home;
BEGIN {
    use Bio::Root::Test;
    use lib '.';
    $home = '..'; # set to '.' for Build use, 
                      # '..' for debugging from .t file
    unshift @INC, $home;
    test_begin(-tests => 100, # modify
	       -requires_modules => [qw(Bio::DB::ESoap
                                        Bio::DB::ESoap::WSDL
                                        Bio::DB::SoapEUtilities
                                        Bio::DB::SoapEUtilities::Result
                                        Bio::DB::SoapEUtilities::FetchAdaptor
                                        Bio::DB::SoapEUtilities::LinkAdaptor
                                        Bio::DB::SoapEUtilities::DocSumAdaptor
                                        Soap::Lite
                                        XML::Twig
                                        )]);
}

my ($fac, $result, $seqio, $seq, $i);
my @prot_ids = qw(1621261 89318838 68536103 20807972 730439);
my @prot_ids_2 = qw(828392 790 470338);
my @accns = qw(CAB02640 EAS10332 YP_250808 NP_623143 P41007);
my $lg_contig = 27479347;
my $sciname_id = 527031;
my @gene_ids = qw(828392 790 470338);
my $nbr_test_id = 1621261;
my @linkout_test_ids = qw(28864546 53828898 14523048 14336674 1817575);

SKIP : {
#    test_skip(-tests => 100, #modify
#	      -requires_networking => 1); # add back on final commit
ok $fac = Bio::DB::SoapEUtilities->new(), "SoapEUtilities factory";
    if (0) {
diag("Retrieve raw data records from GenBank, save raw data to file, then parse via Bio::SeqIO");

ok $result = $fac->efetch( -db => 'protein', -id => \@prot_ids )->run(-no_parse=>1), "do efetch";
is $result->count, 5, "fetched all";
ok $seqio = Bio::DB::SoapEUtilities::FetchAdaptor->new(-result=>$result), "create adaptor";
for ($i=0; $seq = $seqio->next_seq; $i++) {1;}
is $i, 5, "iterated all seq objs";

diag("Get accessions (actually accession.versions) for a list of GenBank IDs (GIs)");
# SOAP server doesn't seem to like 'acc' as a rettype, get in fasta format
# and use the result accessors
ok $fac->efetch->set_parameters(-db=>'protein',
				-id=>\@prot_ids,
				-rettype => 'fasta' ), "set rettype = fasta";
ok $result = $fac->efetch->run, "run query with methods parsing";
is scalar @{$result->TSeqSet_TSeq_TSeqAccver}, 5, "retrieved all accns via \$result->TSeqSet_TSeq_TSeqAccver";
diag("Get GIs for a list of accessions");
ok $fac->efetch->set_parameters( -id=>\@accns ), "set -id to accn list";
ok $result = $fac->efetch->run, "run query with methods parsing";
is scalar @{$result->TSeqSet_TSeq_TSeqGi}, 5, "retrieved all GIs via \$result->TSeqSet_TSeq_TSeqGi";

diag("Downloading a large contig");
ok $fac->efetch->reset_parameters( -db => 'nucleotide',
				   -id => $lg_contig), "set parms for lg contig example";
ok $seqio = $fac->efetch->run( -auto_adapt => 1 ), "run with auto_adapt";

ok $seq = $seqio->next_seq, "iterate adaptor";
ok !$seq->seq, "no sequence present (contig only)";
TODO: {
    local $TODO = "why not work with gbwithparts?";
    ok $fac->efetch->set_parameters( -rettype=>'gbwithparts' ), "rettype = gbwithparts";
    dies_ok { $seqio = $fac->efetch->run( -auto_adapt => 1 ) };
    diag("run with auto_adapt (dies not really ok...)");
    
    ok $seq = $seqio->next_seq, "iterate adaptor";
    if ($seq) { ok $seq->seq, "sequence now present"; } else {ok 1;}
}

diag("Get the scientific name for an organism");
ok $fac->efetch->reset_parameters( -db=>'taxonomy', -id=>[$sciname_id, $sciname_id+1] ), "set params for sciname test";
ok my $spio = $fac->efetch->run(-auto_adapt => 1), "run with autoadapt";
ok my $sp = $spio->next_species;
like $sp->scientific_name, qr/Bacillus thuringiensis/, "sciname";
is ($sciname_id, $sp->ncbi_taxid, "taxid retrieved and correct");

ok $fac->esummary( -db => 'taxonomy', -id => $sciname_id ), "set esummary parms";
ok my $docs = $fac->run(-auto_adapt=>1), "run with autoadapt";
ok my $doc = $docs->next_docsum, "iterate adaptor";
like $doc->ScientificName, qr/Bacillus thuringiensis/, "sciname";
is ($sciname_id, $doc->TaxId, "taxid retrieved and correct");

ok $fac->esearch( -db=>'protein', -term=> 'BRCA and human', -usehistory=>1 );
ok $result = $fac->run, "run with method parsing";
is $result->QueryTranslation, 
   'BRCA[All Fields] AND ("Homo sapiens"[Organism] OR human[All Fields])',
"query translation";
cmp_ok $result->count, ">=", 73, "result count";
ok $fac->esearch->reset_parameters( -WebEnv => $result->webenv, 
				    -QueryKey => $result->query_key,
				    -RetMax => 100 );
ok my $wresult = $fac->esearch->run, "run web environment query with retmax set";
cmp_ok $wresult->count, ">=", 73, "all ids retrieved";

ok $result = $fac->einfo()->run, "run einfo general query";
cmp_ok scalar(@{$result->dbs}), ">=", 42, "bunch o' dbs";
ok $result = $fac->einfo(-db=>'pubmed')->run, "run pubmed info";
is $result->db, 'pubmed', "dbname";
cmp_ok $result->record_count, ">=", 19000000, "record count";

    }
$DB::single=1;


1;


1;




    

    
}

# remove later
sub test_input_file { "data/".shift };
