#=======================================================================
#	 ____  ____  _____              _    ____ ___   ____
#	|  _ \|  _ \|  ___|  _   _     / \  |  _ \_ _| |___ \
#	| |_) | | | | |_    (_) (_)   / _ \ | |_) | |    __) |
#	|  __/| |_| |  _|    _   _   / ___ \|  __/| |   / __/
#	|_|   |____/|_|     (_) (_) /_/   \_\_|  |___| |_____|
#
#	Copyright 1999-2001 Alfred Reibenschuh <areibens@cpan.org>.
#
#	This library is free software; you can redistribute it 
#	and/or modify it under the same terms as Perl itself.
#
#=======================================================================
#
#	PDF::API2::Outline
#
#=======================================================================
package PDF::API2::Outline;

BEGIN {
	use strict;
	use vars qw( @ISA $hasWeakRef );
	eval " use WeakRef; ";
	$hasWeakRef= $@ ? 0 : 1;
	@ISA = qw(Text::PDF::Dict);
}

use Text::PDF::Dict;
use Text::PDF::Utils;
use PDF::API2::Util;

=head2 PDF::API2::Outline

Subclassed from Text::PDF::Dict.

=over 4

=item $otl = PDF::API2::Outline->new $api,$parent,$prev

Returns a new outline object (called from $otls->outline).

=cut

sub new {
	my ($class,$api,$parent,$prev)=@_;
	my $self = $class->SUPER::new;
	$self->{' apipdf'}=$api->{pdf};
	weaken($self->{' apipdf'}) if($hasWeakRef);
	$self->{' api'}=$api;
	weaken($self->{' api'}) if($hasWeakRef);
	$self->{Parent}=$parent if(defined $parent);
	$self->{Prev}=$prev if(defined $prev);
	return($self);
}

sub parent {
	my $self=shift @_;
	if(defined $_[0]) {
		$self->{Parent}=shift @_;
	}
	return $self->{Parent};
}

sub prev {
	my $self=shift @_;
	if(defined $_[0]) {
		$self->{Prev}=shift @_;
	}
	return $self->{Prev};
}

sub next {
	my $self=shift @_;
	if(defined $_[0]) {
		$self->{Next}=shift @_;
	}
	return $self->{Next};
}

sub first {
	my $self=shift @_;
	$self->{First}=$self->{' childs'}->[0] if(defined $self->{' childs'});
	return $self->{First} ;
}

sub last {
	my $self=shift @_;
	$self->{Last}=$self->{' childs'}->[-1] if(defined $self->{' childs'});
	return $self->{Last};
}

sub count {
	my $self=shift @_;
	my $cnt=scalar @{$self->{' childs'}||[]};
	map { $cnt+=$_->count();} @{$self->{' childs'}};
	$self->{Count}=PDFNum($cnt) if($cnt>0);
	return $cnt;
}

sub fix_outline {
	my ($self)=@_;
	$self->first;
	$self->last;
	$self->count;
}

=item $otl->title $text

Set the title of the outline.

=cut

sub title {
	my ($self,$txt)=@_;
	$self->{Title}=PDFStr($txt);
	return($self);
}

=item $sotl=$otl->outline

Returns a new sub-outline.

=cut

sub outline {
	my $self=shift @_;
	my $obj=PDF::API2::Outline->new($self->{' api'},$self);
	$obj->prev($self->{' childs'}->[-1]) if(defined $self->{' childs'});
	$self->{' childs'}->[-1]->next($obj) if(defined $self->{' childs'});
	push(@{$self->{' childs'}},$obj);
	$self->{' api'}->{pdf}->new_obj($obj) if(!$obj->is_obj($self->{' api'}->{pdf}));
	return $obj;
}

=item $otl->dest $pageobj [, %opts]

Sets the destination page of the outline.

=item $otl->dest( $page, -fit => 1 )

Display the page designated by page, with its contents magnified just enough to
fit the entire page within the window both horizontally and vertically. If the
required horizontal and vertical magnification factors are different, use the
smaller of the two, centering the page within the window in the other dimension.

=item $otl->dest( $page, -fith => $top )

