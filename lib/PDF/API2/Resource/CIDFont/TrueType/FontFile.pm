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
#   $Id: FontFile.pm,v 1.6 2004/06/15 09:14:52 fredo Exp $
#
#=======================================================================
package PDF::API2::Resource::CIDFont::TrueType::FontFile;

BEGIN {

    use utf8;
    use Encode qw(:all);
    use PDF::API2::Util;
    use PDF::API2::IOString;

    use PDF::API2::Basic::PDF::Utils;
    use PDF::API2::Basic::PDF::Dict;
    use PDF::API2::Basic::TTF::Font;

    use POSIX;

    use vars qw( @ISA $VERSION);

    @ISA = qw( PDF::API2::Basic::PDF::Dict );

    ( $VERSION ) = '$Revision: 1.6 $' =~ /Revision: (\S+)\s/; # $Date: 2004/06/15 09:14:52 $

}

sub new {
    my ($class,$pdf,$file)=@_;
    my $data={};

    die "cannot find font '$file' ..." unless(-f $file);
    my $font=PDF::API2::Basic::TTF::Font->open($file);
    $data->{obj}=$font;

    $class = ref $class if ref $class;
    $self=$class->SUPER::new();

    $self->{Filter}=PDFArray(PDFName('FlateDecode'));
    $self->{' font'}=$font;
    $self->{' data'}=$data;

    $data->{iscff} = (defined $font->{'CFF '}) ? 1 : 0;

    $self->{Subtype}=PDFName('Type1C') if($data->{iscff});
#    $self->{Subtype}=PDFName('CIDFontType0C') if($data->{iscff});

    $data->{fontname}=$font->{'name'}->read->find_name(4);
    $data->{apiname}=$data->{fontname};
    $data->{apiname}=~s/[^A-Za-z0-9]+/ /og;
    $data->{apiname}=join('',map { $_=~s/[^A-Za-z0-9]+//og; $_=ucfirst(lc(substr($_,0,2))); $_; } split(/\s+/,$data->{apiname}));
    $data->{fontname}=~s/\s//og;

    $data->{altname}=$font->{'name'}->find_name(1);
    $data->{altname}=~s/\s//og;

    $data->{subname}=$font->{'name'}->find_name(2);
    $data->{subname}=~s/\s//og;

    if(defined $font->{cmap}->read->find_ms) {
        $data->{issymbol} = ($font->{cmap}->read->find_ms->{'Platform'} == 3 && $font->{cmap}->read->find_ms->{'Encoding'} == 0) || 0;
    } else {
        $data->{issymbol} = 0;
    }

    $data->{upem}=$font->{'head'}->read->{'unitsPerEm'};

    $data->{fontbbox}=[
        int($font->{'head'}->{'xMin'} * 1000 / $data->{upem}),
        int($font->{'head'}->{'yMin'} * 1000 / $data->{upem}),
        int($font->{'head'}->{'xMax'} * 1000 / $data->{upem}),
        int($font->{'head'}->{'yMax'} * 1000 / $data->{upem})
    ];

    $data->{stemv}=0;
    $data->{stemh}=0;

    $data->{missingwidth}=int($font->{'hhea'}->read->{'advanceWidthMax'} * 1000 / $data->{upem}) || 1000;
    $data->{maxwidth}=int($font->{'hhea'}->{'advanceWidthMax'} * 1000 / $data->{upem});
    $data->{ascender}=int($font->{'hhea'}->read->{'Ascender'} * 1000 / $data->{upem});
    $data->{descender}=int($font->{'hhea'}{'Descender'} * 1000 / $data->{upem});

    $data->{flags} = 0;
    $data->{flags} |= 1 if ($font->{'OS/2'}->read->{'bProportion'} == 9);
    $data->{flags} |= 2 unless ($font->{'OS/2'}{'bSerifStyle'} > 10 && $font->{'OS/2'}{'bSerifStyle'} < 14);
    $data->{flags} |= 8 if ($font->{'OS/2'}{'bFamilyType'} == 2);
    $data->{flags} |= 32; # if ($font->{'OS/2'}{'bFamilyType'} > 3);
    $data->{flags} |= 64 if ($font->{'OS/2'}{'bLetterform'} > 8);;

    $data->{capheight}=$font->{'OS/2'}->{CapHeight} || int($data->{fontbbox}->[3]*0.8);
    $data->{xheight}=$font->{'OS/2'}->{xHeight} || int($data->{fontbbox}->[3]*0.4);

    if($data->{issymbol}) {
        $data->{e2u}=[0xf000 .. 0xf0ff];
    } else {
        $data->{e2u}=[ unpack('U*',decode('cp1252', pack('C*',0..255))) ];
    }

    if(($font->{'post'}->read->{FormatType} == 3) && defined($font->{cmap}->read->find_ms)) {
        $data->{g2n} = [];
        foreach my $u (sort {$a<=>$b} keys %{$font->{cmap}->read->find_ms->{val}}) {
            my $n=nameByUni($u);
            $data->{g2n}->[$font->{cmap}->read->find_ms->{val}->{$u}]=$n;
        }
    } else {
        $data->{g2n} = [ map { $_ || '.notdef' } @{$font->{'post'}->read->{'VAL'}} ];
    }

    $data->{italicangle}=$font->{'post'}->{italicAngle};
    $data->{isfixedpitch}=$font->{'post'}->{isFixedPitch};
    $data->{underlineposition}=$font->{'post'}->{underlinePosition};
    $data->{underlinethickness}=$font->{'post'}->{underlineThickness};

    $data->{u2g} = {};
    if($data->{issymbol}) {
        map { $data->{u2g}->{$_} ||= $font->{'cmap'}->read->ms_lookup($_) } (0xf000 .. 0xf0ff);
        map { $data->{u2g}->{$_ & 0xff} ||= $font->{'cmap'}->read->ms_lookup($_) } (0xf000 .. 0xf0ff);
    }
 #   } else {
        my $g=0;
        foreach my $u ($font->{'cmap'}->read->reverse) {
            my $uni=$u||0;
        #    print STDERR "got g=$g u=$uni\n";
            $data->{u2g}->{$uni}=$g;
            $g++;
        }
 #   }
    $data->{g2u}=[ map { $_ || 0 } $font->{'cmap'}->read->reverse ];

##    $data->{char}=[ map { $font->{'cmap'}->read->ms_lookup($_) || 0 } @{$data->{e2u}} ];

    $data->{e2n}=[ map { $data->{g2n}->[$data->{u2g}->{$_} || 0] || '.notdef' } @{$data->{e2u}} ];

    $data->{e2g}=[ map { $data->{u2g}->{$_ || 0} || 0 } @{$data->{e2u}} ];
    $data->{u2e}={};
    foreach my $n (reverse 0..255) {
        $data->{u2e}->{$data->{e2u}->[$n]}=$n unless(defined $data->{u2e}->{$data->{e2u}->[$n]});
    }

    $data->{u2n}={ map { $data->{g2u}->[$_] => $data->{g2n}->[$_] } (0 .. (scalar @{$data->{g2u}} -1)) };

    $data->{wx}=[];
    foreach my $w (0..(scalar @{$data->{g2u}}-1)) {
        $data->{wx}->[$w]=int($font->{'hmtx'}->read->{'advance'}[$w]*1000/$data->{upem})
            || $data->{missingwidth};
    }
    return($self,$data);
}

sub font { return( $_[0]->{' font'} ); }
sub data { return( $_[0]->{' data'} ); }
sub iscff { return( $_[0]->data->{iscff} ); }

sub subsetByCId {
    my $self = shift @_;
    my $g = shift @_;
    $self->data->{subset}=1;
    vec($self->data->{subvec},$g,1)=1;
    return if($self->iscff);
    if(defined $self->font->{loca}->read->{glyphs}->[$g]) {
        $self->font->{loca}->read->{glyphs}->[$g]->read;
        map { vec($self->data->{subvec},$_,1)=1; } $self->font->{loca}->{glyphs}->[$g]->get_refs;
    }
}

sub subvec {
    my $self = shift @_;
    return(1) if($self->iscff);
    my $g = shift @_;
    return(vec($self->data->{subvec},$g,1));
}

sub glyphNum { return ( $_[0]->font->{'maxp'}->read->{'numGlyphs'} ); }

sub outobjdeep {
    my ($self, $fh, $pdf, %opts) = @_;

    return $self->SUPER::outobjdeep($fh, $pdf) if defined $opts{'passthru'};

    my $f = $self->font;

    if($self->iscff) {
        $f->{'CFF '}->read_dat;
        $self->{' stream'} = $f->{'CFF '}->{' dat'};
    } else {
        if ($self->data->{subset}) {
            $f->{'glyf'}->read;
            for (my $i = 0; $i < $self->glyphNum; $i++) {
                next if($self->subvec($i));
                $f->{'loca'}{'glyphs'}->[$i] = undef;
            #    print STDERR "$i,";
            }
        }

        $self->{' stream'} = "";
        my $ffh = PDF::API2::IOString->new(\$self->{' stream'});
        $f->out($ffh, 'cmap', 'cvt ', 'fpgm', 'glyf', 'head', 'hhea', 'hmtx', 'loca', 'maxp', 'prep');
        $self->{'Length1'}=PDFNum(length($self->{' stream'}));
    }

    $self->SUPER::outobjdeep($fh, $pdf, %opts);
}


1;

__END__

=head1 AUTHOR

alfred reibenschuh

=head1 HISTORY

    $Log: FontFile.pm,v $
    Revision 1.6  2004/06/15 09:14:52  fredo
    removed cr+lf

    Revision 1.5  2004/06/07 19:44:43  fredo
    cleaned out cr+lf for lf

    Revision 1.4  2004/04/20 09:46:25  fredo
    added glyph->read fix for subset-vector

    Revision 1.3  2003/12/08 13:06:01  Administrator
    corrected to proper licencing statement

    Revision 1.2  2003/11/30 17:31:41  Administrator
    merged into default

    Revision 1.1.1.1.2.2  2003/11/30 16:57:02  Administrator
    merged into default

    Revision 1.1.1.1.2.1  2003/11/30 14:16:39  Administrator
    added CVS id/log


=cut
