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
#   $Id: API2.pm,v 1.24 2004/04/07 10:48:53 fredo Exp $
#
#=======================================================================

package PDF::API2;

BEGIN {

    use vars qw( $VERSION $RELEASEVERSION $seq @FontDirs );

    ( $VERSION ) = '$Revision: 1.24 $' =~ /Revision: (\S+)\s/; # $Date: 2004/04/07 10:48:53 $

    @FontDirs = ( (map { "$_/PDF/API2/fonts" } @INC), 
        qw( /usr/share/fonts /usr/local/share/fonts c:/windows/fonts c:/winnt/fonts ) );

    use PDF::API2::Version;
    
    $RELEASEVERSION = $PDF::API2::Version::VERSION;

    $seq="AA";

    require 5.008; # we need this for unicode support

    use PDF::API2::Basic::PDF::File;
    use PDF::API2::Basic::PDF::Page;
    use PDF::API2::Basic::PDF::Utils;

    use PDF::API2::Util;
    use PDF::API2::Page;
    use PDF::API2::IOString;

    use PDF::API2::Outlines;

    use PDF::API2::Resource::ExtGState;

    use PDF::API2::Resource::Font::CoreFont;
    use PDF::API2::Resource::Font::Postscript;
    use PDF::API2::Resource::Font::SynFont;
    use PDF::API2::Resource::CIDFont::TrueType;
    use PDF::API2::Resource::CIDFont::CJKFont;

    use PDF::API2::Resource::XObject::Image::JPEG;
    use PDF::API2::Resource::XObject::Image::TIFF;
    use PDF::API2::Resource::XObject::Image::PNM;
    use PDF::API2::Resource::XObject::Image::PNG;
    use PDF::API2::Resource::XObject::Image::GIF;
    use PDF::API2::Resource::XObject::Image::GD;

    use PDF::API2::Resource::XObject::Form::Hybrid;

    use PDF::API2::Resource::XObject::Form::BarCode::int2of5;
    use PDF::API2::Resource::XObject::Form::BarCode::codabar;
    use PDF::API2::Resource::XObject::Form::BarCode::code128;
    use PDF::API2::Resource::XObject::Form::BarCode::code3of9;
    use PDF::API2::Resource::XObject::Form::BarCode::ean13;

    use PDF::API2::Resource::ColorSpace::Indexed::ACTFile;
    use PDF::API2::Resource::ColorSpace::Indexed::Hue;
    use PDF::API2::Resource::ColorSpace::Indexed::WebColor;

    use PDF::API2::Resource::ColorSpace::Separation;
    
    use Compress::Zlib;

    use Math::Trig;

    use POSIX qw( ceil floor );

    use utf8;
    use Encode qw(:all);

}


=head1 NAME

PDF::API2 - A Perl Module Chain to faciliate the Creation and Modification of High-Quality "Portable Document Format (aka. PDF)" Files.

=head1 SYNOPSIS

    use PDF::API2;
    #
    $pdf = PDF::API2->new;
    $pdf = PDF::API2->open('some.pdf');
    $page = $pdf->page;
    $page = $pdf->openpage($pagenum);
    $img = $pdf->image('some.jpg');
    $font = $pdf->corefont('Times-Roman');
    $font = $pdf->ttfont('TimesNewRoman.ttf');

=head1 GENERIC METHODS

=over 4

=item $pdf = PDF::API->new %opts

Creates a new pdf-file object. If you know beforehand
to save the pdf to file you can give the '-file' option,
to minimize possible memory requirements later-on.

B<Example:>

    $pdf = PDF::API2->new();

    $pdf = PDF::API2->new(-file => 'our/new.pdf');

=cut

sub new {
    my $class=shift(@_);
    my %opt=@_;
    my $self={};
    bless($self,$class);
    $self->{pdf}=PDF::API2::Basic::PDF::File->new();
    $self->{time}='_'.pdfkey(time());

    $self->{pdf}->{' version'} = 4;
    $self->{pages} = PDF::API2::Basic::PDF::Pages->new($self->{pdf});
    $self->{pages}->proc_set(qw( PDF Text ImageB ImageC ImageI ));
    $self->{pages}->{Resources}||=PDFDict();
    $self->{pdf}->new_obj($self->{pages}->{Resources}) unless($self->{pages}->{Resources}->is_obj($self->{pdf}));
    $self->{catalog}=$self->{pdf}->{Root};
    $self->{fonts}={};
    $self->{pagestack}=[];
    $self->{forcecompress}= ($^O eq 'os390') ? 0 : 1;
    $self->preferences(%opt);
    if($opt{-file}) {
        $self->{' filed'}=$opt{-file};
        $self->{pdf}->create_file($opt{-file});
    }
    $self->info( 'Producer' => "PDF::API2 v=$RELEASEVERSION($VERSION) os=$^O" );
    return $self;
}

=item $pdf = PDF::API->open $pdffile

Opens an existing PDF for modification.

=cut

sub open {
    my $class=shift(@_);
    my $file=shift(@_);
    my %opt=@_;
    my $self={};
    bless($self,$class);
    $self->default('Compression',1);
    $self->default('subset',1);
    $self->default('update',1);
    foreach my $para (keys(%opt)) {
        $self->default($para,$opt{$para});
    }
    die "File '$file' does not exist." unless(-f $file);
    my $fh=PDF::API2::IOString->new();
    $fh->import_from_file($file);
    $self->{pdf}=PDF::API2::Basic::PDF::File->open_swallowed($fh,1);
    $self->{pdf}->{' fname'}=$file;
    $self->{pdf}->{'Root'}->realise;
    $self->{pages}=$self->{pdf}->{'Root'}->{'Pages'}->realise;
    $self->{pdf}->{' version'} = 3;
    $self->{pdf}->{' apipagecount'} = 0;
    my @pages=proc_pages($self->{pdf},$self->{pages});
    $self->{pagestack}=[sort {$a->{' pnum'} <=> $b->{' pnum'}} @pages];
    $self->{catalog}=$self->{pdf}->{Root};
    $self->{reopened}=1;
    $self->{time}='_'.pdfkey(time());
    $self->{forcecompress}= ($^O eq 'os390') ? 0 : 1;
    $self->{fonts}={};
    return $self;
}

=item $pdf = PDF::API->openScalar $pdfstream

Opens an existing PDF-stream for modification.

=cut

