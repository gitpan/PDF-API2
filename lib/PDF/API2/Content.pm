#=======================================================================
#    ____  ____  _____              _    ____ ___   ____
#   |  _ \|  _ \|  ___|  _   _     / \  |  _ \_ _| |___ \
#   | |_) | | | | |_    (_) (_)   / _ \ | |_) | |    __) |
#   |  __/| |_| |  _|    _   _   / ___ \|  __/| |   / __/
#   |_|   |____/|_|     (_) (_) /_/   \_\_|  |___| |_____|
#
#   A Perl Module Chain to faciliate the Creation and Modification
#   of High-Quality "Portable Document Format (PDF)" Files.
#
#   Copyright 1999-2004 Alfred Reibenschuh <areibens@cpan.org>.
#
#=======================================================================
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Lesser General Public
#   License as published by the Free Software Foundation; either
#   version 2 of the License, or (at your option) any later version.
#
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public
#   License along with this library; if not, write to the
#   Free Software Foundation, Inc., 59 Temple Place - Suite 330,
#   Boston, MA 02111-1307, USA.
#
#   $Id: Content.pm,v 1.15 2004/08/31 13:50:09 fredo Exp $
#
#=======================================================================

package PDF::API2::Content;

BEGIN {

    use strict;
    use vars qw(@ISA $VERSION);
    use PDF::API2::Basic::PDF::Dict;
    use PDF::API2::Basic::PDF::Utils;
    use PDF::API2::Util;
    use PDF::API2::Matrix;
    use Math::Trig;
    use Encode;
    @ISA = qw(PDF::API2::Basic::PDF::Dict);

    ( $VERSION ) = '$Revision: 1.15 $' =~ /Revision: (\S+)\s/; # $Date: 2004/08/31 13:50:09 $

}

=head1 $co = PDF::API2::Content->new @parameters

Returns a new content object (called from $page->text/gfx).

=cut

sub new {
    my ($class)=@_;
    my $self = $class->SUPER::new(@_);
    $self->{' stream'}='';
    $self->{' poststream'}='';
    $self->{' font'}=undef;
    $self->{' fontsize'}=0;
    $self->{' charspace'}=0;
    $self->{' hspace'}=100;
    $self->{' wordspace'}=0;
    $self->{' lead'}=0;
    $self->{' rise'}=0;
    $self->{' render'}=0;
    $self->{' matrix'}=[1,0,0,1,0,0];
    $self->{' fillcolor'}=[0];
    $self->{' strokecolor'}=[0];
    $self->{' translate'}=[0,0];
    $self->{' scale'}=[1,1];
    $self->{' skew'}=[0,0];
    $self->{' rotate'}=0;
    $self->{' apiistext'}=0;
#    $self->save;
    return($self);
}

sub outobjdeep {
    my $self = shift @_;
    $self->textend;
    foreach my $k (qw/ api apipdf apiistext apipage font fontsize charspace hspace wordspace lead rise render matrix fillcolor strokecolor translate scale skew rotate /) {
        $self->{" $k"}=undef;
        delete($self->{" $k"});
    }
    $self->SUPER::outobjdeep(@_);
}

=item $co->add @content

Adds @content to the object.

=cut

sub add_post {
    my $self=shift @_;
    if(scalar @_>0) {
        $self->{' poststream'}.=($self->{' poststream'}=~m|\s$|o?'':' ').join(' ',@_).' ';
    }
    $self;
}
sub add {
    my $self=shift @_;
    if(scalar @_>0) {
        $self->{' stream'}.=encode("iso-8859-1",($self->{' stream'}=~m|\s$|o?'':' ').join(' ',@_).' ');
    }
    $self;
}

=item $co->save

Saves the state of the object.

=cut

sub _save {
    return('q');
}

sub save {
    my $self=shift @_;
    unless(defined($self->{' apiistext'}) && $self->{' apiistext'} == 1) {
        $self->add(_save());
    }
}

=item $co->restore

Restores the state of the object.

=cut

sub _restore {
    return('Q');
}

sub restore {
    my $self=shift @_;
    unless(defined($self->{' apiistext'}) && $self->{' apiistext'} == 1) {
        $self->add(_restore());
    }
}

=item $co->compress

Marks content for compression on output.

=cut

sub compress {
    my $self=shift @_;
    $self->{'Filter'}=PDFArray(PDFName('FlateDecode'));
    return($self);
}

=item $co->flatness $flat

Sets flatness.

=cut

sub _flatness {
    my ($flatness)=@_;
    return($flatness,'i');
}
sub flatness {
    my ($self,$flatness)=@_;
    $self->add(_flatness($flatness));
}

=item $co->linecap $cap

Sets linecap.

