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
#	PDF::API2::CoreFont
#
#=======================================================================
package PDF::API2::CoreFont;

BEGIN {
	use vars qw( @ISA $fonts $alias $subs @latin1 @macroman @winansi @adobestd $VERSION );
	( $VERSION ) = '$Revisioning: 0.3b40 $' =~ /\$Revisioning:\s+([^\s]+)/;
}

use strict;

use PDF::API2::UniMap;
use PDF::API2::Util;
use PDF::API2::PDF::Utils;
use PDF::API2::PDF::Dict;

@ISA = qw( PDF::API2::PDF::Dict );

=head1 PDF::API2::CoreFont

PDF::API2::CoreFont - a perl-module providing core-font objects for both 
Text::PDF and PDF::API2.

=head2 SYNOPSIS

	use PDF::API2;
	use PDF::API2::CoreFont;
	
	$api = PDF::API2->new;
	...
	$font = PDF::API2::CoreFont->new_api($api,'Helvetica', -encode => 'latin1'); 

OR
	
	use PDF::API2::PDF::File;
	use PDF::API2::CoreFont;
	
	$pdf = PDF::API2::PDF::File->new('some.pdf');
	...
	$font = PDF::API2::CoreFont->new($pdf,'Helvetica', -encode => 'latin1', -pdfname => 'F0'); 

=head2 METHODS

=item $font = PDF::API2::CoreFont->new $pdf, $fontname, %options

Returns a corefont object.

Valid %options are:

	'-encode' ... changes the encoding of the font from its default.

	'-pdfname' ... changes the reference-name of the font from its default.

B<On '-encode':> The natively supported encodings are 'latin1','winansi' and 'macroman'.
Other Encodings are supported via PDF::API2::UniMap.

B<On '-pdfname':> The reference-name is normally generated automatically and can be
retrived via $pdfname=$font->name.

=cut

sub _look_for_font ($) {
	my $fname=shift;
	return(%{$fonts->{$fname}}) if(defined $fonts->{$fname});
	eval "require PDF::API2::CoreFont::$fname; ";
	unless($@){
		return(%{$fonts->{$fname}});
	} else {
		die "requested font '$fname' not installed ";
	}
}

sub new {
	my ($class,$pdf,$name,@opts) = @_;
	my $self;
	my %opts=();
	my $lookname=lc($name);
	$lookname=~s/[^a-z0-9]+//gi;
	%opts=@opts if((scalar @opts)%2 == 0);
	$class = ref $class if ref $class;
	$self = $class->SUPER::new();

	$lookname = defined($alias->{$lookname}) ? $alias->{$lookname} : $lookname ;

	if(defined $subs->{$lookname}) {
		$self->{' data'}={_look_for_font($subs->{$lookname}->{-alias})};
		foreach my $k (keys %{$subs->{$lookname}}) {
			next if($k=~/^\-/);
			$self->{' data'}->{$k}=$subs->{$lookname}->{$k};
		}
	} else {
		unless(defined $opts{-metrics}) {
			$self->{' data'}={_look_for_font($lookname)};
		} else {
			$self->{' data'}={%{$opts{-metrics}}};
		}
	}
	
	die "Undefined Font '$name($lookname)'" unless($self->{' data'}->{fontname});

	$self->{'Type'} = PDFName("Font");
	$self->{'Subtype'} = PDFName($self->{' data'}->{type});
	$self->{'BaseFont'} = PDFName($self->{' data'}->{fontname});
	$self->{' apiname'} = 'cFx'.pdfkey($self->{' data'}->{fontname}).((scalar @opts >0) ? '-'.pdfkey(@opts) : '0');
	$self->{'Name'} = PDFName($self->{' apiname'});

	$self->{'PDFAPIOptions'} = PDFStr(join(' ',@opts));

	unless($self->{' data'}->{iscore}) {
		$self->{'FontDescriptor'}=PDFDict();
		$self->{'FontDescriptor'}->{'Type'}=PDFName('FontDescriptor');
		$self->{'FontDescriptor'}->{'FontName'}=PDFName($self->{' data'}->{fontname});
		$self->{'FontDescriptor'}->{'FontBBox'}=PDFArray(map { PDFNum($_ || 0) } @{$self->{' data'}->{fontbbox}});
		unless($self->{' data'}->{issymbol}) {
			$self->{'FontDescriptor'}->{'Ascent'}=PDFNum($self->{' data'}->{ascender});
			$self->{'FontDescriptor'}->{'Descent'}=PDFNum($self->{' data'}->{descender});
			$self->{'FontDescriptor'}->{'ItalicAngle'}=PDFNum($self->{' data'}->{italicangle});
			$self->{'FontDescriptor'}->{'CapHeight'}=PDFNum($self->{' data'}->{capheight});
		#	$self->{'FontDescriptor'}->{'StemV'}=PDFNum($self->{' data'}->{stemv});
		#	$self->{'FontDescriptor'}->{'StemH'}=PDFNum($self->{' data'}->{stemh});
			$self->{'FontDescriptor'}->{'XHeight'}=PDFNum($self->{' data'}->{xheight});
		}

		$self->{'FontDescriptor'}->{'Flags'}=PDFNum($self->{' data'}->{flags}) if(defined $self->{' data'}->{flags});

	}	

	$self->encode($opts{-encode});

	if(defined($pdf) && !$self->is_obj($pdf)) {
		$pdf->new_obj($self);
	}

	return($self);
}

=item $font = PDF::API2::CoreFont->new_api $api, $fontname, %options

Returns a corefont object. This method is different from 'new' that
it needs an PDF::API2-object rather than a PDF::API2::PDF::File-object.

=cut

sub new_api {
	my ($class,$api,@opts)=@_;

	my $obj=$class->new($api->{pdf},@opts);
	my $key=$obj->{' apiname'};

	$api->{pdf}->new_obj($obj) unless($obj->is_obj($api->{pdf}));

	$api->resource('Font',$key,$obj);

	$api->{pdf}->out_obj($api->{pages});
	return($obj);
}

=item PDF::API2::CoreFont->loadallfonts()

"Requires in" all fonts available as corefonts.

=cut

sub loadallfonts {
	foreach my $f (qw(
		arialrounded
		bankgothic
		courier
		courierbold
		courierboldoblique
		courieroblique
		georgia
		georgiabold
		georgiabolditalic
		georgiaitalic
		helveticaboldoblique
		helveticaoblique
		impact
		ozhandicraft
		symbol
		timesbolditalic
		timesitalic
		trebuchet
		trebuchetbold
		trebuchetbolditalic
		trebuchetitalic
		verdana
		verdanabold
		verdanabolditalic
		verdanaitalic
		webdings
		wingdings
	)){
		_look_for_font($f);
	}
}

=item $pdfstring = $font->text $text

Returns a properly formated string-representation of $text
for use in the PDF.

=cut

sub text {
	my ($self,$text,%opts)=@_;
	my $newtext='';
	if($opts{-utf8}) {
		$text=utf8_to_ucs2($text);
		foreach my $x (0..(length($text)>>1)-1) {
			$newtext.=pack("C",vec($text,$x,16) & 0xff);
		}
	} elsif($opts{-ucs2}) {
		foreach my $x (0..(length($text)>>1)-1) {
			$newtext.=pack("C",vec($text,$x,16) & 0xff);
		}
	} else {
	#	foreach my $g (0..length($text)-1) {
	#		$newtext.=
	#			(substr($text,$g,1)=~/[\x00-\x1f\\\{\}\[\]\(\)]/)
	#			? sprintf('\%03lo',vec($text,$g,8))
	#			: substr($text,$g,1) ;
	#	}
		$newtext=$text;
		$newtext=~s/\\/\\\\/go;
		$newtext=~s/([\x00-\x1f])/sprintf('\%03lo',ord($1))/ge;
		$newtext=~s/([\{\}\[\]\(\)])/\\$1/g
	}
	return("($newtext)");
}

sub text_utf8 {
	my ($self,$text,%opts)=@_;
	return($self->text($text,-utf8=>1));
}

=item $pdfstring = $font->text_hex $text

Returns a properly formated hex-representation of $text
for use in the PDF.

=cut

sub text_hex {
	my ($font,$text,%opts)=@_;
	my $newtext='';
	if($opts{-utf8}) {
		$text=utf8_to_ucs2($text);
		foreach my $x (0..(length($text)>>1)-1) {
			$newtext.=sprintf('%02X',vec($text,$x,16) & 0xff);
		}
	} elsif($opts{-ucs2}) {
		foreach my $x (0..(length($text)>>1)-1) {
			$newtext.=sprintf('%02X',vec($text,$x,16) & 0xff);
		}
	} else {
		foreach (unpack("C*", $text)) {
			$newtext.= sprintf('%02X',$_);
		}
	}
	return('<'.$newtext.'>');
}

=item $wd = $font->width $text

Returns the width of $text as if it were at size 1.

=cut

sub width {
	my ($self,$text,%opts)=@_;
	my $width=0;
	if($opts{-utf8}) {
		$text=utf8_to_ucs2($text);
		foreach my $x (0..(length($text)>>1)-1) {
			my $ch=vec($text,$x,16) & 0xff;
			$width += $self->{' data'}{'wx'}{$self->{' data'}{'char'}[$ch] || 'space'} || $self->{' data'}{'wx'}{space};
		}
	} elsif($opts{-ucs2}) {
		foreach my $x (0..(length($text)>>1)-1) {
			my $ch=vec($text,$x,16) & 0xff;
			$width += $self->{' data'}{'wx'}{$self->{' data'}{'char'}[$ch] || 'space'} || $self->{' data'}{'wx'}{space};
		}
	} else {
		foreach (unpack("C*", $text)) {
			$width += $self->{' data'}{'wx'}{$self->{' data'}{'char'}[$_] || 'space'} || $self->{' data'}{'wx'}{space};
		}
	}
	$width/=1000;
	return($width);
}

=item @widths = $font->width_array $text

Returns the widths of the words in $text as if they were at size 1.

=cut

sub width_array {
	my ($self,$text,%opts)=@_;
	my @text=split(/\s+/,$text);
	my @widths=map {$self->width($_,%opts)} @text;
	return(@widths);
}

#=item ($llx,$lly,$urx,$ury) = $font->bbox $text
#
#Returns the texts bounding-box as if it were at size 1.
#
#=cut
#
#sub bbox {
#	my ($self,$text,%opts)=@_;
#	my $width=$self->width(substr($text,0,length($text)-1));
#	my @f=@{$self->{' data'}{'bbox'}{$self->{' data'}{'char'}[unpack("C",substr($text,0,1))] || 'space'}};
#	my @l=@{$self->{' data'}{'bbox'}{$self->{' data'}{'char'}[unpack("C",substr($text,-1,1))] || 'space'}};
#	my ($high,$low);
#	foreach (unpack("C*", $text)) {
#		$high = $self->{' data'}{'bbox'}{$self->{' data'}{'char'}[$_] || 'space'}->[3]>$high ? $self->{' data'}{'bbox'}{$self->{' data'}{'char'}[$_] || 'space'}->[3] : $high;
#		$low  = $self->{' data'}{'bbox'}{$self->{' data'}{'char'}[$_] || 'space'}->[1]<$low  ? $self->{' data'}{'bbox'}{$self->{' data'}{'char'}[$_] || 'space'}->[1] : $low;
#	}
#	return map {$_/1000} ($f[0],$low,(($width*1000)+$l[2]),$high);
#}

#=item $font->encode $encoding
#
#=cut

sub encode {
	my ($self,$encoding)=@_;

	my ($firstChar,$lastChar);

	my $pdfencode='WinAnsiEncoding';

	unless($self->{' data'}->{issymbol}) {
		if($encoding) {
			if($encoding eq 'winansi') {
				$pdfencode='WinAnsiEncoding';
				$encoding=undef;
				$self->{' data'}->{char}=[ @winansi ];
			} elsif($encoding eq 'macroman') {
				$pdfencode='MacRomanEncoding';
				$encoding=undef;
				$self->{' data'}->{char}=[ @macroman ];
			} elsif($encoding eq 'latin1') {
				$pdfencode='WinAnsiEncoding';
				$self->{' data'}->{char}=[ @latin1 ];
			} else {
				$pdfencode='WinAnsiEncoding';
				my $uniMap = PDF::API2::UniMap->new($encoding);
				$self->{' data'}->{char}=[ $uniMap->glyphs() ];
			}
		} else {
			$pdfencode='WinAnsiEncoding';
			$encoding=undef;
		#	$pdfencode='';
		}
	}

	$firstChar=32;
	$lastChar=255;

	$self->{'FirstChar'} = PDFNum($firstChar);
	$self->{'LastChar'} = PDFNum($lastChar);
	if($encoding || $self->{' data'}->{issymbol}) { 
		$self->{'Encoding'}=PDFDict();
		$self->{'Encoding'}->{'Type'}=PDFName('Encoding');
		$self->{'Encoding'}->{'BaseEncoding'}=PDFName($pdfencode || 'WinAnsiEncoding');
		my $notdefbefore=1;
		my @w=();

		foreach my $w ($firstChar..$lastChar) {
			if(!defined($self->{' data'}->{char}->[$w]) ||($self->{' data'}->{char}->[$w] eq '.notdef')) {
				$notdefbefore=1;
				next;
			} else {
				if($notdefbefore) {
					push(@w,PDFNum($w))
				}
				$notdefbefore=0;
				push(@w,PDFName($self->{' data'}->{char}->[$w]));
			}
		}
		$self->{'Encoding'}->{'Differences'}=PDFArray(@w);
	} else {
		$self->{'Encoding'}=PDFName($pdfencode) if($pdfencode);
	}

	my @w = map { 
		PDFNum($self->{' data'}->{'wx'}{$_ || '.notdef'} || $self->{' data'}->{missingwidth} || 300) 
	} map {
		$self->{' data'}->{'char'}[$_]	
	} ($firstChar..$lastChar);
	$self->{'Widths'}=PDFArray(@w);
	
	return($self);
}

=item $pdfname = $font->name

Returns the fonts pdfname.

=cut

sub name      { return $_[0]->{' apiname'}; }

=item $a = $font->ascent

Returns the fonts ascender value.

=cut

sub ascent      { return $_[0]->{' data'}->{ascent}; }

=item $d = $font->descent

Returns the fonts descender value.

=cut

sub descent     { return $_[0]->{' data'}->{descent}; }

=item $ia = $font->italicangle

Returns the fonts italicangle value.

=cut

sub italicangle { return $_[0]->{' data'}->{italicangle}; }

=item ($llx,$lly,$urx,$ury) = $font->fontbbox

Returns the fonts bounding-box.