Display the page designated by page, with the vertical coordinate top positioned
at the top edge of the window and the contents of the page magnified just enough
to fit the entire width of the page within the window.

=item $otl->dest( $page, -fitv => $left )

Display the page designated by page, with the horizontal coordinate left positioned
at the left edge of the window and the contents of the page magnified just enough
to fit the entire height of the page within the window.

=item $otl->dest( $page, -fitr => [ $left, $bottom, $right, $top ] )

Display the page designated by page, with its contents magnified just enough to
fit the rectangle specified by the coordinates left, bottom, right, and top
entirely within the window both horizontally and vertically. If the required
horizontal and vertical magnification factors are different, use the smaller of
the two, centering the rectangle within the window in the other dimension.

=item $otl->dest( $page, -fitb => 1 )

Display the page designated by page, with its contents magnified just
enough to fit its bounding box entirely within the window both horizontally and
vertically. If the required horizontal and vertical magnification factors are
different, use the smaller of the two, centering the bounding box within the
window in the other dimension.

=item $otl->dest( $page, -fitbh => $top )

Display the page designated by page, with the vertical coordinate top
positioned at the top edge of the window and the contents of the page magnified
just enough to fit the entire width of its bounding box within the window.

=item $otl->dest( $page, -fitbv => $left )

Display the page designated by page, with the horizontal coordinate
left positioned at the left edge of the window and the contents of the page
magnified just enough to fit the entire height of its bounding box within the
window.

=item $otl->dest( $page, -xyz => [ $left, $top, $zoom ] )

Display the page designated by page, with the coordinates (left, top) positioned
at the top-left corner of the window and the contents of the page magnified by
the factor zoom. A zero (0) value for any of the parameters left, top, or zoom
specifies that the current value of that parameter is to be retained unchanged.

=cut

sub dest {
	my ($self,$page,%opts)=@_;

	die "no valid page '$page' specified." if(!ref($page));

	$opts{-fit}=1 if(scalar(keys %opts)<1);

	if(defined $opts{-fit}) {
		$self->{Dest}=PDFArray($page,PDFName('Fit'));
	} elsif(defined $opts{-fith}) {
		$self->{Dest}=PDFArray($page,PDFName('FitH'),PDFNum($opts{-fith}));
	} elsif(defined $opts{-fitb}) {
		$self->{Dest}=PDFArray($page,PDFName('FitB'));
	} elsif(defined $opts{-fitbh}) {
		$self->{Dest}=PDFArray($page,PDFName('FitBH'),PDFNum($opts{-fitbh}));
	} elsif(defined $opts{-fitv}) {
		$self->{Dest}=PDFArray($page,PDFName('FitV'),PDFNum($opts{-fitv}));
	} elsif(defined $opts{-fitbv}) {
		$self->{Dest}=PDFArray($page,PDFName('FitBV'),PDFNum($opts{-fitbv}));
	} elsif(defined $opts{-fitr}) {
		die "insufficient parameters to ->dest( page, -fitr => [] ) " unless(scalar @{$opts{-fitr}} == 4);
		$self->{Dest}=PDFArray($page,PDFName('FitR'),map {PDFNum($_)} @{$opts{-fitr}});
	} elsif(defined $opts{-xyz}) {
		die "insufficient parameters to ->dest( page, -xyz => [] ) " unless(scalar @{$opts{-fitr}} == 3);
		$self->{Dest}=PDFArray($page,PDFName('XYZ'),map {PDFNum($_)} @{$opts{-xyz}});
	}
	return($self);
}

sub out_obj {
	my ($self,@param)=@_;
	$self->fix_outline;
	return $self->SUPER::out_obj(@param);
}

sub outobjdeep {
	my ($self,@param)=@_;
	$self->fix_outline;
	foreach my $k (qw/ api apipdf apipage /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	my @ret=$self->SUPER::outobjdeep(@param);
	foreach my $k (qw/ First Parent Next Last Prev /) {
		$self->{$k}=undef;
		delete($self->{$k});
	}
	return @ret;
}

1;

__END__

=head1 AUTHOR

alfred reibenschuh

=cut