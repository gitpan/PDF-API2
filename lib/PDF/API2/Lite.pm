#==================================================================
#
# Copyright 1999-2001 Alfred Reibenschuh <areibens@cpan.org>.
#
# This library is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
#==================================================================
package PDF::API2::Lite;

BEGIN {
	use vars qw( $VERSION $hasWeakRef );
	( $VERSION ) = '$Revisioning: 0.2.3.8 $ ' =~ /\$Revisioning:\s+([^\s]+)/;
	eval " use WeakRef; ";
	$hasWeakRef= $@ ? 0 : 1;
	$PDF::API2::Lite::useInternalFonts=0;
	$PDF::API2::Lite::loadedInternalFonts=0;
}



=head1 PDF::API2::Lite

=head1 NAME

PDF::API2:: - A lite high-level wrapper around PDF::API2 for pdf-creation only.

=head1 SYNOPSIS

	use PDF::API2::Lite;

	$pdf = PDF::API2::Lite->new;
	$pdf->page(595,842);
	$img = $pdf->image('some.jpg');
	$font = $pdf->corefont('Times-Roman');
	$font = $pdf->ttfont('TimesNewRoman.ttf');

=cut

use PDF::API2;
use PDF::API2::Util;
use Text::PDF::Utils;

use POSIX qw( ceil floor );

=head1 METHODS

=head2 PDF::API2::Lite

=item $pdf = PDF::API::Lite->new

=cut

sub new {
	my $class=shift(@_);
	my %opt=@_;
	my $self={};
	bless($self,$class);
	$self->{api}=PDF::API2->new(@_);
	return $self;
}

=item $pdf->page

=item $pdf->page $width,$height

=item $pdf->page $llx, $lly, $urx, $ury

Opens a new page.

=cut

sub page {
	my $self=shift;
	$self->{page}=$self->{api}->page; 
	$self->{page}->mediabox(@_) if($_[0]);
	$self->{hybrid}=$self->{page}->hybrid;
	$self->{hybrid}->compress;
	return $self;
}


=item $pdf->mediabox $w, $h

=item $pdf->mediabox $llx, $lly, $urx, $ury

Sets the global mediabox.

=cut

sub mediabox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{api}->mediabox($x1,$y1,$x2,$y2);
	} else {
		$self->{api}->mediabox($x1,$y1);
	}
	$self;
}

=item $pdf->saveas $file

Saves the document (may not be modified later) and
deallocates the pdf-structures.

=cut

sub saveas {
	my ($self,$file)=@_;
	if($file eq '-') {
		return $self->{api}->stringify;
	} else {
		$self->{api}->saveas($file);
		return $self;
	}
	$self->{api}->end;
	foreach my $k (keys %{$self}) {
		if(UNIVERSAL::can($k,'release')) {
			$k->release(1);
		} elsif(UNIVERSAL::can($k,'end')) {
			$k->end;
		}
		$self->{$k}=undef;
		delete($self->{$k});
	}
	return undef;
}


=item $font = $pdf->corefont $fontname

Returns a new or existing adobe core font object.

B<Examples:>

	$font = $pdf->corefont('Times-Roman');
	$font = $pdf->corefont('Times-Bold');
	$font = $pdf->corefont('Helvetica');
	$font = $pdf->corefont('ZapfDingbats');

=cut

sub corefont {
	my ($self,$name,@opts)=@_;
	my $obj;
	if($PDF::API2::Lite::useInternalFonts) {
		eval " use PDF::API2::cFont; " unless($PDF::API2::Lite::loadedInternalFonts);
		$PDF::API2::Lite::loadedInternalFonts=1;
		$obj=PDF::API2::cFont->new_api($self->{api},$name,@opts);
	} else {
		$obj=$self->{api}->corefont($name,1);
	}
	return $obj;
}

=item $font = $pdf->ttfont $ttfile

Returns a new or existing truetype font object.

B<Examples:>

	$font = $pdf->ttfont('TimesNewRoman.ttf');
	$font = $pdf->ttfont('/fonts/Univers-Bold.ttf');
	$font = $pdf->ttfont('../Democratica-SmallCaps.ttf');

=cut

sub ttfont {
	my ($self,$file)=@_;
	return $self->{api}->ttfont($file);
}

=item $img = $pdf->loadimage $file

Returns a new image object.

B<Examples:>

	$img = $pdf->loadimage('yetanotherfun.jpg');
	$img = $pdf->loadimage('truly24bitpic.png');
	$img = $pdf->loadimage('reallargefile.pnm');

=cut

sub loadimage {
	my ($self,$file)=@_;
	return $self->{api}->image($file);
}

=item $pdf->savestate

Saves the state of the page.

=cut

