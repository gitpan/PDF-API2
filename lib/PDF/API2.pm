#=======================================================================
#	 ____  ____  _____              _    ____ ___   ____
#	|  _ \|  _ \|  ___|  _   _     / \  |  _ \_ _| |___ \
#	| |_) | | | | |_    (_) (_)   / _ \ | |_) | |    __) |
#	|  __/| |_| |  _|    _   _   / ___ \|  __/| |   / __/
#	|_|   |____/|_|     (_) (_) /_/   \_\_|  |___| |_____|
#
#	Copyright 1999-2001 Alfred Reibenschuh <areibens@cpan.org>.
#
#	This library is free software; you can redistribute it 
#	and/or modify it under the same terms as Perl itself.
#
#=======================================================================
package PDF::API2;

BEGIN {
	use vars qw( $VERSION $hasWeakRef );
	( $VERSION ) = '$Revisioning: 0.3a2 $' =~ /\$Revisioning:\s+([^\s]+)/;
	eval " use WeakRef; ";
	$hasWeakRef= $@ ? 0 : 1;
}


=head1 PDF::API2

=head1 NAME

PDF::API2 - The Next Generation API for creating and modifing PDFs.

=head1 SYNOPSIS

	use PDF::API2;

	$pdf = PDF::API2->new;
	$pdf = PDF::API2->open('some.pdf');
	$page = $pdf->page;
	$page = $pdf->openpage($pagenum);
	$img = $pdf->image('some.jpg');
	$font = $pdf->corefont('Times-Roman');
	$font = $pdf->psfont('Times-Roman.pfb','Times-Roman.afm');
	$font = $pdf->ttfont('TimesNewRoman.ttf');

=cut

use Text::PDF::FileAPI;
use Text::PDF::Page;
use Text::PDF::Utils;
use Text::PDF::TTFont;
use Text::PDF::TTFont0;

use PDF::API2::Util;
use PDF::API2::CoreFont;
use PDF::API2::Page;
use PDF::API2::IOString;
use PDF::API2::PSFont;
use PDF::API2::TTFont;
use PDF::API2::Image;
use PDF::API2::PdfImage;
use PDF::API2::Pattern;
use PDF::API2::ColorSpace;
use PDF::API2::Barcode;
use PDF::API2::ExtGState;
use PDF::API2::Outlines;

use Math::Trig;

use POSIX qw( ceil floor );

=head1 METHODS

=head2 PDF::API2

=item $pdf = PDF::API->new %opts

Creates a new pdf-file object. If you know beforehand 
to save the pdf to file you can give the '-file' option,
to minimize possible memory requirements.

B<Example:>

	$pdf = PDF::API2->new();

	$pdf = PDF::API2->new(-file => 'ournew.pdf');

=cut

sub new {
	my $class=shift(@_);
	my %opt=@_;
	my $self={};
	bless($self,$class);
	$self->{pdf}=Text::PDF::FileAPI->new();
	$self->{time}='_'.pdfkey(time());
#	foreach my $para (keys(%opt)) {
#		$self->{$para}=$opt{$para};
#	}
	$self->{pdf}->{' version'} = 4;
	$self->{pages} = Text::PDF::Pages->new($self->{pdf});
	weaken($self->{pages}) if($hasWeakRef);
	$self->{pages}->proc_set(qw( PDF Text ImageB ImageC ImageI ));
	$self->{catalog}=$self->{pdf}->{Root};
	weaken($self->{catalog}) if($hasWeakRef);
	$self->{pagestack}=[];
	my $dig=digest16(digest32($class,$self,%opt));
       	$self->{pdf}->{'ID'}=PDFArray(PDFStr($dig),PDFStr($dig));
       	$self->{pdf}->{' id'}=$dig;
	if($opt{-file}) {
		$self->{' filed'}=$opt{-file};
		$self->{pdf}->create_file($opt{-file});
	}
	return $self;
}

my $rrr=<<EOT;

