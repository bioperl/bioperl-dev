# $Id$
#
# BioPerl module for Bio::Tools::Run::SoapEUtilities::FetchAdaptor::seq
#
# Please direct questions and support issues to <bioperl-l@bioperl.org>
#
# Cared for by Mark A. Jensen <maj -at- fortinbras -dot- us>
#
# Copyright Mark A. Jensen
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::Tools::Run::SoapEUtilities::FetchAdaptor::seq - Fetch adaptor for 'seq' efetch SOAP messages

=head1 SYNOPSIS

Imported by L<Bio::Tools::Run::SoapEUtilities::FetchAdaptor> as required.

=head1 DESCRIPTION

Describe the object here

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

Email maj -at- fortinbras -dot- us

=head1 CONTRIBUTORS

Much inspiration from L<Bio::SeqIO> and family.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

# Let the code begin...


package Bio::Tools::Run::SoapEUtilities::FetchAdaptor::seq;
use strict;

use lib '../../../../..'; # remove later
use Bio::Root::Root;
use Bio::Annotation::Collection;
use Bio::Annotation::Reference;
use Bio::Annotation::Comment;
use Bio::Annotation::SimpleValue;
use Bio::Seq::SeqBuilder;
use Bio::Seq::SeqFactory;
use Bio::Species;

use base qw(Bio::Tools::Run::SoapEUtilities::FetchAdaptor Bio::Root::Root);

our %VALID_ALPHABET = (
    'AA' => 'protein',
    'DNA' => 'dna',
    'RNA' => 'rna'
);

sub _initialize {
    my ($self, @args) = @_;
    $self->SUPER::_initialize(@args);
    my ($builder, $seqfac ) = $self->_rearrange( [qw(SEQBUILDER
                                                     SEQFACTORY)], @args );
    $self->{'_obj_class'} = ($seqfac ? $seqfac->type : 'Bio::Seq::RichSeq') ; 
    $self->{'_builder'} = $builder || Bio::Seq::SeqBuilder->new();
    $self->{'_builder'}->sequence_factory( 
	$seqfac || Bio::Seq::SeqFactory->new( -type => $self->{'_obj_class'} )
	);
    $self->{'_idx'} = 1;
    1;
}

sub obj_class { shift->{'_obj_class'} }

sub builder { shift->{'_builder'} };

sub next_obj {
    my $self = shift;
    my $a = $self->{'_idx'};
    my $stem = "//GBSet/[$a]";
    my $som = $self->result->som;
    return unless defined $som->valueof("$stem");

    my $get = sub { $som->valueof("$stem/GBSeq_".shift) };
    # parsing based on Bio::SeqIO::genbank

    my %params = (-verbose => $self->verbose);

    # source, id, alphabet
    $params{'-display_id'} = $get->('locus');
    $params{'-length'} = $get->('length');
    $get->('moltype') =~ /(AA|[DR]NA)/;
    $params{'-alphabet'} = $VALID_ALPHABET{$1} || '';

    # molecule, division, dates
    $params{'-molecule'} = $get->('moltype');
    $params{'-is_circular'} = ($get->('topology') eq 'circular');
    $params{'-division'} = $get->('division');
    $params{'-dates'} = [$get->('create-date'), $get->('update-date')];

    $self->builder->add_slot_value(%params);
    %params = ();

    if ( !$self->builder->want_object ) { # skip this
	$self->builder->make_object;
	($self->{_idx})++;
	goto &next_obj;
    }

    # accessions, version, pid, description
    $get->('accession-version') =~ /.*\.([0-9]+)$/;
    $params{'-version'} = $params{'-seq_version'} = $1;
    my @secondary_ids;
    my @ids = $get->('other-seqids/GBSeqid');
    foreach (@ids) {
	/^gi\|([0-9]+)/ && do {
	    $params{'-primary_id'} = $1;
	    $params{'-accession_number'} = $_; # correct?
	    next;
	};
	do { # else
	    push @secondary_ids, $_;
	    next;
	};
    }
    $params{'-secondary_accessions'} = \@secondary_ids;
	    
    $params{'-desc'} = $get->('definition');

    # sequence 
    if ( $self->builder->want_slot('seq')) {
	$params{'-seq'} = $get->('sequence');
    }

    # organism data
    if ( $self->builder->want_slot('species') && $get->('source') ) {
	my $sp = _read_species($get);
	$params{'-species'} = $sp if $sp;
    }

    # keywords
    if ($get->('keywords')) {
	my @kw;
	foreach my $kw ($som->valueof("$stem/GBSeq_keywords/*")) {
	    push @kw, $kw;
	}
	$params{'-keywords'} = join(' ',@kw);
    }
    
    $self->builder->add_slot_value(%params);
    %params = ();    
	
    my $ann;
    # annotations
    if ($self->builder->want_slot('annotation')) {
	$ann = Bio::Annotation::Collection->new();
	# references
	$ann->add_Annotation('reference', $_) for _read_references($stem,$som);
	# comment
	if ($get->('comment')) {
	    $ann->add_Annotation('comment', 
			       Bio::Annotation::Comment->new(
				   -tagname => 'comment',
				   -text => $get->('comment')
				 )
		);
	}
	# project
	if ( $get->('project') ) {
	    $ann->add_Annotation('project',
			       Bio::Annotation::SimpleValue->new(
				   -value => $get->('project')
				 )
		);
	}
	# deal with making dblink as in SeqIO::genbank line 470 here.

	$self->builder->add_slot_value(-annotation => $ann);
    }

    # features
    if ($self->builder->want_slot('features')) {


    }
    
    ($self->{_idx})++;
    return $self->builder->make_object;
}

