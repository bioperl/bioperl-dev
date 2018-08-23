#!/usr/bin/perl
#$Id$
# This is a Module::Build script for bioperl-dev installation.
# See http://search.cpan.org/~kwilliams/Module-Build/lib/Module/Build.pm

# Uses a custom subclass of Module::Build called Bio::Root::Build

use strict;
use warnings;
my $v = '1.006900'; # pre-1.7, requires bioperl-live main trunk
eval "use Bio::Root::Build $v";
if ($@) {
    # using die so wrappers can catch the error message    
    die "BioPerl minimal core version $v is required for BioPerl-dev\n";
}

# Set up the Bio::Root::Build object
my $build = Bio::Root::Build->new(
    module_name         => 'Bio',
    dist_name           => 'BioPerl-dev',
    dist_version        => $v,
    dist_author         => 'BioPerl Team <bioperl-l@bioperl.org>',
    dist_abstract       => 'BioPerl-dev - wrapper toolkit',
    license             => 'perl',
    requires            => {
	                    # probably justified in bumping this up, but
	                    # leaving it for now:
                            'perl'                      => '5.6.1',
                            #'Bio::Root::Version'        => '1.007000' # checked above
                           },
    recommends          => {
	                    # your ad here
	                    # 
                            # please add in your dependencies here, 
	                    # if you intend your modules to be user-tested,
	                    # as:
	                    #'[dependency]' => '[version reqd]/[informative phrase]/[requirer]'
	                    # ex)
                            #'Array::Compare'            => '0/Phylogenetic Networks/Bio::PhyloNetwork'

                           },
    get_options         => {
                            network => { } # say 'perl Build.PL --network' to manually request network tests
                           },
    auto_features       => {
                            Network               => {
                                                        description => "Enable tests that need an internet connection",
                                                        requires    => { 'LWP::UserAgent' => 0 },
                                                        test        => \&Bio::Root::Build::test_internet
                                                     }
                           },
    dynamic_config      => 1,
    create_makefile_pl  => 'passthrough'
    
    #pm_files           => {} # modules in Bio are treated as if they were in lib and auto-installed
    #script_files       => [] # scripts in scripts directory are installed on-demand
);

my $accept = $build->args->{accept};

# Ask questions
$build->choose_scripts;
{
    if ($build->args('network')) {
        if ($build->feature('Network')) {
            $build->notes(network => 1);
            $build->log_info("  - will run internet-requiring tests\n");
        }
        else {
            $build->notes(network => 0);
            $build->log_info("  - will not run network tests since I seem to be missing essential network functionality\n");
        }
    }
    else {
        $build->prompt_for_network($accept) if $build->feature('Network');
    }
}

# Create the build script and exit
$build->create_build_script;

exit;