PageMode 
	UseNone Open document with neither outline nor thumbnails visible.
	UseOutlines Open document with outline visible.
	UseThumbs Open document with thumbnails visible.
	FullScreen Open document in full-screen mode. In full-screen mode, there is
		no menu bar, window controls, nor any other window present.
		The default value of PageMode is UseNone.
ViewerPreferences
	dictionary (Optional) Specifies a dictionary that contains kiosk options for this document; see
	Table 6.2. If this key is omitted, viewers behave in accordance with any current
	user preferences. The name of the key reflects the fact that this dictionary is not
	part of the document structure itself, but represents a set of viewer-level options for
	displaying this document. A given viewer implementation may or may not support
	the options in this dictionary.

	HideToolbar Boolean (Optional) Specifies that the viewer's toolbar should be hidden whenever the
		document is active. This attribute defaults to false.
	HideMenubar Boolean (Optional) Specifies that the viewer's menubar should be hidden whenever the
		document is active. This attribute defaults to false.
	HideWindowUI Boolean (Optional) Specifies that the user interface elements in the document's window
		should be hidden. This attribute defaults to false.
	FitWindow Boolean (Optional) Specifies that the viewer should resize the window displaying the
		document to fit the size of the first displayed page of the document. This attribute
		defaults to false.
	CenterWindow Boolean (Optional) Specifies that the viewer should position the window displaying the
		document in the center of the computer's monitor. This attribute defaults to false.
	PageLayout name (Optional) Specifies the layout for the page when the document is opened. If this
		attribute is not present, viewers behave in accordance with the current user
		preference. Allowed values:
			SinglePage Display the pages one page at a time.
			OneColumn Display the pages in one column.
			TwoColumnLeft Display the pages in two columns, with odd-numbered
				pages on the left.
			TwoColumnRight Display the pages in two columns, with odd-numbered
				pages on the right.
	NonFullScreenPageMode
		name (Optional) Specifies how the document should be displayed after exiting fullscreen
		mode if the value of the PageMode key in the Catalog is FullScreen.
		This key is ignored if the value of the PageMode key in the Catalog is not
		FullScreen. Allowed values and semantics are the same as for the PageMode
		key in the Catalog, except that a value of FullScreen is not allowed.
EOT

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
			$pgref->{' pnum'} = $pcount++;
			if(defined($pg->{Resources})) {
				eval {
					$pg->{Resources}->realise;
				};
			}
			weaken($pgref) if($hasWeakRef);
			push (@pglist, $pgref);
		}
	}
	return(@pglist);
}

=item $pdf = PDF::API->open $pdffile

Opens an existing PDF.

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

	my $fh=PDF::API2::IOString->new();
	$fh->import($file);
	$self->{pdf}=Text::PDF::FileAPI->open($fh,1);

#	$self->{pdf}=Text::PDF::FileAPI->open($file,1);

	$self->{pdf}->{' fname'}=$file;
	$self->{pdf}->{'Root'}->realise;
	$self->{pages}=$self->{pdf}->{'Root'}->{'Pages'}->realise;
	weaken($self->{pages}) if($hasWeakRef);
	$self->{pdf}->{' version'} = 3;
	my @pages=proc_pages($self->{pdf},$self->{pages});
	$self->{pagestack}=[sort {$a->{' pnum'} <=> $b->{' pnum'}} @pages];
	$self->{reopened}=1;
	$self->{time}='_'.pdfkey(time());
	my $dig=digest16(digest32($class,$file,%opt));
	if(defined $self->{pdf}->{'ID'}){
		$self->{pdf}->{'ID'}->realise;
		$self->{pdf}->{' id'}=$self->{pdf}->{'ID'}->val->[0]->val;
		$self->{pdf}->{'ID'}=PDFArray(PDFStr($self->{pdf}->{' id'}),PDFStr($dig));
	} else {
		$self->{pdf}->{'ID'}=PDFArray(PDFStr($dig),PDFStr($dig));
		$self->{pdf}->{' id'}=$dig;
	}
	return $self;
}

=item $page = $pdf->page

=item $page = $pdf->page $index

Returns a new page object or inserts-and-returns a new page at $index.

