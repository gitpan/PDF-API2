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
#   $Id: BaseFont.pm,v 1.4 2003/12/08 13:05:32 Administrator Exp $
#
#=======================================================================
package PDF::API2::Resource::BaseFont;

BEGIN {

    use utf8;
    use Encode qw(:all);

    use PDF::API2::Util;
    use PDF::API2::Basic::PDF::Utils;
    use PDF::API2::Resource;

    use vars qw(@ISA $VERSION);

    @ISA = qw( PDF::API2::Resource );

    ( $VERSION ) = '$Revision: 1.4 $' =~ /Revision: (\S+)\s/; # $Date: 2003/12/08 13:05:32 $

}

=item $font = PDF::API2::Resource::BaseFont->new $pdf, $name

Returns a font resource object.

=cut

sub new {
    my ($class,$pdf,$name) = @_;
    my $self;

    $class = ref $class if ref $class;
    $self=$class->SUPER::new($pdf,$name);

    $pdf->new_obj($self) unless($self->is_obj($pdf));

    $self->{Type} = PDFName('Font');

    $self->{' apipdf'}=$pdf;
    return($self);
}

=item $font = PDF::API2::Resource::BaseFont->new_api $api, $name

Returns a font resource object. This method is different from 'new' that
it needs an PDF::API2-object rather than a Text::PDF::File-object.

=cut

sub new_api {
    my ($class,$api,@opts)=@_;

    my $obj=$class->new($api->{pdf},@opts);
    $obj->{' api'}=$api;

    return($obj);
}

sub data { return( $_[0]->{' data'} ); }

=item $descriptor = $font->descrByData()

Returns the fonts FontDescriptor key-structure based on the fonts data.

=cut

sub descrByData {
    my $self=shift @_;

    my $des=PDFDict();
    $self->{' apipdf'}->new_obj($des);

    ### $self->{'FontDescriptor'}=$des;

    $des->{'Type'}=PDFName('FontDescriptor');
    $des->{'FontName'}=PDFName($self->fontname);

    my @w = map { PDFNum($_ || 0) } $self->fontbbox;
    $des->{'FontBBox'}=PDFArray(@w);

 #   unless($self->issymbol) {
        $des->{'Ascent'}=PDFNum($self->ascender || 0);
        $des->{'Descent'}=PDFNum($self->descender || 0);
        $des->{'ItalicAngle'}=PDFNum($self->italicangle || 0.0);
        $des->{'XHeight'}=PDFNum($self->xheight || (($self->fontbbox)[3]*0.5) || 500);
        $des->{'CapHeight'}=PDFNum($self->capheight || ($self->fontbbox)[3] || 800);
        $des->{'StemV'}=PDFNum($self->stemv || 0);
        $des->{'StemH'}=PDFNum($self->stemh || 0);
#        $des->{'AvgWidth'}=PDFNum($self->missingwidth || 300);
        $des->{'AvgWidth'}=PDFNum($self->avgwidth || 300);
        $des->{'MissingWidth'}=PDFNum($self->missingwidth || 300);
        $des->{'MaxWidth'}=PDFNum($self->maxwidth || $self->missingwidth || ($self->fontbbox)[2]);
        $des->{'Flags'}=PDFNum($self->flags || 0) unless($self->data->{iscore});
 #   }

    return($des);
}


=back

=head1 FONT-MANAGEMENT RELATED METHODS

=over 4

=item $name = $font->fontname()

Returns the fonts name (aka. display-name).

=cut

sub fontname { return( $_[0]->data->{fontname} ); }

=item $name = $font->altname()

Returns the fonts alternative-name (aka. windows-name for a postscript font).

=cut

sub altname { return( $_[0]->data->{altname} ); }

=item $name = $font->subname()

Returns the fonts subname (aka. font-variant, schriftschnitt).

=cut

sub subname { return( $_[0]->data->{subname} ); }

=item $name = $font->apiname()

Returns the fonts name to be used internally (should be equal to $font->name).

=cut

sub apiname { return( $_[0]->data->{apiname} ); }

=item $issymbol = $font->issymbol()

Returns the fonts symbol flag.

=cut

sub issymbol { return( $_[0]->data->{issymbol} ); }

