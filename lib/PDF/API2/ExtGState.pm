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
#	PDF::API2::ExtGState
#
#=======================================================================
package PDF::API2::ExtGState;

use strict;
use vars qw(@ISA $VERSION);
@ISA = qw(PDF::API2::PDF::Dict);
( $VERSION ) = '$Revisioning: 0.3a25 $' =~ /\$Revisioning:\s+([^\s]+)/;


use PDF::API2::PDF::Dict;
use PDF::API2::PDF::Utils;
use Math::Trig;
use PDF::API2::Util;

=head2 PDF::API2::ExtGState

Subclassed from PDF::API2::PDF::Dict.

=item $egs = PDF::API2::ExtGState->new @parameters

Returns a new extgstate object (called from $pdf->extgstate).

=cut

sub new {
	my ($class,$pdf,$key)=@_;
	my $self = $class->SUPER::new;
	$self->{' apiname'}=$key;
	$self->{Type}=PDFName('ExtGState');
	return($self);
}

=item $egs->strokeadjust $boolean

=cut

sub strokeadjust {
	my ($self,$var)=@_;
	$self->{SA}=PDFBool($var);
	return($self);
}

=item $egs->strokeoverprint $boolean

=cut

sub strokeoverprint {
	my ($self,$var)=@_;
	$self->{OP}=PDFBool($var);
	return($self);
}

=item $egs->filloverprint $boolean

=cut

sub filloverprint {
	my ($self,$var)=@_;
	$self->{op}=PDFBool($var);
	return($self);
}

=item $egs->overprintmode $num

=cut

sub overprintmode {
	my ($self,$var)=@_;
	$self->{OPM}=PDFNum($var);
	return($self);
}

=item $egs->blackgeneration $obj

=cut

sub blackgeneration {
	my ($self,$obj)=@_;
	$self->{BG}=$obj;
	return($self);
}

=item $egs->blackgeneration2 $obj

=cut

sub blackgeneration2 {
	my ($self,$obj)=@_;
	$self->{BG2}=$obj;
	return($self);
}

=item $egs->undercolorremoval $obj

=cut

sub undercolorremoval {
	my ($self,$obj)=@_;
	$self->{UCR}=$obj;
	return($self);
}

=item $egs->undercolorremoval2 $obj

=cut

sub undercolorremoval2 {
	my ($self,$obj)=@_;
	$self->{UCR2}=$obj;
	return($self);
}

=item $egs->transfer $obj

=cut

sub transfer {
	my ($self,$obj)=@_;
	$self->{TR}=$obj;
	return($self);
}

=item $egs->transfer2 $obj

=cut

sub transfer2 {
	my ($self,$obj)=@_;
	$self->{TR2}=$obj;
	return($self);
}

=item $egs->halftone $obj

=cut

sub halftone {
	my ($self,$obj)=@_;
	$self->{HT}=$obj;
	return($self);
}

sub halftonephase {
	my ($self,$obj)=@_;
	$self->{HTP}=$obj;
	return($self);
}

sub smoothness {
	my ($self,$var)=@_;
	$self->{SM}=PDFNum($var);
	return($self);
}

sub font {
	my ($self,$font,$size)=@_;
	$self->{Font}=PDFArray(PDFName($font->{' apiname'}),PDFNum($size));
	return($self);
}

sub linewidth {
	my ($self,$var)=@_;
	$self->{LW}=PDFNum($var);
	return($self);
}

sub linecap {
	my ($self,$var)=@_;
	$self->{LC}=PDFNum($var);
	return($self);
}

sub linejoin {
	my ($self,$var)=@_;
	$self->{LJ}=PDFNum($var);
	return($self);
}

sub meterlimit {
	my ($self,$var)=@_;
	$self->{ML}=PDFNum($var);
	return($self);
}

sub dash {
	my ($self,@dash)=@_;
	$self->{ML}=PDFArray( map { PDFNum($_); } @dash );
	return($self);
}

sub flatness {
	my ($self,$var)=@_;
	$self->{FL}=PDFNum($var);
	return($self);
}

sub renderingintent {
	my ($self,$var)=@_;
	$self->{FL}=PDFName($var);
	return($self);
}

sub outobjdeep {
	my ($self, @opts) = @_;
	foreach my $k (qw/ api apipdf /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	$self->SUPER::outobjdeep(@opts);
}

1;

__END__

=head1 AUTHOR

alfred reibenschuh

=cut