B<Note:> on $index

	-1 ... is inserted before the last page
	1 ... is inserted before page number 1
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
	weaken($page->{' apipdf'}) if($hasWeakRef);
	$page->{' api'}=$self;
	weaken($page->{' api'}) if($hasWeakRef);
	$self->{pdf}->out_obj($page);
	$self->{pdf}->out_obj($self->{pages});
	if($index==0) {
		push(@{$self->{pagestack}},$page);
	} elsif($index<0) {
		splice(@{$self->{pagestack}},$index,0,$page);
	} else {
		splice(@{$self->{pagestack}},$index-1,0,$page);
	}	
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
	my $page;

	if($index==0) {
		$page=@{$self->{pagestack}}[-1];
	} elsif($index<0) {
		$page=@{$self->{pagestack}}[$index];
	} else {
		$page=@{$self->{pagestack}}[$index-1];
	}
	$page=PDF::API2::Page->coerce($self->{pdf},$page) if(ref($page) ne 'PDF::API2::Page');

#        $self->{pdf}->out_obj($page);
#        $self->{pdf}->out_obj($self->{pages});
	$page->{' api'}=$self;
	weaken($page->{' api'}) if($hasWeakRef);
	$page->{' reopened'}=1;
	return($page);
}

=item $pageobj = $pdf->clonepage $sourceindex, $targetindex

Returns the pageobject of page $targetindex, cloned from $sourceindex.

B<Note:> on $index

	-1,0 ... returns the last page
	1 ... returns page number 1

B<Beware:>

Under some circumstances, this method may cause $pdf->update to die.
These circumstances remain unresolved but previously generated pdfs
via API2 remain unaffected so far.

=cut

sub clonepage {
	my $self=shift @_;
	my $s_idx=shift @_||0;
	my $t_idx=shift @_||0;
	$t_idx=0 if($self->pages<$t_idx);
	my ($s_page,$t_page);

	$s_page=$self->openpage($s_idx);
	$t_page=$self->page($t_idx);

	$s_page->copy($self->{pdf},$t_page);

####################################################################
        if(defined($t_page->{Resources})) {
                $t_page->{Resources}->realise if($t_page->{Resources}->is_obj($self->{pdf}));
                $t_page->{Resources}=$t_page->{Resources}->copy($self->{pdf});
        ##      $self->{pdf}->new_obj($t_page->{Resources});
                $t_page->{Resources}->{' realised'}=1;
        }

        if(defined($t_page->{Contents})) {
		$t_page->fixcontents;
		$s_page->fixcontents;
	#	foreach my $content ($t_page->{Contents}->elementsof) {
	#		$content->realise;
	#	}
	#
	#	my $tempobj=$t_page->{Contents};
	#
        #        $t_page->{Contents}=$t_page->{Contents}->copy;
	#	$self->{pdf}->remove_obj($tempobj);

        #        foreach my $content ($t_page->{Contents}->elementsof) {
        #                $self->{pdf}->new_obj($content);
        #        }

		$t_page->{Contents}->{' val'}=[];
		$t_page->{Contents}->add_elements($s_page->{Contents}->elementsof);
        }
####################################################################
	delete $t_page->{' reopened'};

        $self->{pdf}->out_obj($t_page);
        $self->{pdf}->out_obj($self->{pages});
	return($t_page);
}


sub walk_obj {
	my ($objs,$spdf,$tpdf,$obj,@key)=@_;

	my $tobj;

	return($objs->{$obj}) if(defined $objs->{$obj});

	if(ref($obj)=~/Objind$/) {
		$obj->realise;
	}

	$tobj=$obj->copy;
	$tpdf->new_obj($tobj) if($obj->is_obj($spdf));

	$objs->{$obj}=$tobj;

	if(ref($obj)=~/Array$/) {
		$tobj->{' val'}=[];
		foreach my $k ($obj->elementsof) {
			$k->realise if(ref($k)=~/Objind$/);
			$tobj->add_elements(walk_obj($objs,$spdf,$tpdf,$k));
		}
	} elsif(ref($obj)=~/Dict$/) {
		@key=keys(%{$tobj}) if(scalar @key <1);
		foreach my $k (@key) {
			$tobj->{$k}=$obj->{$k} if(($k eq ' stream') || ($k eq ' nofilt'));
			next if($k=~/^ /);
			$tobj->{$k}=walk_obj($objs,$spdf,$tpdf,$obj->{$k});
		}
	}
	delete $tobj->{' streamloc'};
	delete $tobj->{' streamsrc'};
	return($tobj);
}

