#$Id$#
package HIVXmlSchemaHelper; # fully qualify namespace eventually
use strict;

=head1 NAME

Bio::DB::HIV::HIVXmlSchemaHelper - XML conversion routines for the Bio::DB::HIV and Bio::DB::Query::HIVQuery namespaces 
(This package eventually bound for bioperl-dev)

=head1 SYNOPSIS

No routines for direct use.

=head1 DESCRIPTION

This package contains internal methods assigned to existing module
namespaces in BioPerl modules C<Bio::DB::HIV> and
C<Bio::DB::Query>. They are used to help create schema-valid XML
messages from sequence metadata returned by the Los Alamos National
Laboratories' CGI interface to their HIV Sequence Database.  The
custom XML namespace to which these routines correspond is
L<http://fortinbras.us/HIVDBSchema/1.0>. Schema definition files can
be obtained at that URL.

=head1 IMPORTANT CAVEAT

These routines are dependent upon revision >= 15594 of
C<Bio::DB::Query::HIVQuery> and revision >= 15593 of
C<Bio::DB::HIV::HIVQueryHelper>. The most recent versions of these
modules are available by SVN checkout from the trunk at
L<svn://code.open-bio.org/bioperl/bioperl-live/trunk/>

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

    1;

# add a couple of translation subs to HIVSchema
package HIVSchema;
use strict;
our %_ankeys_to_fields = ();
our %_values_to_codes = ();

=head1 in package HIVSchema (Bio::DB::HIV::HIVQueryHelper)

=head2 _field_from_ankey
 
 Title:     _field_from_ankey
 Usage:     $schema->_field_from_ankey($ankey)
 Function:  For converting from LANL's "native" returned annotation headers
            to C<Bio::DB::HIV>'s custom XML LANL database representation 
            (C<lanl-schema.xml>).
 Args:      a[n array of] scalar string[s], valid as <ankey> elements in 
            C<lanl-schema.xml>

=cut

sub _field_from_ankey {
    my $self = shift;
    my @args = @_;
    # memoize here
    unless (%_ankeys_to_fields) {
	my %a = $self->ankh( $self->fields );
	while ( my ($fld, $ankh) = each %a ) { 
	    $_ankeys_to_fields{$ankh->{ankey}} = $fld;
	}
    }
    return wantarray ? @_ankeys_to_fields{@args} : $_ankeys_to_fields{$args[0]};
}

=head2 _code_from_value

 Title:    _code_from_value
 Usage:    $schema->_code_from_value($fieldname, @field_values);
 Function: Convert a LANL annotation return value (encoded in the 
           C<Bio::DB::HIV> custom schema as "desc" attributes to 
           <option> elements) to the *code attribute for the 
           XSD element associated with the (custom schema) <sfield>
           field name.
 Returns:  [an array of] code[s] (= "option" elts) looked up by field 
           value[s] (= "desc" attributes)
 Args:     the custom fieldname (in table.column format), followed by
           [an array of] the "desc" value[s] to be converted
 Note:     Requires Bio::DB::HIV::HIVQueryHelper revision 15593!

=cut

sub _code_from_value {
    my $self = shift;
    my ($fld, @val) = @_;
    # memoize here
    unless (%_values_to_codes) {
	foreach my $word ( qw( country risk_factor badseq georegion ) ) {
	    my @flds = grep /$word$/, $self->fields;
	    foreach my $f (@flds) {
		my %h;
		@h{@{$self->_sfieldh($f)->{desc}}} = 
		    @{$self->_sfieldh($f)->{option}};
		$_values_to_codes{$f} = {%h};
	    }
	}
    }
    return wantarray ? 
	@{$_values_to_codes{$fld}}{@val} : 
	$_values_to_codes{$fld}->{$val[0]};

}

1; 

package Bio::DB::Query::HIVQuery;
use strict;

=head1 in package Bio::DB::Query::HIVQuery
 
