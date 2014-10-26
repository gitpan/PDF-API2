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
#	PDF::API2::TrueTypeFont
#
#=======================================================================
package PDF::API2::TrueTypeFont;

use PDF::API2::UniMap qw( utf8_to_ucs2 );
use PDF::API2::Util;
use PDF::API2::PDF::Utils;
use PDF::API2::PDF::Dict;
use POSIX;
use vars qw(@ISA $VERSION);
@ISA = qw( PDF::API2::PDF::Dict );
( $VERSION ) = '$Revisioning: 0.3b49 $' =~ /\$Revisioning:\s+([^\s]+)/;

=item $font = PDF::API2::TrueTypeFont->new $pdf, $file, %options

Returns a font object.

Defined Options:

	-nonembed ... prohibits embedding of the font (you cant use utf8 with that).

	-encode ... specify fonts encoding for non-utf8 text.

=cut

sub new {
	my ($class,$pdf,$file,@opts) = @_;
	my $self;
	my $t0;
	my %opts=();
	die "cannot find font '$file' ..." unless(-f $file);
	%opts=@opts if((scalar @opts)%2 == 0);
	$class = ref $class if ref $class;
	$self=$class->SUPER::new();

	my $des=PDF::API2::TrueTypeFont::FontDescriptor->new($pdf,$file,@opts);

	#================================================
	# creating the type0 pseudo object
	#================================================

	unless($opts{-nonembed}) {
		$t0 = PDF::API2::TrueTypeFont0->new($pdf,$des,@opts);
		if($des->issymbol) {
			return($t0);
		}
	} else {
		$t0=$self;
	}

	#================================================
	# creating the default encoded object
	#	(either latin1 or symbol)
	#================================================
	$pdf->new_obj($self);
	$self->{'Type'} = PDFName('Font');
	$self->{'Subtype'} = PDFName($des->iscff ? 'Type1' : 'TrueType');
	$self->{'BaseFont'} = PDFName($des->fontname);
	$self->{' apiname'} = 'TTx'.pdfkey($des->fontname,%opts);
	$self->{'Name'} = PDFName($self->{' apiname'});
	$self->{'FirstChar'} = PDFNum(1);
	$self->{'LastChar'} = PDFNum(255);
	$self->{'FontDescriptor'} = $des;

	my @w=();

	$self->{'PdfApi2Encoding'}=PDFStr($opts{-encode}) if($opts{-encode});
	$self->{'Encoding'}=PDFDict();
	$self->{'Encoding'}->{'Type'}=PDFName('Encoding');
	$self->{'Encoding'}->{'BaseEncoding'}=PDFName('WinAnsiEncoding');
	my $notdefbefore=1;
	foreach my $w (1..255) {
		if(!defined($des->charset->[$w]) ||($des->charset->[$w] eq '.notdef')) {
			$notdefbefore=1;
			next;
		} else {
			if($notdefbefore) {
				push(@w,PDFNum($w))
			}
			$notdefbefore=0;
			push(@w,PDFName($des->charset->[$w]));
		}
	}
	$self->{'Encoding'}->{'Differences'}=PDFArray(@w);
	@w = map { PDFNum($des->wxe($_)||300) } (1..255);
	$self->{'Widths'}=PDFArray(@w);
	$self->{' t0'}=$t0;

	return($self);
}

=item $font = PDF::API2::TrueTypeFont->new_api $api, $file, %options

Returns a corefont object. This method is different from 'new' that
it needs an PDF::API2-object rather than a Text::PDF::File-object.

=cut

sub new_api {
	my ($class,$api,@opts)=@_;

	my $obj=$class->new($api->{pdf},@opts);
	my $key=$obj->{' apiname'};

	$api->resource('Font',$key,$obj);
	$api->resource('Font',$obj->{' apiname'},$obj);

	$api->{pdf}->out_obj($api->{pages});
	return($obj);
}

sub fontdesc { return( $_[0]->{FontDescriptor} ); }

=item $pdfstring = $font->text $text

Returns a properly formated string-representation of $text
for use in the PDF.

=cut

sub text {
	my ($self,$text)=@_;
	my $newtext='';
	foreach my $g (0..length($text)-1) {
		$newtext.=
			(substr($text,$g,1)=~/[\x00-\x1f\\\{\}\[\]\(\)]/)
			? sprintf('\%03lo',vec($text,$g,8))
			: substr($text,$g,1) ;
		$self->fontdesc->subsete(vec($text,$g,8));
	}
	return("($newtext)");
}

=item $pdfstring = $font->text_ucs2 $text

Returns a properly formated string-representation of $text
for use in the PDF but requires $text to be in UCS2.

=cut

sub text_ucs2 {
	my ($self,$text)=@_;
	return($self->text( pack('C*',unpack('n*',$text)) ));
}

=item $pdfstring = $font->text_utf8 $text

Returns a properly formated string-representation of $text
for use in the PDF but requires $text to be in UTF8.

=cut

sub text_utf8 {
	my ($self,$text)=@_;
	return($self->text( pack('C*',unpack('U*',$text)) ));
}

=item $wd = $font->width $text

Returns the width of $text as if it were at size 1.

=cut

sub width {
	my ($self,$text,%opts)=@_;
	my $width=$self->wx($text,%opts);
	$width/=1000;
	return($width);
}

=item $wd = $font->width_ucs2 $text

Returns the width of $text as if it were at size 1,
but requires $text to be in UCS2.

=cut

sub width_ucs2 {
	my ($self,$text,%opts)=@_;
	my $width=$self->wx($text,-ucs2=>1,%opts);
	$width/=1000;
	return($width);
}

=item $wd = $font->width_utf8 $text

Returns the width of $text as if it were at size 1,
but requires $text to be in UTF8.

=cut

sub width_utf8 {
	my ($self,$text,%opts)=@_;
	my $width=$self->wx($text,-utf8=>1,%opts);
	$width/=1000;
	return($width);
}

=item @widths = $font->width_array $text

Returns the widths of the words in $text as if they were at size 1.

=cut

sub width_array {
	my ($self,$text,%opts)=@_;
	if($opts{-ucs2}) {
		my @text=split(/\0x00\0x20/,$text);
		my @widths=map {$self->width_ucs2($_,%opts)} @text;
		return(@widths);
	} elsif($opts{-utf8}) {
		my @text=split(/\s+/,$text);
		my @widths=map {$self->width_utf8($_,%opts)} @text;
		return(@widths);
	} else {
		my @text=split(/\s+/,$text);
		my @widths=map {$self->width($_,%opts)} @text;
		return(@widths);
	}
}

#=item ($llx,$lly,$urx,$ury) = $font->bbox $text
#
#Returns the texts bounding-box as if it were at size 1.
#
#=cut
#
#sub bbox {
#	my ($self,$text,%opts)=@_;
#	return(map {$_/1000} $self->bbx($text,%opts));
#}
#
#=item ($llx,$lly,$urx,$ury) = $font->bbox_ucs2 $text
#
#Returns the texts bounding-box as if it were at size 1.
#
#=cut
#
#sub bbox_ucs2 {
#	my ($self,$text,%opts)=@_;
#	return(map {$_/1000} $self->bbx($text,-ucs2=>1));
#}
#
#=item ($llx,$lly,$urx,$ury) = $font->bbox_utf8 $text
#
#Returns the texts bounding-box as if it were at size 1.
#
#=cut
#
#sub bbox_utf8 {
#	my ($self,$text,%opts)=@_;
#	return(map {$_/1000} $self->bbx($text,-utf8=>1));
#}


sub name { return (shift @_)->{' apiname'}; }

sub fontbbox { return( (shift @_)->fontdesc->fontbbox ); }
sub capheight { return( (shift @_)->fontdesc->capheight ); }
sub xheight { return( (shift @_)->fontdesc->xheight ); }
sub underlineposition { return( (shift @_)->fontdesc->underlineposition ); }
sub underlinethickness { return( (shift @_)->fontdesc->underlinethickness ); }
sub ascender { return( (shift @_)->fontdesc->ascender ); }
sub descender { return( (shift @_)->fontdesc->descender ); }

sub issymbol { return( (shift @_)->fontdesc->issymbol ); }
sub unicode { return( (shift @_)->{' t0'} ); }

sub data { return( (shift @_)->fontdesc->data ); }

sub wxe { return( (shift @_)->fontdesc->wxe(@_) ); }
sub wxu { return( (shift @_)->fontdesc->wxu(@_) ); }
sub wxn { return( (shift @_)->fontdesc->wxn(@_) ); }
sub wxg { return( (shift @_)->fontdesc->wxg(@_) ); }
sub wx { return( (shift @_)->fontdesc->wx(@_) ); }

#sub bbxg { return( (shift @_)->fontdesc->bbxg(@_) ); }
#sub bbxu { return( (shift @_)->fontdesc->bbxu(@_) ); }
#sub bbxe { return( (shift @_)->fontdesc->bbxe(@_) ); }
#sub bbxn { return( (shift @_)->fontdesc->bbxn(@_) ); }
#sub bbx { return( (shift @_)->fontdesc->bbx(@_) ); }


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
#	PDF::API2::TrueTypeFont0
#
#=======================================================================
package PDF::API2::TrueTypeFont0;

use PDF::API2::Util;
use PDF::API2::PDF::Utils;
use PDF::API2::PDF::Dict;
use PDF::API2::UniMap qw( utf8_to_ucs2 );
use POSIX;

use vars qw(@ISA);
@ISA = qw( PDF::API2::PDF::Dict );

=item $font = PDF::API2::TrueTypeFont0->new $pdf, $des

Returns a font object.

=cut

sub new {
	my ($class,$pdf,$des,@opts) = @_;
	my %opts=();
	%opts=@opts if((scalar @opts)%2 == 0);
	$class = ref $class if ref $class;

#================================================
# creating the type0 pseudo object
#================================================
	my $self = $class->SUPER::new();
	$pdf->new_obj($self);
	$self->{'Type'} = PDFName("Font");
	$self->{'Subtype'} = PDFName('Type0');
	$self->{'BaseFont'} = PDFName($des->fontname.'+CID');
	$self->{' apiname'} = 'T0x'.pdfkey($des->fontname,%opts);
	$self->{'Name'} = PDFName($self->{' apiname'});
	$self->{'Encoding'} = PDFName('Identity-H');
	$self->{'SpecifiedEncoding'}=PDFStr($opts{-encode}) if($opts{-encode});
	my $de=PDFDict();
	$pdf->new_obj($de);
	$self->{'DescendantFonts'} = PDFArray($de);
	$self->{' de'} = $de;

#================================================
# creating the cid encoded object
#================================================
	$de->{'Type'} = PDFName('Font');
	$de->{'FontDescriptor'} = $des;
	$de->{'Subtype'} = PDFName($self->iscff ? 'CIDFontType0' : 'CIDFontType2');
	$de->{'BaseFont'} = PDFName($des->fontname.'+CID');
	$de->{'CIDSystemInfo'} = PDFDict();
	$de->{'CIDSystemInfo'}->{Registry} = PDFStr('Adobe');
	$de->{'CIDSystemInfo'}->{Ordering} = PDFStr('Identity');
	$de->{'CIDSystemInfo'}->{Supplement} = PDFNum(0);
	$de->{'DW'} = PDFNum($des->missingwidth);
	$de->{'CIDToGIDMap'} = PDFName('Identity');

	return($self);
}

=item $pdfstring = $font->text $text

Returns a properly formated string-representation of $text
for use in the PDF.

=cut

sub text {
	my ($self,$text,%opt)=@_;
	return($self->text_utf8($text)) if($opt{-utf8});
	return($self->text_ucs2($text)) if($opt{-ucs2});
	return($self->text_utf8(pack('U*',unpack('C*',$text))));
}

=item $pdfstring = $font->text_ucs2 $text

Returns a properly formated string-representation of $text
for use in the PDF but requires $text to be in UCS2.

=cut

sub text_ucs2 {
	my ($self,$text)=@_;
	my ($newtext);
	foreach my $x (0..(length($text)>>1)-1) {
		my $g=$self->fontdesc->uni2glyph( vec($text,$x,16) );
		$newtext.= sprintf('%04x',$g);
		$self->fontdesc->subsetg($g);
	}
	return("<$newtext>");
}

=item $pdfstring = $font->text_utf8 $text

Returns a properly formated string-representation of $text
for use in the PDF but requires $text to be in UTF8.

=cut

sub text_utf8 {
	my ($self,$text)=@_;
	$text=utf8_to_ucs2($text);
	return $self->text_ucs2($text);
}

=item $wd = $font->width $text

Returns the width of $text as if it were at size 1.

=cut

sub width {
	my ($self,$text,%opts)=@_;
	my $width=$self->wx($text,%opts);
	$width/=1000;
	return($width);
}

=item $wd = $font->width_ucs2 $text

Returns the width of $text as if it were at size 1,
but requires $text to be in UCS2.

=cut

sub width_ucs2 {
	my ($self,$text,%opts)=@_;
	my $width=$self->wx($text,-ucs2=>1,%opts);
	$width/=1000;
	return($width);
}

=item $wd = $font->width_utf8 $text

Returns the width of $text as if it were at size 1,
but requires $text to be in UTF8.

=cut

sub width_utf8 {
	my ($self,$text,%opts)=@_;
	my $width=$self->wx($text,-utf8=>1,%opts);
	$width/=1000;
	return($width);
}

=item @widths = $font->width_array $text

Returns the widths of the words in $text as if they were at size 1.

=cut

sub width_array {
	my ($self,$text,%opts)=@_;
	if($opts{-ucs2}) {
		my @text=split(/\0x00\0x20/,$text);
		my @widths=map {$self->width($_,%opts)} @text;
		return(@widths);
	} else {
		my @text=split(/\s+/,$text);
		my @widths=map {$self->width($_,%opts)} @text;
		return(@widths);
	}
}

#=item ($llx,$lly,$urx,$ury) = $font->bbox $text
#
#Returns the texts bounding-box as if it were at size 1.
#
#=cut
#
#sub bbox {
#	my ($self,$text,%opts)=@_;
#	return(map {$_/1000} $self->bbx($text,%opts));
#}
#
#=item ($llx,$lly,$urx,$ury) = $font->bbox_ucs2 $text
#
#Returns the texts bounding-box as if it were at size 1.
#
#=cut
#
#sub bbox_ucs2 {
#	my ($self,$text)=@_;
#	return(map {$_/1000} $self->bbx($text,-ucs2=>1));
#}
#
#=item ($llx,$lly,$urx,$ury) = $font->bbox_utf8 $text
#
#Returns the texts bounding-box as if it were at size 1.
#
#=cut
#
#sub bbox_utf8 {
#	my ($self,$text)=@_;
#	return(map {$_/1000} $self->bbx($text,-utf8=>1));
#}


sub outobjdeep {
	my ($self, $fh, $pdf, %opts) = @_;

	return $self->SUPER::outobjdeep($fh, $pdf) if defined $opts{'passthru'};

	my $notdefbefore=1;
	
	my $wx=PDFArray();
	$self->{' de'}->{'W'} = $wx;
	my $ml;
	
	my @w=();
	foreach my $w (1..$self->fontdesc->glyphs) {
		if($self->fontdesc->subvec($w) && $notdefbefore==1) {
			$notdefbefore=0;
			$ml=PDFArray();
			$wx->add_elements(PDFNum($w),$ml);
			$ml->add_elements(PDFNum($self->fontdesc->wxg($w)));
		} elsif($self->fontdesc->subvec($w) && $notdefbefore==0) {
			$notdefbefore=0;
			$ml->add_elements(PDFNum($self->fontdesc->wxg($w)));
		} else {
			$notdefbefore=1;
		}
	}

	$self->SUPER::outobjdeep($fh, $pdf, %opts);
}

sub fontdesc { return( $_[0]->{' de'}->{FontDescriptor} ); }

sub fontbbox { return( (shift @_)->fontdesc->fontbbox ); }
sub capheight { return( (shift @_)->fontdesc->capheight ); }
sub xheight { return( (shift @_)->fontdesc->xheight ); }
sub underlineposition { return( (shift @_)->fontdesc->underlineposition ); }
sub underlinethickness { return( (shift @_)->fontdesc->underlinethickness ); }
sub ascender { return( (shift @_)->fontdesc->ascender ); }
sub descender { return( (shift @_)->fontdesc->descender ); }

