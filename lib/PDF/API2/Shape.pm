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
#   $Id: Shape.pm,v 1.3 2004/02/12 20:20:28 fredo Exp $
#
#=======================================================================

package PDF::API2::Shape;

BEGIN {
    use vars qw($VERSION);
    ( $VERSION ) = '$Revision: 1.3 $' =~ /Revision: (\S+)\s/; # $Date: 2004/02/12 20:20:28 $

    use PDF::API2::Util;
    use POSIX;
    use Math::Trig;
    use List::Util qw(max min);
}

=head1 NAME

PDF::API2::Shape - base class for shapes in pdf content-streams.

=cut

=item $shape = PDF::API2::Shape->new

Returns a shape object.

=cut

sub new {
    my ($class,%opts) = @_;
    my $self={ %opts };

    $class = ref $class if(ref $class);

    bless($self, $class);

    return($self);
}

sub updatestats {
    my ($self) = @_;

    die "Base Class must be subclassed and method overridden to properly update stats.";

    return($self);
}

sub basexy {
    my $self = shift @_;

    $self->{-bxy}||=[];
    
    if(scalar @_ == 2) {
        my ($x,$y) = @{$self->{-bxy}};
        $x = min($_[0],$x);
        $y = min($_[0],$y);
        @{$self->{-bxy}} = ($x,$y);
    }

    return(@{$self->{-bxy}});
}

sub maxxy {
    my $self = shift @_;

    $self->{-mxy}||=[];
    
    if(scalar @_ == 2) {
        my ($x,$y) = @{$self->{-mxy}};
        $x = max($_[0],$x);
        $y = max($_[0],$y);
        @{$self->{-mxy}} = ($x,$y);
    }

    return(@{$self->{-mxy}});
}

sub width {
    my $self = shift @_;

    if(scalar @_ == 1) {
        $self->{-w}=$_[0];
    }

    return($self->{-w});
}

sub height {
    my $self = shift @_;

    if(scalar @_ == 1) {
        $self->{-h}=$_[0];
    }

    return($self->{-h});
}

sub renderfh {
    my ($self, $fh) = @_;

    eval {
        print $fh $self->render;
    };
    die $@ if($@);
    
    return($self);
}

sub render {
    my ($self) = @_;

    die "Base Class must be subclassed and method overridden to properly prepare stream." unless(defined $self->{-stream});

    return($self->{-stream});
}

sub release {
    my ($self) = @_;

    foreach my $key (keys %{$self}) {
        $self->{$key}=undef;
        delete($self->{$key});
    }
    
    %{$self}=();
    $self=undef;
    
    return(undef);
}


sub _save { return('q'); }

sub _restore { return('Q'); }

sub _flatness {
    my ($self,$flatness)=@_;
    return($flatness,'i');
}

sub _linecap {
    my ($self,$linecap)=@_;
    return($linecap,'J');
}

sub _linedash {
    my ($self,@a)=@_;
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

sub _linejoin {
    my ($self,$linejoin)=@_;
    return($linejoin,'j');
}

sub _linewidth {
    my ($self,$linewidth)=@_;
    return($linewidth,'w');
}

sub _meterlimit {
    my ($self,$limit)=@_;
    return($limit,'M');
}

sub _matrix_text {
    my ($self,$a,$b,$c,$d,$e,$f)=@_;
    return(floats($a,$b,$c,$d,$e,$f),'Tm');
}

sub _matrix_gfx {
    my ($self,$a,$b,$c,$d,$e,$f)=@_;
    return(floats($a,$b,$c,$d,$e,$f),'cm');
}

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
    } elsif((scalar @clr == 1) && ref($clr[0])) {
        # pattern or shading space
    } elsif(scalar @clr == 1) {
        # grey color spec.
        while($clr[0]>1) { $clr[0]/=255; }
        # adjusted for 8/16/32bit spec.
        return($clr[0],($sf?'g':'G'));
    } elsif(scalar @clr > 1 && ref($clr[0])) {
        # indexed colorspace plus color-index
        # or custom colorspace plus param
    } elsif(scalar @clr == 2) {
        # indexed colorspace plus color-index
        # or custom colorspace plus param
    } elsif(scalar @clr == 3) {
        # legacy rgb color-spec (0 <= x <= 1)
        return(floats($clr[0],$clr[1],$clr[2]),($sf?'rg':'RG'));
    } elsif(scalar @clr == 4) {
        # legacy cmyk color-spec (0 <= x <= 1)
        return(floats($clr[0],$clr[1],$clr[2],$clr[3]),($sf?'k':'K'));
    }
    die 'invalid color specification.';
}

sub _fillcolor {
    my $self=shift @_;
    if(ref $self) {
        if(scalar @_) {
            @{$self->{-fillcolor}}=$self->_makecolor(1,@_);
        }
        return(@{$self->{-fillcolor}});
    } else {
        return($self->_makecolor(1,@_));
    }
}

sub _strokecolor {
    my $self=shift @_;
    if(ref $self) {
        if(scalar @_) {
            @{$self->{-strokecolor}}=$self->_makecolor(0,@_);
        }
        return(@{$self->{-strokecolor}});
    } else {
        return($self->_makecolor(0,@_));
    }
}