sub openScalar {
    my $class=shift(@_);
    my $file=shift(@_);
    my %opt=@_;
    my $self={};
    bless($self,$class);
    $self->default('Compression',1);
    $self->default('subset',1);
    $self->default('update',1);
    foreach my $para (keys(%opt)) {
        $self->default($para,$opt{$para});
    }
    my $fh=PDF::API2::IOString->new();
    $fh->import_from_scalar($file);
    $self->{pdf}=PDF::API2::Basic::PDF::File->open_swallowed($fh,1);
    $self->{pdf}->{'Root'}->realise;
    $self->{pages}=$self->{pdf}->{'Root'}->{'Pages'}->realise;
    $self->{pdf}->{' version'} = 3;
    $self->{pdf}->{' apipagecount'} = 0;
    my @pages=proc_pages($self->{pdf},$self->{pages});
    $self->{pagestack}=[sort {$a->{' pnum'} <=> $b->{' pnum'}} @pages];
    $self->{catalog}=$self->{pdf}->{Root};
    $self->{reopened}=1;
    $self->{time}='_'.pdfkey(time());
    $self->{forcecompress}= ($^O eq 'os390') ? 0 : 1;
    $self->{fonts}={};
    return $self;
}

=item $pdf->preferences %opts

Controls viewing-preferences for the pdf.

=cut

=pod

B<Page Mode Options:>

I<-fullscreen>
... Full-screen mode, with no menu bar, window controls, or any other window visible.

I<-thumbs>
... Thumbnail images visible.

I<-outlines>
... Document outline visible.

=cut

=pod

B<Page Layout Options:>

I<-singlepage>
... Display one page at a time.

I<-onecolumn>
... Display the pages in one column.

I<-twocolumnleft>
... Display the pages in two columns, with oddnumbered pages on the left.

I<-twocolumnrigth>
... Display the pages in two columns, with oddnumbered pages on the right.

=cut

=pod

B<Viewer Options:>

I<-hidetoolbar>
        ... Specifying whether to hide tool bars.

I<-hidemenubar>
        ... Specifying whether to hide menu bars.

I<-hidewindowui>
        ... Specifying whether to hide user interface elements.

I<-fitwindow>
        ... Specifying whether to resize the document’s window to the size of the displayed page.

I<-centerwindow>
        ... Specifying whether to position the document’s window in the center of the screen.

I<-displaytitle>
        ... Specifying whether the window’s title bar should display the document title
        taken from the Title entry of the document information dictionary.

I<-afterfullscreenthumbs>
        ... Thumbnail images visible after Full-screen mode.

I<-afterfullscreenoutlines>
        ... Document outline visible after Full-screen mode.

=cut

=pod

B<Initial Page Option:>

I<-firstpage> => [ $pageobj, %opts]
        ... Specifying the page to be displayed, plus one of the following options:

=cut

=pod

B<Initial Page Options:>

I<-fit> => 1
            ... Display the page designated by page, with its contents magnified just enough to
            fit the entire page within the window both horizontally and vertically. If the
            required horizontal and vertical magnification factors are different, use the
            smaller of the two, centering the page within the window in the other dimension.

I<-fith> => $top
            ... Display the page designated by page, with the vertical coordinate top positioned
            at the top edge of the window and the contents of the page magnified just enough
            to fit the entire width of the page within the window.

I<-fitv> => $left
            ... Display the page designated by page, with the horizontal coordinate left positioned
            at the left edge of the window and the contents of the page magnified just enough
            to fit the entire height of the page within the window.

I<-fitr> => [ $left, $bottom, $right, $top ]
            ... Display the page designated by page, with its contents magnified just enough to
            fit the rectangle specified by the coordinates left, bottom, right, and top
            entirely within the window both horizontally and vertically. If the required
            horizontal and vertical magnification factors are different, use the smaller of
            the two, centering the rectangle within the window in the other dimension.

I<-fitb> => 1
            ... Display the page designated by page, with its contents magnified just enough
            to fit its bounding box entirely within the window both horizontally and
            vertically. If the required horizontal and vertical magnification factors are
            different, use the smaller of the two, centering the bounding box within the
            window in the other dimension.

I<-fitbh> => $top
            ... Display the page designated by page, with the vertical coordinate top
            positioned at the top edge of the window and the contents of the page
            magnified just enough to fit the entire width of its bounding box
            within the window.

I<-fitbv> => $left
            ... Display the page designated by page, with the horizontal coordinate
            left positioned at the left edge of the window and the contents of the page
            magnified just enough to fit the entire height of its bounding box within the
            window.

I<-xyz> => [ $left, $top, $zoom ]
            ... Display the page designated by page, with the coordinates (left, top) positioned
            at the top-left corner of the window and the contents of the page magnified by
            the factor zoom. A zero (0) value for any of the parameters left, top, or zoom
            specifies that the current value of that parameter is to be retained unchanged.

=cut

=pod

B<Example:>

    $pdf->preferences(
        -fullscreen => 1,
        -onecolumn => 1,
        -afterfullscreenoutlines => 1,
        -firstpage => [ $pageobj , -fit => 1],
    );

=cut

sub preferences {
    my $self=shift @_;
    my %opt=@_;
    if($opt{-fullscreen}) {
        $self->{catalog}->{PageMode}=PDFName('FullScreen');
    } elsif($opt{-thumbs}) {
        $self->{catalog}->{PageMode}=PDFName('UseThumbs');
    } elsif($opt{-outlines}) {
        $self->{catalog}->{PageMode}=PDFName('UseOutlines');
    } else {
        $self->{catalog}->{PageMode}=PDFName('UseNone');
    }
    if($opt{-singlepage}) {
        $self->{catalog}->{PageLayout}=PDFName('SinglePage');
    } elsif($opt{-onecolumn}) {
        $self->{catalog}->{PageLayout}=PDFName('OneColumn');
    } elsif($opt{-twocolumnleft}) {
        $self->{catalog}->{PageLayout}=PDFName('TwoColumnLeft');
    } elsif($opt{-twocolumnrigth}) {
        $self->{catalog}->{PageLayout}=PDFName('TwoColumnRight');
    } else {
        $self->{catalog}->{PageLayout}=PDFName('SinglePage');
    }

    $self->{catalog}->{ViewerPreferences}||=PDFDict();
    $self->{catalog}->{ViewerPreferences}->realise;

    if($opt{-hidetoolbar}) {
        $self->{catalog}->{ViewerPreferences}->{HideToolbar}=PDFBool(1);
    }
    if($opt{-hidemenubar}) {
        $self->{catalog}->{ViewerPreferences}->{HideMenubar}=PDFBool(1);
    }
    if($opt{-hidewindowui}) {
        $self->{catalog}->{ViewerPreferences}->{HideWindowUI}=PDFBool(1);
    }
    if($opt{-fitwindow}) {
        $self->{catalog}->{ViewerPreferences}->{FitWindow}=PDFBool(1);
    }
    if($opt{-centerwindow}) {
        $self->{catalog}->{ViewerPreferences}->{CenterWindow}=PDFBool(1);
    }
    if($opt{-displaytitle}) {
        $self->{catalog}->{ViewerPreferences}->{DisplayDocTitle}=PDFBool(1);
    }
    if($opt{-righttoleft}) {
        $self->{catalog}->{ViewerPreferences}->{Direction}=PDFName("R2L");
    }

    if($opt{-afterfullscreenthumbs}) {
        $self->{catalog}->{ViewerPreferences}->{NonFullScreenPageMode}=PDFName('UseThumbs');
    } elsif($opt{-afterfullscreenoutlines}) {
        $self->{catalog}->{ViewerPreferences}->{NonFullScreenPageMode}=PDFName('UseOutlines');
    } else {
        $self->{catalog}->{ViewerPreferences}->{NonFullScreenPageMode}=PDFName('UseNone');
    }

    if($opt{-firstpage}) {
        my ($page,%o)=@{$opt{-firstpage}};

        $o{-fit}=1 if(scalar(keys %o)<1);

        if(defined $o{-fit}) {
            $self->{catalog}->{OpenAction}=PDFArray($page,PDFName('Fit'));
        } elsif(defined $o{-fith}) {
            $self->{catalog}->{OpenAction}=PDFArray($page,PDFName('FitH'),PDFNum($o{-fith}));
        } elsif(defined $o{-fitb}) {
            $self->{catalog}->{OpenAction}=PDFArray($page,PDFName('FitB'));
        } elsif(defined $o{-fitbh}) {
            $self->{catalog}->{OpenAction}=PDFArray($page,PDFName('FitBH'),PDFNum($o{-fitbh}));
        } elsif(defined $o{-fitv}) {
            $self->{catalog}->{OpenAction}=PDFArray($page,PDFName('FitV'),PDFNum($o{-fitv}));
        } elsif(defined $o{-fitbv}) {
            $self->{catalog}->{OpenAction}=PDFArray($page,PDFName('FitBV'),PDFNum($o{-fitbv}));
        } elsif(defined $o{-fitr}) {
            die "insufficient parameters to -fitr => [] " unless(scalar @{$o{-fitr}} == 4);
            $self->{catalog}->{OpenAction}=PDFArray($page,PDFName('FitR'),map {PDFNum($_)} @{$o{-fitr}});
        } elsif(defined $o{-xyz}) {
            die "insufficient parameters to -xyz => [] " unless(scalar @{$o{-xyz}} == 3);
            $self->{catalog}->{OpenAction}=PDFArray($page,PDFName('XYZ'),map {PDFNum($_)} @{$o{-xyz}});
        }
    }
    $self->{pdf}->out_obj($self->{catalog});

    return $self;
}

