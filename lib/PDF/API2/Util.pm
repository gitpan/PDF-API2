package PDF::API2::Util;

use vars qw($VERSION @ISA @EXPORT %colors);
use Math::Trig;
use POSIX;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( 
	pdfkey digest digestx digest16 digest32 
	float floats floats5 intg intgs 
	mMin mMax 
	cRGB cRGB8 RGBasCMYK HSVtoRGB
	namecolor
);            

BEGIN {
        %colors=(
        	aliceblue => [0.941176470588235,0.972549019607843,1],
        	antiquewhite => [0.980392156862745,0.92156862745098,0.843137254901961],
        	aqua => [0,1,1],
        	aquamarine => [0.498039215686275,1,0.831372549019608],
        	azure => [0.941176470588235,1,1],
        	beige => [0.96078431372549,0.96078431372549,0.862745098039216],
        	bisque => [1,0.894117647058824,0.768627450980392],
        	black => [0,0,0],
        	blanchedalmond => [1,0.92156862745098,0.803921568627451],
        	blue => [0,0,1],
        	blueviolet => [0.541176470588235,0.168627450980392,0.886274509803922],
        	brown => [0.647058823529412,0.164705882352941,0.164705882352941],
        	burlywood => [0.870588235294118,0.72156862745098,0.529411764705882],
        	cadetblue => [0.372549019607843,0.619607843137255,0.627450980392157],
        	chartreuse => [0.498039215686275,1,0],
        	chocolate => [0.823529411764706,0.411764705882353,0.117647058823529],
        	coral => [1,0.498039215686275,0.313725490196078],
        	cornflowerblue => [0.392156862745098,0.584313725490196,0.929411764705882],
        	cornsilk => [1,0.972549019607843,0.862745098039216],
        	crimson => [0.862745098039216,0.0784313725490196,0.235294117647059],
        	cyan => [0,1,1],
        	darkblue => [0,0,0.545098039215686],
        	darkcyan => [0,0.545098039215686,0.545098039215686],
        	darkgoldenrod => [0.72156862745098,0.525490196078431,0.0431372549019608],
        	darkgray => [0.662745098039216,0.662745098039216,0.662745098039216],
        	darkgreen => [0,0.392156862745098,0],
        	darkgrey => [0.662745098039216,0.662745098039216,0.662745098039216],
        	darkkhaki => [0.741176470588235,0.717647058823529,0.419607843137255],
        	darkmagenta => [0.545098039215686,0,0.545098039215686],
        	darkolivegreen => [0.333333333333333,0.419607843137255,0.184313725490196],
        	darkorange => [1,0.549019607843137,0],
        	darkorchid => [0.6,0.196078431372549,0.8],
        	darkred => [0.545098039215686,0,0],
        	darksalmon => [0.913725490196078,0.588235294117647,0.47843137254902],
        	darkseagreen => [0.56078431372549,0.737254901960784,0.56078431372549],
        	darkslateblue => [0.282352941176471,0.23921568627451,0.545098039215686],
        	darkslategray => [0.184313725490196,0.309803921568627,0.309803921568627],
        	darkslategrey => [0.184313725490196,0.309803921568627,0.309803921568627],
        	darkturquoise => [0,0.807843137254902,0.819607843137255],
        	darkviolet => [0.580392156862745,0,0.827450980392157],
        	deeppink => [1,0.0784313725490196,0.576470588235294],
        	deepskyblue => [0,0.749019607843137,1],
        	dimgray => [0.411764705882353,0.411764705882353,0.411764705882353],
        	dimgrey => [0.411764705882353,0.411764705882353,0.411764705882353],
        	dodgerblue => [0.117647058823529,0.564705882352941,1],
        	firebrick => [0.698039215686274,0.133333333333333,0.133333333333333],
        	floralwhite => [1,0.980392156862745,0.941176470588235],
        	forestgreen => [0.133333333333333,0.545098039215686,0.133333333333333],
        	fuchsia => [1,0,1],
        	gainsboro => [0.862745098039216,0.862745098039216,0.862745098039216],
        	ghostwhite => [0.972549019607843,0.972549019607843,1],
        	gold => [1,0.843137254901961,0],
        	goldenrod => [0.854901960784314,0.647058823529412,0.125490196078431],
        	gray => [0.501960784313725,0.501960784313725,0.501960784313725],
        	grey => [0.501960784313725,0.501960784313725,0.501960784313725],
        	green => [0,0.501960784313725,0],
        	greenyellow => [0.67843137254902,1,0.184313725490196],
        	honeydew => [0.941176470588235,1,0.941176470588235],
        	hotpink => [1,0.411764705882353,0.705882352941177],
        	indianred => [0.803921568627451,0.36078431372549,0.36078431372549],
        	indigo => [0.294117647058824,0,0.509803921568627],
        	ivory => [1,1,0.941176470588235],
        	khaki => [0.941176470588235,0.901960784313726,0.549019607843137],
        	lavender => [0.901960784313726,0.901960784313726,0.980392156862745],
        	lavenderblush => [1,0.941176470588235,0.96078431372549],
        	lawngreen => [0.486274509803922,0.988235294117647,0],
        	lemonchiffon => [1,0.980392156862745,0.803921568627451],
        	lightblue => [0.67843137254902,0.847058823529412,0.901960784313726],
        	lightcoral => [0.941176470588235,0.501960784313725,0.501960784313725],
        	lightcyan => [0.87843137254902,1,1],
        	lightgoldenrodyellow => [0.980392156862745,0.980392156862745,0.823529411764706],
        	lightgray => [0.827450980392157,0.827450980392157,0.827450980392157],
        	lightgreen => [0.564705882352941,0.933333333333333,0.564705882352941],
        	lightgrey => [0.827450980392157,0.827450980392157,0.827450980392157],
        	lightpink => [1,0.713725490196078,0.756862745098039],
        	lightsalmon => [1,0.627450980392157,0.47843137254902],
        	lightseagreen => [0.125490196078431,0.698039215686274,0.666666666666667],
        	lightskyblue => [0.529411764705882,0.807843137254902,0.980392156862745],
        	lightslategray => [0.466666666666667,0.533333333333333,0.6],
        	lightslategrey => [0.466666666666667,0.533333333333333,0.6],
        	lightsteelblue => [0.690196078431373,0.768627450980392,0.870588235294118],
        	lightyellow => [1,1,0.87843137254902],
        	lime => [0,1,0],
        	limegreen => [0.196078431372549,0.803921568627451,0.196078431372549],
        	linen => [0.980392156862745,0.941176470588235,0.901960784313726],
        	magenta => [1,0,1],
        	maroon => [0.501960784313725,0,0],
        	mediumaquamarine => [0.4,0.803921568627451,0.666666666666667],
        	mediumblue => [0,0,0.803921568627451],
        	mediumorchid => [0.729411764705882,0.333333333333333,0.827450980392157],
        	mediumpurple => [0.576470588235294,0.43921568627451,0.858823529411765],
        	mediumseagreen => [0.235294117647059,0.701960784313725,0.443137254901961],
        	mediumslateblue => [0.482352941176471,0.407843137254902,0.933333333333333],
        	mediumspringgreen => [0,0.980392156862745,0.603921568627451],
        	mediumturquoise => [0.282352941176471,0.819607843137255,0.8],
        	mediumvioletred => [0.780392156862745,0.0823529411764706,0.52156862745098],
        	midnightblue => [0.0980392156862745,0.0980392156862745,0.43921568627451],
        	mintcream => [0.96078431372549,1,0.980392156862745],
        	mistyrose => [1,0.894117647058824,0.882352941176471],
        	moccasin => [1,0.894117647058824,0.709803921568627],
        	navajowhite => [1,0.870588235294118,0.67843137254902],
        	navy => [0,0,0.501960784313725],
        	oldlace => [0.992156862745098,0.96078431372549,0.901960784313726],
        	olive => [0.501960784313725,0.501960784313725,0],
        	olivedrab => [0.419607843137255,0.556862745098039,0.137254901960784],
        	orange => [1,0.647058823529412,0],
        	orangered => [1,0.270588235294118,0],
        	orchid => [0.854901960784314,0.43921568627451,0.83921568627451],
        	palegoldenrod => [0.933333333333333,0.909803921568627,0.666666666666667],
        	palegreen => [0.596078431372549,0.984313725490196,0.596078431372549],
        	paleturquoise => [0.686274509803922,0.933333333333333,0.933333333333333],
        	palevioletred => [0.858823529411765,0.43921568627451,0.576470588235294],
        	papayawhip => [1,0.937254901960784,0.835294117647059],
        	peachpuff => [1,0.854901960784314,0.725490196078431],
        	peru => [0.803921568627451,0.52156862745098,0.247058823529412],
        	pink => [1,0.752941176470588,0.796078431372549],
        	plum => [0.866666666666667,0.627450980392157,0.866666666666667],
        	powderblue => [0.690196078431373,0.87843137254902,0.901960784313726],
        	purple => [0.501960784313725,0,0.501960784313725],
        	red => [1,0,0],
        	rosybrown => [0.737254901960784,0.56078431372549,0.56078431372549],
        	royalblue => [0.254901960784314,0.411764705882353,0.882352941176471],
        	saddlebrown => [0.545098039215686,0.270588235294118,0.0745098039215686],
        	salmon => [0.980392156862745,0.501960784313725,0.447058823529412],
        	sandybrown => [0.956862745098039,0.643137254901961,0.376470588235294],
        	seagreen => [0.180392156862745,0.545098039215686,0.341176470588235],
        	seashell => [1,0.96078431372549,0.933333333333333],
        	sienna => [0.627450980392157,0.32156862745098,0.176470588235294],
        	silver => [0.752941176470588,0.752941176470588,0.752941176470588],
        	skyblue => [0.529411764705882,0.807843137254902,0.92156862745098],
        	slateblue => [0.415686274509804,0.352941176470588,0.803921568627451],
        	slategray => [0.43921568627451,0.501960784313725,0.564705882352941],
        	slategrey => [0.43921568627451,0.501960784313725,0.564705882352941],
        	snow => [1,0.980392156862745,0.980392156862745],
        	springgreen => [0,1,0.498039215686275],
        	steelblue => [0.274509803921569,0.509803921568627,0.705882352941177],
        	tan => [0.823529411764706,0.705882352941177,0.549019607843137],
        	teal => [0,0.501960784313725,0.501960784313725],
        	thistle => [0.847058823529412,0.749019607843137,0.847058823529412],
        	tomato => [1,0.388235294117647,0.27843137254902],
        	turquoise => [0.250980392156863,0.87843137254902,0.815686274509804],
        	violet => [0.933333333333333,0.509803921568627,0.933333333333333],
        	wheat => [0.96078431372549,0.870588235294118,0.701960784313725],
        	white => [1,1,1],
        	whitesmoke => [0.96078431372549,0.96078431372549,0.96078431372549],
        	yellow => [1,1,0],
        	yellowgreen => [0.603921568627451,0.803921568627451,0.196078431372549],
                none => [0,0,0],
        );

}

