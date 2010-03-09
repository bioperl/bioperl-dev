#!/usr/bin/perl -w

use strict;
use Bio::SearchIO;
use Data::Dumper;

#Try this on either test_results_default.hscan, test_results_default.hsearch
#or test_results_noalignment.hsearch
my $searchobj = Bio::SearchIO->new(-file => $ARGV[0], -format => 'hmmer3');
my $resct = 0;
while ( my $res = $searchobj->next_result() ) {
#  print Dumper($res);
  my $algorithm  = $res->algorithm();
  my $query      = $res->query_name();
  my $qacc       = $res->query_accession();
  my $qlen       = $res->query_length();
  my $qdesc      = $res->query_description();
  my $num_hits   = $res->num_hits();
  print "PROCESSING $algorithm RESULT:\n\t";
  print join ("\n\t", "query: " . $query, "desc: " . $qdesc, "length: ". $qlen, "num_hits: " . $num_hits);
  print "\n\t\t";
  while (my $hit = $res->next_hit() ){
    my $hitid    = $hit->name();
    my $score    = $hit->raw_score();
    my $signif   = $hit->significance();
    print join ("\n\t\t", "hit: " . $hitid, "score: " . $score, "evalue: " . $signif);
    print "\n\t\t\t";
    my $nhsp     = 0;
    while ( my $hsp = $hit->next_hsp() ){
      my $gaps      = $hsp->gaps();
      my $hsplen    = $hsp->length('total');
      my $hqlen     = $hsp->length('query');
      my $hhlen     = $hsp->length('hit');
      my $qrange    = $hsp->range('query');
      my $hrange    = $hsp->range('hit');
      my $hstart    = $hsp->start('hit');
      my $hstop     = $hsp->end('hit');
      my $qstart    = $hsp->start('query');
      my $qstop     = $hsp->end('query');
      print join("\n\t\t\t", "qstart: " . $qstart, "qstop: " . $qstop, "hstart: " . $hstart, "hstop: " . $hstop, "qrange: " . $qrange, "hrange: " . $hrange, "hsplen: " . $hsplen, "hqlen: " . $hqlen, "hhlen: " . $hhlen, "gaps: " . $gaps);
      print "\n";
      $nhsp++;
    }
  }
  print "\n\t\t\t\tNEXT RESULT\n";
}

