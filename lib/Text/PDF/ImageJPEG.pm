#==================================================================
#	Text::PDF::ImageJPEG
#==================================================================
package Text::PDF::ImageJPEG;

use strict;
use Text::PDF::Dict;
use Text::PDF::Utils;
use Text::PDF::Image;
use vars qw(@ISA);

@ISA = qw(Text::PDF::Image);

=head2 Text::PDF::ImageJPEG

=item $img = Text::PDF::ImageJPEG->new $pdf,$name, $filename

Returns a new image object.

=cut

sub new {
	my ($class,$pdf,$name,$file)=@_;
	my $self = $class->SUPER::new($pdf,$name);
	$self->readjpeg($pdf,$file);
	return($self);
}

sub readjpeg {
	my $self = shift @_;
	my $pdf = shift @_;
	my $file = shift @_;

	my ($buf, $p, $h, $w, $c, $ff, $mark, $len);

	open(JF,$file);
	binmode(JF);
	read(JF,$buf,2);
	while (1) {
		read(JF,$buf,4);
		my($ff, $mark, $len) = unpack("CCn", $buf);
		last if( $ff != 0xFF);
		last if( $mark == 0xDA || $mark == 0xD9);  # SOS/EOI
		last if( $len < 2);
		last if( eof(JF));
		read(JF,$buf,$len-2);
		next if ($mark == 0xFE);
		next if ($mark >= 0xE0 && $mark <= 0xEF);
		if (($mark >= 0xC0) && ($mark <= 0xCF)) {
			($p, $h, $w, $c) = unpack("CnnC", substr($buf, 0, 6));
			last;
		}
	}
	close(JF);

	$self->width($w);
	$self->height($h);

	$self->bpc($p);

	$self->filters('DCTDecode');
	$self->{' nofilt'}=1;

	if($c==3) {
	        $self->colorspace('DeviceRGB');
	} elsif($c==4) {
	        $self->colorspace('DeviceCMYK');
	} elsif($c==1) {
	        $self->colorspace('DeviceGray');
	}

	$self->{' streamfile'}=$file;
	$self->{Length}=PDFNum(-s $file);

	return($self);
}

1;