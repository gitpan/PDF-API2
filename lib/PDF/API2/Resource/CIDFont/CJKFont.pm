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
#   $Id: CJKFont.pm,v 1.10 2004/11/22 02:04:27 fredo Exp $
#
#=======================================================================
package PDF::API2::Resource::CIDFont::CJKFont;

BEGIN {

    use utf8;
    use Encode qw(:all);

    use PDF::API2::Util;
    use PDF::API2::Basic::PDF::Utils;
    use PDF::API2::Resource::CIDFont;
    use PDF::API2::IOString;

    use PDF::API2::Basic::TTF::Font;

    use POSIX;

    use vars qw( @ISA $fonts $cmap $alias $subs $VERSION );

    @ISA = qw( PDF::API2::Resource::CIDFont );

    ( $VERSION ) = '$Revision: 1.10 $' =~ /Revision: (\S+)\s/; # $Date: 2004/11/22 02:04:27 $

    $fonts = { };
    $cmap = { };
}

=item $font = PDF::API2::Resource::CIDFont::CJKFont->new $pdf, $cjkname, %options

Returns a cjk-font object.

Defined Options:

    -encode ... specify fonts encoding for non-utf8 text.

=cut

sub _look_for_font ($) {
    my $fname=lc(shift);
    $fname=~s/[^a-z0-9]+//gi;
    $fname=$alias->{$fname} if(defined $alias->{$fname});
    return({%{$fonts->{$fname}}}) if(defined $fonts->{$fname});

    if(defined $subs->{$fname}) {
        $data=_look_for_font($subs->{$fname}->{-alias});
        foreach my $k (keys %{$subs->{$fname}}) {
          next if($k=~/^\-/);
          $data->{$k}=$subs->{$fname}->{$k};
        }
        $fonts->{$fname}=$data;
        return({%{$data}})
    }

    eval "require PDF::API2::Resource::CIDFont::CJKFont::$fname; ";
    unless($@){
        return({%{$fonts->{$fname}}});
    } else {
        die "requested font '$fname' not installed ";
    }
}

sub _look_for_cmap ($) {
    my $fname=lc(shift);
    $fname=~s/[^a-z0-9]+//gi;
    return({%{$cmap->{$fname}}}) if(defined $cmap->{$fname});
    eval "require PDF::API2::Resource::CIDFont::CMap::$fname; ";
    unless($@){
        return({%{$cmap->{$fname}}});
    } else {
        die "requested cmap '$fname' not installed ";
    }
}
sub new {
    my ($class,$pdf,$name,@opts) = @_;
    my %opts=();
    %opts=@opts if((scalar @opts)%2 == 0);
    $opts{-encode}||='ident';
    
    my $data = _look_for_font($name);

    my $cmap = _look_for_cmap($data->{cmap});

    $data->{u2g} = { %{$cmap->{u2g}} };
    $data->{g2u} = [ @{$cmap->{g2u}} ];

    $class = ref $class if ref $class;
    my $self=$class->SUPER::new($pdf,$data->{apiname}.pdfkey());
    $pdf->new_obj($self) if(defined($pdf) && !$self->is_obj($pdf));

    $self->{' data'}=$data;

    my $des=$self->descrByData;

    my $de=$self->{' de'};

    if(defined $opts{-encode} && $opts{-encode} ne 'ident') {
        $self->data->{encode}=$opts{-encode};
    }

    my $emap={
        'reg'=>'Adobe',
        'ord'=>'Identity',
        'sup'=> 0,
        'map'=>'Identity',
        'dir'=>'H',
        'dec'=>'ident',
    };
    
    if(defined $cmap->{ccs}) {
        $emap->{reg}=$cmap->{ccs}->[0];
        $emap->{ord}=$cmap->{ccs}->[1];
        $emap->{sup}=$cmap->{ccs}->[2];
    }

    #if(defined $cmap->{cmap} && defined $cmap->{cmap}->{$opts{-encode}} ) {
    #    $emap->{dec}=$cmap->{cmap}->{$opts{-encode}}->[0];
    #    $emap->{map}=$cmap->{cmap}->{$opts{-encode}}->[1];
    #} elsif(defined $cmap->{cmap} && defined $cmap->{cmap}->{'utf8'} ) {
    #    $emap->{dec}=$cmap->{cmap}->{'utf8'}->[0];
    #    $emap->{map}=$cmap->{cmap}->{'utf8'}->[1];
    #}

    $self->data->{decode}=$emap->{dec};

    $self->{'BaseFont'} = PDFName($self->fontname."-$emap->{map}-$emap->{dir}");
    $self->{'Encoding'} = PDFName("$emap->{map}-$emap->{dir}");

    $de->{'FontDescriptor'} = $des;
    $de->{'Subtype'} = PDFName('CIDFontType0');
    $de->{'BaseFont'} = PDFName($self->fontname);
    $de->{'DW'} = PDFNum($self->missingwidth);
    $de->{'CIDSystemInfo'}->{Registry} = PDFStr($emap->{reg});
    $de->{'CIDSystemInfo'}->{Ordering} = PDFStr($emap->{ord});
    $de->{'CIDSystemInfo'}->{Supplement} = PDFNum($emap->{sup});
    ## $de->{'CIDToGIDMap'} = PDFName($emap->{map}); # ttf only

    return($self);
}

