#==================================================================
#	Text::PDF::Crypt
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
package Text::PDF::Crypt;

use strict;
use vars qw(@ISA $passwordPad $encryptKeyLen);
@ISA = qw( Text::PDF::Dict );

$passwordPad = "\x28\xbf\x4e\x5e\x4e\x75\x8a\x41\x64\x00\x4e\x56\xff\xfa\x01\x08";
$passwordPad.= "\x2e\x2e\x00\xb6\xd0\x68\x3e\x80\x2f\x0c\xa9\xfe\x64\x53\x69\x7a";

$encryptKeyLen=5; # in bytes

sub new {
	my $class=shift @_;
	my $self=$class->SUPER::new(@_);

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
#	Text::PDF::Crypt::MD5
#==================================================================
#
package Text::PDF::Crypt::MD5;
use strict;
use integer;
use Exporter;
use vars qw($VERSION @ISA @EXPORTER @EXPORT_OK);

@EXPORT_OK = qw(md5 md5_hex md5_base64);

@ISA = 'Exporter';
$VERSION = '1.5';

# I-Vektor
sub A() { 0x67_45_23_01 }
sub B() { 0xef_cd_ab_89 }
sub C() { 0x98_ba_dc_fe }
sub D() { 0x10_32_54_76 }

# for internal use
sub MAX() { 0xFFFFFFFF }

# padd a message to a multiple of 64
sub padding($) {
    my $l = length (my $msg = shift() . chr(128));    
    $msg .= "\0" x (($l%64<=56?56:120)-$l%64);
    $l = ($l-1)*8;
    $msg .= pack 'VV', $l & MAX , ($l >> 16 >> 16);
}


sub rotate_left($$) {
	#$_[0] << $_[1] | $_[0] >> (32 - $_[1]);
	#my $right = $_[0] >> (32 - $_[1]);
	#my $rmask = (1 << $_[1]) - 1;
	($_[0] << $_[1]) | (( $_[0] >> (32 - $_[1])  )  & ((1 << $_[1]) - 1));
	#$_[0] << $_[1] | (($_[0]>> (32 - $_[1])) & (1 << (32 - $_[1])) - 1);
}

sub gen_code {
  # Discard upper 32 bits on 64 bit archs.
  my $MSK = ((1 << 16) << 16) ? ' & ' . MAX : '';
#	FF => "X0=rotate_left(((X1&X2)|(~X1&X3))+X0+X4+X6$MSK,X5)+X1$MSK;",
#	GG => "X0=rotate_left(((X1&X3)|(X2&(~X3)))+X0+X4+X6$MSK,X5)+X1$MSK;",
  my %f = (
	FF => "X0=rotate_left((X3^(X1&(X2^X3)))+X0+X4+X6$MSK,X5)+X1$MSK;",
	GG => "X0=rotate_left((X2^(X3&(X1^X2)))+X0+X4+X6$MSK,X5)+X1$MSK;",
	HH => "X0=rotate_left((X1^X2^X3)+X0+X4+X6$MSK,X5)+X1$MSK;",
	II => "X0=rotate_left((X2^(X1|(~X3)))+X0+X4+X6$MSK,X5)+X1$MSK;",
  );
  #unless ( (1 << 16) << 16) { %f = %{$CODES{'32bit'}} }
  #else { %f = %{$CODES{'64bit'}} }

  my %s = (  # shift lengths
	S11 => 7, S12 => 12, S13 => 17, S14 => 22, S21 => 5, S22 => 9, S23 => 14,
	S24 => 20, S31 => 4, S32 => 11, S33 => 16, S34 => 23, S41 => 6, S42 => 10,
	S43 => 15, S44 => 21
  );

  my $insert = "";
  while(<DATA>) {
	chomp;
	next unless /^[FGHI]/;
	my ($func,@x) = split /,/;
	my $c = $f{$func};
	$c =~ s/X(\d)/$x[$1]/g;
	$c =~ s/(S\d{2})/$s{$1}/;
        $c =~ s/^(.*)=rotate_left\((.*),(.*)\)\+(.*)$//;

	#my $rotate = "(($2 << $3) || (($2 >> (32 - $3)) & (1 << $2) - 1)))"; 
	$c = "\$r = $2;
        $1 = ((\$r << $3) | ((\$r >> (32 - $3))  & ((1 << $3) - 1))) + $4";
	$insert .= "\t$c\n";
  }
  
  my $dump = '
  sub round {
	my ($a,$b,$c,$d) = @_[0 .. 3];
	my $r;

	' . $insert . '
	$_[0]+$a' . $MSK . ', $_[1]+$b ' . $MSK . 
        ', $_[2]+$c' . $MSK . ', $_[3]+$d' . $MSK . ';
  }';
  eval $dump;
  #print "$dump\n";
  #exit 0;
}

gen_code();


# object part of this module
sub new {
	my $class = shift;
	bless {}, ref($class) || $class;
}

sub reset {
	my $self = shift;
	delete $self->{data};
	$self
}

sub add(@) {
	my $self = shift;
	$self->{data} .= join'', @_;
	$self
}

sub addfile {
  	my ($self,$fh) = @_;
	if (!ref($fh) && ref(\$fh) ne "GLOB") {
	    require Symbol;
	    $fh = Symbol::qualify($fh, scalar caller);
	}
	$self->{data} .= do{local$/;<$fh>};
	$self
}

sub digest {
	md5(shift->{data})
}

sub hexdigest {
	md5_hex(shift->{data})
}

sub b64digest {
	md5_base64(shift->{data})
}

sub md5(@) {
	my $message = padding(join'',@_);
	my ($a,$b,$c,$d) = (A,B,C,D);
	my $i;
	for $i (0 .. (length $message)/64-1) {
		my @X = unpack 'V16', substr $message,$i*64,64;	
		($a,$b,$c,$d) = round($a,$b,$c,$d,@X);
	}
	pack 'V4',$a,$b,$c,$d;
}


sub md5_hex(@) {  
  unpack 'H*', &md5;
}

sub md5_base64(@) {
  encode_base64(&md5);
}


sub encode_base64 ($) {
    my $res;
    while ($_[0] =~ /(.{1,45})/gs) {
	$res .= substr pack('u', $1), 1;
	chop $res;
    }
    $res =~ tr|` -_|AA-Za-z0-9+/|;#`
    chop $res;chop $res;
    $res;
}

1;

__DATA__
FF,$a,$b,$c,$d,$_[4],7,0xd76aa478,/* 1 */
FF,$d,$a,$b,$c,$_[5],12,0xe8c7b756,/* 2 */
FF,$c,$d,$a,$b,$_[6],17,0x242070db,/* 3 */
FF,$b,$c,$d,$a,$_[7],22,0xc1bdceee,/* 4 */
FF,$a,$b,$c,$d,$_[8],7,0xf57c0faf,/* 5 */
FF,$d,$a,$b,$c,$_[9],12,0x4787c62a,/* 6 */
FF,$c,$d,$a,$b,$_[10],17,0xa8304613,/* 7 */
FF,$b,$c,$d,$a,$_[11],22,0xfd469501,/* 8 */
FF,$a,$b,$c,$d,$_[12],7,0x698098d8,/* 9 */
FF,$d,$a,$b,$c,$_[13],12,0x8b44f7af,/* 10 */
FF,$c,$d,$a,$b,$_[14],17,0xffff5bb1,/* 11 */
FF,$b,$c,$d,$a,$_[15],22,0x895cd7be,/* 12 */
FF,$a,$b,$c,$d,$_[16],7,0x6b901122,/* 13 */
FF,$d,$a,$b,$c,$_[17],12,0xfd987193,/* 14 */
FF,$c,$d,$a,$b,$_[18],17,0xa679438e,/* 15 */
FF,$b,$c,$d,$a,$_[19],22,0x49b40821,/* 16 */ 
GG,$a,$b,$c,$d,$_[5],5,0xf61e2562,/* 17 */
GG,$d,$a,$b,$c,$_[10],9,0xc040b340,/* 18 */
GG,$c,$d,$a,$b,$_[15],14,0x265e5a51,/* 19 */
GG,$b,$c,$d,$a,$_[4],20,0xe9b6c7aa,/* 20 */
GG,$a,$b,$c,$d,$_[9],5,0xd62f105d,/* 21 */
GG,$d,$a,$b,$c,$_[14],9,0x2441453,/* 22 */
GG,$c,$d,$a,$b,$_[19],14,0xd8a1e681,/* 23 */
GG,$b,$c,$d,$a,$_[8],20,0xe7d3fbc8,/* 24 */
GG,$a,$b,$c,$d,$_[13],5,0x21e1cde6,/* 25 */
GG,$d,$a,$b,$c,$_[18],9,0xc33707d6,/* 26 */
GG,$c,$d,$a,$b,$_[7],14,0xf4d50d87,/* 27 */
GG,$b,$c,$d,$a,$_[12],20,0x455a14ed,/* 28 */
GG,$a,$b,$c,$d,$_[17],5,0xa9e3e905,/* 29 */
GG,$d,$a,$b,$c,$_[6],9,0xfcefa3f8,/* 30 */
GG,$c,$d,$a,$b,$_[11],14,0x676f02d9,/* 31 */
GG,$b,$c,$d,$a,$_[16],20,0x8d2a4c8a,/* 32 */
HH,$a,$b,$c,$d,$_[9],4,0xfffa3942,/* 33 */
HH,$d,$a,$b,$c,$_[12],11,0x8771f681,/* 34 */
HH,$c,$d,$a,$b,$_[15],16,0x6d9d6122,/* 35 */
HH,$b,$c,$d,$a,$_[18],23,0xfde5380c,/* 36 */
HH,$a,$b,$c,$d,$_[5],4,0xa4beea44,/* 37 */
HH,$d,$a,$b,$c,$_[8],11,0x4bdecfa9,/* 38 */
HH,$c,$d,$a,$b,$_[11],16,0xf6bb4b60,/* 39 */
HH,$b,$c,$d,$a,$_[14],23,0xbebfbc70,/* 40 */
HH,$a,$b,$c,$d,$_[17],4,0x289b7ec6,/* 41 */
HH,$d,$a,$b,$c,$_[4],11,0xeaa127fa,/* 42 */
HH,$c,$d,$a,$b,$_[7],16,0xd4ef3085,/* 43 */
HH,$b,$c,$d,$a,$_[10],23,0x4881d05,/* 44 */
HH,$a,$b,$c,$d,$_[13],4,0xd9d4d039,/* 45 */
HH,$d,$a,$b,$c,$_[16],11,0xe6db99e5,/* 46 */
HH,$c,$d,$a,$b,$_[19],16,0x1fa27cf8,/* 47 */
HH,$b,$c,$d,$a,$_[6],23,0xc4ac5665,/* 48 */
II,$a,$b,$c,$d,$_[4],6,0xf4292244,/* 49 */
II,$d,$a,$b,$c,$_[11],10,0x432aff97,/* 50 */
II,$c,$d,$a,$b,$_[18],15,0xab9423a7,/* 51 */
II,$b,$c,$d,$a,$_[9],21,0xfc93a039,/* 52 */
II,$a,$b,$c,$d,$_[16],6,0x655b59c3,/* 53 */
II,$d,$a,$b,$c,$_[7],10,0x8f0ccc92,/* 54 */
II,$c,$d,$a,$b,$_[14],15,0xffeff47d,/* 55 */
II,$b,$c,$d,$a,$_[5],21,0x85845dd1,/* 56 */
II,$a,$b,$c,$d,$_[12],6,0x6fa87e4f,/* 57 */
II,$d,$a,$b,$c,$_[19],10,0xfe2ce6e0,/* 58 */
II,$c,$d,$a,$b,$_[10],15,0xa3014314,/* 59 */
II,$b,$c,$d,$a,$_[17],21,0x4e0811a1,/* 60 */
II,$a,$b,$c,$d,$_[8],6,0xf7537e82,/* 61 */
II,$d,$a,$b,$c,$_[15],10,0xbd3af235,/* 62 */
II,$c,$d,$a,$b,$_[6],15,0x2ad7d2bb,/* 63 */
II,$b,$c,$d,$a,$_[13],21,0xeb86d391,/* 64 */