=item $val = $pdf->default $parameter

=item $pdf->default $parameter, $val

Gets/Sets default values for the behaviour of ::API2.

=cut

sub default {
    my ($self,$parameter,$var)=@_;
    $parameter=~s/[^a-zA-Z\d]//g;
    $parameter=lc($parameter);
    my $temp=$self->{$parameter};
    if(defined $var) {
        $self->{$parameter}=$var;
    }
    return($temp);
}

=item $bool = $pdf->isEncrypted

Checks if the previously opened pdf is encrypted.

=cut

sub isEncrypted {
    my $self=shift @_;
    return(defined($self->{pdf}->{'Encrypt'}) ? 1 : 0);
}
    
=item %infohash $pdf->info %infohash

Sets/Gets the info structure of the document.

B<Example:>

    $pdf->info(
        'Author'       => " Alfred Reibenschuh ",
        'CreationDate' => "D:20020911000000+01'00'",
        'ModDate'      => "D:YYYYMMDDhhmmssOHH'mm'",
        'Creator'      => "fredos-script.pl",
        'Producer'     => "PDF::API2",
        'Title'        => "some Publication",
        'Subject'      => "perl ?",
        'Keywords'     => "all good things are pdf"
    );

=cut

sub info {
    my $self=shift @_;
    my %opt=@_;

    if(!defined($self->{pdf}->{'Info'})) {
            $self->{pdf}->{'Info'}=PDFDict();
            $self->{pdf}->new_obj($self->{'pdf'}->{'Info'});
    } else {
        $self->{pdf}->{'Info'}->realise;
    }

    if(scalar @_) {
      foreach my $k (qw(  Author CreationDate ModDate Creator Producer Title Subject Keywords  )) {
        next unless(defined $opt{$k});
        if(is_utf8($opt{$k}) || utf8::valid($opt{$k})) {
            $self->{pdf}->{'Info'}->{$k}=PDFUtf($opt{$k}||'')
        } else {
            $self->{pdf}->{'Info'}->{$k}=PDFStr($opt{$k}||'')
        }
      }
      $self->{pdf}->out_obj($self->{pdf}->{'Info'});
    }


    if(defined $self->{pdf}->{'Info'}) {
      %opt=();
      foreach my $k (qw(  Author CreationDate ModDate Creator Producer Title Subject Keywords  )) {
        next unless(defined $self->{pdf}->{'Info'}->{$k});
        $opt{$k}=$self->{pdf}->{'Info'}->{$k}->val;
        if(unpack('n',$opt{$_})==0xfffe) {
            my ($mark,@c)=unpack('n*',$opt{$k});
            $opt{$k}=pack('U*',@c);
        } elsif(unpack('n',$opt{$k})==0xfeff) {
            my ($mark,@c)=unpack('v*',$opt{$k});
            $opt{$k}=pack('U*',@c);
        }
      }
  }
  return(%opt);
}

=item $pdf->finishobjects @objects

Force objects to be written to file.

=cut

sub finishobjects {
    my ($self,@objs)=@_;
    if($self->{reopened}) {
        die "invalid method invokation: no file, use 'saveas' instead.";
    } elsif($self->{' filed'}) {
        $self->{pdf}->ship_out(@objs);
    } else {
        die "invalid method invokation: no file, use 'saveas' instead.";
    }
}

sub proc_pages {
    my ($pdf, $pgs) = @_;
    my ($pg, $pgref, @pglist);

    if(defined($pgs->{Resources})) {
        eval {
            $pgs->{Resources}->realise;
        };
    }
    foreach $pgref ($pgs->{'Kids'}->elementsof) {
        $pg = $pdf->read_obj($pgref);
        if ($pg->{'Type'}->val =~ m/^Pages$/o) {
            push(@pglist, proc_pages($pdf, $pg));
        } else {
            $pdf->{' apipagecount'}++;
            $pgref->{' pnum'} = $pdf->{' apipagecount'};
            if(defined($pg->{Resources})) {
                eval {
                    $pg->{Resources}->realise;
                };
            }
            push (@pglist, $pgref);
        }
    }
    return(@pglist);
}

=item $pdf->update

Updates a previously "opened" document after all changes have been applied.

=cut

sub update {
    my $self=shift @_;
    $self->saveas($self->{pdf}->{' fname'});
}

=item $pdf->saveas $file

Saves the document to file.

=cut

sub saveas {
    my ($self,$file)=@_;
    if($self->{reopened}) {
        $self->{pdf}->append_file;
        CORE::open(OUTF,">$file");
        binmode(OUTF,':raw');
        print OUTF ${$self->{pdf}->{' OUTFILE'}->string_ref};
        CORE::close(OUTF);
    } elsif($self->{' filed'}) {
        $self->{pdf}->close_file;
    } else {
        $self->{pdf}->out_file($file);
    }
    $self->end;
}