sub iscff { return( (shift @_)->fontdesc->iscff ); }
sub issymbol { return( (shift @_)->fontdesc->issymbol ); }
sub unicode { return(shift @_); }

sub data { return( (shift @_)->fontdesc->data ); }

sub name { return (shift @_)->{' apiname'}; }

sub wxe { return( (shift @_)->fontdesc->wxe(@_) ); }
sub wxu { return( (shift @_)->fontdesc->wxu(@_) ); }
sub wxn { return( (shift @_)->fontdesc->wxn(@_) ); }
sub wxg { return( (shift @_)->fontdesc->wxg(@_) ); }
sub wx { return( (shift @_)->fontdesc->wx(@_) ); }

#sub bbxg { return( (shift @_)->fontdesc->bbxg(@_) ); }
#sub bbxu { return( (shift @_)->fontdesc->bbxu(@_) ); }
#sub bbxe { return( (shift @_)->fontdesc->bbxe(@_) ); }
#sub bbxn { return( (shift @_)->fontdesc->bbxn(@_) ); }
#sub bbx { return( (shift @_)->fontdesc->bbx(@_) ); }


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
#	PDF::API2::TrueTypeFont::FontDescriptor
#
#=======================================================================
package PDF::API2::TrueTypeFont::FontDescriptor;

use PDF::API2::Util;
use PDF::API2::PDF::Utils;
use PDF::API2::PDF::Dict;
use POSIX;

use vars qw(@ISA);
@ISA = qw( PDF::API2::PDF::Dict );

sub new {
	my ($class,$pdf,$file,@opts) = @_;
	my $self;
	my %opts=();
	die "cannot find font '$file' ..." unless(-f $file);
	%opts=@opts if((scalar @opts)%2 == 0);
	$class = ref $class if ref $class;
	$self=$class->SUPER::new();

	$pdf->new_obj($self);

	$self->{' fontfile'}=PDF::API2::TrueTypeFont::FontFile->new($pdf,$file,@opts);
	if($self->iscff) {
		$self->{FontFile3}=$self->{' fontfile'} unless($opts{-nonembed});
	} else {
		$self->{FontFile2}=$self->{' fontfile'} unless($opts{-nonembed});
	}
	$self->{'Type'}=PDFName('FontDescriptor');
	$self->{'FontName'}=PDFName($self->fontfile->fontname);
	$self->{'FontBBox'}=PDFArray(map { PDFNum($_ || 0) } @{$self->fontfile->fontbbox});
	$self->{'Ascent'}=PDFNum($self->fontfile->ascender);
	$self->{'Descent'}=PDFNum($self->fontfile->descender);
	$self->{'ItalicAngle'}=PDFNum($self->fontfile->italicangle);
	$self->{'CapHeight'}=PDFNum($self->fontfile->capheight);
	$self->{'StemV'}=PDFNum($self->fontfile->stemv);
	$self->{'StemH'}=PDFNum($self->fontfile->stemh);
	$self->{'XHeight'}=PDFNum($self->fontfile->xheight);
	$self->{'Flags'}=PDFNum($self->fontfile->flags);
	$self->{'MaxWidth'}=PDFNum($self->fontfile->maxwidth);
	$self->{'MissingWidth'}=PDFNum($self->fontfile->missingwidth);
	$self->{'SpecifiedEncoding'}=PDFStr($opts{-encode}) if($opts{-encode});

	return($self);
}

sub fontfile { return( $_[0]->{' fontfile'} ); }

sub data { return( $_[0]->fontfile->data ); }

sub fontname { return( $_[0]->fontfile->fontname ); }
sub altname { return( (shift @_)->fontfile->altname ); }
sub subname { return( (shift @_)->fontfile->subname ); }

sub charset { return( $_[0]->fontfile->char ); }

sub wxe { return( (shift @_)->fontfile->wxe(@_) ); }
sub wxu { return( (shift @_)->fontfile->wxu(@_) ); }
sub wxn { return( (shift @_)->fontfile->wxn(@_) ); }
sub wxg { return( (shift @_)->fontfile->wxg(@_) ); }
sub wx { return( (shift @_)->fontfile->wx(@_) ); }

#sub bbxg { return( (shift @_)->fontfile->bbxg(@_) ); }
#sub bbxu { return( (shift @_)->fontfile->bbxu(@_) ); }
#sub bbxe { return( (shift @_)->fontfile->bbxe(@_) ); }
#sub bbxn { return( (shift @_)->fontfile->bbxn(@_) ); }
#sub bbx { return( (shift @_)->fontfile->bbx(@_) ); }

sub subsetg { return( (shift @_)->fontfile->subsetg(@_) ); }
sub subsete { return( (shift @_)->fontfile->subsete(@_) ); }
sub subsetu { return( (shift @_)->fontfile->subsetu(@_) ); }
sub subvec { return( (shift @_)->fontfile->subvec(@_) ); }

sub uni2glyph { return( (shift @_)->fontfile->uni2glyph(@_) ); }
sub enc2glyph { return( (shift @_)->fontfile->enc2glyph(@_) ); }
sub glyphs { return( (shift @_)->fontfile->glyphs ); }

sub issymbol { return( (shift @_)->fontfile->issymbol ); }
sub missingwidth { return( (shift @_)->fontfile->missingwidth ); }
sub fontbbox { return( (shift @_)->fontfile->fontbbox ); }
sub capheight { return( (shift @_)->fontfile->capheight ); }
sub xheight { return( (shift @_)->fontfile->xheight ); }
sub underlineposition { return( (shift @_)->fontfile->underlineposition ); }
sub underlinethickness { return( (shift @_)->fontfile->underlinethickness ); }
sub ascender { return( (shift @_)->fontfile->ascender ); }
sub descender { return( (shift @_)->fontfile->descender ); }
sub iscff { return( (shift @_)->fontfile->iscff ); }

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
#	PDF::API2::TrueTypeFont::FontFile
#
#=======================================================================
package PDF::API2::TrueTypeFont::FontFile;

use PDF::API2::Util;
use PDF::API2::IOString;
use PDF::API2::PDF::Utils;
use PDF::API2::PDF::Dict;
use POSIX;
use PDF::API2::TTF::Font;

use vars qw(@ISA %u2n);
@ISA = qw( PDF::API2::PDF::Dict );

