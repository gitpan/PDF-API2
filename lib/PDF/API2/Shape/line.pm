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
#   $Id: line.pm,v 1.2 2004/02/12 20:20:52 fredo Exp $
#
#=======================================================================

package PDF::API2::Shape::line;

BEGIN {
    use vars qw($VERSION @ISA);
    ( $VERSION ) = '$Revision: 1.2 $' =~ /Revision: (\S+)\s/; # $Date: 2004/02/12 20:20:52 $
    
    use PDF::API2::Shape;
    @ISA = qw(PDF::API2::Shape);
    use PDF::API2::Util;
    use POSIX;
    use Math::Trig;
    use List::Util qw(max min);
}

=head1 NAME

PDF::API2::Shape::line - class for line shapes.

=cut

=item $shape = PDF::API2::Shape::line->new

Returns a shape.

=cut

sub new {
    my ($class,$x1,$y1,$x2,$y2,%opts) = @_;
    $class = ref $class if(ref $class);
    my $self=$class->SUPER::new(%opts);
    $self->{-p}=[$x1,$y1,$x2,$y2];
    return($self);
}

sub render {
    my ($self) = @_;
    my @out;
    push @out, $self->_save if($self->{-saverestore});
    push @out, $self->_flatness($self->{-flatness}) if(defined $self->{-flatness});
    push @out, $self->_linecap($self->{-linecap}) if(defined $self->{-linecap});
    push @out, $self->_linedash(@{$self->{-linedash}}) if(defined $self->{-linedash});
    push @out, $self->_linejoin($self->{-linejoin}) if(defined $self->{-linejoin});
    push @out, $self->_linewidth($self->{-linewidth}) if(defined $self->{-linewidth});
    push @out, $self->_meterlimit($self->{-meterlimit}) if(defined $self->{-meterlimit});
    push @out, $self->_strokecolor(@{$self->{-strokecolor}}) if(defined $self->{-strokecolor});
    my ($x1,$y1,$x2,$y2)=@{$self->{-p}};
    push @out, $self->_move($x1,$y1);
    push @out, $self->_line($x2,$y2);
    push @out, $self->_stroke;
    push @out, $self->_restore if($self->{-saverestore});
    $self->{-stream}=join(' ', @out);
    return($self->SUPER::render);
}

1;

__END__

=head1 AUTHOR

alfred reibenschuh

=head1 HISTORY

    $Log: line.pm,v $
    Revision 1.2  2004/02/12 20:20:52  fredo
    updated new method for options

    Revision 1.1  2004/02/12 20:10:44  fredo
    initial import



=cut