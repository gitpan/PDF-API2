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
#	PDF::API2::Image
#
#=======================================================================
package PDF::API2::Image;
use strict;
use PDF::API2::Util;
use PDF::API2::PDF::Utils;
use vars qw( $VERSION );
( $VERSION ) = '$Revisioning: 0.3a29 $' =~ /\$Revisioning:\s+([^\s]+)/;

use PDF::API2::PDF::ImageGD;
use PDF::API2::PDF::ImageJPEG;
use PDF::API2::PDF::ImagePPM;

=head2 PDF::API2::Image

=item $img = PDF::API2::Image->new $pdf, $imgfile

Returns a new image object (called from $pdf->image).

=cut

sub new {
	my ($class,$pdf,$file,$tt,%opts)=@_;
	my ($obj,$buf);
	if(ref $file) {
		if(UNIVERSAL::isa($file,'GD::Image')) {
			$obj=PDF::API2::PDF::ImageGD->new($pdf,'IMGxGDx'.pdfkey($file),$file);
			$obj->{' apiname'}='IMGxGDx'.pdfkey($file);
	#	} elsif(UNIVERSAL::isa($file,'Image::Base')) {
	#		$obj=PDF::API2::PDF::ImageIMAGE->new($pdf,'IMGxIMAGEx'.pdfkey($file),$file);
	#		$obj->{' apiname'}='IMGxIMAGEx'.pdfkey($file);
		} elsif( (ref($file) eq 'PDF::API2::IOString') && $opts{-jpeg} ) {
			$obj=PDF::API2::PDF::ImageJPEG->new_fh($pdf,'IMGxJPEGx'.pdfkey($tt),$file);
			$obj->{' apiname'}='IMGxJPEGx'.pdfkey($tt);
		} elsif((ref($file) eq 'SCALAR') && $opts{-jpeg}) {
			$obj=PDF::API2::PDF::ImageJPEG->new_stream($pdf,'IMGxJPEGx'.pdfkey($tt),$file);
			$obj->{' apiname'}='IMGxJPEGx'.pdfkey($tt);
		} else {
			die "Unknown Object '$file'";
		}
	} else {
		open(INF,$file);
		binmode(INF);
		read(INF,$buf,10,0);
		close(INF);
		if ($buf=~/^\xFF\xD8/) {
			$obj=PDF::API2::PDF::ImageJPEG->new($pdf,'IMGxJPEGx'.pdfkey($file),$file);
			$obj->{' apiname'}='IMGxJPEGx'.pdfkey($file);
		} elsif ($buf=~/^\x89PNG/) {
			eval ' use PDF::API2::PDF::ImagePNG; ';
			die "unable to load PDF::API2::PDF::ImagePNG (did you install correctly?) " if($@);
			$obj=PDF::API2::PDF::ImagePNG->new($pdf,'IMGxPNGx'.pdfkey($file),$file);
			$obj->{' apiname'}='IMGxPNGx'.pdfkey($file);
		} elsif ($buf=~/^P[456][\s\n]/) {
			$obj=PDF::API2::PDF::ImagePPM->new($pdf,'IMGxPPMx'.pdfkey($file),$file);
			$obj->{' apiname'}='IMGxPPMx'.pdfkey($file);
		} else {
			die sprintf("image '$file' has unknown format with signature '%02x%02x%02x%02x%02x%02x'",
				ord(substr($buf,0,1)),
				ord(substr($buf,1,1)),
				ord(substr($buf,2,1)),
				ord(substr($buf,3,1)),
				ord(substr($buf,4,1)),
				ord(substr($buf,5,1))
			);
		}
	}
	return($obj);
}

sub newMask {
	my ($class,$pdf,$img,$file,$tt)=@_;
	my ($obj,$buf);
	open(INF,$file);
	binmode(INF);
	read(INF,$buf,10,0);
	close(INF);
	if ($buf=~/^\xFF\xD8/) {
		$obj=PDF::API2::JPEG->newMask($img,$file,$tt);
	} elsif ($buf=~/^\x89PNG/) {
		$obj=PDF::API2::PNG->newMask($img,$file,$tt);
	} elsif ($buf=~/^P[456][\s\n]/) {
		$obj=PDF::API2::PPM->newMask($img,$file,$tt);
	} else {
		die sprintf("image '$file' has unknown format with signature '%02x%02x%02x%02x%02x%02x'",
			ord(substr($buf,0,1)),
			ord(substr($buf,1,1)),
			ord(substr($buf,2,1)),
			ord(substr($buf,3,1)),
			ord(substr($buf,4,1)),
			ord(substr($buf,5,1))
		);
	}
	$pdf->new_obj($obj);
	$obj->{' apipdf'}.=$pdf;
	return($obj);
}

=item $wd = $img->width

=cut

sub width {
	my $self = shift @_;
	return($self->{' width'});
}

=item $ht = $img->height

=cut

sub height {
	my $self = shift @_;
	return($self->{' height'});
}

1;

__END__

=head1 AUTHOR

alfred reibenschuh

=cut