=item $pageobj = $pdf->importpage $sourcepdf, $sourceindex, $targetindex

Returns the pageobject of page $targetindex, imported from $sourcepdf,$sourceindex.

B<Note:> on $index

	-1,0 ... returns the last page
	1 ... returns page number 1

=cut

sub importpage {
	my $self=shift @_;
	my $s_pdf=shift @_;
	my $s_idx=shift @_||0;
	my $t_idx=shift @_||0;
	$t_idx=0 if($self->pages<$t_idx);
	my ($s_page,$t_page);

	$s_page=$s_pdf->openpage($s_idx);
	$t_page=$self->page($t_idx);

	$self->{apiimportcache}=$self->{apiimportcache}||{};
	$self->{apiimportcache}->{$s_pdf}=$self->{apiimportcache}->{$s_pdf}||{};

	foreach my $k (qw( MediaBox ArtBox TrimBox BleedBox CropBox Rotate B Dur Hid Trans AA PieceInfo LastModified SeparationInfo ID PZ )) {
		next unless(defined $s_page->{$k});
		$t_page->{$k} = walk_obj($self->{apiimportcache}->{$s_pdf},$s_pdf->{pdf},$self->{pdf},$s_page->{$k});
	}
#	foreach my $k (qw( Thumb Annots )) {
	foreach my $k (qw( Thumb )) {
		next unless(defined $s_page->{$k});
		$t_page->{$k} = walk_obj({},$s_pdf->{pdf},$self->{pdf},$s_page->{$k});
	}
	foreach my $k (qw( Resources )) {
		$s_page->{$k}=$s_page->find_prop($k);
		next unless(defined $s_page->{$k});
		$s_page->{$k}->realise if(ref($s_page->{$k})=~/Objind$/);

		$t_page->{$k}=PDFDict();
		foreach my $sk (qw( ColorSpace XObject ExtGState Font Pattern ProcSet Properties Shading )) {
			next unless(defined $s_page->{$k}->{$sk});
			$s_page->{$k}->{$sk}->realise if(ref($s_page->{$k}->{$sk})=~/Objind$/);
			$t_page->{$k}->{$sk}=PDFDict();
			foreach my $ssk (keys %{$s_page->{$k}->{$sk}}) {
				next if($ssk=~/^ /);
				$t_page->{$k}->{$sk}->{$ssk} = walk_obj($self->{apiimportcache}->{$s_pdf},$s_pdf->{pdf},$self->{pdf},$s_page->{$k}->{$sk}->{$ssk});
			}
		}
	}
	if(defined $s_page->{Contents}) {
		$s_page->fixcontents;
		$t_page->{Contents}=PDFArray();

		foreach my $k ($s_page->{Contents}->elementsof) {
			my $content=PDFDict();
			$self->{pdf}->new_obj($content);
			$t_page->{Contents}->add_elements($content);

			$k->realise;
		#	$k->read_stream(1);
			
			if($k->{Filter}){
				$content->{'Filter'}=PDFArray($k->{Filter}->elementsof);
				$content->{' nofilt'}=1;
				$content->{' stream'}=$k->{' stream'};
			} else {
				$content->{' stream'}=substr($k->{' stream'},0,$k->{Length}->val-1);
			}
			
		}
	}
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

=item $pdf->mediabox $w, $h

=item $pdf->mediabox $llx, $lly, $urx, $ury

Sets the global mediabox.

=cut

sub mediabox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{pages}->{'MediaBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} else {
		$self->{pages}->{'MediaBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	}
	$self;
}

=item $pdf->update

Updates a previously "opened" document after all changes have been applied.

=cut

sub update {
	my $self=shift @_;
	$self->saveas($self->{pdf}->{' fname'});
}

=item $pdf->saveas $file

Saves the document.

=cut

sub saveas {
	my ($self,$file)=@_;
	if($self->{reopened}) {
		$self->{pdf}->append_file;
		CORE::open(OUTF,">$file");
		binmode(OUTF);
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

=item $pdf->info %infohash

Sets the info structure of the document.

=cut

sub info {
	my $self=shift @_;
	my %opt=@_;

	if(!defined($self->{pdf}->{'Info'})) {
        	$self->{pdf}->{'Info'}=PDFDict();
        	$self->{pdf}->new_obj($self->{'pdf'}->{'Info'});
	}

        map { $self->{pdf}->{'Info'}->{$_}=PDFStr($opt{$_}) } keys %opt;
        $self->{pdf}->out_obj($self->{pdf}->{'Info'});
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

=item $font = $pdf->corefont $fontname [, %options]

Returns a new or existing adobe core font object.

B<Examples:>

	$font = $pdf->corefont('Times-Roman');
	$font = $pdf->corefont('Times-Bold');
	$font = $pdf->corefont('Helvetica');
	$font = $pdf->corefont('ZapfDingbats');

=cut

sub corefont {
	my ($self,$name,@opts)=@_;

	my $obj=PDF::API2::CoreFont->new_api($self,$name,@opts);
	my $key=$obj->{' apiname'};

	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));

	$self->resource('Font',$key,$obj);

	$self->{pdf}->out_obj($self->{pages});
	return($obj);
}

=item $font = $pdf->psfont $pfbfile,$afmfile

Returns a new or existing adobe type1 font object.

B<Examples:>

	$font = $pdf->psfont('Times-Book.pfb','Times-Book.afm');
	$font = $pdf->psfont('/fonts/Synest-FB.pfb','/fonts/Synest-FB.afm');
	$font = $pdf->psfont('../Highland-URW.pfb','../Highland-URW.afm');

=cut

sub psfont {
	my ($self,$pfb,$afm,$encoding,@glyphs)=@_;
	my $key='PSx'.pdfkey(($pfb||'x').($afm||'y'),$self->{time});

	my $obj=PDF::API2::PSFont->new($self->{pdf},$pfb,$afm,$key,$encoding,@glyphs);
	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));

	$obj->{' apiname'}=$key;
	$obj->{' apipdf'}=$self->{pdf};
	weaken($obj->{' apipdf'}) if($hasWeakRef);
        $obj->{' api'}=$self;
	weaken($obj->{' api'}) if($hasWeakRef);

	$self->resource('Font',$key,$obj,$self->{reopened});

	$self->{pdf}->out_obj($self->{pages});
	return($obj);
}

=item $font = $pdf->ttfont $ttfile

Returns a new or existing truetype font object.

B<Examples:>

	$font = $pdf->ttfont('TimesNewRoman.ttf');
	$font = $pdf->ttfont('/fonts/Univers-Bold.ttf');
	$font = $pdf->ttfont('../Democratica-SmallCaps.ttf');



=cut

sub ttfont {
	my ($self,$file)=@_;

	my $key='TTx'.pdfkey($file,$self->{time});

	my $obj=PDF::API2::TTFont->new($self->{pdf},$file,$key);
	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));

	$obj->{' apiname'}=$key;
	$obj->{' apipdf'}=$self->{pdf};
	weaken($obj->{' apipdf'}) if($hasWeakRef);
        $obj->{' api'}=$self;
	weaken($obj->{' api'}) if($hasWeakRef);

	$self->resource('Font',$key,$obj,$self->{reopened});

	$self->{pdf}->out_obj($self->{pages});
	return($obj);
}

