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
#   $Id: CoreFont.pm,v 1.4 2004/06/07 19:44:43 fredo Exp $
#
#=======================================================================
package PDF::API2::Resource::Font::CoreFont;

=head1 NAME

PDF::API2::Resource::Font::CoreFont - Module for using the 14 PDF built-in Fonts.

=head1 SYNOPSIS

    #
    use PDF::API2;
    #
    $pdf = PDF::API2->new;
    $cft = $pdf->corefont('Times-Roman');
    #

=head1 METHODS

=over 4

=cut

BEGIN {

    use utf8;
    use Encode qw(:all);

    use vars qw( @ISA $fonts $alias $subs $encodings $VERSION );
    use PDF::API2::Resource::Font;
    use PDF::API2::Util;
    use PDF::API2::Basic::PDF::Utils;

    @ISA=qw(PDF::API2::Resource::Font);

    ( $VERSION ) = '$Revision: 1.4 $' =~ /Revision: (\S+)\s/; # $Date: 2004/06/07 19:44:43 $

}

=item $font = PDF::API2::Resource::Font::CoreFont->new $pdf, $fontname, %options

Returns a corefont object.

=cut

=pod

Valid %options are:

I<-encode>
... changes the encoding of the font from its default.
See I<perl's Encode> for the supported values.

I<-pdfname> ... changes the reference-name of the font from its default.
The reference-name is normally generated automatically and can be
retrived via $pdfname=$font->name.

=cut

sub _look_for_font ($) {
  my $fname=shift;
  return(%{$fonts->{$fname}}) if(defined $fonts->{$fname});
  eval "require PDF::API2::Resource::Font::CoreFont::$fname; ";
  unless($@){
    $fonts->{$fname}->{uni}||=[];
    foreach my $n (0..255) {
        $fonts->{$fname}->{uni}->[$n]=uniByName($fonts->{$fname}->{char}->[$n]) unless(defined $fonts->{$fname}->{uni}->[$n]);
    }
    return(%{$fonts->{$fname}});
  } else {
    die "requested font '$fname' not installed ";
  }
}

sub _look_for_fontfile ($) {
  my $fname=shift;
  my $fpath;
  foreach my $dir (@INC) {
    $fpath="$dir/PDF/API2/Resource/Font/CoreFont/$fname";
    last if(-f $fpath);
    $fpath=undef;
  }
  return($fpath);
}

sub new {
    my ($class,$pdf,$name,@opts) = @_;
    my ($self,$data);
    my %opts=();
    my $lookname=lc($name);
    $lookname=~s/[^a-z0-9]+//gi;
    %opts=@opts if((scalar @opts)%2 == 0);
    $opts{-encode}||='asis';

    $lookname = defined($alias->{$lookname}) ? $alias->{$lookname} : $lookname ;

    if(defined $subs->{$lookname}) {
        $data={_look_for_font($subs->{$lookname}->{-alias})};
        foreach my $k (keys %{$subs->{$lookname}}) {
          next if($k=~/^\-/);
          $data->{$k}=$subs->{$lookname}->{$k};
        }
    } else {
        unless(defined $opts{-metrics}) {
          $data={_look_for_font($lookname)};
        } else {
          $data={%{$opts{-metrics}}};
        }
    }

    die "Undefined Font '$name($lookname)'" unless($data->{fontname});

    # we have data now here so we need to check if
    # there is a -ttfile or -afmfile/-pfmfile/-pfbfile
    # and proxy the call to the relevant modules
    #
    #if(defined $data->{-ttfile} && $data->{-ttfile}=_look_for_fontfile($data->{-ttfile})) {
    #    return(PDF::API2::Resource::CIDFont::TrueType->new($pdf,$data->{-ttfile},@opts));
    #} elsif(defined $data->{-pfbfile} && $data->{-pfbfile}=_look_for_fontfile($data->{-pfbfile})) {
    #    $data->{-afmfile}=_look_for_fontfile($data->{-afmfile});
    #    return(PDF::API2::Resource::Font::Postscript->new($pdf,$data->{-pfbfile},$data->{-afmfile},@opts));
    #}
    #
    # the above has to be cleaned up for production use


    $class = ref $class if ref $class;
    $self = $class->SUPER::new($pdf, $data->{apiname}.pdfkey());
    $pdf->new_obj($self) unless($self->is_obj($pdf));
    $self->{' data'}=$data;

    $self->{'Subtype'} = PDFName($self->data->{type});
    $self->{'BaseFont'} = PDFName($self->fontname);

    if($opts{-pdfname}) {
        $self->name($opts{-pdfname});
    }

    unless($self->data->{iscore}) {
        $self->{'FontDescriptor'}=$self->descrByData();
    }

    $self->encodeByData($opts{-encode});

    return($self);
}