=item $iscff = $font->iscff()

Returns the fonts compact-font-format flag.

=cut

sub iscff { return( $_[0]->data->{iscff} ); }

=back

=head1 TYPOGRAPHY RELATED METHODS

=over 4

=item ($llx, $lly, $urx, $ury) = $font->fontbbox()

Returns the fonts bounding-box.

=cut

sub fontbbox { return( @{$_[0]->data->{fontbbox}} ); }

=item $capheight = $font->capheight()

Returns the fonts capheight value.

=cut

sub capheight { return( $_[0]->data->{capheight} ); }

=item $xheight = $font->xheight()

Returns the fonts xheight value.

=cut

sub xheight { return( $_[0]->data->{xheight} ); }

=item $missingwidth = $font->missingwidth()

Returns the fonts missingwidth value.

=cut

sub missingwidth { return( $_[0]->data->{missingwidth} ); }

=item $maxwidth = $font->maxwidth()

Returns the fonts maxwidth value.

=cut

sub maxwidth { return( $_[0]->data->{maxwidth} ); }

=item $avgwidth = $font->avgwidth()

Returns the fonts avgwidth value.

=cut

sub avgwidth {
    my ($self) = @_;
    my $aw=$self->data->{avgwidth};
    $aw||=((
        $self->wxByGlyph('a')*64  +
        $self->wxByGlyph('b')*14  +
        $self->wxByGlyph('c')*27  +
        $self->wxByGlyph('d')*35  +
        $self->wxByGlyph('e')*100 +
        $self->wxByGlyph('f')*20  +
        $self->wxByGlyph('g')*14  +
        $self->wxByGlyph('h')*42  +
        $self->wxByGlyph('i')*63  +
        $self->wxByGlyph('j')* 3  +
        $self->wxByGlyph('k')* 6  +
        $self->wxByGlyph('l')*35  +
        $self->wxByGlyph('m')*20  +
        $self->wxByGlyph('n')*56  +
        $self->wxByGlyph('o')*56  +
        $self->wxByGlyph('p')*17  +
        $self->wxByGlyph('q')* 4  +
        $self->wxByGlyph('r')*49  +
        $self->wxByGlyph('s')*56  +
        $self->wxByGlyph('t')*71  +
        $self->wxByGlyph('u')*31  +
        $self->wxByGlyph('v')*10  +
        $self->wxByGlyph('w')*18  +
        $self->wxByGlyph('x')* 3  +
        $self->wxByGlyph('y')*18  +
        $self->wxByGlyph('z')* 2  +
        $self->wxByGlyph('A')*64  +
        $self->wxByGlyph('B')*14  +
        $self->wxByGlyph('C')*27  +
        $self->wxByGlyph('D')*35  +
        $self->wxByGlyph('E')*100 +
        $self->wxByGlyph('F')*20  +
        $self->wxByGlyph('G')*14  +
        $self->wxByGlyph('H')*42  +
        $self->wxByGlyph('I')*63  +
        $self->wxByGlyph('J')* 3  +
        $self->wxByGlyph('K')* 6  +
        $self->wxByGlyph('L')*35  +
        $self->wxByGlyph('M')*20  +
        $self->wxByGlyph('N')*56  +
        $self->wxByGlyph('O')*56  +
        $self->wxByGlyph('P')*17  +
        $self->wxByGlyph('Q')* 4  +
        $self->wxByGlyph('R')*49  +
        $self->wxByGlyph('S')*56  +
        $self->wxByGlyph('T')*71  +
        $self->wxByGlyph('U')*31  +
        $self->wxByGlyph('V')*10  +
        $self->wxByGlyph('W')*18  +
        $self->wxByGlyph('X')* 3  +
        $self->wxByGlyph('Y')*18  +
        $self->wxByGlyph('Z')* 2  +
        $self->wxByGlyph('space')*332
    ) / 2000);
    return( int($aw) );
}

=item $flags = $font->flags()

Returns the fonts flags value.

=cut

sub flags { return( $_[0]->data->{flags} ); }

=item $stemv = $font->stemv()

Returns the fonts stemv value.

=cut

sub stemv { return( $_[0]->data->{stemv} ); }

=item $stemh = $font->stemh()

Returns the fonts stemh value.