%u2n=(
	'32' => 'space',			# U=0020, N=32
	'33' => 'exclam',			# U=0021, N=33
	'34' => 'quotedbl',			# U=0022, N=34
	'35' => 'numbersign',			# U=0023, N=35
	'36' => 'dollar',			# U=0024, N=36
	'37' => 'percent',			# U=0025, N=37
	'38' => 'ampersand',			# U=0026, N=38
	'39' => 'quotesingle',			# U=0027, N=39
	'40' => 'parenleft',			# U=0028, N=40
	'41' => 'parenright',			# U=0029, N=41
	'42' => 'asterisk',			# U=002A, N=42
	'43' => 'plus',				# U=002B, N=43
	'44' => 'comma',			# U=002C, N=44
	'45' => 'hyphen',			# U=002D, N=45
	'46' => 'period',			# U=002E, N=46
	'47' => 'slash',			# U=002F, N=47
	'48' => 'zero',				# U=0030, N=48
	'49' => 'one',				# U=0031, N=49
	'50' => 'two',				# U=0032, N=50
	'51' => 'three',			# U=0033, N=51
	'52' => 'four',				# U=0034, N=52
	'53' => 'five',				# U=0035, N=53
	'54' => 'six',				# U=0036, N=54
	'55' => 'seven',			# U=0037, N=55
	'56' => 'eight',			# U=0038, N=56
	'57' => 'nine',				# U=0039, N=57
	'58' => 'colon',			# U=003A, N=58
	'59' => 'semicolon',			# U=003B, N=59
	'60' => 'less',				# U=003C, N=60
	'61' => 'equal',			# U=003D, N=61
	'62' => 'greater',			# U=003E, N=62
	'63' => 'question',			# U=003F, N=63
	'64' => 'at',				# U=0040, N=64
	'65' => 'A',				# U=0041, N=65
	'66' => 'B',				# U=0042, N=66
	'67' => 'C',				# U=0043, N=67
	'68' => 'D',				# U=0044, N=68
	'69' => 'E',				# U=0045, N=69
	'70' => 'F',				# U=0046, N=70
	'71' => 'G',				# U=0047, N=71
	'72' => 'H',				# U=0048, N=72
	'73' => 'I',				# U=0049, N=73
	'74' => 'J',				# U=004A, N=74
	'75' => 'K',				# U=004B, N=75
	'76' => 'L',				# U=004C, N=76
	'77' => 'M',				# U=004D, N=77
	'78' => 'N',				# U=004E, N=78
	'79' => 'O',				# U=004F, N=79
	'80' => 'P',				# U=0050, N=80
	'81' => 'Q',				# U=0051, N=81
	'82' => 'R',				# U=0052, N=82
	'83' => 'S',				# U=0053, N=83
	'84' => 'T',				# U=0054, N=84
	'85' => 'U',				# U=0055, N=85
	'86' => 'V',				# U=0056, N=86
	'87' => 'W',				# U=0057, N=87
	'88' => 'X',				# U=0058, N=88
	'89' => 'Y',				# U=0059, N=89
	'90' => 'Z',				# U=005A, N=90
	'91' => 'bracketleft',			# U=005B, N=91
	'92' => 'backslash',			# U=005C, N=92
	'93' => 'bracketright',			# U=005D, N=93
	'94' => 'asciicircum',			# U=005E, N=94
	'95' => 'underscore',			# U=005F, N=95
	'96' => 'grave',			# U=0060, N=96
	'97' => 'a',				# U=0061, N=97
	'98' => 'b',				# U=0062, N=98
	'99' => 'c',				# U=0063, N=99
	'100' => 'd',				# U=0064, N=100
	'101' => 'e',				# U=0065, N=101
	'102' => 'f',				# U=0066, N=102
	'103' => 'g',				# U=0067, N=103
	'104' => 'h',				# U=0068, N=104
	'105' => 'i',				# U=0069, N=105
	'106' => 'j',				# U=006A, N=106
	'107' => 'k',				# U=006B, N=107
	'108' => 'l',				# U=006C, N=108
	'109' => 'm',				# U=006D, N=109
	'110' => 'n',				# U=006E, N=110
	'111' => 'o',				# U=006F, N=111
	'112' => 'p',				# U=0070, N=112
	'113' => 'q',				# U=0071, N=113
	'114' => 'r',				# U=0072, N=114
	'115' => 's',				# U=0073, N=115
	'116' => 't',				# U=0074, N=116
	'117' => 'u',				# U=0075, N=117
	'118' => 'v',				# U=0076, N=118
	'119' => 'w',				# U=0077, N=119
	'120' => 'x',				# U=0078, N=120
	'121' => 'y',				# U=0079, N=121
	'122' => 'z',				# U=007A, N=122
	'123' => 'braceleft',			# U=007B, N=123
	'124' => 'bar',				# U=007C, N=124
	'125' => 'braceright',			# U=007D, N=125
	'126' => 'asciitilde',			# U=007E, N=126
	'127' => 'bullet',			# U=007F, N=127
	'128' => 'Euro',			# U=0080, N=128
	'129' => 'bullet',			# U=0081, N=129
	'130' => 'quotesinglbase',		# U=0082, N=130
	'131' => 'florin',			# U=0083, N=131
	'132' => 'quotedblbase',		# U=0084, N=132
	'133' => 'ellipsis',			# U=0085, N=133
	'134' => 'dagger',			# U=0086, N=134
	'135' => 'daggerdbl',			# U=0087, N=135
	'136' => 'circumflex',			# U=0088, N=136
	'137' => 'perthousand',			# U=0089, N=137
	'138' => 'Scaron',			# U=008A, N=138
	'139' => 'guilsinglleft',		# U=008B, N=139
	'140' => 'OE',				# U=008C, N=140
	'141' => 'bullet',			# U=008D, N=141
	'142' => 'Zcaron',			# U=008E, N=142
	'143' => 'bullet',			# U=008F, N=143
	'144' => 'bullet',			# U=0090, N=144
	'145' => 'quoteleft',			# U=0091, N=145
	'146' => 'quoteright',			# U=0092, N=146
	'147' => 'quotedblleft',		# U=0093, N=147
	'148' => 'quotedblright',		# U=0094, N=148
	'149' => 'bullet',			# U=0095, N=149
	'150' => 'endash',			# U=0096, N=150
	'151' => 'emdash',			# U=0097, N=151
	'152' => 'tilde',			# U=0098, N=152
	'153' => 'trademark',			# U=0099, N=153
	'154' => 'scaron',			# U=009A, N=154
	'155' => 'guilsinglright',		# U=009B, N=155
	'156' => 'oe',				# U=009C, N=156
	'157' => 'bullet',			# U=009D, N=157
	'158' => 'zcaron',			# U=009E, N=158
	'159' => 'Ydieresis',			# U=009F, N=159
	'160' => 'space',			# U=00A0, N=160
	'161' => 'exclamdown',			# U=00A1, N=161
	'162' => 'cent',			# U=00A2, N=162
	'163' => 'sterling',			# U=00A3, N=163
	'164' => 'currency',			# U=00A4, N=164
	'165' => 'yen',				# U=00A5, N=165
	'166' => 'brokenbar',			# U=00A6, N=166
	'167' => 'section',			# U=00A7, N=167
	'168' => 'dieresis',			# U=00A8, N=168
	'169' => 'copyright',			# U=00A9, N=169
	'170' => 'ordfeminine',			# U=00AA, N=170
	'171' => 'guillemotleft',		# U=00AB, N=171
	'172' => 'logicalnot',			# U=00AC, N=172
	'173' => 'hyphen',			# U=00AD, N=173
	'174' => 'registered',			# U=00AE, N=174
	'175' => 'macron',			# U=00AF, N=175
	'176' => 'degree',			# U=00B0, N=176
	'177' => 'plusminus',			# U=00B1, N=177
	'178' => 'twosuperior',			# U=00B2, N=178
	'179' => 'threesuperior',		# U=00B3, N=179
	'180' => 'acute',			# U=00B4, N=180
	'181' => 'mu',				# U=00B5, N=181
	'182' => 'paragraph',			# U=00B6, N=182
	'183' => 'periodcentered',		# U=00B7, N=183
	'184' => 'cedilla',			# U=00B8, N=184
	'185' => 'onesuperior',			# U=00B9, N=185
	'186' => 'ordmasculine',		# U=00BA, N=186
	'187' => 'guillemotright',		# U=00BB, N=187
	'188' => 'onequarter',			# U=00BC, N=188
	'189' => 'onehalf',			# U=00BD, N=189
	'190' => 'threequarters',		# U=00BE, N=190
	'191' => 'questiondown',		# U=00BF, N=191
	'192' => 'Agrave',			# U=00C0, N=192
	'193' => 'Aacute',			# U=00C1, N=193
	'194' => 'Acircumflex',			# U=00C2, N=194
	'195' => 'Atilde',			# U=00C3, N=195
	'196' => 'Adieresis',			# U=00C4, N=196
	'197' => 'Aring',			# U=00C5, N=197
	'198' => 'AE',				# U=00C6, N=198
	'199' => 'Ccedilla',			# U=00C7, N=199
	'200' => 'Egrave',			# U=00C8, N=200
	'201' => 'Eacute',			# U=00C9, N=201
	'202' => 'Ecircumflex',			# U=00CA, N=202
	'203' => 'Edieresis',			# U=00CB, N=203
	'204' => 'Igrave',			# U=00CC, N=204
	'205' => 'Iacute',			# U=00CD, N=205
	'206' => 'Icircumflex',			# U=00CE, N=206
	'207' => 'Idieresis',			# U=00CF, N=207
	'208' => 'Eth',				# U=00D0, N=208
	'209' => 'Ntilde',			# U=00D1, N=209
	'210' => 'Ograve',			# U=00D2, N=210
	'211' => 'Oacute',			# U=00D3, N=211
	'212' => 'Ocircumflex',			# U=00D4, N=212
	'213' => 'Otilde',			# U=00D5, N=213
	'214' => 'Odieresis',			# U=00D6, N=214
	'215' => 'multiply',			# U=00D7, N=215
	'216' => 'Oslash',			# U=00D8, N=216
	'217' => 'Ugrave',			# U=00D9, N=217
	'218' => 'Uacute',			# U=00DA, N=218
	'219' => 'Ucircumflex',			# U=00DB, N=219
	'220' => 'Udieresis',			# U=00DC, N=220
	'221' => 'Yacute',			# U=00DD, N=221
	'222' => 'Thorn',			# U=00DE, N=222
	'223' => 'germandbls',			# U=00DF, N=223
	'224' => 'agrave',			# U=00E0, N=224
	'225' => 'aacute',			# U=00E1, N=225
	'226' => 'acircumflex',			# U=00E2, N=226
	'227' => 'atilde',			# U=00E3, N=227
	'228' => 'adieresis',			# U=00E4, N=228
	'229' => 'aring',			# U=00E5, N=229
	'230' => 'ae',				# U=00E6, N=230
	'231' => 'ccedilla',			# U=00E7, N=231
	'232' => 'egrave',			# U=00E8, N=232
	'233' => 'eacute',			# U=00E9, N=233
	'234' => 'ecircumflex',			# U=00EA, N=234
	'235' => 'edieresis',			# U=00EB, N=235
	'236' => 'igrave',			# U=00EC, N=236
	'237' => 'iacute',			# U=00ED, N=237
	'238' => 'icircumflex',			# U=00EE, N=238
	'239' => 'idieresis',			# U=00EF, N=239
	'240' => 'eth',				# U=00F0, N=240
	'241' => 'ntilde',			# U=00F1, N=241
	'242' => 'ograve',			# U=00F2, N=242
	'243' => 'oacute',			# U=00F3, N=243
	'244' => 'ocircumflex',			# U=00F4, N=244
	'245' => 'otilde',			# U=00F5, N=245
	'246' => 'odieresis',			# U=00F6, N=246
	'247' => 'divide',			# U=00F7, N=247
	'248' => 'oslash',			# U=00F8, N=248
	'249' => 'ugrave',			# U=00F9, N=249
	'250' => 'uacute',			# U=00FA, N=250
	'251' => 'ucircumflex',			# U=00FB, N=251
	'252' => 'udieresis',			# U=00FC, N=252
	'253' => 'yacute',			# U=00FD, N=253
	'254' => 'thorn',			# U=00FE, N=254
	'255' => 'ydieresis',			# U=00FF, N=255
	'256' => 'Amacron',			# U=0100, N=256
	'257' => 'amacron',			# U=0101, N=257
	'258' => 'Abreve',			# U=0102, N=258
	'259' => 'abreve',			# U=0103, N=259
	'260' => 'Aogonek',			# U=0104, N=260
	'261' => 'aogonek',			# U=0105, N=261
	'262' => 'Cacute',			# U=0106, N=262
	'263' => 'cacute',			# U=0107, N=263
	'264' => 'Ccircumflex',			# U=0108, N=264
	'265' => 'ccircumflex',			# U=0109, N=265
	'266' => 'Cdotaccent',			# U=010A, N=266
	'267' => 'cdotaccent',			# U=010B, N=267
	'268' => 'Ccaron',			# U=010C, N=268
	'269' => 'ccaron',			# U=010D, N=269
	'270' => 'Dcaron',			# U=010E, N=270
	'271' => 'dcaron',			# U=010F, N=271
	'272' => 'Dcroat',			# U=0110, N=272
	'273' => 'dcroat',			# U=0111, N=273
	'274' => 'Emacron',			# U=0112, N=274
	'275' => 'emacron',			# U=0113, N=275
	'276' => 'Ebreve',			# U=0114, N=276
	'277' => 'ebreve',			# U=0115, N=277
	'278' => 'Edotaccent',			# U=0116, N=278
	'279' => 'edotaccent',			# U=0117, N=279
	'280' => 'Eogonek',			# U=0118, N=280
	'281' => 'eogonek',			# U=0119, N=281
	'282' => 'Ecaron',			# U=011A, N=282
	'283' => 'ecaron',			# U=011B, N=283
	'284' => 'Gcircumflex',			# U=011C, N=284
	'285' => 'gcircumflex',			# U=011D, N=285
	'286' => 'Gbreve',			# U=011E, N=286
	'287' => 'gbreve',			# U=011F, N=287
	'288' => 'Gdotaccent',			# U=0120, N=288
	'289' => 'gdotaccent',			# U=0121, N=289
	'290' => 'Gcommaaccent',		# U=0122, N=290
	'291' => 'gcommaaccent',		# U=0123, N=291
	'292' => 'Hcircumflex',			# U=0124, N=292
	'293' => 'hcircumflex',			# U=0125, N=293
	'294' => 'Hbar',			# U=0126, N=294
	'295' => 'hbar',			# U=0127, N=295
	'296' => 'Itilde',			# U=0128, N=296
	'297' => 'itilde',			# U=0129, N=297
	'298' => 'Imacron',			# U=012A, N=298
	'299' => 'imacron',			# U=012B, N=299
	'300' => 'Ibreve',			# U=012C, N=300
	'301' => 'ibreve',			# U=012D, N=301
	'302' => 'Iogonek',			# U=012E, N=302
	'303' => 'iogonek',			# U=012F, N=303
	'304' => 'Idotaccent',			# U=0130, N=304
	'305' => 'dotlessi',			# U=0131, N=305
	'306' => 'IJ',				# U=0132, N=306
	'307' => 'ij',				# U=0133, N=307
	'308' => 'Jcircumflex',			# U=0134, N=308
	'309' => 'jcircumflex',			# U=0135, N=309
	'310' => 'Kcommaaccent',		# U=0136, N=310
	'311' => 'kcommaaccent',		# U=0137, N=311
	'312' => 'kgreenlandic',		# U=0138, N=312
	'313' => 'Lacute',			# U=0139, N=313
	'314' => 'lacute',			# U=013A, N=314
	'315' => 'Lcommaaccent',		# U=013B, N=315
	'316' => 'lcommaaccent',		# U=013C, N=316
	'317' => 'Lcaron',			# U=013D, N=317
	'318' => 'lcaron',			# U=013E, N=318
	'319' => 'Ldot',			# U=013F, N=319
	'320' => 'ldot',			# U=0140, N=320
	'321' => 'Lslash',			# U=0141, N=321
	'322' => 'lslash',			# U=0142, N=322
	'323' => 'Nacute',			# U=0143, N=323
	'324' => 'nacute',			# U=0144, N=324
	'325' => 'Ncommaaccent',		# U=0145, N=325
	'326' => 'ncommaaccent',		# U=0146, N=326
	'327' => 'Ncaron',			# U=0147, N=327
	'328' => 'ncaron',			# U=0148, N=328
	'329' => 'napostrophe',			# U=0149, N=329
	'330' => 'Eng',				# U=014A, N=330
	'331' => 'eng',				# U=014B, N=331
	'332' => 'Omacron',			# U=014C, N=332
	'333' => 'omacron',			# U=014D, N=333
	'334' => 'Obreve',			# U=014E, N=334
	'335' => 'obreve',			# U=014F, N=335
	'336' => 'Ohungarumlaut',		# U=0150, N=336
	'337' => 'ohungarumlaut',		# U=0151, N=337
	'338' => 'OE',				# U=0152, N=338
	'339' => 'oe',				# U=0153, N=339
	'340' => 'Racute',			# U=0154, N=340
	'341' => 'racute',			# U=0155, N=341
	'342' => 'Rcommaaccent',		# U=0156, N=342
	'343' => 'rcommaaccent',		# U=0157, N=343
	'344' => 'Rcaron',			# U=0158, N=344
	'345' => 'rcaron',			# U=0159, N=345
	'346' => 'Sacute',			# U=015A, N=346
	'347' => 'sacute',			# U=015B, N=347
	'348' => 'Scircumflex',			# U=015C, N=348
	'349' => 'scircumflex',			# U=015D, N=349
	'350' => 'Scedilla',			# U=015E, N=350
	'351' => 'scedilla',			# U=015F, N=351
	'352' => 'Scaron',			# U=0160, N=352
	'353' => 'scaron',			# U=0161, N=353
	'354' => 'Tcommaaccent',		# U=0162, N=354
	'355' => 'tcommaaccent',		# U=0163, N=355
	'356' => 'Tcaron',			# U=0164, N=356
	'357' => 'tcaron',			# U=0165, N=357
	'358' => 'Tbar',			# U=0166, N=358
	'359' => 'tbar',			# U=0167, N=359
	'360' => 'Utilde',			# U=0168, N=360
	'361' => 'utilde',			# U=0169, N=361
	'362' => 'Umacron',			# U=016A, N=362
	'363' => 'umacron',			# U=016B, N=363
	'364' => 'Ubreve',			# U=016C, N=364
	'365' => 'ubreve',			# U=016D, N=365
	'366' => 'Uring',			# U=016E, N=366
	'367' => 'uring',			# U=016F, N=367
	'368' => 'Uhungarumlaut',		# U=0170, N=368
	'369' => 'uhungarumlaut',		# U=0171, N=369
	'370' => 'Uogonek',			# U=0172, N=370
	'371' => 'uogonek',			# U=0173, N=371
	'372' => 'Wcircumflex',			# U=0174, N=372
	'373' => 'wcircumflex',			# U=0175, N=373
	'374' => 'Ycircumflex',			# U=0176, N=374
	'375' => 'ycircumflex',			# U=0177, N=375
	'376' => 'Ydieresis',			# U=0178, N=376
	'377' => 'Zacute',			# U=0179, N=377
	'378' => 'zacute',			# U=017A, N=378
	'379' => 'Zdotaccent',			# U=017B, N=379
	'380' => 'zdotaccent',			# U=017C, N=380
	'381' => 'Zcaron',			# U=017D, N=381
	'382' => 'zcaron',			# U=017E, N=382
	'383' => 'longs',			# U=017F, N=383
	'402' => 'florin',			# U=0192, N=402
	'416' => 'Ohorn',			# U=01A0, N=416
	'417' => 'ohorn',			# U=01A1, N=417
	'431' => 'Uhorn',			# U=01AF, N=431
	'432' => 'uhorn',			# U=01B0, N=432
	'486' => 'Gcaron',			# U=01E6, N=486
	'487' => 'gcaron',			# U=01E7, N=487
	'506' => 'Aringacute',			# U=01FA, N=506
	'507' => 'aringacute',			# U=01FB, N=507
	'508' => 'AEacute',			# U=01FC, N=508
	'509' => 'aeacute',			# U=01FD, N=509
	'510' => 'Oslashacute',			# U=01FE, N=510
	'511' => 'oslashacute',			# U=01FF, N=511
	'536' => 'Scommaaccent',		# U=0218, N=536
	'537' => 'scommaaccent',		# U=0219, N=537
	'538' => 'Tcommaaccent',		# U=021A, N=538
	'539' => 'tcommaaccent',		# U=021B, N=539
	'700' => 'afii57929',			# U=02BC, N=700
	'701' => 'afii64937',			# U=02BD, N=701
	'710' => 'circumflex',			# U=02C6, N=710
	'711' => 'caron',			# U=02C7, N=711
	'713' => 'macron',			# U=02C9, N=713
	'728' => 'breve',			# U=02D8, N=728
	'729' => 'dotaccent',			# U=02D9, N=729
	'730' => 'ring',			# U=02DA, N=730
	'731' => 'ogonek',			# U=02DB, N=731
	'732' => 'tilde',			# U=02DC, N=732
	'733' => 'hungarumlaut',		# U=02DD, N=733
	'768' => 'gravecomb',			# U=0300, N=768
	'769' => 'acutecomb',			# U=0301, N=769
	'771' => 'tildecomb',			# U=0303, N=771
	'777' => 'hookabovecomb',		# U=0309, N=777
	'803' => 'dotbelowcomb',		# U=0323, N=803
	'900' => 'tonos',			# U=0384, N=900
	'901' => 'dieresistonos',		# U=0385, N=901
	'902' => 'Alphatonos',			# U=0386, N=902
	'903' => 'anoteleia',			# U=0387, N=903
	'904' => 'Epsilontonos',		# U=0388, N=904
	'905' => 'Etatonos',			# U=0389, N=905
	'906' => 'Iotatonos',			# U=038A, N=906
	'908' => 'Omicrontonos',		# U=038C, N=908
	'910' => 'Upsilontonos',		# U=038E, N=910
	'911' => 'Omegatonos',			# U=038F, N=911
	'912' => 'iotadieresistonos',		# U=0390, N=912
	'913' => 'Alpha',			# U=0391, N=913
	'914' => 'Beta',			# U=0392, N=914
	'915' => 'Gamma',			# U=0393, N=915
	'916' => 'Delta',			# U=0394, N=916
	'917' => 'Epsilon',			# U=0395, N=917
	'918' => 'Zeta',			# U=0396, N=918
	'919' => 'Eta',				# U=0397, N=919
	'920' => 'Theta',			# U=0398, N=920
	'921' => 'Iota',			# U=0399, N=921
	'922' => 'Kappa',			# U=039A, N=922
	'923' => 'Lambda',			# U=039B, N=923
	'924' => 'Mu',				# U=039C, N=924
	'925' => 'Nu',				# U=039D, N=925
	'926' => 'Xi',				# U=039E, N=926
	'927' => 'Omicron',			# U=039F, N=927
	'928' => 'Pi',				# U=03A0, N=928
	'929' => 'Rho',				# U=03A1, N=929
	'931' => 'Sigma',			# U=03A3, N=931
	'932' => 'Tau',				# U=03A4, N=932
	'933' => 'Upsilon',			# U=03A5, N=933
	'934' => 'Phi',				# U=03A6, N=934
	'935' => 'Chi',				# U=03A7, N=935
	'936' => 'Psi',				# U=03A8, N=936
	'937' => 'Omega',			# U=03A9, N=937
	'938' => 'Iotadieresis',		# U=03AA, N=938
	'939' => 'Upsilondieresis',		# U=03AB, N=939
	'940' => 'alphatonos',			# U=03AC, N=940
	'941' => 'epsilontonos',		# U=03AD, N=941
	'942' => 'etatonos',			# U=03AE, N=942
	'943' => 'iotatonos',			# U=03AF, N=943
	'944' => 'upsilondieresistonos',	# U=03B0, N=944
	'945' => 'alpha',			# U=03B1, N=945
	'946' => 'beta',			# U=03B2, N=946
	'947' => 'gamma',			# U=03B3, N=947
	'948' => 'delta',			# U=03B4, N=948
	'949' => 'epsilon',			# U=03B5, N=949
	'950' => 'zeta',			# U=03B6, N=950
	'951' => 'eta',				# U=03B7, N=951
	'952' => 'theta',			# U=03B8, N=952
	'953' => 'iota',			# U=03B9, N=953
	'954' => 'kappa',			# U=03BA, N=954
	'955' => 'lambda',			# U=03BB, N=955
	'956' => 'mu',				# U=03BC, N=956
	'957' => 'nu',				# U=03BD, N=957
	'958' => 'xi',				# U=03BE, N=958
	'959' => 'omicron',			# U=03BF, N=959
	'960' => 'pi',				# U=03C0, N=960
	'961' => 'rho',				# U=03C1, N=961
	'962' => 'sigma1',			# U=03C2, N=962
	'963' => 'sigma',			# U=03C3, N=963
	'964' => 'tau',				# U=03C4, N=964
	'965' => 'upsilon',			# U=03C5, N=965
	'966' => 'phi',				# U=03C6, N=966
	'967' => 'chi',				# U=03C7, N=967
	'968' => 'psi',				# U=03C8, N=968
	'969' => 'omega',			# U=03C9, N=969
	'970' => 'iotadieresis',		# U=03CA, N=970
	'971' => 'upsilondieresis',		# U=03CB, N=971
	'972' => 'omicrontonos',		# U=03CC, N=972
	'973' => 'upsilontonos',		# U=03CD, N=973
	'974' => 'omegatonos',			# U=03CE, N=974
	'977' => 'theta1',			# U=03D1, N=977
	'978' => 'Upsilon1',			# U=03D2, N=978
	'981' => 'phi1',			# U=03D5, N=981
	'982' => 'omega1',			# U=03D6, N=982
	'1025' => 'afii10023',			# U=0401, N=1025
	'1026' => 'afii10051',			# U=0402, N=1026
	'1027' => 'afii10052',			# U=0403, N=1027
	'1028' => 'afii10053',			# U=0404, N=1028
	'1029' => 'afii10054',			# U=0405, N=1029
	'1030' => 'afii10055',			# U=0406, N=1030
	'1031' => 'afii10056',			# U=0407, N=1031
	'1032' => 'afii10057',			# U=0408, N=1032
	'1033' => 'afii10058',			# U=0409, N=1033
	'1034' => 'afii10059',			# U=040A, N=1034
	'1035' => 'afii10060',			# U=040B, N=1035
	'1036' => 'afii10061',			# U=040C, N=1036
	'1038' => 'afii10062',			# U=040E, N=1038
	'1039' => 'afii10145',			# U=040F, N=1039
	'1040' => 'afii10017',			# U=0410, N=1040
	'1041' => 'afii10018',			# U=0411, N=1041
	'1042' => 'afii10019',			# U=0412, N=1042
	'1043' => 'afii10020',			# U=0413, N=1043
	'1044' => 'afii10021',			# U=0414, N=1044
	'1045' => 'afii10022',			# U=0415, N=1045
	'1046' => 'afii10024',			# U=0416, N=1046
	'1047' => 'afii10025',			# U=0417, N=1047
	'1048' => 'afii10026',			# U=0418, N=1048
	'1049' => 'afii10027',			# U=0419, N=1049
	'1050' => 'afii10028',			# U=041A, N=1050
	'1051' => 'afii10029',			# U=041B, N=1051
	'1052' => 'afii10030',			# U=041C, N=1052
	'1053' => 'afii10031',			# U=041D, N=1053
	'1054' => 'afii10032',			# U=041E, N=1054
	'1055' => 'afii10033',			# U=041F, N=1055
	'1056' => 'afii10034',			# U=0420, N=1056
	'1057' => 'afii10035',			# U=0421, N=1057
	'1058' => 'afii10036',			# U=0422, N=1058
	'1059' => 'afii10037',			# U=0423, N=1059
	'1060' => 'afii10038',			# U=0424, N=1060
	'1061' => 'afii10039',			# U=0425, N=1061
	'1062' => 'afii10040',			# U=0426, N=1062
	'1063' => 'afii10041',			# U=0427, N=1063
	'1064' => 'afii10042',			# U=0428, N=1064
	'1065' => 'afii10043',			# U=0429, N=1065
	'1066' => 'afii10044',			# U=042A, N=1066
	'1067' => 'afii10045',			# U=042B, N=1067
	'1068' => 'afii10046',			# U=042C, N=1068
	'1069' => 'afii10047',			# U=042D, N=1069
	'1070' => 'afii10048',			# U=042E, N=1070
	'1071' => 'afii10049',			# U=042F, N=1071
	'1072' => 'afii10065',			# U=0430, N=1072
	'1073' => 'afii10066',			# U=0431, N=1073
	'1074' => 'afii10067',			# U=0432, N=1074
	'1075' => 'afii10068',			# U=0433, N=1075
	'1076' => 'afii10069',			# U=0434, N=1076
	'1077' => 'afii10070',			# U=0435, N=1077
	'1078' => 'afii10072',			# U=0436, N=1078
	'1079' => 'afii10073',			# U=0437, N=1079
	'1080' => 'afii10074',			# U=0438, N=1080
	'1081' => 'afii10075',			# U=0439, N=1081
	'1082' => 'afii10076',			# U=043A, N=1082
	'1083' => 'afii10077',			# U=043B, N=1083
	'1084' => 'afii10078',			# U=043C, N=1084
	'1085' => 'afii10079',			# U=043D, N=1085
	'1086' => 'afii10080',			# U=043E, N=1086
	'1087' => 'afii10081',			# U=043F, N=1087
	'1088' => 'afii10082',			# U=0440, N=1088
	'1089' => 'afii10083',			# U=0441, N=1089
	'1090' => 'afii10084',			# U=0442, N=1090
	'1091' => 'afii10085',			# U=0443, N=1091
	'1092' => 'afii10086',			# U=0444, N=1092
	'1093' => 'afii10087',			# U=0445, N=1093
	'1094' => 'afii10088',			# U=0446, N=1094
	'1095' => 'afii10089',			# U=0447, N=1095
	'1096' => 'afii10090',			# U=0448, N=1096
	'1097' => 'afii10091',			# U=0449, N=1097
	'1098' => 'afii10092',			# U=044A, N=1098
	'1099' => 'afii10093',			# U=044B, N=1099
	'1100' => 'afii10094',			# U=044C, N=1100
	'1101' => 'afii10095',			# U=044D, N=1101
	'1102' => 'afii10096',			# U=044E, N=1102
	'1103' => 'afii10097',			# U=044F, N=1103
	'1105' => 'afii10071',			# U=0451, N=1105
	'1106' => 'afii10099',			# U=0452, N=1106
	'1107' => 'afii10100',			# U=0453, N=1107
	'1108' => 'afii10101',			# U=0454, N=1108
	'1109' => 'afii10102',			# U=0455, N=1109
	'1110' => 'afii10103',			# U=0456, N=1110
	'1111' => 'afii10104',			# U=0457, N=1111
	'1112' => 'afii10105',			# U=0458, N=1112
	'1113' => 'afii10106',			# U=0459, N=1113
	'1114' => 'afii10107',			# U=045A, N=1114
	'1115' => 'afii10108',			# U=045B, N=1115
	'1116' => 'afii10109',			# U=045C, N=1116
	'1118' => 'afii10110',			# U=045E, N=1118
	'1119' => 'afii10193',			# U=045F, N=1119
	'1122' => 'afii10146',			# U=0462, N=1122
	'1123' => 'afii10194',			# U=0463, N=1123
	'1138' => 'afii10147',			# U=0472, N=1138
	'1139' => 'afii10195',			# U=0473, N=1139
	'1140' => 'afii10148',			# U=0474, N=1140
	'1141' => 'afii10196',			# U=0475, N=1141
	'1168' => 'afii10050',			# U=0490, N=1168
	'1169' => 'afii10098',			# U=0491, N=1169
	'1241' => 'afii10846',			# U=04D9, N=1241
	'1456' => 'afii57799',			# U=05B0, N=1456
	'1457' => 'afii57801',			# U=05B1, N=1457
	'1458' => 'afii57800',			# U=05B2, N=1458
	'1459' => 'afii57802',			# U=05B3, N=1459
	'1460' => 'afii57793',			# U=05B4, N=1460
	'1461' => 'afii57794',			# U=05B5, N=1461
	'1462' => 'afii57795',			# U=05B6, N=1462
	'1463' => 'afii57798',			# U=05B7, N=1463
	'1464' => 'afii57797',			# U=05B8, N=1464
	'1465' => 'afii57806',			# U=05B9, N=1465
	'1467' => 'afii57796',			# U=05BB, N=1467
	'1468' => 'afii57807',			# U=05BC, N=1468
	'1469' => 'afii57839',			# U=05BD, N=1469
	'1470' => 'afii57645',			# U=05BE, N=1470
	'1471' => 'afii57841',			# U=05BF, N=1471
	'1472' => 'afii57842',			# U=05C0, N=1472
	'1473' => 'afii57804',			# U=05C1, N=1473
	'1474' => 'afii57803',			# U=05C2, N=1474
	'1475' => 'afii57658',			# U=05C3, N=1475
	'1488' => 'afii57664',			# U=05D0, N=1488
	'1489' => 'afii57665',			# U=05D1, N=1489
	'1490' => 'afii57666',			# U=05D2, N=1490
	'1491' => 'afii57667',			# U=05D3, N=1491
	'1492' => 'afii57668',			# U=05D4, N=1492
	'1493' => 'afii57669',			# U=05D5, N=1493
	'1494' => 'afii57670',			# U=05D6, N=1494
	'1495' => 'afii57671',			# U=05D7, N=1495
	'1496' => 'afii57672',			# U=05D8, N=1496
	'1497' => 'afii57673',			# U=05D9, N=1497
	'1498' => 'afii57674',			# U=05DA, N=1498
	'1499' => 'afii57675',			# U=05DB, N=1499
	'1500' => 'afii57676',			# U=05DC, N=1500
	'1501' => 'afii57677',			# U=05DD, N=1501
	'1502' => 'afii57678',			# U=05DE, N=1502
	'1503' => 'afii57679',			# U=05DF, N=1503
	'1504' => 'afii57680',			# U=05E0, N=1504
	'1505' => 'afii57681',			# U=05E1, N=1505
	'1506' => 'afii57682',			# U=05E2, N=1506
	'1507' => 'afii57683',			# U=05E3, N=1507
	'1508' => 'afii57684',			# U=05E4, N=1508
	'1509' => 'afii57685',			# U=05E5, N=1509
	'1510' => 'afii57686',			# U=05E6, N=1510
	'1511' => 'afii57687',			# U=05E7, N=1511
	'1512' => 'afii57688',			# U=05E8, N=1512
	'1513' => 'afii57689',			# U=05E9, N=1513
	'1514' => 'afii57690',			# U=05EA, N=1514
	'1520' => 'afii57716',			# U=05F0, N=1520
	'1521' => 'afii57717',			# U=05F1, N=1521
	'1522' => 'afii57718',			# U=05F2, N=1522
	'1548' => 'afii57388',			# U=060C, N=1548
	'1563' => 'afii57403',			# U=061B, N=1563
	'1567' => 'afii57407',			# U=061F, N=1567
	'1569' => 'afii57409',			# U=0621, N=1569
	'1570' => 'afii57410',			# U=0622, N=1570
	'1571' => 'afii57411',			# U=0623, N=1571
	'1572' => 'afii57412',			# U=0624, N=1572
	'1573' => 'afii57413',			# U=0625, N=1573
	'1574' => 'afii57414',			# U=0626, N=1574
	'1575' => 'afii57415',			# U=0627, N=1575
	'1576' => 'afii57416',			# U=0628, N=1576
	'1577' => 'afii57417',			# U=0629, N=1577
	'1578' => 'afii57418',			# U=062A, N=1578
	'1579' => 'afii57419',			# U=062B, N=1579
	'1580' => 'afii57420',			# U=062C, N=1580
	'1581' => 'afii57421',			# U=062D, N=1581
	'1582' => 'afii57422',			# U=062E, N=1582
	'1583' => 'afii57423',			# U=062F, N=1583
	'1584' => 'afii57424',			# U=0630, N=1584
	'1585' => 'afii57425',			# U=0631, N=1585
	'1586' => 'afii57426',			# U=0632, N=1586
	'1587' => 'afii57427',			# U=0633, N=1587
	'1588' => 'afii57428',			# U=0634, N=1588
	'1589' => 'afii57429',			# U=0635, N=1589
	'1590' => 'afii57430',			# U=0636, N=1590
	'1591' => 'afii57431',			# U=0637, N=1591
	'1592' => 'afii57432',			# U=0638, N=1592
	'1593' => 'afii57433',			# U=0639, N=1593
	'1594' => 'afii57434',			# U=063A, N=1594
	'1600' => 'afii57440',			# U=0640, N=1600
	'1601' => 'afii57441',			# U=0641, N=1601
	'1602' => 'afii57442',			# U=0642, N=1602
	'1603' => 'afii57443',			# U=0643, N=1603
	'1604' => 'afii57444',			# U=0644, N=1604
	'1605' => 'afii57445',			# U=0645, N=1605
	'1606' => 'afii57446',			# U=0646, N=1606
	'1607' => 'afii57470',			# U=0647, N=1607
	'1608' => 'afii57448',			# U=0648, N=1608
	'1609' => 'afii57449',			# U=0649, N=1609
	'1610' => 'afii57450',			# U=064A, N=1610
	'1611' => 'afii57451',			# U=064B, N=1611
	'1612' => 'afii57452',			# U=064C, N=1612
	'1613' => 'afii57453',			# U=064D, N=1613
	'1614' => 'afii57454',			# U=064E, N=1614
	'1615' => 'afii57455',			# U=064F, N=1615
	'1616' => 'afii57456',			# U=0650, N=1616
	'1617' => 'afii57457',			# U=0651, N=1617
	'1618' => 'afii57458',			# U=0652, N=1618
	'1632' => 'afii57392',			# U=0660, N=1632
	'1633' => 'afii57393',			# U=0661, N=1633
	'1634' => 'afii57394',			# U=0662, N=1634
	'1635' => 'afii57395',			# U=0663, N=1635
	'1636' => 'afii57396',			# U=0664, N=1636
	'1637' => 'afii57397',			# U=0665, N=1637
	'1638' => 'afii57398',			# U=0666, N=1638
	'1639' => 'afii57399',			# U=0667, N=1639
	'1640' => 'afii57400',			# U=0668, N=1640
	'1641' => 'afii57401',			# U=0669, N=1641
	'1642' => 'afii57381',			# U=066A, N=1642
	'1645' => 'afii63167',			# U=066D, N=1645
	'1657' => 'afii57511',			# U=0679, N=1657
	'1662' => 'afii57506',			# U=067E, N=1662
	'1670' => 'afii57507',			# U=0686, N=1670
	'1672' => 'afii57512',			# U=0688, N=1672
	'1681' => 'afii57513',			# U=0691, N=1681
	'1688' => 'afii57508',			# U=0698, N=1688
	'1700' => 'afii57505',			# U=06A4, N=1700
	'1711' => 'afii57509',			# U=06AF, N=1711
	'1722' => 'afii57514',			# U=06BA, N=1722
	'1746' => 'afii57519',			# U=06D2, N=1746
	'1749' => 'afii57534',			# U=06D5, N=1749
	'7808' => 'Wgrave',			# U=1E80, N=7808
	'7809' => 'wgrave',			# U=1E81, N=7809
	'7810' => 'Wacute',			# U=1E82, N=7810
	'7811' => 'wacute',			# U=1E83, N=7811
	'7812' => 'Wdieresis',			# U=1E84, N=7812
	'7813' => 'wdieresis',			# U=1E85, N=7813
	'7922' => 'Ygrave',			# U=1EF2, N=7922
	'7923' => 'ygrave',			# U=1EF3, N=7923
	'8204' => 'afii61664',			# U=200C, N=8204
	'8205' => 'afii301',			# U=200D, N=8205
	'8206' => 'afii299',			# U=200E, N=8206
	'8207' => 'afii300',			# U=200F, N=8207
	'8210' => 'figuredash',			# U=2012, N=8210
	'8211' => 'endash',			# U=2013, N=8211
	'8212' => 'emdash',			# U=2014, N=8212
	'8213' => 'afii00208',			# U=2015, N=8213
	'8215' => 'underscoredbl',		# U=2017, N=8215
	'8216' => 'quoteleft',			# U=2018, N=8216
	'8217' => 'quoteright',			# U=2019, N=8217
	'8218' => 'quotesinglbase',		# U=201A, N=8218
	'8219' => 'quotereversed',		# U=201B, N=8219
	'8220' => 'quotedblleft',		# U=201C, N=8220
	'8221' => 'quotedblright',		# U=201D, N=8221
	'8222' => 'quotedblbase',		# U=201E, N=8222
	'8224' => 'dagger',			# U=2020, N=8224
	'8225' => 'daggerdbl',			# U=2021, N=8225
	'8226' => 'bullet',			# U=2022, N=8226
	'8228' => 'onedotenleader',		# U=2024, N=8228
	'8229' => 'twodotenleader',		# U=2025, N=8229
	'8230' => 'ellipsis',			# U=2026, N=8230
	'8236' => 'afii61573',			# U=202C, N=8236
	'8237' => 'afii61574',			# U=202D, N=8237
	'8238' => 'afii61575',			# U=202E, N=8238
	'8240' => 'perthousand',		# U=2030, N=8240
	'8242' => 'minute',			# U=2032, N=8242
	'8243' => 'second',			# U=2033, N=8243
	'8249' => 'guilsinglleft',		# U=2039, N=8249
	'8250' => 'guilsinglright',		# U=203A, N=8250
	'8252' => 'exclamdbl',			# U=203C, N=8252
	'8254' => 'overline',			# U=203E, N=8254
	'8260' => 'fraction',			# U=2044, N=8260
	'8304' => 'zerosuperior',		# U=2070, N=8304
	'8308' => 'foursuperior',		# U=2074, N=8308
	'8309' => 'fivesuperior',		# U=2075, N=8309
	'8310' => 'sixsuperior',		# U=2076, N=8310
	'8311' => 'sevensuperior',		# U=2077, N=8311
	'8312' => 'eightsuperior',		# U=2078, N=8312
	'8313' => 'ninesuperior',		# U=2079, N=8313
	'8317' => 'parenleftsuperior',		# U=207D, N=8317
	'8318' => 'parenrightsuperior',		# U=207E, N=8318
	'8319' => 'nsuperior',			# U=207F, N=8319
	'8320' => 'zeroinferior',		# U=2080, N=8320
	'8321' => 'oneinferior',		# U=2081, N=8321
	'8322' => 'twoinferior',		# U=2082, N=8322
	'8323' => 'threeinferior',		# U=2083, N=8323
	'8324' => 'fourinferior',		# U=2084, N=8324
	'8325' => 'fiveinferior',		# U=2085, N=8325
	'8326' => 'sixinferior',		# U=2086, N=8326
	'8327' => 'seveninferior',		# U=2087, N=8327
	'8328' => 'eightinferior',		# U=2088, N=8328
	'8329' => 'nineinferior',		# U=2089, N=8329
	'8333' => 'parenleftinferior',		# U=208D, N=8333
	'8334' => 'parenrightinferior',		# U=208E, N=8334
	'8353' => 'colonmonetary',		# U=20A1, N=8353
	'8355' => 'franc',			# U=20A3, N=8355
	'8356' => 'lira',			# U=20A4, N=8356
	'8359' => 'peseta',			# U=20A7, N=8359
	'8362' => 'afii57636',			# U=20AA, N=8362
	'8363' => 'dong',			# U=20AB, N=8363
	'8364' => 'Euro',			# U=20AC, N=8364
	'8453' => 'afii61248',			# U=2105, N=8453
	'8465' => 'Ifraktur',			# U=2111, N=8465
	'8467' => 'afii61289',			# U=2113, N=8467
	'8470' => 'afii61352',			# U=2116, N=8470
	'8472' => 'weierstrass',		# U=2118, N=8472
	'8476' => 'Rfraktur',			# U=211C, N=8476
	'8478' => 'prescription',		# U=211E, N=8478
	'8482' => 'trademark',			# U=2122, N=8482
	'8486' => 'Omega',			# U=2126, N=8486
	'8494' => 'estimated',			# U=212E, N=8494
	'8501' => 'aleph',			# U=2135, N=8501
	'8531' => 'onethird',			# U=2153, N=8531
	'8532' => 'twothirds',			# U=2154, N=8532
	'8539' => 'oneeighth',			# U=215B, N=8539
	'8540' => 'threeeighths',		# U=215C, N=8540
	'8541' => 'fiveeighths',		# U=215D, N=8541
	'8542' => 'seveneighths',		# U=215E, N=8542
	'8592' => 'arrowleft',			# U=2190, N=8592
	'8593' => 'arrowup',			# U=2191, N=8593
	'8594' => 'arrowright',			# U=2192, N=8594
	'8595' => 'arrowdown',			# U=2193, N=8595
	'8596' => 'arrowboth',			# U=2194, N=8596
	'8597' => 'arrowupdn',			# U=2195, N=8597
	'8616' => 'arrowupdnbse',		# U=21A8, N=8616
	'8629' => 'carriagereturn',		# U=21B5, N=8629
	'8656' => 'arrowdblleft',		# U=21D0, N=8656
	'8657' => 'arrowdblup',			# U=21D1, N=8657
	'8658' => 'arrowdblright',		# U=21D2, N=8658
	'8659' => 'arrowdbldown',		# U=21D3, N=8659
	'8660' => 'arrowdblboth',		# U=21D4, N=8660
	'8704' => 'universal',			# U=2200, N=8704
	'8706' => 'partialdiff',		# U=2202, N=8706
	'8707' => 'existential',		# U=2203, N=8707
	'8709' => 'emptyset',			# U=2205, N=8709
	'8710' => 'Delta',			# U=2206, N=8710
	'8711' => 'gradient',			# U=2207, N=8711
	'8712' => 'element',			# U=2208, N=8712
	'8713' => 'notelement',			# U=2209, N=8713
	'8715' => 'suchthat',			# U=220B, N=8715
	'8719' => 'product',			# U=220F, N=8719
	'8721' => 'summation',			# U=2211, N=8721
	'8722' => 'minus',			# U=2212, N=8722
	'8725' => 'fraction',			# U=2215, N=8725
	'8727' => 'asteriskmath',		# U=2217, N=8727
	'8729' => 'periodcentered',		# U=2219, N=8729
	'8730' => 'radical',			# U=221A, N=8730
	'8733' => 'proportional',		# U=221D, N=8733
	'8734' => 'infinity',			# U=221E, N=8734
	'8735' => 'orthogonal',			# U=221F, N=8735
	'8736' => 'angle',			# U=2220, N=8736
	'8743' => 'logicaland',			# U=2227, N=8743
	'8744' => 'logicalor',			# U=2228, N=8744
	'8745' => 'intersection',		# U=2229, N=8745
	'8746' => 'union',			# U=222A, N=8746
	'8747' => 'integral',			# U=222B, N=8747
	'8756' => 'therefore',			# U=2234, N=8756
	'8764' => 'similar',			# U=223C, N=8764
	'8773' => 'congruent',			# U=2245, N=8773
	'8776' => 'approxequal',		# U=2248, N=8776
	'8800' => 'notequal',			# U=2260, N=8800
	'8801' => 'equivalence',		# U=2261, N=8801
	'8804' => 'lessequal',			# U=2264, N=8804
	'8805' => 'greaterequal',		# U=2265, N=8805
	'8834' => 'propersubset',		# U=2282, N=8834
	'8835' => 'propersuperset',		# U=2283, N=8835
	'8836' => 'notsubset',			# U=2284, N=8836
	'8838' => 'reflexsubset',		# U=2286, N=8838
	'8839' => 'reflexsuperset',		# U=2287, N=8839
	'8853' => 'circleplus',			# U=2295, N=8853
	'8855' => 'circlemultiply',		# U=2297, N=8855
	'8869' => 'perpendicular',		# U=22A5, N=8869
	'8901' => 'dotmath',			# U=22C5, N=8901
	'8962' => 'house',			# U=2302, N=8962
	'8976' => 'revlogicalnot',		# U=2310, N=8976
	'8992' => 'integraltp',			# U=2320, N=8992
	'8993' => 'integralbt',			# U=2321, N=8993
	'9001' => 'angleleft',			# U=2329, N=9001
	'9002' => 'angleright',			# U=232A, N=9002
	'9312' => 'a120',			# U=2460, N=9312
	'9313' => 'a121',			# U=2461, N=9313
	'9314' => 'a122',			# U=2462, N=9314
	'9315' => 'a123',			# U=2463, N=9315
	'9316' => 'a124',			# U=2464, N=9316
	'9317' => 'a125',			# U=2465, N=9317
	'9318' => 'a126',			# U=2466, N=9318
	'9319' => 'a127',			# U=2467, N=9319
	'9320' => 'a128',			# U=2468, N=9320
	'9321' => 'a129',			# U=2469, N=9321
	'9472' => 'SF100000',			# U=2500, N=9472
	'9474' => 'SF110000',			# U=2502, N=9474
	'9484' => 'SF010000',			# U=250C, N=9484
	'9488' => 'SF030000',			# U=2510, N=9488
	'9492' => 'SF020000',			# U=2514, N=9492
	'9496' => 'SF040000',			# U=2518, N=9496
	'9500' => 'SF080000',			# U=251C, N=9500
	'9508' => 'SF090000',			# U=2524, N=9508
	'9516' => 'SF060000',			# U=252C, N=9516
	'9524' => 'SF070000',			# U=2534, N=9524
	'9532' => 'SF050000',			# U=253C, N=9532
	'9552' => 'SF430000',			# U=2550, N=9552
	'9553' => 'SF240000',			# U=2551, N=9553
	'9554' => 'SF510000',			# U=2552, N=9554
	'9555' => 'SF520000',			# U=2553, N=9555
	'9556' => 'SF390000',			# U=2554, N=9556
	'9557' => 'SF220000',			# U=2555, N=9557
	'9558' => 'SF210000',			# U=2556, N=9558
	'9559' => 'SF250000',			# U=2557, N=9559
	'9560' => 'SF500000',			# U=2558, N=9560
	'9561' => 'SF490000',			# U=2559, N=9561
	'9562' => 'SF380000',			# U=255A, N=9562
	'9563' => 'SF280000',			# U=255B, N=9563
	'9564' => 'SF270000',			# U=255C, N=9564
	'9565' => 'SF260000',			# U=255D, N=9565
	'9566' => 'SF360000',			# U=255E, N=9566
	'9567' => 'SF370000',			# U=255F, N=9567
	'9568' => 'SF420000',			# U=2560, N=9568
	'9569' => 'SF190000',			# U=2561, N=9569
	'9570' => 'SF200000',			# U=2562, N=9570
	'9571' => 'SF230000',			# U=2563, N=9571
	'9572' => 'SF470000',			# U=2564, N=9572
	'9573' => 'SF480000',			# U=2565, N=9573
	'9574' => 'SF410000',			# U=2566, N=9574
	'9575' => 'SF450000',			# U=2567, N=9575
	'9576' => 'SF460000',			# U=2568, N=9576
	'9577' => 'SF400000',			# U=2569, N=9577
	'9578' => 'SF540000',			# U=256A, N=9578
	'9579' => 'SF530000',			# U=256B, N=9579
	'9580' => 'SF440000',			# U=256C, N=9580
	'9600' => 'upblock',			# U=2580, N=9600
	'9604' => 'dnblock',			# U=2584, N=9604
	'9608' => 'block',			# U=2588, N=9608
	'9612' => 'lfblock',			# U=258C, N=9612
	'9616' => 'rtblock',			# U=2590, N=9616
	'9617' => 'ltshade',			# U=2591, N=9617
	'9618' => 'shade',			# U=2592, N=9618
	'9619' => 'dkshade',			# U=2593, N=9619
	'9632' => 'filledbox',			# U=25A0, N=9632
	'9633' => 'H22073',			# U=25A1, N=9633
	'9642' => 'H18543',			# U=25AA, N=9642
	'9643' => 'H18551',			# U=25AB, N=9643
	'9644' => 'filledrect',			# U=25AC, N=9644
	'9650' => 'triagup',			# U=25B2, N=9650
	'9658' => 'triagrt',			# U=25BA, N=9658
	'9660' => 'triagdn',			# U=25BC, N=9660
	'9668' => 'triaglf',			# U=25C4, N=9668
	'9670' => 'a78',			# U=25C6, N=9670
	'9674' => 'lozenge',			# U=25CA, N=9674
	'9675' => 'circle',			# U=25CB, N=9675
	'9679' => 'a71',			# U=25CF, N=9679
	'9687' => 'a81',			# U=25D7, N=9687
	'9688' => 'invbullet',			# U=25D8, N=9688
	'9689' => 'invcircle',			# U=25D9, N=9689
	'9702' => 'openbullet',			# U=25E6, N=9702
	'9733' => 'a35',			# U=2605, N=9733
	'9742' => 'a4',				# U=260E, N=9742
	'9755' => 'a11',			# U=261B, N=9755
	'9758' => 'a12',			# U=261E, N=9758
	'9786' => 'smileface',			# U=263A, N=9786
	'9787' => 'invsmileface',		# U=263B, N=9787
	'9788' => 'sun',			# U=263C, N=9788
	'9792' => 'female',			# U=2640, N=9792
	'9794' => 'male',			# U=2642, N=9794
	'9824' => 'spade',			# U=2660, N=9824
	'9827' => 'club',			# U=2663, N=9827
	'9829' => 'heart',			# U=2665, N=9829
	'9830' => 'diamond',			# U=2666, N=9830
	'9834' => 'musicalnote',		# U=266A, N=9834
	'9835' => 'musicalnotedbl',		# U=266B, N=9835
	'9985' => 'a1',				# U=2701, N=9985
	'9986' => 'a2',				# U=2702, N=9986
	'9987' => 'a202',			# U=2703, N=9987
	'9988' => 'a3',				# U=2704, N=9988
	'9990' => 'a5',				# U=2706, N=9990
	'9991' => 'a119',			# U=2707, N=9991
	'9992' => 'a118',			# U=2708, N=9992
	'9993' => 'a117',			# U=2709, N=9993
	'9996' => 'a13',			# U=270C, N=9996
	'9997' => 'a14',			# U=270D, N=9997
	'9998' => 'a15',			# U=270E, N=9998
	'9999' => 'a16',			# U=270F, N=9999
	'10000' => 'a105',			# U=2710, N=10000
	'10001' => 'a17',			# U=2711, N=10001
	'10002' => 'a18',			# U=2712, N=10002
	'10003' => 'a19',			# U=2713, N=10003
	'10004' => 'a20',			# U=2714, N=10004
	'10005' => 'a21',			# U=2715, N=10005
	'10006' => 'a22',			# U=2716, N=10006
	'10007' => 'a23',			# U=2717, N=10007
	'10008' => 'a24',			# U=2718, N=10008
	'10009' => 'a25',			# U=2719, N=10009
	'10010' => 'a26',			# U=271A, N=10010
	'10011' => 'a27',			# U=271B, N=10011
	'10012' => 'a28',			# U=271C, N=10012
	'10013' => 'a6',			# U=271D, N=10013
	'10014' => 'a7',			# U=271E, N=10014
	'10015' => 'a8',			# U=271F, N=10015
	'10016' => 'a9',			# U=2720, N=10016
	'10017' => 'a10',			# U=2721, N=10017
	'10018' => 'a29',			# U=2722, N=10018
	'10019' => 'a30',			# U=2723, N=10019
	'10020' => 'a31',			# U=2724, N=10020
	'10021' => 'a32',			# U=2725, N=10021
	'10022' => 'a33',			# U=2726, N=10022
	'10023' => 'a34',			# U=2727, N=10023
	'10025' => 'a36',			# U=2729, N=10025
	'10026' => 'a37',			# U=272A, N=10026
	'10027' => 'a38',			# U=272B, N=10027
	'10028' => 'a39',			# U=272C, N=10028
	'10029' => 'a40',			# U=272D, N=10029
	'10030' => 'a41',			# U=272E, N=10030
	'10031' => 'a42',			# U=272F, N=10031
	'10032' => 'a43',			# U=2730, N=10032
	'10033' => 'a44',			# U=2731, N=10033
	'10034' => 'a45',			# U=2732, N=10034
	'10035' => 'a46',			# U=2733, N=10035
	'10036' => 'a47',			# U=2734, N=10036
	'10037' => 'a48',			# U=2735, N=10037
	'10038' => 'a49',			# U=2736, N=10038
	'10039' => 'a50',			# U=2737, N=10039
	'10040' => 'a51',			# U=2738, N=10040
	'10041' => 'a52',			# U=2739, N=10041
	'10042' => 'a53',			# U=273A, N=10042
	'10043' => 'a54',			# U=273B, N=10043
	'10044' => 'a55',			# U=273C, N=10044
	'10045' => 'a56',			# U=273D, N=10045
	'10046' => 'a57',			# U=273E, N=10046
	'10047' => 'a58',			# U=273F, N=10047
	'10048' => 'a59',			# U=2740, N=10048
	'10049' => 'a60',			# U=2741, N=10049
	'10050' => 'a61',			# U=2742, N=10050
	'10051' => 'a62',			# U=2743, N=10051
	'10052' => 'a63',			# U=2744, N=10052
	'10053' => 'a64',			# U=2745, N=10053
	'10054' => 'a65',			# U=2746, N=10054
	'10055' => 'a66',			# U=2747, N=10055
	'10056' => 'a67',			# U=2748, N=10056
	'10057' => 'a68',			# U=2749, N=10057
	'10058' => 'a69',			# U=274A, N=10058
	'10059' => 'a70',			# U=274B, N=10059
	'10061' => 'a72',			# U=274D, N=10061
	'10063' => 'a74',			# U=274F, N=10063
	'10064' => 'a203',			# U=2750, N=10064
	'10065' => 'a75',			# U=2751, N=10065
	'10066' => 'a204',			# U=2752, N=10066
	'10070' => 'a79',			# U=2756, N=10070
	'10072' => 'a82',			# U=2758, N=10072
	'10073' => 'a83',			# U=2759, N=10073
	'10074' => 'a84',			# U=275A, N=10074
	'10075' => 'a97',			# U=275B, N=10075
	'10076' => 'a98',			# U=275C, N=10076
	'10077' => 'a99',			# U=275D, N=10077
	'10078' => 'a100',			# U=275E, N=10078
	'10081' => 'a101',			# U=2761, N=10081
	'10082' => 'a102',			# U=2762, N=10082
	'10083' => 'a103',			# U=2763, N=10083
	'10084' => 'a104',			# U=2764, N=10084
	'10085' => 'a106',			# U=2765, N=10085
	'10086' => 'a107',			# U=2766, N=10086
	'10087' => 'a108',			# U=2767, N=10087
	'10102' => 'a130',			# U=2776, N=10102
	'10103' => 'a131',			# U=2777, N=10103
	'10104' => 'a132',			# U=2778, N=10104
	'10105' => 'a133',			# U=2779, N=10105
	'10106' => 'a134',			# U=277A, N=10106
	'10107' => 'a135',			# U=277B, N=10107
	'10108' => 'a136',			# U=277C, N=10108
	'10109' => 'a137',			# U=277D, N=10109
	'10110' => 'a138',			# U=277E, N=10110
	'10111' => 'a139',			# U=277F, N=10111
	'10112' => 'a140',			# U=2780, N=10112
	'10113' => 'a141',			# U=2781, N=10113
	'10114' => 'a142',			# U=2782, N=10114
	'10115' => 'a143',			# U=2783, N=10115
	'10116' => 'a144',			# U=2784, N=10116
	'10117' => 'a145',			# U=2785, N=10117
	'10118' => 'a146',			# U=2786, N=10118
	'10119' => 'a147',			# U=2787, N=10119
	'10120' => 'a148',			# U=2788, N=10120
	'10121' => 'a149',			# U=2789, N=10121
	'10122' => 'a150',			# U=278A, N=10122
	'10123' => 'a151',			# U=278B, N=10123
	'10124' => 'a152',			# U=278C, N=10124
	'10125' => 'a153',			# U=278D, N=10125
	'10126' => 'a154',			# U=278E, N=10126
	'10127' => 'a155',			# U=278F, N=10127
	'10128' => 'a156',			# U=2790, N=10128
	'10129' => 'a157',			# U=2791, N=10129
	'10130' => 'a158',			# U=2792, N=10130
	'10131' => 'a159',			# U=2793, N=10131
	'10132' => 'a160',			# U=2794, N=10132
	'10136' => 'a196',			# U=2798, N=10136
	'10137' => 'a165',			# U=2799, N=10137
	'10138' => 'a192',			# U=279A, N=10138
	'10139' => 'a166',			# U=279B, N=10139
	'10140' => 'a167',			# U=279C, N=10140
	'10141' => 'a168',			# U=279D, N=10141
	'10142' => 'a169',			# U=279E, N=10142
	'10143' => 'a170',			# U=279F, N=10143
	'10144' => 'a171',			# U=27A0, N=10144
	'10145' => 'a172',			# U=27A1, N=10145
	'10146' => 'a173',			# U=27A2, N=10146
	'10147' => 'a162',			# U=27A3, N=10147
	'10148' => 'a174',			# U=27A4, N=10148
	'10149' => 'a175',			# U=27A5, N=10149
	'10150' => 'a176',			# U=27A6, N=10150
	'10151' => 'a177',			# U=27A7, N=10151
	'10152' => 'a178',			# U=27A8, N=10152
	'10153' => 'a179',			# U=27A9, N=10153
	'10154' => 'a193',			# U=27AA, N=10154
	'10155' => 'a180',			# U=27AB, N=10155
	'10156' => 'a199',			# U=27AC, N=10156
	'10157' => 'a181',			# U=27AD, N=10157
	'10158' => 'a200',			# U=27AE, N=10158
	'10159' => 'a182',			# U=27AF, N=10159
	'10161' => 'a201',			# U=27B1, N=10161
	'10162' => 'a183',			# U=27B2, N=10162
	'10163' => 'a184',			# U=27B3, N=10163
	'10164' => 'a197',			# U=27B4, N=10164
	'10165' => 'a185',			# U=27B5, N=10165
	'10166' => 'a194',			# U=27B6, N=10166
	'10167' => 'a198',			# U=27B7, N=10167
	'10168' => 'a186',			# U=27B8, N=10168
	'10169' => 'a195',			# U=27B9, N=10169
	'10170' => 'a187',			# U=27BA, N=10170
	'10171' => 'a188',			# U=27BB, N=10171
	'10172' => 'a189',			# U=27BC, N=10172
	'10173' => 'a190',			# U=27BD, N=10173
	'10174' => 'a191',			# U=27BE, N=10174
	'61441' => 'fi',			# U=F001, N=61441
	'61442' => 'fl',			# U=F002, N=61442
	'61472' => 'space',			# U=F020, N=61472
	'61473' => 'pencil',			# U=F021, N=61473
	'61474' => 'scissors',			# U=F022, N=61474
	'61475' => 'scissorscutting',		# U=F023, N=61475
	'61476' => 'readingglasses',		# U=F024, N=61476
	'61477' => 'bell',			# U=F025, N=61477
	'61478' => 'book',			# U=F026, N=61478
	'61479' => 'candle',			# U=F027, N=61479
	'61480' => 'telephonesolid',		# U=F028, N=61480
	'61481' => 'telhandsetcirc',		# U=F029, N=61481
	'61482' => 'envelopeback',		# U=F02A, N=61482
	'61483' => 'envelopefront',		# U=F02B, N=61483
	'61484' => 'mailboxflagdwn',		# U=F02C, N=61484
	'61485' => 'mailboxflagup',		# U=F02D, N=61485
	'61486' => 'mailbxopnflgup',		# U=F02E, N=61486
	'61487' => 'mailbxopnflgdwn',		# U=F02F, N=61487
	'61488' => 'folder',			# U=F030, N=61488
	'61489' => 'folderopen',		# U=F031, N=61489
	'61490' => 'filetalltext1',		# U=F032, N=61490
	'61491' => 'filetalltext',		# U=F033, N=61491
	'61492' => 'filetalltext3',		# U=F034, N=61492
	'61493' => 'filecabinet',		# U=F035, N=61493
	'61494' => 'hourglass',			# U=F036, N=61494
	'61495' => 'keyboard',			# U=F037, N=61495
	'61496' => 'mouse2button',		# U=F038, N=61496
	'61497' => 'ballpoint',			# U=F039, N=61497
	'61498' => 'pc',			# U=F03A, N=61498
	'61499' => 'harddisk',			# U=F03B, N=61499
	'61500' => 'floppy3',			# U=F03C, N=61500
	'61501' => 'floppy5',			# U=F03D, N=61501
	'61502' => 'tapereel',			# U=F03E, N=61502
	'61503' => 'handwrite',			# U=F03F, N=61503
	'61504' => 'handwriteleft',		# U=F040, N=61504
	'61505' => 'handv',			# U=F041, N=61505
	'61506' => 'handok',			# U=F042, N=61506
	'61507' => 'thumbup',			# U=F043, N=61507
	'61508' => 'thumbdown',			# U=F044, N=61508
	'61509' => 'handptleft',		# U=F045, N=61509
	'61510' => 'handptright',		# U=F046, N=61510
	'61511' => 'handptup',			# U=F047, N=61511
	'61512' => 'handptdwn',			# U=F048, N=61512
	'61513' => 'handhalt',			# U=F049, N=61513
	'61514' => 'smileface',			# U=F04A, N=61514
	'61515' => 'neutralface',		# U=F04B, N=61515
	'61516' => 'frownface',			# U=F04C, N=61516
	'61517' => 'bomb',			# U=F04D, N=61517
	'61518' => 'skullcrossbones',		# U=F04E, N=61518
	'61519' => 'flag',			# U=F04F, N=61519
	'61520' => 'pennant',			# U=F050, N=61520
	'61521' => 'airplane',			# U=F051, N=61521
	'61522' => 'sunshine',			# U=F052, N=61522
	'61523' => 'droplet',			# U=F053, N=61523
	'61524' => 'snowflake',			# U=F054, N=61524
	'61525' => 'crossoutline',		# U=F055, N=61525
	'61526' => 'crossshadow',		# U=F056, N=61526
	'61527' => 'crossceltic',		# U=F057, N=61527
	'61528' => 'crossmaltese',		# U=F058, N=61528
	'61529' => 'starofdavid',		# U=F059, N=61529
	'61530' => 'crescentstar',		# U=F05A, N=61530
	'61531' => 'yinyang',			# U=F05B, N=61531
	'61532' => 'om',			# U=F05C, N=61532
	'61533' => 'wheel',			# U=F05D, N=61533
	'61534' => 'aries',			# U=F05E, N=61534
	'61535' => 'taurus',			# U=F05F, N=61535
	'61536' => 'gemini',			# U=F060, N=61536
	'61537' => 'cancer',			# U=F061, N=61537
	'61538' => 'leo',			# U=F062, N=61538
	'61539' => 'virgo',			# U=F063, N=61539
	'61540' => 'libra',			# U=F064, N=61540
	'61541' => 'scorpio',			# U=F065, N=61541
	'61542' => 'saggitarius',		# U=F066, N=61542
	'61543' => 'capricorn',			# U=F067, N=61543
	'61544' => 'aquarius',			# U=F068, N=61544
	'61545' => 'pisces',			# U=F069, N=61545
	'61546' => 'ampersanditlc',		# U=F06A, N=61546
	'61547' => 'ampersandit',		# U=F06B, N=61547
	'61548' => 'circle6',			# U=F06C, N=61548
	'61549' => 'circleshadowdwn',		# U=F06D, N=61549
	'61550' => 'square6',			# U=F06E, N=61550
	'61551' => 'box3',			# U=F06F, N=61551
	'61552' => 'box4',			# U=F070, N=61552
	'61553' => 'boxshadowdwn',		# U=F071, N=61553
	'61554' => 'boxshadowup',		# U=F072, N=61554
	'61555' => 'lozenge4',			# U=F073, N=61555
	'61556' => 'lozenge6',			# U=F074, N=61556
	'61557' => 'rhombus6',			# U=F075, N=61557
	'61558' => 'xrhombus',			# U=F076, N=61558
	'61559' => 'rhombus4',			# U=F077, N=61559
	'61560' => 'clear',			# U=F078, N=61560
	'61561' => 'escape',			# U=F079, N=61561
	'61562' => 'command',			# U=F07A, N=61562
	'61563' => 'rosette',			# U=F07B, N=61563
	'61564' => 'rosettesolid',		# U=F07C, N=61564
	'61565' => 'quotedbllftbld',		# U=F07D, N=61565
	'61566' => 'quotedblrtbld',		# U=F07E, N=61566
	'61568' => 'zerosans',			# U=F080, N=61568
	'61569' => 'onesans',			# U=F081, N=61569
	'61570' => 'twosans',			# U=F082, N=61570
	'61571' => 'threesans',			# U=F083, N=61571
	'61572' => 'foursans',			# U=F084, N=61572
	'61573' => 'fivesans',			# U=F085, N=61573
	'61574' => 'sixsans',			# U=F086, N=61574
	'61575' => 'sevensans',			# U=F087, N=61575
	'61576' => 'eightsans',			# U=F088, N=61576
	'61577' => 'ninesans',			# U=F089, N=61577
	'61578' => 'tensans',			# U=F08A, N=61578
	'61579' => 'zerosansinv',		# U=F08B, N=61579
	'61580' => 'onesansinv',		# U=F08C, N=61580
	'61581' => 'twosansinv',		# U=F08D, N=61581
	'61582' => 'threesansinv',		# U=F08E, N=61582
	'61583' => 'foursansinv',		# U=F08F, N=61583
	'61584' => 'fivesansinv',		# U=F090, N=61584
	'61585' => 'sixsansinv',		# U=F091, N=61585
	'61586' => 'sevensansinv',		# U=F092, N=61586
	'61587' => 'eightsansinv',		# U=F093, N=61587
	'61588' => 'ninesansinv',		# U=F094, N=61588
	'61589' => 'tensansinv',		# U=F095, N=61589
	'61590' => 'budleafne',			# U=F096, N=61590
	'61591' => 'budleafnw',			# U=F097, N=61591
	'61592' => 'budleafsw',			# U=F098, N=61592
	'61593' => 'budleafse',			# U=F099, N=61593
	'61594' => 'vineleafboldne',		# U=F09A, N=61594
	'61595' => 'vineleafboldnw',		# U=F09B, N=61595
	'61596' => 'vineleafboldsw',		# U=F09C, N=61596
	'61597' => 'vineleafboldse',		# U=F09D, N=61597
	'61598' => 'circle2',			# U=F09E, N=61598
	'61599' => 'circle4',			# U=F09F, N=61599
	'61600' => 'square2',			# U=F0A0, N=61600
	'61601' => 'ring2',			# U=F0A1, N=61601
	'61602' => 'ring4',			# U=F0A2, N=61602
	'61603' => 'ring6',			# U=F0A3, N=61603
	'61604' => 'ringbutton2',		# U=F0A4, N=61604
	'61605' => 'target',			# U=F0A5, N=61605
	'61606' => 'circleshadowup',		# U=F0A6, N=61606
	'61607' => 'square4',			# U=F0A7, N=61607
	'61608' => 'box2',			# U=F0A8, N=61608
	'61609' => 'tristar2',			# U=F0A9, N=61609
	'61610' => 'crosstar2',			# U=F0AA, N=61610
	'61611' => 'pentastar2',		# U=F0AB, N=61611
	'61612' => 'hexstar2',			# U=F0AC, N=61612
	'61613' => 'octastar2',			# U=F0AD, N=61613
	'61614' => 'dodecastar3',		# U=F0AE, N=61614
	'61615' => 'octastar4',			# U=F0AF, N=61615
	'61616' => 'registersquare',		# U=F0B0, N=61616
	'61617' => 'registercircle',		# U=F0B1, N=61617
	'61618' => 'cuspopen',			# U=F0B2, N=61618
	'61619' => 'cuspopen1',			# U=F0B3, N=61619
	'61620' => 'query',			# U=F0B4, N=61620
	'61621' => 'circlestar',		# U=F0B5, N=61621
	'61622' => 'starshadow',		# U=F0B6, N=61622
	'61623' => 'oneoclock',			# U=F0B7, N=61623
	'61624' => 'twooclock',			# U=F0B8, N=61624
	'61625' => 'threeoclock',		# U=F0B9, N=61625
	'61626' => 'fouroclock',		# U=F0BA, N=61626
	'61627' => 'fiveoclock',		# U=F0BB, N=61627
	'61628' => 'sixoclock',			# U=F0BC, N=61628
	'61629' => 'sevenoclock',		# U=F0BD, N=61629
	'61630' => 'eightoclock',		# U=F0BE, N=61630
	'61631' => 'nineoclock',		# U=F0BF, N=61631
	'61632' => 'tenoclock',			# U=F0C0, N=61632
	'61633' => 'elevenoclock',		# U=F0C1, N=61633
	'61634' => 'twelveoclock',		# U=F0C2, N=61634
	'61635' => 'arrowdwnleft1',		# U=F0C3, N=61635
	'61636' => 'arrowdwnrt1',		# U=F0C4, N=61636
	'61637' => 'arrowupleft1',		# U=F0C5, N=61637
	'61638' => 'arrowuprt1',		# U=F0C6, N=61638
	'61639' => 'arrowleftup1',		# U=F0C7, N=61639
	'61640' => 'arrowrtup1',		# U=F0C8, N=61640
	'61641' => 'arrowleftdwn1',		# U=F0C9, N=61641
	'61642' => 'arrowrtdwn1',		# U=F0CA, N=61642
	'61643' => 'quiltsquare2',		# U=F0CB, N=61643
	'61644' => 'quiltsquare2inv',		# U=F0CC, N=61644
	'61645' => 'leafccwsw',			# U=F0CD, N=61645
	'61646' => 'leafccwnw',			# U=F0CE, N=61646
	'61647' => 'leafccwse',			# U=F0CF, N=61647
	'61648' => 'leafccwne',			# U=F0D0, N=61648
	'61649' => 'leafnw',			# U=F0D1, N=61649
	'61650' => 'leafsw',			# U=F0D2, N=61650
	'61651' => 'leafne',			# U=F0D3, N=61651
	'61652' => 'leafse',			# U=F0D4, N=61652
	'61653' => 'deleteleft',		# U=F0D5, N=61653
	'61654' => 'deleteright',		# U=F0D6, N=61654
	'61655' => 'head2left',			# U=F0D7, N=61655
	'61656' => 'head2right',		# U=F0D8, N=61656
	'61657' => 'head2up',			# U=F0D9, N=61657
	'61658' => 'head2down',			# U=F0DA, N=61658
	'61659' => 'circleleft',		# U=F0DB, N=61659
	'61660' => 'circleright',		# U=F0DC, N=61660
	'61661' => 'circleup',			# U=F0DD, N=61661
	'61662' => 'circledown',		# U=F0DE, N=61662
	'61663' => 'barb2left',			# U=F0DF, N=61663
	'61664' => 'barb2right',		# U=F0E0, N=61664
	'61665' => 'barb2up',			# U=F0E1, N=61665
	'61666' => 'barb2down',			# U=F0E2, N=61666
	'61667' => 'barb2nw',			# U=F0E3, N=61667
	'61668' => 'barb2ne',			# U=F0E4, N=61668
	'61669' => 'barb2sw',			# U=F0E5, N=61669
	'61670' => 'barb2se',			# U=F0E6, N=61670
	'61671' => 'barb4left',			# U=F0E7, N=61671
	'61672' => 'barb4right',		# U=F0E8, N=61672
	'61673' => 'barb4up',			# U=F0E9, N=61673
	'61674' => 'barb4down',			# U=F0EA, N=61674
	'61675' => 'barb4nw',			# U=F0EB, N=61675
	'61676' => 'barb4ne',			# U=F0EC, N=61676
	'61677' => 'barb4sw',			# U=F0ED, N=61677
	'61678' => 'barb4se',			# U=F0EE, N=61678
	'61679' => 'bleft',			# U=F0EF, N=61679
	'61680' => 'bright',			# U=F0F0, N=61680
	'61681' => 'bup',			# U=F0F1, N=61681
	'61682' => 'bdown',			# U=F0F2, N=61682
	'61683' => 'bleftright',		# U=F0F3, N=61683
	'61684' => 'bupdown',			# U=F0F4, N=61684
	'61685' => 'bnw',			# U=F0F5, N=61685
	'61686' => 'bne',			# U=F0F6, N=61686
	'61687' => 'bsw',			# U=F0F7, N=61687
	'61688' => 'bse',			# U=F0F8, N=61688
	'61689' => 'bdash1',			# U=F0F9, N=61689
	'61690' => 'bdash2',			# U=F0FA, N=61690
	'61691' => 'xmarkbld',			# U=F0FB, N=61691
	'61692' => 'checkbld',			# U=F0FC, N=61692
	'61693' => 'boxxmarkbld',		# U=F0FD, N=61693
	'61694' => 'boxcheckbld',		# U=F0FE, N=61694
	'61695' => 'windowslogo',		# U=F0FF, N=61695
	'63166' => 'dotlessj',			# U=F6BE, N=63166
	'63167' => 'LL',			# U=F6BF, N=63167
	'63168' => 'll',			# U=F6C0, N=63168
	'63169' => 'Scedilla',			# U=F6C1, N=63169
	'63170' => 'scedilla',			# U=F6C2, N=63170
	'63171' => 'commaaccent',		# U=F6C3, N=63171
	'63172' => 'afii10063',			# U=F6C4, N=63172
	'63173' => 'afii10064',			# U=F6C5, N=63173
	'63174' => 'afii10192',			# U=F6C6, N=63174
	'63175' => 'afii10831',			# U=F6C7, N=63175
	'63176' => 'afii10832',			# U=F6C8, N=63176
	'63177' => 'Acute',			# U=F6C9, N=63177
	'63178' => 'Caron',			# U=F6CA, N=63178
	'63179' => 'Dieresis',			# U=F6CB, N=63179
	'63180' => 'DieresisAcute',		# U=F6CC, N=63180
	'63181' => 'DieresisGrave',		# U=F6CD, N=63181
	'63182' => 'Grave',			# U=F6CE, N=63182
	'63183' => 'Hungarumlaut',		# U=F6CF, N=63183
	'63184' => 'Macron',			# U=F6D0, N=63184
	'63185' => 'cyrBreve',			# U=F6D1, N=63185
	'63186' => 'cyrFlex',			# U=F6D2, N=63186
	'63187' => 'dblGrave',			# U=F6D3, N=63187
	'63188' => 'cyrbreve',			# U=F6D4, N=63188
	'63189' => 'cyrflex',			# U=F6D5, N=63189
	'63190' => 'dblgrave',			# U=F6D6, N=63190
	'63191' => 'dieresisacute',		# U=F6D7, N=63191
	'63192' => 'dieresisgrave',		# U=F6D8, N=63192
	'63193' => 'copyrightserif',		# U=F6D9, N=63193
	'63194' => 'registerserif',		# U=F6DA, N=63194
	'63195' => 'trademarkserif',		# U=F6DB, N=63195
	'63196' => 'onefitted',			# U=F6DC, N=63196
	'63197' => 'rupiah',			# U=F6DD, N=63197
	'63198' => 'threequartersemdash',	# U=F6DE, N=63198
	'63199' => 'centinferior',		# U=F6DF, N=63199
	'63200' => 'centsuperior',		# U=F6E0, N=63200
	'63201' => 'commainferior',		# U=F6E1, N=63201
	'63202' => 'commasuperior',		# U=F6E2, N=63202
	'63203' => 'dollarinferior',		# U=F6E3, N=63203
	'63204' => 'dollarsuperior',		# U=F6E4, N=63204
	'63205' => 'hypheninferior',		# U=F6E5, N=63205
	'63206' => 'hyphensuperior',		# U=F6E6, N=63206
	'63207' => 'periodinferior',		# U=F6E7, N=63207
	'63208' => 'periodsuperior',		# U=F6E8, N=63208
	'63209' => 'asuperior',			# U=F6E9, N=63209
	'63210' => 'bsuperior',			# U=F6EA, N=63210
	'63211' => 'dsuperior',			# U=F6EB, N=63211
	'63212' => 'esuperior',			# U=F6EC, N=63212
	'63213' => 'isuperior',			# U=F6ED, N=63213
	'63214' => 'lsuperior',			# U=F6EE, N=63214
	'63215' => 'msuperior',			# U=F6EF, N=63215
	'63216' => 'osuperior',			# U=F6F0, N=63216
	'63217' => 'rsuperior',			# U=F6F1, N=63217
	'63218' => 'ssuperior',			# U=F6F2, N=63218
	'63219' => 'tsuperior',			# U=F6F3, N=63219
	'63220' => 'Brevesmall',		# U=F6F4, N=63220
	'63221' => 'Caronsmall',		# U=F6F5, N=63221
	'63222' => 'Circumflexsmall',		# U=F6F6, N=63222
	'63223' => 'Dotaccentsmall',		# U=F6F7, N=63223
	'63224' => 'Hungarumlautsmall',		# U=F6F8, N=63224
	'63225' => 'Lslashsmall',		# U=F6F9, N=63225
	'63226' => 'OEsmall',			# U=F6FA, N=63226
	'63227' => 'Ogoneksmall',		# U=F6FB, N=63227
	'63228' => 'Ringsmall',			# U=F6FC, N=63228
	'63229' => 'Scaronsmall',		# U=F6FD, N=63229
	'63230' => 'Tildesmall',		# U=F6FE, N=63230
	'63231' => 'Zcaronsmall',		# U=F6FF, N=63231
	'63265' => 'exclamsmall',		# U=F721, N=63265
	'63268' => 'dollaroldstyle',		# U=F724, N=63268
	'63270' => 'ampersandsmall',		# U=F726, N=63270
	'63280' => 'zerooldstyle',		# U=F730, N=63280
	'63281' => 'oneoldstyle',		# U=F731, N=63281
	'63282' => 'twooldstyle',		# U=F732, N=63282
	'63283' => 'threeoldstyle',		# U=F733, N=63283
	'63284' => 'fouroldstyle',		# U=F734, N=63284
	'63285' => 'fiveoldstyle',		# U=F735, N=63285
	'63286' => 'sixoldstyle',		# U=F736, N=63286
	'63287' => 'sevenoldstyle',		# U=F737, N=63287
	'63288' => 'eightoldstyle',		# U=F738, N=63288
	'63289' => 'nineoldstyle',		# U=F739, N=63289
	'63295' => 'questionsmall',		# U=F73F, N=63295
	'63328' => 'Gravesmall',		# U=F760, N=63328
	'63329' => 'Asmall',			# U=F761, N=63329
	'63330' => 'Bsmall',			# U=F762, N=63330
	'63331' => 'Csmall',			# U=F763, N=63331
	'63332' => 'Dsmall',			# U=F764, N=63332
	'63333' => 'Esmall',			# U=F765, N=63333
	'63334' => 'Fsmall',			# U=F766, N=63334
	'63335' => 'Gsmall',			# U=F767, N=63335
	'63336' => 'Hsmall',			# U=F768, N=63336
	'63337' => 'Ismall',			# U=F769, N=63337
	'63338' => 'Jsmall',			# U=F76A, N=63338
	'63339' => 'Ksmall',			# U=F76B, N=63339
	'63340' => 'Lsmall',			# U=F76C, N=63340
	'63341' => 'Msmall',			# U=F76D, N=63341
	'63342' => 'Nsmall',			# U=F76E, N=63342
	'63343' => 'Osmall',			# U=F76F, N=63343
	'63344' => 'Psmall',			# U=F770, N=63344
	'63345' => 'Qsmall',			# U=F771, N=63345
	'63346' => 'Rsmall',			# U=F772, N=63346
	'63347' => 'Ssmall',			# U=F773, N=63347
	'63348' => 'Tsmall',			# U=F774, N=63348
	'63349' => 'Usmall',			# U=F775, N=63349
	'63350' => 'Vsmall',			# U=F776, N=63350
	'63351' => 'Wsmall',			# U=F777, N=63351
	'63352' => 'Xsmall',			# U=F778, N=63352
	'63353' => 'Ysmall',			# U=F779, N=63353
	'63354' => 'Zsmall',			# U=F77A, N=63354
	'63393' => 'exclamdownsmall',		# U=F7A1, N=63393
	'63394' => 'centoldstyle',		# U=F7A2, N=63394
	'63400' => 'Dieresissmall',		# U=F7A8, N=63400
	'63407' => 'Macronsmall',		# U=F7AF, N=63407
	'63412' => 'Acutesmall',		# U=F7B4, N=63412
	'63416' => 'Cedillasmall',		# U=F7B8, N=63416
	'63423' => 'questiondownsmall',		# U=F7BF, N=63423
	'63456' => 'Agravesmall',		# U=F7E0, N=63456
	'63457' => 'Aacutesmall',		# U=F7E1, N=63457
	'63458' => 'Acircumflexsmall',		# U=F7E2, N=63458
	'63459' => 'Atildesmall',		# U=F7E3, N=63459
	'63460' => 'Adieresissmall',		# U=F7E4, N=63460
	'63461' => 'Aringsmall',		# U=F7E5, N=63461
	'63462' => 'AEsmall',			# U=F7E6, N=63462
	'63463' => 'Ccedillasmall',		# U=F7E7, N=63463
	'63464' => 'Egravesmall',		# U=F7E8, N=63464
	'63465' => 'Eacutesmall',		# U=F7E9, N=63465
	'63466' => 'Ecircumflexsmall',		# U=F7EA, N=63466
	'63467' => 'Edieresissmall',		# U=F7EB, N=63467
	'63468' => 'Igravesmall',		# U=F7EC, N=63468
	'63469' => 'Iacutesmall',		# U=F7ED, N=63469
	'63470' => 'Icircumflexsmall',		# U=F7EE, N=63470
	'63471' => 'Idieresissmall',		# U=F7EF, N=63471
	'63472' => 'Ethsmall',			# U=F7F0, N=63472
	'63473' => 'Ntildesmall',		# U=F7F1, N=63473
	'63474' => 'Ogravesmall',		# U=F7F2, N=63474
	'63475' => 'Oacutesmall',		# U=F7F3, N=63475
	'63476' => 'Ocircumflexsmall',		# U=F7F4, N=63476
	'63477' => 'Otildesmall',		# U=F7F5, N=63477
	'63478' => 'Odieresissmall',		# U=F7F6, N=63478
	'63480' => 'Oslashsmall',		# U=F7F8, N=63480
	'63481' => 'Ugravesmall',		# U=F7F9, N=63481
	'63482' => 'Uacutesmall',		# U=F7FA, N=63482
	'63483' => 'Ucircumflexsmall',		# U=F7FB, N=63483
	'63484' => 'Udieresissmall',		# U=F7FC, N=63484
	'63485' => 'Yacutesmall',		# U=F7FD, N=63485
	'63486' => 'Thornsmall',		# U=F7FE, N=63486
	'63487' => 'Ydieresissmall',		# U=F7FF, N=63487
	'63703' => 'a89',			# U=F8D7, N=63703
	'63704' => 'a90',			# U=F8D8, N=63704
	'63705' => 'a93',			# U=F8D9, N=63705
	'63706' => 'a94',			# U=F8DA, N=63706
	'63707' => 'a91',			# U=F8DB, N=63707
	'63708' => 'a92',			# U=F8DC, N=63708
	'63709' => 'a205',			# U=F8DD, N=63709
	'63710' => 'a85',			# U=F8DE, N=63710
	'63711' => 'a206',			# U=F8DF, N=63711
	'63712' => 'a86',			# U=F8E0, N=63712
	'63713' => 'a87',			# U=F8E1, N=63713
	'63714' => 'a88',			# U=F8E2, N=63714
	'63715' => 'a95',			# U=F8E3, N=63715
	'63716' => 'a96',			# U=F8E4, N=63716
	'63717' => 'radicalex',			# U=F8E5, N=63717
	'63718' => 'arrowvertex',		# U=F8E6, N=63718
	'63719' => 'arrowhorizex',		# U=F8E7, N=63719
	'63720' => 'registersans',		# U=F8E8, N=63720
	'63721' => 'copyrightsans',		# U=F8E9, N=63721
	'63722' => 'trademarksans',		# U=F8EA, N=63722
	'63723' => 'parenlefttp',		# U=F8EB, N=63723
	'63724' => 'parenleftex',		# U=F8EC, N=63724
	'63725' => 'parenleftbt',		# U=F8ED, N=63725
	'63726' => 'bracketlefttp',		# U=F8EE, N=63726
	'63727' => 'bracketleftex',		# U=F8EF, N=63727
	'63728' => 'bracketleftbt',		# U=F8F0, N=63728
	'63729' => 'bracelefttp',		# U=F8F1, N=63729
	'63730' => 'braceleftmid',		# U=F8F2, N=63730
	'63731' => 'braceleftbt',		# U=F8F3, N=63731
	'63732' => 'braceex',			# U=F8F4, N=63732
	'63733' => 'integralex',		# U=F8F5, N=63733
	'63734' => 'parenrighttp',		# U=F8F6, N=63734
	'63735' => 'parenrightex',		# U=F8F7, N=63735
	'63736' => 'parenrightbt',		# U=F8F8, N=63736
	'63737' => 'bracketrighttp',		# U=F8F9, N=63737
	'63738' => 'bracketrightex',		# U=F8FA, N=63738
	'63739' => 'bracketrightbt',		# U=F8FB, N=63739
	'63740' => 'bracerighttp',		# U=F8FC, N=63740
	'63741' => 'bracerightmid',		# U=F8FD, N=63741
	'63742' => 'bracerightbt',		# U=F8FE, N=63742
	'64256' => 'ff',			# U=FB00, N=64256
	'64257' => 'fi',			# U=FB01, N=64257
	'64258' => 'fl',			# U=FB02, N=64258
	'64259' => 'ffi',			# U=FB03, N=64259
	'64260' => 'ffl',			# U=FB04, N=64260
	'64287' => 'afii57705',			# U=FB1F, N=64287
	'64298' => 'afii57694',			# U=FB2A, N=64298
	'64299' => 'afii57695',			# U=FB2B, N=64299
	'64309' => 'afii57723',			# U=FB35, N=64309
	'64331' => 'afii57700',			# U=FB4B, N=64331
);

