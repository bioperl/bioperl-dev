#$Id$#

=head1 NAME

Bio::DB::HIV::HIVXmlSchema - routines to convert LANL HIV sequence DB data into XML
(This package eventually bound for bioperl-dev)

=head1 SYNOPSIS

 use HIVXmlSchema qw(HIVNS);
 print HIVNS;                  # returns "http://fortinbras.us/HIVDBSchema/1.0"

 my $q = Bio::DB::Query::HIVQuery->new( 
     -query => "(F)[subtype] (Env)[gene] (BR ZA)[country]"
              ."{ pat_id risk_factor project }"
     );
 my $xml_seq_doc   = $db->make_nexml_from_query( $q );
 my $xml_annot_doc = $q->make_xml_from_query( $q->ids );

=head1 DESCRIPTION

This package contains the definition of the
C<Bio::DB::HIV::HIVXmlSchema> class, and also internal methods
assigned to existing module namespaces in BioPerl modules
C<Bio::DB::HIV> and C<Bio::DB::Query>. They are used to help create
schema-valid XML messages from sequences and their metadata as
returned by the Los Alamos National Laboratories' CGI interface to
their HIV Sequence Database.  Annotations can be returned as an XML
document in the custom namespace
L<http://fortinbras.us/HIVDBSchema/1.0>. The schema definition files
can be obtained at that URL. Sequences can be returned as an XML
document in the NeXML format (namespace L<http://www.nexml.org/1.0>).
Voluminous details on the NeXML standard can be obtained at
L<http://www.nexml.org>.

The namespace constants C<HIVNS> and C<NEXML> are exportable from 
C<Bio::DB::HIV::HIVXmlSchema>.

=head1 IMPORTANT CAVEAT

These routines are dependent upon revision 15594 of
C<Bio::DB::Query::HIVQuery> and revision 15593 of
C<Bio::DB::HIV::HIVQueryHelper>. The most recent versions of these
modules are available by SVN checkout from the trunk at
L<svn://code.open-bio.org/bioperl/bioperl-live/trunk/>

=head1 IMPLEMENTATION NOTES

These routines depend on the NeXML parser/writers in the C<Bio::Phylo> package
by Rutger Vos. It can be obtained at L<http://phylo.sourceforge.net>.

XML manipulations here currently employ the C<XML::LibXML> package of Petr Pajas and C<XML::Compile> and C<XML::Compile::Schema> of Mark Overbeek. These require the presence of C<libxml2> libraries, which can be obtained for many platforms 
at L<http://xmlsoft.org/index.html>

=head1 AUTHOR - Mark A. Jensen

Email maj@fortinbras.us

=head1 ACKNOWLEDGEMENTS

Many thanks to the knowledgeable and patient participants of the 
National Center for Evolutionary Synthesis' Database Interoperability
Hackthon, Durham, NC, USA, March 2009. See their work at
L<http://www.nescent.org/wg_evoinfo/Category:DB_Interop_Hackathon>.

=head1 APPENDIX

The rest of the documentation details each of the contained packages.
Internal methods are usually preceded with a _

=cut

package Bio::DB::Query::HIVQuery;
use strict;
use HIVXmlSchemaHelper; # fully qualify the ns when necessary
use XML::LibXML;
use Log::Report;

=head2 Bio::DB::HIV::HIVQuery::make_xml_from_query

 Title   : make_XML_from_query
 Usage   : $q->make_XML_from_query()
 Function: Create an XML document of sequence annotations, according to
           the XML Schema namespace http://fortinbras.us/HIVDBSchema/1.0
 Example :
 Returns : HIVDBSchema-compliant XML document as string
 Args    : none

=cut

sub make_xml_from_query {
    my $self = shift;
    return $self->make_xml_with_ids( $self->ids );
}

=head2 Bio::DB::HIV::HIVQuery::make_XML_with_ids

 Title   : make_xml_with_ids
 Usage   : $q->make_xml_with_ids( @ids )
 Function: Create an XML document of sequence annotations, according to
           the XML Schema namespace http://fortinbras.us/HIVDBSchema/1.0
 Example :
 Returns : HIVDBSchema-compliant XML document as string
 Args    : a[n array of] LANL id[s] (scalar[s])

=cut

sub make_xml_with_ids {
    my $self = shift;
    my @ids = @_;
    my @hashes;
    unless ($self->_run_option == 2) {
	$self->warn("Method requires that query be run at level 2");
	return undef;
    }
    foreach (@ids) {
	my $h = $self->_xml_hashref_from_id($_);
	next unless $h; # skip on dne
	push @hashes, $h;
    }
    if (@hashes) {
	my $sch = Bio::DB::HIV::HIVXmlSchema->new();
	my $doc = XML::LibXML::Document->new();
	my ($wri, $guts);

	# use the Log::Report try block around $wri->() and check
	# $@; throw BP error if set.
	try {
	    $wri = $sch->make_writer;
	    $guts = $wri->($doc, { 'annotHivqSeq' => [@hashes] })
	};
	if ($@) {
	    $@->reportAll;
	    exit(0);
	    # handle XML::Compile::Schema error
	}
	else {
	    $doc->addChild($guts);
	    return $doc->toString(1);
	}
    }
    else {
	# dude, no data!
	$self->warn("No XML was generated for this query");
    }
}
    
1;

package Bio::DB::HIV;
use strict;
use HIVXmlSchemaHelper; # fully qualify the ns when necessary
use XML::LibXML::Reader;
use XML::LibXML;
use Bio::Phylo::Factory;
use constant NEXML => 'http://www.nexml.org/1.0';

=head2 make_nexml_from_query

 Title   : make_nexml_from_query
 Usage   : $db->make_nexml_from_query( $hiv_query_object )
 Function: Create a NeXML-compliant XML document containing 
           sequences (not annotations; see 
           Bio::DB::Query::HIV::make_XML_with_ids()
           for that) associated with a Bio::DB::Query::HIVQuery
           object
 Example :
 Returns : NeXML-compliant XML document as string
 Args    : Bio::DB::Query::HIVQuery object; [optional] array of
           LANL sequence ids.
 Note    : Requires Rutger Vos' external package Bio::Phylo 

=cut

sub make_nexml_from_query{
   my ($self,@args) = @_;
   my ($q)  = @args;
   
   my $bpf       = Bio::Phylo::Factory->new;
   my $seqio     = $self->get_Stream_by_query( $q );
   my $dat_obj   = $bpf->create_datum();
   my $taxon_obj = $bpf->create_taxon();
   my $taxa      = $bpf->create_taxa();
   my ($xrdr, $dom);

   my $doc = XML::LibXML::Document->new();
   my ($mx, $alphabet);

   while ( my $seq = $seqio->next_seq ) {

       # check first seq and make matrix (note this won't 
       # work if we have mixed data)
       if ($mx) {
	   $self->throw( "Mixed data NeXML not currently implemented" ) if
	       $seq->alphabet ne $alphabet;
       }
       else {
	   $alphabet = $seq->alphabet;
       }

       $mx ||= $bpf->create_matrix( -type=>$seq->alphabet ); 
       
       my ($taxon, $datum);
       #create elements...
       $taxon = $taxon_obj->new( -name => $seq->id, 
				 -desc => $seq->annotation->get_value('Special','accession'));

       $datum = $dat_obj->new_from_bioperl($seq);
       $taxon->set_data($datum);
       #organize into containers...
       $taxa->insert( $taxon );
       $mx->insert( $datum);
       1;
   }
   
   # so if @dna != 0 and @aa != 0, we require a mixed matrix.
   # link the matrix to the taxa 'block'
   $mx->set_taxa( $taxa);
   $xrdr = XML::LibXML::Reader->new( string => join('', '<fake>',
						    $taxa->to_xml,
						    $mx->to_xml(-compact => 1),
				     '</fake>'));
   $xrdr->read;
   my ( $otus_node, $characters_node ) = $xrdr->copyCurrentNode(1)->childNodes;
   
   # build the DOM
   foreach my $otu_node ( $otus_node->childNodes ) {
       next unless $otu_node->nodeName eq 'otu';
       my ($lanlid, $tmp, $lanlid_node, $gbaccn_node);

       $lanlid_node = XML::LibXML::Element->new('dict');
       $lanlid_node->setAttribute('id', "dict$$lanlid_node"); # uniquify

       $lanlid = $otu_node->getAttribute('label');
       $tmp = XML::LibXML::Element->new('string');
       $tmp->setAttribute('id', "LANLSeqId_$$lanlid_node");
       $tmp->addChild( XML::LibXML::Text->new($lanlid ) );
       $lanlid_node->addChild($tmp);
       
       $gbaccn_node =  XML::LibXML::Element->new('dict');
       $gbaccn_node->setAttribute('id', "dict$$gbaccn_node");

       $tmp = XML::LibXML::Element->new('string');
       $tmp->setAttribute('id', "GenBankAccn_$$gbaccn_node");
       $tmp->addChild( XML::LibXML::Text->new($q->get_accessions_by_id($lanlid)));
       $gbaccn_node->addChild($tmp);

       $otu_node->addChild($lanlid_node);
       $otu_node->addChild($gbaccn_node);

   }
   
   # create the NexML doc
   $dom = XML::LibXML::Element->new('nexml');
   $dom->setNamespace(NEXML, 'nex');
   $dom->setAttribute('version', '0.8');
   $dom->setAttribute('generator', 'Bio::DB::HIVXmlSchema');
   $dom->setAttribute('xmlns', NEXML);
   $dom->addChild($otus_node);
   $dom->addChild($characters_node);

   $doc->setDocumentElement($dom);

   return $doc->toString(1);

}

1;

package Bio::DB::HIV::HIVXmlSchema;
use strict;
use constant HIVNS => 'http://fortinbras.us/HIVDBSchema/1.0';
use constant NEXML => 'http://www.nexml.org/1.0';

use XML::LibXML;
use XML::Compile;
use XML::Compile::Util qw( SCHEMA2001 SCHEMA2001i pack_type );
use Exporter;
use base qw(XML::Compile::Schema Bio::Root::Root);

BEGIN {
    our (@ISA, @EXPORT_OK);
    push @ISA, qw( Exporter );
    @EXPORT_OK = qw( HIVNS NEXML );
}

our @schemata = qw(
                   hivqSchema.xsd 
                   hivqAnnotSeqType.xsd
                   hivqComplexTypes.xsd
                   hivqSimpleTypes.xsd
                  );

=head2 Constructor

 Title   : new
 Usage   : $sch = HIVXmlSchema->new();
 Function: create a new HIVXmlSchema object
 Example :
 Returns : a new HIVXmlSchema object (is-a XML::Compile::Schema, and
           is-a Bio::Root::Root)
 Args    : -SCHEMADIR => $dir_containing_xsd_files or [@dirs]
           -XSCARGS   => \@array_of_XML_Compile_Schema_constructor_args

=cut

# binding prefixes needs:
# compile(..., prefixes => { SCHEMA2001 => 'xs', SCHEMA2001i => 'xsi', HIVNS => 'hivq' }

sub new{
   my ($class,@args) = @_;
   my ($schema_dir,$XSC_args) = $class->SUPER::_rearrange([qw(SCHEMADIR,XSCARGS)], @args);
   my @XSDDIRs = ($schema_dir and ref($schema_dir) eq 'ARRAY') ? @$schema_dir : ($schema_dir);
   my @XSDDIRS = (@INC, $schema_dir);
   my $self = $class->SUPER::new([SCHEMA2001,SCHEMA2001i, @schemata],
				 'schema_dirs' => [@XSDDIRS],
				 @$XSC_args);

   # now,can do other stuff here using XML::Compile:Schema instance methods:
   # add filtering hooks, rewrite tables, typemaps...
   # maybe to do under the hood 
   # see http://search.cpan.org/~markov/XML-Compile-1.02/lib/XML/Compile/Schema.pod#Administration
   
   # attach hivq-specific reader and writer slots (for doc purposes really)
   $self->{_hivq_writer} = {};
   $self->{_hivq_reader} = {};

   return $self;
}

=head2 make_writer

 Title   : make_writer
 Usage   : $hivq_wri = $obj->make_writer
 Function: compile and return an XML::Compile writer based on the HIVQ schema,
           add ref to parent object
 Example : 
 Returns : a coderef (see XML::Compile manpage)
 Args    : -AT_ELT => $fully_qualified_element_name_in_hivq_ns 
           -XSCARGS => [@args_to_pass_to_compiler]

=cut

sub make_writer{
   my ($self,@args) = @_;
   my ($at_elt, $XSC_args) = $self->_rearrange([qw(AT_ELT XSCARGS)], @args);
   $at_elt ||= pack_type(HIVNS, 'HivqSeqs');
   $XSC_args ||= [];
   return $self->_hivq_writer( $self->compile('WRITER',
					      $at_elt,
					      prefixes => [ 
						  'xs'  => SCHEMA2001,
						  'xsi' => SCHEMA2001i,
						  'hivq'=> HIVNS
					      ],
					      @$XSC_args) );
}

=head2 make_reader

 Title   : make_reader
 Usage   : $hivq_rdr = $obj->make_reader
 Function: compile and return an XML::Compile reader based on the HIVQ Schema,
           add ref to parent object
 Example :
 Returns : a coderef (see XML::Compile manpage)
 Args    : -AT_ELT => $fully_qualified_element_name_in_hivq_ns 
           -XSCARGS => [@args_to_pass_to_compiler]

=cut

sub make_reader{
   my ($self,@args) = @_;
   my ($at_elt, $XSC_args) = $self->_rearrange([qw(AT_ELT XSCARGS)], @args);
   $at_elt ||= 'HivqSeqs';
   $XSC_args ||= [];
   return $self->_hivq_reader( $self->compile('READER',
					      $at_elt,
					      prefixes => [
						  'xs'   => SCHEMA2001,
						  'xsi'  => SCHEMA2001i,
						  'hivq' => HIVNS
					      ],
					      @$XSC_args) );


}

=head2 _hivq_writer

 Title   : _hivq_writer
 Usage   : $obj->_hivq_writer($newval)
 Function: container for XML::Compile compiled writer
 Example : 
 Returns : value of _writer (a coderef)
 Args    : on set, new value (a coderef or undef, optional)

=cut

sub _hivq_writer{
    my $self = shift;

    return $self->{'_hivq_writer'} = shift if @_;
    return $self->{'_hivq_writer'};
}

=head2 _hivq_reader

 Title   : _hivq_reader
 Usage   : $obj->_hivq_reader($newval)
 Function: container for XML::Compile compiled reader
 Example : 
 Returns : value of _hivq_reader (a coderef)
 Args    : on set, new value (a coderef or undef, optional)

=cut

sub _hivq_reader{
    my $self = shift;

    return $self->{'_hivq_reader'} = shift if @_;
    return $self->{'_hivq_reader'};
}

1;