sub save {
    my ($self,$file)=@_;
    if($self->{reopened}) {
        die "invalid method invokation: use 'saveas' instead.";
    } elsif($self->{' filed'}) {
        $self->{pdf}->close_file;
    } else {
        die "invalid method invokation: use 'saveas' instead.";
    }
    $self->end;
}

sub save_xml {
    my ($self,$file)=@_;
    my $fh=IO::File->new;
    $fh->open("> $file");
    $self->{pdf}->save_xml($fh);
    $fh->close;
    $self->end;
}


=item $string = $pdf->stringify

Returns the document in a string.

=cut

sub stringify {
    my ($self)=@_;
    my $str;
    if((defined $self->{reopened}) && ($self->{reopened}==1)) {
        $self->{pdf}->append_file;
        $str=${$self->{pdf}->{' OUTFILE'}->string_ref};
    } else {
        my $fh = PDF::API2::IOString->new();
        $fh->open();
        eval {
            $self->{pdf}->out_file($fh);
        };
        $str=${$fh->string_ref};
        $fh->realclose;
    }
    $self->end;
    return($str);
}

sub release { $_[0]->end; return(undef);}

=item $pdf->end

Destroys the document.

=cut

sub end {
    my $self=shift(@_);
    $self->{pdf}->release if(defined($self->{pdf}));

        foreach my $key (keys %{$self})
        {
            $self->{$key}=undef;
            delete ($self->{$key});
        }

    undef;
}

=back

=head1 PAGE METHODS

=over 4

=item $page = $pdf->page

=item $page = $pdf->page $index

Returns a new page object or inserts-and-returns a new page at $index.

B<Note:> on $index

    -1 ... is inserted before the last page
    1 ... is inserted before page number 1 (the first page)
    0 ... is simply appended

=cut

sub page {
    my $self=shift;
    my $index=shift || 0;
    my $page;
    if($index==0) {
        $page=PDF::API2::Page->new($self->{pdf},$self->{pages});
    } else {
        $page=PDF::API2::Page->new($self->{pdf},$self->{pages},$index);
    }
    $page->{' apipdf'}=$self->{pdf};
    $page->{' api'}=$self;
    $self->{pdf}->out_obj($page);
    $self->{pdf}->out_obj($self->{pages});
    if($index==0) {
        push(@{$self->{pagestack}},$page);
    } elsif($index<0) {
        splice(@{$self->{pagestack}},$index,0,$page);
    } else {
        splice(@{$self->{pagestack}},$index-1,0,$page);
    }
 #   $page->{Resources}=$self->{pages}->{Resources};
    return $page;
}

=item $pageobj = $pdf->openpage $index

Returns the pageobject of page $index.

B<Note:> on $index

    -1,0 ... returns the last page
    1 ... returns page number 1

=cut

sub openpage {
    my $self=shift @_;
    my $index=shift @_||0;
    my ($page,$rotate,$media,$trans);

    if($index==0) {
        $page=$self->{pagestack}->[-1];
    } elsif($index<0) {
        $page=$self->{pagestack}->[$index];
    } else {
        $page=$self->{pagestack}->[$index-1];
    }
    if(ref($page) ne 'PDF::API2::Page') {
        bless($page,'PDF::API2::Page');
        $page->{' apipdf'}=$self->{pdf};
        $page->{' api'}=$self;
        $self->{pdf}->out_obj($page);
        if(($rotate=$page->find_prop('Rotate')) && (!defined($page->{' fixed'}) || $page->{' fixed'}<1)) {
            $rotate=($rotate->val+360)%360;

            if($rotate!=0) {
                $page->{Rotate}=PDFNum(0);
                foreach my $mediatype (qw( MediaBox CropBox BleedBox TrimBox ArtBox )) {
                    if($media=$page->find_prop($mediatype)) {
                        $media=[ map{ $_->val } $media->elementsof ];
                    } else {
                        $media=[0,0,612,792];
                        next if($mediatype ne 'MediaBox');
                    }
                    if($rotate==90) {
                        $trans="0 -1 1 0 0 $media->[2] cm" if($mediatype eq 'MediaBox');
                        $media=[$media->[1],$media->[0],$media->[3],$media->[2]];
                    } elsif($rotate==180) {
                        $trans="-1 0 0 -1 $media->[2] $media->[3] cm" if($mediatype eq 'MediaBox');
                    } elsif($rotate==270) {
                        $trans="0 1 -1 0 $media->[3] 0 cm" if($mediatype eq 'MediaBox');
                        $media=[$media->[1],$media->[0],$media->[3],$media->[2]];
                    }
                    $page->{$mediatype}=PDFArray(map { PDFNum($_) } @{$media});
                }
            } else {
                $trans="";
            }
        } else {
            $trans="";
        }

        if(defined $page->{Contents} && (!defined($page->{' fixed'}) || $page->{' fixed'}<1) ) {
            $page->fixcontents;
            my $uncontent=$page->{Contents};
            delete $page->{Contents};
            my $content=$page->gfx();
            $content->add(" $trans ");

            foreach my $k ($uncontent->elementsof) {
                $k->realise;
                $content->{' stream'}.=" ".unfilter($k->{Filter}, $k->{' stream'})." ";
            }

            ## $content->{Length}=PDFNum(length($content->{' stream'}));
            # this  will be fixed by the following code or content or filters

            ## if we like compress we will do it now to do quicker saves
            if($self->{forcecompress}>0){
                $content->compress;
                $content->{' stream'}=dofilter($content->{Filter}, $content->{' stream'});
                $content->{' nofilt'}=1;
                $content->{Length}=PDFNum(length($content->{' stream'}));
            }
            $page->{' fixed'}=1;
        }
    }

    $self->{pdf}->out_obj($page);
    $self->{pdf}->out_obj($self->{pages});
    $page->{' apipdf'}=$self->{pdf};
    $page->{' api'}=$self;
    $page->{' reopened'}=1;
    return($page);
}


# $target_object = walk_obj $obj_cache, $source_pdf, $target_pdf, $source_object [, @keys_to_copy ]

