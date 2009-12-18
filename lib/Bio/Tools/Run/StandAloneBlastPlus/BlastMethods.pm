# $Id$
#
# BioPerl module for Bio::Tools::Run::StandAloneBlastPlus::BlastMethods
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

Bio::Tools::Run::StandAloneBlastPlus::BlastMethods - Provides BLAST methods to StandAloneBlastPlus

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

This module provides the BLAST methods (blastn, blastp, psiblast, etc.) to the L<Bio::Tools::Run::StandAloneBlastPlus> object.

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

# note: providing methods directly to the namespace...
package Bio::Tools::Run::StandAloneBlastPlus;
use strict;
use warnings;

use Bio::SearchIO;
use lib '../../../..';
use Bio::Tools::Run::BlastPlus;
use File::Temp;

our @BlastMethods = qw( blastp blastn blastx tblastn tblastx 
                       psiblast rpsblast rpstblastn );

sub run {
    my $self = shift;
    my @args = @_;
    my ($method, $query, $outfile, $method_args) = $self->_rearrange( [qw( 
                                         METHOD
                                         QUERY
                                         OUTFILE
                                         METHOD_ARGS
                                         )], @args);
    my $ret;
    
    unless ($method) {
	$self->throw("Blast run: method not specified, use -method");
    }
    unless ($query) {
	$self->throw("Blast run: query data required, use -query");
    }
    unless ($outfile) { # create a tempfile name
	my $fh = File::Temp->new(TEMPLATE => 'BLOXXXXX',
				 UNLINK => 0);
	$outfile = $fh->filename;
	$fh->close;
	$self->_register_temp_for_cleanup($outfile);
    }
    my %usr_args;
    if ($method_args) {
	$self->throw("Blast run: method arguments must be name => value pairs") unless !(@$method_args % 2);
	%usr_args = @$method_args;
    }
    # make db if necessary
    $self->make_db unless $self->check_db;

    $self->{_factory} = Bio::Tools::Run::BlastPlus->new( -command => $method );
    if (%usr_args) {
	my @avail_parms = $self->factory->available_parameters('all');
	while ( my( $key, $value ) = each %usr_args ) {
	    $key =~ s/^-//;
	    unless (grep /^$key$/, @avail_parms) {
		$self->throw("Blast run: parameter '$key' is not available for method '$method'");
	    }
	}
    }

    my %blast_args;
    $blast_args{-db} = $self->db;
    $blast_args{-query} = $self->_fastize($query);
    $blast_args{-out} = $outfile;
    # user arg override
    if (%usr_args) {
	$blast_args{$_} = $usr_args{$_} for keys %usr_args;
    }

    $self->factory->set_parameters( %blast_args );
    $self->factory->no_throw_on_crash( $self->no_throw_on_crash );
    my $status = $self->_run;

    return $status unless $status;
    # if here, success 
    for ($method) {
	m/^[t]?blast[npx]/ && do {
	    $ret = Bio::SearchIO->new(-file => $outfile, 
				      -format => 'blast');
	    $self->{_blastout} = $outfile;
	    $ret = $ret->next_result;
	    last;
	};
	do {
	    1; # huh?
	};
    }
    
    return $ret;
}


1;
