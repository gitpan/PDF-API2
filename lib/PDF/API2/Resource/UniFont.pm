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
#   $Id: UniFont.pm,v 1.1 2004/11/24 20:11:31 fredo Exp $
#
#=======================================================================
package PDF::API2::Resource::UniFont;

BEGIN {

    use utf8;
    use Encode qw(:all);

    use PDF::API2::Util;

    use POSIX;

    use vars qw($VERSION);

    ( $VERSION ) = '$Revision: 1.1 $' =~ /Revision: (\S+)\s/; # $Date: 2004/11/24 20:11:31 $

}

=item $font = PDF::API2::Resource::UniFont->new $pdf, @fontarray

Returns a uni-font object.

=cut

sub new {
    my ($class,$pdf,@fonts) = @_;

    $class = ref $class if ref $class;
    my $self={
        fonts=>[],
        block=>{},
        code=>{},
    };
    bless $self,$class;

    $self->{pdf}=$pdf;
    
    # look at all fonts
    my $fn=0;
    foreach my $font (@fonts)
    {
        if(ref($font) eq 'ARRAY')
        {
            push @{$self->{fonts}},$font->[0];
            shift @{$font};
            while(defined $font->[0])
            {
                my $r0=shift @{$font};
                if(ref $r0)
                {
                    foreach my $b ($r0->[0]..$r0->[-1])
                    {
                        $self->{block}->{$b}=$fn;
                    }
                }
                else
                {
                    my $r1=shift @{$font};
                    foreach my $c ($r0..$r1)
                    {
                        $self->{code}->{$c}=$fn;
                    }
                }
            }
        }
        else
        {
            push @{$self->{fonts}},$font;
            foreach my $b (0..255)
            {
                $self->{block}->{$b}=$fn;
            }
        }
        $fn++;
    }
    
    return($self);
}

=item $font = PDF::API2::Resource::UniFont->new_api $api, $name, %options

Returns a uni-font object. This method is different from 'new' that
it needs an PDF::API2-object rather than a Text::PDF::File-object.

=cut

sub new_api {
    my ($class,$api,@opts)=@_;

    my $obj=$class->new($api->{pdf},@opts);
    $obj->{api}=$api;

    return($obj);
}

sub isvirtual { return(1); }

sub fontlist
{
    my ($self)=@_;
    return [@{$self->{fonts}}];
}

sub width {
    my ($self,$text)=@_;
    die 'text not in utf8 format' unless(is_utf8($text));
    my $width=0;
    foreach my $u (unpack('U*',$text))
    {
        if(defined $self->{code}->{$u})
        {
            $width+=$self->fontlist->[$self->{code}->{$u}]->width(pack('U',$u));
        }
        elsif(defined $self->{block}->{($u>>8)})
        {
            $width+=$self->fontlist->[$self->{block}->{($u>>8)}]->width(pack('U',$u));
        }
        else
        {
            $width+=$self->fontlist->[0]->width(pack('U',$u));
        }
    }
    return($width);
}

sub text 
{ 
    my ($self,$text,$size)=@_;
    die 'text not in utf8 format' unless(is_utf8($text));
    die 'textsize not specified' unless(defined $size);
    my $newtext='';
    my $lastfont=-1;
    my @codes=();
    
    foreach my $u (unpack('U*',$text))
    {
        my $thisfont=0;
        if(defined $self->{code}->{$u})
        {
            $thisfont=$self->{code}->{$u};
        }
        elsif(defined $self->{block}->{($u>>8)})
        {
            $thisfont=$self->{block}->{($u>>8)};
        }
        
        if($thisfont!=$lastfont && $lastfont!=-1)
        {
            my $f=$self->fontlist->[$lastfont];
            $newtext.='/'.$f->name.' '.$size.' Tf '.$f->text(pack('U*',@codes)).' Tj ';
            @codes=();
        }
        
        push(@codes,$u);
        $lastfont=$thisfont;
    }

    if(scalar @codes > 0)
    {
        my $f=$self->fontlist->[$lastfont];
        $newtext.='/'.$f->name.' '.$size.' Tf '.$f->text(pack('U*',@codes)).' Tj ';
    }

    return($newtext);
}

1;

__END__