=item $img = $pdf->image $file

Returns a new image object from a file or a GD::Image object.

B<Examples:>

	$img = $pdf->image('yetanotherfun.jpg');
	$img = $pdf->image('truly24bitpic.png');
	$img = $pdf->image('reallargefile.pnm');

	$gdimgobj=GD::Image->newFromPng('truly24bitpic.png');
	$img = $pdf->image($gdimgobj);

B<Important Note:>

As of version 0.2.3.4 the development of the PNG import methods
has been discontinued in favor of the GD::Image import facility.

=cut

sub image {
	my ($self,$file)=@_;
        my $obj=PDF::API2::Image->new($self->{pdf},$file,$self->{time});
	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));
	if($obj->{SMask}) {
		$self->{pdf}->new_obj($obj->{SMask}) unless($obj->{SMask}->is_obj($self->{pdf}));
	}

#	$obj->{' apipdf'}=$self->{pdf};
#	$obj->{' api'}=$self;

	$self->resource('XObject',$obj->{' apiname'},$obj,1);

	$self->{pdf}->out_obj($self->{pages});
	return($obj);
}

=item $img = $pdf->pdfimage $file, $page_number

Returns a new image object,
which is actually a page from another pdf.

B<Examples:>

	$img = $pdf->pdfimage('test1.pdf',1);
	$img = $pdf->pdfimage('another-test.pdf',2);
	$img = $pdf->pdfimage('really-large.pdf',1000);

