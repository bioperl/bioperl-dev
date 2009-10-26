# BioPerl module for Bio::DB::GuessDB
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Chase Miller <chmille4 at gmail dot com>
#
# Copyright Chase Miller, Hans-Rudolf Hotz
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
# 

=head1 NAME

Bio::DB::GuessDB - guesses source database of an accession number

=head1 SYNOPSIS

  # ...To be added!

=head1 DESCRIPTION

This is a simple module that tries to analyze an accesion number 
and determine which database it belongs to

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the 
evolution of this and other Bioperl modules. Send
your comments and suggestions preferably to one
of the Bioperl mailing lists. Your participation
is much appreciated.

  bioperl-l@lists.open-bio.org               - General discussion
  http://www.bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 

Please direct usage questions or support issues to the mailing list:

I<bioperl-l@bioperl.org>

rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to
help us keep track the bugs and their resolution.
Bug reports can be submitted via the web.

  http://bugzilla.open-bio.org/

=head1 AUTHOR

Chase Miller
Email chmille4 at gmail dot com

Hans-Rudolf Hotz
hans-rudolf.hotz@fmi.ch


=head1 APPENDIX

The rest of the documentation details each of the
object methods. Internal methods are usually
preceded with a _

=cut

# Let the code begin...


package Bio::DB::GuessDB;
use strict;

sub guessDB {
	my ($self, $accession) = @_;
	
	#add logic
}