sub walk_obj {
    my ($objs,$spdf,$tpdf,$obj,@keys)=@_;

    my $tobj;


    if(ref($obj)=~/Objind$/) {
        $obj->realise;
    }

    return($objs->{scalar $obj}) if(defined $objs->{scalar $obj});
##  die "infinite loop while copying objects" if($obj->{' copied'});
    $tobj=$obj->copy;
##  $obj->{' copied'}=1;
    $tpdf->new_obj($tobj) if($obj->is_obj($spdf));

    $objs->{scalar $obj}=$tobj;

    if(ref($obj)=~/Array$/) {
        $tobj->{' val'}=[];
        foreach my $k ($obj->elementsof) {
            $k->realise if(ref($k)=~/Objind$/);
            $tobj->add_elements(walk_obj($objs,$spdf,$tpdf,$k));
        }
    } elsif(ref($obj)=~/Dict$/) {
        @keys=keys(%{$tobj}) if(scalar @keys <1);
        foreach my $k (@keys) {
            next if($k=~/^ /);
            next unless(defined($obj->{$k}));
            $tobj->{$k}=walk_obj($objs,$spdf,$tpdf,$obj->{$k});
        }
        if($obj->{' stream'}) {
            if($tobj->{Filter}) {
                $tobj->{' nofilt'}=1;
            } else {
                delete $tobj->{' nofilt'};
                $tobj->{Filter}=PDFArray(PDFName('FlateDecode'));
            }
            $tobj->{' stream'}=$obj->{' stream'};
        }
    }
    delete $tobj->{' streamloc'};
    delete $tobj->{' streamsrc'};
    return($tobj);
}

=item $xoform = $pdf->importPageIntoForm $sourcepdf, $sourceindex

Returns a form-xobject created from $sourcepdf,$sourceindex.
This is useful if you want to transpose the imported page-description
somewhat differently onto a page (ie. two-up, four-up, duplex, etc.).

B<Note:> on $index

    -1,0 ... returns the last page
    1 ... returns page number 1

=cut

sub importPageIntoForm {
    my $self=shift @_;
    my $s_pdf=shift @_;
    my $s_idx=shift @_||0;

    my ($s_page,$xo);

    $xo=$self->xo_form;

    if(ref($s_idx) eq 'PDF::API2::Page') {
        $s_page=$s_idx;
    } else {
        $s_page=$s_pdf->openpage($s_idx);
    }

    $self->{apiimportcache}||={};
    $self->{apiimportcache}->{$s_pdf}||={};

    foreach my $k (qw( MediaBox ArtBox TrimBox BleedBox CropBox )) {
        next unless(defined $s_page->{$k});
        my $box = walk_obj($self->{apiimportcache}->{$s_pdf},$s_pdf->{pdf},$self->{pdf},$s_page->{$k});
        $xo->bbox(map { $_->val } $box->elementsof);
        last;
    }
    $xo->bbox( 0, 0, 612, 792) unless(defined $xo->{BBox});

    foreach my $k (qw( Resources )) {
        $s_page->{$k}=$s_page->find_prop($k);
        next unless(defined $s_page->{$k});
        $s_page->{$k}->realise if(ref($s_page->{$k})=~/Objind$/);

        foreach my $sk (qw( XObject ExtGState Font ProcSet Properties ColorSpace Pattern Shading )) {
            next unless(defined $s_page->{$k}->{$sk});
            $s_page->{$k}->{$sk}->realise if(ref($s_page->{$k}->{$sk})=~/Objind$/);
            foreach my $ssk (keys %{$s_page->{$k}->{$sk}}) {
                next if($ssk=~/^ /);
                $xo->resource($sk,$ssk,walk_obj($self->{apiimportcache}->{$s_pdf},$s_pdf->{pdf},$self->{pdf},$s_page->{$k}->{$sk}->{$ssk}));
            }
        }
    }

    # create a whole content stream
    ## technically it is possible to submit an unfinished
    ## (eg. newly created) source-page, but thats non-sense,
    ## so we expect a page fixed by openpage and die otherwise
    die "page not processed via openpage ... " unless($s_page->{' fixed'}==1);

    # since the source page comes from openpage it may already
    # contains the required starting 'q' without the final 'Q'
    # if forcecompress is in effect
    if(defined $s_page->{Contents}) {
        $s_page->fixcontents;

        $xo->{' stream'}="";
        # openpage pages only contain one stream
        my ($k)=$s_page->{Contents}->elementsof;
        $k->realise;
        if($k->{' nofilt'}) {
          # we have a finished stream here
          # so we unfilter
          $xo->add('q',unfilter($k->{Filter}, $k->{' stream'}),'Q');
        } else {
          # stream is an unfinished/unfiltered content
          # so we just copy it and add the required "qQ"
            $xo->add('q',$k->{' stream'},'Q');
        }
        $xo->compress if($self->{forcecompress}>0);
    }

    return($xo);
}

=item $pageobj = $pdf->importpage $sourcepdf, $sourceindex, $targetindex

Returns the pageobject of page $targetindex, imported from $sourcepdf,$sourceindex.

B<Note:> on $index

    -1,0 ... returns the last page
    1 ... returns page number 1

B<Note:> you can specify a page object instead as $targetindex
so that the contents of the sourcepage will be 'merged into'.

=cut

# B<Note:> the interactive forms of a page will also be imported, but may
# cause problems if forms of another document have already been imported.