# mostly ripped from Bio::SeqIO::genbank...

sub _read_species {
    my ($get) = @_;
    
    my @unkn_names = ('other', 'unknown organism', 'not specified', 'not shown',
		      'Unspecified', 'Unknown', 'None', 'unclassified',
		      'unidentified organism', 'not supplied');
    # dictionary of synonyms for taxid 32644
    my @unkn_genus = ('unknown','unclassified','uncultured','unidentified');
    # all above can be part of valid species name

    my( $sub_species, $species, $genus, $sci_name, $common, 
         $abbr_name, $organelle);

    $sci_name = $get->('organism') || return;

    # parse out organelle, common name, abbreviated name if present;
    # this should catch everything, but falls back to
    # entire GBSeq_taxonomy element just in case
    if ($get->('source') =~ m{^
		              (mitochondrion|chloroplast|plastid)?
		              \s*(.*?)
		              \s*(?: \( (.*?) \) )?\.?
		              $}xms ) { 
        ($organelle, $abbr_name, $common) = ($1, $2, $3); # optional
    } else {
        $abbr_name = $get->('source'); # nothing caught; this is a backup!
    }

    # Convert data in classification lines into classification array.
    my @class = split(/; /, $get->('taxonomy'));

    # do we have a genus?
    my $possible_genus =  quotemeta($class[-1])
       . ($class[-2] ? "|" . quotemeta($class[-2]) : '');
    if ($sci_name =~ /^($possible_genus)/) {
	$genus = $1;
	($species) = $sci_name =~ /^$genus\s+(.+)/;
    }
    else {
	$species = $sci_name;
    }

    # is this organism of rank species or is it lower?
    # (we don't catch everything lower than species, but it doesn't matter -
    # this is just so we abide by previous behaviour whilst not calling a
    # species a subspecies)
    if ($species && $species =~ /subsp\.|var\./) {
	($species, $sub_species) = $species =~ /(.+)\s+((?:subsp\.|var\.).+)/;
    }

    # Don't make a species object if it's empty or "Unknown" or "None"
    # return unless $genus and  $genus !~ /^(Unknown|None)$/oi;
    # Don't make a species object if it belongs to taxid 32644
    my $src = $get->('source');
    return unless ($species || $genus) and 
	!grep { $_ eq $src } @unkn_names;

    # Bio::Species array needs array in Species -> Kingdom direction
    push(@class, $sci_name);
    @class = reverse @class;

    my $make = Bio::Species->new();
    $make->scientific_name($sci_name);
    $make->classification(@class) if @class > 0;
    $make->common_name( $common ) if $common;
    $make->name('abbreviated', $abbr_name) if $abbr_name;
    $make->organelle($organelle) if $organelle;

    return $make;
}

sub next_seq { shift->next_obj }

