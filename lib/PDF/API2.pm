#==================================================================
#
# Copyright 1999-2001 Alfred Reibenschuh <areibens@cpan.org>.
#
# This library is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself. 
#
#==================================================================
package PDF::API2;

=title PDF::API2

=head1 NAME

PDF::API2 - The Next Generation API for creating and modifing PDFs.

=head1 SYNOPSIS

	use PDF::API2;

	$pdf = PDF::API2->new;
	$pdf = PDF::API2->open('some.pdf');
	$page = $pdf->page;
	$page = $pdf->openpage($pagenum);
	$img = $pdf->image('some.jpg');
	$font = $pdf->corefont('Times-Roman');
	$font = $pdf->psfont('Times-Roman.pfb','Times-Roman.afm');
	$font = $pdf->ttfont('TimesNewRoman.ttf');

=cut

use Text::PDF::File;
use Text::PDF::AFont;
use Text::PDF::Page;
use Text::PDF::Utils;
use Text::PDF::TTFont;
use Text::PDF::TTFont0;

use PDF::API2::Util;

use Math::Trig;
use POSIX qw( ceil floor );

=head1 METHODS

=head2 PDF::API2

=item $pdf = PDF::API->new

=cut

sub new {
	my $class=shift(@_);
	my %opt=@_;
	my $self={};
	bless($self);
	$self->default('pdf',Text::PDF::File->new);
	$self->default('Compression',1);
	$self->default('subset',1);
	foreach my $para (keys(%opt)) {
		$self->default($para,$opt{$para});
	}
	$self->{pdf}->{' version'} = 3;
	$self->{pages} = Text::PDF::Pages->new($self->{pdf});
	$self->{pages}->proc_set(qw( PDF Text ImageB ImageC ImageI ));
	$self->{catalog}=$self->{pdf}->{Root};
	$self->{pagestack}=[];
	my $dig=digest16($class,$self,%opt);
       	$self->{pdf}->{'ID'}=PDFArray(PDFStr($dig),PDFStr($dig));
       	$self->{pdf}->{' id'}=$dig;
	return $self;
}

sub proc_pages {
	my ($pdf, $pgs) = @_;
	my ($pg, $pgref, @pglist);

	if(defined($pgs->{Resources})) {
		eval {
			$pgs->{Resources}->realise;
		};
	}
	foreach $pgref ($pgs->{'Kids'}->elementsof) {
		$pg = $pdf->read_obj($pgref);
		if ($pg->{'Type'}->val =~ m/^Pages$/o) {
			push(@pglist, proc_pages($pdf, $pg));
		} else {
			$pgref->{' pnum'} = $pcount++;
			if(defined($pg->{Resources})) {
				eval {
					$pg->{Resources}->realise;
				};
			}
			push (@pglist, $pgref);
		}
	}
	return(@pglist);
}

=item $pdf = PDF::API->open $pdffile

Opens an existing PDF.

=cut

sub open {
	my $class=shift(@_);
	my $file=shift(@_);
	my %opt=@_;
	my $self={};
	bless($self);
	$self->default('Compression',1);
	$self->default('subset',1);
	$self->default('update',1);
	foreach my $para (keys(%opt)) {
		$self->default($para,$opt{$para});
	}
	$self->{pdf}=Text::PDF::File->open($file,1);
	$self->{pdf}->{'Root'}->realise;
	$self->{pages}=$self->{pdf}->{'Root'}->{'Pages'}->realise;
	my @pages=proc_pages($self->{pdf},$self->{pages});
	$self->{pagestack}=[sort {$a->{' pnum'} <=> $b->{' pnum'}} @pages];
	$self->{reopened}=1;
	return $self;
}

=item $page = $pdf->page

=item $page = $pdf->page $index

Returns a new page object or inserts-and-returns a new page at $index.

B<Note:> on $index
	
	-1 ... is inserted before the last page 
	1 ... is inserted before page number 1
	0 ... is simply appended

=cut

sub page {
	my $self=shift;
	my $index=shift || 0;
	my $page;
	if($index==0) {
		$page=PDF::API2::Page->new($self->{pdf},$self->{pages});
	} else {
		$page=PDF::API2::Page->new($self->{pdf},$self->{pages},$index);
	}
	$page->{' apipdf'}=$self->{pdf};
	$page->{' api'}=$self;
        $self->{pdf}->out_obj($page);
	if($index==0) {
		push(@{$self->{pagestack}},$page);
	} elsif($index<0) {
		splice(@{$self->{pagestack}},$index,0,$page);
	} else {
		splice(@{$self->{pagestack}},$index-1,0,$page);
	}
	return $page;
}

=item $pageobj = $pdf->openpage $index

Returns the pageobject of page $index.

B<Note:> on $index
	
	-1,0 ... returns the last page
	1 ... returns page number 1

=cut

sub openpage {
	my $self=shift @_;
	my $index=shift @_||0;
	my $page;
	if($index==0) {
		$page=PDF::API2::Page->coerce($self->{pdf},@{$self->{pagestack}}[-1]);
	} elsif($index<0) {
		$page=PDF::API2::Page->coerce($self->{pdf},@{$self->{pagestack}}[$index]);
	} else {
		$page=PDF::API2::Page->coerce($self->{pdf},@{$self->{pagestack}}[$index-1]);
	}
	
	$page->{' api'}=$self;
	return($page);
}

=item $pagenumber = $pdf->pages

Returns the number of pages in the document.

=cut

sub pages {
	my $self=shift @_;
	return scalar @{$self->{pagestack}};
}

=item $pdf->update

Updates a previously "opened" document after all changes have been applied.

=cut

sub update {
	my $self=shift @_;
	$self->{pdf}->append_file;
	close( $self->{pdf}->{' OUTFILE'} );
}

=item $pdf->saveas $file

Saves the document.

=cut

sub saveas {
	my ($this,$file)=@_;
	$this->{pdf}->out_file($file);
}

=item $string = $pdf->stringify

Returns the document in a string.

=cut

sub stringify {
	my ($this)=@_;
	my $fh = PDF::API2::IOString->new();
	$fh->open();
	eval {
		$this->{pdf}->out_file($fh);
	};
	my $str=${$fh->string_ref};
	$fh->realclose;
	return($str);
}

sub release {return(undef);}

=item $pdf->end

Destroys the document.

=cut

sub end {
	my $self=shift(@_);
	$self->{pdf}->release;
	$self->release;
	undef;
}

=item $pdf->info %infohash

Sets the info structure of the document.

=cut

sub info {
	my $self=shift @_;
	my %opt=@_;

	if(!defined($self->{pdf}->{'Info'})) {
        	$self->{pdf}->{'Info'}=PDFDict();
        	$self->{pdf}->new_obj($self->{'pdf'}->{'Info'});
	}

        map { $self->{pdf}->{'Info'}->{$_}=PDFStr($opt{$_}) } keys %opt;
        $self->{pdf}->out_obj($self->{pdf}->{'Info'});
}

=item $val = $pdf->default $parameter

=item $pdf->default $parameter, $val

Gets/Sets default values for the behaviour of ::API2.

=cut

sub default {
	my ($self,$parameter,$var)=@_;
	$parameter=~s/[^a-zA-Z\d]//g;
	$parameter=lc($parameter);
	my $temp=$self->{$parameter};
	if(defined $var) {
		$self->{$parameter}=$var;
	}
	return($temp);
}

=item $font = $pdf->corefont $fontname [, $lightembed]

Returns a new or existing adobe core font object.

B<Examples:>

	$font = $pdf->corefont('Times-Roman',1);
	$font = $pdf->corefont('Times-Bold');
	$font = $pdf->corefont('Helvetica',1);
	$font = $pdf->corefont('ZapfDingbats');

=cut

sub corefont {
	my ($self,$name,$light)=@_;
	my $key='COREx'.pdfkey($name);

        $self->{pages}->{'Resources'}
        	= $self->{pages}->{'Resources'} 
        	|| PDFDict();
 	$self->{pages}->{'Resources'}->{'Font'}
 		= $self->{pages}->{'Resources'}->{'Font'} 
 		|| PDFDict();
	if((defined $self->{pages}->{'Resources'}->{'Font'}->{$key}) && ($self->{reopened}==1)) {
		# we are here because we somehow created
		# the reopened pdf so we simulate a valid 
		# object without writing a new one
		$self->{pages}->{'Resources'}->{'Font'}->{$key}
			= PDF::API2::CoreFont->coerce(
				$self->{pages}->{'Resources'}->{'Font'}->{$key},$self->{pdf},$name,$key,$light
			);
	} else {
		$self->{pages}->{'Resources'}->{'Font'}->{$key}
			= $self->{pages}->{'Resources'}->{'Font'}->{$key} 
			|| PDF::API2::CoreFont->new(
				$self->{pdf},$name,$key,$light
			);
	}

	$self->{pdf}->out_obj($self->{pages});

	$self->{pages}->{'Resources'}->{'Font'}->{$key}->{' api'} = $self;

	return($self->{pages}->{'Resources'}->{'Font'}->{$key});
}


=item $font = $pdf->psfont $pfbfile,$afmfile

Returns a new or existing adobe type1 font object.

B<Examples:>

	$font = $pdf->psfont('Times-Book.pfb','Times-Book.afm');
	$font = $pdf->psfont('/fonts/Synest-FB.pfb','/fonts/Synest-FB.afm');
	$font = $pdf->psfont('../Highland-URW.pfb','../Highland-URW.afm');

=cut

sub psfont {
	my ($self,$pfb,$afm,$encoding,@glyphs)=@_;
	my $key='POSTx'.pdfkey($pfb.$afm);

        $self->{pages}->{'Resources'}=$self->{pages}->{'Resources'} || PDFDict();
        $self->{pages}->{'Resources'}->{'Font'}=$self->{pages}->{'Resources'}->{'Font'} || PDFDict();

	if((defined $self->{pages}->{'Resources'}->{'Font'}->{$key}) && ($self->{reopened}==1)) {
		$self->{pages}->{'Resources'}->{'Font'}->{$key}
			= PDF::API2::PSFont->new(
				$self->{pdf},$pfb,$afm,$key,$encoding,@glyphs
			);
	} else {
		$self->{pages}->{'Resources'}->{'Font'}->{$key}=
			$self->{pages}->{'Resources'}->{'Font'}->{$key} || PDF::API2::PSFont->new(
				$self->{pdf},$pfb,$afm,$key,$encoding,@glyphs
			);
	}
        $self->{pdf}->out_obj($self->{pages});

	$self->{pdf}->new_obj($self->{pages}->{'Resources'}->{'Font'}->{$key});
	$self->{pages}->{'Resources'}->{'Font'}->{$key}->{' api'}=$self;

	return($self->{pages}->{'Resources'}->{'Font'}->{$key});
}

=item $font = $pdf->ttfont $ttffile

Returns a new or existing truetype font object.

B<Examples:>

	$font = $pdf->ttfont('TimesNewRoman.ttf');
	$font = $pdf->ttfont('/fonts/Univers-Bold.ttf');
	$font = $pdf->ttfont('../Democratica-SmallCaps.ttf');

=cut

sub ttfont {
	my ($self,$file,$encoding)=@_;
	my $key='TRUEx'.pdfkey($file);

        $self->{pages}->{'Resources'}=$self->{pages}->{'Resources'} || PDFDict();
        $self->{pages}->{'Resources'}->{'Font'}=$self->{pages}->{'Resources'}->{'Font'} || PDFDict();

	if((defined $self->{pages}->{'Resources'}->{'Font'}->{$key}) && ($self->{reopened}==1)) {
		$self->{pages}->{'Resources'}->{'Font'}->{$key}=PDF::API2::TTFont->new(
				$self->{pdf},$file,$key,$encoding
			);
	} else {
		$self->{pages}->{'Resources'}->{'Font'}->{$key}=
			$self->{pages}->{'Resources'}->{'Font'}->{$key} || PDF::API2::TTFont->new(
				$self->{pdf},$file,$key,$encoding
			);
	}

        $self->{pdf}->out_obj($self->{pages});

        $self->{pages}->{'Resources'}->{'Font'}->{$key}->{' api'}=$self;

	return($self->{pages}->{'Resources'}->{'Font'}->{$key});
}

=item $img = $pdf->image $file

Returns a new image object.

B<Examples:>

	$img = $pdf->image('yetanotherfun.jpg');
	$img = $pdf->image('truly24bitpic.png');
	$img = $pdf->image('reallargefile.pnm');

=cut

sub image {
	my ($self,$file)=@_;

        $self->{pages}->{'Resources'}=$self->{pages}->{'Resources'} || PDFDict();
        $self->{pages}->{'Resources'}->{'XObject'}=$self->{pages}->{'Resources'}->{'XObject'} || PDFDict();

        my $obj=PDF::API2::Image->new($self->{pdf},$file);

        $self->{pages}->{'Resources'}->{'XObject'}->{$obj->{' apiname'}}=$obj;

        $self->{pdf}->out_obj($self->{pages});

	$obj->{' api'}=$self;

	return($obj);
}

