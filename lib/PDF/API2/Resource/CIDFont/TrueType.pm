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
#   $Id: TrueType.pm,v 1.6 2004/11/22 21:07:55 fredo Exp $
#
#=======================================================================
package PDF::API2::Resource::CIDFont::TrueType;

BEGIN {

    use utf8;
    use Encode qw(:all);

    use PDF::API2::Util;
    use PDF::API2::Basic::PDF::Utils;
    use PDF::API2::Resource::CIDFont;
    use PDF::API2::IOString;

    use PDF::API2::Basic::TTF::Font;
    use PDF::API2::Resource::CIDFont::TrueType::FontFile;

    use POSIX;

    use vars qw(@ISA $VERSION);

    @ISA = qw( PDF::API2::Resource::CIDFont );

    ( $VERSION ) = '$Revision: 1.6 $' =~ /Revision: (\S+)\s/; # $Date: 2004/11/22 21:07:55 $

}

=item $font = PDF::API2::Resource::CIDFont::TrueType->new $pdf, $file, %options

Returns a font object.

Defined Options:

    -encode ... specify fonts encoding for non-utf8 text.

=cut

sub new {
    my ($class,$pdf,$file,@opts) = @_;
    my %opts=();
    %opts=@opts if((scalar @opts)%2 == 0);
    $opts{-encode}||='latin1';
    my ($ff,$data)=PDF::API2::Resource::CIDFont::TrueType::FontFile->new($pdf,$file);

    $class = ref $class if ref $class;
    my $self=$class->SUPER::new($pdf,$data->{apiname}.pdfkey());
    $pdf->new_obj($self) if(defined($pdf) && !$self->is_obj($pdf));

    $self->{' data'}=$data;

    my $des=$self->descrByData;

    $self->{'BaseFont'} = PDFName($self->fontname);

    my $de=$self->{' de'};

    $de->{'FontDescriptor'} = $des;
    $de->{'Subtype'} = PDFName($self->iscff ? 'CIDFontType0' : 'CIDFontType2');
    $de->{'BaseFont'} = PDFName($self->fontname);
    $de->{'DW'} = PDFNum($self->missingwidth);
    $des->{$self->data->{iscff} ? 'FontFile3' : 'FontFile2'}=$ff;

    unless($self->issymbol) {
        $self->encodeByName($opts{-encode});
        $self->data->{encode}=$opts{-encode};
        $self->data->{decode}='ident';
    }


    $self->{' ff'} = $ff;
    $pdf->new_obj($ff);

    return($self);
}


sub fontfile { return( $_[0]->{' ff'} ); }
sub fontobj { return( $_[0]->data->{obj} ); }

=item $font = PDF::API2::Resource::CIDFont::TrueType->new_api $api, $file, %options

Returns a truetype-font object. This method is different from 'new' that
it needs an PDF::API2-object rather than a Text::PDF::File-object.

=cut

sub new_api {
    my ($class,$api,@opts)=@_;

    my $obj=$class->new($api->{pdf},@opts);
    $self->{' api'}=$api;

    $api->{pdf}->out_obj($api->{pages});
    return($obj);
}

sub wxByCId {
    my $self=shift @_;
    my $g=shift @_;
    my $w;

    if(defined $self->fontobj->{'hmtx'}->read->{'advance'}[$g]) {
        $w = int($self->fontobj->{'hmtx'}->read->{'advance'}[$g]*1000/$self->data->{upem});
    } else {
        $w = $self->missingwidth;
    }

    return($w);
}

sub subsetByCId {
    my $self = shift @_;
    return if($self->iscff);
    my $g = shift @_;
    $self->fontfile->subsetByCId($g);
}
sub subvec {
    my $self = shift @_;
    return(1) if($self->iscff);
    my $g = shift @_;
    $self->fontfile->subvec($g);
}

sub glyphNum { return ( $_[0]->fontfile->glyphNum ); }

sub outobjdeep {
    my ($self, $fh, $pdf, %opts) = @_;

    return $self->SUPER::outobjdeep($fh, $pdf) if defined $opts{'passthru'};

    my $notdefbefore=1;

    my $wx=PDFArray();
    $self->{' de'}->{'W'} = $wx;
    my $ml;

    foreach my $w (0..(scalar @{$self->data->{g2u}} - 1 )) {
        if($self->subvec($w) && $notdefbefore==1) {
            $notdefbefore=0;
            $ml=PDFArray();
            $wx->add_elements(PDFNum($w),$ml);
            $ml->add_elements(PDFNum($self->data->{wx}->[$w]));
        } elsif($self->subvec($w) && $notdefbefore==0) {
            $notdefbefore=0;
            $ml->add_elements(PDFNum($self->data->{wx}->[$w]));
        } else {
            $notdefbefore=1;
        }
    }

    $self->SUPER::outobjdeep($fh, $pdf, %opts);
}


1;

__END__

=head1 AUTHOR

alfred reibenschuh

=head1 HISTORY

    $Log: TrueType.pm,v $
    Revision 1.6  2004/11/22 21:07:55  fredo
    fixed multibyte-encoding support to work consistently acress cjk/ttf/otf

    Revision 1.5  2004/06/15 09:14:42  fredo
    removed cr+lf

    Revision 1.4  2004/06/07 19:44:37  fredo
    cleaned out cr+lf for lf

    Revision 1.3  2003/12/08 13:05:33  Administrator
    corrected to proper licencing statement

    Revision 1.2  2003/11/30 17:30:41  Administrator
    merged into default

    Revision 1.1.1.1.2.2  2003/11/30 16:56:36  Administrator
    merged into default

    Revision 1.1.1.1.2.1  2003/11/30 14:13:33  Administrator
    added CVS id/log


=cut