=item $img = $pdf->pdfimageobj $pdfobj, $page_number

As $pdf->pdfimage, but takes an already opened pdfobject (API2->open) as parameter.

B<Note:> This is functionally the same as the one above, but far less
resource-intensive, if you use many pages (possible the same) from one single pdf.

=cut


sub pdfimageobj {
	my $self=shift @_;
	my $s_pdf=shift @_;
	my $s_idx=shift @_||0;
	my ($s_page,$t_page);

	$s_page=$s_pdf->openpage($s_idx);
	$t_page=PDF::API2::PdfImage->new();

	$self->{apiimportcache}=$self->{apiimportcache}||{};

	my $dict = $s_page->find_prop('CropBox')||$s_page->find_prop('MediaBox');
	if(defined $dict) {
		my ($lx,$ly,$rx,$ry)=$dict->elementsof;
		$t_page->{LX}=PDFNum($lx->val);
		$t_page->{' lx'}=$lx->val;
		$t_page->{LY}=PDFNum($ly->val);
		$t_page->{' ly'}=$ly->val;
		$t_page->{RX}=PDFNum($rx->val);
		$t_page->{' rx'}=$rx->val;
		$t_page->{RY}=PDFNum($ry->val);
		$t_page->{' ry'}=$ry->val;
	}
	$k='Resources';
	$s_page->{$k}=$s_page->find_prop($k);
	if(defined $s_page->{$k}) {
		$t_page->{$k}=PDFDict();
		foreach my $sk (qw( ColorSpace XObject ExtGState Font Pattern ProcSet Properties Shading )) {
			next unless(defined $s_page->{$k}->{$sk});
			$t_page->{$k}->{$sk}=PDFDict();
			foreach my $ssk (keys %{$s_page->{$k}->{$sk}}) {
				next if($ssk=~/^ /);
				$t_page->{$k}->{$sk}->{$ssk} = walk_obj($self->{apiimportcache},$s_pdf->{pdf},$self->{pdf},$s_page->{$k}->{$sk}->{$ssk});
			}
		}
	}
	if(defined $s_page->{Contents}) {
		$s_page->fixcontents;
		foreach my $k ($s_page->{Contents}->elementsof) {
			$k->realise if(ref($k)=~/Objind$/);

			my $str=$k->{' stream'};

			if((defined $k->{Filter}) ) {

				# we need to fix filter because it MAY be
				# an array BUT IT COULD BE only a name
				if(ref($k->{Filter})!~/Array$/) {
				       $k->{Filter} = PDFArray($k->{Filter});
				}

				use Text::PDF::Filter;
				my @filts;
			        my ($hasflate) = -1;
			        my ($temp, $i, $temp1);

			        for ($i = 0; $i <= $#{$k->{'Filter'}{' val'}}; $i++)
			        {
			            $temp = $k->{'Filter'}{' val'}[$i]->val;
			            $temp1 = "Text::PDF::$temp";
			            push (@filts, $temp1->new);
			        }

				foreach my $f (@filts) {
					$str = $f->infilt($str, 1);
				}
			}
			$t_page->{' pdfimage'}.="\n$str\n";
		}
	}
        $self->{pdf}->new_obj($t_page) unless($t_page->is_obj($self->{pdf}));
        $self->{pdf}->out_obj($self->{pages});

	return($t_page);
}

sub pdfimage {
	my $self=shift @_;
	my $s_pdf=shift @_;
	my $s_idx=shift @_||0;

	$s_pdf=PDF::API2->open($s_pdf);
	my $t_page=$self->pdfimageobj($s_pdf,$s_idx);
	$s_pdf->end;

	return($t_page);
}

=item $shadeing = $pdf->shade

Returns a new shading object.

=cut

sub shade {
	my ($self,%opts)=@_;
	my $key='SHx'.pdfkey(%opts || 'shade'.localtime() );
	my $obj=PDFDict();
#	my $pat=$self->pattern(-type=>2);
	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));

	$obj->{' apiname'}=$key;
	$obj->{' apipdf'}=$self->{pdf};
	weaken($obj->{' apipdf'}) if($hasWeakRef);
        $obj->{' api'}=$self;
	weaken($obj->{' api'}) if($hasWeakRef);

	$self->resource('Shading',$key,$obj,1);

	$self->{pdf}->out_obj($self->{pages});
	return($obj);
}

