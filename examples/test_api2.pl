#!/usr/bin/perl

use PDF::API2;
use PDF::API2::Util;
use Text::PDF::Utils;

$pdf=PDF::API2->new;

$page = $pdf->page;
$page->mediabox(595,842);

$font=$pdf->corefont('Helvetica',1);
$font->encode('latin1');
$txt=$page->text;
$txt->compress;
$txt->translate(100,100);
$txt->font($font,50);
$txt->text('Hello World !');

## $pdf->protect;

$pdf->saveas('empty.pdf');


__END__

`cp -f some.pdf empty.pdf`;

$pdf=PDF::API2->open('empty_old.pdf');
$pdf2=PDF::API2->open('some.pdf');

$page = $pdf->importpage($pdf2,1,2);
$page = $pdf->importpage($pdf2,1,3);

$font=$pdf->corefont('Helvetica',1);
$font->encode('latin1');
$txt=$page->text;
$txt->translate(100,100);
$txt->font($font,10);
$txt->text('Hello World !');

## $page->update;

$pdf->saveas('empty.pdf');


__END__

$pdf=PDF::API2->new;


$font=$pdf->corefont('Helvetica',1);


$page=$pdf->page;
$page->mediabox(595,842);

$txt=$page->text;
$txt->translate(100,100);
$txt->font($font,10);
$txt->text('Hello World !');

$bar=$pdf->barcode(
	-type => '3of9',
	-font => $font,
	-code => '010203045678909',
	-quzn => 20,
	-umzn => 10,
	-lmzn => 10,
	-zone => 30,
	-spcr => ' ',
);

$gfx=$page->gfx;
$gfx->image($bar,0,0,1,1);

$bar=$pdf->barcode(
	-type => '3of9ext',
	-font => $font,
	-code => 'PDF::API2::Test',
	-quzn => 20,
	-umzn => 10,
	-lmzn => 10,
	-zone => 30,
);

$gfx->image($bar,0,200,0.5,0.5);

$bar=$pdf->barcode(
	-type => 'code128b',
	-font => $font,
	-code => "Code 128",
	-quzn => 20,
	-umzn => 10,
	-lmzn => 10,
	-zone => 30,
);

$gfx->image($bar,0,400,1,1);

$y=500;

foreach $t (
	'(00) 38431853003496706',
	'(00) 384318530034967067',
	'(02) 08412345678905 (37) 23',
	'(01) 18410020706513 (20) 70',
	'(01) 08412345678905 (10) 4512XA (00) 384123451234567899 (15) 930120',
	'(01) 08412345678905 (10) 451XA2 (00) 384123451234567899 (15) 930120'
) {
	$bar=$pdf->barcode(
		-type => 'ean128',
		-font => $font,
		-code => $t,
		-quzn => 20,
		-umzn => 0,
		-lmzn => 0,
		-zone => 20,
		-fnsz => 8,
		-text => $t
	);

	$gfx->barcode($bar,$bar->{' w'}/2,$y,1,1);
	$y+=50;
}

$pdf->saveas("$0.pdf");

exit;

__END__


#=== sRGB - ColorSpace ===
#  1475 0 obj
#  [ 
#	/CalRGB << 
#		/WhitePoint [ 0.95049 1 1.08897 ] 
#		/Gamma [ 2.22218 2.22218 2.22218 ] 
#		/Matrix [ 0.41238 0.21259 0.01929 0.35757 0.71519 0.11919 0.1805 0.07217 0.95049 ] 
#	>> 
#  ]
#  endobj


$cs=$pdf->colorspace(
	-type=> 'Lab',
	-whitepoint => [0.95049,1,1.08897],
	-blackpoint => [0,0,0],
	-range => [-500,500,-200,200],
	-gamma => [2.22218,2.22218,2.22218]
);

foreach $l (0..10) {
	$page=$pdf->page;
	$page->mediabox(300,300);
	$gfx=$page->gfx;

	foreach $x (-20..20) {
		foreach $y (-20..20) {
			$gfx->fillcolorbyspace($cs,$l*10,$x*10,$y*10);
			$gfx->rect(100+$x*5,100+$y*5,10,10);
			$gfx->fill;
		}
	}
}

$pdf->saveas("$0.pdf");

exit;

__END__

$csd=PDFDict();

$csd->{WhitePoint}=PDFArray(PDFNum(1),PDFNum(1),PDFNum(1));
$csd->{BlackPoint}=PDFArray(PDFNum(0),PDFNum(0),PDFNum(0));
## $csd->{Gamma}=PDFArray(PDFNum(2.22218),PDFNum(2.22218),PDFNum(2.22218));
$csd->{Gamma}=PDFArray(PDFNum(4),PDFNum(3),PDFNum(2));
$csd->{Matrix}=PDFArray(
	PDFNum(0.41238),PDFNum(0.21259),PDFNum(0.01929),
	PDFNum(0.35757),PDFNum(0.71519),PDFNum(0.11919),
	PDFNum(0.1805),PDFNum(0.07217),PDFNum(0.95049)
);

$cs=PDFArray(
	PDFName('CalRGB'),$csd
);