=item $shadeing = $pdf->shade

Returns a new shading object.

=cut

sub shade {
	my ($self,$obj,$name)=@_;
	my $key='SHADEx'.pdfkey($name || 'shade'.time().rand(0x7fffff));
	$obj=$obj || PDFDict();
	$obj->{' apiname'}=$key;
	$obj->{' apipdf'}=$self->{pdf};
	$obj->{' api'}=$self;
	$self->{pdf}->new_obj($obj);
        $self->{pages}->{'Resources'}=$self->{pages}->{'Resources'} || PDFDict();
        $self->{pages}->{'Resources'}->{'Shading'}=$self->{pages}->{'Resources'}->{'Shading'} || PDFDict();
        $self->{pages}->{'Resources'}->{'Shading'}->{$key}=$obj;
        $self->{pdf}->out_obj($self->{pages});

	return($obj);
}

=item $cs = $pdf->colorspace %parameters

Returns a new colorspace object.

B<Examples:>

	$cs = $pdf->colorspace(
		-type => 'CalRGB',
		-whitepoint => [ 0.9, 1, 1.1 ],
		-blackpoint => [ 0, 0, 0 ],
		-gamma => [ 2.2, 2.2, 2.2 ],
		-matrix => [
			0.41238, 0.21259, 0.01929,
			0.35757, 0.71519, 0.11919,
			0.1805,  0.07217, 0.95049
		]
	);

	$cs = $pdf->colorspace(
		-type => 'CalGray',
		-whitepoint => [ 0.9, 1, 1.1 ],
		-blackpoint => [ 0, 0, 0 ],
		-gamma => 2.2
	);

	$cs = $pdf->colorspace(
		-type => 'Lab',
		-whitepoint => [ 0.9, 1, 1.1 ],
		-blackpoint => [ 0, 0, 0 ],
		-gamma => [ 2.2, 2.2, 2.2 ],
		-range => [ -100, 100, -100, 100 ]
	);

	$cs = $pdf->colorspace(
		-type => 'Indexed',
		-base => 'DeviceRGB',
		-maxindex => 3,
		-whitepoint => [ 0.9, 1, 1.1 ],
		-blackpoint => [ 0, 0, 0 ],
		-gamma => [ 2.2, 2.2, 2.2 ],
		-colors => [
			[ 0,0,0 ],	# black = 0
			[ 1,1,1 ],	# white = 1
			[ 1,0,0 ],	# red = 2
			[ 0,0,1 ],	# blue = 3
		]
	);

=cut

sub colorspace {
	my ($self,@opt)=@_;
	my $key='COLORx'.pdfkey('color'.time().rand(0x7fffff));
	my $obj=PDF::API2::ColorSpace->new($self->{pdf},$key,@opt);
	$self->{pdf}->new_obj($obj);
        $self->{pages}->{'Resources'}=$self->{pages}->{'Resources'} || PDFDict();
        $self->{pages}->{'Resources'}->{'ColorSpace'}=$self->{pages}->{'Resources'}->{'ColorSpace'} || PDFDict();
        $self->{pages}->{'Resources'}->{'ColorSpace'}->{$key}=$obj;
        $obj->{' api'}=$self;
        $self->{pdf}->out_obj($self->{pages});
	return($obj);
}

sub extgstate {
	my ($self)=@_;
	my $key='EXTGSTATEx'.pdfkey('extgstate'.time().rand(0x7fffff));
	my $obj=PDF::API2::ExtGState->new($self->{pdf},$key);
	$self->{pdf}->new_obj($obj);
        $self->{pages}->{'Resources'}=$self->{pages}->{'Resources'} || PDFDict();
        $self->{pages}->{'Resources'}->{'ExtGState'}=$self->{pages}->{'Resources'}->{'ExtGState'} || PDFDict();
        $self->{pages}->{'Resources'}->{'ExtGState'}->{$key}=$obj;
        $obj->{' api'}=$self;
        $self->{pdf}->out_obj($self->{pages});
	return($obj);
}

#==================================================================
#	PDF::API2::Crypt
#==================================================================
#
# /Filter /Standard
# /O <...>
# /U <...>
# /V 1		if V > 1 then encryptKeyLen > 40
# /R 2
# /P -60
# /Length 40    only if V > 1
#
package PDF::API2::Crypt;

use strict;
use vars qw(@ISA $passwordPad $encryptKeyLen);
@ISA = qw();

use Text::PDF::Utils;
use PDF::API2::Util;
use PDF::API2::MD5 qw( md5 );
use Math::Trig;

$passwordPad = "\x28\xbf\x4e\x5e\x4e\x75\x8a\x41\x64\x00\x4e\x56\xff\xfa\x01\x08";
$passwordPad.= "\x2e\x2e\x00\xb6\xd0\x68\x3e\x80\x2f\x0c\xa9\xfe\x64\x53\x69\x7a";

$encryptKeyLen=5; # in bytes

sub new {
	my ($class,%opts)=@_;
	my $self={};
	bless $self,$class;
	my ($own,$usr,$ver,$perm,$rev,$len);

	$own=digest32(scalar localtime());
	$usr='';
	$ver=1;
	$rev=2;
	$perm=-60;
	$len=$encryptKeyLen * 8;

	$self->{' nocrypt'}=1;
	$self->{' filekey'}=fileKey($usr,$perm,$opts{-ID},$own);

	$self->{V}=PDFNum($ver);
	$self->{R}=PDFNum($rev);
	$self->{Filter}=PDFName('Standard');
	$self->{P}=PDFNum($perm);
	$self->{Length}=PDFNum($len);
	$self->{O}=PDFStr($own);
	$self->{U}=PDFStr(userKey($self->{' filekey'}));

	return($self);
}

sub encrypt {
	my ($self,$data)=@_;
	my $ekey=objKey($self->{' o'},$self->{' g'},$self->{' filekey'});
	$ekey=substr($ekey,0,$encryptKeyLen+5);
	return(rc4($ekey,$data));
}

sub reg {
	my ($self,$num,$gen,$enc)=@_;
	if(defined($num)) {
		$self->{' o'}=$num;
		$self->{' g'}=$gen;
		$self->{' e'}=$enc;
	}
	return(
		$self->{' o'},
		$self->{' g'},
		$self->{' e'}
	);
}

sub passPad {
	my ($pwd,$str)=@_;
	$str=substr($pwd.$passwordPad,0,32);
	return($str);
}

#------------------------------------
# filekey needs:
#	user password
#	/P	(permissions)
#	/ID	(file id)
#	/O	(owner key)
#------------------------------------

sub fileKey {
	my ($pwd,$p,$id,$o)=@_;
	my $str;
	$str=passPad($pwd);
	$str.=$o;
	$str.=pack('C', $p & 0xff);
	$str.=pack('C', ($p >> 8 ) & 0xff);
	$str.=pack('C', ($p >> 16) & 0xff);
	$str.=pack('C', ($p >> 24) & 0xff);
	$str.=$id;
	return md5($str);
}

#------------------------------------
# objKey needs:
#	objnum	
#	objgen	
#	fileKey
#------------------------------------

sub objKey {
	my ($num,$gen,$filekey)=@_;
	my $str;
	$str=substr($filekey,0,$encryptKeyLen);
	$str.=pack('C', $num & 0xff);
	$str.=pack('C', ($num >> 8 ) & 0xff);
	$str.=pack('C', ($num >> 16) & 0xff);
	$str.=pack('C', $gen & 0xff);
	$str.=pack('C', ($gen >> 8 ) & 0xff);
	return md5($str);
}

sub ownerKey {
	my ($pwd,$usr)=@_;
	my $str;
	$pwd=passPad($pwd);
	$pwd=substr($str,0,$encryptKeyLen);
	$usr=passPad($usr);
	$str=rc4($pwd,$usr);
	return($str);
}

sub userKey {
	my ($filekey)=@_;
	my $str=passPad('');;
	$filekey=substr($filekey,0,$encryptKeyLen);
	$str=rc4($filekey,$str);
	return($str);
}

sub rc4 ($$)
{
	my ($key,$buffer) = @_;

	my(@s,$x,$y,$i1,$i2,$i,$t);
	for($i=0;$i<256;$i++){
		$s[$i]=$i;
	}
	$i2=$i1=$y=$x=0;
	for($i=0;$i<256;$i++){
		$i2=(vec($key,$i1,8)+$s[$i]+$i2)%256;
		$t=$s[$i];
		$s[$i]=$s[$i2];
		$s[$i2]=$t;
		$i1=($i1+1)%length($key);
	}	
	for($i=0;$i<length($buffer);$i++){
		$x=($x+1)%256;
		$y=($s[$x]+$y)%256;
		$t=$s[$x];
		$s[$x]=$s[$y];
		$s[$y]=$t;
		$i1=($s[$x]+$s[$y])%256;
		vec($buffer,$i,8)^=$s[$i1];
	}

	return $buffer;
}

#==================================================================
#	PDF::API2::ColorSpace
#==================================================================
package PDF::API2::ColorSpace;

use strict;
use vars qw(@ISA);
@ISA = qw(Text::PDF::Array);

use Text::PDF::Utils;
use PDF::API2::Util;
use Math::Trig;

=head2 PDF::API2::ColorSpace

Subclassed from Text::PDF::Array.

=item $cs = PDF::API2::ColorSpace->new $pdf, $key, %parameters

Returns a new colorspace object (called from $pdf->colorspace).

=cut

sub new {
	my ($class,$pdf,$key,%opts)=@_;
	my $self = $class->SUPER::new();
	$self->{' apiname'}=$key;
	$self->{' apipdf'}=$pdf;

	if($opts{-type} eq 'CalRGB') {

		my $csd=PDFDict();
		$opts{-whitepoint}=$opts{-whitepoint} || [ 0.95049, 1, 1.08897 ];
		$opts{-blackpoint}=$opts{-blackpoint} || [ 0, 0, 0 ];
		$opts{-gamma}=$opts{-gamma} || [ 2.22218, 2.22218, 2.22218 ];
		$opts{-matrix}=$opts{-matrix} || [ 
			0.41238, 0.21259, 0.01929,
			0.35757, 0.71519, 0.11919,
			0.1805,  0.07217, 0.95049
		];
		
		$csd->{WhitePoint}=PDFArray(map {PDFNum($_)} @{$opts{-whitepoint}});
		$csd->{BlackPoint}=PDFArray(map {PDFNum($_)} @{$opts{-blackpoint}});
		$csd->{Gamma}=PDFArray(map {PDFNum($_)} @{$opts{-gamma}});
		$csd->{Matrix}=PDFArray(map {PDFNum($_)} @{$opts{-matrix}});

		$self->add_elements(PDFName($opts{-type}),$csd);

	} elsif($opts{-type} eq 'CalGray') {

		my $csd=PDFDict();
		$opts{-whitepoint}=$opts{-whitepoint} || [ 0.95049, 1, 1.08897 ];
		$opts{-blackpoint}=$opts{-blackpoint} || [ 0, 0, 0 ];
		$opts{-gamma}=$opts{-gamma} || 2.22218;
		$csd->{WhitePoint}=PDFArray(map {PDFNum($_)} @{$opts{-whitepoint}});
		$csd->{BlackPoint}=PDFArray(map {PDFNum($_)} @{$opts{-blackpoint}});
		$csd->{Gamma}=PDFNum($opts{-gamma});
		
		$self->add_elements(PDFName($opts{-type}),$csd);

	} elsif($opts{-type} eq 'Lab') {

		my $csd=PDFDict();
		$opts{-whitepoint}=$opts{-whitepoint} || [ 0.95049, 1, 1.08897 ];
		$opts{-blackpoint}=$opts{-blackpoint} || [ 0, 0, 0 ];
		$opts{-range}=$opts{-range} || [ -200, 200, -200, 200 ];
		$opts{-gamma}=$opts{-gamma} || [ 2.22218, 2.22218, 2.22218 ];
		
		$csd->{WhitePoint}=PDFArray(map {PDFNum($_)} @{$opts{-whitepoint}});
		$csd->{BlackPoint}=PDFArray(map {PDFNum($_)} @{$opts{-blackpoint}});
		$csd->{Gamma}=PDFArray(map {PDFNum($_)} @{$opts{-gamma}});
		$csd->{Range}=PDFArray(map {PDFNum($_)} @{$opts{-range}});
		
		$self->add_elements(PDFName($opts{-type}),$csd);

	} elsif($opts{-type} eq 'Indexed') {

		my $csd=PDFDict();
		$opts{-base}=$opts{-base} || 'DeviceRGB';
		$opts{-maxindex}=$opts{-maxindex} || scalar(@{$opts{-colors}})-1;
		$opts{-whitepoint}=$opts{-whitepoint} || [ 0.95049, 1, 1.08897 ];
		$opts{-blackpoint}=$opts{-blackpoint} || [ 0, 0, 0 ];
		$opts{-gamma}=$opts{-gamma} || [ 2.22218, 2.22218, 2.22218 ];
		
		$csd->{WhitePoint}=PDFArray(map {PDFNum($_)} @{$opts{-whitepoint}});
		$csd->{BlackPoint}=PDFArray(map {PDFNum($_)} @{$opts{-blackpoint}});
		$csd->{Gamma}=PDFArray(map {PDFNum($_)} @{$opts{-gamma}});
		
		foreach my $col (@{$opts{-colors}}) {
			map { $csd->{' stream'}.=pack('C',$_); } @{$col};
		}
		$csd->{Filter}=PDFArray(PDFName('FlateDecode'));
		$self->add_elements(PDFName($opts{-type}),PDFName($opts{-base}),PDFNum($opts{-maxindex}),$csd);

	}

	return($self);
}