=item $font = PDF::API2::Resource::Font::CoreFont->new_api $api, $fontname, %options

Returns a corefont object. This method is different from 'new' that
it needs an PDF::API2-object rather than a PDF::API2::PDF::File-object.

=cut

sub new_api {
  my ($class,$api,@opts)=@_;

  my $obj=$class->new($api->{pdf},@opts);

  $api->{pdf}->new_obj($obj) unless($obj->is_obj($api->{pdf}));

#  $api->resource('Font',$obj->name,$obj);

  $api->{pdf}->out_obj($api->{pages});
  return($obj);
}

=item PDF::API2::Resource::Font::CoreFont->loadallfonts()

"Requires in" all fonts available as corefonts.

=cut

sub loadallfonts {
  foreach my $f (qw(
    courier
    courierbold
    courierboldoblique
    courieroblique
    georgia
    georgiabold
    georgiabolditalic
    georgiaitalic
    helveticaboldoblique
    helveticaoblique
    helveticabold
    helvetica
    symbol
    timesbolditalic
    timesitalic
    timesroman
    timesbold
    verdana
    verdanabold
    verdanabolditalic
    verdanaitalic
    webdings
    wingdings
    zapfdingbats
  )){
    _look_for_font($f);
  }
}

#    andalemono
#    arialrounded
#    bankgothic
#    impact
#    ozhandicraft
#    trebuchet
#    trebuchetbold
#    trebuchetbolditalic
#    trebuchetitalic

