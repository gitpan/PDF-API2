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
use Text::PDF::Utils;

=head2 PDF::API2::Image

=item $img = PDF::API2::Image->new $pdf, $imgfile

Returns a new image object (called from $pdf->image).

=cut

sub new {
	my ($class,$pdf,$file,$tt)=@_;
	my ($obj,$buf);
	if(ref $file) {
		if(UNIVERSAL::isa($file,'GD::Image')) {
			eval ' use Text::PDF::ImageGD; ';
			die "unable to load Text::PDF::ImageGD (did you install correctly?) " if($@);
			$obj=Text::PDF::ImageGD->new($pdf,'IMGxGDx'.pdfkey($file),$file);
			$obj->{' apiname'}='IMGxGDx'.pdfkey($file);
	#	} elsif(UNIVERSAL::isa($file,'Image::Base')) {
	#		$obj=Text::PDF::ImageIMAGE->new($pdf,'IMGxIMAGEx'.pdfkey($file),$file);
	#		$obj->{' apiname'}='IMGxIMAGEx'.pdfkey($file);
		} else {
			die "Unknown Object '$file'";
		}
	} else {
		open(INF,$file);
		binmode(INF);
		read(INF,$buf,10,0);
		close(INF);
		if ($buf=~/^\xFF\xD8/) {
			eval ' use Text::PDF::ImageJPEG; ';
			die "unable to load Text::PDF::ImageJPEG (did you install correctly?) " if($@);
			$obj=Text::PDF::ImageJPEG->new($pdf,'IMGxJPEGx'.pdfkey($file),$file);
			$obj->{' apiname'}='IMGxJPEGx'.pdfkey($file);
		} elsif ($buf=~/^\x89PNG/) {
			eval ' use Text::PDF::ImagePNG; ';
			die "unable to load Text::PDF::ImagePNG (did you install correctly?) " if($@);
			$obj=Text::PDF::ImagePNG->new($pdf,'IMGxPNGx'.pdfkey($file),$file);
			$obj->{' apiname'}='IMGxPNGx'.pdfkey($file);
		} elsif ($buf=~/^P[456][\s\n]/) {
			eval ' use Text::PDF::ImagePPM; ';
			die "unable to load Text::PDF::ImagePPM (did you install correctly?) " if($@);
			$obj=Text::PDF::ImagePPM->new($pdf,'IMGxPPMx'.pdfkey($file),$file);
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