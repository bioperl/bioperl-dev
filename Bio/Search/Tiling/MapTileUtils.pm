#$Id: MapTileUtils.pm 433 2009-05-19 19:19:38Z maj $
package Bio::Search::Tiling::MapTileUtils;
use strict;
use warnings;
use Exporter;

BEGIN {
    our @ISA = qw( Exporter );
    our @EXPORT = qw( get_intervals_from_hsps interval_tiling decompose_interval );
}

# tiling trials
# assumed: intervals are [$a0, $a1], with $a0 <= $a1
=head1 NAME

Bio::Search::Tiling::MapTileUtils - utilities for manipulating closed intervals for an HSP tiling algorithm

=head1 SYNOPSIS

Not used directly.

=head1 DESCRIPTION

=head1 NOTE

An "interval" in this module is defined as an arrayref C<[$a0, $a1]>, where
C<$a0, $a1> are scalar numbers satisfying C<$a0 E<lt>= $a1>.

=head1 AUTHOR

Mark A. Jensen <maj -at- fortinbras -dot- us>

=head1 APPENDIX

=head2 interval_tiling    

 Title   : interval_tiling()
 Usage   : @tiling = interval_tiling( \@array_of_intervals )
 Function: Find minimal set of intervals covering the input set
 Returns : array of arrayrefs of the form
  ( [$interval => [ @indices_of_collapsed_input_intervals ]], ...)
 Args    : arrayref of intervals

=cut

sub interval_tiling {
    return unless $_[0]; # no input
    my $n = scalar @{$_[0]};
    my %input;
    @input{(0..$n-1)} = @{$_[0]};
    my @active = (0..$n-1);
    my @hold;
    my @tiled_ints;
    my @ret;
    while (@active) {
	my $tgt = $input{my $tgt_i = shift @active};
	push @tiled_ints, $tgt_i;
	my $tgt_not_disjoint = 1;
	while ($tgt_not_disjoint) {
	    $tgt_not_disjoint = 0;
	    while (my $try_i = shift @active) {
		my $try = $input{$try_i};
		if ( !are_disjoint($tgt, $try) ) {
		    $tgt = min_covering_interval($tgt,$try);
		    push @tiled_ints, $try_i;
		    $tgt_not_disjoint = 1;
		}
		else {
		    push @hold, $try_i;
		}
	    }
	    if (!$tgt_not_disjoint) {
		push @ret, [ $tgt => [@tiled_ints] ];
		@tiled_ints = ();
	    }
	    @active = @hold;
	    @hold = ();
	}
    }
    return @ret;
}

=head2 decompose_interval

 Title   : decompose_interval
 Usage   : @decomposition = decompose_interval( \@overlappers )
 Function: Calculate the disjoint decomposition of a set of
           overlapping intervals, each annotated with a list of
           covering intervals
 Returns : array of arrayrefs of the form
           ( [[@interval] => [@indices_of_coverers]], ... )
 Args    : arrayref of intervals (arrayrefs like [$a0, $a1], with
 Note    : Each returned interval is associated with a list of indices of the
           original intervals that cover that decomposition component
           (scalar size of this list could be called the 'coverage coefficient')
 Note    : Coverage: each component of the decomp is completely contained
           in the input intervals that overlap it, by construction.
 Caveat  : This routine expects the members of @overlappers to overlap,
           but doesn't check this.

=cut

### what if the input intervals don't overlap?? They MUST overlap; that's
### what interval_tiling() is for.

sub decompose_interval {
    return unless $_[0]; # no input
    my @ints = @{$_[0]};
    my (%flat,@flat);
    ### this is ok, but need to handle the case where a lh and rh endpoint
    ### coincide...
    # decomposition --
    # flatten:
    # every lh endpoint generates (lh-1, lh)
    # every rh endpoint generates (rh, rh+)
    foreach (@ints) {
	$flat{$$_[0]-1}++;
	$flat{$$_[0]}++;
	$flat{$$_[1]}++;
	$flat{$$_[1]+1}++;
    }
    # sort, create singletons if nec.
    my @a;
    @a = sort {$a<=>$b} keys %flat;
    # throw out first and last (meeting a boundary condition)
    shift @a; pop @a;
    # look for singletons
    @flat = (shift @a, shift @a);
    if ( $flat[1]-$flat[0] == 1 ) {
	@flat = ($flat[0],$flat[0], $flat[1]);
    }
    while (my $a = shift @a) {
	if ($a-$flat[-2]==2) {
	    push @flat, $flat[-1]; # create singleton interval
	}
	push @flat, $a;
    }
    # component intervals are consecutive pairs
    my @decomp;
    while (my $a = shift @flat) {
	push @decomp, [$a, shift @flat];
    }

    # for each component, return a list of the indices of the input intervals
    # that cover the component.
    my @coverage;
    foreach my $i (0..$#decomp) {
	foreach my $j (0..$#ints) {
	    unless (are_disjoint($decomp[$i], $ints[$j])) {
		if (defined $coverage[$i]) {
		    push @{$coverage[$i]}, $j;
		}
		else {
		    $coverage[$i] = [$j];
		}
	    }
	}
    }
    return map { [$decomp[$_] => $coverage[$_]] } (0..$#decomp);
}    

=head2 are_disjoint

 Title   : are_disjoint
 Usage   : are_disjoint( [$a0, $a1], [$b0, $b1] )
 Function: Determine if two intervals are disjoint
 Returns : True if the intervals are disjoint, false if they overlap
 Args    : array of two intervals

=cut

sub are_disjoint {
    my ($int1, $int2) = @_;
    return 1 if ( $$int1[1] < $$int2[0] ) || ( $$int2[1] < $$int1[0]);
    return 0;
}

=head2 min_covering_interval

 Title   : min_covering_interval 
 Usage   : $interval = min_covering_interval( [$a0,$a1],[$b0,$b1] )
 Function: Determine the minimal covering interval for two intervals
 Returns : an interval
 Args    : two intervals

=cut

sub min_covering_interval {
    my ($int1, $int2) = @_;
    my @a = sort {$a <=> $b} (@$int1, @$int2);
    return [$a[0],$a[-1]];
}

=head2 get_intervals_from_hsps

 Title   : get_intervals_from_hsps
 Usage   : @intervals = get_intervals_from_hsps($type, @hsp_objects)
 Function: Return array of intervals of the form [ $start, $end ],
           from an array of hsp objects
 Returns : an array of intervals
 Args    : scalar $type, array of HSPI objects; where $type is one of 'hit',
           'subject', 'query'

=cut

sub get_intervals_from_hsps {
    my $type = shift;
    my @hsps;
    if (ref($type) =~ /HSP/) {
	push @hsps, $type;
	$type = 'query';
    }
    elsif ( !grep /^$type$/,qw( hit subject query ) ) {
	die "Unknown HSP type '$type'";
    }
    $type = 'hit' if $type eq 'subject';
    push @hsps, @_;
    my @ret;
    foreach (@hsps) {
#	push @ret, [ $_->start($type), $_->end($type)];
	push @ret, [ $_->range($type) ];
    }
    return @ret;
}
1;