sub _move { # x,y ...
    my ($self,$x,$y) = @_;
    $self->maxxy($x,$y);
    $self->basexy($x,$y);
    return(floats($x,$y),'m');
}

sub _line { # x,y ...
    my $self=shift @_;
    my($x,$y,@out);
    while(defined($x=shift @_)) {
        $y=shift @_;
        $self->maxxy($x,$y);
        $self->basexy($x,$y);
        push(@out,floats($x,$y),'l');
    }
    return(@out);
}

sub _curve { # x1,y1,x2,y2,x3,y3 ...
    my $self=shift @_;
    my($x1,$y1,$x2,$y2,$x3,$y3,@out);
    while(defined($x1=shift @_)) {
        $y1=shift @_;
        $self->maxxy($x1,$y1);
        $self->basexy($x1,$y1);
        $x2=shift @_;
        $y2=shift @_;
        $self->maxxy($x2,$y2);
        $self->basexy($x2,$y2);
        $x3=shift @_;
        $y3=shift @_;
        $self->maxxy($x3,$y3);
        $self->basexy($x3,$y3);
        push(@out,floats($x1,$y1,$x2,$y2,$x3,$y3),'c');
    }
    return(@out);
}

sub _arctocurve {
    my ($a,$b,$alpha,$beta)=@_;
    if(abs($beta-$alpha) > 30) {
        return (
            _arctocurve($a,$b,$alpha,($beta+$alpha)/2),
            _arctocurve($a,$b,($beta+$alpha)/2,$beta)
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

sub _arc { # x,y,a,b,alf,bet[,mov]
    my ($self,$x,$y,$a,$b,$alpha,$beta,$move)=@_;
    my @points=_arctocurve($a,$b,$alpha,$beta);
    my ($p0_x,$p0_y,$p1_x,$p1_y,$p2_x,$p2_y,$p3_x,$p3_y,@out);

    $p0_x= $x + shift @points;
    $p0_y= $y + shift @points;

    push(@out, $self->_move($p0_x,$p0_y)) if($move);

    while(scalar @points > 0) {
        $p1_x= $x + shift @points;
        $p1_y= $y + shift @points;
        $p2_x= $x + shift @points;
        $p2_y= $y + shift @points;
        $p3_x= $x + shift @points;
        $p3_y= $y + shift @points;
        push(@out, $self->_curve($p1_x,$p1_y,$p2_x,$p2_y,$p3_x,$p3_y));
    }
    return(@out);
}

sub _ellipse {
    my ($self,$x,$y,$a,$b) = @_;
    my @out;
    push(@out, $self->_arc($x,$y,$a,$b,0,360,1));
    push(@out, $self->_close);
    return(@out);
}

sub _circle {
    my ($self,$x,$y,$r) = @_;
    my @out;
    push(@out, $self->_arc($x,$y,$r,$r,0,360,1));
    push(@out, $self->_close);
    return(@out);
}

sub _pie {
    my $self=shift @_;
    my ($x,$y,$a,$b,$alfa,$beta)=@_;
    my @out;
    my ($p0_x,$p0_y)=_arctocurve($a,$b,$alfa,$beta);
    push(@out, $self->_move($x,$y));
    push(@out, $self->_line($p0_x+$x,$p0_y+$y));
    push(@out, $self->_arc($x,$y,$a,$b,$alfa,$beta));
    push(@out, $self->_close);
    return(@out);
}

sub _rect { # x,y,w,h ...
    my $self=shift @_;
    my($x,$y,$w,$h,@out);
    while(defined($x=shift @_)) {
        $y=shift @_;
        $w=shift @_;
        $h=shift @_;
        push(@out, floats($x,$y,$w,$h),'re');
    }
    return(@out);
}

sub _rectxy {
    my ($self,$x,$y,$x2,$y2)=@_;
    return($self->rect($x,$y,($x2-$x),($y2-$y)));
}

sub _poly {
    my $self=shift @_;
    my($x,$y,@out);
    $x=shift @_;
    $y=shift @_;
    push(@out, $self->_move($x,$y));
    push(@out, $self->_line(@_));
    return(@out);
}

sub _close { return('h'); }

sub _endpath { return('n'); }

sub _clip { # nonzero
    my $self=shift @_;
    return(!(shift @_)?'W':'W*');
}

sub _stroke { return('S'); }

sub _fill { # nonzero
    my $self=shift @_;
    return(!(shift @_)?'f':'f*');
}

sub _fillstroke { # nonzero
    my $self=shift @_;
    return(!(shift @_)?'B':'B*');
}


1;

__END__

=head1 AUTHOR

alfred reibenschuh

=head1 HISTORY

    $Log: Shape.pm,v $
    Revision 1.3  2004/02/12 20:20:28  fredo
    updated new method for options

    Revision 1.2  2004/02/12 16:55:05  fredo
    added release method,
    fixed render methods

    Revision 1.1  2004/02/12 16:40:44  fredo
    initial import


=cut