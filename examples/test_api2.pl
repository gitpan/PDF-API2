#!/usr/bin/perl

sub smack {
	return;
	my($name,$self,$pdf)=@_;
	printf("%s : %d %d R\n",$name, @{$pdf->{' objects'}{$self->uid}}[0..1]);
	foreach my $k (keys %{$self}) {
		printf "%s\t'$k' => ",$name;
		if(ref($self->{$k})=~/Array$/) {
			print "\n";
			smack("$name :\t'$k'",$self->{$k},$pdf);
		} elsif(ref($self->{$k})=~/Name$/) {
			print "\n";
			smack("$name :\t'$k'",$self->{$k},$pdf);
		} elsif(ref($self->{$k})=~/ARRAY/) {
			eval {
				printf "[ '%s' ]\n",join("','",map {$_->val} @{$self->{$k}});
			};
			if($@) {
				print "$self->{$k}\n";
			}
		} else {
			print "$self->{$k}\n";
		}
	}
}

use PDF::API2;
use PDF::API2::Util;
use Text::PDF::Utils;

$pdf=PDF::API2->new;

# $pdf->encrypt('','');

$font=$pdf->corefont('Helvetica',1);

smack('font',$font,$pdf->{pdf});

$page=$pdf->page;
$page->mediabox(595,842);

smack('page',$page,$pdf->{pdf});

$txt=$page->text;
$txt->translate(10,10);
$txt->font($font,10);
$txt->text('Hello World !');

$gfx=$page->gfx;

$gfx->linejoin(1);

$gfx->fillcolorbyname('red');
$gfx->pie3d(200,100,100,70,200,290,20);
$gfx->fillstroke;

$gfx->fillcolorbyname('green');
$gfx->pie3d(200,100,100,70,290,390,20);
$gfx->fillstroke;

$gfx->fillcolorbyname('yellow');
$gfx->pie3d(200,100,100,70,80,200,20);
$gfx->fillstroke;

$gfx->fillcolorbyname('lightblue');
$gfx->pie3d(200,300,100,70,10,320,20,1);
$gfx->fillstroke;

$gfx->fillcolorbyname('orange');
$gfx->pie3d(200,500,100,70,-80,250,20,1);
$gfx->fillstroke;

$gfx->fillcolorbyname('orange');
$gfx->pie3d(200,700,100,70,100,420,20,1);
$gfx->fillstroke;



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