sub new {
	my ($class,$pdf,$file,@opts) = @_;
	my $self;
	my %opts=();
	die "cannot find font '$file' ..." unless(-f $file);
	my $font=PDF::API2::TTF::Font->open($file);
	## die "Opentype font '$file' not supported -- exiting." if($font->{'CFF '});
	%opts=@opts if((scalar @opts)%2 == 0);
	$class = ref $class if ref $class;
	$self=$class->SUPER::new();

	$pdf->new_obj($self) unless($opts{-nonembed});
	$self->{Filter}=PDFArray(PDFName('FlateDecode'));
	$self->{' font'}=$font;
	$self->{' data'}={};

	$self->{Subtype}=PDFName('Type1C') if($self->iscff);

	$self->data->{fontname}=$self->font->{'name'}->read->find_name(4);
	$self->data->{fontname}=~s/\s//og;
	$self->data->{altname}=$self->font->{'name'}->find_name(1);
	$self->data->{altname}=~s/\s//og;
	$self->data->{subname}=$self->font->{'name'}->find_name(2);
	$self->data->{subname}=~s/\s//og;

  if(defined($self->mstable)) {
  	$self->data->{issymbol} = ($self->mstable->{'Platform'} == 3 && $self->mstable->{'Encoding'} == 0) || 0;
  } else {
  	$self->data->{issymbol} = 0;
  }

	$self->data->{upem}=$self->font->{'head'}->read->{'unitsPerEm'};

	$self->data->{fontbbox}=[
		int($self->font->{'head'}->{'xMin'} * 1000 / $self->upem),
        	int($self->font->{'head'}->{'yMin'} * 1000 / $self->upem),
        	int($self->font->{'head'}->{'xMax'} * 1000 / $self->upem),
        	int($self->font->{'head'}->{'yMax'} * 1000 / $self->upem)
        ];

	$self->data->{stemv}=0;
	$self->data->{stemh}=0;
	
	$self->data->{missingwidth}=int($self->font->{'hhea'}->read->{'advanceWidthMax'} * 1000 / $self->upem) + 2;
	$self->data->{maxwidth}=int($self->font->{'hhea'}->{'advanceWidthMax'} * 1000 / $self->upem);
	$self->data->{ascender}=int($self->font->{'hhea'}->read->{'Ascender'} * 1000 / $self->upem);
	$self->data->{descender}=int($self->font->{'hhea'}{'Descender'} * 1000 / $self->upem);

	$self->data->{flags} = 0;
	$self->data->{flags} |= 1 if ($self->font->{'OS/2'}->read->{'bProportion'} == 9);
	$self->data->{flags} |= 2 unless ($self->font->{'OS/2'}{'bSerifStyle'} > 10 && $self->font->{'OS/2'}{'bSerifStyle'} < 14);
	$self->data->{flags} |= 8 if ($self->font->{'OS/2'}{'bFamilyType'} == 2);
	$self->data->{flags} |= 32; # if ($self->font->{'OS/2'}{'bFamilyType'} > 3);
	$self->data->{flags} |= 64 if ($self->font->{'OS/2'}{'bLetterform'} > 8);;

	$self->data->{capheight}=$self->font->{'OS/2'}->{CapHeight}
		|| $self->bbxn('H')->[3]
		|| int($self->fontbbox->[3]*0.8);
	$self->data->{xheight}=$self->font->{'OS/2'}->{xHeight}
		|| $self->bbxn('x')->[3]
		|| int($self->fontbbox->[3]*0.4);

	if($self->issymbol) {
		$self->data->{eu}=[0xf000 .. 0xf0ff];
	} else {
		$self->data->{eu}=[
			0 .. 127,
			0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
			0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F,
			0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
			0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178,
			0xA0 .. 0xFF
		];
	}
	if(($self->font->{'post'}->read->{FormatType} == 3) && defined($self->mstable)) {
		$self->data->{ng} = {};
		$self->data->{gn} = [];
		foreach my $u (sort {$a<=>$b} keys %{$self->mstable->{val}}) {
			my $n=$u2n{$u} || sprintf('uni%04X',$u);
			$self->data->{ng}->{$n}=$self->mstable->{val}->{$u};
			$self->data->{gn}->[$self->mstable->{val}->{$u}]=$n;
		}
	}
	$self->data->{italicangle}=$self->font->{'post'}->{italicAngle};
	$self->data->{isfixedpitch}=$self->font->{'post'}->{isFixedPitch};
	$self->data->{underlineposition}=$self->font->{'post'}->{underlinePosition};
	$self->data->{underlinethickness}=$self->font->{'post'}->{underlineThickness};

	$self->data->{char}=[];
	if($opts{-encode} && (lc($opts{-encode}) ne 'latin1') && !$self->issymbol) {
		my $uniMap = PDF::API2::UniMap->new($opts{-encode});
		@{$self->{' data'}->{char}}=( $uniMap->glyphs() );
		foreach my $c (0..255) {
			$self->data->{eu}->[$c]=$uniMap->c2u($c);
		}
	} else {
		foreach my $c (0..255) {
			$self->data->{char}->[$c]=$self->glyph2name($self->enc2glyph($c));
		}
	}

	$self->data->{ug} ||= {};
	if($self->issymbol) {
		map { $self->data->{ug}->{$_ & 0xff} = $self->font->{'cmap'}->read->ms_lookup($_) } (0xf000 .. 0xf0ff);
#	} else {
#		map { 
#			$self->data->{ug}->{$_} = $self->enc2glyph($_ & 0xff); 
#			$self->data->{ug}->{$_ & 0xff} = $self->enc2glyph($_ & 0xff); 
#		} (0xf000 .. 0xf0ff);
	}
	return($self);
}