$cs=$pdf->colorspace($cs);

foreach $col (qw(
	aqua blueviolet crimson 
	darkgreen gold indianred 
	indigo navy orange 
	orangered purple red 
	royalblue violet yellow 
	yellowgreen
)) {
	$page=$pdf->page;
	$page->mediabox(300,300);
	$gfx=$page->gfx;
	$gfx->fillcolorbyspace($cs,namecolor($col));
	$gfx->rect(0,0,300,300);
	$gfx->fill;
	$gfx->fillcolor(namecolor($col));
	$gfx->rect(150,150,300,300);
	$gfx->fill;
}

$pdf->saveas("$0.pdf");

exit;

__END__

#$curz=$font->clone('ebcdic-uk');
#$curz->encode('ebcdic-uk');
#$zpfd=$pdf->corefont('ZapfDingbats');
#$zpfd->encode('adobe-zapf-dingbats');

#$high=$pdf->psfont('HighlanderITC-Book.pfb','HighlanderITC-Book.afm');

#$tt=$pdf->ttfont('/share/_fonts_/mono.dir/bates_regular.ttf');

#$page=$pdf->page;
#$page->mediabox(300,300);
#$txt=$page->text;
#$txt->translate(10,10);
#$txt->font($font,10);
#$txt->text('Hello World !');
#$txt->font($zpfd,10);
#$txt->text('Hello World !');
#$txt->font($curz,10);
#$txt->text('Hello World !');
#$txt->cr(-10);
#$txt->font($high,10);
#$txt->hspace(200);
#$txt->text('Hello World !');

$page=$pdf->page;
$page->mediabox(300,300);

$gfx=$page->gfx;
$gfx->move(10,10);
$gfx->line(100,100);
$gfx->bogen(100,100,200,200,100,0,1,0);
$gfx->stroke;

#$img=$pdf->image('test.jpg');
#$gfx->image($img,0,0,$img->width,$img->height);

#$txt=$page->text;

#$txt->font($tt,20);
#$txt->translate(50,50);
#$txt->text('Hello Fun TTF !!!');

$page=$pdf->page;
$page->mediabox(300,300);



$gfx=$page->gfx;
#$img=$pdf->image('cleo.png');
#$gfx->image($img,0,0,$img->width/2,$img->height/2);
$gfx->linewidth(10);
$gfx->strokecolor(1,0,0);
$gfx->move(10,10);
$gfx->line(100,100);
$gfx->bogen(100,100,200,200,100,0,1,1);
$gfx->stroke;


#	aqua blueviolet  crimson darkgreen gold indianred indigo navy orange orangered purple red royalblue violet yellow yellowgreen
	#fa8 #ffaa88 #cc44ff #ccc444fff #cccc4444ffff
foreach $col (qw(
	!eeffff
	!ccffff
	!aaffff
	!88ffff
	!66ffff
	!44ffff
	!22ffff
	!00ffff
)) {
	$page=$pdf->page;
	$page->mediabox(300,300);
	$txt=$page->text;
	$txt->font($font,20);
	$txt->text("color(rgb/cmyk) = '$col'");
	$gfx=$page->gfx;
	print STDERR "$col\n";
	$gfx->fillcolorbyname($col,1);
	$gfx->rect(50,100,100,100);
	$gfx->fill;
	$gfx->fillcolorbyname($col,0);
	$gfx->rect(150,100,100,100);
	$gfx->fill;
}


$pdf->saveas("$0.pdf");

exit;

__END__

#=================================================
$pdf=PDF::API2->open("$0.pdf");
$font=$pdf->corefont('Times-Roman');
$page=$pdf->openpage(2);

$txt=$page->text;
$txt->font($font,20);
$txt->text('Hello Update !');

$page->update;

$pdf->update;

exit;

__END__
ADOBE:

6 0 obj
<< 
/Filter /Standard 
/R 2 
/O (k'é·ŸZ‡H1îÕÓó”/Ó:•¥|	6h»ï$¿1)
/U (/{´¢‰{O÷½¥¨P2\r©Ä]Õ0ì ]åkÌ)
/P -60 
/V 1 
/Length 40 
>> 
endobj
11 0 obj
<< /S 36 /Filter /FlateDecode /Length 12 0 R >> 
stream
—e8RİıWG¨ç9@ÁıÍŠH\A…vÜä,@ÊÓXqDèKFë×
Œ³T
endstream
endobj

<<
/Length 40
/Filter /Standard
/O (k'é·ŸZ‡H1îÕÓó”/Ó:•¥|\t6h»ï$¿1)
/P -60
/R 2
/U (/{´¢‰{O÷½¥¨P2\r©Ä]Õ0ì ]åkÌ)
/V 1
>>
endobj
5 0 obj
<<
/Length 98
>>
stream
²¨4÷Ò¼—Ÿt[b²¡QwB9©[ÿ'm-°çVöğ:ÚD5šòJÓ~òjªÌ†ë‡Ëï¦l
óÖÊ[ØLvšà‡fí±X'’> ï+Ä2z_zS†O³4š€ú
endstream
endobj