#==================================================================
#	PDF::API2::ExtGState
#==================================================================
package PDF::API2::ExtGState;

use strict;
use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict);

use Text::PDF::Dict;
use Text::PDF::Utils;
use Math::Trig;
use PDF::API2::Util;

=head2 PDF::API2::ExtGState

Subclassed from Text::PDF::Dict.

=item $egs = PDF::API2::ExtGState->new @parameters

Returns a new extgstate object (called from $pdf->extgstate).

=cut

sub new {
	my ($class,$pdf,$key)=@_;
	my $self = $class->SUPER::new;
	$self->{' apiname'}=$key;
	$self->{' apipdf'}=$pdf;
	$self->{Type}=PDFName('ExtGState');
	return($self);
}

=item $egs->strokeadjust $boolean

=cut

sub strokeadjust {
	my ($self,$var)=@_;
	$self->{SA}=PDFBool($var);
	return($self);
}

=item $egs->strokeoverprint $boolean

=cut

sub strokeoverprint {
	my ($self,$var)=@_;
	$self->{OP}=PDFBool($var);
	return($self);
}

=item $egs->filloverprint $boolean

=cut

sub filloverprint {
	my ($self,$var)=@_;
	$self->{op}=PDFBool($var);
	return($self);
}

=item $egs->overprintmode $num

=cut

sub overprintmode {
	my ($self,$var)=@_;
	$self->{OPM}=PDFNum($var);
	return($self);
}

=item $egs->blackgeneration $obj

=cut

sub blackgeneration {
	my ($self,$obj)=@_;
	$self->{BG}=$obj;
	return($self);
}

=item $egs->blackgeneration2 $obj

=cut

sub blackgeneration2 {
	my ($self,$obj)=@_;
	$self->{BG2}=$obj;
	return($self);
}

=item $egs->undercolorremoval $obj

=cut

sub undercolorremoval {
	my ($self,$obj)=@_;
	$self->{UCR}=$obj;
	return($self);
}

=item $egs->undercolorremoval2 $obj

=cut

sub undercolorremoval2 {
	my ($self,$obj)=@_;
	$self->{UCR2}=$obj;
	return($self);
}

=item $egs->transfer $obj

=cut

sub transfer {
	my ($self,$obj)=@_;
	$self->{TR}=$obj;
	return($self);
}

=item $egs->transfer2 $obj

=cut

sub transfer2 {
	my ($self,$obj)=@_;
	$self->{TR2}=$obj;
	return($self);
}

=item $egs->halftone $obj

=cut

sub halftone {
	my ($self,$obj)=@_;
	$self->{HT}=$obj;
	return($self);
}

sub halftonephase {
	my ($self,$obj)=@_;
	$self->{HTP}=$obj;
	return($self);
}

sub smoothness {
	my ($self,$var)=@_;
	$self->{SM}=PDFNum($var);
	return($self);
}

sub font {
	my ($self,$font,$size)=@_;
	$self->{Font}=PDFArray(PDFName($font->{' apiname'}),PDFNum($size));
	return($self);
}

sub linewidth {
	my ($self,$var)=@_;
	$self->{LW}=PDFNum($var);
	return($self);
}

sub linecap {
	my ($self,$var)=@_;
	$self->{LC}=PDFNum($var);
	return($self);
}

sub linejoin {
	my ($self,$var)=@_;
	$self->{LJ}=PDFNum($var);
	return($self);
}

sub meterlimit {
	my ($self,$var)=@_;
	$self->{ML}=PDFNum($var);
	return($self);
}

sub dash {
	my ($self,@dash)=@_;
	$self->{ML}=PDFArray( map { PDFNum($_); } @dash );
	return($self);
}

sub flatness {
	my ($self,$var)=@_;
	$self->{FL}=PDFNum($var);
	return($self);
}

sub renderingintent {
	my ($self,$var)=@_;
	$self->{FL}=PDFName($var);
	return($self);
}


#==================================================================
#	PDF::API2::Font
#==================================================================
package PDF::API2::Font;
use strict;
use PDF::API2::UniMap;
use PDF::API2::Util;
use Text::PDF::Utils;

=head2 PDF::API2::Font

=item $font2 = $font->clone $subkey

Returns a clone of a font object.

=cut

sub copy { die "COPY NOT IMPLEMENTED !!!";}

sub clone {
	my $self=shift @_;
	my $key=shift @_;
	my $res=$self->copy($self->{' apipdf'});
	$self->{' apipdf'}->new_obj($res);
	$res->{' apiname'}.='xCx'.pdfkey($key);
	$res->{'Name'}=PDFName($res->{' apiname'});

        $res->{' api'}->{pages}->{'Resources'}=$res->{' api'}->{pages}->{'Resources'} || PDFDict();
        $res->{' api'}->{pages}->{'Resources'}->{'Font'}=$res->{' api'}->{pages}->{'Resources'}->{'Font'} || PDFDict();
	$res->{' api'}->{pages}->{'Resources'}->{'Font'}->{$res->{' apiname'}}=$res;

	return($res);
}


=item @glyphs = $font->glyphs $encoding

Returns an array with glyphnames of the specified encoding.

=cut

sub glyphs {
	my ($self,$enc) = @_;
	$self->{' apipdf'}->{' encoding'}=$self->{' apipdf'}->{' encoding'} || {};
	$self->{' apipdf'}->{' encoding'}->{$enc}=$self->{' apipdf'}->{' encoding'}->{$enc} || PDF::API2::UniMap->new($enc);
	return($self->{' apipdf'}->{' encoding'}->{$enc}->glyphs);
}

=item $font->encode $encoding

Changes the encoding of the font object. If you want more than one encoding
for one font use 'clone' and then 'encode'.

=cut

sub encode {
	my $self=shift @_;
	my ($encoding,@glyphs)=@_;
	if(scalar @glyphs < 1) {
		eval {
			@glyphs=$self->glyphs($encoding);
		};
		$encoding='custom';
	}
	
	if($self->{' apifontlight'}==1) {
		$self->encodeProperLight($encoding,32,255,@glyphs);
	} else {
		$self->encodeProper($encoding,32,255,@glyphs);
	}
}


=item $pdfstring = $font->text $text

Returns a properly formated string-representation of $text
for use in the PDF.

=cut

sub text {
	my ($font,$text)=@_;
	my ($newtext);
	foreach my $g (0..length($text)-1) {
		$newtext.=
			(substr($text,$g,1)=~/[\x00-\x1f\\\{\}\[\]\(\)\xa0-\xff]/)
			? sprintf('\%03lo',vec($text,$g,8))
			: substr($text,$g,1) ;
	}
	return("($newtext)");
}

=item $wd = $font->width $text

Returns the width of $text as if it were at size 1.

=cut

sub width {
	my ($self,$text)=@_;
	my ($width);
	foreach (unpack("C*", $text)) {
		$width += $self->{' AFM'}{'wx'}{$self->{' AFM'}{'char'}[$_]};
	}
	$width/=1000;
	return($width);
}

#==================================================================
#	PDF::API2::CoreFont
#==================================================================
package PDF::API2::CoreFont;
use strict;
use PDF::API2::Util;
use Text::PDF::Utils;

use vars qw(@ISA);
@ISA = qw( Text::PDF::AFont PDF::API2::Font );

=head2 PDF::API2::CoreFont

Subclassed from Text::PDF::AFont and PDF::API2::Font.

=item $font = PDF::API2::CoreFont->new @parameters

Returns a adobe core font object (called from $pdf->corefont).

=cut

sub new {
	my ($class,$pdf,$name,$key,$light) = @_;
	my ($self) = {};

	$class = ref $class if ref $class;
	if($light==1) {
		$self = $class->SUPER::newCoreLight($pdf,$name,$key);
		$self->{' apifontlight'}=1;
	} else {
		$self = $class->SUPER::newCore($pdf,$name,$key);
	}
	$self->{' apiname'}=$key;
	$self->{' apipdf'}=$pdf;

	return($self);
}

sub coerce {
	my ($class,$font,$pdf,$name,$key,$light) = @_;
	my ($self) = {};
	
	$class = ref $class if ref $class;
	if($light==1) {
		$self = $class->SUPER::newCoreLight(undef,$name,$key);
		$self->{' apifontlight'}=1;
	} else {
		$self = $class->SUPER::newCore(undef,$name,$key);
	}
	$self->{' apiname'}=$key;
	$self->{' apipdf'}=$pdf;
 
	foreach my $k (keys %{$font}) {
		$self->{$k}=$font->{$k};
	}

	return($self);
}


#==================================================================
#	PDF::API2::PSFont
#==================================================================
package PDF::API2::PSFont;
use strict;
use PDF::API2::Util;
use Text::PDF::Utils;

use vars qw(@ISA);
@ISA = qw( Text::PDF::AFont PDF::API2::Font );

=head2 PDF::API2::PSFont

Subclassed from Text::PDF::AFont and PDF::API2::Font.

=item $font = PDF::API2::PSFont->new @parameters

Returns a adobe type1 font object (called from $pdf->psfont).

=cut

sub new {
	my ($class, @para) = @_;
	my ($self) = {};

	$class = ref $class if ref $class;
	$self = $class->SUPER::new(@para);

	$self->{' apiname'}=$para[3];
	$self->{' apipdf'}=$para[0];

	return($self);
}


#==================================================================
#	PDF::API2::TTFont
#==================================================================
package PDF::API2::TTFont;
use strict;
use PDF::API2::UniMap qw( utf8_to_ucs2 );
use PDF::API2::Util;
use Text::PDF::Utils;

use vars qw(@ISA);
@ISA = qw( Text::PDF::TTFont0 PDF::API2::Font );

=head2 PDF::API2::TTFont

Subclassed from Text::PDF::TTFont0 and PDF::API2::Font.

=item $font = PDF::API2::TTFont->new $pdf,$ttffile,$pdfname

Returns a truetype font object (called from $pdf->ttfont).

=cut

sub new {
	my ($class, $pdf,$file,$name) = @_;

	$class = ref $class if ref $class;
	my $self = $class->SUPER::new($pdf,$file,$name, -subset => 1);

	my $ttf=$self->{' font'};
	$ttf->{'cmap'}->read;
	$ttf->{'hmtx'}->read;
	$ttf->{'post'}->read;
	my $upem = $ttf->{'head'}->read->{'unitsPerEm'};

	$self->{' unicid'}=();
	$self->{' uniwidth'}=();
	my @map=$ttf->{'cmap'}->reverse;
	foreach my $x (0..scalar(@map)) {
		$self->{' unicid'}{$map[$x]||0}=$x;
		$self->{' uniwidth'}{$map[$x]||0}=$ttf->{'hmtx'}{'advance'}[$x]*1000/$upem;
	}
	$self->{' encoding'}='latin1';
	$self->{' chrcid'}={};
	$self->{' chrcid'}->{'latin1'}=();
	$self->{' chrwidth'}={};
	$self->{' chrwidth'}->{'latin1'}=();
	foreach my $x (0..255) {
		$self->{' chrcid'}->{'latin1'}{$x}=$self->{' unicid'}{$x}||$self->{' unicid'}{32};
		$self->{' chrwidth'}->{'latin1'}{$x}=$ttf->{'hmtx'}{'advance'}[$self->{' unicid'}{$x}||$self->{' unicid'}{32}]*1000/$upem;
	}

	$self->{' apiname'}=$name;
	$self->{' apipdf'}=$pdf;

	return($self);
}

=item $pdfstring = $font->text $text

Returns a properly formated string-representation of $text
for use in the PDF.

=cut