=cut

sub _linecap {
    my ($linecap)=@_;
    return($linecap,'J');
}
sub linecap {
    my ($self,$linecap)=@_;
    $self->add(_linecap($linecap));
}

=item $co->linedash @dash

Sets linedash.

=cut

sub _linedash {
    my (@a)=@_;
    if(scalar @a < 1) {
            return('[',']','0','d');
    } else {
        if($a[0]=~/^\-/){
            my %a=@a;
            $a{-pattern}=[$a{-full}||0,$a{-clear}||0] unless($a{-pattern});
            return('[',floats(@{$a{-pattern}}),']',($a{-shift}||0),'d');
        } else {
            return('[',floats(@a),'] 0 d');
        }
    }
}
sub linedash {
    my ($self,@a)=@_;
    $self->add(_linedash(@a));
}

=item $co->linejoin $join

Sets linejoin.

=cut

sub _linejoin {
    my ($linejoin)=@_;
    return($linejoin,'j');
}
sub linejoin {
    my ($this,$linejoin)=@_;
    $this->add(_linejoin($linejoin));
}

=item $co->linewidth $width

Sets linewidth.

=cut

sub _linewidth {
    my ($linewidth)=@_;
    return($linewidth,'w');
}
sub linewidth {
    my ($this,$linewidth)=@_;
    $this->add(_linewidth($linewidth));
}

=item $co->meterlimit $limit

Sets meterlimit.

=cut

sub _meterlimit {
    my ($limit)=@_;
    return($limit,'M');
}
sub meterlimit {
    my ($this, $limit)=@_;
    $this->add(_meterlimit($limit));
}

=item $co->matrix $a,$b,$c,$d,$e,$f

Sets matrix transformation.

=cut

sub _matrix_text {
    my ($a,$b,$c,$d,$e,$f)=@_;
    return(floats($a,$b,$c,$d,$e,$f),'Tm');
}
sub _matrix_gfx {
    my ($a,$b,$c,$d,$e,$f)=@_;
    return(floats($a,$b,$c,$d,$e,$f),'cm');
}
sub matrix {
    my $self=shift @_;
    my ($a,$b,$c,$d,$e,$f)=@_;
    if(defined $a) {
        if(defined($self->{' apiistext'}) && $self->{' apiistext'} == 1) {
            $self->add(_matrix_text($a,$b,$c,$d,$e,$f));
            @{$self->{' matrix'}}=($a,$b,$c,$d,$e,$f);
        } else {
            $self->add(_matrix_gfx($a,$b,$c,$d,$e,$f));
        }
    }
    if(defined($self->{' apiistext'}) && $self->{' apiistext'} == 1) {
        return(@{$self->{' matrix'}});
    } else {
        return($self);
    }
}

=item $co->translate $x,$y

Sets translation transformation.

=cut

sub _translate {
    my ($x,$y)=@_;
    return(1,0,0,1,$x,$y);
}
sub translate {
  my ($self,$x,$y)=@_;
  $self->transform(-translate=>[$x,$y]);
}

=item $co->scale $sx,$sy

Sets scaleing transformation.

=cut

sub _scale {
    my ($x,$y)=@_;
    return($x,0,0,$y,0,0);
}
sub scale {
  my ($self,$sx,$sy)=@_;
  $self->transform(-scale=>[$sx,$sy]);
}

=item $co->skew $sa,$sb

Sets skew transformation.

=cut

sub _skew {
    my ($a,$b)=@_;
    return(1, tan(deg2rad($a)),tan(deg2rad($b)),1,0,0);
}
sub skew {
  my ($self,$a,$b)=@_;
  $self->transform(-skew=>[$a,$b]);
}

=item $co->rotate $rot

Sets rotation transformation.

=cut