=cut

sub stemh { return( $_[0]->data->{stemh} ); }

=item $italicangle = $font->italicangle()

Returns the fonts italicangle value.

=cut

sub italicangle { return( $_[0]->data->{italicangle} ); }

=item $isfixedpitch = $font->isfixedpitch()

Returns the fonts isfixedpitch flag.

=cut

sub isfixedpitch { return( $_[0]->data->{isfixedpitch} ); }

=item $underlineposition = $font->underlineposition()

Returns the fonts underlineposition value.

=cut

sub underlineposition { return( $_[0]->data->{underlineposition} ); }

=item $underlinethickness = $font->underlinethickness()

Returns the fonts underlinethickness value.

=cut

sub underlinethickness { return( $_[0]->data->{underlinethickness} ); }

=item $ascender = $font->ascender()

Returns the fonts ascender value.

=cut

sub ascender { return( $_[0]->data->{ascender} ); }

=item $descender = $font->descender()

Returns the fonts descender value.

=cut

sub descender { return( $_[0]->data->{descender} ); }

=back

=head1 GLYPH RELATED METHODS

=over 4

=item @names = $font->glyphNames()

Returns the defined glyph-names of the font.

=cut

sub glyphNames { return ( keys %{$_[0]->data->{wx}} ); }

=item $glNum = $font->glyphNum()

Returns the number of defined glyph-names of the font.

=cut

sub glyphNum { return ( scalar keys %{$_[0]->data->{wx}} ); }

=item $uni = $font->uniByGlyph $char

Returns the unicode by glyph-name.

=cut

sub uniByGlyph { return( $_[0]->data->{n2u}->{$_[1]} ); }

=item $uni = $font->uniByEnc $char

Returns the unicode by the fonts encoding map.

=cut

sub uniByEnc { return($_[0]->data->{e2u}->[$_[1]] ); }

=item $uni = $font->uniByMap $char

Returns the unicode by the fonts default map.

=cut

sub uniByMap { return($_[0]->data->{uni}->[$_[1]]); }

=item $char = $font->encByGlyph $glyph

Returns the character by the given glyph-name of the fonts encoding map.

=cut

sub encByGlyph { return( $_[0]->data->{n2e}->{$_[1]} || 0 ); }

=item $char = $font->encByUni $uni

Returns the character by the given unicode of the fonts encoding map.

=cut

sub encByUni { return( $_[0]->data->{u2e}->{$_[1]} || 0 ); }

=item $char = $font->mapByGlyph $glyph

Returns the character by the given glyph-name of the fonts default map.

=cut

sub mapByGlyph { return( $_[0]->data->{n2c}->{$_[1]} || 0 ); }

=item $char = $font->mapByUni $uni

Returns the character by the given unicode of the fonts default map.

=cut

sub mapByUni { return( $_[0]->data->{u2c}->{$_[1]} || 0 ); }

=item $name = $font->glyphByUni $unicode

Returns the glyphs name by the fonts unicode map.
B<BEWARE:> non-standard glyph-names are mapped onto
the ms-symbol area (0xF000).

=cut

sub glyphByUni { return ( $_[0]->data->{u2n}->{$_[1]} || '.notdef' ); }

=item $name = $font->glyphByEnc $char

Returns the glyphs name by the fonts encoding map.

=cut

sub glyphByEnc {
    my ($self,$e)=@_;
    my $g=$self->data->{e2n}->[$e];
    return( $g );
}

=item $name = $font->glyphByMap $char

Returns the glyphs name by the fonts default map.

=cut

sub glyphByMap { return ( $_[0]->data->{char}->[$_[1]] ); }

=item $width = $font->wxByGlyph $glyph

Returns the glyphs width.

=cut

sub wxByGlyph { return ( (ref($_[0]->data->{wx}) eq 'HASH' ? $_[0]->data->{wx}->{$_[1]} : $_[0]->data->{wx}->[$_[1]]) || $_[0]->missingwidth || 300 ); }

=item $width = $font->wxByUni $uni

Returns the unicodes width.

=cut

sub wxByUni { return ( $_[0]->data->{wx}->{$_[0]->glyphByUni($_[1])} || $_[0]->missingwidth || 300  ); }