=cut

sub fontbbox     { return @{$_[0]->{' data'}->{fontbbox}}; }

=item $ch = $font->capheight

Returns the fonts capheight value.

=cut

sub capheight   { return $_[0]->{' data'}->{capheight}; }

=item $xh = $font->xheight

Returns the fonts xheight.

=cut

sub xheight     { return $_[0]->{' data'}->{xheight}; }

=item $ul = $font->underlineposition

Returns the fonts underlineposition.

=cut

sub underlineposition { return $_[0]->{' data'}->{underlineposition}; }


BEGIN {

	$alias = {
		## Windows Fonts with Type1 equivalence
	
		'arialbolditalic'		=> 'helveticaboldoblique',
		'arialbold'			=> 'helveticabold',
		'arialitalic'			=> 'helveticaoblique',
		'arial'				=> 'helvetica',

		'times'				=> 'timesroman',
		'timesnewromanbolditalic'	=> 'timesbolditalic',
		'timesnewromanbold'		=> 'timesbold',
		'timesnewromanitalic'		=> 'timesitalic',
		'timesnewroman'			=> 'timesroman',
	
		'couriernewbolditalic'		=> 'courierboldoblique',
		'couriernewbold'		=> 'courierbold',
		'couriernewitalic'		=> 'courieroblique',
		'couriernew'			=> 'courier',
	
	
		## unix/TeX-ish aliases
	
		'typewriterbolditalic'		=> 'courierboldoblique',
		'typewriterbold'		=> 'courierbold',
		'typewriteritalic'		=> 'courieroblique',
		'typewriter'			=> 'courier',
		
		'sansbolditalic'		=> 'helveticaboldoblique',
		'sansbold'			=> 'helveticabold',
		'sansitalic'			=> 'helveticaoblique',
		'sans'				=> 'helvetica',
	
		'serifbolditalic'		=> 'timesbolditalic',
		'serifbold'			=> 'timesbold',
		'serifitalic'			=> 'timesitalic',
		'serif'				=> 'timesroman',
	
		'greek'				=> 'symbol',
		'bats'				=> 'zapfdingbats',
	};
	
	$subs = {
		'impactitalic'			=> {
							'-alias'	=> 'impact',
							'fontname'	=> 'Impact,Italic',
							'italicangle'	=> -12,
						},
		'ozhandicraftbold'		=> {
							'-alias'	=> 'ozhandicraft',
							'fontname'	=> 'OzHandicraftBT,Bold',
							'italicangle'	=> 0,
							'flags' => 32+262144,
						},
		'ozhandicraftitalic'		=> {
							'-alias'	=> 'ozhandicraft',
							'fontname'	=> 'OzHandicraftBT,Italic',
							'italicangle'	=> -15,
							'flags' => 96,
						},
		'ozhandicraftbolditalic'	=> {
							'-alias'	=> 'ozhandicraft',
							'fontname'	=> 'OzHandicraftBT,BoldItalic',
							'italicangle'	=> -15,
							'flags' => 96+262144,
						},
		'arialroundeditalic'	=> {
							'-alias'	=> 'arialrounded',
							'fontname'	=> 'ArialRoundedMTBold,Italic',
							'italicangle'	=> -15,
							'flags' => 96+262144,
						},
		'bankgothicbold'	=> {
							'-alias'	=> 'bankgothic',
							'fontname'	=> 'BankGothicMediumBT,Bold',
							'flags' => 32+262144,
						},
		'bankgothicbolditalic'	=> {
							'-alias'	=> 'bankgothic',
							'fontname'	=> 'BankGothicMediumBT,BoldItalic',
							'italicangle'	=> -15,
							'flags' => 96+262144,
						},
		'bankgothicitalic'	=> {
							'-alias'	=> 'bankgothic',
							'fontname'	=> 'BankGothicMediumBT,Italic',
							'italicangle'	=> -15,
							'flags' => 96,
						},
	};

	@latin1 = (
		'.notdef',		# 0x00, 0o000, 0 
		'.notdef',		# 0x01, 0o001, 1 
		'.notdef',		# 0x02, 0o002, 2 
		'.notdef',		# 0x03, 0o003, 3 
		'.notdef',		# 0x04, 0o004, 4 
		'.notdef',		# 0x05, 0o005, 5 
		'.notdef',		# 0x06, 0o006, 6 
		'.notdef',		# 0x07, 0o007, 7 
		'.notdef',		# 0x08, 0o010, 8 
		'.notdef',		# 0x09, 0o011, 9 
		'.notdef',		# 0x0A, 0o012, 10 
		'.notdef',		# 0x0B, 0o013, 11 
		'.notdef',		# 0x0C, 0o014, 12 
		'.notdef',		# 0x0D, 0o015, 13 
		'.notdef',		# 0x0E, 0o016, 14 
		'.notdef',		# 0x0F, 0o017, 15 
		'.notdef',		# 0x10, 0o020, 16 
		'.notdef',		# 0x11, 0o021, 17 
		'.notdef',		# 0x12, 0o022, 18 
		'.notdef',		# 0x13, 0o023, 19 
		'.notdef',		# 0x14, 0o024, 20 
		'.notdef',		# 0x15, 0o025, 21 
		'.notdef',		# 0x16, 0o026, 22 
		'.notdef',		# 0x17, 0o027, 23 
		'.notdef',		# 0x18, 0o030, 24 
		'.notdef',		# 0x19, 0o031, 25 
		'.notdef',		# 0x1A, 0o032, 26 
		'.notdef',		# 0x1B, 0o033, 27 
		'.notdef',		# 0x1C, 0o034, 28 
		'.notdef',		# 0x1D, 0o035, 29 
		'.notdef',		# 0x1E, 0o036, 30 
		'.notdef',		# 0x1F, 0o037, 31 
		'space',		# 0x20, 0o040, 32 
		'exclam',		# 0x21, 0o041, 33 
		'quotedbl',		# 0x22, 0o042, 34 
		'numbersign',		# 0x23, 0o043, 35 
		'dollar',		# 0x24, 0o044, 36 
		'percent',		# 0x25, 0o045, 37 
		'ampersand',		# 0x26, 0o046, 38 
		'quotesingle',		# 0x27, 0o047, 39 
		'parenleft',		# 0x28, 0o050, 40 
		'parenright',		# 0x29, 0o051, 41 
		'asterisk',		# 0x2A, 0o052, 42 
		'plus',		# 0x2B, 0o053, 43 
		'comma',		# 0x2C, 0o054, 44 
		'hyphen',		# 0x2D, 0o055, 45 
		'period',		# 0x2E, 0o056, 46 
		'slash',		# 0x2F, 0o057, 47 
		'zero',		# 0x30, 0o060, 48 
		'one',		# 0x31, 0o061, 49 
		'two',		# 0x32, 0o062, 50 
		'three',		# 0x33, 0o063, 51 
		'four',		# 0x34, 0o064, 52 
		'five',		# 0x35, 0o065, 53 
		'six',		# 0x36, 0o066, 54 
		'seven',		# 0x37, 0o067, 55 
		'eight',		# 0x38, 0o070, 56 
		'nine',		# 0x39, 0o071, 57 
		'colon',		# 0x3A, 0o072, 58 
		'semicolon',		# 0x3B, 0o073, 59 
		'less',		# 0x3C, 0o074, 60 
		'equal',		# 0x3D, 0o075, 61 
		'greater',		# 0x3E, 0o076, 62 
		'question',		# 0x3F, 0o077, 63 
		'at',		# 0x40, 0o100, 64 
		'A',		# 0x41, 0o101, 65 
		'B',		# 0x42, 0o102, 66 
		'C',		# 0x43, 0o103, 67 
		'D',		# 0x44, 0o104, 68 
		'E',		# 0x45, 0o105, 69 
		'F',		# 0x46, 0o106, 70 
		'G',		# 0x47, 0o107, 71 
		'H',		# 0x48, 0o110, 72 
		'I',		# 0x49, 0o111, 73 
		'J',		# 0x4A, 0o112, 74 
		'K',		# 0x4B, 0o113, 75 
		'L',		# 0x4C, 0o114, 76 
		'M',		# 0x4D, 0o115, 77 
		'N',		# 0x4E, 0o116, 78 
		'O',		# 0x4F, 0o117, 79 
		'P',		# 0x50, 0o120, 80 
		'Q',		# 0x51, 0o121, 81 
		'R',		# 0x52, 0o122, 82 
		'S',		# 0x53, 0o123, 83 
		'T',		# 0x54, 0o124, 84 
		'U',		# 0x55, 0o125, 85 
		'V',		# 0x56, 0o126, 86 
		'W',		# 0x57, 0o127, 87 
		'X',		# 0x58, 0o130, 88 
		'Y',		# 0x59, 0o131, 89 
		'Z',		# 0x5A, 0o132, 90 
		'bracketleft',		# 0x5B, 0o133, 91 
		'backslash',		# 0x5C, 0o134, 92 
		'bracketright',		# 0x5D, 0o135, 93 
		'asciicircum',		# 0x5E, 0o136, 94 
		'underscore',		# 0x5F, 0o137, 95 
		'grave',		# 0x60, 0o140, 96 
		'a',		# 0x61, 0o141, 97 
		'b',		# 0x62, 0o142, 98 
		'c',		# 0x63, 0o143, 99 
		'd',		# 0x64, 0o144, 100 
		'e',		# 0x65, 0o145, 101 
		'f',		# 0x66, 0o146, 102 
		'g',		# 0x67, 0o147, 103 
		'h',		# 0x68, 0o150, 104 
		'i',		# 0x69, 0o151, 105 
		'j',		# 0x6A, 0o152, 106 
		'k',		# 0x6B, 0o153, 107 
		'l',		# 0x6C, 0o154, 108 
		'm',		# 0x6D, 0o155, 109 
		'n',		# 0x6E, 0o156, 110 
		'o',		# 0x6F, 0o157, 111 
		'p',		# 0x70, 0o160, 112 
		'q',		# 0x71, 0o161, 113 
		'r',		# 0x72, 0o162, 114 
		's',		# 0x73, 0o163, 115 
		't',		# 0x74, 0o164, 116 
		'u',		# 0x75, 0o165, 117 
		'v',		# 0x76, 0o166, 118 
		'w',		# 0x77, 0o167, 119 
		'x',		# 0x78, 0o170, 120 
		'y',		# 0x79, 0o171, 121 
		'z',		# 0x7A, 0o172, 122 
		'braceleft',		# 0x7B, 0o173, 123 
		'bar',		# 0x7C, 0o174, 124 
		'braceright',		# 0x7D, 0o175, 125 
		'asciitilde',		# 0x7E, 0o176, 126 
		'bullet',		# 0x7F, 0o177, 127 
		'Euro',		# 0x80, 0o200, 128 
		'bullet',		# 0x81, 0o201, 129 
		'quotesinglbase',		# 0x82, 0o202, 130 
		'florin',		# 0x83, 0o203, 131 
		'quotedblbase',		# 0x84, 0o204, 132 
		'ellipsis',		# 0x85, 0o205, 133 
		'dagger',		# 0x86, 0o206, 134 
		'daggerdbl',		# 0x87, 0o207, 135 
		'circumflex',		# 0x88, 0o210, 136 
		'perthousand',		# 0x89, 0o211, 137 
		'Scaron',		# 0x8A, 0o212, 138 
		'guilsinglleft',		# 0x8B, 0o213, 139 
		'OE',		# 0x8C, 0o214, 140 
		'bullet',		# 0x8D, 0o215, 141 
		'Zcaron',		# 0x8E, 0o216, 142 
		'bullet',		# 0x8F, 0o217, 143 
		'bullet',		# 0x90, 0o220, 144 
		'quoteleft',		# 0x91, 0o221, 145 
		'quoteright',		# 0x92, 0o222, 146 
		'quotedblleft',		# 0x93, 0o223, 147 
		'quotedblright',		# 0x94, 0o224, 148 
		'bullet',		# 0x95, 0o225, 149 
		'endash',		# 0x96, 0o226, 150 
		'emdash',		# 0x97, 0o227, 151 
		'tilde',		# 0x98, 0o230, 152 
		'trademark',		# 0x99, 0o231, 153 
		'scaron',		# 0x9A, 0o232, 154 
		'guilsinglright',		# 0x9B, 0o233, 155 
		'oe',		# 0x9C, 0o234, 156 
		'bullet',		# 0x9D, 0o235, 157 
		'zcaron',		# 0x9E, 0o236, 158 
		'Ydieresis',		# 0x9F, 0o237, 159 
		'space',		# 0xA0, 0o240, 160 
		'exclamdown',		# 0xA1, 0o241, 161 
		'cent',		# 0xA2, 0o242, 162 
		'sterling',		# 0xA3, 0o243, 163 
		'currency',		# 0xA4, 0o244, 164 
		'yen',		# 0xA5, 0o245, 165 
		'brokenbar',		# 0xA6, 0o246, 166 
		'section',		# 0xA7, 0o247, 167 
		'dieresis',		# 0xA8, 0o250, 168 
		'copyright',		# 0xA9, 0o251, 169 
		'ordfeminine',		# 0xAA, 0o252, 170 
		'guillemotleft',		# 0xAB, 0o253, 171 
		'logicalnot',		# 0xAC, 0o254, 172 
		'hyphen',		# 0xAD, 0o255, 173 
		'registered',		# 0xAE, 0o256, 174 
		'macron',		# 0xAF, 0o257, 175 
		'degree',		# 0xB0, 0o260, 176 
		'plusminus',		# 0xB1, 0o261, 177 
		'twosuperior',		# 0xB2, 0o262, 178 
		'threesuperior',		# 0xB3, 0o263, 179 
		'acute',		# 0xB4, 0o264, 180 
		'mu',		# 0xB5, 0o265, 181 
		'paragraph',		# 0xB6, 0o266, 182 
		'periodcentered',		# 0xB7, 0o267, 183 
		'cedilla',		# 0xB8, 0o270, 184 
		'onesuperior',		# 0xB9, 0o271, 185 
		'ordmasculine',		# 0xBA, 0o272, 186 
		'guillemotright',		# 0xBB, 0o273, 187 
		'onequarter',		# 0xBC, 0o274, 188 
		'onehalf',		# 0xBD, 0o275, 189 
		'threequarters',		# 0xBE, 0o276, 190 
		'questiondown',		# 0xBF, 0o277, 191 
		'Agrave',		# 0xC0, 0o300, 192 
		'Aacute',		# 0xC1, 0o301, 193 
		'Acircumflex',		# 0xC2, 0o302, 194 
		'Atilde',		# 0xC3, 0o303, 195 
		'Adieresis',		# 0xC4, 0o304, 196 
		'Aring',		# 0xC5, 0o305, 197 
		'AE',		# 0xC6, 0o306, 198 
		'Ccedilla',		# 0xC7, 0o307, 199 
		'Egrave',		# 0xC8, 0o310, 200 
		'Eacute',		# 0xC9, 0o311, 201 
		'Ecircumflex',		# 0xCA, 0o312, 202 
		'Edieresis',		# 0xCB, 0o313, 203 
		'Igrave',		# 0xCC, 0o314, 204 
		'Iacute',		# 0xCD, 0o315, 205 
		'Icircumflex',		# 0xCE, 0o316, 206 
		'Idieresis',		# 0xCF, 0o317, 207 
		'Eth',		# 0xD0, 0o320, 208 
		'Ntilde',		# 0xD1, 0o321, 209 
		'Ograve',		# 0xD2, 0o322, 210 
		'Oacute',		# 0xD3, 0o323, 211 
		'Ocircumflex',		# 0xD4, 0o324, 212 
		'Otilde',		# 0xD5, 0o325, 213 
		'Odieresis',		# 0xD6, 0o326, 214 
		'multiply',		# 0xD7, 0o327, 215 
		'Oslash',		# 0xD8, 0o330, 216 
		'Ugrave',		# 0xD9, 0o331, 217 
		'Uacute',		# 0xDA, 0o332, 218 
		'Ucircumflex',		# 0xDB, 0o333, 219 
		'Udieresis',		# 0xDC, 0o334, 220 
		'Yacute',		# 0xDD, 0o335, 221 
		'Thorn',		# 0xDE, 0o336, 222 
		'germandbls',		# 0xDF, 0o337, 223 
		'agrave',		# 0xE0, 0o340, 224 
		'aacute',		# 0xE1, 0o341, 225 
		'acircumflex',		# 0xE2, 0o342, 226 
		'atilde',		# 0xE3, 0o343, 227 
		'adieresis',		# 0xE4, 0o344, 228 
		'aring',		# 0xE5, 0o345, 229 
		'ae',		# 0xE6, 0o346, 230 
		'ccedilla',		# 0xE7, 0o347, 231 
		'egrave',		# 0xE8, 0o350, 232 
		'eacute',		# 0xE9, 0o351, 233 
		'ecircumflex',		# 0xEA, 0o352, 234 
		'edieresis',		# 0xEB, 0o353, 235 
		'igrave',		# 0xEC, 0o354, 236 
		'iacute',		# 0xED, 0o355, 237 
		'icircumflex',		# 0xEE, 0o356, 238 
		'idieresis',		# 0xEF, 0o357, 239 
		'eth',		# 0xF0, 0o360, 240 
		'ntilde',		# 0xF1, 0o361, 241 
		'ograve',		# 0xF2, 0o362, 242 
		'oacute',		# 0xF3, 0o363, 243 
		'ocircumflex',		# 0xF4, 0o364, 244 
		'otilde',		# 0xF5, 0o365, 245 
		'odieresis',		# 0xF6, 0o366, 246 
		'divide',		# 0xF7, 0o367, 247 
		'oslash',		# 0xF8, 0o370, 248 
		'ugrave',		# 0xF9, 0o371, 249 
		'uacute',		# 0xFA, 0o372, 250 
		'ucircumflex',		# 0xFB, 0o373, 251 
		'udieresis',		# 0xFC, 0o374, 252 
		'yacute',		# 0xFD, 0o375, 253 
		'thorn',		# 0xFE, 0o376, 254 
		'ydieresis',		# 0xFF, 0o377, 255 
	);
	@macroman = (
		'.notdef',		# 0x00, 0o000, 0 
		'.notdef',		# 0x01, 0o001, 1 
		'.notdef',		# 0x02, 0o002, 2 
		'.notdef',		# 0x03, 0o003, 3 
		'.notdef',		# 0x04, 0o004, 4 
		'.notdef',		# 0x05, 0o005, 5 
		'.notdef',		# 0x06, 0o006, 6 
		'.notdef',		# 0x07, 0o007, 7 
		'.notdef',		# 0x08, 0o010, 8 
		'.notdef',		# 0x09, 0o011, 9 
		'.notdef',		# 0x0A, 0o012, 10 
		'.notdef',		# 0x0B, 0o013, 11 
		'.notdef',		# 0x0C, 0o014, 12 
		'.notdef',		# 0x0D, 0o015, 13 
		'.notdef',		# 0x0E, 0o016, 14 
		'.notdef',		# 0x0F, 0o017, 15 
		'.notdef',		# 0x10, 0o020, 16 
		'.notdef',		# 0x11, 0o021, 17 
		'.notdef',		# 0x12, 0o022, 18 
		'.notdef',		# 0x13, 0o023, 19 
		'.notdef',		# 0x14, 0o024, 20 
		'.notdef',		# 0x15, 0o025, 21 
		'.notdef',		# 0x16, 0o026, 22 
		'.notdef',		# 0x17, 0o027, 23 
		'.notdef',		# 0x18, 0o030, 24 
		'.notdef',		# 0x19, 0o031, 25 
		'.notdef',		# 0x1A, 0o032, 26 
		'.notdef',		# 0x1B, 0o033, 27 
		'.notdef',		# 0x1C, 0o034, 28 
		'.notdef',		# 0x1D, 0o035, 29 
		'.notdef',		# 0x1E, 0o036, 30 
		'.notdef',		# 0x1F, 0o037, 31 
		'space',		# 0x20, 0o040, 32 
		'exclam',		# 0x21, 0o041, 33 
		'quotedbl',		# 0x22, 0o042, 34 
		'numbersign',		# 0x23, 0o043, 35 
		'dollar',		# 0x24, 0o044, 36 
		'percent',		# 0x25, 0o045, 37 
		'ampersand',		# 0x26, 0o046, 38 
		'quotesingle',		# 0x27, 0o047, 39 
		'parenleft',		# 0x28, 0o050, 40 
		'parenright',		# 0x29, 0o051, 41 
		'asterisk',		# 0x2A, 0o052, 42 
		'plus',		# 0x2B, 0o053, 43 
		'comma',		# 0x2C, 0o054, 44 
		'hyphen',		# 0x2D, 0o055, 45 
		'period',		# 0x2E, 0o056, 46 
		'slash',		# 0x2F, 0o057, 47 
		'zero',		# 0x30, 0o060, 48 
		'one',		# 0x31, 0o061, 49 
		'two',		# 0x32, 0o062, 50 
		'three',		# 0x33, 0o063, 51 
		'four',		# 0x34, 0o064, 52 
		'five',		# 0x35, 0o065, 53 
		'six',		# 0x36, 0o066, 54 
		'seven',		# 0x37, 0o067, 55 
		'eight',		# 0x38, 0o070, 56 
		'nine',		# 0x39, 0o071, 57 
		'colon',		# 0x3A, 0o072, 58 
		'semicolon',		# 0x3B, 0o073, 59 
		'less',		# 0x3C, 0o074, 60 
		'equal',		# 0x3D, 0o075, 61 
		'greater',		# 0x3E, 0o076, 62 
		'question',		# 0x3F, 0o077, 63 
		'at',		# 0x40, 0o100, 64 
		'A',		# 0x41, 0o101, 65 
		'B',		# 0x42, 0o102, 66 
		'C',		# 0x43, 0o103, 67 
		'D',		# 0x44, 0o104, 68 
		'E',		# 0x45, 0o105, 69 
		'F',		# 0x46, 0o106, 70 
		'G',		# 0x47, 0o107, 71 
		'H',		# 0x48, 0o110, 72 
		'I',		# 0x49, 0o111, 73 
		'J',		# 0x4A, 0o112, 74 
		'K',		# 0x4B, 0o113, 75 
		'L',		# 0x4C, 0o114, 76 
		'M',		# 0x4D, 0o115, 77 
		'N',		# 0x4E, 0o116, 78 
		'O',		# 0x4F, 0o117, 79 
		'P',		# 0x50, 0o120, 80 
		'Q',		# 0x51, 0o121, 81 
		'R',		# 0x52, 0o122, 82 
		'S',		# 0x53, 0o123, 83 
		'T',		# 0x54, 0o124, 84 
		'U',		# 0x55, 0o125, 85 
		'V',		# 0x56, 0o126, 86 
		'W',		# 0x57, 0o127, 87 
		'X',		# 0x58, 0o130, 88 
		'Y',		# 0x59, 0o131, 89 
		'Z',		# 0x5A, 0o132, 90 
		'bracketleft',		# 0x5B, 0o133, 91 
		'backslash',		# 0x5C, 0o134, 92 
		'bracketright',		# 0x5D, 0o135, 93 
		'asciicircum',		# 0x5E, 0o136, 94 
		'underscore',		# 0x5F, 0o137, 95 
		'grave',		# 0x60, 0o140, 96 
		'a',		# 0x61, 0o141, 97 
		'b',		# 0x62, 0o142, 98 
		'c',		# 0x63, 0o143, 99 
		'd',		# 0x64, 0o144, 100 
		'e',		# 0x65, 0o145, 101 
		'f',		# 0x66, 0o146, 102 
		'g',		# 0x67, 0o147, 103 
		'h',		# 0x68, 0o150, 104 
		'i',		# 0x69, 0o151, 105 
		'j',		# 0x6A, 0o152, 106 
		'k',		# 0x6B, 0o153, 107 
		'l',		# 0x6C, 0o154, 108 
		'm',		# 0x6D, 0o155, 109 
		'n',		# 0x6E, 0o156, 110 
		'o',		# 0x6F, 0o157, 111 
		'p',		# 0x70, 0o160, 112 
		'q',		# 0x71, 0o161, 113 
		'r',		# 0x72, 0o162, 114 
		's',		# 0x73, 0o163, 115 
		't',		# 0x74, 0o164, 116 
		'u',		# 0x75, 0o165, 117 
		'v',		# 0x76, 0o166, 118 
		'w',		# 0x77, 0o167, 119 
		'x',		# 0x78, 0o170, 120 
		'y',		# 0x79, 0o171, 121 
		'z',		# 0x7A, 0o172, 122 
		'braceleft',		# 0x7B, 0o173, 123 
		'bar',		# 0x7C, 0o174, 124 
		'braceright',		# 0x7D, 0o175, 125 
		'asciitilde',		# 0x7E, 0o176, 126 
		'.notdef',		# 0x7F, 0o177, 127 
		'Adieresis',		# 0x80, 0o200, 128 
		'Aring',		# 0x81, 0o201, 129 
		'Ccedilla',		# 0x82, 0o202, 130 
		'Eacute',		# 0x83, 0o203, 131 
		'Ntilde',		# 0x84, 0o204, 132 
		'Odieresis',		# 0x85, 0o205, 133 
		'Udieresis',		# 0x86, 0o206, 134 
		'aacute',		# 0x87, 0o207, 135 
		'agrave',		# 0x88, 0o210, 136 
		'acircumflex',		# 0x89, 0o211, 137 
		'adieresis',		# 0x8A, 0o212, 138 
		'atilde',		# 0x8B, 0o213, 139 
		'aring',		# 0x8C, 0o214, 140 
		'ccedilla',		# 0x8D, 0o215, 141 
		'eacute',		# 0x8E, 0o216, 142 
		'egrave',		# 0x8F, 0o217, 143 
		'ecircumflex',		# 0x90, 0o220, 144 
		'edieresis',		# 0x91, 0o221, 145 
		'iacute',		# 0x92, 0o222, 146 
		'igrave',		# 0x93, 0o223, 147 
		'icircumflex',		# 0x94, 0o224, 148 
		'idieresis',		# 0x95, 0o225, 149 
		'ntilde',		# 0x96, 0o226, 150 
		'oacute',		# 0x97, 0o227, 151 
		'ograve',		# 0x98, 0o230, 152 
		'ocircumflex',		# 0x99, 0o231, 153 
		'odieresis',		# 0x9A, 0o232, 154 
		'otilde',		# 0x9B, 0o233, 155 
		'uacute',		# 0x9C, 0o234, 156 
		'ugrave',		# 0x9D, 0o235, 157 
		'ucircumflex',		# 0x9E, 0o236, 158 
		'udieresis',		# 0x9F, 0o237, 159 
		'dagger',		# 0xA0, 0o240, 160 
		'degree',		# 0xA1, 0o241, 161 
		'cent',		# 0xA2, 0o242, 162 
		'sterling',		# 0xA3, 0o243, 163 
		'section',		# 0xA4, 0o244, 164 
		'.notdef',		# 0xA5, 0o245, 165 
		'paragraph',		# 0xA6, 0o246, 166 
		'germandbls',		# 0xA7, 0o247, 167 
		'registered',		# 0xA8, 0o250, 168 
		'copyright',		# 0xA9, 0o251, 169 
		'trademark',		# 0xAA, 0o252, 170 
		'guillemotleft',		# 0xAB, 0o253, 171 
		'dieresis',		# 0xAC, 0o254, 172 
		'.notdef',		# 0xAD, 0o255, 173 
		'AE',		# 0xAE, 0o256, 174 
		'Oslash',		# 0xAF, 0o257, 175 
		'.notdef',		# 0xB0, 0o260, 176 
		'plusminus',		# 0xB1, 0o261, 177 
		'.notdef',		# 0xB2, 0o262, 178 
		'.notdef',		# 0xB3, 0o263, 179 
		'yen',		# 0xB4, 0o264, 180 
		'mu',		# 0xB5, 0o265, 181 
		'266',		# 0xB6, 0o266, 182 
		'bullet',		# 0xB7, 0o267, 183 
		'313',		# 0xB8, 0o270, 184 
		'~W',		# 0xB9, 0o271, 185 
		'353',		# 0xBA, 0o272, 186 
		'ordfeminine',		# 0xBB, 0o273, 187 
		'ordmasculine',		# 0xBC, 0o274, 188 
		'~W',		# 0xBD, 0o275, 189 
		'ae',		# 0xBE, 0o276, 190 
		'oslash',		# 0xBF, 0o277, 191 
		'questiondown',		# 0xC0, 0o300, 192 
		'exclamdown',		# 0xC1, 0o301, 193 
		'logicalnot',		# 0xC2, 0o302, 194 
		'.notdef',		# 0xC3, 0o303, 195 
		'florin',		# 0xC4, 0o304, 196 
		'.notdef',		# 0xC5, 0o305, 197 
		'.notdef',		# 0xC6, 0o306, 198 
		'.notdef',		# 0xC7, 0o307, 199 
		'.notdef',		# 0xC8, 0o310, 200 
		'ellipsis',		# 0xC9, 0o311, 201 
		'.notdef',		# 0xCA, 0o312, 202 
		'Agrave',		# 0xCB, 0o313, 203 
		'Atilde',		# 0xCC, 0o314, 204 
		'Otilde',		# 0xCD, 0o315, 205 
		'OE',		# 0xCE, 0o316, 206 
		'oe',		# 0xCF, 0o317, 207 
		'endash',		# 0xD0, 0o320, 208 
		'emdash',		# 0xD1, 0o321, 209 
		'quotedblleft',		# 0xD2, 0o322, 210 
		'quotedblright',		# 0xD3, 0o323, 211 
		'quoteleft',		# 0xD4, 0o324, 212 
		'quoteright',		# 0xD5, 0o325, 213 
		'divide',		# 0xD6, 0o326, 214 
		'~W',		# 0xD7, 0o327, 215 
		'ydieresis',		# 0xD8, 0o330, 216 
		'Ydieresis',		# 0xD9, 0o331, 217 
		'fraction',		# 0xDA, 0o332, 218 
		'.notdef',		# 0xDB, 0o333, 219 
		'guilsinglleft',		# 0xDC, 0o334, 220 
		'guilsinglright',		# 0xDD, 0o335, 221 
		'fi',		# 0xDE, 0o336, 222 
		'fl',		# 0xDF, 0o337, 223 
		'daggerdbl',		# 0xE0, 0o340, 224 
		'periodcentered',		# 0xE1, 0o341, 225 
		'quotesinglbase',		# 0xE2, 0o342, 226 
		'quotedblbase',		# 0xE3, 0o343, 227 
		'perthousand',		# 0xE4, 0o344, 228 
		'~W',		# 0xE5, 0o345, 229 
		'Ecircumflex',		# 0xE6, 0o346, 230 
		'~W',		# 0xE7, 0o347, 231 
		'Edieresis',		# 0xE8, 0o350, 232 
		'Egrave',		# 0xE9, 0o351, 233 
		'Iacute',		# 0xEA, 0o352, 234 
		'Icircumflex',		# 0xEB, 0o353, 235 
		'Idieresis',		# 0xEC, 0o354, 236 
		'Igrave',		# 0xED, 0o355, 237 
		'Oacute',		# 0xEE, 0o356, 238 
		'Ocircumflex',		# 0xEF, 0o357, 239 
		'.notdef',		# 0xF0, 0o360, 240 
		'~W',		# 0xF1, 0o361, 241 
		'~W',		# 0xF2, 0o362, 242 
		'~W',		# 0xF3, 0o363, 243 
		'~W',		# 0xF4, 0o364, 244 
		'dotlessi',		# 0xF5, 0o365, 245 
		'circumflex',		# 0xF6, 0o366, 246 
		'tilde',		# 0xF7, 0o367, 247 
		'macron',		# 0xF8, 0o370, 248 
		'breve',		# 0xF9, 0o371, 249 
		'dotaccent',		# 0xFA, 0o372, 250 
		'ring',		# 0xFB, 0o373, 251 
		'cedilla',		# 0xFC, 0o374, 252 
		'hungarumlaut',		# 0xFD, 0o375, 253 
		'ogonek',		# 0xFE, 0o376, 254 
		'caron',		# 0xFF, 0o377, 255 
	);
	@winansi = (
		'.notdef',		# 0x00, 0o000, 0 
		'.notdef',		# 0x01, 0o001, 1 
		'.notdef',		# 0x02, 0o002, 2 
		'.notdef',		# 0x03, 0o003, 3 
		'.notdef',		# 0x04, 0o004, 4 
		'.notdef',		# 0x05, 0o005, 5 
		'.notdef',		# 0x06, 0o006, 6 
		'.notdef',		# 0x07, 0o007, 7 
		'.notdef',		# 0x08, 0o010, 8 
		'.notdef',		# 0x09, 0o011, 9 
		'.notdef',		# 0x0A, 0o012, 10 
		'.notdef',		# 0x0B, 0o013, 11 
		'.notdef',		# 0x0C, 0o014, 12 
		'.notdef',		# 0x0D, 0o015, 13 
		'.notdef',		# 0x0E, 0o016, 14 
		'.notdef',		# 0x0F, 0o017, 15 
		'.notdef',		# 0x10, 0o020, 16 
		'.notdef',		# 0x11, 0o021, 17 
		'.notdef',		# 0x12, 0o022, 18 
		'.notdef',		# 0x13, 0o023, 19 
		'.notdef',		# 0x14, 0o024, 20 
		'.notdef',		# 0x15, 0o025, 21 
		'.notdef',		# 0x16, 0o026, 22 
		'.notdef',		# 0x17, 0o027, 23 
		'.notdef',		# 0x18, 0o030, 24 
		'.notdef',		# 0x19, 0o031, 25 
		'.notdef',		# 0x1A, 0o032, 26 
		'.notdef',		# 0x1B, 0o033, 27 
		'.notdef',		# 0x1C, 0o034, 28 
		'.notdef',		# 0x1D, 0o035, 29 
		'.notdef',		# 0x1E, 0o036, 30 
		'.notdef',		# 0x1F, 0o037, 31 
		'space',		# 0x20, 0o040, 32 
		'exclam',		# 0x21, 0o041, 33 
		'quotedbl',		# 0x22, 0o042, 34 
		'numbersign',		# 0x23, 0o043, 35 
		'dollar',		# 0x24, 0o044, 36 
		'percent',		# 0x25, 0o045, 37 
		'ampersand',		# 0x26, 0o046, 38 
		'quotesingle',		# 0x27, 0o047, 39 
		'parenleft',		# 0x28, 0o050, 40 
		'parenright',		# 0x29, 0o051, 41 
		'asterisk',		# 0x2A, 0o052, 42 
		'plus',		# 0x2B, 0o053, 43 
		'comma',		# 0x2C, 0o054, 44 
		'hyphen',		# 0x2D, 0o055, 45 
		'period',		# 0x2E, 0o056, 46 
		'slash',		# 0x2F, 0o057, 47 
		'zero',		# 0x30, 0o060, 48 
		'one',		# 0x31, 0o061, 49 
		'two',		# 0x32, 0o062, 50 
		'three',		# 0x33, 0o063, 51 
		'four',		# 0x34, 0o064, 52 
		'five',		# 0x35, 0o065, 53 
		'six',		# 0x36, 0o066, 54 
		'seven',		# 0x37, 0o067, 55 
		'eight',		# 0x38, 0o070, 56 
		'nine',		# 0x39, 0o071, 57 
		'colon',		# 0x3A, 0o072, 58 
		'semicolon',		# 0x3B, 0o073, 59 
		'less',		# 0x3C, 0o074, 60 
		'equal',		# 0x3D, 0o075, 61 
		'greater',		# 0x3E, 0o076, 62 
		'question',		# 0x3F, 0o077, 63 
		'at',		# 0x40, 0o100, 64 
		'A',		# 0x41, 0o101, 65 
		'B',		# 0x42, 0o102, 66 
		'C',		# 0x43, 0o103, 67 
		'D',		# 0x44, 0o104, 68 
		'E',		# 0x45, 0o105, 69 
		'F',		# 0x46, 0o106, 70 
		'G',		# 0x47, 0o107, 71 
		'H',		# 0x48, 0o110, 72 
		'I',		# 0x49, 0o111, 73 
		'J',		# 0x4A, 0o112, 74 
		'K',		# 0x4B, 0o113, 75 
		'L',		# 0x4C, 0o114, 76 
		'M',		# 0x4D, 0o115, 77 
		'N',		# 0x4E, 0o116, 78 
		'O',		# 0x4F, 0o117, 79 
		'P',		# 0x50, 0o120, 80 
		'Q',		# 0x51, 0o121, 81 
		'R',		# 0x52, 0o122, 82 
		'S',		# 0x53, 0o123, 83 
		'T',		# 0x54, 0o124, 84 
		'U',		# 0x55, 0o125, 85 
		'V',		# 0x56, 0o126, 86 
		'W',		# 0x57, 0o127, 87 
		'X',		# 0x58, 0o130, 88 
		'Y',		# 0x59, 0o131, 89 
		'Z',		# 0x5A, 0o132, 90 
		'bracketleft',		# 0x5B, 0o133, 91 
		'backslash',		# 0x5C, 0o134, 92 
		'bracketright',		# 0x5D, 0o135, 93 
		'asciicircum',		# 0x5E, 0o136, 94 
		'underscore',		# 0x5F, 0o137, 95 
		'grave',		# 0x60, 0o140, 96 
		'a',		# 0x61, 0o141, 97 
		'b',		# 0x62, 0o142, 98 
		'c',		# 0x63, 0o143, 99 
		'd',		# 0x64, 0o144, 100 
		'e',		# 0x65, 0o145, 101 
		'f',		# 0x66, 0o146, 102 
		'g',		# 0x67, 0o147, 103 
		'h',		# 0x68, 0o150, 104 
		'i',		# 0x69, 0o151, 105 
		'j',		# 0x6A, 0o152, 106 
		'k',		# 0x6B, 0o153, 107 
		'l',		# 0x6C, 0o154, 108 
		'm',		# 0x6D, 0o155, 109 
		'n',		# 0x6E, 0o156, 110 
		'o',		# 0x6F, 0o157, 111 
		'p',		# 0x70, 0o160, 112 
		'q',		# 0x71, 0o161, 113 
		'r',		# 0x72, 0o162, 114 
		's',		# 0x73, 0o163, 115 
		't',		# 0x74, 0o164, 116 
		'u',		# 0x75, 0o165, 117 
		'v',		# 0x76, 0o166, 118 
		'w',		# 0x77, 0o167, 119 
		'x',		# 0x78, 0o170, 120 
		'y',		# 0x79, 0o171, 121 
		'z',		# 0x7A, 0o172, 122 
		'braceleft',		# 0x7B, 0o173, 123 
		'bar',		# 0x7C, 0o174, 124 
		'braceright',		# 0x7D, 0o175, 125 
		'asciitilde',		# 0x7E, 0o176, 126 
		'bullet',		# 0x7F, 0o177, 127 
		'Euro',		# 0x80, 0o200, 128 
		'bullet',		# 0x81, 0o201, 129 
		'quotesinglbase',		# 0x82, 0o202, 130 
		'florin',		# 0x83, 0o203, 131 
		'quotedblbase',		# 0x84, 0o204, 132 
		'ellipsis',		# 0x85, 0o205, 133 
		'dagger',		# 0x86, 0o206, 134 
		'daggerdbl',		# 0x87, 0o207, 135 
		'circumflex',		# 0x88, 0o210, 136 
		'perthousand',		# 0x89, 0o211, 137 
		'Scaron',		# 0x8A, 0o212, 138 
		'guilsinglleft',		# 0x8B, 0o213, 139 
		'OE',		# 0x8C, 0o214, 140 
		'bullet',		# 0x8D, 0o215, 141 
		'Zcaron',		# 0x8E, 0o216, 142 
		'bullet',		# 0x8F, 0o217, 143 
		'bullet',		# 0x90, 0o220, 144 
		'quoteleft',		# 0x91, 0o221, 145 
		'quoteright',		# 0x92, 0o222, 146 
		'quotedblleft',		# 0x93, 0o223, 147 
		'quotedblright',		# 0x94, 0o224, 148 
		'bullet',		# 0x95, 0o225, 149 
		'endash',		# 0x96, 0o226, 150 
		'emdash',		# 0x97, 0o227, 151 
		'tilde',		# 0x98, 0o230, 152 
		'trademark',		# 0x99, 0o231, 153 
		'scaron',		# 0x9A, 0o232, 154 
		'guilsinglright',		# 0x9B, 0o233, 155 
		'oe',		# 0x9C, 0o234, 156 
		'bullet',		# 0x9D, 0o235, 157 
		'zcaron',		# 0x9E, 0o236, 158 
		'Ydieresis',		# 0x9F, 0o237, 159 
		'space',		# 0xA0, 0o240, 160 
		'exclamdown',		# 0xA1, 0o241, 161 
		'cent',		# 0xA2, 0o242, 162 
		'sterling',		# 0xA3, 0o243, 163 
		'currency',		# 0xA4, 0o244, 164 
		'yen',		# 0xA5, 0o245, 165 
		'brokenbar',		# 0xA6, 0o246, 166 
		'section',		# 0xA7, 0o247, 167 
		'dieresis',		# 0xA8, 0o250, 168 
		'copyright',		# 0xA9, 0o251, 169 
		'ordfeminine',		# 0xAA, 0o252, 170 
		'guillemotleft',		# 0xAB, 0o253, 171 
		'logicalnot',		# 0xAC, 0o254, 172 
		'hyphen',		# 0xAD, 0o255, 173 
		'registered',		# 0xAE, 0o256, 174 
		'macron',		# 0xAF, 0o257, 175 
		'degree',		# 0xB0, 0o260, 176 
		'plusminus',		# 0xB1, 0o261, 177 
		'twosuperior',		# 0xB2, 0o262, 178 
		'threesuperior',		# 0xB3, 0o263, 179 
		'acute',		# 0xB4, 0o264, 180 
		'mu',		# 0xB5, 0o265, 181 
		'paragraph',		# 0xB6, 0o266, 182 
		'periodcentered',		# 0xB7, 0o267, 183 
		'cedilla',		# 0xB8, 0o270, 184 
		'onesuperior',		# 0xB9, 0o271, 185 
		'ordmasculine',		# 0xBA, 0o272, 186 
		'guillemotright',		# 0xBB, 0o273, 187 
		'onequarter',		# 0xBC, 0o274, 188 
		'onehalf',		# 0xBD, 0o275, 189 
		'threequarters',		# 0xBE, 0o276, 190 
		'questiondown',		# 0xBF, 0o277, 191 
		'Agrave',		# 0xC0, 0o300, 192 
		'Aacute',		# 0xC1, 0o301, 193 
		'Acircumflex',		# 0xC2, 0o302, 194 
		'Atilde',		# 0xC3, 0o303, 195 
		'Adieresis',		# 0xC4, 0o304, 196 
		'Aring',		# 0xC5, 0o305, 197 
		'AE',		# 0xC6, 0o306, 198 
		'Ccedilla',		# 0xC7, 0o307, 199 
		'Egrave',		# 0xC8, 0o310, 200 
		'Eacute',		# 0xC9, 0o311, 201 
		'Ecircumflex',		# 0xCA, 0o312, 202 
		'Edieresis',		# 0xCB, 0o313, 203 
		'Igrave',		# 0xCC, 0o314, 204 
		'Iacute',		# 0xCD, 0o315, 205 
		'Icircumflex',		# 0xCE, 0o316, 206 
		'Idieresis',		# 0xCF, 0o317, 207 
		'Eth',		# 0xD0, 0o320, 208 
		'Ntilde',		# 0xD1, 0o321, 209 
		'Ograve',		# 0xD2, 0o322, 210 
		'Oacute',		# 0xD3, 0o323, 211 
		'Ocircumflex',		# 0xD4, 0o324, 212 
		'Otilde',		# 0xD5, 0o325, 213 
		'Odieresis',		# 0xD6, 0o326, 214 
		'multiply',		# 0xD7, 0o327, 215 
		'Oslash',		# 0xD8, 0o330, 216 
		'Ugrave',		# 0xD9, 0o331, 217 
		'Uacute',		# 0xDA, 0o332, 218 
		'Ucircumflex',		# 0xDB, 0o333, 219 
		'Udieresis',		# 0xDC, 0o334, 220 
		'Yacute',		# 0xDD, 0o335, 221 
		'Thorn',		# 0xDE, 0o336, 222 
		'germandbls',		# 0xDF, 0o337, 223 
		'agrave',		# 0xE0, 0o340, 224 
		'aacute',		# 0xE1, 0o341, 225 
		'acircumflex',		# 0xE2, 0o342, 226 
		'atilde',		# 0xE3, 0o343, 227 
		'adieresis',		# 0xE4, 0o344, 228 
		'aring',		# 0xE5, 0o345, 229 
		'ae',		# 0xE6, 0o346, 230 
		'ccedilla',		# 0xE7, 0o347, 231 
		'egrave',		# 0xE8, 0o350, 232 
		'eacute',		# 0xE9, 0o351, 233 
		'ecircumflex',		# 0xEA, 0o352, 234 
		'edieresis',		# 0xEB, 0o353, 235 
		'igrave',		# 0xEC, 0o354, 236 
		'iacute',		# 0xED, 0o355, 237 
		'icircumflex',		# 0xEE, 0o356, 238 
		'idieresis',		# 0xEF, 0o357, 239 
		'eth',		# 0xF0, 0o360, 240 
		'ntilde',		# 0xF1, 0o361, 241 
		'ograve',		# 0xF2, 0o362, 242 
		'oacute',		# 0xF3, 0o363, 243 
		'ocircumflex',		# 0xF4, 0o364, 244 
		'otilde',		# 0xF5, 0o365, 245 
		'odieresis',		# 0xF6, 0o366, 246 
		'divide',		# 0xF7, 0o367, 247 
		'oslash',		# 0xF8, 0o370, 248 
		'ugrave',		# 0xF9, 0o371, 249 
		'uacute',		# 0xFA, 0o372, 250 
		'ucircumflex',		# 0xFB, 0o373, 251 
		'udieresis',		# 0xFC, 0o374, 252 
		'yacute',		# 0xFD, 0o375, 253 
		'thorn',		# 0xFE, 0o376, 254 
		'ydieresis',		# 0xFF, 0o377, 255 
	);
	@adobestd = (
		'.notdef',		# 0x00, 0o000, 0 
		'.notdef',		# 0x01, 0o001, 1 
		'.notdef',		# 0x02, 0o002, 2 
		'.notdef',		# 0x03, 0o003, 3 
		'.notdef',		# 0x04, 0o004, 4 
		'.notdef',		# 0x05, 0o005, 5 
		'.notdef',		# 0x06, 0o006, 6 
		'.notdef',		# 0x07, 0o007, 7 
		'.notdef',		# 0x08, 0o010, 8 
		'.notdef',		# 0x09, 0o011, 9 
		'.notdef',		# 0x0A, 0o012, 10 
		'.notdef',		# 0x0B, 0o013, 11 
		'.notdef',		# 0x0C, 0o014, 12 
		'.notdef',		# 0x0D, 0o015, 13 
		'.notdef',		# 0x0E, 0o016, 14 
		'.notdef',		# 0x0F, 0o017, 15 
		'.notdef',		# 0x10, 0o020, 16 
		'.notdef',		# 0x11, 0o021, 17 
		'.notdef',		# 0x12, 0o022, 18 
		'.notdef',		# 0x13, 0o023, 19 
		'.notdef',		# 0x14, 0o024, 20 
		'.notdef',		# 0x15, 0o025, 21 
		'.notdef',		# 0x16, 0o026, 22 
		'.notdef',		# 0x17, 0o027, 23 
		'.notdef',		# 0x18, 0o030, 24 
		'.notdef',		# 0x19, 0o031, 25 
		'.notdef',		# 0x1A, 0o032, 26 
		'.notdef',		# 0x1B, 0o033, 27 
		'.notdef',		# 0x1C, 0o034, 28 
		'.notdef',		# 0x1D, 0o035, 29 
		'.notdef',		# 0x1E, 0o036, 30 
		'.notdef',		# 0x1F, 0o037, 31 
		'space',		# 0x20, 0o040, 32 
		'exclam',		# 0x21, 0o041, 33 
		'quotedbl',		# 0x22, 0o042, 34 
		'numbersign',		# 0x23, 0o043, 35 
		'dollar',		# 0x24, 0o044, 36 
		'percent',		# 0x25, 0o045, 37 
		'ampersand',		# 0x26, 0o046, 38 
		'quotesingle',		# 0x27, 0o047, 39 
		'parenleft',		# 0x28, 0o050, 40 
		'parenright',		# 0x29, 0o051, 41 
		'asterisk',		# 0x2A, 0o052, 42 
		'plus',		# 0x2B, 0o053, 43 
		'comma',		# 0x2C, 0o054, 44 
		'hyphen',		# 0x2D, 0o055, 45 
		'period',		# 0x2E, 0o056, 46 
		'slash',		# 0x2F, 0o057, 47 
		'zero',		# 0x30, 0o060, 48 
		'one',		# 0x31, 0o061, 49 
		'two',		# 0x32, 0o062, 50 
		'three',		# 0x33, 0o063, 51 
		'four',		# 0x34, 0o064, 52 
		'five',		# 0x35, 0o065, 53 
		'six',		# 0x36, 0o066, 54 
		'seven',		# 0x37, 0o067, 55 
		'eight',		# 0x38, 0o070, 56 
		'nine',		# 0x39, 0o071, 57 
		'colon',		# 0x3A, 0o072, 58 
		'semicolon',		# 0x3B, 0o073, 59 
		'less',		# 0x3C, 0o074, 60 
		'equal',		# 0x3D, 0o075, 61 
		'greater',		# 0x3E, 0o076, 62 
		'question',		# 0x3F, 0o077, 63 
		'at',		# 0x40, 0o100, 64 
		'A',		# 0x41, 0o101, 65 
		'B',		# 0x42, 0o102, 66 
		'C',		# 0x43, 0o103, 67 
		'D',		# 0x44, 0o104, 68 
		'E',		# 0x45, 0o105, 69 
		'F',		# 0x46, 0o106, 70 
		'G',		# 0x47, 0o107, 71 
		'H',		# 0x48, 0o110, 72 
		'I',		# 0x49, 0o111, 73 
		'J',		# 0x4A, 0o112, 74 
		'K',		# 0x4B, 0o113, 75 
		'L',		# 0x4C, 0o114, 76 
		'M',		# 0x4D, 0o115, 77 
		'N',		# 0x4E, 0o116, 78 
		'O',		# 0x4F, 0o117, 79 
		'P',		# 0x50, 0o120, 80 
		'Q',		# 0x51, 0o121, 81 
		'R',		# 0x52, 0o122, 82 
		'S',		# 0x53, 0o123, 83 
		'T',		# 0x54, 0o124, 84 
		'U',		# 0x55, 0o125, 85 
		'V',		# 0x56, 0o126, 86 
		'W',		# 0x57, 0o127, 87 
		'X',		# 0x58, 0o130, 88 
		'Y',		# 0x59, 0o131, 89 
		'Z',		# 0x5A, 0o132, 90 
		'bracketleft',		# 0x5B, 0o133, 91 
		'backslash',		# 0x5C, 0o134, 92 
		'bracketright',		# 0x5D, 0o135, 93 
		'asciicircum',		# 0x5E, 0o136, 94 
		'underscore',		# 0x5F, 0o137, 95 
		'quoteleft',		# 0x60, 0o140, 96 
		'a',		# 0x61, 0o141, 97 
		'b',		# 0x62, 0o142, 98 
		'c',		# 0x63, 0o143, 99 
		'd',		# 0x64, 0o144, 100 
		'e',		# 0x65, 0o145, 101 
		'f',		# 0x66, 0o146, 102 
		'g',		# 0x67, 0o147, 103 
		'h',		# 0x68, 0o150, 104 
		'i',		# 0x69, 0o151, 105 
		'j',		# 0x6A, 0o152, 106 
		'k',		# 0x6B, 0o153, 107 
		'l',		# 0x6C, 0o154, 108 
		'm',		# 0x6D, 0o155, 109 
		'n',		# 0x6E, 0o156, 110 
		'o',		# 0x6F, 0o157, 111 
		'p',		# 0x70, 0o160, 112 
		'q',		# 0x71, 0o161, 113 
		'r',		# 0x72, 0o162, 114 
		's',		# 0x73, 0o163, 115 
		't',		# 0x74, 0o164, 116 
		'u',		# 0x75, 0o165, 117 
		'v',		# 0x76, 0o166, 118 
		'w',		# 0x77, 0o167, 119 
		'x',		# 0x78, 0o170, 120 
		'y',		# 0x79, 0o171, 121 
		'z',		# 0x7A, 0o172, 122 
		'braceleft',		# 0x7B, 0o173, 123 
		'bar',		# 0x7C, 0o174, 124 
		'braceright',		# 0x7D, 0o175, 125 
		'asciitilde',		# 0x7E, 0o176, 126 
		'bullet',		# 0x7F, 0o177, 127 
		'Euro',		# 0x80, 0o200, 128 
		'.notdef',		# 0x81, 0o201, 129 
		'.notdef',		# 0x82, 0o202, 130 
		'.notdef',		# 0x83, 0o203, 131 
		'.notdef',		# 0x84, 0o204, 132 
		'.notdef',		# 0x85, 0o205, 133 
		'.notdef',		# 0x86, 0o206, 134 
		'.notdef',		# 0x87, 0o207, 135 
		'.notdef',		# 0x88, 0o210, 136 
		'.notdef',		# 0x89, 0o211, 137 
		'.notdef',		# 0x8A, 0o212, 138 
		'.notdef',		# 0x8B, 0o213, 139 
		'.notdef',		# 0x8C, 0o214, 140 
		'.notdef',		# 0x8D, 0o215, 141 
		'.notdef',		# 0x8E, 0o216, 142 
		'.notdef',		# 0x8F, 0o217, 143 
		'.notdef',		# 0x90, 0o220, 144 
		'.notdef',		# 0x91, 0o221, 145 
		'.notdef',		# 0x92, 0o222, 146 
		'.notdef',		# 0x93, 0o223, 147 
		'.notdef',		# 0x94, 0o224, 148 
		'.notdef',		# 0x95, 0o225, 149 
		'.notdef',		# 0x96, 0o226, 150 
		'.notdef',		# 0x97, 0o227, 151 
		'.notdef',		# 0x98, 0o230, 152 
		'.notdef',		# 0x99, 0o231, 153 
		'.notdef',		# 0x9A, 0o232, 154 
		'.notdef',		# 0x9B, 0o233, 155 
		'.notdef',		# 0x9C, 0o234, 156 
		'.notdef',		# 0x9D, 0o235, 157 
		'.notdef',		# 0x9E, 0o236, 158 
		'.notdef',		# 0x9F, 0o237, 159 
		'space',		# 0xA0, 0o240, 160 
		'exclamdown',		# 0xA1, 0o241, 161 
		'cent',		# 0xA2, 0o242, 162 
		'sterling',		# 0xA3, 0o243, 163 
		'fraction',		# 0xA4, 0o244, 164 
		'yen',		# 0xA5, 0o245, 165 
		'florin',		# 0xA6, 0o246, 166 
		'section',		# 0xA7, 0o247, 167 
		'currency',		# 0xA8, 0o250, 168 
		'quotesingle',		# 0xA9, 0o251, 169 
		'quotedblleft',		# 0xAA, 0o252, 170 
		'guillemotleft',		# 0xAB, 0o253, 171 
		'guilsinglleft',		# 0xAC, 0o254, 172 
		'guilsinglright',		# 0xAD, 0o255, 173 
		'fi',		# 0xAE, 0o256, 174 
		'fl',		# 0xAF, 0o257, 175 
		'degree',		# 0xB0, 0o260, 176 
		'endash',		# 0xB1, 0o261, 177 
		'dagger',		# 0xB2, 0o262, 178 
		'daggerdbl',		# 0xB3, 0o263, 179 
		'periodcentered',		# 0xB4, 0o264, 180 
		'mu',		# 0xB5, 0o265, 181 
		'paragraph',		# 0xB6, 0o266, 182 
		'bullet',		# 0xB7, 0o267, 183 
		'quotesinglbase',		# 0xB8, 0o270, 184 
		'quotedblbase',		# 0xB9, 0o271, 185 
		'quotedblright',		# 0xBA, 0o272, 186 
		'guillemotright',		# 0xBB, 0o273, 187 
		'ellipsis',		# 0xBC, 0o274, 188 
		'perthousand',		# 0xBD, 0o275, 189 
		'threequarters',		# 0xBE, 0o276, 190 
		'questiondown',		# 0xBF, 0o277, 191 
		'.notdef',		# 0xC0, 0o300, 192 
		'grave',		# 0xC1, 0o301, 193 
		'acute',		# 0xC2, 0o302, 194 
		'circumflex',		# 0xC3, 0o303, 195 
		'tilde',		# 0xC4, 0o304, 196 
		'macron',		# 0xC5, 0o305, 197 
		'breve',		# 0xC6, 0o306, 198 
		'dotaccent',		# 0xC7, 0o307, 199 
		'dieresis',		# 0xC8, 0o310, 200 
		'.notdef',		# 0xC9, 0o311, 201 
		'ring',		# 0xCA, 0o312, 202 
		'cedilla',		# 0xCB, 0o313, 203 
		'.notdef',		# 0xCC, 0o314, 204 
		'hungarumlaut',		# 0xCD, 0o315, 205 
		'orgonek',		# 0xCE, 0o316, 206 
		'caron',		# 0xCF, 0o317, 207 
		'emdash',		# 0xD0, 0o320, 208 
		'.notdef',		# 0xD1, 0o321, 209 
		'.notdef',		# 0xD2, 0o322, 210 
		'.notdef',		# 0xD3, 0o323, 211 
		'.notdef',		# 0xD4, 0o324, 212 
		'.notdef',		# 0xD5, 0o325, 213 
		'.notdef',		# 0xD6, 0o326, 214 
		'.notdef',		# 0xD7, 0o327, 215 
		'.notdef',		# 0xD8, 0o330, 216 
		'.notdef',		# 0xD9, 0o331, 217 
		'.notdef',		# 0xDA, 0o332, 218 
		'.notdef',		# 0xDB, 0o333, 219 
		'.notdef',		# 0xDC, 0o334, 220 
		'.notdef',		# 0xDD, 0o335, 221 
		'.notdef',		# 0xDE, 0o336, 222 
		'germandbls',		# 0xDF, 0o337, 223 
		'.notdef',		# 0xE0, 0o340, 224 
		'AE',		# 0xE1, 0o341, 225 
		'.notdef',		# 0xE2, 0o342, 226 
		'ordfeminine',		# 0xE3, 0o343, 227 
		'.notdef',		# 0xE4, 0o344, 228 
		'.notdef',		# 0xE5, 0o345, 229 
		'.notdef',		# 0xE6, 0o346, 230 
		'.notdef',		# 0xE7, 0o347, 231 
		'Lslash',		# 0xE8, 0o350, 232 
		'Oslash',		# 0xE9, 0o351, 233 
		'OE',		# 0xEA, 0o352, 234 
		'ordmasculine',		# 0xEB, 0o353, 235 
		'.notdef',		# 0xEC, 0o354, 236 
		'.notdef',		# 0xED, 0o355, 237 
		'.notdef',		# 0xEE, 0o356, 238 
		'.notdef',		# 0xEF, 0o357, 239 
		'.notdef',		# 0xF0, 0o360, 240 
		'ae',		# 0xF1, 0o361, 241 
		'.notdef',		# 0xF2, 0o362, 242 
		'.notdef',		# 0xF3, 0o363, 243 
		'.notdef',		# 0xF4, 0o364, 244 
		'dotlessi',		# 0xF5, 0o365, 245 
		'.notdef',		# 0xF6, 0o366, 246 
		'.notdef',		# 0xF7, 0o367, 247 
		'lslash',		# 0xF8, 0o370, 248 
		'oslash',		# 0xF9, 0o371, 249 
		'oe',		# 0xFA, 0o372, 250 
		'germandbls',		# 0xFB, 0o373, 251 
		'.notdef',		# 0xFC, 0o374, 252 
		'.notdef',		# 0xFD, 0o375, 253 
		'.notdef',		# 0xFE, 0o376, 254 
		'.notdef',		# 0xFF, 0o377, 255 
	);

	$fonts = {
		'helveticabold' => {
			'ascender' => '718',
			'capheight' => '718',
			'char' => [undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'space','exclam','quotedbl','numbersign','dollar','percent','ampersand','quoteright','parenleft','parenright','asterisk','plus','comma','hyphen','period','slash','zero','one','two','three','four','five','six','seven','eight','nine','colon','semicolon','less','equal','greater','question','at','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','bracketleft','backslash','bracketright','asciicircum','underscore','quoteleft','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','braceleft','bar','braceright','asciitilde',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'exclamdown','cent','sterling','fraction','yen','florin','section','currency','quotesingle','quotedblleft','guillemotleft','guilsinglleft','guilsinglright','fi','fl',undef,'endash','dagger','daggerdbl','periodcentered',undef,'paragraph','bullet','quotesinglbase','quotedblbase','quotedblright','guillemotright','ellipsis','perthousand',undef,'questiondown',undef,'grave','acute','circumflex','tilde','macron','breve','dotaccent','dieresis',undef,'ring','cedilla',undef,'hungarumlaut','ogonek','caron','emdash',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'AE',undef,'ordfeminine',undef,undef,undef,undef,'Lslash','Oslash','OE','ordmasculine',undef,undef,undef,undef,undef,'ae',undef,undef,undef,'dotlessi',undef,undef,'lslash','oslash','oe','germandbls'],
			'descender' => '-207',
			'fontbbox' => ['-170','-228','1003','962'],
			'fontname' => 'Helvetica-Bold',
			'iscore' => 1,
			'isfixedpitch' => 0,
			'italicangle' => '0',
			'missingwidth' => '278',
			'stdhw' => '118',
			'stdvw' => '140',
			'type' => 'Type1',
			'underlineposition' => '-100',
			'underlinethickness' => '50',
			'wx' => {'ntilde' => '611','cacute' => '556','Ydieresis' => '667','Oacute' => '778','zdotaccent' => '500','acute' => '333','lcommaaccent' => '278','ohungarumlaut' => '611','parenleft' => '333','lozenge' => '494','zero' => '556','aring' => '556','ncaron' => '611','Acircumflex' => '722','Zcaron' => '611','Nacute' => '722','scommaaccent' => '556','multiply' => '584','ellipsis' => '1000','uacute' => '611','hungarumlaut' => '333','aogonek' => '556','aacute' => '556','Emacron' => '667','Lslash' => '611','cedilla' => '333','A' => '722','B' => '722','Ecaron' => '667','Kcommaaccent' => '722','C' => '722','florin' => '556','D' => '722','Igrave' => '278','E' => '667','braceright' => '389','F' => '611','G' => '778','Abreve' => '722','H' => '722','germandbls' => '611','I' => '278','J' => '556','K' => '722','L' => '611','adieresis' => '556','M' => '833','lcaron' => '400','braceleft' => '389','N' => '722','O' => '778','P' => '667','Q' => '778','R' => '722','brokenbar' => '280','S' => '667','T' => '611','Lacute' => '611','U' => '722','V' => '667','quoteleft' => '278','Rcommaaccent' => '722','W' => '944','scedilla' => '556','X' => '667','ocircumflex' => '611','Y' => '667','Z' => '611','semicolon' => '333','Dcaron' => '722','Uogonek' => '722','sacute' => '556','dieresis' => '333','Dcroat' => '722','a' => '556','b' => '611','threequarters' => '834','twosuperior' => '333','c' => '556','d' => '611','e' => '556','f' => '333','g' => '611','h' => '611','i' => '278','ograve' => '611','j' => '278','k' => '556','gbreve' => '611','l' => '278','m' => '889','n' => '611','tcommaaccent' => '333','circumflex' => '333','o' => '611','edieresis' => '556','p' => '611','dotlessi' => '278','q' => '611','r' => '389','notequal' => '549','Ohungarumlaut' => '778','s' => '556','t' => '333','u' => '611','Ccaron' => '722','v' => '556','w' => '778','x' => '556','Ucircumflex' => '722','y' => '556','racute' => '389','z' => '500','amacron' => '556','daggerdbl' => '556','Idotaccent' => '278','Eth' => '722','Iogonek' => '278','Atilde' => '722','Lcommaaccent' => '611','gcommaaccent' => '611','greaterequal' => '549','summation' => '600','idieresis' => '278','dollar' => '556','trademark' => '1000','Scommaaccent' => '667','Iacute' => '278','sterling' => '556','currency' => '556','ncommaaccent' => '611','Umacron' => '722','quotedblright' => '500','Odieresis' => '778','yen' => '556','oslash' => '611','backslash' => '278','Egrave' => '667','quotedblleft' => '500','exclamdown' => '333','Tcaron' => '611','Omacron' => '778','eight' => '556','OE' => '1000','oacute' => '611','Zdotaccent' => '611','five' => '556','eogonek' => '556','Thorn' => '667','ordmasculine' => '365','Imacron' => '278','Ccedilla' => '722','icircumflex' => '278','three' => '556','Scaron' => '667','space' => '278','seven' => '556','Uring' => '722','quotesinglbase' => '278','breve' => '333','quotedbl' => '474','zcaron' => '500','degree' => '400','nacute' => '611','uhungarumlaut' => '611','registered' => '737','parenright' => '333','eth' => '611','greater' => '584','AE' => '1000','Zacute' => '611','ogonek' => '333','six' => '556','Tcommaaccent' => '611','hyphen' => '333','questiondown' => '611','ring' => '333','Rcaron' => '722','mu' => '611','guilsinglleft' => '333','guillemotright' => '556','logicalnot' => '584','Ocircumflex' => '778','bullet' => '350','lslash' => '278','udieresis' => '611','ampersand' => '722','dotaccent' => '333','ecaron' => '556','Yacute' => '667','exclam' => '333','igrave' => '278','abreve' => '556','threesuperior' => '333','Eacute' => '667','four' => '556','copyright' => '737','Ugrave' => '722','fraction' => '167','Gcommaaccent' => '778','Agrave' => '722','lacute' => '278','edotaccent' => '556','emacron' => '556','section' => '556','dcaron' => '743','.notdef' => 0,'two' => '556','dcroat' => '611','Otilde' => '778','quotedblbase' => '500','ydieresis' => '556','tilde' => '333','oe' => '944','Ncommaaccent' => '722','ecircumflex' => '556','Adieresis' => '722','lessequal' => '549','macron' => '333','endash' => '556','ccaron' => '556','Ntilde' => '722','Cacute' => '722','uogonek' => '611','bar' => '280','Uhungarumlaut' => '722','Delta' => '612','caron' => '333','ae' => '889','Edieresis' => '667','atilde' => '556','perthousand' => '1000','Aogonek' => '722','onequarter' => '834','Scedilla' => '667','equal' => '584','at' => '975','Ncaron' => '722','minus' => '584','plusminus' => '584','underscore' => '556','quoteright' => '278','ordfeminine' => '370','iacute' => '278','onehalf' => '834','Uacute' => '722','iogonek' => '278','periodcentered' => '278','egrave' => '556','bracketright' => '333','thorn' => '611','Aacute' => '722','Icircumflex' => '278','Idieresis' => '278','onesuperior' => '333','Aring' => '722','acircumflex' => '556','uring' => '611','tcaron' => '389','less' => '584','radical' => '549','percent' => '889','umacron' => '611','Lcaron' => '611','plus' => '584','asciicircum' => '584','asciitilde' => '584','scaron' => '556','dagger' => '556','Amacron' => '722','omacron' => '611','Sacute' => '667','colon' => '333','Ograve' => '778','asterisk' => '389','zacute' => '500','Gbreve' => '778','grave' => '333','Euro' => '556','rcaron' => '389','imacron' => '278','Racute' => '722','comma' => '278','kcommaaccent' => '556','yacute' => '556','guillemotleft' => '556','question' => '611','Ecircumflex' => '667','odieresis' => '611','eacute' => '556','ugrave' => '611','divide' => '584','agrave' => '556','Edotaccent' => '667','ccedilla' => '556','rcommaaccent' => '389','numbersign' => '556','bracketleft' => '333','ucircumflex' => '611','partialdiff' => '494','guilsinglright' => '333','nine' => '556','Udieresis' => '722','quotesingle' => '238','otilde' => '611','Oslash' => '778','paragraph' => '556','slash' => '278','Eogonek' => '667','period' => '278','emdash' => '1000','cent' => '556','one' => '556','fi' => '611','fl' => '611','commaaccent' => '250'},
			'xheight' => '532',
		},
		'helvetica' => {
			'ascender' => '718',
			'capheight' => '718',
			'char' => [undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'space','exclam','quotedbl','numbersign','dollar','percent','ampersand','quoteright','parenleft','parenright','asterisk','plus','comma','hyphen','period','slash','zero','one','two','three','four','five','six','seven','eight','nine','colon','semicolon','less','equal','greater','question','at','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','bracketleft','backslash','bracketright','asciicircum','underscore','quoteleft','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','braceleft','bar','braceright','asciitilde',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'exclamdown','cent','sterling','fraction','yen','florin','section','currency','quotesingle','quotedblleft','guillemotleft','guilsinglleft','guilsinglright','fi','fl',undef,'endash','dagger','daggerdbl','periodcentered',undef,'paragraph','bullet','quotesinglbase','quotedblbase','quotedblright','guillemotright','ellipsis','perthousand',undef,'questiondown',undef,'grave','acute','circumflex','tilde','macron','breve','dotaccent','dieresis',undef,'ring','cedilla',undef,'hungarumlaut','ogonek','caron','emdash',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'AE',undef,'ordfeminine',undef,undef,undef,undef,'Lslash','Oslash','OE','ordmasculine',undef,undef,undef,undef,undef,'ae',undef,undef,undef,'dotlessi',undef,undef,'lslash','oslash','oe','germandbls'],
			'descender' => '-207',
			'fontbbox' => ['-166','-225','1000','931'],
			'fontname' => 'Helvetica',
			'iscore' => 1,
			'isfixedpitch' => 0,
			'italicangle' => '0',
			'missingwidth' => '278',
			'stdhw' => '76',
			'stdvw' => '88',
			'type' => 'Type1',
			'underlineposition' => '-100',
			'underlinethickness' => '50',
			'wx' => {'ntilde' => '556','cacute' => '500','Ydieresis' => '667','Oacute' => '778','zdotaccent' => '500','acute' => '333','lcommaaccent' => '222','ohungarumlaut' => '556','parenleft' => '333','lozenge' => '471','zero' => '556','aring' => '556','ncaron' => '556','Acircumflex' => '667','Zcaron' => '611','Nacute' => '722','scommaaccent' => '500','multiply' => '584','ellipsis' => '1000','uacute' => '556','hungarumlaut' => '333','aogonek' => '556','aacute' => '556','Emacron' => '667','Lslash' => '556','cedilla' => '333','A' => '667','B' => '667','Ecaron' => '667','Kcommaaccent' => '667','C' => '722','florin' => '556','D' => '722','Igrave' => '278','E' => '667','braceright' => '334','F' => '611','G' => '778','Abreve' => '667','H' => '722','germandbls' => '611','I' => '278','J' => '500','K' => '667','L' => '556','adieresis' => '556','M' => '833','lcaron' => '299','braceleft' => '334','N' => '722','O' => '778','P' => '667','Q' => '778','R' => '722','brokenbar' => '260','S' => '667','T' => '611','Lacute' => '556','U' => '722','V' => '667','quoteleft' => '222','Rcommaaccent' => '722','W' => '944','scedilla' => '500','X' => '667','ocircumflex' => '556','Y' => '667','Z' => '611','semicolon' => '278','Dcaron' => '722','Uogonek' => '722','sacute' => '500','dieresis' => '333','Dcroat' => '722','a' => '556','b' => '556','threequarters' => '834','twosuperior' => '333','c' => '500','d' => '556','e' => '556','f' => '278','g' => '556','h' => '556','i' => '222','ograve' => '556','j' => '222','k' => '500','gbreve' => '556','l' => '222','m' => '833','n' => '556','tcommaaccent' => '278','circumflex' => '333','o' => '556','edieresis' => '556','p' => '556','dotlessi' => '278','q' => '556','r' => '333','notequal' => '549','Ohungarumlaut' => '778','s' => '500','t' => '278','u' => '556','Ccaron' => '722','v' => '500','w' => '722','x' => '500','Ucircumflex' => '722','y' => '500','racute' => '333','z' => '500','amacron' => '556','daggerdbl' => '556','Idotaccent' => '278','Eth' => '722','Iogonek' => '278','Atilde' => '667','Lcommaaccent' => '556','gcommaaccent' => '556','greaterequal' => '549','summation' => '600','idieresis' => '278','dollar' => '556','trademark' => '1000','Scommaaccent' => '667','Iacute' => '278','sterling' => '556','currency' => '556','ncommaaccent' => '556','Umacron' => '722','quotedblright' => '333','Odieresis' => '778','yen' => '556','oslash' => '611','backslash' => '278','Egrave' => '667','quotedblleft' => '333','exclamdown' => '333','Tcaron' => '611','Omacron' => '778','eight' => '556','OE' => '1000','oacute' => '556','Zdotaccent' => '611','five' => '556','eogonek' => '556','Thorn' => '667','ordmasculine' => '365','Imacron' => '278','Ccedilla' => '722','icircumflex' => '278','three' => '556','Scaron' => '667','space' => '278','seven' => '556','Uring' => '722','quotesinglbase' => '222','breve' => '333','quotedbl' => '355','zcaron' => '500','degree' => '400','nacute' => '556','uhungarumlaut' => '556','registered' => '737','parenright' => '333','eth' => '556','greater' => '584','AE' => '1000','Zacute' => '611','ogonek' => '333','six' => '556','Tcommaaccent' => '611','hyphen' => '333','questiondown' => '611','ring' => '333','Rcaron' => '722','mu' => '556','guilsinglleft' => '333','guillemotright' => '556','logicalnot' => '584','Ocircumflex' => '778','bullet' => '350','lslash' => '222','udieresis' => '556','ampersand' => '667','dotaccent' => '333','ecaron' => '556','Yacute' => '667','exclam' => '278','igrave' => '278','abreve' => '556','threesuperior' => '333','Eacute' => '667','four' => '556','copyright' => '737','Ugrave' => '722','fraction' => '167','Gcommaaccent' => '778','Agrave' => '667','lacute' => '222','edotaccent' => '556','emacron' => '556','section' => '556','dcaron' => '643','.notdef' => 0,'two' => '556','dcroat' => '556','Otilde' => '778','quotedblbase' => '333','ydieresis' => '500','tilde' => '333','oe' => '944','Ncommaaccent' => '722','ecircumflex' => '556','Adieresis' => '667','lessequal' => '549','macron' => '333','endash' => '556','ccaron' => '500','Ntilde' => '722','Cacute' => '722','uogonek' => '556','bar' => '260','Uhungarumlaut' => '722','Delta' => '612','caron' => '333','ae' => '889','Edieresis' => '667','atilde' => '556','perthousand' => '1000','Aogonek' => '667','onequarter' => '834','Scedilla' => '667','equal' => '584','at' => '1015','Ncaron' => '722','minus' => '584','plusminus' => '584','underscore' => '556','quoteright' => '222','ordfeminine' => '370','iacute' => '278','onehalf' => '834','Uacute' => '722','iogonek' => '222','periodcentered' => '278','egrave' => '556','bracketright' => '278','thorn' => '556','Aacute' => '667','Icircumflex' => '278','Idieresis' => '278','onesuperior' => '333','Aring' => '667','acircumflex' => '556','uring' => '556','tcaron' => '317','less' => '584','radical' => '453','percent' => '889','umacron' => '556','Lcaron' => '556','plus' => '584','asciicircum' => '469','asciitilde' => '584','scaron' => '500','dagger' => '556','Amacron' => '667','omacron' => '556','Sacute' => '667','colon' => '278','Ograve' => '778','asterisk' => '389','zacute' => '500','Gbreve' => '778','grave' => '333','Euro' => '556','rcaron' => '333','imacron' => '278','Racute' => '722','comma' => '278','kcommaaccent' => '500','yacute' => '500','guillemotleft' => '556','question' => '556','Ecircumflex' => '667','odieresis' => '556','eacute' => '556','ugrave' => '556','divide' => '584','agrave' => '556','Edotaccent' => '667','ccedilla' => '500','rcommaaccent' => '333','numbersign' => '556','bracketleft' => '278','ucircumflex' => '556','partialdiff' => '476','guilsinglright' => '333','nine' => '556','Udieresis' => '722','quotesingle' => '191','otilde' => '556','Oslash' => '778','paragraph' => '537','slash' => '278','Eogonek' => '667','period' => '278','emdash' => '1000','cent' => '556','one' => '556','fi' => '500','fl' => '500','commaaccent' => '250'},
			'xheight' => '523',
		},
		'timesbold' => {
			'ascender' => '683',
			'capheight' => '676',
			'char' => [undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'space','exclam','quotedbl','numbersign','dollar','percent','ampersand','quoteright','parenleft','parenright','asterisk','plus','comma','hyphen','period','slash','zero','one','two','three','four','five','six','seven','eight','nine','colon','semicolon','less','equal','greater','question','at','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','bracketleft','backslash','bracketright','asciicircum','underscore','quoteleft','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','braceleft','bar','braceright','asciitilde',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'exclamdown','cent','sterling','fraction','yen','florin','section','currency','quotesingle','quotedblleft','guillemotleft','guilsinglleft','guilsinglright','fi','fl',undef,'endash','dagger','daggerdbl','periodcentered',undef,'paragraph','bullet','quotesinglbase','quotedblbase','quotedblright','guillemotright','ellipsis','perthousand',undef,'questiondown',undef,'grave','acute','circumflex','tilde','macron','breve','dotaccent','dieresis',undef,'ring','cedilla',undef,'hungarumlaut','ogonek','caron','emdash',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'AE',undef,'ordfeminine',undef,undef,undef,undef,'Lslash','Oslash','OE','ordmasculine',undef,undef,undef,undef,undef,'ae',undef,undef,undef,'dotlessi',undef,undef,'lslash','oslash','oe','germandbls'],
			'descender' => '-217',
			'fontbbox' => ['-168','-218','1000','935'],
			'fontname' => 'Times-Bold',
			'iscore' => 1,
			'isfixedpitch' => 0,
			'italicangle' => '0',
			'missingwidth' => '250',
			'stdhw' => '44',
			'stdvw' => '139',
			'type' => 'Type1',
			'underlineposition' => '-100',
			'underlinethickness' => '50',
			'wx' => {'ntilde' => '556','cacute' => '444','Ydieresis' => '722','Oacute' => '778','zdotaccent' => '444','acute' => '333','lcommaaccent' => '278','ohungarumlaut' => '500','parenleft' => '333','lozenge' => '494','zero' => '500','aring' => '500','ncaron' => '556','Acircumflex' => '722','Zcaron' => '667','Nacute' => '722','scommaaccent' => '389','multiply' => '570','ellipsis' => '1000','uacute' => '556','hungarumlaut' => '333','aogonek' => '500','aacute' => '500','Emacron' => '667','Lslash' => '667','cedilla' => '333','A' => '722','B' => '667','Ecaron' => '667','Kcommaaccent' => '778','C' => '722','florin' => '500','D' => '722','Igrave' => '389','E' => '667','braceright' => '394','F' => '611','G' => '778','Abreve' => '722','H' => '778','germandbls' => '556','I' => '389','J' => '500','K' => '778','L' => '667','adieresis' => '500','M' => '944','lcaron' => '394','braceleft' => '394','N' => '722','O' => '778','P' => '611','Q' => '778','R' => '722','brokenbar' => '220','S' => '556','T' => '667','Lacute' => '667','U' => '722','V' => '722','quoteleft' => '333','Rcommaaccent' => '722','W' => '1000','scedilla' => '389','X' => '722','ocircumflex' => '500','Y' => '722','Z' => '667','semicolon' => '333','Dcaron' => '722','Uogonek' => '722','sacute' => '389','dieresis' => '333','Dcroat' => '722','a' => '500','b' => '556','threequarters' => '750','twosuperior' => '300','c' => '444','d' => '556','e' => '444','f' => '333','g' => '500','h' => '556','i' => '278','ograve' => '500','j' => '333','k' => '556','gbreve' => '500','l' => '278','m' => '833','n' => '556','tcommaaccent' => '333','circumflex' => '333','o' => '500','edieresis' => '444','p' => '556','dotlessi' => '278','q' => '556','r' => '444','notequal' => '549','Ohungarumlaut' => '778','s' => '389','t' => '333','u' => '556','Ccaron' => '722','v' => '500','w' => '722','x' => '500','Ucircumflex' => '722','y' => '500','racute' => '444','z' => '444','amacron' => '500','daggerdbl' => '500','Idotaccent' => '389','Eth' => '722','Iogonek' => '389','Atilde' => '722','Lcommaaccent' => '667','gcommaaccent' => '500','greaterequal' => '549','summation' => '600','idieresis' => '278','dollar' => '500','trademark' => '1000','Scommaaccent' => '556','Iacute' => '389','sterling' => '500','currency' => '500','ncommaaccent' => '556','Umacron' => '722','quotedblright' => '500','Odieresis' => '778','yen' => '500','oslash' => '500','backslash' => '278','Egrave' => '667','quotedblleft' => '500','exclamdown' => '333','Tcaron' => '667','Omacron' => '778','eight' => '500','OE' => '1000','oacute' => '500','Zdotaccent' => '667','five' => '500','eogonek' => '444','Thorn' => '611','ordmasculine' => '330','Imacron' => '389','Ccedilla' => '722','icircumflex' => '278','three' => '500','Scaron' => '556','space' => '250','seven' => '500','Uring' => '722','quotesinglbase' => '333','breve' => '333','quotedbl' => '555','zcaron' => '444','degree' => '400','nacute' => '556','uhungarumlaut' => '556','registered' => '747','parenright' => '333','eth' => '500','greater' => '570','AE' => '1000','Zacute' => '667','ogonek' => '333','six' => '500','Tcommaaccent' => '667','hyphen' => '333','questiondown' => '500','ring' => '333','Rcaron' => '722','mu' => '556','guilsinglleft' => '333','guillemotright' => '500','logicalnot' => '570','Ocircumflex' => '778','bullet' => '350','lslash' => '278','udieresis' => '556','ampersand' => '833','dotaccent' => '333','ecaron' => '444','Yacute' => '722','exclam' => '333','igrave' => '278','abreve' => '500','threesuperior' => '300','Eacute' => '667','four' => '500','copyright' => '747','Ugrave' => '722','fraction' => '167','Gcommaaccent' => '778','Agrave' => '722','lacute' => '278','edotaccent' => '444','emacron' => '444','section' => '500','dcaron' => '672','.notdef' => 0,'two' => '500','dcroat' => '556','Otilde' => '778','quotedblbase' => '500','ydieresis' => '500','tilde' => '333','oe' => '722','Ncommaaccent' => '722','ecircumflex' => '444','Adieresis' => '722','lessequal' => '549','macron' => '333','endash' => '500','ccaron' => '444','Ntilde' => '722','Cacute' => '722','uogonek' => '556','bar' => '220','Uhungarumlaut' => '722','Delta' => '612','caron' => '333','ae' => '722','Edieresis' => '667','atilde' => '500','perthousand' => '1000','Aogonek' => '722','onequarter' => '750','Scedilla' => '556','equal' => '570','at' => '930','Ncaron' => '722','minus' => '570','plusminus' => '570','underscore' => '500','quoteright' => '333','ordfeminine' => '300','iacute' => '278','onehalf' => '750','Uacute' => '722','iogonek' => '278','periodcentered' => '250','egrave' => '444','bracketright' => '333','thorn' => '556','Aacute' => '722','Icircumflex' => '389','Idieresis' => '389','onesuperior' => '300','Aring' => '722','acircumflex' => '500','uring' => '556','tcaron' => '416','less' => '570','radical' => '549','percent' => '1000','umacron' => '556','Lcaron' => '667','plus' => '570','asciicircum' => '581','asciitilde' => '520','scaron' => '389','dagger' => '500','Amacron' => '722','omacron' => '500','Sacute' => '556','colon' => '333','Ograve' => '778','asterisk' => '500','zacute' => '444','Gbreve' => '778','grave' => '333','Euro' => '500','rcaron' => '444','imacron' => '278','Racute' => '722','comma' => '250','kcommaaccent' => '556','yacute' => '500','guillemotleft' => '500','question' => '500','Ecircumflex' => '667','odieresis' => '500','eacute' => '444','ugrave' => '556','divide' => '570','agrave' => '500','Edotaccent' => '667','ccedilla' => '444','rcommaaccent' => '444','numbersign' => '500','bracketleft' => '333','ucircumflex' => '556','partialdiff' => '494','guilsinglright' => '333','nine' => '500','Udieresis' => '722','quotesingle' => '278','otilde' => '500','Oslash' => '778','paragraph' => '540','slash' => '278','Eogonek' => '667','period' => '250','emdash' => '1000','cent' => '500','one' => '500','fi' => '556','fl' => '556','commaaccent' => '250'},
			'xheight' => '461',
		},
		'timesroman' => {
			'ascender' => '683',
			'capheight' => '662',
			'char' => [undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'space','exclam','quotedbl','numbersign','dollar','percent','ampersand','quoteright','parenleft','parenright','asterisk','plus','comma','hyphen','period','slash','zero','one','two','three','four','five','six','seven','eight','nine','colon','semicolon','less','equal','greater','question','at','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','bracketleft','backslash','bracketright','asciicircum','underscore','quoteleft','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','braceleft','bar','braceright','asciitilde',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'exclamdown','cent','sterling','fraction','yen','florin','section','currency','quotesingle','quotedblleft','guillemotleft','guilsinglleft','guilsinglright','fi','fl',undef,'endash','dagger','daggerdbl','periodcentered',undef,'paragraph','bullet','quotesinglbase','quotedblbase','quotedblright','guillemotright','ellipsis','perthousand',undef,'questiondown',undef,'grave','acute','circumflex','tilde','macron','breve','dotaccent','dieresis',undef,'ring','cedilla',undef,'hungarumlaut','ogonek','caron','emdash',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'AE',undef,'ordfeminine',undef,undef,undef,undef,'Lslash','Oslash','OE','ordmasculine',undef,undef,undef,undef,undef,'ae',undef,undef,undef,'dotlessi',undef,undef,'lslash','oslash','oe','germandbls'],
			'descender' => '-217',
			'fontbbox' => ['-168','-218','1000','898'],
			'fontname' => 'Times-Roman',
			'iscore' => 1,
			'isfixedpitch' => 0,
			'italicangle' => '0',
			'missingwidth' => '250',
			'stdhw' => '28',
			'stdvw' => '84',
			'type' => 'Type1',
			'underlineposition' => '-100',
			'underlinethickness' => '50',
			'wx' => {'ntilde' => '500','cacute' => '444','Ydieresis' => '722','Oacute' => '722','zdotaccent' => '444','acute' => '333','lcommaaccent' => '278','ohungarumlaut' => '500','parenleft' => '333','lozenge' => '471','zero' => '500','aring' => '444','ncaron' => '500','Acircumflex' => '722','Zcaron' => '611','Nacute' => '722','scommaaccent' => '389','multiply' => '564','ellipsis' => '1000','uacute' => '500','hungarumlaut' => '333','aogonek' => '444','aacute' => '444','Emacron' => '611','Lslash' => '611','cedilla' => '333','A' => '722','B' => '667','Ecaron' => '611','Kcommaaccent' => '722','C' => '667','florin' => '500','D' => '722','Igrave' => '333','E' => '611','braceright' => '480','F' => '556','G' => '722','Abreve' => '722','H' => '722','germandbls' => '500','I' => '333','J' => '389','K' => '722','L' => '611','adieresis' => '444','M' => '889','lcaron' => '344','braceleft' => '480','N' => '722','O' => '722','P' => '556','Q' => '722','R' => '667','brokenbar' => '200','S' => '556','T' => '611','Lacute' => '611','U' => '722','V' => '722','quoteleft' => '333','Rcommaaccent' => '667','W' => '944','scedilla' => '389','X' => '722','ocircumflex' => '500','Y' => '722','Z' => '611','semicolon' => '278','Dcaron' => '722','Uogonek' => '722','sacute' => '389','dieresis' => '333','Dcroat' => '722','a' => '444','b' => '500','threequarters' => '750','twosuperior' => '300','c' => '444','d' => '500','e' => '444','f' => '333','g' => '500','h' => '500','i' => '278','ograve' => '500','j' => '278','k' => '500','gbreve' => '500','l' => '278','m' => '778','n' => '500','tcommaaccent' => '278','circumflex' => '333','o' => '500','edieresis' => '444','p' => '500','dotlessi' => '278','q' => '500','r' => '333','notequal' => '549','Ohungarumlaut' => '722','s' => '389','t' => '278','u' => '500','Ccaron' => '667','v' => '500','w' => '722','x' => '500','Ucircumflex' => '722','y' => '500','racute' => '333','z' => '444','amacron' => '444','daggerdbl' => '500','Idotaccent' => '333','Eth' => '722','Iogonek' => '333','Atilde' => '722','Lcommaaccent' => '611','gcommaaccent' => '500','greaterequal' => '549','summation' => '600','idieresis' => '278','dollar' => '500','trademark' => '980','Scommaaccent' => '556','Iacute' => '333','sterling' => '500','currency' => '500','ncommaaccent' => '500','Umacron' => '722','quotedblright' => '444','Odieresis' => '722','yen' => '500','oslash' => '500','backslash' => '278','Egrave' => '611','quotedblleft' => '444','exclamdown' => '333','Tcaron' => '611','Omacron' => '722','eight' => '500','OE' => '889','oacute' => '500','Zdotaccent' => '611','five' => '500','eogonek' => '444','Thorn' => '556','ordmasculine' => '310','Imacron' => '333','Ccedilla' => '667','icircumflex' => '278','three' => '500','Scaron' => '556','space' => '250','seven' => '500','Uring' => '722','quotesinglbase' => '333','breve' => '333','quotedbl' => '408','zcaron' => '444','degree' => '400','nacute' => '500','uhungarumlaut' => '500','registered' => '760','parenright' => '333','eth' => '500','greater' => '564','AE' => '889','Zacute' => '611','ogonek' => '333','six' => '500','Tcommaaccent' => '611','hyphen' => '333','questiondown' => '444','ring' => '333','Rcaron' => '667','mu' => '500','guilsinglleft' => '333','guillemotright' => '500','logicalnot' => '564','Ocircumflex' => '722','bullet' => '350','lslash' => '278','udieresis' => '500','ampersand' => '778','dotaccent' => '333','ecaron' => '444','Yacute' => '722','exclam' => '333','igrave' => '278','abreve' => '444','threesuperior' => '300','Eacute' => '611','four' => '500','copyright' => '760','Ugrave' => '722','fraction' => '167','Gcommaaccent' => '722','Agrave' => '722','lacute' => '278','edotaccent' => '444','emacron' => '444','section' => '500','dcaron' => '588','.notdef' => 0,'two' => '500','dcroat' => '500','Otilde' => '722','quotedblbase' => '444','ydieresis' => '500','tilde' => '333','oe' => '722','Ncommaaccent' => '722','ecircumflex' => '444','Adieresis' => '722','lessequal' => '549','macron' => '333','endash' => '500','ccaron' => '444','Ntilde' => '722','Cacute' => '667','uogonek' => '500','bar' => '200','Uhungarumlaut' => '722','Delta' => '612','caron' => '333','ae' => '667','Edieresis' => '611','atilde' => '444','perthousand' => '1000','Aogonek' => '722','onequarter' => '750','Scedilla' => '556','equal' => '564','at' => '921','Ncaron' => '722','minus' => '564','plusminus' => '564','underscore' => '500','quoteright' => '333','ordfeminine' => '276','iacute' => '278','onehalf' => '750','Uacute' => '722','iogonek' => '278','periodcentered' => '250','egrave' => '444','bracketright' => '333','thorn' => '500','Aacute' => '722','Icircumflex' => '333','Idieresis' => '333','onesuperior' => '300','Aring' => '722','acircumflex' => '444','uring' => '500','tcaron' => '326','less' => '564','radical' => '453','percent' => '833','umacron' => '500','Lcaron' => '611','plus' => '564','asciicircum' => '469','asciitilde' => '541','scaron' => '389','dagger' => '500','Amacron' => '722','omacron' => '500','Sacute' => '556','colon' => '278','Ograve' => '722','asterisk' => '500','zacute' => '444','Gbreve' => '722','grave' => '333','Euro' => '500','rcaron' => '333','imacron' => '278','Racute' => '667','comma' => '250','kcommaaccent' => '500','yacute' => '500','guillemotleft' => '500','question' => '444','Ecircumflex' => '611','odieresis' => '500','eacute' => '444','ugrave' => '500','divide' => '564','agrave' => '444','Edotaccent' => '611','ccedilla' => '444','rcommaaccent' => '333','numbersign' => '500','bracketleft' => '333','ucircumflex' => '500','partialdiff' => '476','guilsinglright' => '333','nine' => '500','Udieresis' => '722','quotesingle' => '180','otilde' => '500','Oslash' => '722','paragraph' => '453','slash' => '278','Eogonek' => '611','period' => '250','emdash' => '1000','cent' => '500','one' => '500','fi' => '556','fl' => '556','commaaccent' => '250'},
			'xheight' => '450',
		},
		'zapfdingbats' => {
			'ascender' => undef,
			'capheight' => undef,
			'char' => [undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'space','a1','a2','a202','a3','a4','a5','a119','a118','a117','a11','a12','a13','a14','a15','a16','a105','a17','a18','a19','a20','a21','a22','a23','a24','a25','a26','a27','a28','a6','a7','a8','a9','a10','a29','a30','a31','a32','a33','a34','a35','a36','a37','a38','a39','a40','a41','a42','a43','a44','a45','a46','a47','a48','a49','a50','a51','a52','a53','a54','a55','a56','a57','a58','a59','a60','a61','a62','a63','a64','a65','a66','a67','a68','a69','a70','a71','a72','a73','a74','a203','a75','a204','a76','a77','a78','a79','a81','a82','a83','a84','a97','a98','a99','a100',undef,'a89','a90','a93','a94','a91','a92','a205','a85','a206','a86','a87','a88','a95','a96',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'a101','a102','a103','a104','a106','a107','a108','a112','a111','a110','a109','a120','a121','a122','a123','a124','a125','a126','a127','a128','a129','a130','a131','a132','a133','a134','a135','a136','a137','a138','a139','a140','a141','a142','a143','a144','a145','a146','a147','a148','a149','a150','a151','a152','a153','a154','a155','a156','a157','a158','a159','a160','a161','a163','a164','a196','a165','a192','a166','a167','a168','a169','a170','a171','a172','a173','a162','a174','a175','a176','a177','a178','a179','a193','a180','a199','a181','a200','a182',undef,'a201','a183','a184','a197','a185','a194','a198','a186','a195','a187','a188','a189','a190','a191'],
			'descender' => undef,
			'fontbbox' => ['-1','-143','981','820'],
			'fontname' => 'ZapfDingbats',
			'iscore' => 1,
			'isfixedpitch' => 'false',
			'issymbol' => 1,
			'italicangle' => '0',
			'missingwidth' => '278',
			'stdhw' => '28',
			'stdvw' => '90',
			'type' => 'Type1',
			'underlineposition' => '-100',
			'underlinethickness' => '50',
			'wx' => {'a190' => '970','a191' => '918','a192' => '748','a193' => '836','a194' => '771','a195' => '888','a196' => '748','a70' => '785','a197' => '771','a71' => '791','a198' => '888','a72' => '873','a199' => '867','a73' => '761','a74' => '762','a75' => '759','a76' => '892','a77' => '892','a78' => '788','a79' => '784','a120' => '788','a121' => '788','a122' => '788','a123' => '788','a124' => '788','a125' => '788','a1' => '974','a126' => '788','a2' => '961','a127' => '788','a3' => '980','a128' => '788','a4' => '719','a129' => '788','a5' => '789','a6' => '494','a7' => '552','a8' => '537','a9' => '577','.notdef' => 0,'a81' => '438','a82' => '138','a83' => '277','a84' => '415','a85' => '509','a86' => '410','a87' => '234','a200' => '696','a88' => '234','a201' => '874','a89' => '390','a202' => '974','a130' => '788','a203' => '762','a131' => '788','a204' => '759','a132' => '788','a205' => '509','a133' => '788','a206' => '410','a134' => '788','a135' => '788','a136' => '788','a137' => '788','a10' => '692','a138' => '788','a11' => '960','a139' => '788','a12' => '939','a13' => '549','a14' => '855','a15' => '911','a16' => '933','a17' => '945','a18' => '974','a19' => '755','a90' => '390','a91' => '276','a92' => '276','a93' => '317','a94' => '317','a95' => '334','a96' => '334','a97' => '392','a98' => '392','a99' => '668','a140' => '788','a141' => '788','a142' => '788','a143' => '788','a144' => '788','a145' => '788','a146' => '788','a147' => '788','a20' => '846','a148' => '788','a21' => '762','a149' => '788','a22' => '761','a23' => '571','a24' => '677','a25' => '763','a26' => '760','a27' => '759','a28' => '754','a29' => '786','a150' => '788','a151' => '788','a152' => '788','a153' => '788','a154' => '788','a155' => '788','a156' => '788','a157' => '788','a30' => '788','a158' => '788','a31' => '788','a32' => '790','a159' => '788','a33' => '793','a34' => '794','a35' => '816','a36' => '823','a37' => '789','a38' => '841','a39' => '823','a160' => '894','a161' => '838','a162' => '924','a163' => '1016','a164' => '458','a165' => '924','a166' => '918','a167' => '927','a40' => '833','a41' => '816','a168' => '928','a42' => '831','a169' => '928','a43' => '923','a44' => '744','a45' => '723','a46' => '749','a47' => '790','a48' => '792','a49' => '695','a170' => '834','a171' => '873','a172' => '828','a173' => '924','a174' => '917','a175' => '930','a176' => '931','a50' => '776','a177' => '463','a51' => '768','a178' => '883','a52' => '792','a179' => '836','a53' => '759','a54' => '707','a55' => '708','a56' => '682','a57' => '701','a58' => '826','a59' => '815','a100' => '668','a101' => '732','a102' => '544','a103' => '544','a104' => '910','a105' => '911','a106' => '667','a107' => '760','a108' => '760','a109' => '626','space' => '278','a180' => '867','a181' => '696','a182' => '874','a183' => '760','a184' => '946','a185' => '865','a186' => '967','a60' => '789','a187' => '831','a61' => '789','a188' => '873','a62' => '707','a189' => '927','a63' => '687','a64' => '696','a65' => '689','a66' => '786','a67' => '787','a68' => '713','a69' => '791','a110' => '694','a111' => '595','a112' => '776','a117' => '690','a118' => '791','a119' => '790'},
			'xheight' => undef,
		}
	};

}