sub _rotate {
    my ($a)=@_;
    return(cos(deg2rad($a)), sin(deg2rad($a)),-sin(deg2rad($a)), cos(deg2rad($a)),0,0);
}
sub rotate {
  my ($self,$a)=@_;
  $self->transform(-rotate=>$a);
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

sub _transform {
    my (%opt)=@_;
    my $mtx=PDF::API2::Matrix->new([1,0,0],[0,1,0],[0,0,1]);
    foreach my $o (qw( -skew -scale -rotate -translate )) {
        next unless(defined($opt{$o}));
        if($o eq '-translate') {
            my @mx=_translate(@{$opt{$o}});
            $mtx=$mtx->multiply(PDF::API2::Matrix->new(
                [$mx[0],$mx[1],0],
                [$mx[2],$mx[3],0],
                [$mx[4],$mx[5],1]
            ));
        } elsif($o eq '-rotate') {
            my @mx=_rotate($opt{$o});
            $mtx=$mtx->multiply(PDF::API2::Matrix->new(
                [$mx[0],$mx[1],0],
                [$mx[2],$mx[3],0],
                [$mx[4],$mx[5],1]
            ));
        } elsif($o eq '-scale') {
            my @mx=_scale(@{$opt{$o}});
            $mtx=$mtx->multiply(PDF::API2::Matrix->new(
                [$mx[0],$mx[1],0],
                [$mx[2],$mx[3],0],
                [$mx[4],$mx[5],1]
            ));
        } elsif($o eq '-skew') {
            my @mx=_skew(@{$opt{$o}});
            $mtx=$mtx->multiply(PDF::API2::Matrix->new(
                [$mx[0],$mx[1],0],
                [$mx[2],$mx[3],0],
                [$mx[4],$mx[4],1]
            ));
        }
    }
    return(
        $mtx->[0][0],$mtx->[0][1],
        $mtx->[1][0],$mtx->[1][1],
        $mtx->[2][0],$mtx->[2][1]
    );
}
sub transform {
    my ($self,%opt)=@_;
    $self->matrix(_transform(%opt));
    if($opt{-translate}) {
        @{$self->{' translate'}}=@{$opt{-translate}};
    } else {
        @{$self->{' translate'}}=(0,0);
    }
    if($opt{-rotate}) {
        $self->{' rotate'}=$opt{-rotate};
    } else {
        $self->{' rotate'}=0;
    }
    if($opt{-scale}) {
        @{$self->{' scale'}}=@{$opt{-scale}};
    } else {
        @{$self->{' scale'}}=(1,1);
    }
    if($opt{-skew}) {
        @{$self->{' skew'}}=@{$opt{-skew}};
    } else {
        @{$self->{' skew'}}=(0,0);
    }
    return($self);
}

=item $co->fillcolor @colors

=item $co->strokecolor @colors

Sets fill-/strokecolor, see PDF::API2::Util for a list of possible color specifiers.

B<Examples:>

    $co->fillcolor('blue');       # blue
    $co->strokecolor('#FF0000');  # red
    $co->fillcolor('%FFF000000'); # cyan

=cut

# default colorspaces: rgb/hsv/named cmyk/hsl lab
#   ... only one text string
#
# pattern or shading space
#   ... only one object
#
# legacy greylevel
#   ... only one value
#
# 

sub _makecolor {
    my ($self,$sf,@clr)=@_;
    if($clr[0]=~/^[a-z\#\!]+/) {
        # colorname or #! specifier
        # with rgb target colorspace
        # namecolor returns always a RGB
        return(namecolor($clr[0]),($sf?'rg':'RG'));
    } elsif($clr[0]=~/^[\%]+/) {
        # % specifier
        # with cmyk target colorspace
        return(namecolor_cmyk($clr[0]),($sf?'k':'K'));
    } elsif($clr[0]=~/^[\$\&]/) {
        # &$ specifier
        # with L*a*b target colorspace
        if(!defined $self->resource('ColorSpace','LabS')) {
            my $dc=PDFDict();
            my $cs=PDFArray(PDFName('Lab'),$dc);
        #    $dc->{WhitePoint}=PDFArray(map { PDFNum($_) } qw(0.9505 1.0000 1.0890));
            $dc->{WhitePoint}=PDFArray(map { PDFNum($_) } qw(1 1 1));
            $dc->{Range}=PDFArray(map { PDFNum($_) } qw(-128 127 -128 127));
            $dc->{Gamma}=PDFArray(map { PDFNum($_) } qw(2.2 2.2 2.2));
            $self->resource('ColorSpace','LabS',$cs);
        }
        return('/LabS',($sf?'cs':'CS'),namecolor_lab($clr[0]),($sf?'sc':'SC'));
    } elsif((scalar @clr == 1) && ref($clr[0])) {
        # pattern or shading space
        return('/Pattern',($sf?'cs':'CS'),'/'.($clr[0]->name),($sf?'scn':'SCN'));
    } elsif(scalar @clr == 1) {
        # grey color spec.
        while($clr[0]>1) { $clr[0]/=255; }
        # adjusted for 8/16/32bit spec.
        return($clr[0],($sf?'g':'G'));
    } elsif(scalar @clr > 1 && ref($clr[0])) {
        # indexed colorspace plus color-index
        # or custom colorspace plus param
        my $cs=shift @clr;
        return('/'.($cs->name),($sf?'cs':'CS'),$cs->param(@clr),($sf?'sc':'SC'));
    } elsif(scalar @clr == 2) {
        # indexed colorspace plus color-index
        # or custom colorspace plus param
        return('/'.($clr[0]->name),($sf?'cs':'CS'),$clr[0]->param($clr[1]),($sf?'sc':'SC'));
    } elsif(scalar @clr == 3) {
        # legacy rgb color-spec (0 <= x <= 1)
        if(!defined $self->resource('ColorSpace','RgbS')) {
            my $dc=PDFDict();
            my $cs=PDFArray(PDFName('CalRGB'),$dc);
            $dc->{WhitePoint}=PDFArray(map { PDFNum($_) } qw(0.9505 1.0000 1.0890));
            $dc->{Gamma}=PDFArray(map { PDFNum($_) } qw(2.2 2.2 2.2));
            $self->resource('ColorSpace','RgbS',$cs);
        }
        return('/RgbS',($sf?'cs':'CS'),floats5(@clr),($sf?'sc':'SC'));
        return(floats($clr[0],$clr[1],$clr[2]),($sf?'rg':'RG'));
    } elsif(scalar @clr == 4) {
        # legacy cmyk color-spec (0 <= x <= 1)
        return(floats($clr[0],$clr[1],$clr[2],$clr[3]),($sf?'k':'K'));
    } else {
        die 'invalid color specification.';
    }
}

sub fillcolor {
    my $self=shift @_;
    if(scalar @_) {
        @{$self->{' fillcolor'}}=@_;
        my @clrs=@_;
        $self->add($self->_makecolor(1,@clrs));
        if(ref($clrs[0]) =~ m|^PDF::API2::Resource::ColorSpace|) {
            $self->resource('ColorSpace',$clrs[0]->name,$clrs[0]);
        } elsif(ref($clrs[0]) =~ m|^PDF::API2::Resource::Pattern|) {
            $self->resource('Pattern',$clrs[0]->name,$clrs[0]);
        }
    }
    return(@{$self->{' fillcolor'}});
}

sub strokecolor {
    my $self=shift @_;
    if(scalar @_) {
        @{$self->{' strokecolor'}}=@_;
        my @clrs=@_;
        $self->add($self->_makecolor(0,@clrs));
        if(ref($clrs[0]) eq 'PDF::API2::ColorSpace') {
            $self->resource('ColorSpace',$clrs[0]->name,$clrs[0]);
        } elsif(ref($clrs[0]) eq 'PDF::API2::Pattern') {
            $self->resource('Pattern',$clrs[0]->name,$clrs[0]);
        }
    }
    return(@{$self->{' strokecolor'}});
}

=head1 GRAPHICS METHODS

=over 4

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
        if(defined($self->{' apiistext'}) && $self->{' apiistext'} == 1) {
            $self->add_post(floats($x,$y),'m');
        } else {
            $self->add(floats($x,$y),'m');
        }
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
        if(defined($self->{' apiistext'}) && $self->{' apiistext'} == 1) {
            $self->add_post(floats($x,$y),'l');
        } else {
            $self->add(floats($x,$y),'l');
        }
    }
    return($self);
}

