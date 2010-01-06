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

Describe contact details here

=head1 CONTRIBUTORS

Additional contributors names and emails here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

# Let the code begin...


package Bio::Tools::Run::SoapEUtilities::FetchAdaptor::seq;
use strict;

use lib '../../../../..'; # remove later
use Bio::Root::Root;
use Bio::Seq::SeqBuilder;

use base qw(Bio::Root::Root Bio::Tools::Run::SoapEUtilities::FetchAdaptor);

=head2 new

 Title   : new
 Usage   : my $obj = new Bio::Tools::Run::SoapEUtilities::FetchAdaptor::seq();
 Function: Builds a new Bio::Tools::Run::SoapEUtilities::FetchAdaptor::seq object
 Returns : an instance of Bio::Tools::Run::SoapEUtilities::FetchAdaptor::seq
 Args    :

=cut

sub new {
    my ($class,@args) = @_;
    my $self = $class->SUPER::new(@args);

    $self->{'_result'} = $self->_rearrange( (qw[RESULT]), @args );
    $self->{'_obj_class'} = 'Bio::RichSeq'; # ??
    
    return $self;
}

sub obj_class { shift->{'_obj_class'} }

sub next_obj {
    my $self = shift;

}
    
1;
__END__

here\'s an example:

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