sub font { return( $_[0]->{' font'} ); }

sub data { return( $_[0]->{' data'} ); }

sub wxg {
	my $self=shift @_;
	my $g=shift @_;
	my $w;

	if(defined $self->font->{'hmtx'}->read->{'advance'}[$g]) {
		$w = int($self->font->{'hmtx'}->{'advance'}[$g]*1000/$self->upem);
	} else {
		$w = $self->missingwidth;
	}
	
	return($w);
}

sub wxn {
	my $self=shift @_;
	my $n=shift @_;
	my $g=$self->name2glyph($n);
	return($self->wxg($g));
}

sub wxu {
	my $self=shift @_;
	my $u=shift @_;
	my $g=$self->uni2glyph($u);
	return($self->wxg($g));
}

sub wxe {
	my $self=shift @_;
	my $e=shift @_;
	my $g=$self->enc2glyph($e);
	return($self->wxg($g));
}

sub wx {
	my ($self,$text,%opts)=@_;
	my $w=0;
	
	if($opts{-utf8}) {
		map { $w+=$self->wxu($_) } unpack('U*',$text);
	} elsif($opts{-ucs2}) {
		map { $w+=$self->wxu($_) } unpack('n*',$text);
	} elsif($opts{-cid}) {
		map { $w+=$self->wxg($_) } unpack('n*',$text);
	} else {
		map { $w+=$self->wxe($_) } unpack('C*',$text);
	}
	return($w);
}

