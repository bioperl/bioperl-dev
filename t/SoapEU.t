#-*-perl-*-
#$Id$
#testing SoapEUtilities and components
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

# use data files for most unit testing
# see skip section for network tests

# ESoap::WSDL
my $NCBI_SOAP_SVC = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/soap/v2.0/soap_adapter_2_0.cgi";

ok my $wsdl = Bio::DB::ESoap::WSDL->new(-wsdl => test_input_file('eutils.wsdl')), "wsdl parse from file";

is_deeply ( [sort values %{$wsdl->operations}], [sort qw( einfo esearch elink egquery epost espell esummary)], "available operations" );
is $wsdl->service, $NCBI_SOAP_SVC, "correct soap svc url (as of 1/9/10)";

is_deeply( $wsdl->request_parameters('einfo'), 
	   { 'eInfoRequest' => [
		 { 'db' => 1 },
		 { 'tool' => 1 },
		 { 'email' => 1 }
		 ] } , 'einfo request parameters');
is_deeply( $wsdl->response_parameters('einfo'), 
	   {'eInfoResult' =>
		[ {'ERROR' => 1},
		  {'DbList' => [{'DbName|' => 1 }]},
		  {'DbInfo' => [ 
		       {'DbName' => 1 }, 
		       {'MenuName' => 1},
		       {'Description' => 1},
		       {'Count' => 1},
		       {'LastUpdate' => 1},
		       {'FieldList' => [
			    {'Field' => [
				 {'Name' => 1},
				 {'FullName' => 1},
				 {'Description' => 1},
				 {'TermCount' => 1},
				 {'IsDate' => 1},
				 {'IsNumerical' => 1},
				 {'SingleToken' => 1},
				 {'Hierarchy' => 1},
				 {'IsHidden' => 1}
				 ]}
			    ]},
		       {'LinkList' => [
			    {'Link' => [
				 {'Name' => 1},
				 {'Menu' => 1},
				 {'Description' => 1},
				 {'DbTo' => 1}
				 ]}
			    ]}
		       ]}
	     ]}, 'einfo response parameters');
is_deeply( $wsdl->request_parameters('egquery'),
	   { 'eGqueryRequest' => [
		 { 'term' => 1 },
		 { 'tool' => 1 },
		 { 'email' => 1 }
		 ] } , 'egquery request parameters');
is_deeply( $wsdl->response_parameters('egquery'),
	   { 'Result' => [
		 { 'Term' => 1 },
		 { 'eGQueryResult' => [
		       {'ERROR' => 1},
		       {'ResultItem' => [
			    {'DbName' => 1},
			    {'MenuName' => 1},
			    {'Count' => 1},
			    {'Status' => 1}
			    ]}
		       ]}
		 ]} , 'egquery response parameters');

# ESoap

ok my $dumfac = Bio::DB::ESoap->new( -util => 'run_eLink',
				     -wsdl_file => test_input_file('eutils.wsdl') ), "dummy ESoap factory";

is $dumfac->util, 'run_eLink', 'operation accessor';
ok $dumfac = Bio::DB::ESoap->new( -util => 'elink',
				     -wsdl_file => test_input_file('eutils.wsdl') ), "dummy ESoap factory";
is $dumfac->util, 'run_eLink', 'operation name converted';
require File::Spec;
is( (File::Spec->splitpath($dumfac->wsdl_file))[-1], 'eutils.wsdl', 'wsdl filename accessor' );
is $dumfac->_request_elt_name, 'eLinkRequest', 'request element name';
is $dumfac->_result_elt_name, 'eLinkResult', 'result element name';
is_deeply( [sort $dumfac->available_parameters], [sort qw( db id reldate mindate maxdate datetype term dbfrom linkname WebEnv query_key cmd tool email )], 'elink available parameters via Bio::ParameterBaseI');
ok $dumfac->set_parameters( -db => 'gene', -id => 12345, -tool => 'ESoapTest' ), 'set_parameters';
ok $dumfac->parameters_changed, "parameters_changed flag set";
is_deeply( [$dumfac->get_parameters], [qw( db gene id 12345 tool ESoapTest )],
	   'get_parameters' );
ok !$dumfac->parameters_changed, "parameters_changed flag cleared";
is $dumfac->db, 'gene', 'parameter as accessor';
is $dumfac->tool, 'ESoapTest', 'parameter as accessor (2)';
ok $dumfac->reset_parameters, "reset_parameters";
ok $dumfac->parameters_changed, "parameters_changed flipped";




SKIP : {
    test_skip(-tests => 100, # modify
	      -requires_networking => 1);

}

# remove later
sub test_input_file { "data/".shift };