1;

__END__

=head1 SUPPORTED FONTS

=item PDF::API::CoreFont supports the following 'Adobe Core Fonts':

	Courier 
	Courier-Bold
	Courier-BoldOblique
	Courier-Oblique
	Helvetica 
	Helvetica-Bold
	Helvetica-BoldOblique
	Helvetica-Oblique
	Symbol 
	Times-Bold
	Times-BoldItalic
	Times-Italic
	Times-Roman 
	ZapfDingbats

=item PDF::API::CoreFont supports the following 'Windows Fonts':

	Arial
	Arial,Bold
	Arial,BoldItalic
	Arial,Italic
	BankGothic
	BankGothic,Bold
	BankGothic,BoldItalic
	BankGothic,Italic
	CourierNew
	CourierNew,Bold
	CourierNew,BoldItalic
	CourierNew,Italic
	Georgia
	Georgia,Bold
	Georgia,BoldItalic
	Georgia,Italic
	Impact
	Impact,Italic
	OzHandicraft
	OzHandicraft,Bold
	OzHandicraft,BoldItalic
	OzHandicraft,Italic
	TimesNewRoman
	TimesNewRoman,Bold
	TimesNewRoman,BoldItalic
	TimesNewRoman,Italic
	Trebuchet
	Trebuchet,Bold
	Trebuchet,BoldItalic
	Trebuchet,Italic
	Verdana
	Verdana,Bold
	Verdana,BoldItalic
	Verdana,Italic
	Webdings
	Wingdings

=item PDF::API::CoreFont supports the following 'Unix-ish Fonts' as aliases:

	sans
	sans,bold
	sans,bolditalic
	sans,italic
	serif
	serif,bold
	serif,bolditalic
	serif,italic
	typewriter
	typewriter,bold
	typewriter,bolditalic
	typewriter,italic
	greek
	bats

=head1 AUTHOR

alfred reibenschuh

=cut


