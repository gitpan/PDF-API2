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
#   $Id: Font.pm,v 1.7 2004/06/15 09:14:41 fredo Exp $
#
#=======================================================================
package PDF::API2::Resource::Font;

BEGIN {

    use utf8;
    use Encode qw(:all);

    use PDF::API2::Util;
    use PDF::API2::Basic::PDF::Utils;
    use PDF::API2::Resource::BaseFont;

    use POSIX;

    use vars qw(@ISA $VERSION);

    @ISA = qw( PDF::API2::Resource::BaseFont );

    ( $VERSION ) = '$Revision: 1.7 $' =~ /Revision: (\S+)\s/; # $Date: 2004/06/15 09:14:41 $

}

=item $font->encodeByData $encoding

Encodes the font in the specified byte-encoding.

=cut

sub encodeByData {
    my ($self,$encoding)=@_;
    my $data=undef;

    my ($firstChar,$lastChar);

    if($self->issymbol || $encoding eq 'asis') {
        $encoding=undef;
    }

    if(defined $encoding) {
        $self->data->{e2u}=[ unpack('U*',decode($encoding,pack('C*',(0..255)))) ];
        $self->data->{e2n}=[ map { nameByUni($_) || '.notdef' } @{$self->data->{e2u}} ];
    #    print STDERR "did encode.\n";
    } else {
        $self->data->{e2u}=[ @{$self->data->{uni}} ];
        $self->data->{e2n}=[ map { $_ || '.notdef' } @{$self->data->{char}} ];
    }

    $self->data->{u2c}={};
    $self->data->{u2e}={};
    $self->data->{u2n}={};
    $self->data->{n2c}={};
    $self->data->{n2e}={};
    $self->data->{n2u}={};

    foreach my $n (0..255) {
        $self->data->{n2c}->{$self->data->{char}->[$n] || '.notdef'}=$n unless(defined $self->data->{n2c}->{$self->data->{char}->[$n] || '.notdef'});
        $self->data->{n2e}->{$self->data->{e2n}->[$n] || '.notdef'}=$n unless(defined $self->data->{n2e}->{$self->data->{e2n}->[$n] || '.notdef'});

        $self->data->{n2u}->{$self->data->{e2n}->[$n] || '.notdef'}=$self->data->{e2u}->[$n] unless(defined $self->data->{n2u}->{$self->data->{e2n}->[$n] || '.notdef'});
        $self->data->{n2u}->{$self->data->{char}->[$n] || '.notdef'}=$self->data->{uni}->[$n] unless(defined $self->data->{n2u}->{$self->data->{char}->[$n] || '.notdef'});

        $self->data->{u2c}->{$self->data->{uni}->[$n]}||=$n unless(defined $self->data->{u2c}->{$self->data->{uni}->[$n]});
        $self->data->{u2e}->{$self->data->{e2u}->[$n]}||=$n unless(defined $self->data->{u2e}->{$self->data->{e2u}->[$n]});

        $self->data->{u2n}->{$self->data->{e2u}->[$n]}=($self->data->{e2n}->[$n] || '.notdef') unless(defined $self->data->{u2n}->{$self->data->{e2u}->[$n]});
        $self->data->{u2n}->{$self->data->{uni}->[$n]}=($self->data->{char}->[$n] || '.notdef') unless(defined $self->data->{u2n}->{$self->data->{uni}->[$n]});
    }

    my $en = PDFDict();
    $self->{Encoding}=$en;

    $en->{Type}=PDFName('Encoding');
    $en->{BaseEncoding}=PDFName('WinAnsiEncoding');

    $en->{Differences}=PDFArray(PDFNum(0));
    foreach my $n (0..255) {
        $en->{Differences}->add_elements( PDFName($self->glyphByEnc($n) || '.notdef') );
    }

    $self->{'FirstChar'} = PDFNum($self->data->{firstchar});
    $self->{'LastChar'} = PDFNum($self->data->{lastchar});

    $self->{Widths}=PDFArray();
    foreach my $n ($self->data->{firstchar}..$self->data->{lastchar}) {
        $self->{Widths}->add_elements( PDFNum($self->wxByEnc($n)) );
    }

#use Data::Dumper;
#    print Dumper($self->data);

    return($self);
}

=item $pdfstring = $font->text $text

Returns a properly formatted representation of $text for use in the PDF.

=cut

sub text { return($_[0]->textByStr($_[1])); }

sub automap {
    my ($self)=@_;

    my %gl=map { $_=>defineName($_) } keys %{$self->data->{wx}};

    foreach my $n (0..255) {
        delete $gl{$self->data->{e2n}->[$n]};
    }

#    my @nm=sort { lc($a) eq lc($b) ? $a cmp $b : lc($a) cmp lc($b) } keys %gl;
    my @nm=sort { $gl{$a}<=>$gl{$b} } keys %gl;
    #splice(@nm,223);
    my @fnts=();
    my $count=0;
    while(@glyphs=splice(@nm,0,223)) {

        my $obj=$self->SUPER::new($self->{' apipdf'},$self->name.'am'.$count);
        $obj->{' data'}={ %{$self->data} };
        $obj->data->{firstchar}=32;
        $obj->data->{lastchar}=32+scalar(@glyphs);
        push @fnts,$obj;
        foreach my $key (qw( Subtype BaseFont FontDescriptor )) {
            $obj->{$key}=$self->{$key} if(defined $self->{$key});
        }
        $obj->data->{char}=[];
        $obj->data->{uni}=[];
        foreach my $n (0..31) {
            $obj->data->{char}->[$n]='.notdef';
            $obj->data->{uni}->[$n]=0;
        }
        $obj->data->{char}->[32]='space';
        $obj->data->{uni}->[32]=32;
        foreach my $n (33..$obj->data->{lastchar}) {
            $obj->data->{char}->[$n]=$glyphs[$n-33];
            $obj->data->{uni}->[$n]=$gl{$glyphs[$n-33]};
        }
        foreach my $n (($obj->data->{lastchar}+1)..255) {
            $obj->data->{char}->[$n]='.notdef';
            $obj->data->{uni}->[$n]=0;
        }
        $obj->encodeByData(undef);

        $count++;
    }

    return(@fnts);
}

sub remap {
    my ($self,$enc)=@_;

    my $obj=$self->SUPER::new($self->{' apipdf'},$self->name.'rm'.pdfkey());
    $obj->{' data'}={ %{$self->data} };
    foreach my $key (qw( Subtype BaseFont FontDescriptor )) {
        $obj->{$key}=$self->{$key} if(defined $self->{$key});
    }

    $obj->encodeByData($enc);

    return($obj);
}

1;

__END__

=head1 AUTHOR

alfred reibenschuh

=head1 HISTORY

    $Log: Font.pm,v $
    Revision 1.7  2004/06/15 09:14:41  fredo
    removed cr+lf

    Revision 1.6  2004/06/07 19:44:36  fredo
    cleaned out cr+lf for lf

    Revision 1.5  2004/05/21 15:10:29  fredo
    worked around some unicode probs

    Revision 1.4  2003/12/08 13:05:33  Administrator
    corrected to proper licencing statement

    Revision 1.3  2003/11/30 17:28:55  Administrator
    merged into default

    Revision 1.2.2.1  2003/11/30 16:56:35  Administrator
    merged into default

    Revision 1.2  2003/11/30 11:44:49  Administrator
    added CVS id/log


=cut