=item $font = PDF::API2::Resource::CIDFont::CJKFont->new_api $api, $cjkname, %options

Returns a cjk-font object. This method is different from 'new' that
it needs an PDF::API2-object rather than a Text::PDF::File-object.

=cut

sub new_api {
    my ($class,$api,@opts)=@_;

    my $obj=$class->new($api->{pdf},@opts);
    $self->{' api'}=$api;

    $api->{pdf}->out_obj($api->{pages});
    return($obj);
}

sub tounicodemap {
    my $self=shift @_;
    # noop since pdf knows its char-collection
    return($self);
}


sub cidsByStr {
    my ($self,$s)=@_;
    my $out='';
    if(defined $self->data->{encode}) {
        foreach my $ch ( unpack('U*',decode($self->data->{encode},$s)) )
        {   
            my $cid=$self->cidByUni($ch);
            $out.=pack('n*', $cid );
        }
    } else {
        $out=pack('n*',map { $self->cidByUni($_) } unpack('U*',$s));
    }
    return($out);
}


sub width {
    my ($self,$text)=@_;
    my $width=0;
    if(is_utf8($text)) {
        foreach my $n (unpack('U*',$text)) {
            $width+=$self->wxByUni($n);
        }
    } else {
        return $self->width_cid($self->cidsByStr($text));
    }
    $width/=1000;
    return($width);
}


sub text_cid {
    my ($self,$text)=@_;
    my $newtext='';
    foreach my $g (unpack('n*',$text)) {
        $newtext.=substr(sprintf('%04X',$g),0,4);
    }
    return("<$newtext>");
}


sub textByStr {
    my ($self,$text)=@_;
    my $newtext='';
    if(is_utf8($text) && $self->data->{decode} ne 'ident') {
        $newtext=unpack('H*',encode($self->data->{decode},$text));
    } elsif(is_utf8($text) && $self->data->{decode} eq 'ident') {
        $newtext=unpack('H*',$self->cidsByUtf($text));
    } elsif(defined $self->data->{encode} && $self->data->{decode} eq 'ident') {
        $newtext=unpack('H*',$self->cidsByUtf(encode($self->data->{encode},$text)));
    } else {
        $newtext=unpack('H*',$text);
    }
    return("<$newtext>");
}

sub glyphByCId
{ 
    my ($self,$cid)=@_;
    my $uni = $self->uniByCId($cid);
    return( nameByUni($uni) ); 
}