sub text {
	my ($self,$text,$enc)=@_;
	$enc=$enc||$self->{' encoding'};
	my ($newtext);
	foreach (unpack("C*", $text)) {
		my $g=$self->{' chrcid'}{$enc}{$_};
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
	my ($newtext);
	foreach my $x (0..(length($text)>>1)-1) {
		my $g=$self->{' unicid'}{vec($text,$x,16)};
		$newtext.= sprintf('%04x',$g);
		vec($self->{' subvec'},$g,1)=1;
	}
	return("<$newtext>");
}

=item $wd = $font->width $text

Returns the width of $text as if it were at size 1.

=cut

sub width {
	my ($self,$text,$enc)=@_;
	$enc=$enc||$self->{' encoding'};
	my ($width);
	foreach (unpack("C*", $text)) {
		$width += $self->{' chrwidth'}{$enc}{$_};
	}
	$width/=1000;
	return($width);
}

=item $wd = $font->width_utf8 $text

Returns the width of $text as if it were at size 1,
but requires $text to be in UTF8.

=cut

sub width_utf8 {
	my ($self,$text)=@_;
	$text=utf8_to_ucs2($text);
	my ($width);
	foreach my $x (0..(length($text)>>1)-1) {
		$width += $self->{' uniwidth'}{vec($text,$x,16)};
	}
	$width/=1000;
	return($width);
}

=item $font->encode $encoding

Changes the encoding of the font object. Since encodings are one virtual
in ::API2 for truetype fonts you DONT have to use 'clone'.

=cut

sub encode {
	my ($self,$enc)=@_;

	$self->{' apipdf'}->{' encoding'}=$self->{' apipdf'}->{' encoding'} || {};
	$self->{' apipdf'}->{' encoding'}->{$enc}=$self->{' apipdf'}->{' encoding'}->{$enc} || PDF::API2::UniMap->new($enc);

	my $map=$self->{' apipdf'}->{' encoding'}->{$enc};

	my $ttf=$self->{' font'};
	my $upem = $ttf->{'head'}->read->{'unitsPerEm'};

	$self->{' encoding'}=$enc;
	$self->{' chrcid'}->{$enc}=$self->{' chrcid'}->{$enc}||();
	$self->{' chrwidth'}->{$enc}=$self->{' chrwidth'}->{$enc}||();
	if(scalar @{$self->{' chrcid'}->{$enc}} < 1) {
		foreach my $x (0..255) {
			$self->{' chrcid'}->{$enc}{$x}=
				$self->{' unicid'}{$map->{'c2u'}->{$x}}||$self->{' unicid'}{32};
			$self->{' chrwidth'}->{$enc}{$x}=
				$ttf->{'hmtx'}{'advance'}[$self->{' unicid'}{$map->{'c2u'}->{$x}}||$self->{' unicid'}{32}]*1000/$upem;
		}
	}
	return($self);
}


#==================================================================
#	PDF::API2::Page
#==================================================================
package PDF::API2::Page;

use strict;
use vars qw(@ISA);
@ISA = qw(Text::PDF::Pages);
use Text::PDF::Pages;
use Text::PDF::Utils;

use PDF::API2::Util;

use Math::Trig;

=head2 PDF::API2::Page

Subclassed from Text::PDF::Pages

=item $page = PDF::API2::Page->new $pdf, $parent, $index

Returns a page object (called from $pdf->page).

=cut

sub new {
    my ($class, $pdf, $parent, $index) = @_;
    my ($self) = {};

    $class = ref $class if ref $class;
    $self = $class->SUPER::new($pdf, $parent);
    $self->{'Type'} = PDFName('Page');
    delete $self->{'Count'};
    delete $self->{'Kids'};
    $parent->add_page($self, $index);
    $self;
}

=item $page = PDF::API2::Page->coerce $pdf, $pdfpage

Returns a page object converted from $pdfpage (called from $pdf->openpage).

=cut

sub coerce {
	my ($class, $pdf, $page) = @_;
	my ($self) = {};
	bless($self);
	foreach my $k (keys %{$page}) {
		$self->{$k}=$page->{$k};
	}
	$self->{' apipdf'}=$pdf;
	return($self);
}

=item $page->update

Marks a page to be updated (by $pdf->update).

=cut

sub update {
	my ($self) = @_;
	$self->{' apipdf'}->out_obj($self);
	$self;
}

=item $page->mediabox $w, $h

=item $page->mediabox $llx, $lly, $urx, $ury

Sets the mediabox.

=cut

sub mediabox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'MediaBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} else {
		$self->{'MediaBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	}
	$self;
}

=item $page->cropbox $w, $h

=item $page->cropbox $llx, $lly, $urx, $ury

Sets the cropbox.

=cut

sub cropbox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'CropBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} else {
		$self->{'CropBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	}
	$self;
}

=item $page->bleedbox $w, $h

=item $page->bleedbox $llx, $lly, $urx, $ury

Sets the bleedbox.

=cut

sub bleedbox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'BleedBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} else {
		$self->{'BleedBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	}
	$self;
}

=item $page->trimbox $w, $h

=item $page->trimbox $llx, $lly, $urx, $ury

Sets the trimbox.

=cut

sub trimbox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'TrimBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} else {
		$self->{'TrimBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	}
	$self;
}

=item $page->artbox $w, $h

=item $page->artbox $llx, $lly, $urx, $ury

Sets the artbox.

=cut

sub artbox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'ArtBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} else {
		$self->{'ArtBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	}
	$self;
}

=item $gfx = $page->gfx

Returns a graphics content object.

=cut

sub fixcontents {
	my ($self) = @_;
        $self->{'Contents'} = $self->{'Contents'} || PDFArray();
        if(ref($self->{'Contents'})=~/Objind/) {
	        $self->{'Contents'} = PDFArray($self->{'Contents'});
	}
}

sub gfx {
	my ($self) = @_;
        $self->fixcontents;
	my $gfx=PDF::API2::Gfx->new();
        $self->{'Contents'}->add_elements($gfx);
        $self->{' apipdf'}->new_obj($gfx);
        $gfx->{' apipdf'}=$self->{' apipdf'};
        $gfx->{' apipage'}=$self;
        return($gfx);
}

=item $txt = $page->text

Returns a text content object.

=cut

sub text {
	my ($self) = @_;
        $self->fixcontents;
	my $text=PDF::API2::Text->new();
        $self->{'Contents'}->add_elements($text);
        $self->{' apipdf'}->new_obj($text);
        $text->{' apipdf'}=$self->{' apipdf'};
        $text->{' apipage'}=$self;
        return($text);
}

=item $hyb = $page->hybrid

Returns a hybrid content object.

=cut

sub hybrid {
	my ($self) = @_;
        $self->fixcontents;
	my $hyb=PDF::API2::Hybrid->new();
        $self->{'Contents'}->add_elements($hyb);
        $self->{' apipdf'}->new_obj($hyb);
        $hyb->{' apipdf'}=$self->{' apipdf'};
        $hyb->{' apipage'}=$self;
        return($hyb);
}

=item $ant = $page->annotation

Returns a annotation object.

=cut

sub annotation {
	my ($self, $type, $key, $obj) = @_;
        $self->{'Annots'} = $self->{'Annots'} || PDFArray();
	my $ant=PDF::API2::Annotation->new;
        $self->{'Annots'}->add_elements($ant);
        $self->{' apipdf'}->new_obj($ant);
        $ant->{' apipdf'}=$self->{' apipdf'};
        $ant->{' apipage'}=$self;
        return($ant);
}

=item $page->resource $type, $key, $obj

Adds a resource to the page-inheritance tree.

B<Example:>

	$co->resource('Font',$fontkey,$fontobj);
	$co->resource('XObject',$imagekey,$imageobj);
	$co->resource('Shading',$shadekey,$shadeobj);
	$co->resource('ColorSpace',$spacekey,$speceobj);

B<Note:> You only have to add the required resources, if
they are NOT handled by the *font*, *image*, *shade* or *space*
methods.

=cut

sub resource {
	my ($self, $type, $key, $obj) = @_;
	my ($dict) = $self->find_prop('Resources');

	$dict= $dict || $self->{Resources} || $self->{' api'}->{pages}->{'Resources'} || PDFDict();	
#	$self->{' api'}->{pages}->{'Resources'}=$self->{' api'}->{pages}->{'Resources'} || $dict;	

	$dict->{$type}=$dict->{$type} || PDFDict();

	$dict->{$type}->{$key}=$dict->{$type}->{$key} || $obj;

	$self->{Resources} = $dict;	
	
	if($dict->is_obj($self->{' apipdf'})) {
		$self->{' apipdf'}->out_obj($dict);
	}
	
	return($self);
}

sub ship_out
{
    my ($self, $pdf) = @_;

    $pdf->ship_out($self);
    if (defined $self->{'Contents'})
    { $pdf->ship_out($self->{'Contents'}->elementsof); }
    $self;
}


#==================================================================
#	PDF::API2::Annotation
#==================================================================
package PDF::API2::Annotation;

use strict;
use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict);

use Text::PDF::Dict;
use Text::PDF::Utils;
use Math::Trig;
use PDF::API2::Util;

=head2 PDF::API2::Annotation

Subclassed from Text::PDF::Dict.

=item $ant = PDF::API2::Annotation->new 

Returns a annotation object (called from $page->annotation).

=cut

sub new {
	my ($class)=@_;
	my $self = $class->SUPER::new(@_);
	return($self);
}

#==================================================================
#	PDF::API2::Content
#==================================================================
package PDF::API2::Content;

use strict;
use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict);

use Text::PDF::Dict;
use Text::PDF::Utils;
use Math::Trig;
use PDF::API2::Util;

=head2 PDF::API2::Content

Subclassed from Text::PDF::Dict.

=item $co = PDF::API2::Content->new @parameters

Returns a new content object (called from $page->text/gfx).

=cut

sub new {
	my ($class)=@_;
	my $self = $class->SUPER::new(@_);
	$self->save;
	return($self);
}

=item $co->add @content

Adds @content to the object.

=cut

sub add {
	my $self=shift @_;
	$self->{' stream'}.=join(' ',@_)."\n";
}

=item $co->save

Saves the state of the object.

=cut

sub save {
	my $self=shift @_;
	$self->add('q');
}

=item $co->restore

Restores the state of the object.

=cut

sub restore {
	my $self=shift @_;
	$self->add('Q');
}

=item $co->compress

Marks content for compression on output.

=cut

sub compress {
	my $self=shift @_;
	$self->{'Filter'}=PDFArray(PDFName('FlateDecode'));
}

sub outobjdeep {
	my ($self, $fh, $pdf) = @_;
	$self->restore;
	$self->SUPER::outobjdeep($fh, $pdf);
}

=item $co->fillcolor $grey

=item $co->fillcolor $api2colorobject

=item $co->fillcolor $red, $green, $blue

=item $co->fillcolor $cyan, $magenta, $yellow, $black

=item $co->fillcolorbyname $colorname, $ascmyk

=item $co->fillcolorbyspace $colorspace, @colordef

Sets fillcolor.

=cut

sub fillcolor {
	my ($self,$c,$m,$y,$k)=@_;
	if (!defined($k)) {
		if (!defined($m)) {
			if(ref($c) eq 'PDF::API2::Color') {
				$self->add(floats($c->asCMYK),'k');
			} else {
				$self->add(float($c),'g');
			}
		} else {
			$self->add(floats($c,$m,$y),'rg');
		}
	} else {
		$self->add(floats($c,$m,$y,$k),'k');
	}
	return($self);
}

sub fillcolorbyname {
	my ($self,$name,$ascmyk)=@_;
	my @col=namecolor($name);
	@col=RGBasCMYK(@col) if($ascmyk);
	$self->fillcolor(@col);
	return($self);
}

sub fillcolorbyspace {
	my ($self,$cs,@para)=@_;
	$self->add("/$cs->{' apiname'}",'cs',floats(@para),'sc');
	$self->resource('ColorSpace',$cs->{' apiname'},$cs);
	return($self);
}

=item $co->strokecolor $grey

=item $co->strokecolor $api2colorobject

=item $co->strokecolor $red, $green, $blue

=item $co->strokecolor $cyan, $magenta, $yellow, $black

=item $co->strokecolorbyname $colorname, $ascmyk

=item $co->strokecolorbyspace $colorspace, @colordef

Sets strokecolor.

B<Note:>

	Defined color-names are:
	
	aliceblue, antiquewhite, aqua, aquamarine, azure,
	beige, bisque, black, blanchedalmond, blue, 
	blueviolet, brown, burlywood, cadetblue, chartreuse, 
	chocolate, coral, cornflowerblue, cornsilk, crimson, 
	cyan, darkblue, darkcyan, darkgoldenrod, darkgray, 
	darkgreen, darkgrey, darkkhaki, darkmagenta, 
	darkolivegreen, darkorange, darkorchid, darkred,
	darksalmon, darkseagreen, darkslateblue, darkslategray,
	darkslategrey, darkturquoise, darkviolet, deeppink, 
	deepskyblue, dimgray, dimgrey, dodgerblue, firebrick, 
	floralwhite, forestgreen, fuchsia, gainsboro, ghostwhite, 
	gold, goldenrod, gray, grey, green, greenyellow, 
	honeydew, hotpink, indianred, indigo, ivory, khaki, 
	lavender, lavenderblush, lawngreen, lemonchiffon, 
	lightblue, lightcoral, lightcyan, lightgoldenrodyellow, 
	lightgray, lightgreen, lightgrey, lightpink, lightsalmon,
	lightseagreen, lightskyblue, lightslategray, 
	lightslategrey, lightsteelblue, lightyellow, lime, 
	limegreen, linen, magenta, maroon, mediumaquamarine, 
	mediumblue, mediumorchid, mediumpurple, mediumseagreen, 
	mediumslateblue, mediumspringgreen, mediumturquoise, 
	mediumvioletred, midnightblue, mintcream, mistyrose, 
	moccasin, navajowhite, navy, oldlace, olive, olivedrab, 
	orange, orangered, orchid, palegoldenrod, palegreen, 
	paleturquoise, palevioletred, papayawhip, peachpuff, 
	peru, pink, plum, powderblue, purple, red, rosybrown, 
	royalblue, saddlebrown, salmon, sandybrown, seagreen, 
	seashell, sienna, silver, skyblue, slateblue, slategray, 
	slategrey, snow, springgreen, steelblue, tan, teal, 
	thistle, tomato, turquoise, violet, wheat, white, 
	whitesmoke, yellow, yellowgreen
	
	or the rgb-hex-notation:
	
	#rgb, #rrggbb, #rrrgggbbb and #rrrrggggbbbb

	or the cmyk-hex-notation:
	
	%cmyk, %ccmmyykk, %cccmmmyyykkk and %ccccmmmmyyyykkkk

	and additionally the hsv-hex-notation:

	!hsv, !hhssvv, !hhhsssvvv and !hhhhssssvvvv