sub _read_references {
    my ($stem, $som) = @_;
    my @ret;
    for ( my $i = 1; $som->valueof($stem."/GBSeq_references/[$i]"); $i++ ) {
	my $get = sub { 
	    $som->valueof($stem."/GBSeq_references/[$i]/GBReference_".shift ) 
	};
	my %params;
	$params{'-title'} = $get->('title');
	$params{'-pubmed'} = $get->('pubmed');
	$params{'-medline'} = $get->('pubmed');
	$params{'-journal'} = $get->('journal');
	$params{'-comment'} = $get->('remark');
	$params{'-consortium'} = $get->('consortium');

	my $pos = $get->('position');
	$pos =~ /^([0-9]+)[.]+([0-9]+)$/;
	$params{'-start'} = $1;
	$params{'-end'} = $2;
	$params{'-gb_reference'} = $get->('reference');
	$params{'-authors'} = '';
	foreach my $author ( $get->('authors/*') ) {
	    $params{'-authors'} .= " $author";
	}
	push @ret, Bio::Annotation::Reference->new(
	    -tagname => 'reference',
	    %params);
    }
    return @ret;
}

sub _read_features {
    my ($stem, $som) = @_;
    my @ret;
    for ( my $i = 0; $som->valueof($stem."/GBSeq_feature-table/[$i]"); $i++ ) {
	my $get = sub { 
	    $som->valueof($stem."/GBSeq_feature-table/[$i]/GBFeature_".shift ) 
	};
	my %params;
	
    }

}
	
1;
__END__

here\'s an example:

PROTEIN

0  HASH(0x439b8a8)
   'GBSet' => HASH(0x439c010)
      'GBSeq' => HASH(0x43a79c8)
         'GBSeq_accession-version' => 'CAA53922.1'
         'GBSeq_comment' => 'On Nov 8, 1997 this sequence version replaced gi:443947.'
         'GBSeq_create-date' => '18-JAN-1994'
         'GBSeq_definition' => 'sonic hedgehog [Mus musculus]'
         'GBSeq_division' => 'ROD'
         'GBSeq_feature-table' => HASH(0x43abf4c)
            'GBFeature' => HASH(0x43b23b4)
               'GBFeature_intervals' => HASH(0x43b800c)
                  'GBInterval' => HASH(0x43b83fc)
                     'GBInterval_accession' => 'CAA53922.1'
                     'GBInterval_from' => 1
                     'GBInterval_to' => 437
               'GBFeature_key' => 'CDS'
               'GBFeature_location' => '1..437'
               'GBFeature_quals' => HASH(0x43b8378)
                  'GBQualifier' => HASH(0x43baeb0)
                     'GBQualifier_name' => 'db_xref'
                     'GBQualifier_value' => 'UniProtKB/Swiss-Prot:Q62226'
         'GBSeq_length' => 437
         'GBSeq_locus' => 'CAA53922'
         'GBSeq_moltype' => 'AA'
         'GBSeq_organism' => 'Mus musculus'
         'GBSeq_other-seqids' => HASH(0x43ab028)
            'GBSeqid' => 'gi|2597988'
         'GBSeq_primary-accession' => 'CAA53922'
         'GBSeq_references' => HASH(0x43abe80)
            'GBReference' => HASH(0x43af1f8)
               'GBReference_authors' => HASH(0x43af3e4)
                  'GBAuthor' => 'McMahon,A.P.'
               'GBReference_journal' => 'Submitted (03-NOV-1997) A.P. McMahon, Harvard University, 16 Divinity Ave., Cambridge, MA 02138, USA'
               'GBReference_position' => '1..437'
               'GBReference_reference' => 3
               'GBReference_title' => 'Direct Submission'
         'GBSeq_sequence' => 'mllllarcflvilassllvcpglacgpgrgfgkrrhpkkltplaykqfipnvaektlgasgryegkitrnserfkeltpnynpdiifkdeentgadrlmtqrckdklnalaisvmnqwpgvklrvtegwdedghhseeslhyegravdittsdrdrskygmlarlaveagfdwvyyeskahihcsvkaensvaaksggcfpgsatvhleqggtklvkdlrpgdrvlaaddqgrllysdfltfldrdegakkvfyvietleprerllltaahllfvaphndsgptpgpsalfasrvrpgqrvyvvaerggdrrllpaavhsvtlreeeagayapltahgtilinrvlascyavieehswahrafapfrlahallaalapartdgggggsipaaqsateargaeptagihwysqllyhigtwlldsetmhplgmavkss'
         'GBSeq_source' => 'Mus musculus (house mouse)'
         'GBSeq_source-db' => 'embl accession X76290.1'
         'GBSeq_taxonomy' => 'Eukaryota; Metazoa; Chordata; Craniata; Vertebrata; Euteleostomi; Mammalia; Eutheria; Euarchontoglires; Glires; Rodentia; Sciurognathi; Muroidea; Muridae; Murinae; Mus'
         'GBSeq_topology' => 'linear'
         'GBSeq_update-date' => '04-NOV-1997'