sub bbxg {
	my $self=shift @_;
	my $g=shift @_;
	my @b;
	return([0,0,0,0]) if($self->iscff);

	my $l=$self->font->{'loca'}->read;

	if($l->{'glyphs'}[$g]) {
		my $m = $l->{'glyphs'}[$g]->read;
		@b=(
			int($m->{'xMin'} * 1000 / $self->upem),
			int($m->{'yMin'} * 1000 / $self->upem),
			int($m->{'xMax'} * 1000 / $self->upem),
			int($m->{'yMax'} * 1000 / $self->upem)
		);
	} else {
		@b = map { $_*0.6 } @{$self->fontbbox};
	}
	
#	if(wantarray) {
#		return(@b);
#	} else {
		return([@b]);
#	}
}

sub bbxn {
	my $self=shift @_;
	my $n=shift @_;
	my $g=$self->name2glyph($n);
	return($self->bbxg($g));
}

sub bbxu {
	my $self=shift @_;
	my $u=shift @_;
	my $g=$self->uni2glyph($u);
	return($self->bbxg($g));
}

sub bbxe {
	my $self=shift @_;
	my $e=shift @_;
	my $g=$self->enc2glyph($e);
	return($self->bbxg($g));
}

sub bbx {
	my ($self,$text,%opts)=@_;
	my @g;
	if($opts{-utf8}) {
		@g=unpack('U*',$text);
	} elsif($opts{-ucs2}) {
		@g=unpack('n*',$text);
	} elsif($opts{-cid}) {
		@g=unpack('n*',$text);
	} else {
		@g=unpack('C*',$text);
	}
	my $l=pop(@g);
	if(scalar @g > 0) {
		my ($llx,$lly,$urx,$ury,$t);

		if($opts{-utf8}) {
			($llx,$lly,$urx,$ury)=$self->bbxu($l);
			($llx,$lly)=$self->bbxu($g[0]);
			$urx+=$self->wx(pack('U*',@g),-utf8=>1);
		} elsif($opts{-ucs2}) {
			($llx,$lly,$urx,$ury)=$self->bbxu($l);
			($llx,$lly)=$self->bbxu($g[0]);
			$urx+=$self->wx(pack('n*',@g),-ucs2=>1);
		} elsif($opts{-cid}) {
			($llx,$lly,$urx,$ury)=$self->bbxg($l);
			($llx,$lly)=$self->bbxg($g[0]);
			$urx+=$self->wx(pack('n*',@g),-cid=>1);
		} else {
			($llx,$lly,$urx,$ury)=$self->bbxe($l);
			($llx,$lly)=$self->bbxe($g[0]);
			$urx+=$self->wx(pack('C*',@g));
		}
		return($llx,$lly,$urx,$ury);
	} else {
		if($opts{-utf8}) {
			return( $self->bbxu($l) );
		} elsif($opts{-ucs2}) {
			return( $self->bbxu($l) );
		} elsif($opts{-cid}) {
			return( $self->bbxg($l) );
		} else {
			return( $self->bbxe($l) );
		}
	}
}