=item $width = $font->wxByEnc $char

Returns the characters width based on the current encoding.

=cut

sub wxByEnc {
    my ($self,$e)=@_;
    my $g=$self->glyphByEnc($e);
    my $w=$self->data->{wx}->{$g} || $self->missingwidth || 300;
    return ( $w );
}

=item $width = $font->wxByMap $char

Returns the characters width based on the fonts default encoding.

=cut

sub wxByMap { return ( $_[0]->data->{wx}->{$_[0]->glyphByMap($_[1])} || $_[0]->missingwidth || 300 ); }

=item $wd = $font->width $text

Returns the width of $text as if it were at size 1.
B<BEWARE:> works only correctly if a proper perl-string
is used either in native or utf8 format (check utf8-flag).

=cut

sub width {
    my ($self,$text)=@_;
    my $width=0;
    if(is_utf8($text)) {
        $text=$self->strByUtf($text)
    }
    foreach my $n (unpack('C*',$text)) {
        $width+=$self->wxByEnc($n);
    }
    $width/=1000;
    return($width);
}

=item @widths = $font->width_array $text

Returns the widths of the words in $text as if they were at size 1.

=cut

sub width_array {
    my ($self,$text)=@_;
    if(!is_utf8($text)) {
        $text=$self->utfByStr($text);
    }
    my @text=split(/\s+/,$text);
    my @widths=map { $self->width($_) } @text;
    return(@widths);
}

=back

=head1 STRING METHODS

=over 4

=item $utf8string = $font->utfByStr $string

Returns the utf8-string from string based on the fonts encoding map.

=cut

sub utfByStr {
    my ($self,$s)=@_;
    $s=pack('U*',map { $self->uniByEnc($_) } unpack('C*',$s));
    utf8::upgrade($s);
    return($s);
}

=item $string = $font->strByUtf $utf8string

Returns the encoded string from utf8-string based on the fonts encoding map.

=cut

sub strByUtf {
    my ($self,$s)=@_;
    $s=pack('C*',map { $self->encByUni($_) & 0xFF } unpack('U*',$s));
    utf8::downgrade($s);
    return($s);
}

=item $pdfstring = $font->textByStr $text

Returns a properly formatted representation of $text for use in the PDF.

=cut

sub textByStr {
    my ($self,$text)=@_;
    my $newtext='';
    if(is_utf8($text)) {
        $text=$self->strByUtf($text);
    }
#    foreach my $g (unpack('C*',$text)) {
#        $newtext.=sprintf('%02X',$g);
#    }
#    return("<$newtext>");
    $newtext=$text;
    $newtext=~s/\\/\\\\/go;
    $newtext=~s/([\x00-\x1f])/sprintf('\%03lo',ord($1))/ge;
    $newtext=~s/([\{\}\[\]\(\)])/\\$1/g;
    return("($newtext)");
}

sub text {
  my ($self,$text,%opts)=@_;
  my $newtext='';
  if($opts{-utf8}) {
    $text=utf8_to_ucs2($text);
    foreach my $x (0..(length($text)>>1)-1) {
      $newtext.=pack("C",vec($text,$x,16) & 0xff);
    }
  } elsif($opts{-ucs2}) {
    foreach my $x (0..(length($text)>>1)-1) {
      $newtext.=pack("C",vec($text,$x,16) & 0xff);
    }
  } else {
  # foreach my $g (0..length($text)-1) {
  #   $newtext.=
  #     (substr($text,$g,1)=~/[\x00-\x1f\\\{\}\[\]\(\)]/)
  #     ? sprintf('\%03lo',vec($text,$g,8))
  #     : substr($text,$g,1) ;
  # }
  }
  return("($newtext)");
}
1;

__END__

=back

=head1 AUTHOR

alfred reibenschuh.

=head1 HISTORY

    $Log: BaseFont.pm,v $
    Revision 1.4  2003/12/08 13:05:32  Administrator
    corrected to proper licencing statement

    Revision 1.3  2003/11/30 17:28:54  Administrator
    merged into default

    Revision 1.2.2.1  2003/11/30 16:56:35  Administrator
    merged into default

    Revision 1.2  2003/11/30 11:44:49  Administrator
    added CVS id/log


=cut