=head2 _xml_hashref_from_id
    
 Title:     _xml_hashref_from_id
 Function:  create an instance of 
            {http://fortinbras.us/HIVDBSchema/1.0}annotSeqType as a 
            hash of hashes ... of hashes suitable for use in
            XML writers compiled using XML::Compile::Schema against
            the namespace http://fortinbras.us/HIVDBSchema/1.0, using
            annotation data returned by a Bio::DB::Query::HIVQuery
            object executed at RUN_LEVEL 2.
 Arguments: an [array of] LANL sequence id number[s]
 Returns:   an array of {hash of hashes ... of hashes}
 Note:      When an annotation is returned whose value is the empty
            string (i.e. get_value($level1,$tag) is ''), the current
            implementation leaves out that tag in the returned
            hash. This is not desirable, but works around a 
            probable bug in XML::Compile::Schema.

=cut

sub _xml_hashref_from_id {
    my ($self, @id) = @_;
    my $sch = $self->_schema;
    my @ret;
    my @annotTypes = ('Geo', 'Patient', 'Sample', 'StdMap', 'Virus');
    my @skip_flds = ($sch->pk('patient'),  map { $sch->foreignkey($_) } $sch->tables);

    foreach my $id (@id) {
	my $ac = $self->get_annotations_by_id($id);
	next unless $ac; # dne
	my %h; # 
	# create 'registration' element

	my ($gba, $gi, $ver, $pat_id, $loc_id) = 
	    ($self->get_accessions_by_id($id),
	     $ac->get_value('Special', 'gi_number'),
	     $ac->get_value('Special', 'version'),
	     $ac->get_value('Patient', 'pat_id'),
	     $ac->get_value('Virus', 'loc_id'));
	my $reg = $h{'registration'} = {};

	$reg->{'sequenceIds'}{LANLSeqId} = $id ;
	$reg->{'sequenceIds'}{GenBankAccn} = $gba if $gba;
	$reg->{'sequenceIds'}{GI} = $gi if $gi;
	$reg->{'sequenceIds'}{SeqVersion} = $ver if $ver;
	$reg->{LANLPatientId} = $pat_id if $pat_id;
	$reg->{LANLLocationId} = $loc_id if $loc_id;

	# create annotation elements as required...
	# can leave out most 'Special' annotations (already took care of 
	# various ids)

	my ($entry, $comments_acc);
	# accumulators for annotations
	$entry = {};
	$comments_acc = {};
	# add registration element
	$entry->{registration} = $reg;

	foreach my $antype (@annotTypes) {
	    foreach my $ankey ($ac->get_keys($antype)) {
		# get the fieldname from the annotation key
		my $fld = $sch->_field_from_ankey($ankey);
		my $val = $ac->get_value($antype, $ankey);

		# now parse the fieldname to acquire the correct
		# hashref keys for an XML::Compile write for the 
		# hivqSchema...
		# handle the specials
		for ($fld) {
		    # skip the foreign key fields, pat_id (already handled)...
		    last if grep /$fld/, @skip_flds; 
		    (/comment$|badseq$/) && do { 
                        # comments
			m/pat_comment/ && do {$$comments_acc{LANLPatComment}=$val;};
			m/db_comment/  && do {$$comments_acc{LANLDBComment}=$val;};
			m/gb_comment/  && do {$$comments_acc{GenBankComment}=$val;};
			m/badseq/      && do {
			    $$comments_acc{LANLProblematicSeq} = 
				($val ? 
				 {
				     'problematicValue' => $val,
				     'problemcode' => $sch->_code_from_value($fld, $val)
				 } :
				 undef );
#				    ('xsi:nil' => 'true')
			    
			};
			last;
		    };
		    (/country$/) && do {
			# has attributes...
			my $tbl = $sch->tbl($fld);
			my $col = $sch->col($fld);
			$$entry{$tbl}->{$col} = 
			    ( $val ? 
			      {
				  'countryString' => $val,
				  'ccode' => $sch->_code_from_value($fld, $val)
			      } :
			      undef );
#			     ( 'xsi:nil' => 'true' )
			last;
		    };
		    (/risk_factor$|country$|georegion$/) && do { 
                        # have attributes...
			my $tbl = $sch->tbl($fld);
			my $col = $sch->col($fld);
			$$entry{$tbl}->{$col} = 
			    ($val ?
			     {
				 $col.'String' => $val,
				 'LANLcode' => $sch->_code_from_value($fld, $val)
			     } :
			     undef
			    );
#			     ( 'xsi:nil' => 'true' )
			last;
		    };
		    (/second_receptor/) && do {
			my @cr = split(/\s+/,$val);
			$$entry{$sch->tbl($fld)}->{'coreceptor_list'} =
			    [@cr] || undef;
			$$entry{$sch->tbl($fld)}->{$sch->col($fld)} = 
			    $val || undef;
			last;
		    };
		    do { 
                        # default formatted elements...
			$$entry{$sch->tbl($fld)}->{$sch->col($fld)} = 
			    $val || undef;
# { 'xsi:nil' => 'true' };
			last;
		    };
		} # for ($fld)

	    }
	}
	# enter accumulated comments, if any:
	$entry->{comments} = $comments_acc if %{$comments_acc};
	# probably a better way to do the following:
      KEY: 
	foreach my $k (keys %$entry) {
	    foreach (keys %{$$entry{$k}}) {
		next KEY if defined($$entry{$k}->{$_});
	    }
	    delete $entry->{$k}; # no defined elts found
	}

	# put the completed annotation hash-of-hashes into the return
	# array here.
	push @ret, $entry;
	
    }
    return wantarray ? @ret : $ret[0];
}

1;