sub savestate {
	my $self=shift @_;
	$self->{hybrid}->save;
}

=item $pdf->restorestate

Restores the state of the page.

=cut

sub restorestate {
	my $self=shift @_;
	$self->{hybrid}->restore;
}

=item $pdf->fillcolor $color

Sets fillcolor.

=cut

sub fillcolor {
	my $self=shift @_;
	$self->{hybrid}->fillcolor(shift);
	return($self);
}

=item $pdf->strokecolor $color

Sets strokecolor.

B<Defined color-names are:>

	aliceblue, 
	antiquewhite, 
	aqua, 
	aquamarine, 
	azure,
	beige, 
	bisque, 
	black, 
	blanchedalmond, 
	blue,
	blueviolet, 
	brown, 
	burlywood, 
	cadetblue, 
	chartreuse,
	chocolate, 
	coral, 
	cornflowerblue, 
	cornsilk, 
	crimson,
	cyan, 
	darkblue, 
	darkcyan, 
	darkgoldenrod, 
	darkgray,
	darkgreen, 
	darkgrey, 
	darkkhaki, 
	darkmagenta,
	darkolivegreen, 
	darkorange, 
	darkorchid, 
	darkred,
	darksalmon, 
	darkseagreen, 
	darkslateblue, 
	darkslategray,
	darkslategrey, 
	darkturquoise, 
	darkviolet, 
	deeppink,
	deepskyblue, 
	dimgray, 
	dimgrey, 
	dodgerblue, 
	firebrick,
	floralwhite, 
	forestgreen, 
	fuchsia, 
	gainsboro, 
	ghostwhite,
	gold, 
	goldenrod, 
	gray, 
	grey, 
	green, 
	greenyellow,
	honeydew, 
	hotpink, 
	indianred, 
	indigo, 
	ivory, 
	khaki,
	lavender, 
	lavenderblush, 
	lawngreen, 
	lemonchiffon,
	lightblue, 
	lightcoral, 
	lightcyan, 
	lightgoldenrodyellow,
	lightgray, 
	lightgreen, 
	lightgrey, 
	lightpink, 
	lightsalmon,
	lightseagreen, 
	lightskyblue, 
	lightslategray,
	lightslategrey, 
	lightsteelblue, 
	lightyellow, 
	lime,
	limegreen, 
	linen, 
	magenta, 
	maroon, 
	mediumaquamarine,
	mediumblue, 
	mediumorchid, 
	mediumpurple, 
	mediumseagreen,
	mediumslateblue, 
	mediumspringgreen, 
	mediumturquoise,
	mediumvioletred, 
	midnightblue, 
	mintcream, 
	mistyrose,
	moccasin, 
	navajowhite, 
	navy, 
	oldlace, 
	olive, 
	olivedrab,
	orange, 
	orangered, 
	orchid, 
	palegoldenrod, 
	palegreen,
	paleturquoise, 
	palevioletred, 
	papayawhip, 
	peachpuff,
	peru, 
	pink, 
	plum, 
	powderblue, 
	purple, 
	red, 
	rosybrown,
	royalblue, 
	saddlebrown, 
	salmon, 
	sandybrown, 
	seagreen,
	seashell, 
	sienna, 
	silver, 
	skyblue, 
	slateblue, 
	slategray,
	slategrey, 
	snow, 
	springgreen, 
	steelblue, 
	tan, 
	teal,
	thistle, 
	tomato, 
	turquoise, 
	violet, 
	wheat, 
	white,
	whitesmoke, 
	yellow, 
	yellowgreen

or the rgb-hex-notation:

	#rgb, #rrggbb, #rrrgggbbb and #rrrrggggbbbb

or the cmyk-hex-notation:

	%cmyk, %ccmmyykk, %cccmmmyyykkk and %ccccmmmmyyyykkkk

and additionally the hsv-hex-notation:

	!hsv, !hhssvv, !hhhsssvvv and !hhhhssssvvvv

=cut

sub strokecolor {
	my $self=shift @_;
	$self->{hybrid}->strokecolor(shift);
	return($self);
}

=item $pdf->linedash @dash

Sets linedash.

=cut

sub linedash {
	my ($self,@a)=@_;
	$self->{hybrid}->linedash(@a);
	return($self);
}

=item $pdf->linewidth $width

Sets linewidth.

=cut

sub linewidth {
	my ($self,$linewidth)=@_;
	$self->{hybrid}->linewidth($linewidth);
	return($self);
}

=item $pdf->transform %opts

Sets transformations (eg. translate, rotate, scale, skew) in pdf-canonical order.

B<Example:>

	$pdf->transform(
		-translate => [$x,$y],
		-rotate    => $rot,
		-scale     => [$sx,$sy],
		-skew      => [$sa,$sb],
	)