=cut

sub strokecolor {
	my ($self,$c,$m,$y,$k)=@_;
	if (!defined($k)) {
		if (!defined($m)) {
			if(ref($c) eq 'PDF::API2::Color') {
				$self->add(floats($c->asCMYK),'K');
			} else {
				$self->add(float($c),'G');
			}
		} else {
			$self->add(floats($c,$m,$y),'RG');
		}
	} else {
		$self->add(floats($c,$m,$y,$k),'K');
	}
	return($self);
}

sub strokecolorbyname {
	my ($self,$name,$ascmyk)=@_;
	my @col=namecolor($name);
	@col=RGBasCMYK(@col) if($ascmyk);
	$self->strokecolor(@col);
	return($self);
}

sub strokecolorbyspace {
	my ($self,$cs,@para)=@_;
	$self->add("/$cs->{' apiname'}",'CS',floats(@para),'SC');
	$self->resource('ColorSpace',$cs->{' apiname'},$cs);
	return($self);
}

=item $co->flatness $flat

Sets flatness.

=cut

sub flatness {
	my ($self,$flatness)=@_;
	$self->add($flatness,'i');
}

=item $co->linecap $cap

Sets linecap.

=cut

sub linecap {
	my ($this,$linecap)=@_;
	$this->add($linecap,'J');
}

=item $co->linedash @dash

Sets linedash.

=cut

sub linedash {
	my ($self,@a)=@_;
	if(scalar @a < 1) {
		$self->add('[ 1 ] 0 d');
	} else {
		$self->add('[',floats(@a),'] 0 d');
	}
}

=item $co->linejoin $join

Sets linejoin.

=cut

sub linejoin {
	my ($this,$linejoin)=@_;
	$this->add($linejoin,'j');
}

=item $co->linewidth $width

Sets linewidth.

=cut

sub linewidth {
	my ($this,$linewidth)=@_;
	$this->add($linewidth,'w');
}

=item $co->meterlimit $limit

Sets meterlimit.

=cut

sub meterlimit {
	my ($this, $limit)=@_;
	$this->add($limit,'M');
}

=item $co->matrix $a,$b,$c,$d,$e,$f

Sets matrix transformation.

=cut

sub matrix {
	my $self=shift @_;
	my ($a,$b,$c,$d,$e,$f)=@_;
	$self->add(floats($a,$b,$c,$d,$e,$f),'cm');
}

=item $co->translate $x,$y

Sets translation transformation.

=cut

sub translate {
	my ($self,$x,$y)=@_;
	$self->matrix(1,0,0,1,$x,$y);
}

=item $co->scale $sx,$sy

Sets scaleing transformation.

=cut

sub scale {
	my ($self,$x,$y)=@_;
	$self->matrix($x,0,0,$y,0,0);
}

=item $co->skew $sa,$sb

Sets skew transformation.

=cut

sub skew {
	my ($self,$a,$b)=@_;
	$self->matrix(1, tan(deg2rad($a)),tan(deg2rad($b)),1,0,0);
}

=item $co->rotate $rot

Sets rotation transformation.

=cut

sub rotate {
	my ($self,$a)=@_;
	$self->matrix(cos(deg2rad($a)), sin(deg2rad($a)),-sin(deg2rad($a)), cos(deg2rad($a)),0,0);
}

=item $co->transform %opts

Sets transformations (eg. translate, rotate, scale, skew) in pdf-canonical order.

B<Example:>

	$co->transform(
		-translate => [$x,$y],
		-rotate    => $rot,
		-scale     => [$sx,$sy],
		-skew      => [$sa,$sb],
	)

=cut

sub transform {
	my ($self,%opt)=@_;
	my $mtx=PDF::API2::Matrix->new([1,0,0],[0,1,0],[0,0,1]);
	foreach my $o (qw( -skew -scale -rotate -translate )) {
		next unless(defined($opt{$o}));
		if($o eq '-translate') {
			my ($tx,$ty)=@{$opt{$o}};
			$mtx=$mtx->multiply(PDF::API2::Matrix->new([1,0,0],[0,1,0],[$tx,$ty,1]));
		} elsif($o eq '-rotate') {
			my $rot=$opt{$o};
			$mtx=$mtx->multiply(PDF::API2::Matrix->new(
				[ cos(deg2rad($rot)),sin(deg2rad($rot)),0],
				[-sin(deg2rad($rot)),cos(deg2rad($rot)),0],
				[0,0,1]
			));
		} elsif($o eq '-scale') {
			my ($sx,$sy)=@{$opt{$o}};
			$mtx=$mtx->multiply(PDF::API2::Matrix->new([$sx,0,0],[0,$sy,0],[0,0,1]));
		} elsif($o eq '-skew') {
			my ($sa,$sb)=@{$opt{$o}};
			$mtx=$mtx->multiply(PDF::API2::Matrix->new(
				[1,tan(deg2rad($sa)),0],
				[tan(deg2rad($sb)),1,0],
				[0,0,1]
			));
		}
	}
	$self->matrix(
		$mtx->[0][0],$mtx->[0][1],
		$mtx->[1][0],$mtx->[1][1],
		$mtx->[2][0],$mtx->[2][1]
	);
	return($self);
}

=item $co->resource $type, $key, $obj

Adds a resource to the page-inheritance tree.

B<Example:>

	$co->resource('Font',$fontkey,$fontobj);
	$co->resource('XObject',$imagekey,$imageobj);
	$co->resource('Shading',$shadekey,$shadeobj);
	$co->resource('ColorSpace',$spacekey,$speceobj);

B<Note:> You only have to add the required resources, if
they are NOT handled by the *font*, *image*, *shade* or *space*
methods.

=cut

sub resource {
	my ($self, $type, $key, $obj) = @_;
	$self->{' apipage'}->resource($type, $key, $obj);
	return($self);
}

#==================================================================
#	PDF::API2::Gfx
#==================================================================
package PDF::API2::Gfx;

use strict;
use vars qw(@ISA);
@ISA = qw(PDF::API2::Content);

use Text::PDF::Utils;
use PDF::API2::Util;
use Math::Trig;

=head2 PDF::API2::Gfx

Subclassed from PDF::API2::Content.

=item $gfx = PDF::API2::Gfx->new @parameters

Returns a new graphics content object (called from $page->gfx).

=item $gfx->matrix $a, $b, $c, $d, $e, $f

Sets the matrix.

=cut

sub matrix {
	my $self=shift @_;
	my ($a,$b,$c,$d,$e,$f)=@_;
	$self->add(floats($a,$b,$c,$d,$e,$f),'cm');
	return($self);
}

=item $gfx->move $x, $y

=cut

sub move { # x,y ...
	my $self=shift @_;
	my($x,$y);
	while(defined($x=shift @_)) {
		$y=shift @_;
		$self->{' x'}=$x;
		$self->{' y'}=$y;
		$self->{' mx'}=$x;
		$self->{' my'}=$y;
		$self->add(floats($x,$y),'m');
	}
	return($self);
}

=item $gfx->line $x, $y

=cut

sub line { # x,y ...
	my $self=shift @_;
	my($x,$y);
	while(defined($x=shift @_)) {
		$y=shift @_;
		$self->{' x'}=$x;
		$self->{' y'}=$y;
		$self->add(floats($x,$y),'l');
	}
	return($self);
}

=item $gfx->hline $x

=cut

sub hline { 
	my($self,$x)=@_;
	$self->add(floats($x,$self->{' y'}),'l');
	$self->{' x'}=$x;
	return($self);
}

=item $gfx->vline $y

=cut

sub vline { 
	my($self,$y)=@_;
	$self->add(floats($self->{' x'},$y),'l');
	$self->{' y'}=$y;
	return($self);
}

=item $gfx->curve $x1, $y1, $x2, $y2, $x3, $y3

=cut

sub curve { # x1,y1,x2,y2,x3,y3 ...
	my $self=shift @_;
	my($x1,$y1,$x2,$y2,$x3,$y3);
	while(defined($x1=shift @_)) {
		$y1=shift @_;
		$x2=shift @_;
		$y2=shift @_;
		$x3=shift @_;
		$y3=shift @_;
		$self->add(floats($x1,$y1,$x2,$y2,$x3,$y3),'c');
		$self->{' x'}=$x3;
		$self->{' y'}=$y3;
	}
	return($self);
}

sub arctocurve {
        my ($a,$b,$alpha,$beta)=@_;
        if(abs($beta-$alpha) > 180) {
        	return (
        		arctocurve($a,$b,$alpha,($beta+$alpha)/2),
        		arctocurve($a,$b,($beta+$alpha)/2,$beta)
        	);
        } else {
                $alpha = ($alpha * 3.1415 / 180);
                $beta  = ($beta * 3.1415 / 180);

                my $bcp = (4.0/3 * (1 - cos(($beta - $alpha)/2)) / sin(($beta - $alpha)/2));
                my $sin_alpha = sin($alpha);
                my $sin_beta =  sin($beta);
                my $cos_alpha = cos($alpha);
                my $cos_beta =  cos($beta);

                my $p0_x = $a * $cos_alpha;
                my $p0_y = $b * $sin_alpha;
                my $p1_x = $a * ($cos_alpha - $bcp * $sin_alpha);
                my $p1_y = $b * ($sin_alpha + $bcp * $cos_alpha);
                my $p2_x = $a * ($cos_beta + $bcp * $sin_beta);
                my $p2_y = $b * ($sin_beta - $bcp * $cos_beta);
                my $p3_x = $a * $cos_beta;
                my $p3_y = $b * $sin_beta;
                return($p0_x,$p0_y,$p1_x,$p1_y,$p2_x,$p2_y,$p3_x,$p3_y);
	}
}

=item $gfx->arc $x, $y, $a, $b, $alfa, $beta, $move

=cut

sub arc { # x,y,a,b,alf,bet[,mov]
        my ($self,$x,$y,$a,$b,$alpha,$beta,$move)=@_;
        my @points=arctocurve($a,$b,$alpha,$beta);
        my ($p0_x,$p0_y,$p1_x,$p1_y,$p2_x,$p2_y,$p3_x,$p3_y);

        $p0_x= $x + shift @points;
        $p0_y= $y + shift @points;

        $self->move($p0_x,$p0_y) if($move);

	while(scalar @points > 0) {
	        $p1_x= $x + shift @points;
	        $p1_y= $y + shift @points;
	        $p2_x= $x + shift @points;
	        $p2_y= $y + shift @points;
	        $p3_x= $x + shift @points;
	        $p3_y= $y + shift @points;
	        $self->curve($p1_x,$p1_y,$p2_x,$p2_y,$p3_x,$p3_y);
	        shift @points;
	        shift @points;
		$self->{' x'}=$p3_x;
		$self->{' y'}=$p3_y;
	}
	return($self);
}

=item $gfx->ellipse $x, $y, $a, $b

=cut

sub ellipse {
	my ($self,$x,$y,$a,$b) = @_;
	$self->arc($x,$y,$a,$b,0,360,1);
	$self->close;
	return($self);
}

=item $gfx->circle $x, $y, $r

=cut

sub circle {
	my ($self,$x,$y,$r) = @_;
	$self->arc($x,$y,$r,$r,0,360,1);
	$self->close;
	return($self);
}

=item $gfx->bogen $x1, $y1, $x2, $y2, $r, $move, $larc, $span

=cut

