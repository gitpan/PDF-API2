#==================================================================
#	Text::PDF::ImageGD
#==================================================================
package Text::PDF::ImageGD;

use strict;
use Text::PDF::Dict;
use Text::PDF::Utils;
use Text::PDF::Image;
use vars qw(@ISA);

@ISA = qw(Text::PDF::Image);

=head2 Text::PDF::ImageGD

=item $img = Text::PDF::ImageGD->new $pdf,$name, $gdobj

Returns a new image object from a gd object.

=cut

sub new {
	my ($class,$pdf,$name,$gd)=@_;
	my $self = $class->SUPER::new($pdf,$name);
	my ($w,$h)=$gd->getBounds();

	$self->width($w);
	$self->height($h);
	$self->bpc(8);
        $self->colorspace('DeviceRGB');

	if(UNIVERSAL::can($gd,'jpeg')) {
		$self->filters('DCTDecode');
		$self->{' nofilt'}=1;
		$self->{' stream'}=$gd->jpeg(100);
	} else {
		$self->filters('FlateDecode');
		my($x,$y);
		for($y=0;$y<$h;$y++) {
			for($x=0;$x<$w;$x++) {
				my $index=$gd->getPixel($x,$y);
				my @rgb=$gd->rgb($index);
				$self->{' stream'}.=pack('CCC',@rgb);
			}
		}
	}

	return($self);
}

1;