BEGIN {

  $alias = {
    ## Windows Fonts with Type1 equivalence

    'arial'  =>  'helvetica',
    'arialitalic' => 'helveticaoblique',
    'arialbold' => 'helveticabold',
    'arialbolditalic' => 'helveticaboldoblique',

    'times'       => 'timesroman',
    'timesnewromanbolditalic' => 'timesbolditalic',
    'timesnewromanbold'   => 'timesbold',
    'timesnewromanitalic'   => 'timesitalic',
    'timesnewroman'     => 'timesroman',

    'couriernewbolditalic'    => 'courierboldoblique',
    'couriernewbold'    => 'courierbold',
    'couriernewitalic'    => 'courieroblique',
    'couriernew'      => 'courier',


    #     ## unix/TeX-ish aliases
    #
    #     'typewriterbolditalic'    => 'courierboldoblique',
    #     'typewriterbold'    => 'courierbold',
    #     'typewriteritalic'    => 'courieroblique',
    #     'typewriter'      => 'courier',
    #
    #     'sansbolditalic'    => 'helveticaboldoblique',
    #     'sansbold'      => 'helveticabold',
    #     'sansitalic'      => 'helveticaoblique',
    #     'sans'        => 'helvetica',
    #
    #     'serifbolditalic'   => 'timesbolditalic',
    #     'serifbold'     => 'timesbold',
    #     'serifitalic'     => 'timesitalic',
    #     'serif'       => 'timesroman',
    #
    #     'greek'       => 'symbol',
    #     'bats'        => 'zapfdingbats',
  };

    $subs = {
        #  'impactitalic'      => {
        #            'apiname' => 'Imp2',
        #            '-alias'  => 'impact',
        #            'fontname'  => 'Impact,Italic',
        #            'italicangle' => -12,
        #          },
        #  'ozhandicraftbold'    => {
        #            'apiname' => 'Oz2',
        #            '-alias'  => 'ozhandicraft',
        #            'fontname'  => 'OzHandicraftBT,Bold',
        #            'italicangle' => 0,
        #            'flags' => 32+262144,
        #          },
        #  'ozhandicraftitalic'    => {
        #            'apiname' => 'Oz3',
        #            '-alias'  => 'ozhandicraft',
        #            'fontname'  => 'OzHandicraftBT,Italic',
        #            'italicangle' => -15,
        #            'flags' => 96,
        #          },
        #  'ozhandicraftbolditalic'  => {
        #            'apiname' => 'Oz4',
        #            '-alias'  => 'ozhandicraft',
        #            'fontname'  => 'OzHandicraftBT,BoldItalic',
        #            'italicangle' => -15,
        #            'flags' => 96+262144,
        #          },
        #  'arialroundeditalic'  => {
        #            'apiname' => 'ArRo2',
        #            '-alias'  => 'arialrounded',
        #            'fontname'  => 'ArialRoundedMTBold,Italic',
        #            'italicangle' => -15,
        #            'flags' => 96+262144,
        #          },
        #  'arialitalic'  => {
        #            'apiname' => 'Ar2',
        #            '-alias'  => 'arial',
        #            'fontname'  => 'Arial,Italic',
        #            'italicangle' => -15,
        #            'flags' => 96,
        #          },
        #  'arialbolditalic'  => {
        #            'apiname' => 'Ar3',
        #            '-alias'  => 'arial',
        #            'fontname'  => 'Arial,BoldItalic',
        #            'italicangle' => -15,
        #            'flags' => 96+262144,
        #          },
        #  'arialbold'  => {
        #            'apiname' => 'Ar4',
        #            '-alias'  => 'arial',
        #            'fontname'  => 'Arial,Bold',
        #            'flags' => 32+262144,
        #          },
        #  'bankgothicbold'  => {
        #            'apiname' => 'Bg2',
        #            '-alias'  => 'bankgothic',
        #            'fontname'  => 'BankGothicMediumBT,Bold',
        #            'flags' => 32+262144,
        #          },
        #  'bankgothicbolditalic'  => {
        #            'apiname' => 'Bg3',
        #            '-alias'  => 'bankgothic',
        #            'fontname'  => 'BankGothicMediumBT,BoldItalic',
        #            'italicangle' => -15,
        #            'flags' => 96+262144,
        #          },
        #  'bankgothicitalic'  => {
        #            'apiname' => 'Bg4',
        #            '-alias'  => 'bankgothic',
        #            'fontname'  => 'BankGothicMediumBT,Italic',
        #            'italicangle' => -15,
        #            'flags' => 96,
        #          },
    };

    $fonts = { };

}

1;

__END__

=back

=head1 SUPPORTED FONTS

=item PDF::API::CoreFont supports the following 'Adobe Core Fonts':

  Courier
  Courier-Bold
  Courier-BoldOblique
  Courier-Oblique
  Helvetica
  Helvetica-Bold
  Helvetica-BoldOblique
  Helvetica-Oblique
  Symbol
  Times-Bold
  Times-BoldItalic
  Times-Italic
  Times-Roman
  ZapfDingbats

=item PDF::API::CoreFont supports the following 'Windows Fonts':

  Georgia
  Georgia,Bold
  Georgia,BoldItalic
  Georgia,Italic
  Verdana
  Verdana,Bold
  Verdana,BoldItalic
  Verdana,Italic
  Webdings
  Wingdings

=head1 AUTHOR

alfred reibenschuh

=head1 HISTORY

    $Log: CoreFont.pm,v $
    Revision 1.4  2004/06/07 19:44:43  fredo
    cleaned out cr+lf for lf

    Revision 1.3  2003/12/08 13:06:01  Administrator
    corrected to proper licencing statement

    Revision 1.2  2003/11/30 17:32:48  Administrator
    merged into default

    Revision 1.1.1.1.2.2  2003/11/30 16:57:05  Administrator
    merged into default

    Revision 1.1.1.1.2.1  2003/11/30 14:45:22  Administrator
    added CVS id/log


=cut