=cut

sub transform {
	my ($self,%opt)=@_;
	$self->{hybrid}->transform(%opt);
	return($self);
}

=item $pdf->move $x, $y

=cut

sub move { # x,y ...
	my $self=shift @_;
	$self->{hybrid}->move(@_);
	return($self);
}

=item $pdf->line $x, $y

=cut

sub line { # x,y ...
	my $self=shift @_;
	$self->{hybrid}->line(@_);
	return($self);
}

=item $pdf->curve $x1, $y1, $x2, $y2, $x3, $y3

=cut

sub curve { # x1,y1,x2,y2,x3,y3 ...
	my $self=shift @_;
	$self->{hybrid}->curve(@_);
	return($self);
}

=item $pdf->arc $x, $y, $a, $b, $alfa, $beta, $move

=cut

sub arc { # x,y,a,b,alf,bet[,mov]
	my $self=shift @_;
	$self->{hybrid}->arc(@_);
	return($self);
}

=item $pdf->ellipse $x, $y, $a, $b

=cut

sub ellipse {
	my $self=shift @_;
	$self->{hybrid}->ellipse(@_);
	return($self);
}

=item $pdf->circle $x, $y, $r

=cut

sub circle {
	my $self=shift @_;
	$self->{hybrid}->circle(@_);
	return($self);
}

=item $pdf->rect $x,$y, $w,$h

=cut

sub rect { # x,y,w,h ...
	my $self=shift @_;
	$self->{hybrid}->rect(@_);
	return($self);
}

=item $pdf->rectxy $x1,$y1, $x2,$y2

=cut

sub rectxy {
	my $self=shift @_;
	$self->{hybrid}->rectxy(@_);
	return($self);
}

=item $pdf->poly $x1,$y1, ..., $xn,$yn

=cut

sub poly {
	my $self=shift @_;
	$self->{hybrid}->poly(@_);
	return($self);
}

=item $pdf->close

=cut

sub close {
	my $self=shift @_;
	$self->{hybrid}->close;
	return($self);
}

=item $pdf->stroke

=cut

sub stroke {
	my $self=shift @_;
	$self->{hybrid}->stroke;
	return($self);
}

=item $pdf->fill

=cut

sub fill { # nonzero
	my $self=shift @_;
	$self->{hybrid}->fill;
	return($self);
}

=item $pdf->fillstroke

=cut

sub fillstroke { # nonzero
	my $self=shift @_;
	$self->{hybrid}->fillstroke;
	return($self);
}

=item $pdf->image $imgobj, $x,$y, $w,$h

=item $pdf->image $imgobj, $x,$y, $scale

=item $pdf->image $imgobj, $x,$y

B<Please Note:> The width/height or scale given
is in user-space coordinates which is subject to
transformations which may have been specified beforehand.

Per default this has a 72dpi resolution, so if you want an
image to have a 150 or 300dpi resolution, you should specify
a scale of 72/150 (or 72/300) or adjust width/height accordingly.

=cut

sub image {
	my $self=shift @_;
	$self->{hybrid}->image(@_);
	return($self);
}

=item $pdf->textstart

=cut

sub textstart {
	my $self=shift @_;
	$self->{hybrid}->textstart;
	return($self);
}

=item $pdf->textfont $fontobj,$size

=cut

sub textfont {
	my $self=shift @_;
	$self->{hybrid}->font(@_);
	return($self);
}

=item $txt->textlead $leading

=cut

sub textlead {
	my $self=shift @_;
	$self->{hybrid}->lead(@_);
	return($self);
}

=item $pdf->text $string

Applys the given text.

=cut

sub text {
	my $self=shift @_;
	return $self->{hybrid}->text(@_)||$self;
}

=item $pdf->nl

=cut

sub nl {
	my $self=shift @_;
	$self->{hybrid}->nl;
	return($self);
}

=item $pdf->textend

=cut

sub textend {
	my $self=shift @_;
	$self->{hybrid}->textend;
	return($self);
}

=item $pdf->print $font, $size, $x, $y, $rot, $just, $text

Convenience wrapper for shortening the textstart..textend sequence.

=cut

sub print {
	my $self=shift @_;
	my ($font, $size, $x, $y, $rot, $just, @text)=@_;
	my $text=join(' ',@text);
	$self->textstart;
	$self->textfont($font, $size);
	$self->transform(
		-translate=>[$x, $y],
		-rotate=> $rot,
	);
	if($just==1) {
		$self->{hybrid}->text_center($text);
	} elsif($just==2) {
		$self->{hybrid}->text_right($text);
	} else {
		$self->text(@text);
	}
	$self->textend;
	return($self);
}

=head1 AUTHOR

alfred reibenschuh

=cut


1;

__END__