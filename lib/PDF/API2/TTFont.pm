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
#	PDF::API2::TTFont
#
#=======================================================================
package PDF::API2::TTFont;
use strict;
use PDF::API2::UniMap qw( utf8_to_ucs2 );
use PDF::API2::Util;
use PDF::API2::Font;
use PDF::API2::PDF::Utils;
use PDF::API2::PDF::TTFont0;
use POSIX;

use vars qw(@ISA $VERSION);
@ISA = qw( PDF::API2::PDF::TTFont0 PDF::API2::Font );
( $VERSION ) = '$Revisioning: 0.3a15 $' =~ /\$Revisioning:\s+([^\s]+)/;


=head2 PDF::API2::TTFont

Subclassed from PDF::API2::PDF::TTFont0 and PDF::API2::Font.

=item $font = PDF::API2::TTFont->new $pdf,$ttffile,$pdfname

Returns a truetype font object (called from $pdf->ttfont).

=cut

sub new {
	my ($class, $pdf,$file,$name) = @_;

	$class = ref $class if ref $class;
	my $self = $class->SUPER::new($pdf,$file,$name, -subset => 1);

	my $font=$self->{' font'};
	$font->{'cmap'}->read;
	$font->{'hmtx'}->read;
	$font->{'post'}->read;
	$font->{'loca'}->read;
	my $upem = $font->{'head'}->read->{'unitsPerEm'};

	$self->{' unicid'}=();
	$self->{' uniwidth'}=();
	$self->{' unibbx'}=();
	my @map=$font->{'cmap'}->reverse;
	foreach my $x (0..scalar(@map)) {
		$self->{' unicid'}{$map[$x]||0}=$x;
		$self->{' uniwidth'}{$map[$x]||0}=$font->{'hmtx'}{'advance'}[$x]*1000/$upem;
		$self->{' unibbx'}{$map[$x]||0}=[
			ceil($font->{'loca'}->{'glyphs'}[$x]->read->{'xMin'} * 1000 / $upem),
			ceil($font->{'loca'}->{'glyphs'}[$x]->{'yMin'} * 1000 / $upem),
			ceil($font->{'loca'}->{'glyphs'}[$x]->{'xMax'} * 1000 / $upem),
			ceil($font->{'loca'}->{'glyphs'}[$x]->{'yMax'} * 1000 / $upem)
		] if($font->{'loca'}->{'glyphs'}[$x]);
	}
	$self->{' encoding'}='latin1';
	$self->{' chrcid'}={};
	$self->{' chrcid'}->{'latin1'}=();
	$self->{' chrwidth'}={};
	$self->{' chrwidth'}->{'latin1'}=();
	$self->{' chrbbx'}={};
	$self->{' chrbbx'}->{'latin1'}=();
	foreach my $x (0..255) {
		$self->{' chrcid'}->{'latin1'}{$x}=$self->{' unicid'}{$x}||$self->{' unicid'}{32};
		$self->{' chrwidth'}->{'latin1'}{$x}=$self->{' uniwidth'}{$x}||$self->{' uniwidth'}{32};
		$self->{' chrbbx'}->{'latin1'}{$x}=$self->{' unibbx'}{$x}||$self->{' unibbx'}{32};
	}
    
    $self->{' ascent'}=int($font->{'hhea'}->read->{'Ascender'} * 1000 / $upem);
    $self->{' descent'}=int($font->{'hhea'}{'Descender'} * 1000 / $upem);

	eval {
		$self->{' capheight'}=int(
			$font->{'loca'}->read->{'glyphs'}[
				$font->{'post'}{'STRINGS'}{"H"}||0
			]->read->{'yMax'}
			* 1000 / $upem
		);
	};
	$self->{' capheight'}||=0;
	
	eval {
		$self->{' xheight'}=int(
			$font->{'loca'}->read->{'glyphs'}[
				$font->{'post'}{'STRINGS'}{"x"}||0
			]->read->{'yMax'}
			* 1000 / $upem
		);
	};
	$self->{' xheight'}||=0;

	$self->{' italicangle'}=$font->{'post'}->read->{'italicAngle'};

	$self->{' fontbbox'}=[
		int($font->{'head'}{'xMin'} * 1000 / $upem),
	        int($font->{'head'}{'yMin'} * 1000 / $upem),
	        int($font->{'head'}{'xMax'} * 1000 / $upem),
		int($font->{'head'}{'yMax'} * 1000 / $upem)
	];

	$self->{' apiname'}=$name;
	$self->{' apipdf'}=$pdf;

	return($self);
}