sub mMin {
	my $n=HUGE_VAL;
	map { $n=($n>$_) ? $_ : $n } @_;
	return($n);	
}

sub mMax {
	my $n=-(HUGE_VAL);
	map { $n=($n<$_) ? $_ : $n } @_;
	return($n);	
}

sub cRGB {
	my @cmy=(map { 1-$_ } @_);
	my $k=mMin(@cmy);
	return((map { $_-$k } @cmy),$k);
}

sub cRGB8 {
	return cRGB(map { $_/255 } @_);
}

sub RGBasCMYK {
	my @rgb=@_;
	my @cmy=(map { 1-$_ } @rgb);
	my $k=mMin(@cmy);
	return((map { $_-$k } @cmy),$k);
}

sub HSVtoRGB ($$$) {
	my ($h,$s,$v)=@_;
	my ($r,$g,$b,$i,$f,$p,$q,$t);

        if( $s == 0 ) {
                ## achromatic (grey)
                return ($v,$v,$v);
        }

        $h %= 360;                      
        $h /= 60;                       ## sector 0 to 5
        $i = POSIX::floor( $h );
        $f = $h - $i;                   ## factorial part of h
        $p = $v * ( 1 - $s );
        $q = $v * ( 1 - $s * $f );
        $t = $v * ( 1 - $s * ( 1 - $f ) );

	if($i<1) {
		$r = $v;
                $g = $t;
                $b = $p;
	} elsif($i<2){
		$r = $q;
                $g = $v;
                $b = $p;
	} elsif($i<3){
		$r = $p;
                $g = $v;
                $b = $t;
	} elsif($i<4){
		$r = $p;
                $g = $q;
                $b = $v;
	} elsif($i<5){
		$r = $t;
                $g = $p;
                $b = $v;
	} else {
		$r = $v;
                $g = $p;
                $b = $q;
	}
	return ($r,$g,$b);
}