sub importpage {
    my $self=shift @_;
    my $s_pdf=shift @_;
    my $s_idx=shift @_||0;
    my $t_idx=shift @_||0;
    my ($s_page,$t_page);

    if(ref($s_idx) eq 'PDF::API2::Page') {
        $s_page=$s_idx;
    } else {
        $s_page=$s_pdf->openpage($s_idx);
    }

    if(ref($t_idx) eq 'PDF::API2::Page') {
        $t_page=$t_idx;
    } else {
        $t_idx=0 if($self->pages<$t_idx);
        $t_page=$self->page($t_idx);
    }

    $self->{apiimportcache}=$self->{apiimportcache}||{};
    $self->{apiimportcache}->{$s_pdf}=$self->{apiimportcache}->{$s_pdf}||{};

    # we now import into a form to keep
    # all that nasty resources from polluting
    # our very own resource naming space.
    my $xo = $self->importPageIntoForm($s_pdf,$s_page);
    $t_page->mediabox( map { $_->val } $xo->{BBox}->elementsof) if(defined $xo->{BBox});
    $t_page->gfx->formimage($xo,0,0,1);

#    # copy annotations and/or form elements as well
#    if (exists $s_page->{Annots} and $s_page->{Annots}) {
#
#            # first set up the AcroForm, if required
#            my $AcroForm;
#            if (my $a = $s_pdf->{pdf}->{Root}->realise->{AcroForm}) {
#                    $a->realise;
#
#                    $AcroForm = walk_obj({},$s_pdf->{pdf},$self->{pdf},$a,qw( NeedAppearances SigFlags CO DR DA Q ));
#            }
#            my @Fields = ();
#            my @Annots = ();
#            foreach my $a ($s_page->{Annots}->elementsof) {
#                    $a->realise;
#                    my $t_a = PDFDict();
#                    $self->{pdf}->new_obj($t_a);
#                    # these objects are likely to be both annotations and Acroform fields
#                    # key names are copied from PDF Reference 1.4 (Tables)
#                    my @k = (
#                            qw( Type Subtype Contents P Rect NM M F BS Border AP AS C CA T Popup A AA StructParent
#                            ),                                      # Annotations - Common (8.10)
#                            qw( Subtype Contents Open Name ),       # Text Annotations (8.15)
#                            qw( Subtype Contents Dest H PA ),       # Link Annotations (8.16)
#                            qw( Subtype Contents DA Q ),            # Free Text Annotations (8.17)
#                            qw( Subtype Contents L BS LE IC ) ,     # Line Annotations (8.18)
#                            qw( Subtype Contents BS IC ),           # Square and Circle Annotations (8.20)
#                            qw( Subtype Contents QuadPoints ),      # Markup Annotations (8.21)
#                            qw( Subtype Contents Name ),            # Rubber Stamp Annotations (8.22)
#                            qw( Subtype Contents InkList BS ),      # Ink Annotations (8.23)
#                            qw( Subtype Contents Parent Open ),     # Popup Annotations (8.24)
#                            qw( Subtype FS Contents Name ),         # File Attachment Annotations (8.25)
#                            qw( Subtype Sound Contents Name ),      # Sound Annotations (8.26)
#                            qw( Subtype Movie Contents A ),         # Movie Annotations (8.27)
#                            qw( Subtype Contents H MK ),            # Widget Annotations (8.28)
#                                                                    # Printers Mark Annotations (none)
#                                                                    # Trap Network Annotations (none)
#                    );
#                    push @k, (
#                            qw( Subtype FT Parent Kids T TU TM Ff V DV AA
#                            ),                                      # Fields - Common (8.49)
#                            qw( DR DA Q ),                          # Fields containing variable text (8.51)
#                            qw( Opt ),                              # Checkbox field (8.54)
#                            qw( Opt ),                              # Radio field (8.55)
#                            qw( MaxLen ),                           # Text field (8.57)
#                            qw( Opt TI I ),                         # Choice field (8.59)
#                    ) if $AcroForm;
#                    # sorting out dups
#                    my %ky=map { $_ => 1 } @k;
#                    # we do P separately, as it points to the page the Annotation is on
#                    delete $ky{P};
#                    # copy everything else
#                    foreach my $k (keys %ky) {
#                            next unless defined $a->{$k};
#                            $t_a->{$k} = walk_obj({},$s_pdf->{pdf},$self->{pdf},$a->{$k});
#                    }
#                    $t_a->{P} = $t_page;
#                    push @Annots, $t_a;
#                    push @Fields, $t_a if ($AcroForm and $t_a->{Subtype}->val eq 'Widget');
#            }
#            $t_page->{Annots} = PDFArray(@Annots);
#            $AcroForm->{Fields} = PDFArray(@Fields) if $AcroForm;
#            $self->{pdf}->{Root}->{AcroForm} = $AcroForm;
#    }

    $t_page->{' imported'} = 1;

    $self->{pdf}->out_obj($t_page);
    $self->{pdf}->out_obj($self->{pages});

    return($t_page);
}

=item $pagenumber = $pdf->pages

Returns the number of pages in the document.

=cut

sub pages {
    my $self=shift @_;
    return scalar @{$self->{pagestack}};
}

=item $pdf->mediabox $name

=item $pdf->mediabox $w, $h

=item $pdf->mediabox $llx, $lly, $urx, $ury

Sets the global mediabox. Other methods: cropbox, bleedbox, trimbox and artbox.

=cut

sub mediabox {
    my ($self,$x1,$y1,$x2,$y2) = @_;
    $self->{pages}->{'MediaBox'}=PDFArray( map { PDFNum(float($_)) } page_size($x1,$y1,$x2,$y2) );
    $self;
}

=item $pdf->cropbox $name

=item $pdf->cropbox $w, $h

=item $pdf->cropbox $llx, $lly, $urx, $ury

Sets the global cropbox.

=cut

sub cropbox {
    my ($self,$x1,$y1,$x2,$y2) = @_;
    $self->{pages}->{'CropBox'}=PDFArray( map { PDFNum(float($_)) } page_size($x1,$y1,$x2,$y2) );
    $self;
}

=item $pdf->bleedbox $name

=item $pdf->bleedbox $w, $h

=item $pdf->bleedbox $llx, $lly, $urx, $ury

Sets the global bleedbox.

=cut

sub bleedbox {
    my ($self,$x1,$y1,$x2,$y2) = @_;
    $self->{pages}->{'BleedBox'}=PDFArray( map { PDFNum(float($_)) } page_size($x1,$y1,$x2,$y2) );
    $self;
}

=item $pdf->trimbox $name

=item $pdf->trimbox $w, $h

=item $pdf->trimbox $llx, $lly, $urx, $ury

Sets the global trimbox.

=cut

sub trimbox {
    my ($self,$x1,$y1,$x2,$y2) = @_;
    $self->{pages}->{'TrimBox'}=PDFArray( map { PDFNum(float($_)) } page_size($x1,$y1,$x2,$y2) );
    $self;
}

=item $pdf->artbox $name

=item $pdf->artbox $w, $h

=item $pdf->artbox $llx, $lly, $urx, $ury

Sets the global artbox.

=cut

sub artbox {
    my ($self,$x1,$y1,$x2,$y2) = @_;
    $self->{pages}->{'ArtBox'}=PDFArray( map { PDFNum(float($_)) } page_size($x1,$y1,$x2,$y2) );
    $self;
}

=back

=head1 FONT METHODS

=over 4

=item @allFontDirs = PDF::API2::addFontDirs $dir1, ..., $dirN

Adds one or more directories to the search-path for finding font files.
Returns the list of searched directories.

=cut

sub addFontDirs {
    push( @FontDirs, @_ );
    return( @FontDirs );
}

sub __findFont {
    my $font=shift @_;
    my @fonts=($font,map { "$_/$font" } @FontDirs);
    while((scalar @fonts > 0) && (! -f $fonts[0])) { shift @fonts; }
    return($fonts[0]);
}

=item $font = $pdf->corefont $fontname [, %options]

Returns a new adobe core font object.

=cut

=pod

See L<PDF::API2::Resource::Font::CoreFont> for an explanation.


B<Examples:>

    $font = $pdf->corefont('Times-Roman');
    $font = $pdf->corefont('Times-Bold');
    $font = $pdf->corefont('Helvetica');
    $font = $pdf->corefont('ZapfDingbats');


Valid %options are:

  '-encode' ... changes the encoding of the font from its default.

=cut