=item $pat = $pdf->pattern

Returns a new pattern object.

=cut

sub pattern {
	my ($self,%opts)=@_;
	my $obj=PDF::API2::Pattern->new();
	my $key=$obj->{' apiname'};
	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));

#	$obj->{' apipdf'}=$self->{pdf};
#	$obj->{' api'}=$self;

	$self->resource('Pattern',$key,$obj,1);

	$self->{pdf}->out_obj($self->{pages});
	return($obj);
}

=item $cs = $pdf->colorspace %parameters

Returns a new colorspace object.

B<Examples:>

	$cs = $pdf->colorspace(
		-type => 'CalRGB',
		-whitepoint => [ 0.9, 1, 1.1 ],
		-blackpoint => [ 0, 0, 0 ],
		-gamma => [ 2.2, 2.2, 2.2 ],
		-matrix => [
			0.41238, 0.21259, 0.01929,
			0.35757, 0.71519, 0.11919,
			0.1805,  0.07217, 0.95049
		]
	);

	$cs = $pdf->colorspace(
		-type => 'CalGray',
		-whitepoint => [ 0.9, 1, 1.1 ],
		-blackpoint => [ 0, 0, 0 ],
		-gamma => 2.2
	);

	$cs = $pdf->colorspace(
		-type => 'Lab',
		-whitepoint => [ 0.9, 1, 1.1 ],
		-blackpoint => [ 0, 0, 0 ],
		-gamma => [ 2.2, 2.2, 2.2 ],
		-range => [ -100, 100, -100, 100 ]
	);

	$cs = $pdf->colorspace(
		-type => 'Indexed',
		-base => 'DeviceRGB',
		-maxindex => 3,
		-whitepoint => [ 0.9, 1, 1.1 ],
		-blackpoint => [ 0, 0, 0 ],
		-gamma => [ 2.2, 2.2, 2.2 ],
		-colors => [
			[ 0,0,0 ],	# black = 0
			[ 1,1,1 ],	# white = 1
			[ 1,0,0 ],	# red = 2
			[ 0,0,1 ],	# blue = 3
		]
	);

	$cs = $pdf->colorspace(
		-type => 'ICCBased',
		-base => 'DeviceRGB',
		-components => 3,
		-iccfile => 'codacus.icc'
	);

=cut

sub colorspace {
	my ($self,@opt)=@_;
	my $key='CSx'.pdfkey('colorspace',@opt);
	my $obj=PDF::API2::ColorSpace->new($self->{pdf},$key,@opt);
	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));

	$obj->{' apiname'}=$key;