sub glyph2name {
	my $self = shift @_;
	my $g = shift @_;
	$self->data->{gn} ||= [];
	if($self->font->{'post'}->read->{FormatType} == 3) {
		$self->data->{gn}->[$g] ||= '.notdef';
	} else {
		$self->data->{gn}->[$g] ||= $self->font->{'post'}->read->{'VAL'}->[$g] || '.notdef';
	}
	return($self->data->{gn}->[$g]);
}

sub name2glyph {
	my $self = shift @_;
	my $n = shift @_;
	$self->data->{ng} ||= {};
	$self->data->{ng}->{$n} ||= $self->font->{'post'}->read->{'STRINGS'}{$n} || 0;
	return($self->data->{ng}->{$n});
}

sub uni2glyph {
	my $self = shift @_;
	my $u = shift @_;
	$self->data->{ug} ||= {};
	$self->data->{ug}->{$u} ||= $self->font->{'cmap'}->read->ms_lookup($u) || 0;
	return($self->data->{ug}->{$u});
}

sub enc2glyph {
	my $self = shift @_;
	my $e = (shift @_) & 0xff;
	$self->data->{eg} ||= {};
	$self->data->{eg}->{$e} ||= $self->uni2glyph($self->data->{eu}->[$e]) || 0;
	return($self->data->{eg}->{$e});
}