=item $pdfstring = $font->text_ucs2 $text

Returns a properly formated string-representation of $text
for use in the PDF but requires $text to be in UCS2.

=cut

sub text_ucs2 {
	my ($self,$text)=@_;
	my ($newtext);
	foreach my $x (0..(length($text)>>1)-1) {
		my $g=$self->{' unicid'}{vec($text,$x,16)}||0;
		$newtext.= sprintf('%04x',$g);
		vec($self->{' subvec'},$g,1)=1;
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

=item $pdfstring = $font->text $text

Returns a properly formated string-representation of $text
for use in the PDF.

=cut

sub text {
	my ($self,$text,$enc)=@_;
	$enc=$enc||$self->{' encoding'};
	if(lc($enc) eq 'ucs2') {
		return $self->text_ucs2($text);
	} elsif(lc($enc) eq 'utf8') {
		return $self->text_utf8($text);
	}
	my $newtext='';
	$self->{' subvec'}='' unless($self->{' subvec'});
	foreach (unpack("C*", $text)) {
		my $g=$self->{' chrcid'}{$enc}{$_}||32;
		$newtext.= sprintf('%04x',$g);
		vec($self->{' subvec'},$g,1)=1;
	}
	return("<$newtext>");
}

=item $wd = $font->width $text

Returns the width of $text as if it were at size 1.

=cut

sub width {
	my ($self,$text,%opts)=@_;
	my $enc=$opts{-encode}||$self->{' encoding'};
	my $width=0;
	if($opts{-utf8}) {
		$text=utf8_to_ucs2($text);
		foreach my $x (0..(length($text)>>1)-1) {
			$width += $self->{' uniwidth'}{vec($text,$x,16)};
		}
	} elsif($opts{-ucs2}) {
			foreach my $x (0..(length($text)>>1)-1) {
				$width += $self->{' uniwidth'}{vec($text,$x,16)};
			}
		} else {
			foreach (unpack("C*", $text)) {
				$width += $self->{' chrwidth'}{$enc}{$_||0};
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

=item $wd = $font->width_ucs2 $text

Returns the width of $text as if it were at size 1,
but requires $text to be in UCS2.

=cut

sub width_ucs2 {
	my ($self,$text,%opts)=@_;
	my ($width);
	foreach my $x (0..(length($text)>>1)-1) {
		$width += $self->{' uniwidth'}{vec($text,$x,16)};
	}
	$width/=1000;
	return($width);
}

=item $wd = $font->width_utf8 $text

Returns the width of $text as if it were at size 1,
but requires $text to be in UTF8.

=cut

sub width_utf8 {
	my ($self,$text,%opts)=@_;
	$text=utf8_to_ucs2($text);
	return $self->width_ucs2($text);
}

=item ($llx,$lly,$urx,$ury) = $font->bbox $text

Returns the texts bounding-box as if it were at size 1.

=cut

sub bbox {
	my ($self,$text,%opts)=@_;
	my $enc=$opts{-encode}||$self->{' encoding'};
	my $width=$self->width(substr($text,0,length($text)-1),$enc);
	my @f=@{$self->{' chrbbx'}{$enc}{unpack("C",substr($text,0,1))}};
	my @l=@{$self->{' chrbbx'}{$enc}{unpack("C",substr($text,-1,1))}};
	my ($high,$low);
	foreach (unpack("C*", $text)) {
		$high = $self->{' chrbbx'}{$enc}{$_}->[3]>$high ? $self->{' chrbbx'}{$enc}{$_}->[3] : $high;
		$low  = $self->{' chrbbx'}{$enc}{$_}->[1]<$low  ? $self->{' chrbbx'}{$enc}{$_}->[1] : $low;
	}
	return map {$_/1000} ($f[0],$low,(($width*1000)+$l[2]),$high);
}

=item ($llx,$lly,$urx,$ury) = $font->bbox_ucs2 $ucs2text

Returns the texts bounding-box as if it were at size 1.

=cut

sub bbox_ucs2 {
	my ($self,$text)=@_;
	my $width=$self->width_ucs2($text);
	my @f=@{$self->{' unibbx'}{vec($text,0,16)}};
	my @l=@{$self->{' unibbx'}{vec($text,(length($text)>>1)-1,16)}};
	my ($high,$low);
	foreach my $x (0..(length($text)>>1)-1) {
		$high = $self->{' unibbx'}{vec($text,$x,16)}->[3]>$high ? $self->{' unibbx'}{vec($text,$x,16)}->[3] : $high;
		$low  = $self->{' unibbx'}{vec($text,$x,16)}->[1]<$low  ? $self->{' unibbx'}{vec($text,$x,16)}->[1] : $low;
	}
	return map {$_/1000} ($f[0],$low,(($width*1000)+$l[2]),$high);
}

=item ($llx,$lly,$urx,$ury) = $font->bbox_utf8 $utf8text

Returns the texts bounding-box as if it were at size 1.

=cut

sub bbox_utf8 {
	my ($self,$text)=@_;
	$text=utf8_to_ucs2($text);
	return $self->bbox_ucs2($text);
}

=item $font->encode $encoding

Changes the encoding of the font object. Since encodings are one virtual
in ::API2 for truetype fonts you DONT have to use 'clone'.

=cut

sub encode {
	my ($self,$enc)=@_;

	my $map=PDF::API2::UniMap->new($enc);

	my $ttf=$self->{' font'};
	my $upem = $ttf->{'head'}->read->{'unitsPerEm'};

	$self->{' encoding'}=$enc;
	$self->{' chrcid'}->{$enc}=$self->{' chrcid'}->{$enc}||{};
	$self->{' chrwidth'}->{$enc}=$self->{' chrwidth'}->{$enc}||{};
	if(scalar keys(%{$self->{' chrcid'}->{$enc}}) < 1) {
		foreach my $x (0..255) {
			$self->{' chrcid'}->{$enc}{$x}=
				$self->{' unicid'}{$map->{'c2u'}->{$x}||32}||$self->{' unicid'}{32};
			$self->{' chrwidth'}->{$enc}{$x}=
				$ttf->{'hmtx'}{'advance'}[$self->{' unicid'}{$map->{'c2u'}->{$x}||32}||$self->{' unicid'}{32}]*1000/$upem;
		}
	}
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

package PDF::API2::TTFont;

use PDF::API2::Util;
use Text::PDF::Utils;
use Text::PDF::Dict;

@ISA = qw( Text::PDF::Dict );

=item $font = PDF::API2::TTFont->new $pdf, $file, %options

Returns a font object.

Valid %options are:

	'-encoding' ... changes the encoding of the font from its default.

	'-pdfname' ... changes the reference-name of the font from its default.

B<On '-encoding':> The natively supported encodings are 'latin1','winansi' and 'macroman'.
Other Encodings are supported via PDF::API2::UniMap.

B<On '-pdfname':> The reference-name is normally generated automatically and can be
retrived via $pdfname=$font->name.

=cut

use Font::TTF::Font;

sub _read_ttf_structs {
	my ($file) = @_;
	my $data={};
	my ($tab,@glyphs);
	my $f = Font::TTF::Font->open($file);
	$f->{'post'}->read;
	$f->{'cmap'}->read;
	$f->{'loca'}->read;
	$f->{'head'}->read;
	$f->{'hhea'}->read;
	$f->{'OS/2'}->read;
	$f->{'hmtx'}->read;

	foreach my $t (@{$f->{cmap}{Tables}}) {
	#	printf "Table: %i\n",$i;
	#	printf "\tPlatform: %i\n",$t->{Platform};
	#	printf "\tEncoding: %i\n",$t->{Encoding};
	#	printf "\tVer: %i\n",$t->{Ver};
	#	foreach $g (sort {$a<=>$b} keys %{$t->{val}}) {
	#		# $t->{val}{$code};
	#		print "\t\t'$g' = ".$t->{val}{$g}."\n";
	#	}
	#	$i++;
		if($t->{'Platform'} == 3) {
			$tab=$t;
			last;
		}
	}

	if($tab->{'Platform'} == 3 && $tab->{'Encoding'} == 0) {
		@glyphs=map { $tab->{val}{$_}||0 } (0xf000 .. 0xf0ff);
	} else {
		@glyphs=map { $tab->{val}{$_}||0 } (0 .. 127,
			0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
			0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F,
			0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
			0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178,
			0xA0 .. 0xFF);
	}

	$data->{char}=[];
	foreach my $c (0..255) {
		$data->{char}->[$c]=$f->{'post'}->{'VAL'}[$glyphs[$c]];
	#	$g=$glyphs[$c];
	#	$n=$f->{'post'}->{'VAL'}[$g];
	#	printf "0x%04X: '%s' : gid=%i\n",$c,$n,$g;
	}

	my $upem = $f->{'head'}->read->{'unitsPerEm'};

	$data->{fontname};
	$data->{fontbbox}=[
		int($f->{'head'}{'xMin'} * 1000 / $upem),
        	int($f->{'head'}{'yMin'} * 1000 / $upem),
        	int($f->{'head'}{'xMax'} * 1000 / $upem),
        	int($f->{'head'}{'yMax'} * 1000 / $upem)
        ];
	$data->{ascender}=int($f->{'hhea'}->read->{'Ascender'} * 1000 / $upem);
	$data->{descender}=int($f->{'hhea'}{'Descender'} * 1000 / $upem);
	$data->{italicangle}=$f->{'post'}->{italicAngle};
	$data->{isfixedpitch}=$f->{'post'}->{isFixedPitch};
	$data->{underlineposition}=$f->{'post'}->{underlinePosition};
	$data->{underlinethickness}=$f->{'post'}->{underlineThickness};
	$data->{stemv}=0;
	$data->{stemh}=0;
	$data->{maxwidth}=int($font->{'hhea'}{'advanceWidthMax'} * 1000 / $upem);
	$data->{missingwidth}=int($font->{'hhea'}{'advanceWidthMax'} * 1000 / $upem) + 2;
	$data->{flags} = 0;
	$data->{flags} |= 1 if ($f->{'OS/2'}->read->{'bProportion'} == 9);
	$data->{flags} |= 2 unless ($f->{'OS/2'}{'bSerifStyle'} > 10 && $f->{'OS/2'}{'bSerifStyle'} < 14);
	$data->{flags} |= 8 if ($f->{'OS/2'}{'bFamilyType'} == 2);
	$data->{flags} |= 32; # if ($f->{'OS/2'}{'bFamilyType'} > 3);
	$data->{flags} |= 64 if ($f->{'OS/2'}{'bLetterform'} > 8);;

	foreach my $k ( keys %{$f->{'post'}->{'STRINGS'}} ) {
		my $g = $f->{'post'}->{'STRINGS'}{$k};
		$data->{wx}->{$k} = $f->{'hmtx'}{'advance'}[$g]*1000/$upem;
		$f->{'loca'}->{'glyphs'}[$g]->read;
		$data->{bbox}->{$k} = [
			$f->{'loca'}->{'glyphs'}[$g]->{'xMin'} * 1000 / $upem,
			$f->{'loca'}->{'glyphs'}[$g]->{'yMin'} * 1000 / $upem,
			$f->{'loca'}->{'glyphs'}[$g]->{'xMax'} * 1000 / $upem,
			$f->{'loca'}->{'glyphs'}[$g]->{'yMax'} * 1000 / $upem
		];
#####		printf "'$k' : gid=%i, u=0x%04X\n",,$map[$f->{'post'}->{'STRINGS'}{$k}];
	}

	$data->{capheight}=$f->{'OS/2'}->{CapHeight}
		|| $data->{bbox}->{H}->[3]
		|| int($data->{fontbbox}->[3]*0.8);
	$data->{xheight}=$f->{'OS/2'}->{xHeight}
		|| $data->{bbox}->{x}->[3]
		|| int($data->{fontbbox}->[3]*0.4);

	return($data,$f);
}

sub new {
	my ($class,$pdf,$file,@opts) = @_;
	my $self;
	my %opts=();
	die "cannot find font '$file' ..." unless(-f $file);
	%opts=@opts if((scalar @opts)%2 == 0);
	$class = ref $class if ref $class;
	my ($data,$font)=_read_ttf_structs($file);

#================================================
# creating the font-descriptor
#================================================
	my $des=PDFDict();
	$pdf->new_obj($des);
	$des->{'Type'}=PDFName('FontDescriptor');
	$des->{'FontName'}=PDFName($data->{fontname});
	$des->{'FontBBox'}=PDFArray(map { PDFNum($_ || 0) } @{$data->{fontbbox}});
	$des->{'Ascent'}=PDFNum($data->{ascender});
	$des->{'Descent'}=PDFNum($data->{descender});
	$des->{'ItalicAngle'}=PDFNum($data->{italicangle});
	$des->{'CapHeight'}=PDFNum($data->{capheight});
	$des->{'StemV'}=PDFNum($data->{stemv});
	$des->{'StemH'}=PDFNum($data->{stemh});
	$des->{'XHeight'}=PDFNum($data->{xheight});
	$des->{'Flags'}=PDFNum($data->{flags}) if(defined $data->{flags});
	$des->{'FontFile2'}=PDFDict();

	$pdf->new_obj($des->{'FontFile2'});
	$des->{'FontFile2'}->{Filter}=PDFName('FlateDecode');
	$des->{'FontFile2'}->{' font'}=$font;
	$des->{'FontFile2'}->{' streamfile'}=$file;

#================================================
# creating the default encoded object
#	(either latin1 or symbol)
#================================================
	my $df=$class->SUPER::new();
	$pdf->new_obj($df);
	$df->{' data'}=$data;
	$df->{'Type'} = PDFName('Font');
	$df->{'Subtype'} = PDFName('TrueType');
	$df->{'BaseFont'} = PDFName($data->{fontname});
	$df->{' apiname'} = 'tFx'.pdfkey($data->{fontname},%opts);
	$df->{'Name'} = PDFName($df->{' apiname'});
	$df->{'FirstChar'} = PDFNum(1);
	$df->{'LastChar'} = PDFNum(255);
	$df->{'FontDescriptor'} = $des;
	$df->{'Encoding'}=PDFDict();
	$df->{'Encoding'}->{'Type'}=PDFName('Encoding');
	$df->{'Encoding'}->{'BaseEncoding'}=PDFName('WinAnsiEncoding');
	my $notdefbefore=1;
	my @w=();
	foreach my $w (1..255) {
		if(!defined($data->{char}->[$w]) ||($data->{char}->[$w] eq '.notdef')) {
			$notdefbefore=1;
			next;
		} else {
			if($notdefbefore) {
				push(@w,PDFNum($w))
			}
			$notdefbefore=0;
			push(@w,PDFName($data->{char}->[$w]));
		}
	}
	$df->{'Encoding'}->{'Differences'}=PDFArray(@w);

	@w = map {
		PDFNum($data->{'wx'}{$_ || '.notdef'} || 300)
	} map {
		$data->{'char'}[$_]
	} (1..255);
	$df->{'Widths'}=PDFArray(@w);

#================================================
# creating the type0 pseudo object
#================================================
	$self = $class->SUPER::new();
	$pdf->new_obj($self);
	$self->{' std'}=$df
	$self->{'Type'} = PDFName("Font");
	$self->{'Subtype'} = PDFName('Type0');
	$self->{'BaseFont'} = PDFName($data->{fontname}.'+T0');
	$self->{' apiname'} = 't0Fx'.pdfkey($data->{fontname},%opts);
	$self->{'Name'} = PDFName($self->{' apiname'});
	$self->{'Encoding'} = PDFName('Identity-H');
	my $de=PDFDict();
	$pdf->new_obj($de);
	$self->{'DescendantFonts'} = PDFArray($de);

#================================================
# creating the cid encoded object
#================================================
	$de->{'Type'} = PDFName('Font');
	$de->{'Subtype'} = PDFName('CIDFontType2');
	$de->{'BaseFont'} = PDFName($data->{fontname}.'+CF2');
	$de->{'CIDSystemInfo'} = PDFDict();
	$de->{'CIDSystemInfo'}->{Registry} = PDFStr('Adobe');
	$de->{'CIDSystemInfo'}->{Ordering} = PDFStr('Identity');
	$de->{'CIDSystemInfo'}->{Supplement} = PDFNum(0);
	$de->{'DW'} = PDFNum(100);
	$de->{'W'} = PDFArray();
	$de->{'CIDToGIDMap'} = PDFName('Identity');
	$de->{'FontDescriptor'} = $des;

	return($self);
}

=item $font = PDF::API2::TTFont->new_api $api, $file, %options

Returns a corefont object. This method is different from 'new' that
it needs an PDF::API2-object rather than a Text::PDF::File-object.

=cut

sub new_api {
	my ($class,$api,@opts)=@_;

	my $obj=$class->new($api->{pdf},@opts);
	my $key=$obj->{' apiname'};

	$api->resource('Font',$key,$obj);
	$api->resource('Font',$obj->{' std'}->{' apiname'},$obj->{' std'});

	$api->{pdf}->out_obj($api->{pages});
	return($obj);
}


__END__

14 0 obj
<<
	/Type		/Font
	/Subtype	/Type0
	/Name		/T0xSOMETHING
	/BaseFont	/HeiseiMin-T0
	/Encoding	/Identity-H
	/DescendantFonts [ 15 0 R]
>>
endobj

15 0 obj
<<
	/Type		/Font
	/Subtype	/CIDFontType2
	/BaseFont	/HeiseiMin-CID2
	/CIDSystemInfo	<<
		/Registry	(Adobe)
		/Ordering	(Identity)
		/Supplement	0
	>>
	/FontDescriptor 17 0 R
	/CIDToGIDMap	/Identity
	/DW		1000
	/W		[]
>>
endobj

16 0 obj
<<
	/Type		/Font
	/Subtype	/TrueType
	/BaseFont	/HeiseiMin
	/Name		/TTxSOMETHING
	/FirstChar	1
	/LastChar	14
	/Widths		[  ]
	/Encoding <<
		/Type		/Encoding
		/BaseEncoding	/WinAnsiEncoding
		/Differences	[ ]
	>>
	/FontDescriptor 17 0 R
>>
endobj

17 0 obj
<<
	/Type		/FontDescriptor
	/FontName	/HeiseiMin
	/Flags		262178
	/FontBBox	[ -177 -269 1123 866]
	/MissingWidth	255
	/StemV		105
	/StemH		45
	/CapHeight	660
	/XHeight	394
	/Ascent		720
	/Descent	-270
	/Leading	83
	/MaxWidth	1212
	/AvgWidth	478
	/ItalicAngle	0
	/FontFile2	18 0 R
>>
endobj

18 0 obj
<<
	/Length 3252
	/Filter [ /FlateDecode ]
>>
stream

dfölsdlhjdslhjlödsjhldjhl

endstream
endobj


