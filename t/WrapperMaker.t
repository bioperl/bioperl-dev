#-*-perl-*-
#$Id$

#testing Bio::Tools::WrapperMaker
use strict;
#use warnings;
our $home;
BEGIN {
 use Bio::Root::Test;
 $home = "..";
 unshift @INC, $home;
 test_begin( -tests => 100,
	      -requires_modules => [qw(
                                     Bio::Tools::Run::WrapperBase
                                     Bio::Tools::Run::WrapperBase::CommandExts
                                     )]
     );
}
use Cwd;
sub test_input_file { "data/".shift }; ###

use_ok( 'Bio::Tools::WrapperMaker' );
if (!$Bio::Tools::WrapperMaker::HAVE_LIBXML) {
    # turn off validation warnings
    $Bio::Tools::WrapperMaker::VALIDATE_DEFS = -1;
}

my $synop_xml = <<END;
<defs xmlns="http://www.bioperl.org/wrappermaker/1.0">
  <program name="ls" dash-policy="mixed"/>
  <self name="_self" prefix="_self">
    <options>
      <option name="all" type="switch"/>
      <option name="sort_by_size" type="switch" translation="S"/>
      <option name="sort_by_time" type="switch" translation="t"/>
      <option name="one_line_each" type="switch" translation="1"/>
    </options>
   <filespecs>
     <filespec token="pth" use="optional-multiple"/>
     <filespec token="out" use="optional-single" redirect="stdout"/>
   </filespecs>
 </self>
</defs>
END

#synopsis and basic functionality

ok -e $Bio::Tools::WrapperMaker::LOCAL_XSD, "local maker.xsd present";
ok my $lsfac = Bio::Tools::WrapperMaker->compile( -defs => $synop_xml ), "import synopsis example xml";
is (ref($lsfac), 'MyWrapper', "class correct");
# check imports
is ($lsfac->program_name, 'ls', "program name in the namespace");
is ($MyWrapper::use_dash, 'mixed','$use_dash');
is_deeply (\@MyWrapper::program_commands, [qw( command _self )], '@program_commands');
is_deeply (\@MyWrapper::program_switches, [qw( all sort_by_size sort_by_time one_line_each )], '@program_switches');
is_deeply (\%MyWrapper::param_translation, { '_self|sort_by_size' => 'S',
					     '_self|sort_by_time' => 't',
					     '_self|one_line_each' => '1' },
	   '%param_translations');
is_deeply (\%MyWrapper::command_files, { _self => [qw( *#pth >#out )] },
	   '%command_files');
ok my $opts = $lsfac->{_options};
is ($MyWrapper::use_dash, 'mixed','$use_dash');
is_deeply ($opts->{_commands}, [qw( command _self )], 'registry (1)');
is_deeply ($opts->{_switches}, [qw( _self|all _self|sort_by_size _self|sort_by_time _self|one_line_each )], 'registry (2)');
is_deeply ($opts->{_translation}, { '_self|sort_by_size' => 'S',
				    '_self|sort_by_time' => 't',
				    '_self|one_line_each' => '1' },
	   'registry (3)');
is_deeply ($opts->{_files}, { _self => [qw( *#pth >#out )] },
	   'registry (4)');

is_deeply ([$lsfac->available_parameters('switches')], [qw( _self|all _self|sort_by_size _self|sort_by_time _self|one_line_each )], "switches thru api");

SKIP : {
    test_skip( -tests => 6,
	       -requires_executable => $lsfac);
    ok $lsfac->run, "run ls";
    ok !$lsfac->stderr, "no err";
    ok $lsfac->set_parameters( -all => 1 );
    ok $lsfac->run;
    like $lsfac->stdout, qr/^\.$/m, "-all";
    $lsfac->all(0);
    opendir my $d, getcwd();
    my @ls = readdir $d;

    my @lsw = split("\n", $lsfac->stdout);
    is_deeply([sort @lsw], [sort @ls] , "return ok");
    1;
}

# deeper tests (also of CommandExts handling)

ok my $pf = Bio::Tools::WrapperMaker->compile( -defs => test_input_file('perl.xml') );

ok $pf->set_parameters( -perl_version => 1 ), "set parms (0)";

is (join(' ',@{$pf->_translate_params}), "-v", "xlt parms(0)");

ok $pf->reset_parameters( -command => '_self',
			-perl_version => 1), "set parms (1)";
is (join(' ',@{$pf->_translate_params}), "-v", "xlt parms (1)");
ok $pf->reset_parameters( -command => 'test1',
			-boog => 42,
			-goob => 1 ), "set parms (2)";
is (join(' ',@{$pf->_translate_params}), "test1 --boog 42 -b", "xlt parms (2)");
ok $pf->reset_parameters( -command => 'test1',
			-goob => 1, 
			-self_options => [
			     -module => 'Test::More'
			]), "set parms (3)";
is (join(' ',@{$pf->_translate_params}), "-M Test::More test1 -b", "xlt parms (3)");
ok $pf->reset_parameters( -command => 'test1',
			  -freen => 1 );
ok $pf->needed, "coreq switch massage";

ok !$pf->reset_parameters( -command => 'test1',
			   -glarb => 1), "coreq param fails";


ok $pf->reset_parameters( -command => '_self',
			 -warnings => 1,
			 -nowarnings => 1 ), "massage incompatibles";
is (join(' ',@{$pf->_translate_params}), "-W", "xlt parms (4)");

ok $pf->reset_parameters( -command => '_self',
			 -nowarnings => 1,
			  -warnings => 1), "massage incompatibles, rev order";
is (join(' ',@{$pf->_translate_params}), "-X", "xlt parms (5)");

ok $pf->reset_parameters( -command => '_self',
			  -autoloop => 1,
			  -one_liner => "\'1;\'",
			  ), "one liner";
ok $pf->_run(-stdin => test_input_file('perl.xml')), "run";
like $pf->stdout, qr/<composite-command/, "output correct";
ok $pf->reset_parameters( -command => '_self',
			  -one_liner => "print('hello,world')" );
ok $pf->_run;
is $pf->stdout, "hello,world";
1;