sub namecolor {
	my $name=lc(shift @_);
	$name=~s/[^\#!%a-z0-9]//cg;
	my $col;
	if($name=~/^#/) {
		my ($r,$g,$b,$h);
		if(length($name)<5) {		# zb. #fa4,          #cf0
			$r=hex(substr($name,1,1))/0xf;
			$g=hex(substr($name,2,1))/0xf;
			$b=hex(substr($name,3,1))/0xf;
		} elsif(length($name)<8) {	# zb. #ffaa44,       #ccff00
			$r=hex(substr($name,1,2))/0xff;
			$g=hex(substr($name,3,2))/0xff;
			$b=hex(substr($name,5,2))/0xff;
		} elsif(length($name)<11) {	# zb. #fffaaa444,    #cccfff000
			$r=hex(substr($name,1,3))/0xfff;
			$g=hex(substr($name,4,3))/0xfff;
			$b=hex(substr($name,7,3))/0xfff;
		} else {			# zb. #ffffaaaa4444, #ccccffff0000
			$r=hex(substr($name,1,4))/0xffff;
			$g=hex(substr($name,5,4))/0xffff;
			$b=hex(substr($name,9,4))/0xffff;
		}
		$col=[$r,$g,$b];
	} elsif($name=~/^%/) {
		my ($r,$g,$b,$c,$y,$m,$k);
		if(length($name)<6) {		# zb. %cmyk
			$c=hex(substr($name,1,1))/0xf;
			$m=hex(substr($name,2,1))/0xf;
			$y=hex(substr($name,3,1))/0xf;
			$k=hex(substr($name,4,1))/0xf;
		} elsif(length($name)<10) {	# zb. %ccmmyykk
			$c=hex(substr($name,1,2))/0xff;
			$m=hex(substr($name,3,2))/0xff;
			$y=hex(substr($name,5,2))/0xff;
			$k=hex(substr($name,7,2))/0xff;
		} elsif(length($name)<14) {	# zb. %cccmmmyyykkk
			$c=hex(substr($name,1,3))/0xfff;
			$m=hex(substr($name,4,3))/0xfff;
			$y=hex(substr($name,7,3))/0xfff;
			$k=hex(substr($name,10,3))/0xfff;
		} else {			# zb. %ccccmmmmyyyykkkk
			$c=hex(substr($name,1,4))/0xffff;
			$m=hex(substr($name,5,4))/0xffff;
			$y=hex(substr($name,9,4))/0xffff;
			$k=hex(substr($name,13,4))/0xffff;
		}
		$r=1-$c-$k;
		$g=1-$m-$k;
		$b=1-$y-$k;
		$col=[$r,$g,$b];
	} elsif($name=~/^!/) {
		my ($r,$g,$b,$h,$s,$v);
		if(length($name)<5) {		
			$h=360*hex(substr($name,1,1))/0xf;
			$s=hex(substr($name,2,1))/0xf;
			$v=hex(substr($name,3,1))/0xf;
		} elsif(length($name)<8) {
			$h=360*hex(substr($name,1,2))/0xff;
			$s=hex(substr($name,3,2))/0xff;
			$v=hex(substr($name,5,2))/0xff;
		} elsif(length($name)<11) {	
			$h=360*hex(substr($name,1,3))/0xfff;
			$s=hex(substr($name,4,3))/0xfff;
			$v=hex(substr($name,7,3))/0xfff;
		} else {		
			$h=360*hex(substr($name,1,4))/0xffff;
			$s=hex(substr($name,5,4))/0xffff;
			$v=hex(substr($name,9,4))/0xffff;
		}
		($r,$g,$b)=HSVtoRGB($h,$s,$v);
		$col=[$r,$g,$b];
	} else {
		$col = $colors{$name} || [0,0,0];
	}
	return(@{$col});
}

sub pdfkey {
	my $ddata=join('',@_);
	my $mdkey='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789gT';
	my $xdata="0" x 8;
	my $off=0;
	foreach my $set (0..(length($ddata)<<1)) {
		$off+=vec($ddata,$set,4);
		$off+=vec($xdata,($set & 7),8);
		vec($xdata,($set & 7),8)=vec($mdkey,($off & 0x3f),8);
	}
	return($xdata);
}

sub digestx {
	my $len=shift @_;
	my $mask=$len-1;
	my $ddata=join('',@_);
	my $mdkey='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789gT';
	my $xdata="0" x $len;
	my $off=0;
	my $set;
	foreach $set (0..(length($ddata)<<1)) {
		$off+=vec($ddata,$set,4);
		$off+=vec($xdata,($set & $mask),8);
		vec($xdata,($set & ($mask<<1 |1)),4)=vec($mdkey,($off & 0x7f),4);
	}
	
#	foreach $set (0..$mask) {
#		vec($xdata,$set,8)=(vec($xdata,$set,8) & 0x7f) | 0x40;
#	}

#	$off=0;
#	foreach $set (0..$mask) {
#		$off+=vec($xdata,$set,8);
#		vec($xdata,$set,8)=vec($mdkey,($off & 0x3f),8);
#	}

	return($xdata);
}

sub digest {
	return(digestx(32,@_));
}

sub digest16 {
	return(digestx(16,@_));
}

sub digest32 {
	return(digestx(32,@_));
}

sub xlog10 {
	my $n = shift;
	if($n) {
    		return log(abs($n))/log(10);
	} else { return 0; }
}

sub float {
	my $f=shift @_;
	my $mxd=shift @_||4;
	$f=0 if(abs($f)<0.0000000000000001);
	my $ad=floor(xlog10($f)-$mxd);
	if(abs($f-int($f)) < (10**(-$mxd))) {
		# just in case we have an integer
		return sprintf('%i',$f);
	} elsif($ad>0){
		return sprintf('%f',$f);
	} else {
		return sprintf('%.'.abs($ad).'f',$f);
	}
}
sub floats { return map { float($_); } @_; }
sub floats5 { return map { float($_,5); } @_; }


sub intg {
	my $f=shift @_;
	return sprintf('%i',$f);
}
sub intgs { return map { intg($_); } @_; }

1;