sub bogen { # x1,y1,x2,y2,r[,move[,large-arc[,span-factor]]]
	my ($self,$x1,$y1,$x2,$y2,$r,$move,$larc,$spf) = @_;
        my ($p0_x,$p0_y,$p1_x,$p1_y,$p2_x,$p2_y,$p3_x,$p3_y);
	my $x=$x2-$x1;
	$x=$x1-$x2 if($spf>0);
	my $y=$y2-$y1;
	$y=$y1-$y2 if($spf>0);
	my $z=sqrt($x**2+$y**2);
	my $alfa_rad=asin($y/$z);

	if($spf>0) {
		$alfa_rad-=pi/2 if($x<0);
		$alfa_rad=-$alfa_rad if($y>0);
	} else {
		$alfa_rad+=pi/2 if($x<0);
		$alfa_rad=-$alfa_rad if($y<0);
	}

	my $alfa=rad2deg($alfa_rad);
	my $d=2*$r;
	my ($beta,$beta_rad,@points);

	$beta=rad2deg(2*asin($z/$d));
	$beta=360-$beta if($larc>0);

	$beta_rad=deg2rad($beta);

	@points=arctocurve($r,$r,90+$alfa+$beta/2,90+$alfa-$beta/2);

	if($spf>0) {
		my @pts=@points;
		@points=();
		while($y=pop @pts){
			$x=pop @pts;
			push(@points,$x,$y);
		}
	}

	$p0_x=shift @points;
	$p0_y=shift @points;
	$x=$x1-$p0_x;
	$y=$y1-$p0_y;

        $self->move($x,$y) if($move);

	while(scalar @points > 0) {
	        $p1_x= $x + shift @points;
	        $p1_y= $y + shift @points;
	        $p2_x= $x + shift @points;
	        $p2_y= $y + shift @points;
	        $p3_x= $x + shift @points;
	        $p3_y= $y + shift @points;
	        $self->curve($p1_x,$p1_y,$p2_x,$p2_y,$p3_x,$p3_y);
	        shift @points;
	        shift @points;
	}
	return($self);
}

=item $gfx->pie $x, $y, $a, $b, $alfa, $beta

=cut

sub pie {
	my $self=shift @_;
	my ($x,$y,$a,$b,$alfa,$beta)=@_;
        my ($p0_x,$p0_y)=arctocurve($a,$b,$alfa,$beta);
	$self->move($x,$y);
	$self->line($p0_x+$x,$p0_y+$y);
	$self->arc($x,$y,$a,$b,$alfa,$beta);
	$self->close;
}

=item $gfx->pie3d $x, $y, $a, $b, $alfa, $beta, $thickness [, $sides]

=cut

sub pie3d {
	my $self=shift @_;
	my ($x,$y,$a,$b,$alfa,$beta,$th,$sd)=@_;
	
	my ($sa,$sb);
	
	while($alfa<0) {$alfa+=360;$beta+=360;}

	while($alfa>360) {$alfa-=360;$beta-=360;}

	$sa=$alfa;

	$sb=$beta;
	while($sb<0) {$sb+=360;}
	while($sb>360) {$sb-=360;}

	my ($p0x,$p0y)=arctocurve($a,$b,$alfa,$beta);
	my ($p1x,$p1y)=arctocurve($a,$b,$beta,$alfa);
	if($sd) {
		if (($sa<90) || ($sa>270)) {
			$self->move($x,$y);
			$self->line($x,$y-$th);
			$self->line($x+$p0x,$y+$p0y-$th);
			$self->line($x+$p0x,$y+$p0y);
			$self->close;
		} 
		if (($sb>90) && ($sb<270)) {
			$self->move($x,$y);
			$self->line($x,$y-$th);
			$self->line($x+$p1x,$y+$p1y-$th);
			$self->line($x+$p1x,$y+$p1y);
			$self->close;
		} 
	}	

	my($r_s,$r_m,$r_e);

	my $mid=($beta+$alfa)/2;

	if( ($alfa<180) && ($beta>180) && ($beta<360) ) {
		$r_s=180;
		$r_e=$beta;
	} elsif(($alfa>180) && ($beta<360)) {
		$r_s=$alfa;
		$r_e=$beta;
	} elsif( ($alfa<360) && ($alfa>180) && ($beta>360) ) {
		$r_s=$alfa;
		$r_e=360;
	} elsif ( ($alfa<180) && ($beta>360) ) {
		$r_s=180;
		$r_e=360;
	}

	if($r_s||$r_e||$r_m) {
		($p0x,$p0y)=arctocurve($a,$b,$r_s,$r_e);
		($p1x,$p1y)=arctocurve($a,$b,$r_e,$r_s);
		$self->move($x+$p0x,$y+$p0y);
		$self->line($x+$p0x,$y+$p0y-$th);
		$self->arc($x,$y-$th,$a,$b,$r_s,$r_e);
		$self->line($x+$p1x,$y+$p1y);
		$self->close;
		if(($sb>180) && ($sb<360) && (($beta-$alfa)>180) && ($sa>$sb)) {
			($p0x,$p0y)=arctocurve($a,$b,180,$beta);
			($p1x,$p1y)=arctocurve($a,$b,$beta,180);
			$self->move($x+$p1x,$y+$p1y);
			$self->line($x+$p1x,$y+$p1y-$th);
			$self->arc($x,$y-$th,$a,$b,$sb,180);
			$self->line($x+$p0x,$y+$p0y);
			$self->close;
		#	print " sa=$sa sb=$sb a=$alfa b=$beta \n";
		}
	}

	$self->fillstroke;

	$self->pie($x,$y,$a,$b,$alfa,$beta);

	return($self);
}

=item $gfx->rect $x1,$y1, $w1,$h1, ..., $xn,$yn, $wn,$hn

=cut

sub rect { # x,y,w,h ...
	my $self=shift @_;
	my($x,$y,$w,$h);
	while(defined($x=shift @_)) {
		$y=shift @_;
		$w=shift @_;
		$h=shift @_;
		$self->add(floats($x,$y,$w,$h),'re');
	}
	$self->{' x'}=$x;
	$self->{' y'}=$y;
	return($self);
}

=item $gfx->rectxy $x1,$y1, $x2,$y2

=cut

sub rectxy {
	my ($self,$x,$y,$x2,$y2)=@_;
	$self->rect($x,$y,($x2-$x),($y2-$y));
	return($self);
}

=item $gfx->poly $x1,$y1, ..., $xn,$yn

=cut

sub poly {
	my $self=shift @_;
	my($x,$y);
	$x=shift @_;
	$y=shift @_;
	$self->move($x,$y);
	$self->line(@_);
	return($self);
}

=item $gfx->close

=cut

sub close {
	my $self=shift @_;
	$self->add('h');
	$self->{' x'}=$self->{' mx'};
	$self->{' y'}=$self->{' my'};
	return($self);
}

=item $gfx->endpath

=cut

sub endpath {
	my $self=shift @_;
	$self->add('n');
	return($self);
}

=item $gfx->clip $nonzero

=cut

sub clip { # nonzero
	my $self=shift @_;
	$self->add(!(shift @_)?'W':'W*');
	return($self);
}

=item $gfx->stroke

=cut

sub stroke {
	my $self=shift @_;
	$self->add('S');
	return($self);
}

=item $gfx->fill $nonzero

=cut

sub fill { # nonzero
	my $self=shift @_;
	$self->add(!(shift @_)?'f':'f*');
	return($self);
}

=item $gfx->fillstroke $nonzero

=cut

sub fillstroke { # nonzero
	my $self=shift @_;
	$self->add(!(shift @_)?'B':'B*');
	return($self);
}

=item $gfx->image $imgobj, $x,$y, $w,$h

=cut

sub image {
	my $self=shift @_;
	my $img=shift @_;
	my ($x,$y,$w,$h)=@_;
	$self->save;
	$self->matrix($w,0,0,$h,$x,$y);
	$self->add("/$img->{' apiname'}",'Do');
	$self->restore;
	$self->{' x'}=$x;
	$self->{' y'}=$y;
	$self->resource('XObject',$img->{' apiname'},$img);
	return($self);
}

=item $gfx->shade $shadeobj, $x1,$y1, $x2,$y2

=cut

sub shade {
	my $self=shift @_;
	my $shade=shift @_;
	my @cord=@_;
	my @tm=(
		$cord[2]-$cord[0] , 0,
		0                 , $cord[3]-$cord[1],
		$cord[0]          , $cord[1]
	);
	$self->save;
	$self->matrix(@tm);
	$self->add("/$shade->{' apiname'}",'sh');

	$self->resource('Shading',$shade->{' apiname'},$shade);

	$self->restore;
	return($self);
}

=item $gfx->egstate $egsobj

=cut

sub egstate {
	my $self=shift @_;
	my $egs=shift @_;
	$self->add("/$egs->{' apiname'}",'gs');
	$self->resource('ExtGState',$egs->{' apiname'},$egs);
	return($self);
}


#==================================================================
#	PDF::API2::Text
#==================================================================
package PDF::API2::Text;

use strict;
use vars qw(@ISA);
@ISA = qw(PDF::API2::Content);

use Text::PDF::Utils;
use PDF::API2::Util;
use Math::Trig;

=head2 PDF::API2::Text

Subclassed from PDF::API2::Content.

=item $txt = PDF::API2::Text->new @parameters

Returns a new text content object (called from $page->text).

=cut

sub new {
	my ($class)=@_;
	my $self = $class->SUPER::new(@_);
	$self->add('BT');
	return($self);
}

=item $txt->matrix $a, $b, $c, $d, $e, $f

Sets the matrix.

=cut

sub matrix {
	my $self=shift @_;
	my ($a,$b,$c,$d,$e,$f)=@_;
	$self->add((floats($a,$b,$c,$d,$e,$f)),'Tm');
	return($self);
}

sub outobjdeep {
	my ($self, $fh, $pdf) = @_;
	$self->add('ET');
	$self->SUPER::outobjdeep($fh, $pdf);
}

=item $txt->font $fontobj,$size

=cut

sub font {
	my ($self,$font,$size)=@_;
	$self->{' font'}=$font;
	$self->{' fontsize'}=$size;
	$self->add("/".$font->{' apiname'},float($size),'Tf');

	$self->resource('Font',$font->{' apiname'},$font);

	return($self);
}

=item $txt->charspace $spacing

=cut

sub charspace {
	my ($self,$para)=@_;
	$self->add(float($para),'Tc');
}

=item $txt->wordspace $spacing

=cut

sub wordspace {
	my ($self,$para)=@_;
	$self->add(float($para),'Tw');
}

=item $txt->hspace $spacing

=cut

sub hspace {
	my ($self,$para)=@_;
	$self->add(float($para),'Tz');
}

=item $txt->lead $leading

=cut

sub lead {
	my ($self,$para)=@_;
	$self->add(float($para),'TL');
}

=item $txt->rise $rise

=cut

sub rise {
	my ($self,$para)=@_;
	$self->add(float($para),'Ts');
}

=item $txt->render $rendering

=cut

sub render {
	my ($self,$para)=@_;
	$self->add(intg($para),'Tr');
}

=item $txt->cr $linesize

=cut

sub cr {
	my ($self,$para)=@_;
	if(defined($para)) {
		$self->add(0,float($para),'Td');
	} else {
		$self->add('T*');
	}
}

=item $txt->nl

=cut

sub nl {
	my ($self)=@_;
	$self->add('T*');
}

=item $txt->distance $dx,$dy

=cut

sub distance {
	my ($self,$dx,$dy)=@_;
	$self->add(float($dx),float($dy),'Td');
}

=item $txt->text $string

=cut

sub text {
	my ($self,@txt)=@_;
	my ($text);
	while(scalar @txt > 0) {
		$text=shift @txt;
		$self->add($self->{' font'}->text($text),'Tj');
	}
}

=item $txt->text_center $string

=cut

sub text_center {
	my ($self,$text)=@_;
	$self->distance(float(-($self->{' font'}->width($text)*$self->{' fontsize'}/2)),0);
	$self->add($self->{' font'}->text($text),'Tj');
	$self->distance(float($self->{' font'}->width($text)*$self->{' fontsize'}/2),0);
}

=item $txt->text_right $string

=cut

sub text_right {
	my ($self,$text)=@_;
	$self->distance(float(-($self->{' font'}->width($text)*$self->{' fontsize'})),0);
	$self->add($self->{' font'}->text($text),'Tj');
	$self->distance(float($self->{' font'}->width($text)*$self->{' fontsize'}),0);
}

=item $txt->text_utf8 $utf8string

=cut

sub text_utf8 {
	my ($self,@txt)=@_;
	my ($text);
	while(scalar @txt > 0) {
		$text=shift @txt;
		$self->add($self->{' font'}->text_utf8($text),'Tj');
	}
}

=item $txt->textln $string1, ..., $stringn

B<Example:>

	$txt->lead(-10);
	$txt->textln($line1,$line2,$line3);

=cut

sub textln {
	my ($self,@txt)=@_;
	my ($text);
	while(scalar @txt > 0) {
		$text=shift @txt;
		$self->add($self->{' font'}->text($text),'Tj','T*');
	}
}


#==================================================================
#	PDF::API2::Hybrid
#==================================================================
package PDF::API2::Hybrid;

use strict;
use vars qw(@ISA);
@ISA = qw(PDF::API2::Gfx PDF::API2::Text PDF::API2::Content);

use Text::PDF::Utils;
use PDF::API2::Util;

=head2 PDF::API2::Hybrid

Subclassed from PDF::API2::Gfx+Text+Content.

=item $hyb = PDF::API2::Hybrid->new @parameters

Returns a new hybrid content object (called from $page->hybrid).

=cut

sub new {
	my ($class)=@_;
	my $self = PDF::API2::Content::new(@_);
	return($self);
}

