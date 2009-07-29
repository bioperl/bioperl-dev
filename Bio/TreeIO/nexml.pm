# $Id$
#
# BioPerl module for Bio::TreeIO::nexml
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Chase Miller <chmille4@gmail.com>
#
# Copyright Chase Miller
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::TreeIO::nexml - A TreeIO driver module for parsing Nexml tree files

=head1 SYNOPSIS

  use Bio::TreeIO;
  my $in = Bio::TreeIO->new(-file => 'data.nexml' -format => 'Nexml');
  while( my $tree = $in->next_tree ) {
  }

=head1 DESCRIPTION

This is a driver module for parsing tree data in a Nexml format.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to
the Bioperl mailing list.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
of the bugs and their resolution. Bug reports can be submitted via
the web:

  http://bugzilla.open-bio.org/

=head1 AUTHOR - Chase Miller

Email chmille4@gmail.com

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::TreeIO::nexml;
use strict;

use lib '../..';
use Bio::Event::EventGeneratorI;
use IO::String;
use Bio::Phylo::IO qw (parse unparse);
use Bio::Nexml::Util;
use Benchmark;

use base qw(Bio::TreeIO);

=head2 new

 Title   : new
 Args    : -header    => boolean  default is true 
                         print/do not print #NEXUS header
           -translate => boolean default is true
                         print/do not print Node Id translation to a number

=cut

sub _initialize {
    my $self = shift;
    $self->SUPER::_initialize(@_);
}

=head2 next_tree

 Title   : next_tree
 Usage   : my $tree = $treeio->next_tree
 Function: Gets the next tree in the stream
 Returns : Bio::Tree::TreeI
 Args    : none


=cut

sub next_tree {
    my ($self) = @_;
    unless ( $self->{'_parsed'} ) {
        $self->_parse;
    }
    return $self->{'_trees'}->[ $self->{'_treeiter'}++ ];
}

sub benchmark_test {
	my $tree = next_tree(@_);
	my $self = shift;
	$self->{'_parsed'} = 0;
	return $tree;
}

sub rewind {
    my $self = shift;
    $self->{'_treeiter'} = 0;
}

sub _parse {
    my ($self) = @_;
    
    $self->{'_parsed'}   = 1;
    $self->{'_treeiter'} = 0;
    
    my $proj;
    #eval {
    	$proj = parse(
 	'-file'       => $self->{'_file'},
 	'-format'     => 'nexml',
 	'-as_project' => '1'
 	);
   # };
 	
 	#if ($@)
 	#{
 	#	print "caught";
 	#}
 	$self->{'_trees'} = Bio::Nexml::Util->_make_tree($proj);
 	#timethis('50', my $test = sub {Bio::Nexml::Util->_make_tree($proj)});
}

=head2 write_tree

 Title   : write_tree
 Usage   : $treeio->write_tree($tree);
 Function: Writes a tree onto the stream
 Returns : none
 Args    : Bio::Tree::TreeI


=cut

sub write_tree {
	my $self = shift(@_);
	my ($tree, $taxa) = Bio::Nexml::Util->create_bphylo_tree(@_);
	
	my $forest = Bio::Phylo::Factory->create_forest();
	my $nexml_doc = Bio::Phylo::Factory->create_project();
	
	$forest->set_taxa($taxa);
	$forest->insert($tree);
	
	$nexml_doc->insert($forest);
	
	$self->_print($nexml_doc->to_xml());
}


1;
