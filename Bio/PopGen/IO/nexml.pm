# $Id$
#
# BioPerl module for Bio::PopGen::IO::nexml
#
# Please direct questions and support issues to <bioperl-l@bioperl.org>
#
# Cared for by Mark A. Jensen <maj@fortinbras.us>
#
# Copyright Mark A. Jensen
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::PopGen::IO::nexml - Facility for parsing and writing NeXML matrix format into L<Bio::PopGen> objects

=head1 SYNOPSIS

This module is loaded by L<Bio::PopGen::IO> when the C<format>
parameter is set to C<'nexml'>.

=head1 DESCRIPTION

This is a instance implementation of L<Bio::PopGen::IO>, for slurping
and squirting the NeXML (L<http://www.nexml.org>) evolutionary data
interchange format. The methods are principally hacked from Chase
Miller's NeXML implementations of L<Bio::SeqIO> and L<Bio::AlignIO>.

=head1 APPLICATION NOTES

NeXML attributes are stored in an annotation collection
(L<Bio::Annotation::Collection>) under the
C<Bio::PopGen::Population::annotation> and
C<Bio::PopGen::Individual::annotation> attributes. These are accessed
in general as follows:

 @nexml_attr = map {$_->value} $obj->annotation->get_Annotations($access_tag);

where we describe the valid access tag descriptors below. Note that
C<get_Annotation> returns an array, so that the following idiom is
often useful, when an annotation represents a simple "key => value"
pair:

 $nexml_attr = ($popn->annotation->get_Annotations($access_tag))[0]->value;

Valid access tags are:

  Bio::PopGen::Population
    taxa_id    : the NeXML id associated with this data matrix
    taxa_label : the human-friendly label assoc. with the data matrix
    datatype   : the NeXML data type describing this data
                 (dna, protein, standard, continuous, custom, restriction)
    taxa       : an array of taxon names corresponding to the population
                 individuals

  Bio::PopGen::Individual
    taxon      : the taxon associated with the individual
    id         : the unique id for this individual, also in $ind->unique_id
    taxa_id    : the taxa id for the population to which the individual belongs
    

=head2 Setting up L<Bio::PopGen::Population> objects for writing to
NeXML

=head2 Accessing NeXML attributes from parsed-in L<Bio::PopGen::Population> 
objects

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

=head1 AUTHOR - Mark A. Jensen

Email maj@fortinbras.us

=head1 CONTRIBUTORS

Chase Miller, Google Summer of Code

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::PopGen::IO::nexml;
use strict;

# Object preamble - inherits from Bio::Root::Root

use lib '../../..';
use Bio::Root::Root;
use Bio::Nexml::Factory;
use Bio::Phylo::IO qw(parse unparse);
use Bio::Annotation::Collection;
use Bio::Annotation::SimpleValue;

use base qw(Bio::PopGen::IO);

sub _initialize {
    my $self = shift;
    my @args = @_;
    $self->doc( Bio::Phylo::Factory->create_project());
}

=head1 ITERATORS (Bio::PopGen::IO compliance)

=head2 next_individual

 Title   : next_individual
 Usage   : my $ind = $popgenio->next_individual;
 Function: Retrieve the next individual from a dataset
 Returns : L<Bio::PopGen::IndividualI> object
 Args    : none

=cut

sub next_individual{
    my ($self) = @_;
    $self->warn('Bio::PopGen::IO::nexml currently parses entire populations based on NeXML <matrix> elements only.\nUse $pop = $obj->next_population; for ($pop->get_Individuals) {...} instead.');
    return;
}

=head2 next_population
    
 Title   : next_population
 Usage   : my $pop = $popgenio->next_population;
 Function: Retrieve the next population from a dataset
 Returns : L<Bio::PopGen::PopulationI> object
 Args    : none

=cut

sub next_population{
    my ($self) = @_;
    unless ($self->mode eq 'r') {
	$self->warn("This stream not opened for reading");
	return;
    }
    $self->_parse unless ( $self->{'_parsed'} );
    return $self->{'_popns'}->[ $self->{'_popniter'}++ ];
}

sub rewind { shift->{'_popns'} = 0; 1 }

=head2 write_individual

 Title   : write_individual
 Usage   : $popgenio->write_individual($ind);
 Function: Write an individual out in the implementation format
 Returns : none
 Args    : L<Bio::PopGen::PopulationI> object(s)

=cut

sub write_individual{
    my ($self) = @_;
    $self->warn('Bio::PopGen::IO::nexml supports writing entire populations as NeXML <matrix> elements only');
    return;
}

=head2 write_population

 Title   : write_population
 Usage   : $popgenio->write_population($pop);
 Function: Write a population out in the implementation format
 Returns : none
 Args    : L<Bio::PopGen::PopulationI> object(s)
 Note    : Many implementation will not implement this

=cut

sub write_population{
    my ($self, @pops) = @_;
    unless ($self->mode eq 'w') {
	$self->warn("This stream not opened for writing");
	return;
    }
    my $fac = Bio::Nexml::Factory->new();
    foreach (@pops) {
	unless ($_->isa('Bio::PopGen::PopulationI')) {
	    $self->warn("Arg not a Bio::PopGen::PopulationI; skipping");
	    next;
	}
	unless (defined $_->annotation) {
	    $self->warn("Nexml annotations not prepared for this population--proceeding by setting a default; see pod for Bio::PopGen::IO::nexml for information");
	    my $ac = Bio::Annotation::Collection->new();
	    $ac->add_Annotation('datatype', Bio::Annotation::SimpleValue->new(-value => 'standard'));
	    $_->annotation($ac);
	    for my $i ($_->get_Individuals) {
		$i->annotation || $i->annotation(Bio::Annotation::Collection->new());
		$i->{_population} = $_; # kludge to access marker descriptions later
	    }
	}
	my $taxa = $fac->create_bphylo_taxa($_);
	my $matrix = $fac->create_bphylo_popn($_, $taxa);
	$matrix->set_taxa($taxa);
	$self->doc->insert($matrix);
	$self->_print($self->doc->to_xml());
    }
    $self->flush;
    return 1;
    
}

=head1 INTERNALS

=head2 _parse

=cut

sub _parse {
    my ($self) = @_;
    
    $self->{'_parsed'}   = 1;
    $self->{'_popniter'} = 0;
    my $fac = Bio::Nexml::Factory->new();
    
    $self->{_doc} = parse(
 	'-file'       => $self->file,
 	'-format'     => 'nexml',
 	'-as_project' => '1'
 	);
 	
    $self->{'_popns'} = $fac->create_bperl_popn($self);
}

=head2 doc

 Title   : doc
 Usage   : $obj->doc($newval)
 Function: Get/set the parsed NeXML document (as a 
         : Bio::Phylo::Project object)
 Example : 
 Returns : Bio::Phylo::Project object
 Args    : on set, new value (a Bio::Phylo::Project object
           or undef, optional)

=cut

sub doc{
    my $self = shift;
    return $self->{'_doc'} = shift if @_;
    return $self->{'_doc'};
}

1;