sub fontname { return( $_[0]->data->{fontname} ); }

sub altname { return( $_[0]->data->{altname} ); }

sub subname { return( $_[0]->data->{subname} ); }

sub mstable { return( $_[0]->font->{cmap}->read->find_ms ); }

sub issymbol { return( $_[0]->data->{issymbol} ); }

sub char { return( $_[0]->data->{char} ); }

sub upem { return( $_[0]->data->{upem} ); }

sub fontbbox { return( $_[0]->data->{fontbbox} ); }

sub capheight { return( $_[0]->data->{capheight} ); }

sub xheight { return( $_[0]->data->{xheight} ); }

sub missingwidth { return( $_[0]->data->{missingwidth} ); }

sub maxwidth { return( $_[0]->data->{maxwidth} ); }

sub flags { return( $_[0]->data->{flags} ); }

sub stemv { return( $_[0]->data->{stemv} ); }

sub stemh { return( $_[0]->data->{stemh} ); }

sub italicangle { return( $_[0]->data->{italicangle} ); }

sub isfixedpitch { return( $_[0]->data->{isfixedpitch} ); }

sub underlineposition { return( $_[0]->data->{underlineposition} ); }

sub underlinethickness { return( $_[0]->data->{underlinethickness} ); }

sub ascender { return( $_[0]->data->{ascender} ); }

sub descender { return( $_[0]->data->{descender} ); }

sub iscff { return(defined $_[0]->font->{'CFF '}); }

sub subsetg { 
	my $self = shift @_;
	return if($self->iscff);
	my $g = shift @_;
	$self->{' subset'}=1;
	vec($self->{' subvec'},$g,1)=1; 
	if($self->font->{loca}->read->{glyphs}[$g]) {
		map { vec($self->{' subvec'},$_,1)=1; } $self->font->{loca}->{glyphs}[$g]->get_refs;
	}
}

sub subsete { 
	my $self = shift @_;
	return if($self->iscff);
	my $e = shift @_;
	my $g = $self->enc2glyph($e);
	$self->subsetg($g);
}

sub subsetu { 
	my $self = shift @_;
	return if($self->iscff);
	my $u = shift @_;
	my $g = $self->uni2glyph($u);
	$self->subsetg($g);
}

sub subvec { 
	my $self = shift @_;
	return if($self->iscff);
	my $g = shift @_;
	return(vec($self->{' subvec'},$g,1));
}

sub glyphs { return ( scalar @{$_[0]->font->{'loca'}{'glyphs'}} ); }

sub outobjdeep {
	my ($self, $fh, $pdf, %opts) = @_;

	return $self->SUPER::outobjdeep($fh, $pdf) if defined $opts{'passthru'};

	my $f = $self->font;

	if($self->iscff) {
		$f->{'CFF '}->read_dat;
		$self->{' stream'} = $f->{'CFF '}->{' dat'};
	} else {
		if ($self->{' subset'}) {
			$f->{'glyf'}->read;

			for (my $i = 0; $i < $self->glyphs; $i++) {
				next if($self->subvec($i));
				$f->{'loca'}{'glyphs'}[$i] = undef;
			}
		}

		$self->{' stream'} = "";
		my $ffh = PDF::API2::IOString->new(\$self->{' stream'});
		$f->out($ffh, 'cmap', 'cvt ', 'fpgm', 'glyf', 'head', 'hhea', 'hmtx', 'loca', 'maxp', 'prep');
		$self->{'Length1'}=PDFNum(length($self->{' stream'}));
	}
	
	$self->SUPER::outobjdeep($fh, $pdf, %opts);
}


1;

__END__

=head1 AUTHOR

alfred reibenschuh

=cut