#	$obj->{' apipdf'}=$self->{pdf};
#       $obj->{' api'}=$self;

	$self->resource('ColorSpace',$key,$obj,1);

        $self->{pdf}->out_obj($self->{pages});
	return($obj);
}

=item @color = $pdf->businesscolor $basecolor [, $lightdark ]

=item @color = $pdf->businesscolor $colornumber [, $lightdark ]

Returns a color-array suitible for use with the stroke/fillcolor methods.

=cut

sub businesscolor {
	my $self=shift @_;
	my @col;
#	$self->{bccs} = $self->{bccs} || $self->colorspace(
#		-type => 'CalRGB',
#		-whitepoint => [ 0.9505, 1, 1.089 ],
#		-blackpoint => [ 0, 0, 0 ],
#		-gamma => [ 2.2, 2.2, 2.2 ],
#		-matrix => [
#			0.41238, 0.21259, 0.01929,
#			0.35757, 0.71519, 0.11919,
#			0.1805,  0.07217, 0.95049
#		]
#	);
	my $color=shift @_||0;
	my $ld=shift @_||0;
	if($color=~/^[a-z\!\$\%\&\#]+/) {
		@col=namecolor($color);
		my ($hue)=RGBtoHSV( @col );
		@col=HSLtoRGB($hue,1,0.5+($ld/10));
	} else {
		$color-=1;
		if($color<0) {
			@col=(0.5+($ld/10),0.5+($ld/10),0.5+($ld/10));
		} else {
			@col=HSLtoRGB($color*30,1,0.5+($ld/10));
		}
	}
#	return($self->{bccs},@col);
	return(RGBasCMYK(@col));
}

=item $img = $pdf->barcode %options

Returns a new barcode object.

B<Note:> refer to PDF::API2::Barcode for more details.

=cut

sub barcode {
	my ($self,%opts)=@_;
	my $key='BCx'.pdfkey('barcode'.time().rand(0x7fffff));
	my $obj=PDF::API2::Barcode->new($key,%opts);
	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));

	$obj->{' apiname'}=$key;
	$obj->{' apipdf'}=$self->{pdf};
	weaken($obj->{' apipdf'}) if($hasWeakRef);
	$obj->{' api'}=$self;
	weaken($obj->{' api'}) if($hasWeakRef);

	$self->resource('XObject',$key,$obj,1);

        $self->{pdf}->out_obj($self->{pages});

	return($obj);
}

sub extgstate {
	my ($self)=@_;
	my $key='XTGSx'.pdfkey('extgstate'.time().rand(0x7fffff));
	my $obj=PDF::API2::ExtGState->new($self->{pdf},$key);
	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));
	$self->resource('ExtGState',$key,$obj,1);
        $obj->{' api'}=$self;
	weaken($obj->{' api'}) if($hasWeakRef);
	return($obj);
}


=item $otls = $pdf->outlines

Returns a new or existing outlines object.

=cut

sub outlines {
	my ($self)=@_;

	$self->{pdf}->{Root}->{Outlines}=$self->{pdf}->{Root}->{Outlines}
		|| PDF::API2::Outlines->new($self);
	my $obj=$self->{pdf}->{Root}->{Outlines};

	$self->{pdf}->new_obj($obj) if(!$obj->is_obj($self->{pdf}));

	return($obj);

}

=item $page->resource $type, $key, $obj, $force

Adds a resource to the global page-inheritance tree.

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
	my ($self, $type, $key, $obj, $force) = @_;

	$self->{pages}->{Resources}= $self->{pages}->{Resources} || PDFDict();

	my $dict=$self->{pages}->{Resources};
	$dict->realise if(ref($dict)=~/Objind$/);

	$dict->{$type}=$dict->{$type} || PDFDict();
	$dict->{$type}->realise if(ref($dict->{$type})=~/Objind$/);

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

1;

__END__

=head1 AUTHOR

alfred reibenschuh

=cut
