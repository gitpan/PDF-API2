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
#	PDF::API2::ColorSpace
#
#=======================================================================
package PDF::API2::ColorSpace;

use strict;
use vars qw(@ISA $VERSION);
@ISA = qw(PDF::API2::PDF::Array);
( $VERSION ) = '$Revisioning: 0.3a25 $' =~ /\$Revisioning:\s+([^\s]+)/;


use PDF::API2::PDF::Utils;
use PDF::API2::Util;
use Math::Trig;

=back

=head2 PDF::API2::ColorSpace

Subclassed from PDF::API2::PDF::Array.

=item $cs = PDF::API2::ColorSpace->new $pdf, $key, %parameters

Returns a new colorspace object (called from $pdf->colorspace).

=cut

sub new {
	my ($class,$pdf,$key,%opts)=@_;
	my $self = $class->SUPER::new();
	$self->{' apiname'}=$key;

	if($opts{-type} eq 'CalRGB') {

		my $csd=PDFDict();
		$opts{-whitepoint}=$opts{-whitepoint} || [ 0.95049, 1, 1.08897 ];
		$opts{-blackpoint}=$opts{-blackpoint} || [ 0, 0, 0 ];
		$opts{-gamma}=$opts{-gamma} || [ 2.22218, 2.22218, 2.22218 ];
		$opts{-matrix}=$opts{-matrix} || [
			0.41238, 0.21259, 0.01929,
			0.35757, 0.71519, 0.11919,
			0.1805,  0.07217, 0.95049
		];

		$csd->{WhitePoint}=PDFArray(map {PDFNum($_)} @{$opts{-whitepoint}});
		$csd->{BlackPoint}=PDFArray(map {PDFNum($_)} @{$opts{-blackpoint}});
		$csd->{Gamma}=PDFArray(map {PDFNum($_)} @{$opts{-gamma}});
		$csd->{Matrix}=PDFArray(map {PDFNum($_)} @{$opts{-matrix}});

		$self->add_elements(PDFName($opts{-type}),$csd);

		$self->{' type'}='rgb';

	} elsif($opts{-type} eq 'CalGray') {

		my $csd=PDFDict();
		$opts{-whitepoint}=$opts{-whitepoint} || [ 0.95049, 1, 1.08897 ];
		$opts{-blackpoint}=$opts{-blackpoint} || [ 0, 0, 0 ];
		$opts{-gamma}=$opts{-gamma} || 2.22218;
		$csd->{WhitePoint}=PDFArray(map {PDFNum($_)} @{$opts{-whitepoint}});
		$csd->{BlackPoint}=PDFArray(map {PDFNum($_)} @{$opts{-blackpoint}});
		$csd->{Gamma}=PDFNum($opts{-gamma});

		$self->add_elements(PDFName($opts{-type}),$csd);

		$self->{' type'}='gray';

	} elsif($opts{-type} eq 'Lab') {

		my $csd=PDFDict();
		$opts{-whitepoint}=$opts{-whitepoint} || [ 0.95049, 1, 1.08897 ];
		$opts{-blackpoint}=$opts{-blackpoint} || [ 0, 0, 0 ];
		$opts{-range}=$opts{-range} || [ -200, 200, -200, 200 ];
		$opts{-gamma}=$opts{-gamma} || [ 2.22218, 2.22218, 2.22218 ];

		$csd->{WhitePoint}=PDFArray(map {PDFNum($_)} @{$opts{-whitepoint}});
		$csd->{BlackPoint}=PDFArray(map {PDFNum($_)} @{$opts{-blackpoint}});
		$csd->{Gamma}=PDFArray(map {PDFNum($_)} @{$opts{-gamma}});
		$csd->{Range}=PDFArray(map {PDFNum($_)} @{$opts{-range}});

		$self->add_elements(PDFName($opts{-type}),$csd);

		$self->{' type'}='lab';

	} elsif($opts{-type} eq 'Indexed') {

		my $csd=PDFDict();
		$opts{-base}=$opts{-base} || 'DeviceRGB';
		$opts{-maxindex}=$opts{-maxindex} || scalar(@{$opts{-colors}})-1;
		$opts{-whitepoint}=$opts{-whitepoint} || [ 0.95049, 1, 1.08897 ];
		$opts{-blackpoint}=$opts{-blackpoint} || [ 0, 0, 0 ];
		$opts{-gamma}=$opts{-gamma} || [ 2.22218, 2.22218, 2.22218 ];

		$csd->{WhitePoint}=PDFArray(map {PDFNum($_)} @{$opts{-whitepoint}});
		$csd->{BlackPoint}=PDFArray(map {PDFNum($_)} @{$opts{-blackpoint}});
		$csd->{Gamma}=PDFArray(map {PDFNum($_)} @{$opts{-gamma}});

		foreach my $col (@{$opts{-colors}}) {
			map { $csd->{' stream'}.=pack('C',$_); } @{$col};
		}
		$pdf->new_obj($csd);
		$csd->{Filter}=PDFArray(PDFName('FlateDecode'));
		$self->add_elements(PDFName($opts{-type}),PDFName($opts{-base}),PDFNum($opts{-maxindex}),$csd);

		$self->{' type'}='index';

	} elsif($opts{-type} eq 'ICCBased') {

		my $csd=PDFDict();

		$csd->{Filter}=PDFArray(PDFName('FlateDecode'));
		$csd->{Alternate}=PDFName($opts{-base}) if(defined $opts{-base});
		$csd->{N}=PDFNum($opts{-components});
		$csd->{' streamfile'}=$opts{-iccfile};
		$pdf->new_obj($csd);
		$self->add_elements(PDFName($opts{-type}),$csd);

		$self->{' type'} =
			$opts{-base}=~/RGB/i ? 'rgb' :
			$opts{-base}=~/CMYK/i ? 'cmyk' :
			$opts{-base}=~/Lab/i ? 'lab' :
			$opts{-base}=~/Gr[ae]y/i ? 'gray' :
			$opts{-base}=~/Index/i ? 'index' : 'other'
		;

	}

	return($self);
}

sub isRGB { $_[0]->{' type'}=~/rgb/ ? 1 : 0 ; }
sub isCMYK { $_[0]->{' type'}=~/cmyk/ ? 1 : 0 ; }
sub isLab { $_[0]->{' type'}=~/lab/ ? 1 : 0 ; }
sub isGray { $_[0]->{' type'}=~/gray/ ? 1 : 0 ; }
sub isIndexed { $_[0]->{' type'}=~/index/ ? 1 : 0 ; }

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
