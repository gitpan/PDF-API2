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
	( $VERSION ) = '$Revisioning: 0.3a1 $' =~ /\$Revisioning:\s+([^\s]+)/;
}

use strict;

use PDF::API2::UniMap;
use PDF::API2::Util;
use Text::PDF::Utils;
use Text::PDF::Dict;

@ISA = qw( Text::PDF::Dict );

=head1 PDF::API2::CoreFont

PDF::API2::CoreFont - a perl-module providing core-font objects for both 
Text::PDF and PDF::API2.

=head2 SYNOPSIS

	use PDF::API2;
	use PDF::API2::CoreFont;
	
	$api = PDF::API2->new;
	...
	$font = PDF::API2::CoreFont->new_api($api,'Helvetica', -encoding => 'latin1'); 

OR
	
	use Text::PDF::File;
	use PDF::API2::CoreFont;
	
	$pdf = Text::PDF::File->new('some.pdf');
	...
	$font = PDF::API2::CoreFont->new($pdf,'Helvetica', -encoding => 'latin1', -pdfname => 'F0'); 

=head2 METHODS

=item $font = PDF::API2::CoreFont->new $pdf, $fontname, %options

Returns a corefont object.

Valid %options are:

	'-encoding' ... changes the encoding of the font from its default.

	'-pdfname' ... changes the reference-name of the font from its default.

B<On '-encoding':> The natively supported encodings are 'latin1','winansi' and 'macroman'.
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
	$lookname=~s/[^a-z0-9]+//cgi;
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
	$self->{' apiname'} = 'cFx'.pdfkey($self->{' data'}->{fontname},%opts);
	$self->{'Name'} = PDFName($self->{' apiname'});

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

	$self->encode($opts{-encoding});

	if(defined($pdf) && !$self->is_obj($pdf)) {
		$pdf->new_obj($self);
	}

	return($self);
}

=item $font = PDF::API2::CoreFont->new_api $api, $fontname, %options

Returns a corefont object. This method is different from 'new' that
it needs an PDF::API2-object rather than a Text::PDF::File-object.

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
	my ($font,$text)=@_;
	my $newtext='';
	foreach my $g (0..length($text)-1) {
		$newtext.=
			(substr($text,$g,1)=~/[\x00-\x1f\\\{\}\[\]\(\)]/)
			? sprintf('\%03lo',vec($text,$g,8))
			: substr($text,$g,1) ;
	}
	return("($newtext)");
}

=item $pdfstring = $font->text_hex $text

Returns a properly formated hex-representation of $text
for use in the PDF.

=cut

sub text_hex {
	my ($font,$text)=@_;
	my $newtext='';
	foreach (unpack("C*", $text)) {
		$newtext.= sprintf('%02X',$_);
	}
	return('<'.$newtext.'>');
}

=item $wd = $font->width $text

Returns the width of $text as if it were at size 1.

=cut

sub width {
	my ($self,$text)=@_;
	my $width=0;
	foreach (unpack("C*", $text)) {
		$width += $self->{' data'}{'wx'}{$self->{' data'}{'char'}[$_] || 'space'} || $self->{' data'}{'wx'}{space};
	}
	$width/=1000;
	return($width);
}

=item @widths = $font->width_array $text

Returns the widths of the words in $text as if they were at size 1.

=cut

sub width_array {
	my ($self,$text)=@_;
	my @text=split(/\s+/,$text);
	my @widths=map {$self->width($_)} @text;
	return(@widths);
}

=item ($llx,$lly,$urx,$ury) = $font->bbox $text

Returns the texts bounding-box as if it were at size 1.

=cut