=item $hyb->matrix $a, $b, $c, $d, $e, $f

Sets the matrix.

=cut

sub matrix {
	my $self=shift @_;
	my ($a,$b,$c,$d,$e,$f)=@_;
	if($self->{' apiistext'} == 1) {
		$self->add(floats($a,$b,$c,$d,$e,$f),'tm');
	} else {
		$self->add(floats($a,$b,$c,$d,$e,$f),'cm');
	}
	return($self);
}

sub outobjdeep {
	my ($self) = @_;
	PDF::API2::Content::outobjdeep(@_);
}

sub transform {
	my ($self)=@_;
	if($self->{' apiistext'} == 1) {
		PDF::API2::Text::transform(@_);
	} else {
		PDF::API2::Gfx::transform(@_);
	}
	return($self);
}

=item $hyb->textstart

=cut

sub textstart {
	my ($self)=@_;
	if($self->{' apiistext'} != 1) {
		$self->add('BT');
		$self->{' apiistext'}=1;
	}
	return($self);
}

=item $hyb->textend

=cut

sub textend {
	my ($self)=@_;
	if($self->{' apiistext'} == 1) {
		$self->add('ET');
		$self->{' apiistext'}=0;
	}
	return($self);
}


#==================================================================
#	PDF::API2::Image
#==================================================================
package PDF::API2::Image;
use strict;
use PDF::API2::Util;
use Text::PDF::Utils;

=head2 PDF::API2::Image

=item $img = PDF::API2::Image->new $pdf, $imgfile

Returns a new image object (called from $pdf->image).

=cut