sub corefont {
    my ($self,$name,@opts)=@_;
    my $obj=PDF::API2::Resource::Font::CoreFont->new_api($self,$name,@opts);
    $self->resource('Font',$obj->name,$obj);
    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=item $font = $pdf->psfont $psfile  [, %options]

Returns a new adobe type1 font object.

=cut

=pod

See L<PDF::API2::Resource::Font::Postscript> for an explanation.

B<Examples:>

    $font = $pdf->psfont( 'Times-Book.pfa', -afmfile => 'Times-Book.afm' );
    $font = $pdf->psfont( '/fonts/Synest-FB.pfb', -pfmfile => '/fonts/Synest-FB.pfm' );

Valid %options are:

  '-encode' ... changes the encoding of the font from its default.

  '-afmfile' ... specifies that font metrics to be read from the
                adobe font metrics file (AFM).

  '-pfmfile' ... specifies that font metrics to be read from the
                windows printer font metrics file (PFM).
                (this option overrides the -encode option)

=cut

sub psfont {
    my ($self,$psf,%opts)=@_;

    foreach my $o (qw(-afmfile -pfmfile)) {
        next unless(defined $opts{$o});
        $opts{$o}=_findFont($opts{$o});
    }
    $psf=_findFont($psf);
    my $obj=PDF::API2::Resource::Font::Postscript->new_api($self,$psf,%opts);

    $self->resource('Font',$obj->name,$obj,$self->{reopened});

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=item $font = $pdf->ttfont $ttfile  [, %options]

Returns a new truetype or opentype font object.

=cut

=pod

See L<PDF::API2::Resource::CIDFont::TrueType> for an explanation.

B<Examples:>

    $font = $pdf->ttfont('Times.ttf');
    $font = $pdf->ttfont('Georgia.otf');

Valid %options are:

  '-encode' ... changes the encoding of the font from its default.

=cut

sub ttfont {
    my ($self,$file,%opts)=@_;

    $file=_findFont($file);
    my $obj=PDF::API2::Resource::CIDFont::TrueType->new_api($self,$file,%opts);

    $self->resource('Font',$obj->name,$obj,$self->{reopened});

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=item $font = $pdf->cjkfont $cjkname  [, %options]

Returns a new cjk font object.

=cut

=pod

See L<PDF::API2::Resource::CIDFont::CJKFont> for an explanation.

B<Examples:>

    $font = $pdf->cjkfont('korean');
    $font = $pdf->cjkfont('traditional');

Valid %options are:

  '-encode' ... changes the encoding of the font from its default.

=cut

sub cjkfont {
    my ($self,$name,%opts)=@_;

    my $obj=PDF::API2::Resource::CIDFont::CJKFont->new_api($self,$name,%opts);

    $self->resource('Font',$obj->name,$obj,$self->{reopened});

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

sub synfont {
    my ($self,@opts)=@_;

    my $obj=PDF::API2::Resource::Font::SynFont->new_api($self,@opts);

    $self->resource('Font',$obj->name,$obj,$self->{reopened});

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=back

=head1 IMAGE METHODS

=over 4

=item $jpeg = $pdf->image_jpeg $file

Returns a new jpeg image object.

=cut

sub image_jpeg {
    my ($self,$file,%opts)=@_;

    my $obj=PDF::API2::Resource::XObject::Image::JPEG->new_api($self,$file);

    $self->resource('XObject',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=item $tiff = $pdf->image_tiff $file

Returns a new tiff image object.

=cut

sub image_tiff {
    my ($self,$file,%opts)=@_;

    my $obj=PDF::API2::Resource::XObject::Image::TIFF->new_api($self,$file);

    $self->resource('XObject',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=item $pnm = $pdf->image_pnm $file

Returns a new pnm image object.

=cut

sub image_pnm {
    my ($self,$file,%opts)=@_;

    my $obj=PDF::API2::Resource::XObject::Image::PNM->new_api($self,$file);

    $self->resource('XObject',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=item $png = $pdf->image_png $file

Returns a new png image object.

=cut

sub image_png {
    my ($self,$file,%opts)=@_;

    my $obj=PDF::API2::Resource::XObject::Image::PNG->new_api($self,$file);

    $self->resource('XObject',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=item $gif = $pdf->image_gif $file

Returns a new gif image object.

=cut

sub image_gif {
    my ($self,$file,%opts)=@_;

    my $obj=PDF::API2::Resource::XObject::Image::GIF->new_api($self,$file);

    $self->resource('XObject',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=item $gdf = $pdf->image_gd $gdobj

Returns a new image object from GD::Image.

=cut

sub image_gd {
    my ($self,$gd,%opts)=@_;

    my $obj=PDF::API2::Resource::XObject::Image::GD->new_api($self,$gd);

    $self->resource('XObject',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=pod

B<Examples:>

    $jpeg = $pdf->image_jpeg('../some/nice/picture.jpeg');
    $tiff = $pdf->image_tiff('../some/nice/picture.tiff');
    $pnm = $pdf->image_pnm('../some/nice/picture.pnm');
    $png = $pdf->image_png('../some/nice/picture.png');
    $gif = $pdf->image_gif('../some/nice/picture.gif');
    $gdf = $pdf->image_gd($gdobj);

=back

=head1 COLORSPACE METHODS

=over 4

=item $cs = $pdf->colorspace_act $file

Returns a new colorspace-object based on a adobe-color-table file.

=cut

=pod

See L<PDF::API2::Resource::ColorSpace::Indexed::ACTFile> for an explanation of the file format.

=cut

sub colorspace_act {
    my ($self,$file,%opts)=@_;

    my $obj=PDF::API2::Resource::ColorSpace::Indexed::ACTFile->new_api($self,$file);

    $self->resource('ColorSpace',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=item $cs = $pdf->colorspace_web

Returns a new colorspace-object based on the web color palette.

=cut

=pod

See L<PDF::API2::Resource::ColorSpace::Indexed::WebColor> for an explanation.

=cut

sub colorspace_web {
    my ($self,$file,%opts)=@_;

    my $obj=PDF::API2::Resource::ColorSpace::Indexed::WebColor->new_api($self);

    $self->resource('ColorSpace',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=item $cs = $pdf->colorspace_hue

Returns a new colorspace-object based on the hue color palette.

=cut

=pod

See L<PDF::API2::Resource::ColorSpace::Indexed::Hue> for an explanation.

=cut

sub colorspace_hue {
    my ($self,$file,%opts)=@_;

    my $obj=PDF::API2::Resource::ColorSpace::Indexed::Hue->new_api($self);

    $self->resource('ColorSpace',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=item $cs = $pdf->colorspace_separation $tint, $color

Returns a new limited separation colorspace-object based on the parameters.

=cut

=pod

I<$tint> can be any valid ink-identifier, including but not limited to:
'Cyan', 'Magenta', 'Yellow', 'Black', 'Red', 'Green', 'Blue' or 'Orange'.

I<$color> must be a valid color-specification limited to:
'#rrggbb', '!hhssvv', '%ccmmyykk' or a "named color" (rgb).

The colorspace model for will be automatically chosen based on the specified color.

B<WARNING:> this is NOT YET a full colorspace object, so it can only be used 
for gray-level bitmap-images.

=cut

sub colorspace_separation {
    my ($self,$name,@clr)=@_;
    my $obj=PDF::API2::Resource::ColorSpace::Separation->new_api($self,$name,@clr);

    $self->resource('ColorSpace',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=back

=head1 OTHER METHODS

=over 4

=item $xo = $pdf->xo_form

Returns a new form-xobject.

B<Examples:>

    $xo = $pdf->xo_form;

=cut

sub xo_form {
    my ($self)=@_;

    my $obj=PDF::API2::Resource::XObject::Form::Hybrid->new_api($self);

    $self->resource('XObject',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=item $egs = $pdf->egstate

Returns a new extended graphics state object.

B<Examples:>

    $egs = $pdf->egstate;

=cut

sub egstate {
    my ($self)=@_;

    my $obj=PDF::API2::Resource::ExtGState->new_api($self,pdfkey());

    $self->resource('ExtGState',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=item $otls = $pdf->outlines

Returns a new or existing outlines object.

=cut

sub outlines {
    my ($self)=@_;

    $self->{pdf}->{Root}->{Outlines}||=PDF::API2::Outlines->new($self);

    my $obj=$self->{pdf}->{Root}->{Outlines};

    $self->{pdf}->new_obj($obj) if(!$obj->is_obj($self->{pdf}));
    $self->{pdf}->out_obj($obj);
    $self->{pdf}->out_obj($self->{pdf}->{Root});

    return($obj);

}

=back

=head1 BARCODE METHODS

=over 4

=item $bc = $pdf->xo_codabar %opts

=item $bc = $pdf->xo_code128 %opts

=item $bc = $pdf->xo_2of5int %opts

=item $bc = $pdf->xo_3of9 %opts

=item $bc = $pdf->xo_ean13 %opts

creates the specified barcode object as a form-xo.

=cut

sub xo_code128 {
    my ($self,@opts)=@_;

    my $obj=PDF::API2::Resource::XObject::Form::BarCode::code128->new_api($self,@opts);

    $self->resource('XObject',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

sub xo_codabar {
    my ($self,@opts)=@_;

    my $obj=PDF::API2::Resource::XObject::Form::BarCode::codabar->new_api($self,@opts);

    $self->resource('XObject',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

sub xo_2of5int {
    my ($self,@opts)=@_;

    my $obj=PDF::API2::Resource::XObject::Form::BarCode::int2of5->new_api($self,@opts);

    $self->resource('XObject',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

sub xo_3of9 {
    my ($self,@opts)=@_;

    my $obj=PDF::API2::Resource::XObject::Form::BarCode::code3of9->new_api($self,@opts);

    $self->resource('XObject',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

sub xo_ean13 {
    my ($self,@opts)=@_;

    my $obj=PDF::API2::Resource::XObject::Form::BarCode::ean13->new_api($self,@opts);

    $self->resource('XObject',$obj->name,$obj);

    $self->{pdf}->out_obj($self->{pages});
    return($obj);
}

=back

=head1 RESOURCE METHODS

=over 4

=item $pdf->resource $type, $key, $obj, $force

Adds a resource to the global pdf tree.

B<Example:>

    $pdf->resource('Font',$fontkey,$fontobj);
    $pdf->resource('XObject',$imagekey,$imageobj);
    $pdf->resource('Shading',$shadekey,$shadeobj);
    $pdf->resource('ColorSpace',$spacekey,$speceobj);

B<Note:> You only have to add the required resources, if
they are NOT handled by the *font*, *image*, *shade* or *space*
methods.

=cut

sub resource {
    return(undef);
    my ($self, $type, $key, $obj, $force) = @_;

    $self->{pages}->{Resources}||=PDFDict();

    my $dict=$self->{pages}->{Resources};
    $dict->realise if(ref($dict)=~/Objind$/);

    $self->{pdf}->new_obj($dict) unless($dict->is_obj($self->{pdf}));

    $dict->{$type}=$dict->{$type} || PDFDict();
    $dict->{$type}->realise if(ref($dict->{$type})=~/Objind$/);

  unless(defined($obj)) {
    return($dict->{$type}->{$key} || undef);
  } else {
    if($force) {
        $dict->{$type}->{$key}=$obj;
    } else {
        $dict->{$type}->{$key}=$dict->{$type}->{$key} || $obj;
    }

    $self->{pdf}->out_obj($dict)
        if($dict->is_obj($self->{pdf}));

    $self->{pdf}->out_obj($dict->{$type})
        if($dict->{$type}->is_obj($self->{pdf}));

    $self->{pdf}->out_obj($obj)
        if($obj->is_obj($self->{pdf}));

          $self->{pdf}->out_obj($self->{pages});

    return($dict);
  }
}

1;

__END__

=back

=head1 AUTHOR

alfred reibenschuh

=head1 HISTORY

    $Log: API2.pm,v $
    Revision 1.24  2004/04/07 10:48:53  fredo
    fixed handling of ColorSpace/Separation

    Revision 1.23  2004/04/06 21:00:52  fredo
    separation colorspace now a full resource

    Revision 1.22  2004/04/04 23:42:10  fredo
    fixed 270 degree rotation in openpage

    Revision 1.21  2004/04/04 23:36:33  fredo
    added simple separation colorspace

    Revision 1.20  2004/03/20 09:11:45  fredo
    modified font search path methodname

    Revision 1.19  2004/03/20 08:38:38  fredo
    added isEncrypted determinator

    Revision 1.18  2004/03/18 09:43:32  fredo
    added font search path handling

    Revision 1.17  2004/02/12 14:38:33  fredo
    added openScalar method

    Revision 1.16  2004/02/05 13:18:39  fredo
    corrected info hash utf8 usage

    Revision 1.15  2004/02/04 23:43:53  fredo
    pdf info method now properly recognized utf8 parameters

    Revision 1.14  2004/01/21 12:29:06  fredo
    moved release versioning to PDF::API2::Version

    Revision 1.13  2004/01/19 14:16:32  fredo
    update for 0.40_16

    Revision 1.12  2004/01/15 21:26:04  fredo
    docbug: fixed inconsistent links

    Revision 1.11  2004/01/14 18:25:41  fredo
    release update 0.40_15

    Revision 1.10  2004/01/12 13:52:41  fredo
    update for 0.40_14

    Revision 1.9  2004/01/08 23:56:20  fredo
    corrected producer tag versioning, updated to release 0.40_13

    Revision 1.8  2003/12/08 13:05:18  Administrator
    corrected to proper licencing statement

    Revision 1.7  2003/12/08 11:47:38  Administrator
    change step 3 for proper module versioning

    Revision 1.6  2003/12/08 11:46:25  Administrator
    change step 2 for proper module versioning

    Revision 1.5  2003/12/08 11:43:10  Administrator
    change step 1 for proper module versioning

    Revision 1.4  2003/11/30 19:00:43  Administrator
    added Code128/EAN128

    Revision 1.3  2003/11/30 17:07:11  Administrator
    merged into default


=cut