sub bbox {
	my ($self,$text)=@_;
	my $width=$self->width(substr($text,0,length($text)-1));
	my @f=@{$self->{' data'}{'bbox'}{$self->{' data'}{'char'}[unpack("C",substr($text,0,1))] || 'space'}};
	my @l=@{$self->{' data'}{'bbox'}{$self->{' data'}{'char'}[unpack("C",substr($text,-1,1))] || 'space'}};
	my ($high,$low);
	foreach (unpack("C*", $text)) {
		$high = $self->{' data'}{'bbox'}{$self->{' data'}{'char'}[$_] || 'space'}->[3]>$high ? $self->{' data'}{'bbox'}{$self->{' data'}{'char'}[$_] || 'space'}->[3] : $high;
		$low  = $self->{' data'}{'bbox'}{$self->{' data'}{'char'}[$_] || 'space'}->[1]<$low  ? $self->{' data'}{'bbox'}{$self->{' data'}{'char'}[$_] || 'space'}->[1] : $low;
	}
	return map {$_/1000} ($f[0],$low,(($width*1000)+$l[2]),$high);
}

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
		PDFNum($self->{' data'}->{'wx'}{$_ || '.notdef'} || 300) 
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
	
		'times'				=> 'timesroman',
		'timesnewromanbolditalic'	=> 'timesbolditalic',
		'timesnewromanbold'		=> 'timesbold',
		'timesnewromanitalic'		=> 'timesitalic',
		'timesnewroman'			=> 'timesroman',
	
		'arialbolditalic'		=> 'helveticaboldoblique',
		'arialbold'			=> 'helveticabold',
		'arialitalic'			=> 'helveticaoblique',
		'arial'				=> 'helvetica',
	
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
			'bbox' => {'ntilde' => ['65','0','546','737'],'cacute' => ['34','-14','524','750'],'Ydieresis' => ['15','0','653','915'],'Oacute' => ['44','-19','734','936'],'zdotaccent' => ['20','0','480','729'],'acute' => ['108','604','356','750'],'lcommaaccent' => ['69','-228','213','718'],'ohungarumlaut' => ['34','-14','625','750'],'parenleft' => ['35','-208','314','734'],'lozenge' => ['10','0','484','745'],'zero' => ['32','-19','524','710'],'aring' => ['29','-14','527','776'],'ncaron' => ['65','0','546','750'],'Acircumflex' => ['20','0','702','936'],'Zcaron' => ['25','0','586','936'],'Nacute' => ['69','0','654','936'],'scommaaccent' => ['30','-228','519','546'],'multiply' => ['40','1','545','505'],'ellipsis' => ['92','0','908','146'],'uacute' => ['66','-14','545','750'],'hungarumlaut' => ['9','604','486','750'],'aogonek' => ['29','-224','545','546'],'aacute' => ['29','-14','527','750'],'Emacron' => ['76','0','621','864'],'Lslash' => ['-20','0','583','718'],'cedilla' => ['6','-228','245','0'],'A' => ['20','0','702','718'],'B' => ['76','0','669','718'],'Ecaron' => ['76','0','621','936'],'Kcommaaccent' => ['87','-228','722','718'],'C' => ['44','-19','684','737'],'florin' => ['-10','-210','516','737'],'D' => ['76','0','685','718'],'Igrave' => ['-50','0','214','936'],'E' => ['76','0','621','718'],'braceright' => ['24','-196','341','722'],'F' => ['76','0','587','718'],'G' => ['44','-19','713','737'],'Abreve' => ['20','0','702','936'],'H' => ['71','0','651','718'],'germandbls' => ['69','-14','579','731'],'I' => ['64','0','214','718'],'J' => ['22','-18','484','718'],'K' => ['87','0','722','718'],'L' => ['76','0','583','718'],'adieresis' => ['29','-14','527','729'],'M' => ['69','0','765','718'],'lcaron' => ['69','0','408','718'],'braceleft' => ['48','-196','365','722'],'N' => ['69','0','654','718'],'O' => ['44','-19','734','737'],'P' => ['76','0','627','718'],'Q' => ['44','-52','737','737'],'R' => ['76','0','677','718'],'brokenbar' => ['84','-150','196','700'],'S' => ['39','-19','629','737'],'T' => ['14','0','598','718'],'Lacute' => ['76','0','583','936'],'U' => ['72','-19','651','718'],'V' => ['19','0','648','718'],'quoteleft' => ['69','454','209','727'],'Rcommaaccent' => ['76','-228','677','718'],'W' => ['16','0','929','718'],'X' => ['14','0','653','718'],'scedilla' => ['30','-228','519','546'],'Y' => ['15','0','653','718'],'ocircumflex' => ['34','-14','578','750'],'Z' => ['25','0','586','718'],'semicolon' => ['92','-168','242','512'],'Dcaron' => ['76','0','685','936'],'Uogonek' => ['72','-228','651','718'],'dieresis' => ['6','614','327','729'],'sacute' => ['30','-14','519','750'],'a' => ['29','-14','527','546'],'Dcroat' => ['-5','0','685','718'],'b' => ['61','-14','578','718'],'c' => ['34','-14','524','546'],'twosuperior' => ['9','283','324','710'],'threequarters' => ['16','-19','799','710'],'d' => ['34','-14','551','718'],'e' => ['23','-14','528','546'],'f' => ['10','0','318','727'],'g' => ['40','-217','553','546'],'h' => ['65','0','546','718'],'i' => ['69','0','209','725'],'j' => ['3','-214','209','725'],'ograve' => ['34','-14','578','750'],'k' => ['69','0','562','718'],'l' => ['69','0','209','718'],'gbreve' => ['40','-217','553','750'],'m' => ['64','0','826','546'],'n' => ['65','0','546','546'],'o' => ['34','-14','578','546'],'circumflex' => ['-10','604','343','750'],'tcommaaccent' => ['10','-228','309','676'],'p' => ['62','-207','578','546'],'edieresis' => ['23','-14','528','729'],'q' => ['34','-207','552','546'],'dotlessi' => ['69','0','209','532'],'r' => ['64','0','373','546'],'s' => ['30','-14','519','546'],'Ohungarumlaut' => ['44','-19','734','936'],'notequal' => ['15','-49','540','570'],'t' => ['10','-6','309','676'],'u' => ['66','-14','545','532'],'v' => ['13','0','543','532'],'Ccaron' => ['44','-19','684','936'],'w' => ['10','0','769','532'],'x' => ['15','0','541','532'],'y' => ['10','-214','539','532'],'Ucircumflex' => ['72','-19','651','936'],'z' => ['20','0','480','532'],'racute' => ['64','0','384','750'],'amacron' => ['29','-14','527','678'],'daggerdbl' => ['36','-171','520','718'],'Idotaccent' => ['64','0','214','915'],'Eth' => ['-5','0','685','718'],'Iogonek' => ['-11','-228','222','718'],'Atilde' => ['20','0','702','923'],'Lcommaaccent' => ['76','-228','583','718'],'gcommaaccent' => ['40','-217','553','850'],'greaterequal' => ['26','0','523','704'],'summation' => ['14','-10','585','706'],'idieresis' => ['-21','0','300','729'],'dollar' => ['30','-115','523','775'],'trademark' => ['44','306','956','718'],'Scommaaccent' => ['39','-228','629','737'],'Iacute' => ['64','0','329','936'],'sterling' => ['28','-16','541','718'],'currency' => ['-3','76','559','636'],'Umacron' => ['72','-19','651','864'],'ncommaaccent' => ['65','-228','546','546'],'quotedblright' => ['64','445','436','718'],'yen' => ['-9','0','565','698'],'Odieresis' => ['44','-19','734','915'],'backslash' => ['-33','-19','311','737'],'oslash' => ['22','-29','589','560'],'Egrave' => ['76','0','621','936'],'quotedblleft' => ['64','454','436','727'],'exclamdown' => ['90','-186','244','532'],'Omacron' => ['44','-19','734','864'],'Tcaron' => ['14','0','598','936'],'eight' => ['32','-19','524','710'],'OE' => ['37','-19','961','737'],'oacute' => ['34','-14','578','750'],'Zdotaccent' => ['25','0','586','915'],'five' => ['27','-19','516','698'],'eogonek' => ['23','-228','528','546'],'ordmasculine' => ['6','401','360','737'],'Thorn' => ['76','0','627','718'],'Imacron' => ['-33','0','312','864'],'icircumflex' => ['-37','0','316','750'],'Ccedilla' => ['44','-228','684','737'],'three' => ['27','-19','516','710'],'Scaron' => ['39','-19','629','936'],'space' => ['0','0','0','0'],'seven' => ['25','0','528','698'],'Uring' => ['72','-19','651','962'],'quotesinglbase' => ['69','-146','209','127'],'breve' => ['-2','604','335','750'],'quotedbl' => ['98','447','376','718'],'uhungarumlaut' => ['66','-14','625','750'],'nacute' => ['65','0','546','750'],'degree' => ['57','426','343','712'],'zcaron' => ['20','0','480','750'],'registered' => ['-11','-19','748','737'],'parenright' => ['19','-208','298','734'],'greater' => ['38','-8','546','514'],'eth' => ['34','-14','578','737'],'AE' => ['5','0','954','718'],'ogonek' => ['71','-228','304','0'],'Zacute' => ['25','0','586','936'],'six' => ['31','-19','520','710'],'questiondown' => ['55','-195','551','532'],'hyphen' => ['27','215','306','345'],'Tcommaaccent' => ['14','-228','598','718'],'ring' => ['59','568','275','776'],'Rcaron' => ['76','0','677','936'],'mu' => ['66','-207','545','532'],'guillemotright' => ['88','76','468','484'],'guilsinglleft' => ['83','76','250','484'],'Ocircumflex' => ['44','-19','734','936'],'logicalnot' => ['40','108','544','419'],'bullet' => ['10','194','340','524'],'lslash' => ['-18','0','296','718'],'udieresis' => ['66','-14','545','729'],'ampersand' => ['54','-19','701','718'],'dotaccent' => ['104','614','230','729'],'ecaron' => ['23','-14','528','750'],'Yacute' => ['15','0','653','936'],'exclam' => ['90','0','244','718'],'igrave' => ['-50','0','209','750'],'abreve' => ['29','-14','527','750'],'threesuperior' => ['8','271','326','710'],'Eacute' => ['76','0','621','936'],'four' => ['27','0','526','710'],'copyright' => ['-11','-19','749','737'],'Ugrave' => ['72','-19','651','936'],'fraction' => ['-170','-19','336','710'],'Gcommaaccent' => ['44','-228','713','737'],'Agrave' => ['20','0','702','936'],'lacute' => ['69','0','329','936'],'edotaccent' => ['23','-14','528','729'],'emacron' => ['23','-14','528','678'],'section' => ['34','-184','522','727'],'dcaron' => ['34','-14','750','718'],'.notdef' => ['0','0','0','0'],'two' => ['26','0','511','710'],'dcroat' => ['34','-14','650','718'],'Otilde' => ['44','-19','734','923'],'quotedblbase' => ['64','-146','436','127'],'ydieresis' => ['10','-214','539','729'],'tilde' => ['-17','610','350','737'],'oe' => ['34','-14','912','546'],'Ncommaaccent' => ['69','-228','654','718'],'ecircumflex' => ['23','-14','528','750'],'Adieresis' => ['20','0','702','915'],'lessequal' => ['29','0','526','704'],'macron' => ['-6','604','339','678'],'endash' => ['0','227','556','333'],'ccaron' => ['34','-14','524','750'],'Ntilde' => ['69','0','654','923'],'Cacute' => ['44','-19','684','936'],'uogonek' => ['66','-228','545','532'],'bar' => ['84','-225','196','775'],'Uhungarumlaut' => ['72','-19','681','936'],'Delta' => ['6','0','608','688'],'caron' => ['-10','604','343','750'],'ae' => ['29','-14','858','546'],'Edieresis' => ['76','0','621','915'],'atilde' => ['29','-14','527','737'],'perthousand' => ['-3','-19','1003','710'],'Aogonek' => ['20','-224','742','718'],'onequarter' => ['26','-19','766','710'],'Scedilla' => ['39','-228','629','737'],'equal' => ['40','87','544','419'],'at' => ['118','-19','856','737'],'Ncaron' => ['69','0','654','936'],'minus' => ['40','197','544','309'],'plusminus' => ['40','0','544','506'],'underscore' => ['0','-125','556','-75'],'quoteright' => ['69','445','209','718'],'ordfeminine' => ['22','401','347','737'],'iacute' => ['69','0','329','750'],'onehalf' => ['26','-19','794','710'],'Uacute' => ['72','-19','651','936'],'iogonek' => ['16','-224','249','725'],'periodcentered' => ['58','172','220','334'],'egrave' => ['23','-14','528','750'],'bracketright' => ['24','-196','270','722'],'thorn' => ['62','-208','578','718'],'Aacute' => ['20','0','702','936'],'Icircumflex' => ['-37','0','316','936'],'Idieresis' => ['-21','0','300','915'],'onesuperior' => ['26','283','237','710'],'Aring' => ['20','0','702','962'],'acircumflex' => ['29','-14','527','750'],'uring' => ['66','-14','545','776'],'tcaron' => ['10','-6','421','878'],'less' => ['38','-8','546','514'],'radical' => ['10','-46','512','850'],'percent' => ['28','-19','861','710'],'umacron' => ['66','-14','545','678'],'plus' => ['40','0','544','506'],'Lcaron' => ['76','0','583','718'],'asciicircum' => ['62','323','522','698'],'scaron' => ['30','-14','519','750'],'asciitilde' => ['61','163','523','343'],'dagger' => ['36','-171','520','718'],'Amacron' => ['20','0','702','864'],'omacron' => ['34','-14','578','678'],'Sacute' => ['39','-19','629','936'],'colon' => ['92','0','242','512'],'Ograve' => ['44','-19','734','936'],'zacute' => ['20','0','480','750'],'asterisk' => ['27','387','362','718'],'Gbreve' => ['44','-19','713','936'],'grave' => ['-23','604','225','750'],'Euro' => ['0','0','0','0'],'rcaron' => ['18','0','373','750'],'imacron' => ['-8','0','285','678'],'Racute' => ['76','0','677','936'],'comma' => ['64','-168','214','146'],'kcommaaccent' => ['69','-228','562','718'],'yacute' => ['10','-214','539','750'],'guillemotleft' => ['88','76','468','484'],'question' => ['60','0','556','727'],'Ecircumflex' => ['76','0','621','936'],'eacute' => ['23','-14','528','750'],'odieresis' => ['34','-14','578','729'],'ugrave' => ['66','-14','545','750'],'agrave' => ['29','-14','527','750'],'divide' => ['40','-42','544','548'],'ccedilla' => ['34','-228','524','546'],'Edotaccent' => ['76','0','621','915'],'rcommaaccent' => ['64','-228','373','546'],'numbersign' => ['18','0','538','698'],'ucircumflex' => ['66','-14','545','750'],'bracketleft' => ['63','-196','309','722'],'partialdiff' => ['11','-21','494','750'],'nine' => ['30','-19','522','710'],'guilsinglright' => ['83','76','250','484'],'Udieresis' => ['72','-19','651','915'],'quotesingle' => ['70','447','168','718'],'otilde' => ['34','-14','578','737'],'Oslash' => ['33','-27','744','745'],'paragraph' => ['-8','-191','539','700'],'slash' => ['-33','-19','311','737'],'Eogonek' => ['76','-224','639','718'],'period' => ['64','0','214','146'],'emdash' => ['0','227','1000','333'],'one' => ['69','0','378','710'],'cent' => ['34','-118','524','628'],'fi' => ['10','0','542','727'],'commaaccent' => ['64','-228','199','-50'],'fl' => ['10','0','542','727']},
			'capheight' => '718',
			'char' => [undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'space','exclam','quotedbl','numbersign','dollar','percent','ampersand','quoteright','parenleft','parenright','asterisk','plus','comma','hyphen','period','slash','zero','one','two','three','four','five','six','seven','eight','nine','colon','semicolon','less','equal','greater','question','at','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','bracketleft','backslash','bracketright','asciicircum','underscore','quoteleft','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','braceleft','bar','braceright','asciitilde',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'exclamdown','cent','sterling','fraction','yen','florin','section','currency','quotesingle','quotedblleft','guillemotleft','guilsinglleft','guilsinglright','fi','fl',undef,'endash','dagger','daggerdbl','periodcentered',undef,'paragraph','bullet','quotesinglbase','quotedblbase','quotedblright','guillemotright','ellipsis','perthousand',undef,'questiondown',undef,'grave','acute','circumflex','tilde','macron','breve','dotaccent','dieresis',undef,'ring','cedilla',undef,'hungarumlaut','ogonek','caron','emdash',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'AE',undef,'ordfeminine',undef,undef,undef,undef,'Lslash','Oslash','OE','ordmasculine',undef,undef,undef,undef,undef,'ae',undef,undef,undef,'dotlessi',undef,undef,'lslash','oslash','oe','germandbls'],
			'descender' => '-207',
			'fontbbox' => ['-170','-228','1003','962'],
			'fontname' => 'Helvetica-Bold',
			'iscore' => 1,
			'isfixedpitch' => 0,
			'italicangle' => '0',
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
			'bbox' => {'ntilde' => ['65','0','491','722'],'cacute' => ['30','-15','477','734'],'Ydieresis' => ['14','0','653','901'],'Oacute' => ['39','-19','739','929'],'zdotaccent' => ['31','0','469','706'],'acute' => ['122','593','319','734'],'lcommaaccent' => ['67','-225','167','718'],'ohungarumlaut' => ['35','-14','521','734'],'parenleft' => ['68','-207','299','733'],'lozenge' => ['10','0','462','728'],'zero' => ['37','-19','519','703'],'aring' => ['36','-15','530','756'],'ncaron' => ['65','0','491','734'],'Acircumflex' => ['14','0','654','929'],'Zcaron' => ['23','0','588','929'],'Nacute' => ['76','0','646','929'],'scommaaccent' => ['32','-225','464','538'],'multiply' => ['39','0','545','506'],'ellipsis' => ['115','0','885','106'],'uacute' => ['68','-15','489','734'],'hungarumlaut' => ['31','593','409','734'],'aogonek' => ['36','-220','547','538'],'aacute' => ['36','-15','530','734'],'Emacron' => ['86','0','616','879'],'Lslash' => ['-20','0','537','718'],'cedilla' => ['45','-225','259','0'],'A' => ['14','0','654','718'],'B' => ['74','0','627','718'],'Ecaron' => ['86','0','616','929'],'Kcommaaccent' => ['76','-225','663','718'],'C' => ['44','-19','681','737'],'florin' => ['-11','-207','501','737'],'D' => ['81','0','674','718'],'Igrave' => ['-13','0','188','929'],'E' => ['86','0','616','718'],'braceright' => ['42','-196','292','722'],'F' => ['86','0','583','718'],'G' => ['48','-19','704','737'],'Abreve' => ['14','0','654','926'],'H' => ['77','0','646','718'],'germandbls' => ['67','-15','571','728'],'I' => ['91','0','188','718'],'J' => ['17','-19','428','718'],'K' => ['76','0','663','718'],'L' => ['76','0','537','718'],'adieresis' => ['36','-15','530','706'],'M' => ['73','0','761','718'],'lcaron' => ['67','0','311','718'],'braceleft' => ['42','-196','292','722'],'N' => ['76','0','646','718'],'O' => ['39','-19','739','737'],'P' => ['86','0','622','718'],'Q' => ['39','-56','739','737'],'R' => ['88','0','684','718'],'brokenbar' => ['94','-150','167','700'],'S' => ['49','-19','620','737'],'T' => ['14','0','597','718'],'Lacute' => ['76','0','537','929'],'U' => ['79','-19','644','718'],'V' => ['20','0','647','718'],'quoteleft' => ['65','470','169','725'],'Rcommaaccent' => ['88','-225','684','718'],'W' => ['16','0','928','718'],'X' => ['19','0','648','718'],'scedilla' => ['32','-225','464','538'],'Y' => ['14','0','653','718'],'ocircumflex' => ['35','-14','521','734'],'Z' => ['23','0','588','718'],'semicolon' => ['87','-147','191','516'],'Dcaron' => ['81','0','674','929'],'Uogonek' => ['79','-225','644','718'],'dieresis' => ['40','604','293','706'],'sacute' => ['32','-15','464','734'],'a' => ['36','-15','530','538'],'Dcroat' => ['0','0','674','718'],'b' => ['58','-15','517','718'],'c' => ['30','-15','477','538'],'twosuperior' => ['4','281','323','703'],'threequarters' => ['45','-19','810','703'],'d' => ['35','-15','499','718'],'e' => ['40','-15','516','538'],'f' => ['14','0','262','728'],'g' => ['40','-220','499','538'],'h' => ['65','0','491','718'],'i' => ['67','0','155','718'],'j' => ['-16','-210','155','718'],'ograve' => ['35','-14','521','734'],'k' => ['67','0','501','718'],'l' => ['67','0','155','718'],'gbreve' => ['40','-220','499','731'],'m' => ['65','0','769','538'],'n' => ['65','0','491','538'],'o' => ['35','-14','521','538'],'circumflex' => ['21','593','312','734'],'tcommaaccent' => ['14','-225','257','669'],'p' => ['58','-207','517','538'],'edieresis' => ['40','-15','516','706'],'q' => ['35','-207','494','538'],'dotlessi' => ['95','0','183','523'],'r' => ['77','0','332','538'],'s' => ['32','-15','464','538'],'Ohungarumlaut' => ['39','-19','739','929'],'notequal' => ['12','-35','537','551'],'t' => ['14','-7','257','669'],'u' => ['68','-15','489','523'],'v' => ['8','0','492','523'],'Ccaron' => ['44','-19','681','929'],'w' => ['14','0','709','523'],'x' => ['11','0','490','523'],'y' => ['11','-214','489','523'],'Ucircumflex' => ['79','-19','644','929'],'z' => ['31','0','469','523'],'racute' => ['77','0','332','734'],'amacron' => ['36','-15','530','684'],'daggerdbl' => ['43','-159','514','718'],'Idotaccent' => ['91','0','188','901'],'Eth' => ['0','0','674','718'],'Iogonek' => ['-3','-225','211','718'],'Atilde' => ['14','0','654','917'],'Lcommaaccent' => ['76','-225','537','718'],'gcommaaccent' => ['40','-220','499','822'],'greaterequal' => ['26','0','523','674'],'summation' => ['15','-10','586','706'],'idieresis' => ['13','0','266','706'],'dollar' => ['32','-115','520','775'],'trademark' => ['46','306','903','718'],'Scommaaccent' => ['49','-225','620','737'],'Iacute' => ['91','0','292','929'],'sterling' => ['33','-16','539','718'],'currency' => ['28','99','528','603'],'Umacron' => ['79','-19','644','879'],'ncommaaccent' => ['65','-225','491','538'],'quotedblright' => ['26','463','295','718'],'yen' => ['3','0','553','688'],'Odieresis' => ['39','-19','739','901'],'backslash' => ['-17','-19','295','737'],'oslash' => ['28','-22','537','545'],'Egrave' => ['86','0','616','929'],'quotedblleft' => ['38','470','307','725'],'exclamdown' => ['118','-195','215','523'],'Omacron' => ['39','-19','739','879'],'Tcaron' => ['14','0','597','929'],'eight' => ['38','-19','517','703'],'OE' => ['36','-19','965','737'],'oacute' => ['35','-14','521','734'],'Zdotaccent' => ['23','0','588','901'],'five' => ['32','-19','514','688'],'eogonek' => ['40','-225','516','538'],'ordmasculine' => ['25','405','341','737'],'Thorn' => ['86','0','622','718'],'Imacron' => ['-17','0','296','879'],'icircumflex' => ['-6','0','285','734'],'Ccedilla' => ['44','-225','681','737'],'three' => ['34','-19','522','703'],'Scaron' => ['49','-19','620','929'],'space' => ['0','0','0','0'],'seven' => ['37','0','523','688'],'Uring' => ['79','-19','644','931'],'quotesinglbase' => ['53','-149','157','106'],'breve' => ['13','595','321','731'],'quotedbl' => ['70','463','285','718'],'uhungarumlaut' => ['68','-15','521','734'],'nacute' => ['65','0','491','734'],'degree' => ['54','411','346','703'],'zcaron' => ['31','0','469','734'],'registered' => ['-14','-19','752','737'],'parenright' => ['34','-207','265','733'],'greater' => ['48','11','536','495'],'eth' => ['35','-15','522','737'],'AE' => ['8','0','951','718'],'ogonek' => ['73','-225','287','0'],'Zacute' => ['23','0','588','929'],'six' => ['38','-19','518','703'],'questiondown' => ['91','-201','527','525'],'hyphen' => ['44','232','289','322'],'Tcommaaccent' => ['14','-225','597','718'],'ring' => ['75','572','259','756'],'Rcaron' => ['88','0','684','929'],'mu' => ['68','-207','489','523'],'guillemotright' => ['97','108','459','446'],'guilsinglleft' => ['88','108','245','446'],'Ocircumflex' => ['39','-19','739','929'],'logicalnot' => ['39','108','545','390'],'bullet' => ['18','202','333','517'],'lslash' => ['-20','0','242','718'],'udieresis' => ['68','-15','489','706'],'ampersand' => ['44','-15','645','718'],'dotaccent' => ['121','604','212','706'],'ecaron' => ['40','-15','516','734'],'Yacute' => ['14','0','653','929'],'exclam' => ['90','0','187','718'],'igrave' => ['-13','0','184','734'],'abreve' => ['36','-15','530','731'],'threesuperior' => ['5','270','325','703'],'Eacute' => ['86','0','616','929'],'four' => ['25','0','523','703'],'copyright' => ['-14','-19','752','737'],'Ugrave' => ['79','-19','644','929'],'fraction' => ['-166','-19','333','703'],'Gcommaaccent' => ['48','-225','704','737'],'Agrave' => ['14','0','654','929'],'lacute' => ['67','0','264','929'],'edotaccent' => ['40','-15','516','706'],'emacron' => ['40','-15','516','684'],'section' => ['43','-191','512','737'],'dcaron' => ['35','-15','655','718'],'.notdef' => ['0','0','0','0'],'two' => ['26','0','507','703'],'dcroat' => ['35','-15','550','718'],'Otilde' => ['39','-19','739','917'],'quotedblbase' => ['26','-149','295','106'],'ydieresis' => ['11','-214','489','706'],'tilde' => ['-4','606','337','722'],'oe' => ['35','-15','902','538'],'Ncommaaccent' => ['76','-225','646','718'],'ecircumflex' => ['40','-15','516','734'],'Adieresis' => ['14','0','654','901'],'lessequal' => ['26','0','523','674'],'macron' => ['10','627','323','684'],'endash' => ['0','240','556','313'],'ccaron' => ['30','-15','477','734'],'Ntilde' => ['76','0','646','917'],'Cacute' => ['44','-19','681','929'],'uogonek' => ['68','-225','519','523'],'bar' => ['94','-225','167','775'],'Uhungarumlaut' => ['79','-19','644','929'],'Delta' => ['6','0','608','688'],'caron' => ['21','593','312','734'],'ae' => ['36','-15','847','538'],'Edieresis' => ['86','0','616','901'],'atilde' => ['36','-15','530','722'],'perthousand' => ['7','-19','994','703'],'Aogonek' => ['14','-225','654','718'],'onequarter' => ['73','-19','756','703'],'Scedilla' => ['49','-225','620','737'],'equal' => ['39','115','545','390'],'at' => ['147','-19','868','737'],'Ncaron' => ['76','0','646','929'],'minus' => ['39','216','545','289'],'plusminus' => ['39','0','545','506'],'underscore' => ['0','-125','556','-75'],'quoteright' => ['53','463','157','718'],'ordfeminine' => ['24','405','346','737'],'iacute' => ['95','0','292','734'],'onehalf' => ['43','-19','773','703'],'Uacute' => ['79','-19','644','929'],'iogonek' => ['-31','-225','183','718'],'periodcentered' => ['77','190','202','315'],'egrave' => ['40','-15','516','734'],'bracketright' => ['28','-196','215','722'],'thorn' => ['58','-207','517','718'],'Aacute' => ['14','0','654','929'],'Icircumflex' => ['-6','0','285','929'],'Idieresis' => ['13','0','266','901'],'onesuperior' => ['43','281','222','703'],'Aring' => ['14','0','654','931'],'acircumflex' => ['36','-15','530','734'],'uring' => ['68','-15','489','756'],'tcaron' => ['14','-7','329','808'],'less' => ['48','11','536','495'],'radical' => ['-4','-80','458','762'],'percent' => ['39','-19','850','703'],'umacron' => ['68','-15','489','684'],'plus' => ['39','0','545','505'],'Lcaron' => ['76','0','537','718'],'asciicircum' => ['-14','264','483','688'],'scaron' => ['32','-15','464','734'],'asciitilde' => ['61','180','523','326'],'dagger' => ['43','-159','514','718'],'Amacron' => ['14','0','654','879'],'omacron' => ['35','-14','521','684'],'Sacute' => ['49','-19','620','929'],'colon' => ['87','0','191','516'],'Ograve' => ['39','-19','739','929'],'zacute' => ['31','0','469','734'],'asterisk' => ['39','431','349','718'],'Gbreve' => ['48','-19','704','926'],'grave' => ['14','593','211','734'],'Euro' => ['0','0','0','0'],'rcaron' => ['61','0','352','734'],'imacron' => ['5','0','272','684'],'Racute' => ['88','0','684','929'],'comma' => ['87','-147','191','106'],'kcommaaccent' => ['67','-225','501','718'],'yacute' => ['11','-214','489','734'],'guillemotleft' => ['97','108','459','446'],'question' => ['56','0','492','727'],'Ecircumflex' => ['86','0','616','929'],'eacute' => ['40','-15','516','734'],'odieresis' => ['35','-14','521','706'],'ugrave' => ['68','-15','489','734'],'agrave' => ['36','-15','530','734'],'divide' => ['39','-19','545','524'],'ccedilla' => ['30','-225','477','538'],'Edotaccent' => ['86','0','616','901'],'rcommaaccent' => ['77','-225','332','538'],'numbersign' => ['28','0','529','688'],'ucircumflex' => ['68','-15','489','734'],'bracketleft' => ['63','-196','250','722'],'partialdiff' => ['13','-38','463','714'],'nine' => ['42','-19','514','703'],'guilsinglright' => ['88','108','245','446'],'Udieresis' => ['79','-19','644','901'],'quotesingle' => ['59','463','132','718'],'otilde' => ['35','-14','521','722'],'Oslash' => ['39','-19','740','737'],'paragraph' => ['18','-173','497','718'],'slash' => ['-17','-19','295','737'],'Eogonek' => ['86','-220','633','718'],'period' => ['87','0','191','106'],'emdash' => ['0','240','1000','313'],'one' => ['101','0','359','703'],'cent' => ['51','-115','513','623'],'fi' => ['14','0','434','728'],'commaaccent' => ['87','-225','181','-40'],'fl' => ['14','0','432','728']},
			'capheight' => '718',
			'char' => [undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'space','exclam','quotedbl','numbersign','dollar','percent','ampersand','quoteright','parenleft','parenright','asterisk','plus','comma','hyphen','period','slash','zero','one','two','three','four','five','six','seven','eight','nine','colon','semicolon','less','equal','greater','question','at','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','bracketleft','backslash','bracketright','asciicircum','underscore','quoteleft','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','braceleft','bar','braceright','asciitilde',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'exclamdown','cent','sterling','fraction','yen','florin','section','currency','quotesingle','quotedblleft','guillemotleft','guilsinglleft','guilsinglright','fi','fl',undef,'endash','dagger','daggerdbl','periodcentered',undef,'paragraph','bullet','quotesinglbase','quotedblbase','quotedblright','guillemotright','ellipsis','perthousand',undef,'questiondown',undef,'grave','acute','circumflex','tilde','macron','breve','dotaccent','dieresis',undef,'ring','cedilla',undef,'hungarumlaut','ogonek','caron','emdash',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'AE',undef,'ordfeminine',undef,undef,undef,undef,'Lslash','Oslash','OE','ordmasculine',undef,undef,undef,undef,undef,'ae',undef,undef,undef,'dotlessi',undef,undef,'lslash','oslash','oe','germandbls'],
			'descender' => '-207',
			'fontbbox' => ['-166','-225','1000','931'],
			'fontname' => 'Helvetica',
			'iscore' => 1,
			'isfixedpitch' => 0,
			'italicangle' => '0',
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
			'bbox' => {'ntilde' => ['21','0','539','674'],'cacute' => ['25','-14','430','713'],'Ydieresis' => ['15','0','699','877'],'Oacute' => ['35','-19','743','923'],'zdotaccent' => ['21','0','420','691'],'acute' => ['86','528','324','713'],'lcommaaccent' => ['16','-218','255','676'],'ohungarumlaut' => ['25','-14','529','713'],'parenleft' => ['46','-168','306','694'],'lozenge' => ['10','0','484','745'],'zero' => ['24','-13','476','688'],'aring' => ['25','-14','488','740'],'ncaron' => ['21','0','539','704'],'Acircumflex' => ['9','0','689','914'],'Zcaron' => ['28','0','634','914'],'Nacute' => ['16','-18','701','923'],'scommaaccent' => ['25','-218','361','473'],'multiply' => ['48','16','522','490'],'ellipsis' => ['82','-13','917','156'],'uacute' => ['16','-14','537','713'],'hungarumlaut' => ['-13','528','425','713'],'aogonek' => ['25','-193','504','473'],'aacute' => ['25','-14','488','713'],'Emacron' => ['16','0','641','847'],'Lslash' => ['19','0','638','676'],'cedilla' => ['68','-218','294','0'],'A' => ['9','0','689','690'],'B' => ['16','0','619','676'],'Ecaron' => ['16','0','641','914'],'Kcommaaccent' => ['30','-218','769','676'],'C' => ['49','-19','687','691'],'florin' => ['0','-155','498','706'],'D' => ['14','0','690','676'],'Igrave' => ['20','0','370','923'],'E' => ['16','0','641','676'],'braceright' => ['54','-175','372','698'],'F' => ['16','0','583','676'],'G' => ['37','-19','755','691'],'Abreve' => ['9','0','689','901'],'H' => ['21','0','759','676'],'germandbls' => ['19','-12','517','691'],'I' => ['20','0','370','676'],'J' => ['3','-96','479','676'],'K' => ['30','0','769','676'],'L' => ['19','0','638','676'],'adieresis' => ['25','-14','488','667'],'M' => ['14','0','921','676'],'lcaron' => ['16','0','412','682'],'braceleft' => ['22','-175','340','698'],'N' => ['16','-18','701','676'],'O' => ['35','-19','743','691'],'P' => ['16','0','600','676'],'Q' => ['35','-176','743','691'],'R' => ['26','0','715','676'],'brokenbar' => ['66','-143','154','707'],'S' => ['35','-19','513','692'],'T' => ['31','0','636','676'],'Lacute' => ['19','0','638','923'],'U' => ['16','-19','701','676'],'V' => ['16','-18','701','676'],'quoteleft' => ['70','356','254','691'],'Rcommaaccent' => ['26','-218','715','676'],'W' => ['19','-15','981','676'],'X' => ['16','0','699','676'],'scedilla' => ['25','-218','361','473'],'Y' => ['15','0','699','676'],'ocircumflex' => ['25','-14','476','704'],'Z' => ['28','0','634','676'],'semicolon' => ['82','-180','266','472'],'Dcaron' => ['14','0','690','914'],'Uogonek' => ['16','-193','701','676'],'dieresis' => ['-2','537','335','667'],'sacute' => ['25','-14','361','713'],'a' => ['25','-14','488','473'],'Dcroat' => ['6','0','690','676'],'b' => ['17','-14','521','676'],'c' => ['25','-14','430','473'],'twosuperior' => ['0','275','300','688'],'threequarters' => ['23','-12','733','688'],'d' => ['25','-14','534','676'],'e' => ['25','-14','426','473'],'f' => ['14','0','389','691'],'g' => ['28','-206','483','473'],'h' => ['16','0','534','676'],'i' => ['16','0','255','691'],'j' => ['-57','-203','263','691'],'ograve' => ['25','-14','476','713'],'k' => ['22','0','543','676'],'l' => ['16','0','255','676'],'gbreve' => ['28','-206','483','691'],'m' => ['16','0','814','473'],'n' => ['21','0','539','473'],'o' => ['25','-14','476','473'],'circumflex' => ['-2','528','335','704'],'tcommaaccent' => ['20','-218','332','630'],'p' => ['19','-205','524','473'],'edieresis' => ['25','-14','426','667'],'q' => ['34','-205','536','473'],'dotlessi' => ['16','0','255','461'],'r' => ['29','0','434','473'],'s' => ['25','-14','361','473'],'Ohungarumlaut' => ['35','-19','743','923'],'notequal' => ['15','-49','540','570'],'t' => ['20','-12','332','630'],'u' => ['16','-14','537','461'],'v' => ['21','-14','485','461'],'Ccaron' => ['49','-19','687','914'],'w' => ['23','-14','707','461'],'x' => ['12','0','484','461'],'y' => ['16','-205','480','461'],'Ucircumflex' => ['16','-19','701','914'],'z' => ['21','0','420','461'],'racute' => ['29','0','434','713'],'amacron' => ['25','-14','488','637'],'daggerdbl' => ['45','-132','456','691'],'Idotaccent' => ['20','0','370','901'],'Eth' => ['6','0','690','676'],'Iogonek' => ['20','-193','370','676'],'Atilde' => ['9','0','689','884'],'Lcommaaccent' => ['19','-218','638','676'],'gcommaaccent' => ['28','-206','483','829'],'greaterequal' => ['26','0','523','704'],'summation' => ['14','-10','585','706'],'idieresis' => ['-37','0','300','667'],'dollar' => ['29','-99','472','750'],'trademark' => ['24','271','977','676'],'Scommaaccent' => ['35','-218','513','692'],'Iacute' => ['20','0','370','923'],'sterling' => ['21','-14','477','684'],'currency' => ['-26','61','526','613'],'Umacron' => ['16','-19','701','847'],'ncommaaccent' => ['21','-218','539','473'],'quotedblright' => ['14','356','468','691'],'yen' => ['-64','0','547','676'],'Odieresis' => ['35','-19','743','877'],'backslash' => ['-25','-19','303','691'],'oslash' => ['25','-92','476','549'],'Egrave' => ['16','0','641','923'],'quotedblleft' => ['32','356','486','691'],'exclamdown' => ['82','-203','252','501'],'Omacron' => ['35','-19','743','847'],'Tcaron' => ['31','0','636','914'],'eight' => ['28','-13','472','688'],'OE' => ['22','-5','981','684'],'oacute' => ['25','-14','476','713'],'Zdotaccent' => ['28','0','634','901'],'five' => ['22','-8','470','676'],'eogonek' => ['25','-193','426','473'],'ordmasculine' => ['18','397','312','688'],'Thorn' => ['16','0','600','676'],'Imacron' => ['20','0','370','847'],'icircumflex' => ['-37','0','300','704'],'Ccedilla' => ['49','-218','687','691'],'three' => ['16','-14','468','688'],'Scaron' => ['35','-19','513','914'],'space' => ['0','0','0','0'],'seven' => ['17','0','477','676'],'Uring' => ['16','-19','701','935'],'quotesinglbase' => ['79','-180','263','155'],'breve' => ['15','528','318','691'],'quotedbl' => ['83','404','472','691'],'uhungarumlaut' => ['16','-14','557','713'],'nacute' => ['21','0','539','713'],'degree' => ['57','402','343','688'],'zcaron' => ['21','0','420','704'],'registered' => ['26','-19','721','691'],'parenright' => ['27','-168','287','694'],'greater' => ['31','-8','539','514'],'eth' => ['25','-14','476','691'],'AE' => ['4','0','951','676'],'ogonek' => ['90','-193','319','24'],'Zacute' => ['28','0','634','923'],'six' => ['28','-13','475','688'],'questiondown' => ['55','-201','443','501'],'hyphen' => ['44','171','287','287'],'Tcommaaccent' => ['31','-218','636','676'],'ring' => ['60','527','273','740'],'Rcaron' => ['26','0','715','914'],'mu' => ['33','-206','536','461'],'guillemotright' => ['27','36','477','415'],'guilsinglleft' => ['51','36','305','415'],'Ocircumflex' => ['35','-19','743','914'],'logicalnot' => ['33','108','537','399'],'bullet' => ['35','198','315','478'],'lslash' => ['-22','0','303','676'],'udieresis' => ['16','-14','537','667'],'ampersand' => ['62','-16','787','691'],'dotaccent' => ['103','536','258','691'],'ecaron' => ['25','-14','426','704'],'Yacute' => ['15','0','699','923'],'exclam' => ['81','-13','251','691'],'igrave' => ['-27','0','255','713'],'abreve' => ['25','-14','488','691'],'threesuperior' => ['3','268','297','688'],'Eacute' => ['16','0','641','923'],'four' => ['19','0','475','688'],'copyright' => ['26','-19','721','691'],'Ugrave' => ['16','-19','701','923'],'fraction' => ['-168','-12','329','688'],'Gcommaaccent' => ['37','-218','755','691'],'Agrave' => ['9','0','689','923'],'lacute' => ['16','0','297','923'],'edotaccent' => ['25','-14','426','691'],'emacron' => ['25','-14','426','637'],'section' => ['57','-132','443','691'],'dcaron' => ['25','-14','681','682'],'.notdef' => ['0','0','0','0'],'two' => ['17','0','478','688'],'dcroat' => ['25','-14','534','676'],'Otilde' => ['35','-19','743','884'],'quotedblbase' => ['14','-180','468','155'],'ydieresis' => ['16','-205','480','667'],'tilde' => ['-16','547','349','674'],'oe' => ['22','-14','696','473'],'Ncommaaccent' => ['16','-188','701','676'],'ecircumflex' => ['25','-14','426','704'],'Adieresis' => ['9','0','689','877'],'lessequal' => ['29','0','526','704'],'macron' => ['1','565','331','637'],'endash' => ['0','181','500','271'],'ccaron' => ['25','-14','430','704'],'Ntilde' => ['16','-18','701','884'],'Cacute' => ['49','-19','687','923'],'uogonek' => ['16','-193','539','461'],'bar' => ['66','-218','154','782'],'Uhungarumlaut' => ['16','-19','701','923'],'Delta' => ['6','0','608','688'],'caron' => ['-2','528','335','704'],'ae' => ['33','-14','693','473'],'Edieresis' => ['16','0','641','877'],'atilde' => ['25','-14','488','674'],'perthousand' => ['7','-29','995','706'],'Aogonek' => ['9','-193','699','690'],'onequarter' => ['28','-12','743','688'],'Scedilla' => ['35','-218','513','692'],'equal' => ['33','107','537','399'],'at' => ['108','-19','822','691'],'Ncaron' => ['16','-18','701','914'],'minus' => ['33','209','537','297'],'plusminus' => ['33','0','537','506'],'underscore' => ['0','-125','500','-75'],'quoteright' => ['79','356','263','691'],'ordfeminine' => ['-1','397','301','688'],'iacute' => ['16','0','289','713'],'onehalf' => ['-7','-12','775','688'],'Uacute' => ['16','-19','701','923'],'iogonek' => ['16','-193','274','691'],'periodcentered' => ['41','248','210','417'],'egrave' => ['25','-14','426','713'],'bracketright' => ['32','-149','266','678'],'thorn' => ['19','-205','524','676'],'Aacute' => ['9','0','689','923'],'Icircumflex' => ['20','0','370','914'],'Idieresis' => ['20','0','370','877'],'onesuperior' => ['28','275','273','688'],'Aring' => ['9','0','689','935'],'acircumflex' => ['25','-14','488','704'],'uring' => ['16','-14','537','740'],'tcaron' => ['20','-12','425','815'],'less' => ['31','-8','539','514'],'radical' => ['10','-46','512','850'],'percent' => ['124','-14','877','692'],'umacron' => ['16','-14','537','637'],'plus' => ['33','0','537','506'],'Lcaron' => ['19','0','652','682'],'asciicircum' => ['73','311','509','676'],'scaron' => ['25','-14','363','704'],'asciitilde' => ['29','173','491','333'],'dagger' => ['47','-134','453','691'],'Amacron' => ['9','0','689','847'],'omacron' => ['25','-14','476','637'],'Sacute' => ['35','-19','513','923'],'colon' => ['82','-13','251','472'],'Ograve' => ['35','-19','743','923'],'zacute' => ['21','0','420','713'],'asterisk' => ['56','255','447','691'],'Gbreve' => ['37','-19','755','901'],'grave' => ['8','528','246','713'],'Euro' => ['0','0','0','0'],'rcaron' => ['29','0','434','704'],'imacron' => ['-8','0','272','637'],'Racute' => ['26','0','715','923'],'comma' => ['39','-180','223','155'],'kcommaaccent' => ['22','-218','543','676'],'yacute' => ['16','-205','480','713'],'guillemotleft' => ['23','36','473','415'],'question' => ['57','-13','445','689'],'Ecircumflex' => ['16','0','641','914'],'eacute' => ['25','-14','426','713'],'odieresis' => ['25','-14','476','667'],'ugrave' => ['16','-14','537','713'],'agrave' => ['25','-14','488','713'],'divide' => ['33','-31','537','537'],'ccedilla' => ['25','-218','430','473'],'Edotaccent' => ['16','0','641','901'],'rcommaaccent' => ['29','-218','434','473'],'numbersign' => ['4','0','496','700'],'ucircumflex' => ['16','-14','537','704'],'bracketleft' => ['67','-149','301','678'],'partialdiff' => ['11','-21','494','750'],'nine' => ['26','-13','473','688'],'guilsinglright' => ['28','36','282','415'],'Udieresis' => ['16','-19','701','877'],'quotesingle' => ['75','404','204','691'],'otilde' => ['25','-14','476','674'],'Oslash' => ['35','-74','743','737'],'paragraph' => ['0','-186','519','676'],'slash' => ['-24','-19','302','691'],'Eogonek' => ['16','-193','644','676'],'period' => ['41','-13','210','156'],'emdash' => ['0','181','1000','271'],'one' => ['65','0','442','688'],'cent' => ['53','-140','458','588'],'fi' => ['14','0','536','691'],'commaaccent' => ['47','-218','203','-50'],'fl' => ['14','0','536','691']},
			'capheight' => '676',
			'char' => [undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'space','exclam','quotedbl','numbersign','dollar','percent','ampersand','quoteright','parenleft','parenright','asterisk','plus','comma','hyphen','period','slash','zero','one','two','three','four','five','six','seven','eight','nine','colon','semicolon','less','equal','greater','question','at','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','bracketleft','backslash','bracketright','asciicircum','underscore','quoteleft','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','braceleft','bar','braceright','asciitilde',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'exclamdown','cent','sterling','fraction','yen','florin','section','currency','quotesingle','quotedblleft','guillemotleft','guilsinglleft','guilsinglright','fi','fl',undef,'endash','dagger','daggerdbl','periodcentered',undef,'paragraph','bullet','quotesinglbase','quotedblbase','quotedblright','guillemotright','ellipsis','perthousand',undef,'questiondown',undef,'grave','acute','circumflex','tilde','macron','breve','dotaccent','dieresis',undef,'ring','cedilla',undef,'hungarumlaut','ogonek','caron','emdash',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'AE',undef,'ordfeminine',undef,undef,undef,undef,'Lslash','Oslash','OE','ordmasculine',undef,undef,undef,undef,undef,'ae',undef,undef,undef,'dotlessi',undef,undef,'lslash','oslash','oe','germandbls'],
			'descender' => '-217',
			'fontbbox' => ['-168','-218','1000','935'],
			'fontname' => 'Times-Bold',
			'iscore' => 1,
			'isfixedpitch' => 0,
			'italicangle' => '0',
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
			'bbox' => {'ntilde' => ['16','0','485','638'],'cacute' => ['25','-10','413','678'],'Ydieresis' => ['22','0','703','835'],'Oacute' => ['34','-14','688','890'],'zdotaccent' => ['27','0','418','623'],'acute' => ['93','507','317','678'],'lcommaaccent' => ['19','-218','257','683'],'ohungarumlaut' => ['29','-10','491','678'],'parenleft' => ['48','-177','304','676'],'lozenge' => ['13','0','459','724'],'zero' => ['24','-14','476','676'],'aring' => ['37','-10','442','711'],'ncaron' => ['16','0','485','674'],'Acircumflex' => ['15','0','706','886'],'Zcaron' => ['9','0','597','886'],'Nacute' => ['12','-11','707','890'],'scommaaccent' => ['51','-218','348','460'],'multiply' => ['38','8','527','497'],'ellipsis' => ['111','-11','888','100'],'uacute' => ['9','-10','479','678'],'hungarumlaut' => ['-3','507','377','678'],'aogonek' => ['37','-165','469','460'],'aacute' => ['37','-10','442','678'],'Emacron' => ['12','0','597','813'],'Lslash' => ['12','0','598','662'],'cedilla' => ['52','-215','261','0'],'A' => ['15','0','706','674'],'B' => ['17','0','593','662'],'Ecaron' => ['12','0','597','886'],'Kcommaaccent' => ['34','-198','723','662'],'C' => ['28','-14','633','676'],'florin' => ['7','-189','490','676'],'D' => ['16','0','685','662'],'Igrave' => ['18','0','315','890'],'E' => ['12','0','597','662'],'braceright' => ['130','-181','380','680'],'F' => ['12','0','546','662'],'G' => ['32','-14','709','676'],'Abreve' => ['15','0','706','876'],'H' => ['19','0','702','662'],'germandbls' => ['12','-9','468','683'],'I' => ['18','0','315','662'],'J' => ['10','-14','370','662'],'K' => ['34','0','723','662'],'L' => ['12','0','598','662'],'adieresis' => ['37','-10','442','623'],'M' => ['12','0','863','662'],'lcaron' => ['19','0','347','695'],'braceleft' => ['100','-181','350','680'],'N' => ['12','-11','707','662'],'O' => ['34','-14','688','676'],'P' => ['16','0','542','662'],'Q' => ['34','-178','701','676'],'R' => ['17','0','659','662'],'brokenbar' => ['67','-143','133','707'],'S' => ['42','-14','491','676'],'T' => ['17','0','593','662'],'Lacute' => ['12','0','598','890'],'U' => ['14','-14','705','662'],'V' => ['16','-11','697','662'],'quoteleft' => ['115','433','254','676'],'Rcommaaccent' => ['17','-198','659','662'],'W' => ['5','-11','932','662'],'X' => ['10','0','704','662'],'scedilla' => ['51','-215','348','460'],'Y' => ['22','0','703','662'],'ocircumflex' => ['29','-10','470','674'],'Z' => ['9','0','597','662'],'semicolon' => ['80','-141','219','459'],'Dcaron' => ['16','0','685','886'],'Uogonek' => ['14','-165','705','662'],'dieresis' => ['18','581','315','681'],'sacute' => ['51','-10','348','678'],'a' => ['37','-10','442','460'],'Dcroat' => ['16','0','685','662'],'b' => ['3','-10','468','683'],'c' => ['25','-10','412','460'],'twosuperior' => ['1','270','296','676'],'threequarters' => ['15','-14','718','676'],'d' => ['27','-10','491','683'],'e' => ['25','-10','424','460'],'f' => ['20','0','383','683'],'g' => ['28','-218','470','460'],'h' => ['9','0','487','683'],'i' => ['16','0','253','683'],'j' => ['-70','-218','194','683'],'ograve' => ['29','-10','470','678'],'k' => ['7','0','505','683'],'l' => ['19','0','257','683'],'gbreve' => ['28','-218','470','664'],'m' => ['16','0','775','460'],'n' => ['16','0','485','460'],'o' => ['29','-10','470','460'],'circumflex' => ['11','507','322','674'],'tcommaaccent' => ['13','-218','279','579'],'p' => ['5','-217','470','460'],'edieresis' => ['25','-10','424','623'],'q' => ['24','-217','488','460'],'dotlessi' => ['16','0','253','460'],'r' => ['5','0','335','460'],'s' => ['51','-10','348','460'],'Ohungarumlaut' => ['34','-14','688','890'],'notequal' => ['12','-31','537','547'],'t' => ['13','-10','279','579'],'u' => ['9','-10','479','450'],'v' => ['19','-14','477','450'],'Ccaron' => ['28','-14','633','886'],'w' => ['21','-14','694','450'],'x' => ['17','0','479','450'],'y' => ['14','-218','475','450'],'Ucircumflex' => ['14','-14','705','886'],'z' => ['27','0','418','450'],'racute' => ['5','0','335','678'],'amacron' => ['37','-10','442','601'],'daggerdbl' => ['58','-153','442','676'],'Idotaccent' => ['18','0','315','835'],'Eth' => ['16','0','685','662'],'Iogonek' => ['18','-165','315','662'],'Atilde' => ['15','0','706','850'],'Lcommaaccent' => ['12','-218','598','662'],'gcommaaccent' => ['28','-218','470','749'],'greaterequal' => ['26','0','523','666'],'summation' => ['15','-10','585','706'],'idieresis' => ['-9','0','288','623'],'dollar' => ['44','-87','457','727'],'trademark' => ['30','256','957','662'],'Scommaaccent' => ['42','-218','491','676'],'Iacute' => ['18','0','317','890'],'sterling' => ['12','-8','490','676'],'currency' => ['-22','58','522','602'],'Umacron' => ['14','-14','705','813'],'ncommaaccent' => ['16','-218','485','460'],'quotedblright' => ['30','433','401','676'],'yen' => ['-53','0','512','662'],'Odieresis' => ['34','-14','688','835'],'backslash' => ['-9','-14','287','676'],'oslash' => ['29','-112','470','551'],'Egrave' => ['12','0','597','890'],'quotedblleft' => ['43','433','414','676'],'exclamdown' => ['97','-218','205','467'],'Omacron' => ['34','-14','688','813'],'Tcaron' => ['17','0','593','886'],'eight' => ['56','-14','445','676'],'OE' => ['30','-6','885','668'],'oacute' => ['29','-10','470','678'],'Zdotaccent' => ['9','0','597','835'],'five' => ['32','-14','438','688'],'eogonek' => ['25','-165','424','460'],'ordmasculine' => ['6','394','304','676'],'Thorn' => ['16','0','542','662'],'Imacron' => ['11','0','322','813'],'icircumflex' => ['-16','0','295','674'],'Ccedilla' => ['28','-215','633','676'],'three' => ['43','-14','431','676'],'Scaron' => ['42','-14','491','886'],'space' => ['0','0','0','0'],'seven' => ['20','-8','449','662'],'Uring' => ['14','-14','705','898'],'quotesinglbase' => ['79','-141','218','102'],'breve' => ['26','507','307','664'],'quotedbl' => ['77','431','331','676'],'uhungarumlaut' => ['9','-10','501','678'],'nacute' => ['16','0','485','678'],'degree' => ['57','390','343','676'],'zcaron' => ['27','0','418','674'],'registered' => ['38','-14','722','676'],'parenright' => ['29','-177','285','676'],'greater' => ['28','-8','536','514'],'eth' => ['29','-10','471','686'],'AE' => ['0','0','863','662'],'ogonek' => ['62','-165','243','0'],'Zacute' => ['9','0','597','890'],'six' => ['34','-14','468','684'],'questiondown' => ['30','-218','376','466'],'hyphen' => ['39','194','285','257'],'Tcommaaccent' => ['17','-218','593','662'],'ring' => ['67','512','266','711'],'Rcaron' => ['17','0','659','886'],'mu' => ['36','-218','512','450'],'guillemotright' => ['44','33','458','416'],'guilsinglleft' => ['63','33','285','416'],'Ocircumflex' => ['34','-14','688','886'],'logicalnot' => ['30','108','534','386'],'bullet' => ['40','196','310','466'],'lslash' => ['19','0','259','683'],'udieresis' => ['9','-10','479','623'],'ampersand' => ['42','-13','750','676'],'dotaccent' => ['118','581','216','681'],'ecaron' => ['25','-10','424','674'],'Yacute' => ['22','0','703','890'],'exclam' => ['130','-9','238','676'],'igrave' => ['-8','0','253','678'],'abreve' => ['37','-10','442','664'],'threesuperior' => ['15','262','291','676'],'Eacute' => ['12','0','597','890'],'four' => ['12','0','472','676'],'copyright' => ['38','-14','722','676'],'Ugrave' => ['14','-14','705','890'],'fraction' => ['-168','-14','331','676'],'Gcommaaccent' => ['32','-218','709','676'],'Agrave' => ['15','0','706','890'],'lacute' => ['19','0','290','890'],'edotaccent' => ['25','-10','424','623'],'emacron' => ['25','-10','424','601'],'section' => ['70','-148','426','676'],'dcaron' => ['27','-10','589','695'],'.notdef' => ['0','0','0','0'],'two' => ['30','0','475','676'],'dcroat' => ['27','-10','500','683'],'Otilde' => ['34','-14','688','850'],'quotedblbase' => ['45','-141','416','102'],'ydieresis' => ['14','-218','475','623'],'tilde' => ['1','532','331','638'],'oe' => ['30','-10','690','460'],'Ncommaaccent' => ['12','-198','707','662'],'ecircumflex' => ['25','-10','424','674'],'Adieresis' => ['15','0','706','835'],'lessequal' => ['26','0','523','666'],'macron' => ['11','547','322','601'],'endash' => ['0','201','500','250'],'ccaron' => ['25','-10','412','674'],'Ntilde' => ['12','-11','707','850'],'Cacute' => ['28','-14','633','890'],'uogonek' => ['9','-155','487','450'],'bar' => ['67','-218','133','782'],'Uhungarumlaut' => ['14','-14','705','890'],'Delta' => ['6','0','608','688'],'caron' => ['11','507','322','674'],'ae' => ['38','-10','632','460'],'Edieresis' => ['12','0','597','835'],'atilde' => ['37','-10','442','638'],'perthousand' => ['7','-19','994','706'],'Aogonek' => ['15','-165','738','674'],'onequarter' => ['37','-14','718','676'],'Scedilla' => ['42','-215','491','676'],'equal' => ['30','120','534','386'],'at' => ['116','-14','809','676'],'Ncaron' => ['12','-11','707','886'],'minus' => ['30','220','534','286'],'plusminus' => ['30','0','534','506'],'underscore' => ['0','-125','500','-75'],'quoteright' => ['79','433','218','676'],'ordfeminine' => ['4','394','270','676'],'iacute' => ['16','0','290','678'],'onehalf' => ['31','-14','746','676'],'Uacute' => ['14','-14','705','890'],'iogonek' => ['16','-165','265','683'],'periodcentered' => ['70','199','181','310'],'egrave' => ['25','-10','424','678'],'bracketright' => ['34','-156','245','662'],'thorn' => ['5','-217','470','683'],'Aacute' => ['15','0','706','890'],'Icircumflex' => ['11','0','322','886'],'Idieresis' => ['18','0','315','835'],'onesuperior' => ['57','270','248','676'],'Aring' => ['15','0','706','898'],'acircumflex' => ['37','-10','442','674'],'uring' => ['9','-10','479','711'],'tcaron' => ['13','-10','318','722'],'less' => ['28','-8','536','514'],'radical' => ['2','-60','452','768'],'percent' => ['61','-13','772','676'],'umacron' => ['9','-10','479','601'],'plus' => ['30','0','534','506'],'Lcaron' => ['12','0','598','676'],'asciicircum' => ['24','297','446','662'],'scaron' => ['39','-10','350','674'],'asciitilde' => ['40','183','502','323'],'dagger' => ['59','-149','442','676'],'Amacron' => ['15','0','706','813'],'omacron' => ['29','-10','470','601'],'Sacute' => ['42','-14','491','890'],'colon' => ['81','-11','192','459'],'Ograve' => ['34','-14','688','890'],'zacute' => ['27','0','418','678'],'asterisk' => ['69','265','432','676'],'Gbreve' => ['32','-14','709','876'],'grave' => ['19','507','242','678'],'Euro' => ['0','0','0','0'],'rcaron' => ['5','0','335','674'],'imacron' => ['6','0','271','601'],'Racute' => ['17','0','659','890'],'comma' => ['56','-141','195','102'],'kcommaaccent' => ['7','-218','505','683'],'yacute' => ['14','-218','475','678'],'guillemotleft' => ['42','33','456','416'],'question' => ['68','-8','414','676'],'Ecircumflex' => ['12','0','597','886'],'eacute' => ['25','-10','424','678'],'odieresis' => ['29','-10','470','623'],'ugrave' => ['9','-10','479','678'],'agrave' => ['37','-10','442','678'],'divide' => ['30','-10','534','516'],'ccedilla' => ['25','-215','412','460'],'Edotaccent' => ['12','0','597','835'],'rcommaaccent' => ['5','-218','335','460'],'numbersign' => ['5','0','496','662'],'ucircumflex' => ['9','-10','479','674'],'bracketleft' => ['88','-156','299','662'],'partialdiff' => ['17','-38','459','710'],'nine' => ['30','-22','459','676'],'guilsinglright' => ['48','33','270','416'],'Udieresis' => ['14','-14','705','835'],'quotesingle' => ['48','431','133','676'],'otilde' => ['29','-10','470','638'],'Oslash' => ['34','-80','688','734'],'paragraph' => ['-22','-154','450','662'],'slash' => ['-9','-14','287','676'],'Eogonek' => ['12','-165','597','662'],'period' => ['70','-11','181','100'],'emdash' => ['0','201','1000','250'],'one' => ['111','0','394','676'],'cent' => ['53','-138','448','579'],'fi' => ['31','0','521','683'],'commaaccent' => ['59','-218','184','-50'],'fl' => ['32','0','521','683']},
			'capheight' => '662',
			'char' => [undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'space','exclam','quotedbl','numbersign','dollar','percent','ampersand','quoteright','parenleft','parenright','asterisk','plus','comma','hyphen','period','slash','zero','one','two','three','four','five','six','seven','eight','nine','colon','semicolon','less','equal','greater','question','at','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z','bracketleft','backslash','bracketright','asciicircum','underscore','quoteleft','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','braceleft','bar','braceright','asciitilde',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'exclamdown','cent','sterling','fraction','yen','florin','section','currency','quotesingle','quotedblleft','guillemotleft','guilsinglleft','guilsinglright','fi','fl',undef,'endash','dagger','daggerdbl','periodcentered',undef,'paragraph','bullet','quotesinglbase','quotedblbase','quotedblright','guillemotright','ellipsis','perthousand',undef,'questiondown',undef,'grave','acute','circumflex','tilde','macron','breve','dotaccent','dieresis',undef,'ring','cedilla',undef,'hungarumlaut','ogonek','caron','emdash',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'AE',undef,'ordfeminine',undef,undef,undef,undef,'Lslash','Oslash','OE','ordmasculine',undef,undef,undef,undef,undef,'ae',undef,undef,undef,'dotlessi',undef,undef,'lslash','oslash','oe','germandbls'],
			'descender' => '-217',
			'fontbbox' => ['-168','-218','1000','898'],
			'fontname' => 'Times-Roman',
			'iscore' => 1,
			'isfixedpitch' => 0,
			'italicangle' => '0',
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
			'bbox' => {'a190' => ['35','76','931','616'],'a191' => ['34','99','884','593'],'a192' => ['35','94','698','597'],'a193' => ['35','44','802','648'],'a194' => ['34','37','736','655'],'a195' => ['34','-19','853','712'],'a70' => ['36','-14','751','705'],'a196' => ['35','94','698','597'],'a197' => ['34','37','736','655'],'a71' => ['35','-14','757','705'],'a198' => ['34','-19','853','712'],'a72' => ['35','-14','838','705'],'a199' => ['35','101','832','591'],'a73' => ['35','0','726','692'],'a74' => ['35','0','727','692'],'a75' => ['35','0','725','692'],'a76' => ['35','0','858','705'],'a77' => ['35','-14','858','692'],'a78' => ['35','-14','754','705'],'a79' => ['35','-14','749','705'],'a120' => ['35','-14','754','705'],'a121' => ['35','-14','754','705'],'a122' => ['35','-14','754','705'],'a123' => ['35','-14','754','705'],'a124' => ['35','-14','754','705'],'a1' => ['35','72','939','621'],'a125' => ['35','-14','754','705'],'a2' => ['35','81','927','611'],'a126' => ['35','-14','754','705'],'a3' => ['35','0','945','692'],'a127' => ['35','-14','754','705'],'a4' => ['34','139','685','566'],'a128' => ['35','-14','754','705'],'a5' => ['35','-14','755','705'],'a129' => ['35','-14','754','705'],'a6' => ['35','0','460','692'],'a7' => ['35','0','517','692'],'a8' => ['35','0','503','692'],'a9' => ['35','96','542','596'],'.notdef' => ['0','0','0','0'],'a81' => ['35','-14','403','705'],'a82' => ['35','0','104','692'],'a83' => ['35','0','242','692'],'a84' => ['35','0','380','692'],'a85' => ['35','0','475','692'],'a86' => ['35','0','375','692'],'a87' => ['35','-14','199','705'],'a88' => ['35','-14','199','705'],'a200' => ['35','44','661','648'],'a89' => ['35','-14','356','705'],'a201' => ['35','73','840','615'],'a202' => ['35','72','939','621'],'a203' => ['35','0','727','692'],'a130' => ['35','-14','754','705'],'a204' => ['35','0','725','692'],'a131' => ['35','-14','754','705'],'a205' => ['35','0','475','692'],'a132' => ['35','-14','754','705'],'a206' => ['35','0','375','692'],'a133' => ['35','-14','754','705'],'a134' => ['35','-14','754','705'],'a135' => ['35','-14','754','705'],'a136' => ['35','-14','754','705'],'a10' => ['35','-14','657','705'],'a137' => ['35','-14','754','705'],'a11' => ['35','123','925','568'],'a138' => ['35','-14','754','705'],'a12' => ['35','134','904','559'],'a139' => ['35','-14','754','705'],'a13' => ['29','-11','516','705'],'a14' => ['34','59','820','632'],'a15' => ['35','50','876','642'],'a16' => ['35','139','899','550'],'a17' => ['35','139','909','553'],'a18' => ['35','104','938','587'],'a19' => ['34','-13','721','705'],'a90' => ['35','-14','355','705'],'a91' => ['35','0','242','692'],'a92' => ['35','0','242','692'],'a93' => ['35','0','283','692'],'a94' => ['35','0','283','692'],'a95' => ['35','0','299','692'],'a96' => ['35','0','299','692'],'a97' => ['35','263','357','705'],'a98' => ['34','263','357','705'],'a99' => ['35','263','633','705'],'a140' => ['35','-14','754','705'],'a141' => ['35','-14','754','705'],'a142' => ['35','-14','754','705'],'a143' => ['35','-14','754','705'],'a144' => ['35','-14','754','705'],'a145' => ['35','-14','754','705'],'a146' => ['35','-14','754','705'],'a20' => ['36','-14','811','705'],'a147' => ['35','-14','754','705'],'a21' => ['35','0','727','692'],'a148' => ['35','-14','754','705'],'a22' => ['35','0','727','692'],'a149' => ['35','-14','754','705'],'a23' => ['-1','-68','571','661'],'a24' => ['36','-13','642','705'],'a25' => ['35','0','728','692'],'a26' => ['35','0','726','692'],'a27' => ['35','0','725','692'],'a28' => ['35','0','720','692'],'a29' => ['35','-14','751','705'],'a150' => ['35','-14','754','705'],'a151' => ['35','-14','754','705'],'a152' => ['35','-14','754','705'],'a153' => ['35','-14','754','705'],'a154' => ['35','-14','754','705'],'a155' => ['35','-14','754','705'],'a156' => ['35','-14','754','705'],'a30' => ['35','-14','752','705'],'a157' => ['35','-14','754','705'],'a158' => ['35','-14','754','705'],'a31' => ['35','-14','753','705'],'a32' => ['35','-14','756','705'],'a159' => ['35','-14','754','705'],'a33' => ['35','-13','759','705'],'a34' => ['35','-13','759','705'],'a35' => ['35','-14','782','705'],'a36' => ['35','-14','787','705'],'a37' => ['35','-14','754','705'],'a38' => ['35','-14','807','705'],'a39' => ['35','-14','789','705'],'a160' => ['35','58','860','634'],'a161' => ['35','152','803','540'],'a162' => ['35','98','889','594'],'a163' => ['34','152','981','540'],'a164' => ['35','-127','422','820'],'a165' => ['35','140','890','552'],'a166' => ['35','166','884','526'],'a40' => ['35','-14','798','705'],'a167' => ['35','32','892','660'],'a41' => ['35','-13','782','705'],'a42' => ['35','-14','796','705'],'a168' => ['35','129','891','562'],'a43' => ['35','-14','888','705'],'a169' => ['35','128','893','563'],'a44' => ['35','0','710','692'],'a45' => ['35','0','688','692'],'a46' => ['35','0','714','692'],'a47' => ['34','-14','756','705'],'a48' => ['35','-14','758','705'],'a49' => ['35','-14','661','706'],'a170' => ['35','155','799','537'],'a171' => ['35','93','838','599'],'a172' => ['35','104','791','588'],'a173' => ['35','98','889','594'],'a174' => ['35','0','882','692'],'a175' => ['35','84','896','608'],'a176' => ['35','84','896','608'],'a50' => ['35','-6','741','699'],'a51' => ['35','-7','734','699'],'a177' => ['35','-99','429','791'],'a52' => ['35','-14','757','705'],'a178' => ['35','71','848','623'],'a53' => ['35','0','725','692'],'a179' => ['35','44','802','648'],'a54' => ['35','-13','672','704'],'a55' => ['35','-14','672','705'],'a56' => ['35','-14','647','705'],'a57' => ['35','-14','666','705'],'a58' => ['35','-14','791','705'],'a59' => ['35','-14','780','705'],'a100' => ['36','263','634','705'],'a101' => ['35','-143','697','806'],'a102' => ['56','-14','488','706'],'a103' => ['34','-14','508','705'],'a104' => ['35','40','875','651'],'a105' => ['35','50','876','642'],'a106' => ['35','-14','633','705'],'a107' => ['35','-14','726','705'],'a108' => ['0','121','758','569'],'a109' => ['34','0','591','705'],'space' => ['0','0','0','0'],'a180' => ['35','101','832','591'],'a181' => ['35','44','661','648'],'a182' => ['35','77','840','619'],'a183' => ['35','0','725','692'],'a184' => ['35','160','911','533'],'a185' => ['35','207','830','481'],'a60' => ['35','-14','754','705'],'a186' => ['35','124','932','568'],'a61' => ['35','-14','754','705'],'a187' => ['35','113','796','579'],'a62' => ['34','-14','673','705'],'a188' => ['36','118','838','578'],'a63' => ['36','0','651','692'],'a189' => ['35','150','891','542'],'a64' => ['35','0','661','691'],'a65' => ['35','0','655','692'],'a66' => ['34','-14','751','705'],'a67' => ['35','-14','752','705'],'a68' => ['35','-14','678','705'],'a69' => ['35','-14','756','705'],'a110' => ['35','-14','659','705'],'a111' => ['34','-14','560','705'],'a112' => ['35','0','741','705'],'a117' => ['34','138','655','553'],'a118' => ['35','-13','761','705'],'a119' => ['35','-14','755','705']},
			'capheight' => undef,
			'char' => [undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'space','a1','a2','a202','a3','a4','a5','a119','a118','a117','a11','a12','a13','a14','a15','a16','a105','a17','a18','a19','a20','a21','a22','a23','a24','a25','a26','a27','a28','a6','a7','a8','a9','a10','a29','a30','a31','a32','a33','a34','a35','a36','a37','a38','a39','a40','a41','a42','a43','a44','a45','a46','a47','a48','a49','a50','a51','a52','a53','a54','a55','a56','a57','a58','a59','a60','a61','a62','a63','a64','a65','a66','a67','a68','a69','a70','a71','a72','a73','a74','a203','a75','a204','a76','a77','a78','a79','a81','a82','a83','a84','a97','a98','a99','a100',undef,'a89','a90','a93','a94','a91','a92','a205','a85','a206','a86','a87','a88','a95','a96',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'a101','a102','a103','a104','a106','a107','a108','a112','a111','a110','a109','a120','a121','a122','a123','a124','a125','a126','a127','a128','a129','a130','a131','a132','a133','a134','a135','a136','a137','a138','a139','a140','a141','a142','a143','a144','a145','a146','a147','a148','a149','a150','a151','a152','a153','a154','a155','a156','a157','a158','a159','a160','a161','a163','a164','a196','a165','a192','a166','a167','a168','a169','a170','a171','a172','a173','a162','a174','a175','a176','a177','a178','a179','a193','a180','a199','a181','a200','a182',undef,'a201','a183','a184','a197','a185','a194','a198','a186','a195','a187','a188','a189','a190','a191'],
			'descender' => undef,
			'fontbbox' => ['-1','-143','981','820'],
			'fontname' => 'ZapfDingbats',
			'iscore' => 1,
			'isfixedpitch' => 'false',
			'issymbol' => 1,
			'italicangle' => '0',
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