sub new {
	my ($class,$pdf,$file)=@_;
	my ($obj,$buf);
	open(INF,$file);
	read(INF,$buf,10,0);
	close(INF);
#	if($buf=~/^GIF8[7,9]a/) {
#		$obj=PDF::API2::GIF->new($file);
#	} elsif ($buf=~/^\xFF\xD8/) {
	if ($buf=~/^\xFF\xD8/) {
		$obj=PDF::API2::JPEG->new($file);
	} elsif ($buf=~/^\x89PNG/) {
		$obj=PDF::API2::PNG->new($file);
	} elsif ($buf=~/^P[456][\s\n]/) {
		$obj=PDF::API2::PPM->new($file);
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


#==================================================================
#	PDF::API2::PPM
#==================================================================
package PDF::API2::PPM;
use strict;
use PDF::API2::Util;
use Text::PDF::Utils;

use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict PDF::API2::Image);

sub new {
	my ($class,$file)=@_;
	my $self = $class->SUPER::new();
	$self->{' apiname'}='IMGxPPMx'.pdfkey($file);

	my ($w,$h,$bpc,$cs,$img)=parsePNM($file);

	$self->{'Type'}=PDFName('XObject');
	$self->{'Subtype'}=PDFName('Image');
	$self->{'Name'}=PDFName($self->{' apiname'});
	$self->{'Width'}=PDFNum(intg($w));
	$self->{'Height'}=PDFNum(intg($h));
	$self->{'Filter'}=PDFArray(PDFName('FlateDecode'));
	$self->{'BitsPerComponent'}=PDFNum(intg($bpc));
	$self->{'ColorSpace'}=PDFName($cs);
	$self->{' stream'}=$img;
	$self->{' height'}=$h;
	$self->{' width'}=$w;

	return($self);
}

sub parsePNM {
	my $file=shift @_;
	my $buf=shift @_;
	my ($t,$s,$line);
	my ($w,$h,$bpc,$cs,$img,@img)=(0,0,'','','');
	open(INF,$file);
	binmode(INF);
	$buf=<INF>;
	$buf.=<INF>;
	($t)=($buf=~/^(P\d+)\s+/);
	if($t eq 'P4') {
		($t,$w,$h)=($buf=~/^(P\d+)\s+(\d+)\s+(\d+)\s+/);
		$bpc=1;
		$s=0;
		for($line=($w*$h/8);$line>0;$line--) {
			read(INF,$buf,1);
			push(@img,$buf);
		}
		$cs='DeviceGray';
	} elsif($t eq 'P5') {
		$buf.=<INF>;
		($t,$w,$h,$bpc)=($buf=~/^(P\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+/);
		if($bpc==255){
			$s=0;
		} else {
			$s=255/$bpc;
		}
		$bpc=8;
		for($line=($w*$h);$line>0;$line--) {
			read(INF,$buf,1);
			if($s>0) {
				$buf=pack('C',(unpack('C',$buf)*$s));
			}
			push(@img,$buf);
		}
		$cs='DeviceGray';
	} elsif($t eq 'P6') {
		$buf.=<INF>;
		($t,$w,$h,$bpc)=($buf=~/^(P\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+/);
		if($bpc==255){
			$s=0;
		} else {
			$s=255/$bpc;
		}
		$bpc=8;
		if($s>0) {
			for($line=($w*$h);$line>0;$line--) {
				read(INF,$buf,1);
				push(@img,pack('C',(unpack('C',$buf)*$s)));
				read(INF,$buf,1);
				push(@img,pack('C',(unpack('C',$buf)*$s)));
				read(INF,$buf,1);
				push(@img,pack('C',(unpack('C',$buf)*$s)));
			}
		} else {
			@img=<INF>;
		}
		$cs='DeviceRGB';
	}
	close(INF);
	return ($w,$h,$bpc,$cs,join('',@img));
}


#==================================================================
#	PDF::API2::JPEG
#==================================================================
package PDF::API2::JPEG;
use strict;
use PDF::API2::Util;
use Text::PDF::Utils;

use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict PDF::API2::Image);

sub new {
	my ($class,$file)=@_;
	my $self = $class->SUPER::new();
	$self->{' apiname'}='IMGxJPEGx'.pdfkey($file);

	my ($buf, $p, $h, $w, $c);

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

	$self->{'Type'}=PDFName('XObject');
	$self->{'Subtype'}=PDFName('Image');
	$self->{'Name'}=PDFName($self->{' apiname'});
	$self->{'Width'}=PDFNum(intg($w));
	$self->{'Height'}=PDFNum(intg($h));
	$self->{'Filter'}=PDFArray(PDFName('DCTDecode'));
	$self->{' nofilt'}=1;
	$self->{'BitsPerComponent'}=PDFNum($p);
	if($c==3) {
	        $self->{'ColorSpace'}=PDFName('DeviceRGB');
	} elsif($c==4) {
	        $self->{'ColorSpace'}=PDFName('DeviceCMYK');
	} elsif($c==1) {
	        $self->{'ColorSpace'}=PDFName('DeviceGray');
	}

	$self->{' streamfile'}=$file;

	$self->{' height'}=$h;
	$self->{' width'}=$w;

	return($self);
}


#==================================================================
#	PDF::API2::PNG
#==================================================================
package PDF::API2::PNG;
use strict;
use PDF::API2::Util;
use Text::PDF::Utils;

use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict PDF::API2::Image);

sub new {
	my ($class,$file)=@_;
	my $self = $class->SUPER::new();
	$self->{' apiname'}='IMGxPNGx'.pdfkey($file);

	my ($w,$h,$bpc,$cs,$img)=parsePNG($file);

	$self->{'Type'}=PDFName('XObject');
	$self->{'Subtype'}=PDFName('Image');
	$self->{'Name'}=PDFName($self->{' apiname'});
	$self->{'Width'}=PDFNum(intg($w));
	$self->{'Height'}=PDFNum(intg($h));
	$self->{'Filter'}=PDFArray(PDFName('FlateDecode'));
	$self->{'BitsPerComponent'}=PDFNum(intg($bpc));
	$self->{'ColorSpace'}=PDFName($cs);
	$self->{' stream'}=$img;
	$self->{' height'}=$h;
	$self->{' width'}=$w;

	return($self);
}

sub parsePNG {
	my $file=shift @_;
	my $buf=shift @_;
	my ($l,$crc,$w,$h,$bpc,$cs,$cm,$fm,$im,@pal,$img,@img,$filter);
	open(INF,$file);
	binmode(INF);
	seek(INF,8,0);
	while(!eof(INF)) {
		read(INF,$buf,4);
		$l=unpack('N',$buf);
		read(INF,$buf,4);
		if($buf eq 'IHDR') {
			read(INF,$buf,$l);
			($w,$h,$bpc,$cs,$cm,$fm,$im)=unpack('NNCCCCC',$buf);
			if($im>0) {die "PNG InterlaceMethod=$im not supported";}
		} elsif($buf eq 'PLTE') {
			while($l) {
				read(INF,$buf,3);
				push(@pal,$buf);
				$l-=3;
			}
		} elsif($buf eq 'IDAT') {
			while($l>512) {
				read(INF,$buf,512);
				push(@img,$buf);
				$l-=512;
			}
			read(INF,$buf,$l);
			push(@img,$buf);
		} elsif($buf eq '') {
		} elsif($buf eq 'IEND') {
			last;
		} else {
			# skip ahead
			seek(INF,$l,1);
		}
		read(INF,$buf,4);
		$crc=$buf;
	}
	close(INF);
	$img=join('',@img);
	use Compress::Zlib;
	$img=uncompress($img);
	@img=split(//,$img);
	$img='';
	my $bpcm=($bpc>8) ? 8 : $bpc/8;
	foreach my $y (1..$h) {
		$filter=unpack('C',shift(@img));
		if($filter>0){
			##die "PNG FilterType=$filter unsupported";
		}
		foreach my $x (1..POSIX::ceil($w*$bpcm)) {
			if($cs==0) { # grayscale
				if($bpc==1) {
					$buf=shift(@img);
					$buf=unpack('C',$buf);
					foreach my $bit (7,6,5,4,3,2,1,0) {
						$img.=pack('C',(($buf >> $bit) & 1)*255);
					}
				} elsif($bpc==2) {
					$buf=shift(@img);
					$buf=unpack('C',$buf);
					foreach my $bit (6,4,2,0) {
						$img.=pack('C',((($buf >> $bit) & 3)+1)*64-1);
					}
				} elsif($bpc==4) {
					$buf=shift(@img);
					$buf=unpack('C',$buf);
					foreach my $bit (4,0) {
						$img.=pack('C',((($buf >> $bit) & 15)+1)*16-1);
					}
				} elsif($bpc==8) {
					$img.=shift(@img);
				} elsif($bpc==16) {
					$buf=shift(@img).shift(@img);
					$buf=unpack('n',$buf);
					$buf=(($buf+1)/256)-1;
					$img.=pack('C',$buf);
				}
			} elsif($cs==2) { # RGB
				if($bpc==8) {
					$img.=shift(@img).shift(@img).shift(@img);
				} elsif($bpc==16) {
					foreach(1..3) {
						$buf=shift(@img).shift(@img);
						$buf=unpack('n',$buf);
						$buf=(($buf+1)/256)-1;
						$img.=pack('C',$buf);
					}
				}
			} elsif($cs==3) { # indexed
				if($bpc==1) {
					$buf=shift(@img);
					$buf=unpack('C',$buf);
					foreach my $bit (7,6,5,4,3,2,1,0) {
						$img.=$pal[(($buf >> $bit) & 1)];
					}
				} elsif($bpc==2) {
					$buf=shift(@img);
					$buf=unpack('C',$buf);
					foreach my $bit (6,4,2,0) {
						$img.=$pal[(($buf >> $bit) & 3)];
					}
				} elsif($bpc==4) {
					$buf=shift(@img);
					$buf=unpack('C',$buf);
					foreach my $bit (4,0) {
						$img.=$pal[(($buf >> $bit) & 15)];
					}
				} elsif($bpc==8) {
					$img.=$pal[unpack('C',shift(@img))];
				}
			} elsif($cs==4) { # gray + alpha
				if($bpc==8) {
					$img.=shift(@img);
					shift(@img);
				} elsif($bpc==16) {
					$buf=shift(@img).shift(@img);
					$buf=unpack('n',$buf);
					$buf=(($buf+1)/256)-1;
					$img.=pack('C',$buf);
					shift(@img);
					shift(@img);
				}
			} elsif($cs==6) { # RGB + alpha
				if($bpc==8) {
					$img.=shift(@img).shift(@img).shift(@img);
					shift(@img);
				} elsif($bpc==16) {
					foreach(1..3) {
						$buf=shift(@img).shift(@img);
						$buf=unpack('n',$buf);
						$buf=(($buf+1)/256)-1;
						$img.=pack('C',$buf);
					}
					shift(@img);
					shift(@img);
				}
			}
		}
	}
	if( ($cs==0) || ($cs==4) ) { 
		$cs='DeviceGray';
	} elsif ( ($cs==2) || ($cs==3) || ($cs==6) ) {
		$cs='DeviceRGB';
	} else {
		$cs='';
	}
	$bpc=8; # all images have been converted to 8bit values !!
	return ($w,$h,$bpc,$cs,$img);
}


#==================================================================
#
# Copyright 1998-2000 Gisle Aas.
#
# This library is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# modified by Alfred Reibenschuh <areibens@cpan.org> for PDF::API2
#
#==================================================================
package PDF::API2::IOString;

require 5.005_03;
use strict;
use vars qw($VERSION $DEBUG $IO_CONSTANTS);
$VERSION = "1.02";

use Symbol ();

sub new
{
    my $class = shift;
    my $self = bless Symbol::gensym(), ref($class) || $class;
    tie *$self, $self;
    $self->open(@_);
    $self;
}

sub open
{
    my $self = shift;
    return $self->new(@_) unless ref($self);

    if (@_) {
	my $bufref = ref($_[0]) ? $_[0] : \$_[0];
	$$bufref = "" unless defined $$bufref;
	*$self->{buf} = $bufref;
    } else {
	my $buf = "";
	*$self->{buf} = \$buf;
    }
    *$self->{pos} = 0;
    *$self->{lno} = 0;
    $self;
}

sub pad
{
    my $self = shift;
    my $old = *$self->{pad};
    *$self->{pad} = substr($_[0], 0, 1) if @_;
    return "\0" unless defined($old) && length($old);
    $old;
}

sub dump
{
    require Data::Dumper;
    my $self = shift;
    print Data::Dumper->Dump([$self], ['*self']);
    print Data::Dumper->Dump([*$self{HASH}], ['$self{HASH}']);
}

sub TIEHANDLE
{
    print "TIEHANDLE @_\n" if $DEBUG;
    return $_[0] if ref($_[0]);
    my $class = shift;
    my $self = bless Symbol::gensym(), $class;
    $self->open(@_);
    $self;
}

sub DESTROY
{
    print "DESTROY @_\n" if $DEBUG;
}

sub close {
    my $self = shift;
    $self;
}

sub realclose
{
    my $self = shift;
    delete *$self->{buf};
    delete *$self->{pos};
    delete *$self->{lno};
    $self;
}

sub opened
{
    my $self = shift;
    defined *$self->{buf};
}

sub getc
{
    my $self = shift;
    my $buf;
    return $buf if $self->read($buf, 1);
    return undef;
}

sub ungetc
{
    my $self = shift;
    $self->setpos($self->getpos() - 1)
}

sub eof
{
    my $self = shift;
    length(${*$self->{buf}}) <= *$self->{pos};
}

sub print
{
    my $self = shift;
    if (defined $\) {
	if (defined $,) {
	    $self->write(join($,, @_).$\);
	} else {
	    $self->write(join("",@_).$\);
	}
    } else {
	if (defined $,) {
	    $self->write(join($,, @_));
	} else {
	    $self->write(join("",@_));
	}
    }
}
*printflush = \*print;

sub printf
{
    my $self = shift;
    print "PRINTF(@_)\n" if $DEBUG;
    my $fmt = shift;
    $self->write(sprintf($fmt, @_));
}


my($SEEK_SET, $SEEK_CUR, $SEEK_END);

sub _init_seek_constants
{
    if ($IO_CONSTANTS) {
	require IO::Handle;
	$SEEK_SET = &IO::Handle::SEEK_SET;
	$SEEK_CUR = &IO::Handle::SEEK_CUR;
	$SEEK_END = &IO::Handle::SEEK_END;
    } else {
	$SEEK_SET = 0;
	$SEEK_CUR = 1;
	$SEEK_END = 2;
    }
}


sub seek
{
    my($self,$off,$whence) = @_;
    my $buf = *$self->{buf} || return;
    my $len = length($$buf);
    my $pos = *$self->{pos};

    _init_seek_constants() unless defined $SEEK_SET;

    if    ($whence == $SEEK_SET) { $pos = $off }
    elsif ($whence == $SEEK_CUR) { $pos += $off }
    elsif ($whence == $SEEK_END) { $pos = $len + $off }
    else { die "Bad whence ($whence)" }
    print "SEEK(POS=$pos,OFF=$off,LEN=$len)\n" if $DEBUG;

    $pos = 0 if $pos < 0;
    $self->truncate($pos) if $pos > $len;  # extend file
    *$self->{lno} = 0;
    *$self->{pos} = $pos;
}

sub pos
{
    my $self = shift;
    my $old = *$self->{pos};
    if (@_) {
	my $pos = shift || 0;
	my $buf = *$self->{buf};
	my $len = $buf ? length($$buf) : 0;
	$pos = $len if $pos > $len;
	*$self->{lno} = 0;
	*$self->{pos} = $pos;
    }
    $old;
}

sub getpos { shift->pos; }

*sysseek = \&seek;
*setpos  = \&pos;
*tell    = \&getpos;



sub getline
{
    my $self = shift;
    my $buf  = *$self->{buf} || return;
    my $len  = length($$buf);
    my $pos  = *$self->{pos};
    return if $pos >= $len;

    unless (defined $/) {  # slurp
	*$self->{pos} = $len;
	return substr($$buf, $pos);
    }

    unless (length $/) {  # paragraph mode
	# XXX slow&lazy implementation using getc()
	my $para = "";
	my $eol = 0;
	my $c;
	while (defined($c = $self->getc)) {
	    if ($c eq "\n") {
		$eol++;
	    } elsif ($eol > 1) {
		$self->ungetc($c);
		last;
	    }
	    $para .= $c;
	}
	return $para;   # XXX wantarray
    }

    my $idx = index($$buf,$/,$pos);
    if ($idx < 0) {
	# return rest of it
	*$self->{pos} = $len;
	$. = ++ *$self->{lno};
	return substr($$buf, $pos);
    }
    $len = $idx - $pos + length($/);
    *$self->{pos} += $len;
    $. = ++ *$self->{lno};
    return substr($$buf, $pos, $len);
}

sub getlines
{
    die "getlines() called in scalar context\n" unless wantarray;
    my $self = shift;
    my($line, @lines);
    push(@lines, $line) while defined($line = $self->getline);
    return @lines;
}

sub READLINE
{
    goto &getlines if wantarray;
    goto &getline;
}

sub input_line_number
{
    my $self = shift;
    my $old = *$self->{lno};
    *$self->{lno} = shift if @_;
    $old;
}

sub truncate
{
    my $self = shift;
    my $len = shift || 0;
    my $buf = *$self->{buf};
    if (length($$buf) >= $len) {
	substr($$buf, $len) = '';
	*$self->{pos} = $len if $len < *$self->{pos};
    } else {
	$$buf .= ($self->pad x ($len - length($$buf)));
    }
    $self;
}

sub read
{
    my $self = shift;
    my $buf = *$self->{buf};
    return unless $buf;

    my $pos = *$self->{pos};
    my $rem = length($$buf) - $pos;
    my $len = $_[1];
    $len = $rem if $len > $rem;
    if (@_ > 2) { # read offset
	substr($_[0],$_[2]) = substr($$buf, $pos, $len);
    } else {
	$_[0] = substr($$buf, $pos, $len);
    }
    *$self->{pos} += $len;
    return $len;
}

sub write
{
    my $self = shift;
    my $buf = *$self->{buf};
    return unless $buf;

    my $pos = *$self->{pos};
    my $slen = length($_[0]);
    my $len = $slen;
    my $off = 0;
    if (@_ > 1) {
	$len = $_[1] if $_[1] < $len;
	if (@_ > 2) {
	    $off = $_[2] || 0;
	    die "Offset outside string" if $off > $slen;
	    if ($off < 0) {
		$off += $slen;
		die "Offset outside string" if $off < 0;
	    }
	    my $rem = $slen - $off;
	    $len = $rem if $rem < $len;
	}
    }
    substr($$buf, $pos, $len) = substr($_[0], $off, $len);
    *$self->{pos} += $len;
    $len;
}

*sysread = \&read;
*syswrite = \&write;

sub stat
{
    my $self = shift;
    return unless $self->opened;
    return 1 unless wantarray;
    my $len = length ${*$self->{buf}};

    return (
     undef, undef,  # dev, ino
     0666,          # filemode
     1,             # links
     $>,            # user id
     $),            # group id
     undef,         # device id
     $len,          # size
     undef,         # atime
     undef,         # mtime
     undef,         # ctime
     512,           # blksize
     int(($len+511)/512)  # blocks
    );
}

sub blocking {
    my $self = shift;
    my $old = *$self->{blocking} || 0;
    *$self->{blocking} = shift if @_;
    $old;
}

my $notmuch = sub { return };

*fileno    = $notmuch;
*error     = $notmuch;
*clearerr  = $notmuch;
*sync      = $notmuch;
*flush     = $notmuch;
*setbuf    = $notmuch;
*setvbuf   = $notmuch;

*untaint   = $notmuch;
*autoflush = $notmuch;
*fcntl     = $notmuch;
*ioctl     = $notmuch;

*GETC   = \&getc;
*PRINT  = \&print;
*PRINTF = \&printf;
*READ   = \&read;
*WRITE  = \&write;
*CLOSE  = \&close;
*SEEK   = \&seek;

sub string_ref
{
    my $self = shift;
    *$self->{buf};
}
*sref = \&string_ref;


# Matrix.pm -- 
# Author          : Ulrich Pfeifer
# Created On      : Tue Oct 24 18:34:08 1995
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Wed Jul 10 20:12:18 1996
# Language        : Perl
# Update Count    : 143
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1995, Universität Dortmund, all rights reserved.
# 
# $Locker: pfeifer $
# $Log: Matrix.pm,v $
# Revision 0.2  1996/07/10 17:48:14  pfeifer
# Fixes from Mike Beachy <beachy@chem.columbia.edu>
#
# Revision 0.1  1995/10/25  09:48:39  pfeifer
# Initial revision
#
# modified for use by PDF::API2 by alfred reibenschuh 2001-08-20
# documentation deleted !

package PDF::API2::Matrix;

sub new {
    my $type = shift;
    my $self = [];
    my $len = scalar(@{$_[0]});
    for (@_) {
        return undef if scalar(@{$_}) != $len;
        push(@{$self}, [@{$_}]);
    }
    bless $self, $type;
}

sub concat {
    my $self = shift;
    my $other = shift;
    my $result = new PDF::API2::Matrix (@{$self});
    
    return undef if scalar(@{$self}) != scalar(@{$other});
    for my $i (0 .. $#{$self}) {	
	push @{$result->[$i]}, @{$other->[$i]};
    }
    $result;
}

sub transpose {
    my $self = shift;
    my @result;
    my $m;

    for my $col (@{$self->[0]}) {
        push @result, [];
    }
    for my $row (@{$self}) {
        $m=0;
        for my $col (@{$row}) {
            push(@{$result[$m++]}, $col);
        }
    }
    new PDF::API2::Matrix (@result);
}

sub vekpro {
    my($a, $b) = @_;
    my $result=0;

    for my $i (0 .. $#{$a}) {
        $result += $a->[$i] * $b->[$i];
    }
    $result;
}
                  
sub multiply {
    my $self  = shift;
    my $other = shift->transpose;
    my @result;
    my $m;
    
    return undef if $#{$self->[0]} != $#{$other->[0]};
    for my $row (@{$self}) {
        my $rescol = [];
	for my $col (@{$other}) {
            push(@{$rescol}, vekpro($row,$col));
        }
        push(@result, $rescol);
    }
    new PDF::API2::Matrix (@result);
}


sub solve {
    my $m    = new PDF::API2::Matrix (@{$_[0]});
    my $mr   = $#{$m};
    my $mc   = $#{$m->[0]};
    my $f;
    my $try;
    my $k;
    my $i;
    my $j;
    my $eps = 0.000001;

    return undef if $mc <= $mr;
    ROW: for($i = 0; $i <= $mr; $i++) {
	$try=$i;
	# make diagonal element nonzero if possible
	while (abs($m->[$i]->[$i]) < $eps) {
	    last ROW if $try++ > $mr;
	    my $row = splice(@{$m},$i,1);
	    push(@{$m}, $row);
	}

	# normalize row
	$f = $m->[$i]->[$i];
	for($k = 0; $k <= $mc; $k++) {
            $m->[$i]->[$k] /= $f;
	}
	# subtract multiple of designated row from other rows
        for($j = 0; $j <= $mr; $j++) {
	    next if $i == $j;
            $f = $m->[$j]->[$i];
            for($k = 0; $k <= $mc; $k++) {
                $m->[$j]->[$k] -= $m->[$i]->[$k] * $f;
            }
        }
    }
# Answer is in augmented column    
    transpose new PDF::API2::Matrix @{$m->transpose}[$mr+1 .. $mc];
}

sub print {
    my $self = shift;
    
    print @_ if scalar(@_);
    for my $row (@{$self}) {
        for my $col (@{$row}) {
            printf "%10.5f ", $col;
        }
        print "\n";
    }
}


1;

=head1 AUTHOR

alfred reibenschuh

=cut

__END__

#=== sRGB - ColorSpace ===
1475 0 obj
[ 
	/CalRGB << 
		/WhitePoint [ 0.95049 1 1.08897 ] 
		/Gamma [ 2.22218 2.22218 2.22218 ] 
		/Matrix [ 0.41238 0.21259 0.01929 0.35757 0.71519 0.11919 0.1805 0.07217 0.95049 ] 
	>> 
]
endobj