sub outobjdeep {
    my ($self, $fh, $pdf, %opts) = @_;

    return $self->SUPER::outobjdeep($fh, $pdf) if defined $opts{'passthru'};

    my $notdefbefore=1;

    my $wx=PDFArray();
    $self->{' de'}->{'W'} = $wx;
    my $ml;

    foreach my $w (0..(scalar @{$self->data->{g2u}} - 1 )) {
        if(ref($self->data->{wx}) eq 'ARRAY' 
            && (defined $self->data->{wx}->[$w])
            && ($self->data->{wx}->[$w] != $self->missingwidth)
            && $notdefbefore==1) 
        {
            $notdefbefore=0;
            $ml=PDFArray();
            $wx->add_elements(PDFNum($w),$ml);
            $ml->add_elements(PDFNum($self->data->{wx}->[$w]));
        } 
        elsif(ref($self->data->{wx}) eq 'HASH' 
            && (defined $self->data->{wx}->{$w}) 
            && ($self->data->{wx}->{$w} != $self->missingwidth)
            && $notdefbefore==1) 
        {
            $notdefbefore=0;
            $ml=PDFArray();
            $wx->add_elements(PDFNum($w),$ml);
            $ml->add_elements(PDFNum($self->data->{wx}->{$w}));
        } 
        elsif(ref($self->data->{wx}) eq 'ARRAY' 
            && (defined $self->data->{wx}->[$w]) 
            && ($self->data->{wx}->[$w] != $self->missingwidth)
            && $notdefbefore==0) 
        {
            $notdefbefore=0;
            $ml->add_elements(PDFNum($self->data->{wx}->[$w]));
        } 
        elsif(ref($self->data->{wx}) eq 'HASH' 
            && (defined $self->data->{wx}->{$w}) 
            && ($self->data->{wx}->{$w} != $self->missingwidth)
            && $notdefbefore==0) 
        {
            $notdefbefore=0;
            $ml->add_elements(PDFNum($self->data->{wx}->{$w}));
        } 
        else 
        {
            $notdefbefore=1;
        }
    }

    $self->SUPER::outobjdeep($fh, $pdf, %opts);
}

BEGIN {

    $alias={
        'traditional'           => 'adobemingstdlightacro',
        'ming'                  => 'adobemingstdlightacro',
        
        'simplified'            => 'adobesongstdlightacro',
        'song'                  => 'adobesongstdlightacro',

        'korean'                => 'adobemyungjostdmediumacro',
        'myungjostdmedium'      => 'adobemyungjostdmediumacro',
        'hysmyeongjomedium'     => 'adobemyungjostdmediumacro',

        'japanese'              => 'kozgopromediumacro',
        'kozgopromedium'        => 'kozgopromediumacro',
        'gothicbbbmedium'       => 'kozgopromediumacro',
        'heiseikakugow5'        => 'kozgopromediumacro',

        'japanese2'             => 'kozminproregularacro',
        'kozminproregular'      => 'kozminproregularacro',
        'ryuminlight'           => 'kozminproregularacro',
        'heiseiminw3'           => 'kozminproregularacro',
    };
    $subs={
        'minchow3' => {
            '-alias'            => 'kozminproregularacro',
            'fontname'          => 'SerifMincho-W3', 
            'fontfamily'        => 'SerifMincho',
            'fontstretch'       => 'Normal',
            'fontweight'        => '300',
            'altname'           => 'SerifMinchoW3',
            'subname'           => 'Regular',
            'cmap'              => 'japanese',
            'encode'            => 'euc-jp',
            'panose'            => "\x01\x05\x02\x0b\x04\x00\x00\x00\x00\x00\x00\x00",
        },
        'minchow5' => {
            '-alias'            => 'kozminproregularacro',
            'fontname'          => 'SerifMincho-W5', 
            'fontfamily'        => 'SerifMincho',
            'fontstretch'       => 'Normal',
            'fontweight'        => '500',
            'altname'           => 'SerifMinchoW5',
            'subname'           => 'Regular',
            'cmap'              => 'japanese',
            'encode'            => 'euc-jp',
            'panose'            => "\x01\x05\x02\x0b\x06\x00\x00\x00\x00\x00\x00\x00",
        },
        'minchow7' => {
            '-alias'            => 'kozminproregularacro',
            'fontname'          => 'SerifMincho-W7', 
            'fontfamily'        => 'SerifMincho',
            'fontstretch'       => 'Normal',
            'fontweight'        => '700',
            'altname'           => 'SerifMinchoW7',
            'subname'           => 'Regular',
            'cmap'              => 'japanese',
            'encode'            => 'euc-jp',
            'panose'            => "\x01\x05\x02\x0b\x08\x00\x00\x00\x00\x00\x00\x00",
        },
        'minchow9' => {
            '-alias'            => 'kozminproregularacro',
            'fontname'          => 'SerifMincho-W9', 
            'fontfamily'        => 'SerifMincho',
            'fontstretch'       => 'Normal',
            'fontweight'        => '900',
            'altname'           => 'SerifMinchoW9',
            'subname'           => 'Regular',
            'cmap'              => 'japanese',
            'encode'            => 'euc-jp',
            'panose'            => "\x01\x05\x02\x0b\x0a\x00\x00\x00\x00\x00\x00\x00",
        },
        'gothicw3' => {
            '-alias'            => 'kozgopromediumacro',
            'fontname'          => 'SansGothic-W3', 
            'fontfamily'        => 'SansGothic',
            'fontstretch'       => 'Normal',
            'fontweight'        => '300',
            'altname'           => 'SansGothicW3',
            'subname'           => 'Regular',
            'cmap'              => 'japanese',
            'encode'            => 'euc-jp',
            'panose'            => "\x08\x01\x02\x0b\x03\x00\x00\x00\x00\x00\x00\x00",
        },
        'gothicw5' => {
            '-alias'            => 'kozgopromediumacro',
            'fontname'          => 'SansGothic-W5', 
            'fontfamily'        => 'SansGothic',
            'fontstretch'       => 'Normal',
            'fontweight'        => '500',
            'altname'           => 'SansGothicW5',
            'subname'           => 'Regular',
            'cmap'              => 'japanese',
            'encode'            => 'euc-jp',
            'panose'            => "\x08\x01\x02\x0b\x05\x00\x00\x00\x00\x00\x00\x00",
        },
        'gothicw7' => {
            '-alias'            => 'kozgopromediumacro',
            'fontname'          => 'SansGothic-W7', 
            'fontfamily'        => 'SansGothic',
            'fontstretch'       => 'Normal',
            'fontweight'        => '700',
            'altname'           => 'SansGothicW7',
            'subname'           => 'Regular',
            'cmap'              => 'japanese',
            'encode'            => 'euc-jp',
            'panose'            => "\x08\x01\x02\x0b\x07\x00\x00\x00\x00\x00\x00\x00",
        },
        'gothicw9' => {
            '-alias'            => 'kozgopromediumacro',
            'fontname'          => 'SansGothic-W9', 
            'fontfamily'        => 'SansGothic',
            'fontstretch'       => 'Normal',
            'fontweight'        => '900',
            'altname'           => 'SansGothicW9',
            'subname'           => 'Regular',
            'cmap'              => 'japanese',
            'encode'            => 'euc-jp',
            'panose'            => "\x08\x01\x02\x0b\x09\x00\x00\x00\x00\x00\x00\x00",
        },
    };

}
1;