=item $gfx->hline $x

=cut

sub hline {
    my($self,$x)=@_;
    if(defined($self->{' apiistext'}) && $self->{' apiistext'} == 1) {
        $self->add_post(floats($x,$self->{' y'}),'l');
    } else {
        $self->add(floats($x,$self->{' y'}),'l');
    }
    $self->{' x'}=$x;
    return($self);
}

=item $gfx->vline $y

=cut

sub vline {
    my($self,$y)=@_;
    if(defined($self->{' apiistext'}) && $self->{' apiistext'} == 1) {
        $self->add_post(floats($self->{' x'},$y),'l');
    } else {
        $self->add(floats($self->{' x'},$y),'l');
    }
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
        if(defined($self->{' apiistext'}) && $self->{' apiistext'} == 1) {
            $self->add_post(floats($x1,$y1,$x2,$y2,$x3,$y3),'c');
        } else {
            $self->add(floats($x1,$y1,$x2,$y2,$x3,$y3),'c');
        }
        $self->{' x'}=$x3;
        $self->{' y'}=$y3;
    }
    return($self);
}

sub arctocurve {
    my ($a,$b,$alpha,$beta)=@_;
    if(abs($beta-$alpha) > 30) {
        return (
            arctocurve($a,$b,$alpha,($beta+$alpha)/2),
            arctocurve($a,$b,($beta+$alpha)/2,$beta)
        );
    } else {
        $alpha = ($alpha * pi / 180);
        $beta  = ($beta * pi / 180);

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

will draw an arc centered at x,y with minor/major-axis
given by a,b from alfa to beta (degrees). move must be
set to 1, unless you want to continue an existing path.

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

will draw an arc of a circle from x1,y1 to x2,y2 with radius r.
move must be set to 1, unless you want to continue an existing path.
larc can be set to 1, if you want to draw the larger instead of the
shorter arc. span can be set to 1, if you want to draw the arc
on the other side. NOTE: 2*r cannot be smaller than the distance
from x1,y1 to x2,y2.

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

=item $gfx->image $imgobj, $x,$y, $scale

=item $gfx->image $imgobj, $x,$y

B<Please Note:> The width/height or scale given
is in user-space coordinates which is subject to
transformations which may have been specified beforehand.

Per default this has a 72dpi resolution, so if you want an
image to have a 150 or 300dpi resolution, you should specify
a scale of 72/150 (or 72/300) or adjust width/height accordingly.

=cut

sub image {
    my $self=shift @_;
    my $img=shift @_;
    my ($x,$y,$w,$h)=@_;
    $self->save;
    if(!defined $w) {
        $h=$img->height;
        $w=$img->width;
    } elsif(!defined $h) {
        $h=$img->height*$w;
        $w=$img->width*$w;
    }
    $self->matrix($w,0,0,$h,$x,$y);
    $self->add("/".$img->name,'Do');
    $self->restore;
    $self->{' x'}=$x;
    $self->{' y'}=$y;
    $self->resource('XObject',$img->name,$img);
    return($self);
}

=item $gfx->formimage $imgobj, $x, $y, $scale

=item $gfx->formimage $imgobj, $x, $y

B<Please Note:> *TODO*

=cut

sub formimage {
    my $self=shift @_;
    my $img=shift @_;
    my ($x,$y,$s)=@_;
    $self->save;
    if(!defined $s) {
        $self->matrix(1,0,0,1,$x,$y);
    } else {
        $self->matrix($s,0,0,$s,$x,$y);
    }
    $self->add("/".$img->name,'Do');
    $self->restore;
    $self->resource('XObject',$img->name,$img);
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
    $self->add("/".$shade->name,'sh');

    $self->resource('Shading',$shade->name,$shade);

    $self->restore;
    return($self);
}

=item $gfx->egstate $egsobj

=cut

sub egstate {
    my $self=shift @_;
    my $egs=shift @_;
    $self->add("/".$egs->name,'gs');
    $self->resource('ExtGState',$egs->name,$egs);
    return($self);
}

=item $hyb->textstart

=cut

sub textstart {
    my ($self)=@_;
    if(!defined($self->{' apiistext'}) || $self->{' apiistext'} != 1) {
        $self->add(' BT ');
        $self->{' apiistext'}=1;
        $self->{' font'}=undef;
        $self->{' fontsize'}=0;
        $self->{' charspace'}=0;
        $self->{' hspace'}=100;
        $self->{' wordspace'}=0;
        $self->{' lead'}=0;
        $self->{' rise'}=0;
        $self->{' render'}=0;
        @{$self->{' matrix'}}=(1,0,0,1,0,0);
        @{$self->{' fillcolor'}}=(0);
        @{$self->{' strokecolor'}}=(0);
        @{$self->{' translate'}}=(0,0);
        @{$self->{' scale'}}=(1,1);
        @{$self->{' skew'}}=(0,0);
        $self->{' rotate'}=0;
    }
    return($self);
}

=item %state = $txt->textstate %state

Sets or gets the current text-object state.

=cut

sub textstate {
  my $self=shift @_;
  my %state;
  if(scalar @_) {
    %state=@_;
    foreach my $k (qw( charspace hspace wordspace lead rise render )) {
      next unless($state{$k});
      eval ' $self->'.$k.'($state{$k}); ';
    }
    if($state{font} && $state{fontsize}) {
      $self->font($state{font},$state{fontsize});
    }
    if($state{matrix}) {
      $self->matrix(@{$state{matrix}});
      @{$self->{' translate'}}=@{$state{translate}};
      $self->{' rotate'}=$state{rotate};
      @{$self->{' scale'}}=@{$state{scale}};
      @{$self->{' skew'}}=@{$state{skew}};
    }
    if($state{fillcolor}) {
      $self->fillcolor(@{$state{fillcolor}});
    }
    if($state{strokecolor}) {
      $self->strokecolor(@{$state{strokecolor}});
    }
    %state=();
  } else {
    foreach my $k (qw( font fontsize charspace hspace wordspace lead rise render )) {
      $state{$k}=$self->{" $k"};
    }
    $state{matrix}=[@{$self->{" matrix"}}];
    $state{rotate}=$self->{" rotate"};
    $state{scale}=[@{$self->{" scale"}}];
    $state{skew}=[@{$self->{" skew"}}];
    $state{translate}=[@{$self->{" translate"}}];
    $state{fillcolor}=[@{$self->{" fillcolor"}}];
    $state{strokecolor}=[@{$self->{" strokecolor"}}];
  }
  return(%state);
}

=item ($tx,$ty) = $txt->textpos

Gets the current estimated text position.

=cut

sub textpos {
  my $self=shift @_;
  my (@m)=$self->matrix;
  return($m[4],$m[5]);
}

=item $txt->transform_rel %opts

Sets transformations (eg. translate, rotate, scale, skew) in pdf-canonical order,
but relative to the previously set values.

B<Example:>

  $txt->transform_rel(
    -translate => [$x,$y],
    -rotate    => $rot,
    -scale     => [$sx,$sy],
    -skew      => [$sa,$sb],
  )

=cut

sub transform_rel {
  my ($self,%opt)=@_;
  my ($sa1,$sb1)=@{$opt{-skew} ? $opt{-skew} : [0,0]};
  my ($sa0,$sb0)=@{$self->{" skew"}};


  my ($sx1,$sy1)=@{$opt{-scale} ? $opt{-scale} : [1,1]};
  my ($sx0,$sy0)=@{$self->{" scale"}};

  my $rot1=$opt{"-rotate"} || 0;
  my $rot0=$self->{" rotate"};

  my ($tx1,$ty1)=@{$opt{-translate} ? $opt{-translate} : [0,0]};
  my ($tx0,$ty0)=@{$self->{" translate"}};

  $self->transform(
    -skew=>[$sa0+$sa1,$sb0+$sb1],
    -scale=>[$sx0*$sx1,$sy0*$sy1],
    -rotate=>$rot0+$rot1,
    -translate=>[$tx0+$tx1,$ty0+$ty1],
  );
  return($self);
}

sub matrix_update {
  use PDF::API2::Matrix;
  my ($self,$tx,$ty)=@_;
  my ($a,$b,$c,$d,$e,$f)=$self->matrix;
  my $mtx=PDF::API2::Matrix->new([$a,$b,0],[$c,$d,0],[$e,$f,1]);
  my $tmtx=PDF::API2::Matrix->new([$tx,$ty,1]);
  $tmtx=$tmtx->multiply($mtx);
  @{$self->{' matrix'}}=(
    $a,$b,
    $c,$d,
    $tmtx->[0][0],$tmtx->[0][1]
  );
  @{$self->{' translate'}}=($tmtx->[0][0],$tmtx->[0][1]);
  return($self);
}

=item $txt->font $fontobj,$size

=cut

sub font {
  my ($self,$font,$size)=@_;
  $self->{' font'}=$font;
  $self->{' fontsize'}=$size;
  $self->add("/".$font->name,float($size),'Tf');

  $self->resource('Font',$font->name,$font);

  return($self);
}

=item $spacing = $txt->charspace $spacing

=cut

sub charspace {
  my ($self,$para)=@_;
  if(defined $para) {
    $self->{' charspace'}=$para;
    $self->add(float($para,6),'Tc');
  }
  return $self->{' charspace'};
}

=item $spacing = $txt->wordspace $spacing

=cut

sub wordspace {
  my ($self,$para)=@_;
  if(defined $para) {
    $self->{' wordspace'}=$para;
    $self->add(float($para,6),'Tw');
  }
  return $self->{' wordspace'};
}

=item $spacing = $txt->hspace $spacing

=cut

sub hspace {
  my ($self,$para)=@_;
  if(defined $para) {
    $self->{' hspace'}=$para;
    $self->add(float($para,6),'Tz');
  }
  return $self->{' hspace'};
}

=item $leading = $txt->lead $leading

=cut

sub lead {
        my ($self,$para)=@_;
        if (defined ($para)) {
                $self->{' lead'} = $para;
                $self->add(float($para),'TL');
        }
        return $self->{' lead'};
}

=item $rise = $txt->rise $rise

=cut

sub rise {
        my ($self,$para)=@_;
        if (defined ($para)) {
                $self->{' rise'} = $para;
                $self->add(float($para),'Ts');
        }
        return $self->{' rise'};
}

=item $rendering = $txt->render $rendering

=cut

sub render {
  my ($self,$para)=@_;
        if (defined ($para)) {
                $self->{' render'} = $para;
    $self->add(intg($para),'Tr');
        }
        return $self->{' render'};
}

=item $txt->cr $linesize

takes an optional argument giving a custom leading between lines.

=cut

sub cr {
  my ($self,$para)=@_;
  if(defined($para)) {
    $self->add(0,float($para),'Td');
    $self->matrix_update(0,$para);
  } else {
    $self->add('T*');
    $self->matrix_update(0,$self->lead);
  }
}

=item $txt->nl

=cut

sub nl {
  my ($self,$width)=@_;
  $self->add('T*');
  $self->matrix_update(-($width||0),$self->lead);
}

=item $txt->distance $dx,$dy

=cut

sub distance {
  my ($self,$dx,$dy)=@_;
  $self->add(float($dx),float($dy),'Td');
  $self->matrix_update($dx,$dy);
}

=item $width = $txt->advancewidth $string

Returns the width of the string based on all currently set text-attributes.

=cut

sub advancewidth {
  my ($self,$text)=@_;
  my $glyph_width=$self->{' font'}->width($text,%opt)*$self->{' fontsize'};
  my @txt=split(/\x20/,$text);
  my $num_space=(scalar @txt)-1;
  my $num_char=length($text);
  my $word_spaces=$self->wordspace*$num_space;
  my $char_spaces=$self->charspace*$num_char;
  my $advance=($glyph_width+$word_spaces+$char_spaces)*$self->{' hspace'}/100;
  return $advance;
}

=item $width = $txt->text $text, %options

Applys text to the content and optionally returns the width of the given text.

=cut

sub text {
  my ($self,$text,%opt)=@_;
  my $wd=0;
  if(defined $opt{-indent}) {
    $self->add('[',(-$opt{-indent}*(1000/$self->{' fontsize'})*(100/$self->hspace)),$self->{' font'}->text($text),']','TJ');
    $wd=$self->advancewidth($text)+$opt{-indent};
  } else {
    $self->add($self->{' font'}->text($text),'Tj');
    $wd=$self->advancewidth($text);
  }

  $self->matrix_update($wd,0);
  return($wd);
}

=item $txt->text_center $text

=cut

sub text_center {
  my ($self,$text)=@_;
  my $width=$self->advancewidth($text);
  return $self->text($text,-indent=>-($width/2));
}

=item $txt->text_right $text, %options

=cut

sub text_right {
  my ($self,$text,%opt)=@_;
  my $width=$self->advancewidth($text);
  return $self->text($text,-indent=>-$width);
}

=item $width = $txt->text_justified $text, $width

** DEVELOPER METHOD **

=cut

sub text_justified {
    my ($self,$text,$width)=@_;
    my $hs=$self->hspace;
    $self->hspace($hs*($width/$self->advancewidth($text)));
    $self->text($text);
    $self->hspace($hs);
    return($width);
}

=item ($width,$chunktext) = $txt->text_fill_left $text, $width

** DEVELOPER METHOD **

=cut

sub text_fill_left {
    my ($self,$text,$width)=@_;
    my @txt=split(/\x20/,$text);
    my @line=();
    my $save=$";
    $"=' ';
    while($self->advancewidth("@line")<$width) {
        push @line,(shift @txt);
    }
    if((scalar @line > 1) && ($self->advancewidth("@line") > $width)) {
        unshift @txt,pop @line;
    }
    $width=$self->text("@line");
    my $ret="@txt";
    $"=$save;
    return($width,$ret);
}

=item ($width,$chunktext) = $txt->text_fill_right $text, $width

** DEVELOPER METHOD **

=cut

sub text_fill_right {
    my ($self,$text,$width)=@_;
    my @txt=split(/\x20/,$text);
    my @line=();
    my $save=$";
    $"=' ';
    while($self->advancewidth("@line")<$width) {
        push @line,(shift @txt);
    }
    if((scalar @line > 1) && ($self->advancewidth("@line") > $width)) {
        unshift @txt,pop @line;
    }
    $width=$self->text_right("@line");
    my $ret="@txt";
    $"=$save;
    return($width,$ret);
}

=item ($width,$chunktext) = $txt->text_fill_justified $text, $width

** DEVELOPER METHOD **

=cut

sub text_fill_justified {
    my ($self,$text,$width)=@_;
    my @txt=split(/\x20/,$text);
    my @line=();
    my $hs=$self->hspace;
    my $save=$";
    $"=' ';
    while($self->advancewidth("@line")<$width) {
        push @line,(shift @txt);
    }
    if((scalar @txt > 0) || ($self->advancewidth("@line") > $width)) {
        $self->hspace($hs*($width/$self->advancewidth("@line")));
    }
    $width=$self->text("@line");
    $self->hspace($hs);
    my $ret="@txt";
    $"=$save;
    return($width,$ret);
}

=item $txt->paragraph $text, $width

** DEVELOPER METHOD **

B<Example:>

    $txt->font($fnt,24);
    $txt->lead(-30);
    $txt->translate(100,700);
    $txt->paragraph('long paragraph here ...',400);

=cut

sub paragraph {
    my ($self,$text,$width)=@_;
    my @line=();
    my $nwidth=0;
    while(length($text)>0) {
        ($nwidth,$text)=$self->text_fill_justified($text,$width);
        $self->nl;
    }    
    
    return($self);
}

=item $hyb->textend

=cut

sub textend {
    my ($self)=@_;
    if($self->{' apiistext'} == 1) {
        $self->add(' ET ',$self->{' poststream'});
        $self->{' apiistext'}=0;
        $self->{' poststream'}='';
    }
    return($self);
}

=item $width = $txt->textlabel $x, $y, $font, $size, $text, %options

Applys text with options, but without teststart/end and optionally returns the width of the given text.

B<Example:> 

    $t = $page->gfx;
    $t->textlabel(300,700,$myfont,20,'Page Header',
        -rotate => -30,
        -color => '#FF0000',
        -hspace => 120,
        -center => 1,
    );
    
=cut

sub textlabel {
    my ($self,$x,$y,$font,$size,$text,%opts,$wht) = @_;
    my %trans_opts=( -translate => [$x,$y] );
    my %text_state=();
    $trans_opts{-rotate} = $opts{-rotate} if($opts{-rotate});

    my $wastext = $self->{' apiistext'};
    if($wastext) {
        %text_state=$self->textstate;
        $self->textend;
    }
    $self->save;
    $self->textstart;
    
    $self->transform(%trans_opts);
    
    $self->fillcolor(ref($opts{-color}) ? @{$opts{-color}} : $opts{-color}) if($opts{-color});
    $self->strokecolor(ref($opts{-strokecolor}) ? @{$opts{-strokecolor}} : $opts{-strokecolor}) if($opts{-strokecolor});

    $self->font($font,$size);

    $self->charspace($opts{-charspace})     if($opts{-charspace});
    $self->hspace($opts{-hspace})           if($opts{-hspace});
    $self->wordspace($opts{-wordspace})     if($opts{-wordspace});
    $self->render($opts{-render})           if($opts{-render});

    if($opts{-right}) {
        $wht = $self->text_right($text);
    } elsif($opts{-center}) {
        $wht = $self->text_center($text);
    } else {
        $wht = $self->text($text);
    }
    
    $self->textend;
    $self->restore;
    
    if($wastext) {
        $self->textstart;
        $self->textstate(%text_state);
    }
    return($wht);
}

sub resource {
    my ($self, $type, $key, $obj, $force) = @_;
    if($self->{' apipage'}) {
        # we are a content stream on a page.
        return( $self->{' apipage'}->resource($type, $key, $obj, $force) );
    } else {
        # we are a self-contained content stream.
        $self->{Resources}||=PDFDict();

        my $dict=$self->{Resources};
        $dict->realise if(ref($dict)=~/Objind$/);

        $dict->{$type}||= PDFDict();
        $dict->{$type}->realise if(ref($dict->{$type})=~/Objind$/);
        unless (defined $obj) {
            return($dict->{$type}->{$key} || undef);
        } else {
            if($force) {
                $dict->{$type}->{$key}=$obj;
            } else {
                $dict->{$type}->{$key}||= $obj;
            }
            return($dict);
        }
    }
}

1;

__END__

=head1 AUTHOR

alfred reibenschuh

=head1 HISTORY

    $Log: Content.pm,v $
    Revision 1.15  2004/08/31 13:50:09  fredo
    fixed space vs. whitespace split bug

    Revision 1.14  2004/07/29 10:46:37  fredo
    added new text_fill_* methods and a simple paragraph

    Revision 1.13  2004/06/21 22:33:36  fredo
    added basic pattern/shading handling

    Revision 1.12  2004/06/15 09:11:37  fredo
    removed cr+lf

    Revision 1.11  2004/06/07 19:44:12  fredo
    cleaned out cr+lf for lf

    Revision 1.10  2004/05/31 23:20:48  fredo
    added basic platform encoding independency

    Revision 1.9  2004/04/07 10:49:26  fredo
    fixed handling of colorSpaces for fill/strokecolor

    Revision 1.8  2004/02/12 14:46:44  fredo
    removed duplicate definition of egstate method

    Revision 1.7  2004/02/06 02:01:25  fredo
    added save/restore around textlabel

    Revision 1.6  2004/02/05 23:24:00  fredo
    fixed lab behavior

    Revision 1.5  2004/02/05 12:26:08  fredo
    revised '_makecolor' to use Lab for hsv/hsl,
    added textlabel method

    Revision 1.4  2003/12/08 13:05:19  Administrator
    corrected to proper licencing statement

    Revision 1.3  2003/11/30 17:09:18  Administrator
    merged into default

    Revision 1.2.2.1  2003/11/30 16:56:21  Administrator
    merged into default

    Revision 1.2  2003/11/30 11:33:59  Administrator
    added CVS id/log


=cut