NUCLEOTIDE

0  HASH(0x42c1a44)
   'GBSet' => HASH(0x42dd728)
      'GBSeq' => HASH(0x44bc2c8)
         'GBSeq_accession-version' => 'NR_029721.1'
         'GBSeq_comment' => 'PROVISIONAL REFSEQ: This record is based on preliminary annotation provided by NCBI staff in collaboration with miRBase. The reference sequence was derived from AL645478.15.; ~Summary: microRNAs (miRNAs) are short (20-24 nt) non-coding RNAs that are involved in post-transcriptional regulation of gene expression in multicellular organisms by affecting both the stability and translation of mRNAs. miRNAs are transcribed by RNA polymerase II as part of capped and polyadenylated primary transcripts (pri-miRNAs) that can be either protein-coding or non-coding. The primary transcript is cleaved by the Drosha ribonuclease III enzyme to produce an approximately 70-nt stem-loop precursor miRNA (pre-miRNA), which is further cleaved by the cytoplasmic Dicer ribonuclease to generate the mature miRNA and antisense miRNA star (miRNA*) products. The mature miRNA is incorporated into a RNA-induced silencing complex (RISC), which recognizes target mRNAs through imperfect base pairing with the miRNA and most commonly results in translational inhibition or destabilization of the target mRNA. The RefSeq represents the predicted microRNA stem-loop. [provided by RefSeq]; ~Sequence Note: This record represents a predicted microRNA stem-loop as defined by miRBase. Some sequence at the 5\' and 3\' ends may not be included in the intermediate precursor miRNA produced by Drosha cleavage.'
         'GBSeq_create-date' => '29-OCT-2009'
         'GBSeq_definition' => 'Mus musculus microRNA 196a-1 (Mir196a-1), microRNA'
         'GBSeq_division' => 'ROD'
         'GBSeq_feature-table' => HASH(0x4579f0c)
            'GBFeature' => HASH(0x457ab6c)
               'GBFeature_intervals' => HASH(0x457fa20)
                  'GBInterval' => HASH(0x45813d0)
                     'GBInterval_accession' => 'NR_029721.1'
                     'GBInterval_from' => 24
                     'GBInterval_to' => 45
               'GBFeature_key' => 'ncRNA'
               'GBFeature_location' => '24..45'
               'GBFeature_quals' => HASH(0x45813e8)
                  'GBQualifier' => HASH(0x4581a90)
                     'GBQualifier_name' => 'db_xref'
                     'GBQualifier_value' => 'MGI:2676860'
         'GBSeq_length' => 102
         'GBSeq_locus' => 'NR_029721'
         'GBSeq_moltype' => 'ncRNA'
         'GBSeq_organism' => 'Mus musculus'
         'GBSeq_other-seqids' => HASH(0x456bea8)
            'GBSeqid' => 'gi|262205520'
         'GBSeq_primary' => 'REFSEQ_SPAN         PRIMARY_IDENTIFIER PRIMARY_SPAN        COMP~1-102               AL645478.15        79764-79865         '
         'GBSeq_primary-accession' => 'NR_029721'
         'GBSeq_references' => HASH(0x45744ac)
            'GBReference' => HASH(0x457ac20)
               'GBReference_authors' => HASH(0x457f36c)
                  'GBAuthor' => 'Tuschl,T.'
               'GBReference_journal' => 'RNA 9 (2), 175-179 (2003)'
               'GBReference_position' => '1..102'
               'GBReference_pubmed' => 12554859
               'GBReference_reference' => 9
               'GBReference_title' => 'New microRNAs from mouse and human'
         'GBSeq_sequence' => 'tgagccgggactgttgagtgaagtaggtagtttcatgttgttgggcctggctttctgaacacaacgacatcaaaccacctgattcatggcagttactgcttc'
         'GBSeq_source' => 'Mus musculus (house mouse)'
         'GBSeq_strandedness' => 'single'
         'GBSeq_taxonomy' => 'Eukaryota; Metazoa; Chordata; Craniata; Vertebrata; Euteleostomi; Mammalia; Eutheria; Euarchontoglires; Glires; Rodentia; Sciurognathi; Muroidea; Muridae; Murinae; Mus'
         'GBSeq_topology' => 'linear'
         'GBSeq_update-date' => '06-JAN-2010'