__END__

=head1 AUTHOR

alfred reibenschuh

=head1 HISTORY

    $Log: CJKFont.pm,v $
    Revision 1.10  2004/11/22 02:04:27  fredo
    added missing substitutes

    Revision 1.9  2004/11/22 01:03:24  fredo
    fixed supplement set, added substitute handling

    Revision 1.8  2004/11/21 02:58:51  fredo
    fixed multibyte encoding issues

    Revision 1.7  2004/10/26 14:43:25  fredo
    added alternative glyph-width storage/retrieval

    Revision 1.6  2004/06/15 09:14:42  fredo
    removed cr+lf

    Revision 1.5  2004/06/07 19:44:36  fredo
    cleaned out cr+lf for lf

    Revision 1.4  2004/02/24 00:08:54  fredo
    added utf8 fallback for encoding

    Revision 1.3  2003/12/08 13:05:33  Administrator
    corrected to proper licencing statement

    Revision 1.2  2003/11/30 17:30:40  Administrator
    merged into default

    Revision 1.1.1.1.2.2  2003/11/30 16:56:36  Administrator
    merged into default

    Revision 1.1.1.1.2.1  2003/11/30 14:13:33  Administrator
    added CVS id/log


=cut



            ------- Chinese -------
    Traditional                 Simplified                  Japanese                Korean
Acrobat 6:
    AdobeMingStd-Light-Acro     AdobeSongStd-Light-Acro     KozGoPro-Medium-Acro    AdobeMyungjoStd-Medium-Acro
                                                            KozMinPro-Regular-Acro
Acrobat 5:
    MSungStd-Light-Acro         STSongStd-Light-Acro        KozMinPro-Regular-Acro  HYSMyeongJoStd-Medium-Acro
Acrobat 4:
    MSung-Light                 STSong-Light                HeiseiKakuGo-W5         HYSMyeongJo-Medium
    MHei-Medium                                             HeiseiMin-W3            HYGoThic-Medium