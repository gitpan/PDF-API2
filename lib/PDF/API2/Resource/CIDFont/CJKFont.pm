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
#   $Id: CJKFont.pm,v 1.3 2003/12/08 13:05:33 Administrator Exp $
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

    use vars qw( @ISA $fonts $cmap $alias $VERSION );

    @ISA = qw( PDF::API2::Resource::CIDFont );

    ( $VERSION ) = '$Revision: 1.3 $' =~ /Revision: (\S+)\s/; # $Date: 2003/12/08 13:05:33 $

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
    return(%{$fonts->{$fname}}) if(defined $fonts->{$fname});
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
    return(%{$cmap->{$fname}}) if(defined $cmap->{$fname});
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

    my $data = _look_for_font($name);

    my $cmap = _look_for_cmap($data->{cmap});

    $data->{u2g} = { %{$cmap->{u2g}} };
    $data->{g2u} = [ @{$cmap->{g2u}} ];

    $class = ref $class if ref $class;
    my $self=$class->SUPER::new($pdf,$data->{apiname}.pdfkey());
    $pdf->new_obj($self) if(defined($pdf) && !$self->is_obj($pdf));

    $self->{' data'}=$data;

    my $des=$self->descrByData;

    $self->{'BaseFont'} = PDFName($self->fontname.'-Identity-H');

    my $de=$self->{' de'};

    $de->{'FontDescriptor'} = $des;
    $de->{'Subtype'} = PDFName('CIDFontType0');
    $de->{'BaseFont'} = PDFName($self->fontname);
    $de->{'DW'} = PDFNum($self->missingwidth);

    if(defined $opts{-encode}) {
        $self->data->{encode}=$opts{-encode};
    }

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

sub text_cid {
    my ($self,$text)=@_;
    my $newtext='';
    foreach my $g (unpack('n*',$text)) {
        $newtext.=sprintf('%04X',$g);
    }
    return("<$newtext>");
}

sub cidsByStr {
    my ($self,$s)=@_;
    $s=pack('n*',map { $self->cidByUni($_) } unpack('U*',decode($self->data->{encode},$s)));
    return($s);
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


sub outobjdeep {
    my ($self, $fh, $pdf, %opts) = @_;

    return $self->SUPER::outobjdeep($fh, $pdf) if defined $opts{'passthru'};

    my $notdefbefore=1;

    my $wx=PDFArray();
    $self->{' de'}->{'W'} = $wx;
    my $ml;

    foreach my $w (0..(scalar @{$self->data->{g2u}} - 1 )) {
        if((defined $self->data->{wx}->[$w]) && $notdefbefore==1) {
            $notdefbefore=0;
            $ml=PDFArray();
            $wx->add_elements(PDFNum($w),$ml);
            $ml->add_elements(PDFNum($self->data->{wx}->[$w]));
        } elsif((defined $self->data->{wx}->[$w]) && $notdefbefore==0) {
            $notdefbefore=0;
            $ml->add_elements(PDFNum($self->data->{wx}->[$w]));
        } else {
            $notdefbefore=1;
        }
    }

    $self->SUPER::outobjdeep($fh, $pdf, %opts);
}

BEGIN {

    $alias={
        'traditional'   => 'adobemingstdlightacro',
        'simplified'    => 'adobesongstdlightacro',
        'korean'        => 'adobemyungjostdmediumacro',
        'japanese'      => 'kozgopromediumacro',
        'japanese2'     => 'kozminproregularacro',
    };

}
1;

__END__

=head1 AUTHOR

alfred reibenschuh

=head1 HISTORY

    $Log: CJKFont.pm,v $
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