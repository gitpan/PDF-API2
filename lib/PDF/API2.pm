#==================================================================
#
# Copyright 1999-2001 Alfred Reibenschuh <areibens@cpan.org>.
#
# This library is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself. 
#
#==================================================================
package PDF::API2;

use vars qw( $VERSION );
( $VERSION ) = '$Revisioning: 20011128.230201 $ ' =~ /\$Revisioning:\s+([^\s]+)/;

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

use Text::PDF::File;
use Text::PDF::AFont;
use Text::PDF::Page;
use Text::PDF::Utils;
use Text::PDF::TTFont;
use Text::PDF::TTFont0;

use PDF::API2::Util;

use POSIX qw( ceil floor );

=head1 METHODS 

=head2 PDF::API2

=item $pdf = PDF::API->new

=cut

sub new {
	my $class=shift(@_);
	my %opt=@_;
	my $self={};
	bless($self);
	$self->default('pdf',Text::PDF::File->new);
	$self->default('Compression',1);
	$self->default('subset',1);
	$self->default('time','_'.pdfkey(time()));
	foreach my $para (keys(%opt)) {
		$self->default($para,$opt{$para});
	}
	$self->{pdf}->{' version'} = 3;
	$self->{pages} = Text::PDF::Pages->new($self->{pdf});
	$self->{pages}->proc_set(qw( PDF Text ImageB ImageC ImageI ));
	$self->{catalog}=$self->{pdf}->{Root};
	$self->{pagestack}=[];
	my $dig=digest16(digest32($class,$self,%opt));
       	$self->{pdf}->{'ID'}=PDFArray(PDFStr($dig),PDFStr($dig));
       	$self->{pdf}->{'ID'}->val->[0]->{' ashex'}=1;
       	$self->{pdf}->{'ID'}->val->[1]->{' ashex'}=1;
       	$self->{pdf}->{' id'}=$dig;
	return $self;
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
			$pgref->{' pnum'} = $pcount++;
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

=item $pdf = PDF::API->open $pdffile

Opens an existing PDF.

=cut

sub open {
	my $class=shift(@_);
	my $file=shift(@_);
	my %opt=@_;
	my $self={};
	bless($self);
	$self->default('Compression',1);
	$self->default('subset',1);
	$self->default('update',1);
	foreach my $para (keys(%opt)) {
		$self->default($para,$opt{$para});
	}

	my $fh=PDF::API2::IOString->new();
	$fh->import($file);

	$self->{pdf}=Text::PDF::File->open($fh,1);
	$self->{pdf}->{' fname'}=$file;
	$self->{pdf}->{'Root'}->realise;
	$self->{pages}=$self->{pdf}->{'Root'}->{'Pages'}->realise;
	$self->{pdf}->{' version'} = 3;
	my @pages=proc_pages($self->{pdf},$self->{pages});
	$self->{pagestack}=[sort {$a->{' pnum'} <=> $b->{' pnum'}} @pages];
	$self->{reopened}=1;
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

	foreach my $k (qw( MediaBox ArtBox TrimBox BleedBox CropBox Rotate B Dur Hid Trans AA PieceInfo LastModified SeparationInfo ID PZ )) {
		next unless(defined $s_page->{$k});
		$t_page->{$k} = walk_obj($self->{apiimportcache},$s_pdf->{pdf},$self->{pdf},$s_page->{$k});
	}
	foreach my $k (qw( Thumb Annots )) {
		next unless(defined $s_page->{$k});
		$t_page->{$k} = walk_obj({},$s_pdf->{pdf},$self->{pdf},$s_page->{$k});
	}
	foreach my $k (qw( Resources )) {
		$s_page->{$k}=$s_page->find_prop($k);
		next unless(defined $s_page->{$k});
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
		$t_page->{Contents}=PDFArray();
		foreach my $k ($s_page->{Contents}->elementsof) {
			$t_page->{Contents}->add_elements(walk_obj($self->{apiimportcache},$s_pdf->{pdf},$self->{pdf},$k));
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
	} else {
		$self->{pdf}->out_file($file);	
	}
}

=item $string = $pdf->stringify

Returns the document in a string.

=cut

sub stringify {
	my ($this)=@_;
	my $str;
	if($self->{reopened}==1) {
		$self->{pdf}->append_file;
		$str=${$self->{pdf}->{' OUTFILE'}->string_ref};
	} else {
		my $fh = PDF::API2::IOString->new();
		$fh->open();
		eval {
			$this->{pdf}->out_file($fh);
		};
		$str=${$fh->string_ref};
		$fh->realclose;
	} 
	return($str);
}

sub release {return(undef);}

=item $pdf->end

Destroys the document.

=cut

sub end {
	my $self=shift(@_);
	$self->{pdf}->release;
	foreach my $k (keys %{$self}) {
		delete $self->{$k};
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

=item $font = $pdf->corefont $fontname [, $lightembed]

Returns a new or existing adobe core font object.

B<Examples:>

	$font = $pdf->corefont('Times-Roman',1);
	$font = $pdf->corefont('Times-Bold');
	$font = $pdf->corefont('Helvetica',1);
	$font = $pdf->corefont('ZapfDingbats');

=cut

sub corefont {
	my ($self,$name,$light)=@_;
	my $key='FFx'.pdfkey($name);

	my $obj;

        $self->{pages}->{'Resources'}
        	= $self->{pages}->{'Resources'} 
        	|| PDFDict();
 	$self->{pages}->{'Resources'}->{'Font'}
 		= $self->{pages}->{'Resources'}->{'Font'} 
 		|| PDFDict();
	if((defined $self->{pages}->{'Resources'}->{'Font'}->{$key}) && $self->{reopened}) {
		# we are here because we somehow created
		# the reopened pdf so we simulate a valid 
		# object without writing a new one
		$obj= PDF::API2::CoreFont->coerce(
				$self->{pages}->{'Resources'}->{'Font'}->{$key},$self->{pdf},$name,$key,$light
			);
	} else {
		$obj= $self->{pages}->{'Resources'}->{'Font'}->{$key} 
			|| PDF::API2::CoreFont->new(
				$self->{pdf},$name,$key,$light
			);
	}

	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));

	$obj->{' apiname'}=$key;
	$obj->{' apipdf'}=$self->{pdf};
        $obj->{' api'}=$self;

	$self->resource('Font',$key,$obj);

	$self->{pdf}->out_obj($self->{pages});
	return($obj);
}

sub xfont {
	my ($self,@opts)=@_;
	
	my $obj=PDF::API2::xFont->new($self->{pdf},@opts);
	my $key=$obj->{' apiname'};

	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));

	$obj->{' apiname'}=$key;
	$obj->{' apipdf'}=$self->{pdf};
        $obj->{' api'}=$self;

	$self->resource('Font',$key,$obj,$self->{reopened});

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
	my $key='PSx'.pdfkey(($pfb||'x').($afm||'y')).$self->{time};

	if($^O eq 'MSWin32') {
		my %opts=opts_from_pfm($pfb);
		$pfb = defined $opts{-pfbfile} ? $opts{-pfbfile} : $pfb; 
		$afm = defined $opts{-pfbfile} ? undef : $afm; 
	}

	my $obj=PDF::API2::PSFont->new($self->{pdf},$pfb,$afm,$key,$encoding,@glyphs);
	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));

	$obj->{' apiname'}=$key;
	$obj->{' apipdf'}=$self->{pdf};
        $obj->{' api'}=$self;

	$self->resource('Font',$key,$obj,$self->{reopened});

	$self->{pdf}->out_obj($self->{pages});
	return($obj);
}

=item $font = $pdf->ttfont $ttfile

=item $font = $pdf->ttfont $ttfile, $lazy

Returns a new or existing truetype font object.

B<Examples:>

	$font = $pdf->ttfont('TimesNewRoman.ttf');
	$font = $pdf->ttfont('/fonts/Univers-Bold.ttf');
	$font = $pdf->ttfont('../Democratica-SmallCaps.ttf');


B<Beware:>

The $lazy option set to 1 will make several assumptions about truetype, used encoding 
and the reader-application (eg. Adobe Acrobat) to provide easy access to fonts without
embedding.

=over 2

1. API2 assumes the used encoding to be compatible with pdf's 'WinAnsiEncoding' or 'latin1'.
This is fixed and cannot be changed !

2. API2 assumes that the fonts is not needed to be embedded and as such that the
reader-application (eg. Acrobat 5) supports proper font search or substitution.

3. Encodings of symbol-fonts do not have to be changed, since this should also be 
handled by the reader-application (eg. Acrobat).

4. Utf8 methods will discard any characters outside of the 'latin1' and 'ms-symbol' ranges.

=back 

B<Benefits:>

The $lazy option set to 1 has the following benefits:

=over 2

1. No font-file will be embedded, saveing space, time and performance for other tasks.

2. You do not have to know where your windows system fonts are located, since instead
of specifying a valid fontfile you can use one of the aliases below to use the font.

3. This method is even faster that using a pdf corefont, if your primary
target-platform is the "adobe acrobat reader" on windows.

=back

B<Lazy Example:>

	$font = $pdf->ttfont('TimesNewRoman',1);

B<Windows Font Names:>

	arial arialbold arialitalic arialbolditalic arialblack 
	comicsansms comicsansmsbold 
	couriernew couriernewbold couriernewitalic couriernewbolditalic 
	tahoma tahomabold 
	timesnewroman timesnewromanbold timesnewromanitalic timesnewromanbolditalic 
	verdana verdanabold verdanaitalic verdanabolditalic 
	wingdings
	
B<Note:>

=over 2

Please see L<PDF::API2::xFont> for other informations.

=back

=cut

sub ttfont {
	my ($self,$file,$lazy)=@_;
	
	if($^O eq 'MSWin32') {
		my %opts=opts_from_ttf($file);
		$file = defined $opts{-ttfile} ? $opts{-ttfile} : $file; 
	}

	return $self->xfont(-ttfile=>$file,-ttopts=>$lazy) if($lazy);
	
	my $key='TTx'.pdfkey($file).$self->{time};

	my $obj=PDF::API2::TTFont->new($self->{pdf},$file,$key);
	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));

	$obj->{' apiname'}=$key;
	$obj->{' apipdf'}=$self->{pdf};
        $obj->{' api'}=$self;

	$self->resource('Font',$key,$obj,$self->{reopened});

	$self->{pdf}->out_obj($self->{pages});
	return($obj);
}

=item $img = $pdf->image $file

Returns a new image object.

B<Examples:>

	$img = $pdf->image('yetanotherfun.jpg');
	$img = $pdf->image('truly24bitpic.png');
	$img = $pdf->image('reallargefile.pnm');

=cut

sub image {
	my ($self,$file)=@_;
        my $obj=PDF::API2::Image->new($self->{pdf},$file,$self->{time});
	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));

	$obj->{' apipdf'}=$self->{pdf};
        $obj->{' api'}=$self;

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
        $obj->{' api'}=$self;

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

	$obj->{' apipdf'}=$self->{pdf};
	$obj->{' api'}=$self;

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
	$obj->{' apipdf'}=$self->{pdf};
        $obj->{' api'}=$self;

	$self->resource('ColorSpace',$key,$obj,1);

        $self->{pdf}->out_obj($self->{pages});
	return($obj);
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
	$obj->{' api'}=$self;

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


#==================================================================
#	PDF::API2::Pattern
#==================================================================
package PDF::API2::Pattern;

use strict;
use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict);

use Text::PDF::Utils;
use Text::PDF::Dict;
use PDF::API2::Util;

=head2 PDF::API2::Pattern

Subclassed from Text::PDF::Dict.

=item $otls = PDF::API2::Pattern->new

Returns a new pattern object (called from $pdf->pattern).

=cut

sub new {
	my ($class,%opts)=@_;
	my $self = $class->SUPER::new;
	my $key='PTx'.pdfkey(%opts || 'pattern'.localtime() );

	$self->{' apiname'}=$key;
	$self->{Type}=PDFName('Pattern');

	return($self);
}


#==================================================================
#	PDF::API2::Outlines
#==================================================================
package PDF::API2::Outlines;

use strict;
use vars qw(@ISA);
@ISA = qw(PDF::API2::Outline);

use Text::PDF::Utils;
use PDF::API2::Util;

=head2 PDF::API2::Outlines

Subclassed from PDF::API2::Outline.

=item $otls = PDF::API2::Outlines->new $api

Returns a new outlines object (called from $pdf->outlines).

=cut

sub new {
	my ($class,$api)=@_;
	my $self = $class->SUPER::new($api);
	$self->{Type}=PDFName('Outlines');

	return($self);
}


#==================================================================
#	PDF::API2::Outline
#==================================================================
package PDF::API2::Outline;

use strict;
use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict);

use Text::PDF::Dict;
use Text::PDF::Utils;
use PDF::API2::Util;

=head2 PDF::API2::Outline

Subclassed from Text::PDF::Dict.

=over 4

=item $otl = PDF::API2::Outline->new $api,$parent,$prev

Returns a new outline object (called from $otls->outline).

=cut

sub new {
	my ($class,$api,$parent,$prev)=@_;
	my $self = $class->SUPER::new;
	$self->{' apipdf'}=$api->{pdf};
	$self->{' api'}=$api;
	$self->{Parent}=$parent if(defined $parent);
	$self->{Prev}=$prev if(defined $prev);
	return($self);
}

sub parent {
	my $self=shift @_;
	if(defined $_[0]) {
		$self->{Parent}=shift @_;
	}
	return $self->{Parent};
}

sub prev {
	my $self=shift @_;
	if(defined $_[0]) {
		$self->{Prev}=shift @_;
	}
	return $self->{Prev};
}

sub next {
	my $self=shift @_;
	if(defined $_[0]) {
		$self->{Next}=shift @_;
	}
	return $self->{Next};
}

sub first {
	my $self=shift @_;
	$self->{First}=$self->{' childs'}->[0] if(defined $self->{' childs'});
	return $self->{First} ;
}

sub last {
	my $self=shift @_;
	$self->{Last}=$self->{' childs'}->[-1] if(defined $self->{' childs'});
	return $self->{Last};
}

sub count {
	my $self=shift @_;
	my $cnt=scalar @{$self->{' childs'}||[]};
	map { $cnt+=$_->count();} @{$self->{' childs'}};
	$self->{Count}=PDFNum($cnt) if($cnt>0);
	return $cnt;
}

sub fix_outline {
	my ($self)=@_;
	$self->first;
	$self->last;
	$self->count;
}

=item $otl->title $text

Set the title of the outline.

=cut

sub title {
	my ($self,$txt)=@_;
	$self->{Title}=PDFStr($txt);
	return($self);
}

=item $sotl=$otl->outline

Returns a new sub-outline.

=cut

sub outline {
	my $self=shift @_;
	my $obj=PDF::API2::Outline->new($self->{' api'},$self);
	$obj->prev($self->{' childs'}->[-1]) if(defined $self->{' childs'});
	$self->{' childs'}->[-1]->next($obj) if(defined $self->{' childs'});
	push(@{$self->{' childs'}},$obj);
	$self->{' api'}->{pdf}->new_obj($obj) if(!$obj->is_obj($self->{' api'}->{pdf}));
	return $obj;
}

=item $otl->dest $pageobj [, %opts]

Sets the destination page of the outline.

=item $otl->dest( $page, -fit => 1 ) 

Display the page designated by page, with its contents magnified just enough to 
fit the entire page within the window both horizontally and vertically. If the 
required horizontal and vertical magnification factors are different, use the 
smaller of the two, centering the page within the window in the other dimension.

=item $otl->dest( $page, -fith => $top )

Display the page designated by page, with the vertical coordinate top positioned
at the top edge of the window and the contents of the page magnified just enough 
to fit the entire width of the page within the window.

=item $otl->dest( $page, -fitv => $left ) 

Display the page designated by page, with the horizontal coordinate left positioned
at the left edge of the window and the contents of the page magnified just enough 
to fit the entire height of the page within the window.

=item $otl->dest( $page, -fitr => [ $left, $bottom, $right, $top ] ) 

Display the page designated by page, with its contents magnified just enough to 
fit the rectangle specified by the coordinates left, bottom, right, and top 
entirely within the window both horizontally and vertically. If the required
horizontal and vertical magnification factors are different, use the smaller of
the two, centering the rectangle within the window in the other dimension.

=item $otl->dest( $page, -fitb => 1 )

Display the page designated by page, with its contents magnified just 
enough to fit its bounding box entirely within the window both horizontally and 
vertically. If the required horizontal and vertical magnification factors are 
different, use the smaller of the two, centering the bounding box within the 
window in the other dimension.

=item $otl->dest( $page, -fitbh => $top )

Display the page designated by page, with the vertical coordinate top 
positioned at the top edge of the window and the contents of the page magnified 
just enough to fit the entire width of its bounding box within the window.

=item $otl->dest( $page, -fitbv => $left )

Display the page designated by page, with the horizontal coordinate 
left positioned at the left edge of the window and the contents of the page 
magnified just enough to fit the entire height of its bounding box within the 
window.

=item $otl->dest( $page, -xyz => [ $left, $top, $zoom ] )

Display the page designated by page, with the coordinates (left, top) positioned 
at the top-left corner of the window and the contents of the page magnified by 
the factor zoom. A zero (0) value for any of the parameters left, top, or zoom 
specifies that the current value of that parameter is to be retained unchanged.

=cut

sub dest {
	my ($self,$page,%opts)=@_;
	
	die "no valid page '$page' specified." if(!ref($page));
	
	$opts{-fit}=1 if(scalar(keys %opts)<1);
	
	if(defined $opts{-fit}) {
		$self->{Dest}=PDFArray($page,PDFName('Fit'));
	} elsif(defined $opts{-fith}) {
		$self->{Dest}=PDFArray($page,PDFName('FitH'),PDFNum($opts{-fith}));
	} elsif(defined $opts{-fitb}) {
		$self->{Dest}=PDFArray($page,PDFName('FitB'));
	} elsif(defined $opts{-fitbh}) {
		$self->{Dest}=PDFArray($page,PDFName('FitBH'),PDFNum($opts{-fitbh}));
	} elsif(defined $opts{-fitv}) {
		$self->{Dest}=PDFArray($page,PDFName('FitV'),PDFNum($opts{-fitv}));
	} elsif(defined $opts{-fitbv}) {
		$self->{Dest}=PDFArray($page,PDFName('FitBV'),PDFNum($opts{-fitbv}));
	} elsif(defined $opts{-fitr}) {
		die "insufficient parameters to ->dest( page, -fitr => [] ) " unless(scalar @{$opts{-fitr}} == 4);
		$self->{Dest}=PDFArray($page,PDFName('FitR'),map {PDFNum($_)} @{$opts{-fitr}});
	} elsif(defined $opts{-xyz}) {
		die "insufficient parameters to ->dest( page, -xyz => [] ) " unless(scalar @{$opts{-fitr}} == 3);
		$self->{Dest}=PDFArray($page,PDFName('XYZ'),map {PDFNum($_)} @{$opts{-xyz}});
	}
	return($self);
}

sub out_obj {
	my ($self,@param)=@_;
	$self->fix_outline;
	return $self->SUPER::out_obj(@param);
}

sub outobjdeep {
	my ($self,@param)=@_;
	$self->fix_outline;
	return $self->SUPER::outobjdeep(@param);
}


#==================================================================
#	PDF::API2::ColorSpace
#==================================================================
package PDF::API2::ColorSpace;

use strict;
use vars qw(@ISA);
@ISA = qw(Text::PDF::Array);

use Text::PDF::Utils;
use PDF::API2::Util;
use Math::Trig;

=back

=head2 PDF::API2::ColorSpace

Subclassed from Text::PDF::Array.

=item $cs = PDF::API2::ColorSpace->new $pdf, $key, %parameters

Returns a new colorspace object (called from $pdf->colorspace).

=cut

sub new {
	my ($class,$pdf,$key,%opts)=@_;
	my $self = $class->SUPER::new();
	$self->{' apiname'}=$key;
	$self->{' apipdf'}=$pdf;

	if($opts{-type} eq 'CalRGB') {

		my $csd=PDFDict();
		$opts{-whitepoint}=$opts{-whitepoint} || [ 0.95049, 1, 1.08897 ];
		$opts{-blackpoint}=$opts{-blackpoint} || [ 0, 0, 0 ];
		$opts{-gamma}=$opts{-gamma} || [ 2.22218, 2.22218, 2.22218 ];
		$opts{-matrix}=$opts{-matrix} || [ 
			0.41238, 0.21259, 0.01929,
			0.35757, 0.71519, 0.11919,
			0.1805,  0.07217, 0.95049
		];
		
		$csd->{WhitePoint}=PDFArray(map {PDFNum($_)} @{$opts{-whitepoint}});
		$csd->{BlackPoint}=PDFArray(map {PDFNum($_)} @{$opts{-blackpoint}});
		$csd->{Gamma}=PDFArray(map {PDFNum($_)} @{$opts{-gamma}});
		$csd->{Matrix}=PDFArray(map {PDFNum($_)} @{$opts{-matrix}});

		$self->add_elements(PDFName($opts{-type}),$csd);

		$self->{' type'}='rgb';

	} elsif($opts{-type} eq 'CalGray') {

		my $csd=PDFDict();
		$opts{-whitepoint}=$opts{-whitepoint} || [ 0.95049, 1, 1.08897 ];
		$opts{-blackpoint}=$opts{-blackpoint} || [ 0, 0, 0 ];
		$opts{-gamma}=$opts{-gamma} || 2.22218;
		$csd->{WhitePoint}=PDFArray(map {PDFNum($_)} @{$opts{-whitepoint}});
		$csd->{BlackPoint}=PDFArray(map {PDFNum($_)} @{$opts{-blackpoint}});
		$csd->{Gamma}=PDFNum($opts{-gamma});
		
		$self->add_elements(PDFName($opts{-type}),$csd);

		$self->{' type'}='gray';

	} elsif($opts{-type} eq 'Lab') {

		my $csd=PDFDict();
		$opts{-whitepoint}=$opts{-whitepoint} || [ 0.95049, 1, 1.08897 ];
		$opts{-blackpoint}=$opts{-blackpoint} || [ 0, 0, 0 ];
		$opts{-range}=$opts{-range} || [ -200, 200, -200, 200 ];
		$opts{-gamma}=$opts{-gamma} || [ 2.22218, 2.22218, 2.22218 ];
		
		$csd->{WhitePoint}=PDFArray(map {PDFNum($_)} @{$opts{-whitepoint}});
		$csd->{BlackPoint}=PDFArray(map {PDFNum($_)} @{$opts{-blackpoint}});
		$csd->{Gamma}=PDFArray(map {PDFNum($_)} @{$opts{-gamma}});
		$csd->{Range}=PDFArray(map {PDFNum($_)} @{$opts{-range}});
		
		$self->add_elements(PDFName($opts{-type}),$csd);

		$self->{' type'}='lab';

	} elsif($opts{-type} eq 'Indexed') {

		my $csd=PDFDict();
		$opts{-base}=$opts{-base} || 'DeviceRGB';
		$opts{-maxindex}=$opts{-maxindex} || scalar(@{$opts{-colors}})-1;
		$opts{-whitepoint}=$opts{-whitepoint} || [ 0.95049, 1, 1.08897 ];
		$opts{-blackpoint}=$opts{-blackpoint} || [ 0, 0, 0 ];
		$opts{-gamma}=$opts{-gamma} || [ 2.22218, 2.22218, 2.22218 ];
		
		$csd->{WhitePoint}=PDFArray(map {PDFNum($_)} @{$opts{-whitepoint}});
		$csd->{BlackPoint}=PDFArray(map {PDFNum($_)} @{$opts{-blackpoint}});
		$csd->{Gamma}=PDFArray(map {PDFNum($_)} @{$opts{-gamma}});
		
		foreach my $col (@{$opts{-colors}}) {
			map { $csd->{' stream'}.=pack('C',$_); } @{$col};
		}
		$pdf->new_obj($csd);
		$csd->{Filter}=PDFArray(PDFName('FlateDecode'));
		$self->add_elements(PDFName($opts{-type}),PDFName($opts{-base}),PDFNum($opts{-maxindex}),$csd);
		
		$self->{' type'}='index';

	} elsif($opts{-type} eq 'ICCBased') {

		my $csd=PDFDict();

		$csd->{Filter}=PDFArray(PDFName('FlateDecode'));
		$csd->{Alternate}=PDFName($opts{-base}) if(defined $opts{-base});
		$csd->{N}=PDFNum($opts{-components});
		$csd->{' streamfile'}=$opts{-iccfile};
		$pdf->new_obj($csd);
		$self->add_elements(PDFName($opts{-type}),$csd);

		$self->{' type'} = 
			$opts{-base}=~/RGB/i ? 'rgb' :
			$opts{-base}=~/CMYK/i ? 'cmyk' :
			$opts{-base}=~/Lab/i ? 'lab' :
			$opts{-base}=~/Gr[ae]y/i ? 'gray' :
			$opts{-base}=~/Index/i ? 'index' : 'other'
		;

	}

	return($self);
}

sub isRGB { $_[0]->{' type'}=~/rgb/ ? 1 : 0 ; }
sub isCMYK { $_[0]->{' type'}=~/cmyk/ ? 1 : 0 ; }
sub isLab { $_[0]->{' type'}=~/lab/ ? 1 : 0 ; }
sub isGray { $_[0]->{' type'}=~/gray/ ? 1 : 0 ; }
sub isIndexed { $_[0]->{' type'}=~/index/ ? 1 : 0 ; }

#==================================================================
#	PDF::API2::ExtGState
#==================================================================
package PDF::API2::ExtGState;

use strict;
use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict);

use Text::PDF::Dict;
use Text::PDF::Utils;
use Math::Trig;
use PDF::API2::Util;

=head2 PDF::API2::ExtGState

Subclassed from Text::PDF::Dict.

=item $egs = PDF::API2::ExtGState->new @parameters

Returns a new extgstate object (called from $pdf->extgstate).

=cut

sub new {
	my ($class,$pdf,$key)=@_;
	my $self = $class->SUPER::new;
	$self->{' apiname'}=$key;
	$self->{' apipdf'}=$pdf;
	$self->{Type}=PDFName('ExtGState');
	return($self);
}

=item $egs->strokeadjust $boolean

=cut

sub strokeadjust {
	my ($self,$var)=@_;
	$self->{SA}=PDFBool($var);
	return($self);
}

=item $egs->strokeoverprint $boolean

=cut

sub strokeoverprint {
	my ($self,$var)=@_;
	$self->{OP}=PDFBool($var);
	return($self);
}

=item $egs->filloverprint $boolean

=cut

sub filloverprint {
	my ($self,$var)=@_;
	$self->{op}=PDFBool($var);
	return($self);
}

=item $egs->overprintmode $num

=cut

sub overprintmode {
	my ($self,$var)=@_;
	$self->{OPM}=PDFNum($var);
	return($self);
}

=item $egs->blackgeneration $obj

=cut

sub blackgeneration {
	my ($self,$obj)=@_;
	$self->{BG}=$obj;
	return($self);
}

=item $egs->blackgeneration2 $obj

=cut

sub blackgeneration2 {
	my ($self,$obj)=@_;
	$self->{BG2}=$obj;
	return($self);
}

=item $egs->undercolorremoval $obj

=cut

sub undercolorremoval {
	my ($self,$obj)=@_;
	$self->{UCR}=$obj;
	return($self);
}

=item $egs->undercolorremoval2 $obj

=cut

sub undercolorremoval2 {
	my ($self,$obj)=@_;
	$self->{UCR2}=$obj;
	return($self);
}

=item $egs->transfer $obj

=cut

sub transfer {
	my ($self,$obj)=@_;
	$self->{TR}=$obj;
	return($self);
}

=item $egs->transfer2 $obj

=cut

sub transfer2 {
	my ($self,$obj)=@_;
	$self->{TR2}=$obj;
	return($self);
}

=item $egs->halftone $obj

=cut

sub halftone {
	my ($self,$obj)=@_;
	$self->{HT}=$obj;
	return($self);
}

sub halftonephase {
	my ($self,$obj)=@_;
	$self->{HTP}=$obj;
	return($self);
}

sub smoothness {
	my ($self,$var)=@_;
	$self->{SM}=PDFNum($var);
	return($self);
}

sub font {
	my ($self,$font,$size)=@_;
	$self->{Font}=PDFArray(PDFName($font->{' apiname'}),PDFNum($size));
	return($self);
}

sub linewidth {
	my ($self,$var)=@_;
	$self->{LW}=PDFNum($var);
	return($self);
}

sub linecap {
	my ($self,$var)=@_;
	$self->{LC}=PDFNum($var);
	return($self);
}

sub linejoin {
	my ($self,$var)=@_;
	$self->{LJ}=PDFNum($var);
	return($self);
}

sub meterlimit {
	my ($self,$var)=@_;
	$self->{ML}=PDFNum($var);
	return($self);
}

sub dash {
	my ($self,@dash)=@_;
	$self->{ML}=PDFArray( map { PDFNum($_); } @dash );
	return($self);
}

sub flatness {
	my ($self,$var)=@_;
	$self->{FL}=PDFNum($var);
	return($self);
}

sub renderingintent {
	my ($self,$var)=@_;
	$self->{FL}=PDFName($var);
	return($self);
}


#==================================================================
#	PDF::API2::Font
#==================================================================
package PDF::API2::Font;
use strict;
use PDF::API2::UniMap;
use PDF::API2::Util;
use Text::PDF::Utils;

=head2 PDF::API2::Font

=item $font2 = $font->clone $subkey

Returns a clone of a font object.

=cut

sub copy { die "COPY NOT IMPLEMENTED !!!";}

sub clone {
	my $self=shift @_;
	my $key=shift @_ || localtime();
	my $res=$self->copy($self->{' apipdf'});
	$self->{' apipdf'}->new_obj($res);
	$res->{' apiname'}.='_CLONEx'.pdfkey($key);
	$res->{'Name'}=PDFName($res->{' apiname'});

        $res->{' api'}->{pages}->{'Resources'}=$res->{' api'}->{pages}->{'Resources'} || PDFDict();
        $res->{' api'}->{pages}->{'Resources'}->{'Font'}=$res->{' api'}->{pages}->{'Resources'}->{'Font'} || PDFDict();
	$res->{' api'}->{pages}->{'Resources'}->{'Font'}->{$res->{' apiname'}}=$res;

	return($res);
}


=item @glyphs = $font->glyphs $encoding

Returns an array with glyphnames of the specified encoding.

=cut

sub glyphs {
	my ($self,$enc) = @_;
	$self->{' apipdf'}->{' encoding'}=$self->{' apipdf'}->{' encoding'} || {};
	$self->{' apipdf'}->{' encoding'}->{$enc}=$self->{' apipdf'}->{' encoding'}->{$enc} || PDF::API2::UniMap->new($enc);
	return($self->{' apipdf'}->{' encoding'}->{$enc}->glyphs);
}

=item $font->encode $encoding

Changes the encoding of the font object. If you want more than one encoding
for one font use 'clone' and then 'encode'.

B<Note:> The following encodings are supported (as of version 0.1.16_beta):

	adobe-standard adobe-symbol adobe-zapf-dingbats 
	cp1250 cp1251 cp1252 
	cp437 cp850
	es es2 pt pt2
	iso-8859-1 iso-8859-2 latin1 latin2
	koi8-r koi8-u
	macintosh
	microsoft-dingbats

B<Note:> Other encodings must be seperately installed via the pdf-api2-unimaps archive.

=cut

sub encode {
	my $self=shift @_;
	my ($encoding,@glyphs)=@_;
	if(scalar @glyphs < 1) {
		eval {
			@glyphs=$self->glyphs($encoding);
		};
		$encoding='custom';
	}
	
	if($self->{' apifontlight'}) {
		$self->encodeProperLight($encoding,32,255,@glyphs);
	} else {
		$self->encodeProper($encoding,32,255,@glyphs);
	}
}


=item $pdfstring = $font->text $text

Returns a properly formated string-representation of $text
for use in the PDF.

=cut

sub text {
	my ($font,$text)=@_;
	my ($newtext);
	foreach my $g (0..length($text)-1) {
		$newtext.=
			(substr($text,$g,1)=~/[\x00-\x1f\\\{\}\[\]\(\)\xa0-\xff]/)
			? sprintf('\%03lo',vec($text,$g,8))
			: substr($text,$g,1) ;
	}
	return("($newtext)");
}

=item $wd = $font->width $text

Returns the width of $text as if it were at size 1.

=cut

sub width {
	my ($self,$text)=@_;
	my ($width);
	foreach (unpack("C*", $text)) {
		$width += $self->{' AFM'}{'wx'}{$self->{' AFM'}{'char'}[$_]};
	}
	$width/=1000;
	return($width);
}

sub ascent      { return $_[0]->{' ascent'}; }
sub descent     { return $_[0]->{' descent'}; }
sub italicangle { return $_[0]->{' italicangle'}; }
sub fontbbx     { return @{$_[0]->{' fontbbox'}}; }
sub capheight   { return $_[0]->{' capheight'}; }
sub xheight     { return $_[0]->{' xheight'}; }


#==================================================================
#	PDF::API2::xFont
#==================================================================
package PDF::API2::xFont;
use strict;
use PDF::API2::UniMap;
use PDF::API2::Util;
use Text::PDF::Utils;
use Font::TTF::Font;

use vars qw(@ISA);
@ISA = qw( PDF::API2::Font Text::PDF::Dict );

=head2 PDF::API2::xFont

Provides special internal font-methods for PDF::API2.

=item @font_names = PDF::API2::xFont::listwinfonts

Returns an array with all the installed truetype font-names of your windows system,
or a default fallback (compatible with Acrobat 5) if under unix.

=cut

sub listwinfonts {
	opts_from_ttf('arial');
	opts_from_pfm('arial');
	return(sort keys %PDF::API2::Util::winfonts);
}

sub new {
	my ($class,$pdf,%opts) = @_;
	my ($self) = {};

	$class = ref $class if ref $class;

	$self = $class->SUPER::new();
	
	%opts=opts_from_ttf($opts{-ttfile},%opts) if(defined $opts{-ttfile});

	$self->{'Type'} = PDFName("Font");
	$self->{'Subtype'} = PDFName($opts{-type});
	$self->{'BaseFont'} = PDFName($opts{-fontname});
	$self->{'AlternateFont'} = PDFName($opts{-altname}) if(defined $opts{-altname});
	$self->{'Name'} = PDFName('FFXx'.pdfkey(%opts));
	$self->{'Encoding'}=PDFName('WinAnsiEncoding');
	$self->{'FirstChar'} = PDFNum($opts{-firstchar});
	$self->{'LastChar'} = PDFNum($opts{-lastchar});
	
	$self->{'Widths'}=PDFArray(map { PDFNum($_ || 0) } @{$opts{-widths}})  if(defined $opts{-widths});

	$self->{' fc'}=$opts{-firstchar};
	$self->{' wx'}=$opts{-widths};

	$self->{'FontDescriptor'}=PDFDict();
	$self->{'FontDescriptor'}->{'Type'}=PDFName('FontDescriptor');
	$self->{'FontDescriptor'}->{'FontName'}=PDFName($opts{-fontname});
	$self->{'FontDescriptor'}->{'Ascent'}=PDFNum($opts{-ascent}||0) if(defined $opts{-ascent});
	$self->{'FontDescriptor'}->{'Descent'}=PDFNum($opts{-descent}||0) if(defined $opts{-descent});
	$self->{'FontDescriptor'}->{'ItalicAngle'}=PDFNum($opts{-italicangle}||0) if(defined $opts{-italicangle});
	$self->{'FontDescriptor'}->{'CapHeight'}=PDFNum($opts{-capheight}||0) if(defined $opts{-capheight});
	$self->{'FontDescriptor'}->{'FontBBox'}=PDFArray(map { PDFNum($_ || 0) } @{$opts{-fontbbox}}) if(defined $opts{-fontbbox});
	$self->{'FontDescriptor'}->{'StemV'}=PDFNum($opts{-stemv}||0) if(defined $opts{-stemv});
	$self->{'FontDescriptor'}->{'StemH'}=PDFNum($opts{-stemh}||0) if(defined $opts{-stemh});
	$self->{'FontDescriptor'}->{'XHeight'}=PDFNum($opts{-xheight}||0) if(defined $opts{-xheight});

	$self->{'FontDescriptor'}->{'Flags'}=PDFNum($opts{-flags}) if(defined $opts{-flags});

	$self->{' ascent'}=$opts{-ascent}||0;
	$self->{' descent'}=$opts{-descent}||0;
	$self->{' italicangle'}=$opts{-italicangle}||0;
	$self->{' fontbbox'}=$opts{-fontbbox}||[0,0,600,600];
	$self->{' capheight'}=$opts{-capheight}||0;
	$self->{' xheight'}=$opts{-xheight}||0;
	
	if(defined($pdf) && !$self->is_obj($pdf)) {
		$pdf->new_obj($self);
	}

	if($opts{-embed} && defined $opts{-ttfile}) {
		my $s = PDFDict();
		$self->{'FontDescriptor'}->{'FontFile2'} = $s;
		$s->{'Length1'} = PDFNum(-s $opts{-ttfile});
		$s->{'Filter'} = PDFArray(PDFName("FlateDecode"));
		$s->{' streamfile'} = $opts{-ttfile};

		$pdf->new_obj($s);
	}

	$self->{' apifontlight'}=1;
	$self->{' apiname'}='FFXx'.pdfkey(%opts);
	$self->{' apipdf'}=$pdf;

	return($self);
}

sub copy { die "COPY NOT IMPLEMENTED !!!";}

sub clone {
	my $self=shift @_;
	return($self);
}

sub glyphs {
	my ($self,$enc) = @_;
	return $self;
}

sub encode {
	my $self=shift @_;
	$self;
}

sub width {
	my ($self,$text)=@_;
	my ($width);
	foreach (unpack("C*", $text)) {
		$width += $self->{' wx'}->[$_-$self->{' fc'}];
	}
	$width/=1000;
	return($width);
}

sub text_utf8 {
	my ($self,$text)=@_;
	$text=utf8_to_ucs2($text);
	foreach my $x (0..(length($text)>>1)-1) {
		vec($text,$x,8)=vec($text,$x,16) & 0xff;
	}
	$text=$self->text(substr($text,0,length($text)>>1));
	return($text);
}

sub width_utf8 {
	my ($self,$text)=@_;
	$text=utf8_to_ucs2($text);
	foreach my $x (0..(length($text)>>1)-1) {
		vec($text,$x,8)=vec($text,$x,16) & 0xff;
	}
	my $width=$self->width(substr($text,0,length($text)>>1));
	return($width);
}


sub ascent      { return $_[0]->{' ascent'}; }
sub descent     { return $_[0]->{' descent'}; }
sub italicangle { return $_[0]->{' italicangle'}; }
sub fontbbx     { return @{$_[0]->{' fontbbox'}}; }
sub capheight   { return $_[0]->{' capheight'}; }
sub xheight     { return $_[0]->{' xheight'}; }


#==================================================================
#	PDF::API2::CoreFont
#==================================================================
package PDF::API2::CoreFont;
use strict;
use PDF::API2::Util;
use Text::PDF::Utils;

use vars qw(@ISA);
@ISA = qw( Text::PDF::AFont PDF::API2::Font );

=head2 PDF::API2::CoreFont

Subclassed from Text::PDF::AFont and PDF::API2::Font.

=item $font = PDF::API2::CoreFont->new @parameters

Returns a adobe core font object (called from $pdf->corefont).

=cut

sub new {
	my ($class,$pdf,$name,$key,$light) = @_;
	my ($self) = {};

	$class = ref $class if ref $class;
	if($light==1) {
		$self = $class->SUPER::newCoreLight($pdf,$name,$key);
		$self->{' apifontlight'}=1;
	} else {
		$self = $class->SUPER::newCore($pdf,$name,$key);
	}
	$self->{' apiname'}=$key;
	$self->{' apipdf'}=$pdf;

	return($self);
}

sub coerce {
	my ($class,$font,$pdf,$name,$key,$light) = @_;
	my ($self) = {};
	
	$class = ref $class if ref $class;
	if($light==1) {
		$self = $class->SUPER::newCoreLight(undef,$name,$key);
		$self->{' apifontlight'}=1;
	} else {
		$self = $class->SUPER::newCore(undef,$name,$key);
	}
	$self->{' apiname'}=$key;
	$self->{' apipdf'}=$pdf;
 
	foreach my $k (keys %{$font}) {
		$self->{$k}=$font->{$k};
	}

	return($self);
}


#==================================================================
#	PDF::API2::PSFont
#==================================================================
package PDF::API2::PSFont;
use strict;
use PDF::API2::Util;
use Text::PDF::Utils;

use vars qw(@ISA);
@ISA = qw( Text::PDF::AFont PDF::API2::Font );

=head2 PDF::API2::PSFont

Subclassed from Text::PDF::AFont and PDF::API2::Font.

=item $font = PDF::API2::PSFont->new @parameters

Returns a adobe type1 font object (called from $pdf->psfont).

=cut

sub new {
	my ($class, @para) = @_;
	my ($self) = {};

	$class = ref $class if ref $class;
	$self = $class->SUPER::new(@para);

	$self->{' apiname'}=$para[3];
	$self->{' apipdf'}=$para[0];

	return($self);
}


#==================================================================
#	PDF::API2::TTFont
#==================================================================
package PDF::API2::TTFont;
use strict;
use PDF::API2::UniMap qw( utf8_to_ucs2 );
use PDF::API2::Util;
use Text::PDF::Utils;

use vars qw(@ISA);
@ISA = qw( Text::PDF::TTFont0 PDF::API2::Font );

=head2 PDF::API2::TTFont

Subclassed from Text::PDF::TTFont0 and PDF::API2::Font.

=item $font = PDF::API2::TTFont->new $pdf,$ttffile,$pdfname

Returns a truetype font object (called from $pdf->ttfont).

=cut

sub new {
	my ($class, $pdf,$file,$name) = @_;

	$class = ref $class if ref $class;
	my $self = $class->SUPER::new($pdf,$file,$name, -subset => 1);

	my $ttf=$self->{' font'};
	$ttf->{'cmap'}->read;
	$ttf->{'hmtx'}->read;
	$ttf->{'post'}->read;
	my $upem = $ttf->{'head'}->read->{'unitsPerEm'};

	$self->{' unicid'}=();
	$self->{' uniwidth'}=();
	my @map=$ttf->{'cmap'}->reverse;
	foreach my $x (0..scalar(@map)) {
		$self->{' unicid'}{$map[$x]||0}=$x;
		$self->{' uniwidth'}{$map[$x]||0}=$ttf->{'hmtx'}{'advance'}[$x]*1000/$upem;
	}
	$self->{' encoding'}='latin1';
	$self->{' chrcid'}={};
	$self->{' chrcid'}->{'latin1'}=();
	$self->{' chrwidth'}={};
	$self->{' chrwidth'}->{'latin1'}=();
	foreach my $x (0..255) {
		$self->{' chrcid'}->{'latin1'}{$x}=$self->{' unicid'}{$x}||$self->{' unicid'}{32};
		$self->{' chrwidth'}->{'latin1'}{$x}=$ttf->{'hmtx'}{'advance'}[$self->{' unicid'}{$x}||$self->{' unicid'}{32}]*1000/$upem;
	}

	$self->{' apiname'}=$name;
	$self->{' apipdf'}=$pdf;

	return($self);
}

=item $pdfstring = $font->text $text

Returns a properly formated string-representation of $text
for use in the PDF.

=cut

sub text {
	my ($self,$text,$enc)=@_;
	$enc=$enc||$self->{' encoding'};
	my ($newtext);
	$self->{' subvec'}='' unless($self->{' subvec'});
	foreach (unpack("C*", $text)) {
		my $g=$self->{' chrcid'}{$enc}{$_};
		$newtext.= sprintf('%04x',$g);
		vec($self->{' subvec'},$g,1)=1;
	}
	return("<$newtext>");
}

=item $pdfstring = $font->text_utf8 $text

Returns a properly formated string-representation of $text
for use in the PDF but requires $text to be in UTF8.

=cut

sub text_utf8 {
	my ($self,$text)=@_;
	$text=utf8_to_ucs2($text);
	my ($newtext);
	foreach my $x (0..(length($text)>>1)-1) {
		my $g=$self->{' unicid'}{vec($text,$x,16)};
		$newtext.= sprintf('%04x',$g);
		vec($self->{' subvec'},$g,1)=1;
	}
	return("<$newtext>");
}

=item $wd = $font->width $text

Returns the width of $text as if it were at size 1.

=cut

sub width {
	my ($self,$text,$enc)=@_;
	$enc=$enc||$self->{' encoding'};
	my ($width);
	foreach (unpack("C*", $text)) {
		$width += $self->{' chrwidth'}{$enc}{$_};
	}
	$width/=1000;
	return($width);
}

=item $wd = $font->width_utf8 $text

Returns the width of $text as if it were at size 1,
but requires $text to be in UTF8.

=cut

sub width_utf8 {
	my ($self,$text)=@_;
	$text=utf8_to_ucs2($text);
	my ($width);
	foreach my $x (0..(length($text)>>1)-1) {
		$width += $self->{' uniwidth'}{vec($text,$x,16)};
	}
	$width/=1000;
	return($width);
}

=item $font->encode $encoding

Changes the encoding of the font object. Since encodings are one virtual
in ::API2 for truetype fonts you DONT have to use 'clone'.

=cut

sub encode {
	my ($self,$enc)=@_;

	$self->{' apipdf'}->{' encoding'}=$self->{' apipdf'}->{' encoding'} || {};
	$self->{' apipdf'}->{' encoding'}->{$enc}=$self->{' apipdf'}->{' encoding'}->{$enc} || PDF::API2::UniMap->new($enc);

	my $map=$self->{' apipdf'}->{' encoding'}->{$enc};

	my $ttf=$self->{' font'};
	my $upem = $ttf->{'head'}->read->{'unitsPerEm'};

	$self->{' encoding'}=$enc;
	$self->{' chrcid'}->{$enc}=$self->{' chrcid'}->{$enc}||{};
	$self->{' chrwidth'}->{$enc}=$self->{' chrwidth'}->{$enc}||{};
	if(scalar keys(%{$self->{' chrcid'}->{$enc}}) < 1) {
		foreach my $x (0..255) {
			$self->{' chrcid'}->{$enc}{$x}=
				$self->{' unicid'}{$map->{'c2u'}->{$x}||32}||$self->{' unicid'}{32};
			$self->{' chrwidth'}->{$enc}{$x}=
				$ttf->{'hmtx'}{'advance'}[$self->{' unicid'}{$map->{'c2u'}->{$x}||32}||$self->{' unicid'}{32}]*1000/$upem;
		}
	}
	return($self);
}


#==================================================================
#	PDF::API2::Page
#==================================================================
package PDF::API2::Page;

use strict;
use vars qw(@ISA);
@ISA = qw(Text::PDF::Pages);
use Text::PDF::Pages;
use Text::PDF::Utils;

use PDF::API2::Util;

use Math::Trig;

=head2 PDF::API2::Page

Subclassed from Text::PDF::Pages

=item $page = PDF::API2::Page->new $pdf, $parent, $index

Returns a page object (called from $pdf->page).

=cut

sub new {
    my ($class, $pdf, $parent, $index) = @_;
    my ($self) = {};

    $class = ref $class if ref $class;
    $self = $class->SUPER::new($pdf, $parent);
    $self->{'Type'} = PDFName('Page');
    delete $self->{'Count'};
    delete $self->{'Kids'};
    $parent->add_page($self, $index);
    $self;
}

=item $page = PDF::API2::Page->coerce $pdf, $pdfpage

Returns a page object converted from $pdfpage (called from $pdf->openpage).

=cut

sub coerce {
	my ($class, $pdf, $page) = @_;
	my ($self) = {};
	bless($self);
	foreach my $k (keys %{$page}) {
		$self->{$k}=$page->{$k};
	}
	$self->{' apipdf'}=$pdf;
	return($self);
}

=item $page->update

Marks a page to be updated (by $pdf->update).

=cut

sub update {
	my ($self) = @_;
	$self->{' apipdf'}->out_obj($self);
	$self;
}

=item $page->mediabox $w, $h

=item $page->mediabox $llx, $lly, $urx, $ury

Sets the mediabox.

=cut

sub mediabox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'MediaBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} else {
		$self->{'MediaBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	}
	$self;
}

=item $page->cropbox $w, $h

=item $page->cropbox $llx, $lly, $urx, $ury

Sets the cropbox.

=cut

sub cropbox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'CropBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} else {
		$self->{'CropBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	}
	$self;
}

=item $page->bleedbox $w, $h

=item $page->bleedbox $llx, $lly, $urx, $ury

Sets the bleedbox.

=cut

sub bleedbox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'BleedBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} else {
		$self->{'BleedBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	}
	$self;
}

=item $page->trimbox $w, $h

=item $page->trimbox $llx, $lly, $urx, $ury

Sets the trimbox.

=cut

sub trimbox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'TrimBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} else {
		$self->{'TrimBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	}
	$self;
}

=item $page->artbox $w, $h

=item $page->artbox $llx, $lly, $urx, $ury

Sets the artbox.

=cut

sub artbox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'ArtBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} else {
		$self->{'ArtBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	}
	$self;
}

=item $gfx = $page->gfx

Returns a graphics content object.

=cut

sub fixcontents {
	my ($self) = @_;
        $self->{'Contents'} = $self->{'Contents'} || PDFArray();
        if(ref($self->{'Contents'})=~/Objind$/) {
		$self->{'Contents'}->realise;
	}
        if(ref($self->{'Contents'})!~/Array$/) {
	        $self->{'Contents'} = PDFArray($self->{'Contents'});
	}
}

sub gfx {
	my ($self) = @_;
        $self->fixcontents;
	my $gfx=PDF::API2::Gfx->new();
        $self->{'Contents'}->add_elements($gfx);
        $self->{' apipdf'}->new_obj($gfx);
        $gfx->{' apipdf'}=$self->{' apipdf'};
        $gfx->{' apipage'}=$self;
        return($gfx);
}

=item $txt = $page->text

Returns a text content object.

=cut

sub text {
	my ($self) = @_;
        $self->fixcontents;
	my $text=PDF::API2::Text->new();
        $self->{'Contents'}->add_elements($text);
        $self->{' apipdf'}->new_obj($text);
        $text->{' apipdf'}=$self->{' apipdf'};
        $text->{' apipage'}=$self;
        return($text);
}

=item $hyb = $page->hybrid

Returns a hybrid content object.

=cut

sub hybrid {
	my ($self) = @_;
        $self->fixcontents;
	my $hyb=PDF::API2::Hybrid->new();
        $self->{'Contents'}->add_elements($hyb);
        $self->{' apipdf'}->new_obj($hyb);
        $hyb->{' apipdf'}=$self->{' apipdf'};
        $hyb->{' apipage'}=$self;
        return($hyb);
}

=item $ant = $page->annotation

Returns a annotation object.

=cut

sub annotation {
	my ($self, $type, $key, $obj) = @_;
        $self->{'Annots'} = $self->{'Annots'} || PDFArray();
	my $ant=PDF::API2::Annotation->new;
        $self->{'Annots'}->add_elements($ant);
        $self->{' apipdf'}->new_obj($ant);
        $ant->{' apipdf'}=$self->{' apipdf'};
        $ant->{' apipage'}=$self;
        return($ant);
}

=item $page->resource $type, $key, $obj

Adds a resource to the page-inheritance tree.

B<Example:>

	$co->resource('Font',$fontkey,$fontobj);
	$co->resource('XObject',$imagekey,$imageobj);
	$co->resource('Shading',$shadekey,$shadeobj);
	$co->resource('ColorSpace',$spacekey,$speceobj);

B<Note:> You only have to add the required resources, if
they are NOT handled by the *font*, *image*, *shade* or *space*
methods.

=cut

sub resource {
	my ($self, $type, $key, $obj, $force) = @_;
	my ($dict) = $self->find_prop('Resources');

	$dict= $dict || $self->{Resources} || PDFDict();	

	$dict->realise if(ref($dict)=~/Objind$/);

	$dict->{$type}=$dict->{$type} || PDFDict();
	$dict->{$type}->realise if(ref($dict->{$type})=~/Objind$/);
	
	if($force) {
		$dict->{$type}->{$key}=$obj;
	} else {
		$dict->{$type}->{$key}=$dict->{$type}->{$key} || $obj;
	}

	$self->{' apipdf'}->out_obj($dict)
		if($dict->is_obj($self->{' apipdf'}));
	
	$self->{' apipdf'}->out_obj($dict->{$type})
		if($dict->{$type}->is_obj($self->{' apipdf'}));
	
	$self->{' apipdf'}->out_obj($obj)
		if($obj->is_obj($self->{' apipdf'}));

        $self->{' apipdf'}->out_obj($self);
		
	return($dict);
}

sub content {
	my ($self,$obj) = @_;
        $self->fixcontents;
        $self->{'Contents'}->add_elements($obj);
##	$self->{' apipdf'}->new_obj($obj);
        $obj->{' apipdf'}=$self->{' apipdf'};
        $obj->{' apipage'}=$self;
        return($obj);
}

sub ship_out
{
    my ($self, $pdf) = @_;

    $pdf->ship_out($self);
    if (defined $self->{'Contents'})
    { $pdf->ship_out($self->{'Contents'}->elementsof); }
    $self;
}


#==================================================================
#	PDF::API2::Annotation
#==================================================================
package PDF::API2::Annotation;

use strict;
use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict);

use Text::PDF::Dict;
use Text::PDF::Utils;
use Math::Trig;
use PDF::API2::Util;

=head2 PDF::API2::Annotation

Subclassed from Text::PDF::Dict.

=item $ant = PDF::API2::Annotation->new 

Returns a annotation object (called from $page->annotation).

=cut

sub new {
	my ($class,%opts)=@_;
	my $self=$class->SUPER::new;
	$self->{Type}=PDFName('Annot');
	return($self);
}

sub link {
	my ($self,$page,%opts)=@_;
	$self->{Subtype}=PDFName('Link');
	$self->dest($page,%opts);
	$self->rect(@{$opts{-rect}}) if(defined $opts{-rect});
	$self->border(@{$opts{-border}}) if(defined $opts{-border});
	return($self);
}

sub text {
	my ($self,$text,%opts)=@_;
	$self->{Subtype}=PDFName('Text');
	$self->content($text);
	$self->rect(@{$opts{-rect}}) if(defined $opts{-rect});
	$self->open($opts{-open}) if(defined $opts{-open});
	return($self);
}

sub rect {
	my ($self,@r)=@_;
	die "insufficient parameters to annotation->rect( ) " unless(scalar @r == 4);
	$self->{Rect}=PDFArray( map { PDFNum($_) } $r[0..3] );
	return($self);
}

sub border {
	my ($self,@r)=@_;
	die "insufficient parameters to annotation->border( ) " unless(scalar @r == 3);
	$self->{Border}=PDFArray( map { PDFNum($_) } $r[0..2] );
	return($self);
}

sub content {
	my ($self,@t)=@_;
	$self->{Content}=PDFStr(join("\n",@t));
	return($self);
}

sub name {
	my ($self,$n)=@_;
	$self->{Name}=PDFName($n);
	return($self);
}

sub open {
	my ($self,$n)=@_;
	$self->{Open}=PDFBool( $n ? 1 : 0 );
	return($self);
}

=item $ant->dest( $page, -fit => 1 ) 

Display the page designated by page, with its contents magnified just enough to 
fit the entire page within the window both horizontally and vertically. If the 
required horizontal and vertical magnification factors are different, use the 
smaller of the two, centering the page within the window in the other dimension.

=item $ant->dest( $page, -fith => $top )

Display the page designated by page, with the vertical coordinate top positioned
at the top edge of the window and the contents of the page magnified just enough 
to fit the entire width of the page within the window.

=item $ant->dest( $page, -fitv => $left ) 

Display the page designated by page, with the horizontal coordinate left positioned
at the left edge of the window and the contents of the page magnified just enough 
to fit the entire height of the page within the window.

=item $ant->dest( $page, -fitr => [ $left, $bottom, $right, $top ] ) 

Display the page designated by page, with its contents magnified just enough to 
fit the rectangle specified by the coordinates left, bottom, right, and top 
entirely within the window both horizontally and vertically. If the required
horizontal and vertical magnification factors are different, use the smaller of
the two, centering the rectangle within the window in the other dimension.

=item $ant->dest( $page, -fitb => 1 )

(PDF 1.1) Display the page designated by page, with its contents magnified just 
enough to fit its bounding box entirely within the window both horizontally and 
vertically. If the required horizontal and vertical magnification factors are 
different, use the smaller of the two, centering the bounding box within the 
window in the other dimension.

=item $ant->dest( $page, -fitbh => $top )

(PDF 1.1) Display the page designated by page, with the vertical coordinate top 
positioned at the top edge of the window and the contents of the page magnified 
just enough to fit the entire width of its bounding box within the window.

=item $ant->dest( $page, -fitbv => $left )

(PDF 1.1) Display the page designated by page, with the horizontal coordinate 
left positioned at the left edge of the window and the contents of the page 
magnified just enough to fit the entire height of its bounding box within the 
window.

=item $ant->dest( $page, -xyz => [ $left, $top, $zoom ] )

Display the page designated by page, with the coordinates (left, top) positioned 
at the top-left corner of the window and the contents of the page magnified by 
the factor zoom. A zero (0) value for any of the parameters left, top, or zoom 
specifies that the current value of that parameter is to be retained unchanged.

=cut

sub dest {
	my ($self,$page,%opts)=@_;
	
	die "no valid page '$page' specified." if(!ref($page));
	
	$opts{-fit}=1 if(scalar(keys %opts)<1);
	
	if(defined $opts{-fit}) {
		$self->{Dest}=PDFArray($page,PDFName('Fit'));
	} elsif(defined $opts{-fith}) {
		$self->{Dest}=PDFArray($page,PDFName('FitH'),PDFNum($opts{-fith}));
	} elsif(defined $opts{-fitb}) {
		$self->{Dest}=PDFArray($page,PDFName('FitB'));
	} elsif(defined $opts{-fitbh}) {
		$self->{Dest}=PDFArray($page,PDFName('FitBH'),PDFNum($opts{-fitbh}));
	} elsif(defined $opts{-fitv}) {
		$self->{Dest}=PDFArray($page,PDFName('FitV'),PDFNum($opts{-fitv}));
	} elsif(defined $opts{-fitbv}) {
		$self->{Dest}=PDFArray($page,PDFName('FitBV'),PDFNum($opts{-fitbv}));
	} elsif(defined $opts{-fitr}) {
		die "insufficient parameters to ->dest( page, -fitr => [] ) " unless(scalar @{$opts{-fitr}} == 4);
		$self->{Dest}=PDFArray($page,PDFName('FitR'),map {PDFNum($_)} @{$opts{-fitr}});
	} elsif(defined $opts{-xyz}) {
		die "insufficient parameters to ->dest( page, -xyz => [] ) " unless(scalar @{$opts{-fitr}} == 3);
		$self->{Dest}=PDFArray($page,PDFName('XYZ'),map {PDFNum($_)} @{$opts{-xyz}});
	}
	return($self);
}


#==================================================================
#	PDF::API2::Content
#==================================================================
package PDF::API2::Content;

use strict;
use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict);

use Text::PDF::Dict;
use Text::PDF::Utils;
use Math::Trig;
use PDF::API2::Util;

=head2 PDF::API2::Content

Subclassed from Text::PDF::Dict.

=item $co = PDF::API2::Content->new @parameters

Returns a new content object (called from $page->text/gfx).

=cut

sub new {
	my ($class)=@_;
	my $self = $class->SUPER::new(@_);
	$self->save;
	return($self);
}

=item $co->add @content

Adds @content to the object.

=cut

sub add {
	my $self=shift @_;
	$self->{' stream'}.=join(' ',@_)."\n";
}

=item $co->save

Saves the state of the object.

=cut

sub save {
	my $self=shift @_;
	$self->add('q');
}

=item $co->restore

Restores the state of the object.

=cut

sub restore {
	my $self=shift @_;
	$self->add('Q');
}

=item $co->compress

Marks content for compression on output.

=cut

sub compress {
	my $self=shift @_;
	$self->{'Filter'}=PDFArray(PDFName('FlateDecode'));
	return($self);
}

sub outobjdeep {
	my ($self, $fh, $pdf) = @_;
	$self->restore;
	$self->SUPER::outobjdeep($fh, $pdf);
}

=item $co->fillcolor $grey

=item $co->fillcolor $api2colorobject

=item $co->fillcolor $red, $green, $blue

=item $co->fillcolor $cyan, $magenta, $yellow, $black

=item $co->fillcolorbyname $colorname, $ascmyk

=item $co->fillcolorbyspace $colorspace, @colordef

Sets fillcolor.

=cut

sub checkcolor {
	my ($t,$c,$m,$y,$k)=@_;

	if (!defined($k)) {
		if (!defined($m)) {
			if($c=~/^[a-z\!\$\%\&\#]+/) {
				my @col=namecolor($c);
				return(checkcolor($t,@col));
			} else {
				return('g',$c) unless(ref $t);
				if($t->isRGB) {
					return('sc',$c,$c,$c);
				} elsif($t->isCMYK) {
					return('sc',0,0,0,1-$c);
				} elsif($t->isGray) {
					return('sc',$c);
				} elsif($t->isIndexed) {
					return('sc',$c);
				} else {
					die "undefined color=(".join(',',$c,$m,$y,$k).") in colorspace $t of type=($t->{' type'})";
				}
			}
		} else {
			return('rg',$c,$m,$y) unless(ref $t);
			if($t->isRGB) {
				return('sc',$c,$m,$y);
			} elsif($t->isCMYK) {
				return('sc',1-$c,1-$m,1-$y,0);
			} elsif($t->isGray) {
				return('sc',($c+$m+$y)/3);
			} else {
				return('sc',$c,$m,$y);
			}
		}
	} else {
		return('k',$c,$m,$y,$k) unless(ref $t);
		if($t->isRGB) {
			return('sc',1-$c-$k,1-$m-$k,1-$y-$k);
		} elsif($t->isCMYK) {
			return('sc',$c,$m,$y,$k);
		} elsif($t->isGray) {
			return('sc',(3-$c-$k-$m-$k-$y-$k)/3);
		} else {
			return('sc',$c,$m,$y,$k);
		}
	}
}

sub fillcolor {
	my $self=shift @_;
	my ($obj,$c,$m,$y,$k,$type,@clrs);
	$obj=shift @_;
	if(ref($obj) eq 'PDF::API2::Color') {
		$self->add(floats($obj->asCMYK),'k');
	} elsif(ref($obj) eq 'PDF::API2::ColorSpace') {
		if($obj->isRGB || $obj->isCMYK||$obj->isGray) {
			($type,@clrs)=checkcolor($obj,@_);
			$self->add("/$obj->{' apiname'}",'cs',floats(@clrs),$type);
		} else {
			$self->add("/$obj->{' apiname'}",'cs',floats(@_),'sc');
		}
		$self->resource('ColorSpace',$obj->{' apiname'},$obj);
	} elsif(ref($obj) eq 'PDF::API2::Pattern') {
		$self->add("/Pattern",'cs',"/$obj->{' apiname'}",'scn');
		$self->resource('Pattern',$obj->{' apiname'},$obj);
	} else {
		($m,$y,$k)=@_;
		$c=$obj;
		($type,@clrs)=checkcolor(undef,$c,$m,$y,$k);
		$self->add(floats(@clrs),$type);
	}
	
	return($self);
}

sub fillcolorbyname {
	my ($self,$name,$ascmyk)=@_;
	my @col=namecolor($name);
	@col=RGBasCMYK(@col) if($ascmyk);
	$self->fillcolor(@col);
	return($self);
}

sub fillcolorbyspace {
	my ($self,$cs,@para)=@_;
	$self->fillcolor($cs,@para);
	return($self);
}

=item $co->strokecolor $grey

=item $co->strokecolor $api2colorobject

=item $co->strokecolor $red, $green, $blue

=item $co->strokecolor $cyan, $magenta, $yellow, $black

=item $co->strokecolorbyname $colorname, $ascmyk

=item $co->strokecolorbyspace $colorspace, @colordef

Sets strokecolor.

B<Defined color-names are:>
	
	aliceblue, antiquewhite, aqua, aquamarine, azure,
	beige, bisque, black, blanchedalmond, blue, 
	blueviolet, brown, burlywood, cadetblue, chartreuse, 
	chocolate, coral, cornflowerblue, cornsilk, crimson, 
	cyan, darkblue, darkcyan, darkgoldenrod, darkgray, 
	darkgreen, darkgrey, darkkhaki, darkmagenta, 
	darkolivegreen, darkorange, darkorchid, darkred,
	darksalmon, darkseagreen, darkslateblue, darkslategray,
	darkslategrey, darkturquoise, darkviolet, deeppink, 
	deepskyblue, dimgray, dimgrey, dodgerblue, firebrick, 
	floralwhite, forestgreen, fuchsia, gainsboro, ghostwhite, 
	gold, goldenrod, gray, grey, green, greenyellow, 
	honeydew, hotpink, indianred, indigo, ivory, khaki, 
	lavender, lavenderblush, lawngreen, lemonchiffon, 
	lightblue, lightcoral, lightcyan, lightgoldenrodyellow, 
	lightgray, lightgreen, lightgrey, lightpink, lightsalmon,
	lightseagreen, lightskyblue, lightslategray, 
	lightslategrey, lightsteelblue, lightyellow, lime, 
	limegreen, linen, magenta, maroon, mediumaquamarine, 
	mediumblue, mediumorchid, mediumpurple, mediumseagreen, 
	mediumslateblue, mediumspringgreen, mediumturquoise, 
	mediumvioletred, midnightblue, mintcream, mistyrose, 
	moccasin, navajowhite, navy, oldlace, olive, olivedrab, 
	orange, orangered, orchid, palegoldenrod, palegreen, 
	paleturquoise, palevioletred, papayawhip, peachpuff, 
	peru, pink, plum, powderblue, purple, red, rosybrown, 
	royalblue, saddlebrown, salmon, sandybrown, seagreen, 
	seashell, sienna, silver, skyblue, slateblue, slategray, 
	slategrey, snow, springgreen, steelblue, tan, teal, 
	thistle, tomato, turquoise, violet, wheat, white, 
	whitesmoke, yellow, yellowgreen
	
or the rgb-hex-notation:
	
	#rgb, #rrggbb, #rrrgggbbb and #rrrrggggbbbb

or the cmyk-hex-notation:
	
	%cmyk, %ccmmyykk, %cccmmmyyykkk and %ccccmmmmyyyykkkk

and additionally the hsv-hex-notation:

	!hsv, !hhssvv, !hhhsssvvv and !hhhhssssvvvv

=cut

sub strokecolor {
	my $self=shift @_;
	my ($obj,$c,$m,$y,$k,$type,@clrs);
	$obj=shift @_;
	if(ref($obj) eq 'PDF::API2::Color') {
		$self->add(floats($obj->asCMYK),'K');
	} elsif(ref($obj) eq 'PDF::API2::ColorSpace') {
		if($obj->isRGB || $obj->isCMYK||$obj->isGray) {
			($type,@clrs)=checkcolor($obj,@_);
			$self->add("/$obj->{' apiname'}",'CS',floats(@clrs),uc $type);
		} else {
			$self->add("/$obj->{' apiname'}",'CS',floats(@_),'SC');
		}
		$self->resource('ColorSpace',$obj->{' apiname'},$obj);
	} elsif(ref($obj) eq 'PDF::API2::Pattern') {
		$self->add("/Pattern",'CS',"/$obj->{' apiname'}",'SCN');
		$self->resource('Pattern',$obj->{' apiname'},$obj);
	} else {
		($m,$y,$k)=@_;
		$c=$obj;
		($type,@clrs)=checkcolor(undef,$c,$m,$y,$k);
		$self->add(floats(@clrs),uc $type);
	}
	
	return($self);
}

sub strokecolorbyname {
	my ($self,$name,$ascmyk)=@_;
	my @col=namecolor($name);
	@col=RGBasCMYK(@col) if($ascmyk);
	$self->strokecolor(@col);
	return($self);
}

sub strokecolorbyspace {
	my ($self,$cs,@para)=@_;
	$self->strokecolor($cs,@para);
	return($self);
}

=item $co->flatness $flat

Sets flatness.

=cut

sub flatness {
	my ($self,$flatness)=@_;
	$self->add($flatness,'i');
}

=item $co->linecap $cap

Sets linecap.

=cut

sub linecap {
	my ($this,$linecap)=@_;
	$this->add($linecap,'J');
}

=item $co->linedash @dash

Sets linedash.

=cut

sub linedash {
	my ($self,@a)=@_;
	if(scalar @a < 1) {
		$self->add('[ 1 ] 0 d');
	} else {
		$self->add('[',floats(@a),'] 0 d');
	}
}

=item $co->linejoin $join

Sets linejoin.

=cut

sub linejoin {
	my ($this,$linejoin)=@_;
	$this->add($linejoin,'j');
}

=item $co->linewidth $width

Sets linewidth.

=cut

sub linewidth {
	my ($this,$linewidth)=@_;
	$this->add($linewidth,'w');
}

=item $co->meterlimit $limit

Sets meterlimit.

=cut

sub meterlimit {
	my ($this, $limit)=@_;
	$this->add($limit,'M');
}

=item $co->matrix $a,$b,$c,$d,$e,$f

Sets matrix transformation.

=cut

sub matrix {
	my $self=shift @_;
	my ($a,$b,$c,$d,$e,$f)=@_;
	$self->add(floats($a,$b,$c,$d,$e,$f),'cm');
}

=item $co->translate $x,$y

Sets translation transformation.

=cut

sub translate {
	my ($self,$x,$y)=@_;
	$self->matrix(1,0,0,1,$x,$y);
}

=item $co->scale $sx,$sy

Sets scaleing transformation.

=cut

sub scale {
	my ($self,$x,$y)=@_;
	$self->matrix($x,0,0,$y,0,0);
}

=item $co->skew $sa,$sb

Sets skew transformation.

=cut

sub skew {
	my ($self,$a,$b)=@_;
	$self->matrix(1, tan(deg2rad($a)),tan(deg2rad($b)),1,0,0);
}

=item $co->rotate $rot

Sets rotation transformation.

=cut

sub rotate {
	my ($self,$a)=@_;
	$self->matrix(cos(deg2rad($a)), sin(deg2rad($a)),-sin(deg2rad($a)), cos(deg2rad($a)),0,0);
}

=item $co->transform %opts

Sets transformations (eg. translate, rotate, scale, skew) in pdf-canonical order.

B<Example:>

	$co->transform(
		-translate => [$x,$y],
		-rotate    => $rot,
		-scale     => [$sx,$sy],
		-skew      => [$sa,$sb],
	)

=cut

sub transform {
	my ($self,%opt)=@_;
	my $mtx=PDF::API2::Matrix->new([1,0,0],[0,1,0],[0,0,1]);
	foreach my $o (qw( -skew -scale -rotate -translate )) {
		next unless(defined($opt{$o}));
		if($o eq '-translate') {
			my ($tx,$ty)=@{$opt{$o}};
			$mtx=$mtx->multiply(PDF::API2::Matrix->new([1,0,0],[0,1,0],[$tx,$ty,1]));
		} elsif($o eq '-rotate') {
			my $rot=$opt{$o};
			$mtx=$mtx->multiply(PDF::API2::Matrix->new(
				[ cos(deg2rad($rot)),sin(deg2rad($rot)),0],
				[-sin(deg2rad($rot)),cos(deg2rad($rot)),0],
				[0,0,1]
			));
		} elsif($o eq '-scale') {
			my ($sx,$sy)=@{$opt{$o}};
			$mtx=$mtx->multiply(PDF::API2::Matrix->new([$sx,0,0],[0,$sy,0],[0,0,1]));
		} elsif($o eq '-skew') {
			my ($sa,$sb)=@{$opt{$o}};
			$mtx=$mtx->multiply(PDF::API2::Matrix->new(
				[1,tan(deg2rad($sa)),0],
				[tan(deg2rad($sb)),1,0],
				[0,0,1]
			));
		}
	}
	$self->matrix(
		$mtx->[0][0],$mtx->[0][1],
		$mtx->[1][0],$mtx->[1][1],
		$mtx->[2][0],$mtx->[2][1]
	);
	return($self);
}

=item $co->resource $type, $key, $obj

Adds a resource to the page-inheritance tree.

B<Example:>

	$co->resource('Font',$fontkey,$fontobj);
	$co->resource('XObject',$imagekey,$imageobj);
	$co->resource('Shading',$shadekey,$shadeobj);
	$co->resource('ColorSpace',$spacekey,$speceobj);

B<Note:> You only have to add the required resources, if
they are NOT handled by the *font*, *image*, *shade* or *space*
methods.

=cut

sub resource {
	my ($self, $type, $key, $obj) = @_;
	$self->{' apipage'}->resource($type, $key, $obj);
	return($self);
}

#==================================================================
#	PDF::API2::Gfx
#==================================================================
package PDF::API2::Gfx;

use strict;
use vars qw(@ISA);
@ISA = qw(PDF::API2::Content);

use Text::PDF::Utils;
use PDF::API2::Util;
use Math::Trig;

=head2 PDF::API2::Gfx

Subclassed from PDF::API2::Content.

=item $gfx = PDF::API2::Gfx->new @parameters

Returns a new graphics content object (called from $page->gfx).

=item $gfx->matrix $a, $b, $c, $d, $e, $f

Sets the matrix.

=cut

sub matrix {
	my $self=shift @_;
	my ($a,$b,$c,$d,$e,$f)=@_;
	$self->add(floats($a,$b,$c,$d,$e,$f),'cm');
	return($self);
}

=item $gfx->move $x, $y

=cut

sub move { # x,y ...
	my $self=shift @_;
	my($x,$y);
	while(defined($x=shift @_)) {
		$y=shift @_;
		$self->{' x'}=$x;
		$self->{' y'}=$y;
		$self->{' mx'}=$x;
		$self->{' my'}=$y;
		$self->add(floats($x,$y),'m');
	}
	return($self);
}

=item $gfx->line $x, $y

=cut

sub line { # x,y ...
	my $self=shift @_;
	my($x,$y);
	while(defined($x=shift @_)) {
		$y=shift @_;
		$self->{' x'}=$x;
		$self->{' y'}=$y;
		$self->add(floats($x,$y),'l');
	}
	return($self);
}

=item $gfx->hline $x

=cut

sub hline { 
	my($self,$x)=@_;
	$self->add(floats($x,$self->{' y'}),'l');
	$self->{' x'}=$x;
	return($self);
}

=item $gfx->vline $y

=cut

sub vline { 
	my($self,$y)=@_;
	$self->add(floats($self->{' x'},$y),'l');
	$self->{' y'}=$y;
	return($self);
}

=item $gfx->curve $x1, $y1, $x2, $y2, $x3, $y3

=cut

sub curve { # x1,y1,x2,y2,x3,y3 ...
	my $self=shift @_;
	my($x1,$y1,$x2,$y2,$x3,$y3);
	while(defined($x1=shift @_)) {
		$y1=shift @_;
		$x2=shift @_;
		$y2=shift @_;
		$x3=shift @_;
		$y3=shift @_;
		$self->add(floats($x1,$y1,$x2,$y2,$x3,$y3),'c');
		$self->{' x'}=$x3;
		$self->{' y'}=$y3;
	}
	return($self);
}

sub arctocurve {
        my ($a,$b,$alpha,$beta)=@_;
        if(abs($beta-$alpha) > 180) {
        	return (
        		arctocurve($a,$b,$alpha,($beta+$alpha)/2),
        		arctocurve($a,$b,($beta+$alpha)/2,$beta)
        	);
        } else {
                $alpha = ($alpha * 3.1415 / 180);
                $beta  = ($beta * 3.1415 / 180);

                my $bcp = (4.0/3 * (1 - cos(($beta - $alpha)/2)) / sin(($beta - $alpha)/2));
                my $sin_alpha = sin($alpha);
                my $sin_beta =  sin($beta);
                my $cos_alpha = cos($alpha);
                my $cos_beta =  cos($beta);

                my $p0_x = $a * $cos_alpha;
                my $p0_y = $b * $sin_alpha;
                my $p1_x = $a * ($cos_alpha - $bcp * $sin_alpha);
                my $p1_y = $b * ($sin_alpha + $bcp * $cos_alpha);
                my $p2_x = $a * ($cos_beta + $bcp * $sin_beta);
                my $p2_y = $b * ($sin_beta - $bcp * $cos_beta);
                my $p3_x = $a * $cos_beta;
                my $p3_y = $b * $sin_beta;
                return($p0_x,$p0_y,$p1_x,$p1_y,$p2_x,$p2_y,$p3_x,$p3_y);
	}
}

=item $gfx->arc $x, $y, $a, $b, $alfa, $beta, $move

=cut

sub arc { # x,y,a,b,alf,bet[,mov]
        my ($self,$x,$y,$a,$b,$alpha,$beta,$move)=@_;
        my @points=arctocurve($a,$b,$alpha,$beta);
        my ($p0_x,$p0_y,$p1_x,$p1_y,$p2_x,$p2_y,$p3_x,$p3_y);

        $p0_x= $x + shift @points;
        $p0_y= $y + shift @points;

        $self->move($p0_x,$p0_y) if($move);

	while(scalar @points > 0) {
	        $p1_x= $x + shift @points;
	        $p1_y= $y + shift @points;
	        $p2_x= $x + shift @points;
	        $p2_y= $y + shift @points;
	        $p3_x= $x + shift @points;
	        $p3_y= $y + shift @points;
	        $self->curve($p1_x,$p1_y,$p2_x,$p2_y,$p3_x,$p3_y);
	        shift @points;
	        shift @points;
		$self->{' x'}=$p3_x;
		$self->{' y'}=$p3_y;
	}
	return($self);
}

=item $gfx->ellipse $x, $y, $a, $b

=cut

sub ellipse {
	my ($self,$x,$y,$a,$b) = @_;
	$self->arc($x,$y,$a,$b,0,360,1);
	$self->close;
	return($self);
}

=item $gfx->circle $x, $y, $r

=cut

sub circle {
	my ($self,$x,$y,$r) = @_;
	$self->arc($x,$y,$r,$r,0,360,1);
	$self->close;
	return($self);
}

=item $gfx->bogen $x1, $y1, $x2, $y2, $r, $move, $larc, $span

=cut

sub bogen { # x1,y1,x2,y2,r[,move[,large-arc[,span-factor]]]
	my ($self,$x1,$y1,$x2,$y2,$r,$move,$larc,$spf) = @_;
        my ($p0_x,$p0_y,$p1_x,$p1_y,$p2_x,$p2_y,$p3_x,$p3_y);
	my $x=$x2-$x1;
	$x=$x1-$x2 if($spf>0);
	my $y=$y2-$y1;
	$y=$y1-$y2 if($spf>0);
	my $z=sqrt($x**2+$y**2);
	my $alfa_rad=asin($y/$z);

	if($spf>0) {
		$alfa_rad-=pi/2 if($x<0);
		$alfa_rad=-$alfa_rad if($y>0);
	} else {
		$alfa_rad+=pi/2 if($x<0);
		$alfa_rad=-$alfa_rad if($y<0);
	}

	my $alfa=rad2deg($alfa_rad);
	my $d=2*$r;
	my ($beta,$beta_rad,@points);

	$beta=rad2deg(2*asin($z/$d));
	$beta=360-$beta if($larc>0);

	$beta_rad=deg2rad($beta);

	@points=arctocurve($r,$r,90+$alfa+$beta/2,90+$alfa-$beta/2);

	if($spf>0) {
		my @pts=@points;
		@points=();
		while($y=pop @pts){
			$x=pop @pts;
			push(@points,$x,$y);
		}
	}

	$p0_x=shift @points;
	$p0_y=shift @points;
	$x=$x1-$p0_x;
	$y=$y1-$p0_y;

        $self->move($x,$y) if($move);

	while(scalar @points > 0) {
	        $p1_x= $x + shift @points;
	        $p1_y= $y + shift @points;
	        $p2_x= $x + shift @points;
	        $p2_y= $y + shift @points;
	        $p3_x= $x + shift @points;
	        $p3_y= $y + shift @points;
	        $self->curve($p1_x,$p1_y,$p2_x,$p2_y,$p3_x,$p3_y);
	        shift @points;
	        shift @points;
	}
	return($self);
}

=item $gfx->pie $x, $y, $a, $b, $alfa, $beta

=cut

sub pie {
	my $self=shift @_;
	my ($x,$y,$a,$b,$alfa,$beta)=@_;
        my ($p0_x,$p0_y)=arctocurve($a,$b,$alfa,$beta);
	$self->move($x,$y);
	$self->line($p0_x+$x,$p0_y+$y);
	$self->arc($x,$y,$a,$b,$alfa,$beta);
	$self->close;
}

=item $gfx->pie3d $x, $y, $a, $b, $alfa, $beta, $thickness [, $sides]

=cut

sub pie3d {
	my $self=shift @_;
	my ($x,$y,$a,$b,$alfa,$beta,$th,$sd)=@_;
	
	my ($sa,$sb);
	
	while($alfa<0) {$alfa+=360;$beta+=360;}

	while($alfa>360) {$alfa-=360;$beta-=360;}

	$sa=$alfa;

	$sb=$beta;
	while($sb<0) {$sb+=360;}
	while($sb>360) {$sb-=360;}

	my ($p0x,$p0y)=arctocurve($a,$b,$alfa,$beta);
	my ($p1x,$p1y)=arctocurve($a,$b,$beta,$alfa);
	if($sd) {
		if (($sa<90) || ($sa>270)) {
			$self->move($x,$y);
			$self->line($x,$y-$th);
			$self->line($x+$p0x,$y+$p0y-$th);
			$self->line($x+$p0x,$y+$p0y);
			$self->close;
		} 
		if (($sb>90) && ($sb<270)) {
			$self->move($x,$y);
			$self->line($x,$y-$th);
			$self->line($x+$p1x,$y+$p1y-$th);
			$self->line($x+$p1x,$y+$p1y);
			$self->close;
		} 
	}	

	my($r_s,$r_m,$r_e);

	my $mid=($beta+$alfa)/2;

	if( ($alfa<180) && ($beta>180) && ($beta<360) ) {
		$r_s=180;
		$r_e=$beta;
	} elsif(($alfa>180) && ($beta<360)) {
		$r_s=$alfa;
		$r_e=$beta;
	} elsif( ($alfa<360) && ($alfa>180) && ($beta>360) ) {
		$r_s=$alfa;
		$r_e=360;
	} elsif ( ($alfa<180) && ($beta>360) ) {
		$r_s=180;
		$r_e=360;
	}

	if($r_s||$r_e||$r_m) {
		($p0x,$p0y)=arctocurve($a,$b,$r_s,$r_e);
		($p1x,$p1y)=arctocurve($a,$b,$r_e,$r_s);
		$self->move($x+$p0x,$y+$p0y);
		$self->line($x+$p0x,$y+$p0y-$th);
		$self->arc($x,$y-$th,$a,$b,$r_s,$r_e);
		$self->line($x+$p1x,$y+$p1y);
		$self->close;
		if(($sb>180) && ($sb<360) && (($beta-$alfa)>180) && ($sa>$sb)) {
			($p0x,$p0y)=arctocurve($a,$b,180,$beta);
			($p1x,$p1y)=arctocurve($a,$b,$beta,180);
			$self->move($x+$p1x,$y+$p1y);
			$self->line($x+$p1x,$y+$p1y-$th);
			$self->arc($x,$y-$th,$a,$b,$sb,180);
			$self->line($x+$p0x,$y+$p0y);
			$self->close;
		#	print " sa=$sa sb=$sb a=$alfa b=$beta \n";
		}
	}

	$self->fillstroke;

	$self->pie($x,$y,$a,$b,$alfa,$beta);

	return($self);
}

=item $gfx->rect $x1,$y1, $w1,$h1, ..., $xn,$yn, $wn,$hn

=cut

sub rect { # x,y,w,h ...
	my $self=shift @_;
	my($x,$y,$w,$h);
	while(defined($x=shift @_)) {
		$y=shift @_;
		$w=shift @_;
		$h=shift @_;
		$self->add(floats($x,$y,$w,$h),'re');
	}
	$self->{' x'}=$x;
	$self->{' y'}=$y;
	return($self);
}

=item $gfx->rectxy $x1,$y1, $x2,$y2

=cut

sub rectxy {
	my ($self,$x,$y,$x2,$y2)=@_;
	$self->rect($x,$y,($x2-$x),($y2-$y));
	return($self);
}

=item $gfx->poly $x1,$y1, ..., $xn,$yn

=cut

sub poly {
	my $self=shift @_;
	my($x,$y);
	$x=shift @_;
	$y=shift @_;
	$self->move($x,$y);
	$self->line(@_);
	return($self);
}

=item $gfx->close

=cut

sub close {
	my $self=shift @_;
	$self->add('h');
	$self->{' x'}=$self->{' mx'};
	$self->{' y'}=$self->{' my'};
	return($self);
}

=item $gfx->endpath

=cut

sub endpath {
	my $self=shift @_;
	$self->add('n');
	return($self);
}

=item $gfx->clip $nonzero

=cut

sub clip { # nonzero
	my $self=shift @_;
	$self->add(!(shift @_)?'W':'W*');
	return($self);
}

=item $gfx->stroke

=cut

sub stroke {
	my $self=shift @_;
	$self->add('S');
	return($self);
}

=item $gfx->fill $nonzero

=cut

sub fill { # nonzero
	my $self=shift @_;
	$self->add(!(shift @_)?'f':'f*');
	return($self);
}

=item $gfx->fillstroke $nonzero

=cut

sub fillstroke { # nonzero
	my $self=shift @_;
	$self->add(!(shift @_)?'B':'B*');
	return($self);
}

=item $gfx->image $imgobj, $x,$y, $w,$h

=item $gfx->image $imgobj, $x,$y, $scale

=item $gfx->image $imgobj, $x,$y

B<Please Note:> The width/height or scale given
is in user-space coordinates which is subject to
transformations which may have been specified beforehand.

Per default this has a 72dpi resolution, so if you want an
image to have a 150 or 300dpi resolution, you should specify
a scale of 72/150 (or 72/300) or adjust width/height accordingly.

=cut

sub image {
	my $self=shift @_;
	my $img=shift @_;
	my ($x,$y,$w,$h)=@_;
	$self->save;
	if(!defined $w) {
		$h=$img->height;
		$w=$img->width;
	} elsif(!defined $h) {
		$h=$img->height*$w;
		$w=$img->width*$w;
	}
	$self->matrix($w,0,0,$h,$x,$y);
	$self->add("/$img->{' apiname'}",'Do');
	$self->restore;
	$self->{' x'}=$x;
	$self->{' y'}=$y;
	$self->resource('XObject',$img->{' apiname'},$img);
	return($self);
}

=item $gfx->pdfimage $imgobj, $x, $y, $sx, $sy 

=item $gfx->pdfimage $imgobj, $x, $y, $scale 

=item $gfx->pdfimage $imgobj, $x, $y

B<Please Note:> *TODO*


=cut

sub pdfimage {
	my $self=shift @_;
	my $img=shift @_;
	my $x=shift @_||0;
	my $y=shift @_||0;
	my ($w,$h)=@_;
	my $sx=shift @_||1;
	my $sy=shift @_||$sx;
	$self->save;
	$self->matrix($sx,0,0,$sy,$x,$y);
	$self->add($img->{' pdfimage'});
	$self->restore;
	foreach my $type (keys %{$img->{Resources}}) {
		next if($type=~/^ /);
		foreach my $res (keys %{$img->{Resources}->{$type}}) {
			next if($res=~/^ /);
			$self->resource($type,$res,$img->{Resources}->{$type}->{$res});
		}
	}
	return($self);
}

=item $gfx->barcode $barcodeobj, $center_x, $center_y, $scale [,$frame]

=item $gfx->barcode_inline $barcodeobj, $center_x, $center_y, $scale [,$frame]

=cut

sub barcode {
	my $self=shift @_;
	my $obj=shift @_;
	my ($cx,$cy,$s,$f)=@_;
	$self->save;
	$self->matrix($s,0,0,$s,$cx-($obj->{' w'}*$s/2),$cy-($obj->{' h'}*$s/2));
	if($f>0) {
		$self->fillcolorbyname('white');
		$self->strokecolorbyname('black');
		$self->linewidth($f);
		$self->rect(0,0,$obj->{' w'},$obj->{' h'});
		$self->fillstroke;
	}
	$self->add("/$obj->{' apiname'}",'Do');
	$self->restore;
	$self->resource('XObject',$obj->{' apiname'},$obj);
	return($self);
}

sub barcode_inline {
	my $self=shift @_;
	my $obj=shift @_;
	my ($cx,$cy,$s,$f)=@_;
	$self->save;
	$self->matrix($s,0,0,$s,$cx-($obj->{' w'}*$s/2),$cy-($obj->{' h'}*$s/2));
	if($f>0) {
		$self->fillcolorbyname('white');
		$self->strokecolorbyname('black');
		$self->linewidth($f);
		$self->rect(0,0,$obj->{' w'},$obj->{' h'});
		$self->fillstroke;
	}
	$self->add($obj->{' stream'});
	$self->restore;
	$self->resource('Font',$obj->{' font'}->{' apiname'},$obj->{' font'});
	return($self);
}

=item $gfx->shade $shadeobj, $x1,$y1, $x2,$y2

=cut

sub shade {
	my $self=shift @_;
	my $shade=shift @_;
	my @cord=@_;
	my @tm=(
		$cord[2]-$cord[0] , 0,
		0                 , $cord[3]-$cord[1],
		$cord[0]          , $cord[1]
	);
	$self->save;
	$self->matrix(@tm);
	$self->add("/$shade->{' apiname'}",'sh');

	$self->resource('Shading',$shade->{' apiname'},$shade);

	$self->restore;
	return($self);
}

=item $gfx->egstate $egsobj

=cut

sub egstate {
	my $self=shift @_;
	my $egs=shift @_;
	$self->add("/$egs->{' apiname'}",'gs');
	$self->resource('ExtGState',$egs->{' apiname'},$egs);
	return($self);
}


#==================================================================
#	PDF::API2::Text
#==================================================================
package PDF::API2::Text;

use strict;
use vars qw(@ISA);
@ISA = qw(PDF::API2::Content);

use Text::PDF::Utils;
use PDF::API2::Util;
use Math::Trig;

=head2 PDF::API2::Text

Subclassed from PDF::API2::Content.

=item $txt = PDF::API2::Text->new @parameters

Returns a new text content object (called from $page->text).

=cut

sub new {
	my ($class)=@_;
	my $self = $class->SUPER::new(@_);
	$self->add('BT');
	return($self);
}

=item $txt->matrix $a, $b, $c, $d, $e, $f

Sets the matrix.

=cut

sub matrix {
	my $self=shift @_;
	my ($a,$b,$c,$d,$e,$f)=@_;
	$self->add((floats($a,$b,$c,$d,$e,$f)),'Tm');
	return($self);
}

sub outobjdeep {
	my ($self, $fh, $pdf) = @_;
	$self->add('ET');
	$self->SUPER::outobjdeep($fh, $pdf);
}

=item $txt->font $fontobj,$size

=cut

sub font {
	my ($self,$font,$size)=@_;
	$self->{' font'}=$font;
	$self->{' fontsize'}=$size;
	$self->add("/".$font->{' apiname'},float($size),'Tf');

	$self->resource('Font',$font->{' apiname'},$font);

	return($self);
}

=item $txt->charspace $spacing

=cut

sub charspace {
	my ($self,$para)=@_;
	$self->add(float($para),'Tc');
}

=item $txt->wordspace $spacing

=cut

sub wordspace {
	my ($self,$para)=@_;
	$self->add(float($para),'Tw');
}

=item $txt->hspace $spacing

=cut

sub hspace {
	my ($self,$para)=@_;
	$self->add(float($para),'Tz');
}

=item $txt->lead $leading

=cut

sub lead {
	my ($self,$para)=@_;
	$self->add(float($para),'TL');
}

=item $txt->rise $rise

=cut

sub rise {
	my ($self,$para)=@_;
	$self->add(float($para),'Ts');
}

=item $txt->render $rendering

=cut

sub render {
	my ($self,$para)=@_;
	$self->add(intg($para),'Tr');
}

=item $txt->cr $linesize

=cut

sub cr {
	my ($self,$para)=@_;
	if(defined($para)) {
		$self->add(0,float($para),'Td');
	} else {
		$self->add('T*');
	}
}

=item $txt->nl

=cut

sub nl {
	my ($self)=@_;
	$self->add('T*');
}

=item $txt->distance $dx,$dy

=cut

sub distance {
	my ($self,$dx,$dy)=@_;
	$self->add(float($dx),float($dy),'Td');
}

=item $txt->text $string

=item $width = $txt->text $string

Applys text to the content and optionally returns the width of the given text.

B<Note:> Does not consider transformations, but only the set fontsize !

=cut

sub text {
	my ($self,@txt)=@_;
	my $text=join('',@txt);
	$self->add($self->{' font'}->text($text),'Tj');
	my $wd=$self->{' font'}->width($text)*$self->{' fontsize'};
	return($wd);

}

=item $txt->text_center $string

=cut

sub text_center {
	my ($self,$text)=@_;
	$self->distance(float(-($self->{' font'}->width($text)*$self->{' fontsize'}/2)),0);
	$self->add($self->{' font'}->text($text),'Tj');
	$self->distance(float($self->{' font'}->width($text)*$self->{' fontsize'}/2),0);
}

=item $txt->text_right $string

=cut

sub text_right {
	my ($self,$text)=@_;
	$self->distance(float(-($self->{' font'}->width($text)*$self->{' fontsize'})),0);
	$self->add($self->{' font'}->text($text),'Tj');
	$self->distance(float($self->{' font'}->width($text)*$self->{' fontsize'}),0);
}

=item $txt->text_utf8 $utf8string

=cut

sub text_utf8 {
	my ($self,@txt)=@_;
	my ($text);
	while(scalar @txt > 0) {
		$text=shift @txt;
		$self->add($self->{' font'}->text_utf8($text),'Tj');
	}
}

=item $txt->textln $string1, ..., $stringn

B<Example:>

	$txt->lead(-10);
	$txt->textln($line1,$line2,$line3);

=cut

sub textln {
	my ($self,@txt)=@_;
	my ($text);
	while(scalar @txt > 0) {
		$text=shift @txt;
		$self->add($self->{' font'}->text($text),'Tj','T*');
	}
}

sub paragraph {
	my ($self,$x,$y,$wd,$ht,$idt,@txt)=@_;
	my $text=join(' ',@txt);
	my $h=$ht;
	my $sz=$self->{' fontsize'};
	@txt=split(/\s+/,$text);
	$self->lead($sz);

	my @line=();
	while((defined $txt[0]) && ($ht>0)) {
		$self->translate($x+$idt,$y+$ht-$h);
		@line=();
		while( (defined $txt[0]) && ($self->{' font'}->width(join(' ',@line,$txt[0]))*$sz<($wd-$idt)) ) {
			push(@line, shift @txt);
		}
		@line=(shift @txt) if(scalar @line ==0  && $self->{' font'}->width($txt[0])*$sz>($wd-$idt) );
		my $l=$self->{' font'}->width(join(' ',@line))*$sz;
		$self->wordspace(($wd-$idt-$l)/(scalar @line)) if(defined $txt[0] && scalar @line>0);
		$idt=$l+$self->{' font'}->width(' ')*$sz;
		$self->text(join(' ',@line));
		if(defined $txt[0]) { $ht-=$sz; $idt=0; }
		$self->wordspace(0);
	}
	return($idt,$y+$ht-$h,@txt);
}

sub paragraphformat {
	my ($self,$x,$y,$wd,$ht,$idt,@txt)=@_;
	my $yy=$y-$ht;
	my @t;
	while(scalar @txt>0 && $y>$yy) {
		my $text=shift @txt;
		$self->font($text,$self->{' fontsize'}) if(ref($text)=~/Font/i);
		next if(ref($text)=~/Font/i);
		while(ref($text) ? scalar @{$text}>0 : (defined $text) && ($text ne '')) {
			($idt,$y,@t)=$self->paragraph($x,$y,$wd,$y-$yy,$idt,ref($text) ? @{$text} : $text);
			$text=[@t];
		}
	}
	return($idt,$y,@txt);
}

#==================================================================
#	PDF::API2::Hybrid
#==================================================================
package PDF::API2::Hybrid;

use strict;
use vars qw(@ISA);
@ISA = qw(PDF::API2::Gfx PDF::API2::Text PDF::API2::Content);

use Text::PDF::Utils;
use PDF::API2::Util;

=head2 PDF::API2::Hybrid

Subclassed from PDF::API2::Gfx+Text+Content.

=item $hyb = PDF::API2::Hybrid->new @parameters

Returns a new hybrid content object (called from $page->hybrid).

=cut

sub new {
	my ($class)=@_;
	my $self = PDF::API2::Content::new(@_);
	return($self);
}

=item $hyb->matrix $a, $b, $c, $d, $e, $f

Sets the matrix.

=cut

sub matrix {
	my $self=shift @_;
	my ($a,$b,$c,$d,$e,$f)=@_;
	if($self->{' apiistext'} == 1) {
		$self->add(floats($a,$b,$c,$d,$e,$f),'Tm');
	} else {
		$self->add(floats($a,$b,$c,$d,$e,$f),'cm');
	}
	return($self);
}

sub outobjdeep {
	my ($self) = @_;
	PDF::API2::Content::outobjdeep(@_);
}

sub transform {
	my ($self)=@_;
	if($self->{' apiistext'} == 1) {
		PDF::API2::Text::transform(@_);
	} else {
		PDF::API2::Gfx::transform(@_);
	}
	return($self);
}

=item $hyb->textstart

=cut

sub textstart {
	my ($self)=@_;
	if($self->{' apiistext'} != 1) {
		$self->add('BT');
		$self->{' apiistext'}=1;
	}
	return($self);
}

=item $hyb->textend

=cut

sub textend {
	my ($self)=@_;
	if($self->{' apiistext'} == 1) {
		$self->add('ET');
		$self->{' apiistext'}=0;
	}
	return($self);
}


#==================================================================
#	PDF::API2::PdfImage
#==================================================================
package PDF::API2::PdfImage;

use strict;
use vars qw(@ISA);
@ISA = qw(PDF::API2::Hybrid);

use Text::PDF::Utils;
use PDF::API2::Util;

=head2 PDF::API2::PdfImage

Subclassed from PDF::API2::Hybrid.

=cut

sub resource {
	my ($self, $type, $key, $obj) = @_;
	$self->{Resources}=$self->{Resources}||PDFDict();
	$self->{Resources}->{$type}=$self->{Resources}->{$type}||PDFDict();
	$self->{Resources}->{$type}->{$key}=$obj;
	return($self);
}

=item $wd = $img->width

=cut

sub width {
	my $self = shift @_;
	return($self->{' rx'}-$self->{' lx'});
}

=item $ht = $img->height

=cut

sub height {
	my $self = shift @_;
	return($self->{' ry'}-$self->{' ly'});
}

#==================================================================
#	PDF::API2::Barcode
#==================================================================
package PDF::API2::Barcode;

## use strict;
use vars qw( 
	@ISA
	
	$code3of9 
	@bar3of9
	%bar3of9ext
	%bar_wdt
	
	@bar128 

	$code128a
	$code128b
	$code128c

	$bar128F1
	$bar128F2
	$bar128F3
	$bar128F4
	$bar128Ca
	$bar128Cb
	$bar128Cc
	$bar128sh
	$bar128Sa
	$bar128Sb
	$bar128Sc
	$bar128St
);

@ISA=qw( PDF::API2::Hybrid );

use Text::PDF::Utils;
use PDF::API2::Util;

%bar_wdt=(
	 0 => 0,
	 1 => 1,
	 2 => 2,
	 3 => 3,
	 4 => 4,
	 5 => 5,
	 6 => 6,
	 7 => 7,
	 8 => 8,
	 9 => 9,
	'a' => 1,
	'b' => 2,
	'c' => 3,
	'd' => 4,
	'e' => 5,
	'f' => 6,
	'g' => 7,
	'h' => 8,
	'i' => 9,
	'A' => 1,
	'B' => 2,
	'C' => 3,
	'D' => 4,
	'E' => 5,
	'F' => 6,
	'G' => 7,
	'H' => 8,
	'I' => 9,
);

$code3of9=q|1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%*|;

@bar3of9=qw/
	2112111121	1122111121	2122111111	1112211121
	2112211111	1122211111	1112112121	2112112111
	1122112111	1112212111	2111121121	1121121121
	2121121111	1111221121	2111221111	1121221111
	1111122121	2111122111	1121122111	1111222111
	2111111221	1121111221	2121111211	1111211221
	2111211211	1121211211	1111112221	2111112211
	1121112211	1111212211	2211111121	1221111121
	2221111111	1211211121	2211211111	1221211111
	1211112121	2211112111	1221112111	1212121111
	1212111211	1211121211	1112121211	abaababaa1
/;

%bar3of9ext=(
	"\x00" => '%U',
	"\x01" => '$A',
	"\x02" => '$B',
	"\x03" => '$C',
	"\x04" => '$D',
	"\x05" => '$E',
	"\x06" => '$F',
	"\x07" => '$G',
	"\x08" => '$H',
	"\x09" => '$I',
	"\x0a" => '$J',
	"\x0b" => '$K',
	"\x0c" => '$L',
	"\x0d" => '$M',
	"\x0e" => '$N',
	"\x0f" => '$O',
	"\x10" => '$P',
	"\x11" => '$Q',
	"\x12" => '$R',
	"\x13" => '$S',
	"\x14" => '$T',
	"\x15" => '$U',
	"\x16" => '$V',
	"\x17" => '$W',
	"\x18" => '$X',
	"\x19" => '$Y',
	"\x1a" => '$Z',
	"\x1b" => '%A',
	"\x1c" => '%B',
	"\x1d" => '%C',
	"\x1e" => '%D',
	"\x1f" => '$E',
	"\x20" => ' ',
	"!" => '/A',
	'"' => '/B',
	"#" => '/C',
	'$' => '/D',
	'%' => '/E',
	'&' => '/F',
	"'" => '/G',
	'(' => '/H',
	')' => '/I',
	'*' => '/J',
	'+' => '/K',
	',' => '/L',
	'-' => '-',
	'.' => '.',
	'/' => '/O',
	'0' => '0',
	'1' => '1',
	'2' => '2',
	'3' => '3',
	'4' => '4',
	'5' => '5',
	'6' => '6',
	'7' => '7',
	'8' => '8',
	'9' => '9',
	':' => '/Z',
	';' => '%F',
	'<' => '%G',
	'=' => '%H',
	'>' => '%I',
	'?' => '%J',
	'@' => '%V',
	'A' => 'A',
	'B' => 'B',
	'C' => 'C',
	'D' => 'D',
	'E' => 'E',
	'F' => 'F',
	'G' => 'G',
	'H' => 'H',
	'I' => 'I',
	'J' => 'J',
	'K' => 'K',
	'L' => 'L',
	'M' => 'M',
	'N' => 'N',
	'O' => 'O',
	'P' => 'P',
	'Q' => 'Q',
	'R' => 'R',
	'S' => 'S',
	'T' => 'T',
	'U' => 'U',
	'V' => 'V',
	'W' => 'W',
	'X' => 'X',
	'Y' => 'Y',
	'Z' => 'Z',
	'[' => '%K',
	'\\' => '%L',
	']' => '%M',
	'^' => '%N',
	'_' => '%O',
	'`' => '%W',
	'a' => '+A',
	'b' => '+B',
	'c' => '+C',
	'd' => '+D',
	'e' => '+E',
	'f' => '+F',
	'g' => '+G',
	'h' => '+H',
	'i' => '+I',
	'j' => '+J',
	'k' => '+K',
	'l' => '+L',
	'm' => '+M',
	'n' => '+N',
	'o' => '+O',
	'p' => '+P',
	'q' => '+Q',
	'r' => '+R',
	's' => '+S',
	't' => '+T',
	'u' => '+U',
	'v' => '+V',
	'w' => '+W',
	'x' => '+X',
	'y' => '+Y',
	'z' => '+Z',
	'{' => '%P',
	'|' => '%Q',
	'}' => '%R',
	'~' => '%S',
	"\x7f" => '%T'
);

$code128a=q| !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_|.join('',map{chr($_)}(0..31)).qq/\xf3\xf2\x80\xcc\xcb\xf4\xf1\x8a\x8b\x8c\xff/;
$code128b=q| !"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|.qq/|}~\x7f\xf3\xf2\x80\xcc\xf4\xca\xf1\x8a\x8b\x8c\xff/;
$code128c=("\xfe" x 100).qq/\xcb\xca\xf1\x8a\x8b\x8c\xff/;

@bar128=qw(
    212222 222122 222221 121223 121322
    131222 122213 122312 132212 221213
    221312 231212 112232 122132 122231
    113222 123122 123221 223211 221132
    221231 213212 223112 312131 311222
    321122 321221 312212 322112 322211
    212123 212321 232121 111323 131123
    131321 112313 132113 132311 211313
    231113 231311 112133 112331 132131
    113123 113321 133121 313121 211331
    231131 213113 213311 213131 311123
    311321 331121 312113 312311 332111
    314111 221411 431111 111224 111422
    121124 121421 141122 141221 112214
    112412 122114 122411 142112 142211
    241211 221114 413111 241112 134111
    111242 121142 121241 114212 124112
    124211 411212 421112 421211 212141
    214121 412121 111143 111341 131141
    114113 114311 411113 411311 113141
    114131 311141 411131 b1a4a2 b1a2a4
    b1a2c2 b3c1a1b
);

$bar128F1="\xf1";
$bar128F2="\xf2";
$bar128F3="\xf3";
$bar128F4="\xf4";

$bar128Ca="\xca";
$bar128Cb="\xcb";
$bar128Cc="\xcc";

$bar128sh="\x80";

$bar128Sa="\x8a";
$bar128Sb="\x8b";
$bar128Sc="\x8c";

$bar128St="\xff";

sub encode_128_char_idx {
	my ($code,$char)=@_;
	my ($idx);
	if(lc($code) eq 'a') {
		return if($char eq $bar128Ca);
		$idx=index($code128a,$char);
	} elsif(lc($code) eq 'b') {
		return if($char eq $bar128Cb);
		$idx=index($code128b,$char);
	} elsif(lc($code) eq 'c') {
		return if($char eq $bar128Cc);
		if($char=~/^\d+$/) {
			$idx=substr($char,0,1)*10+substr($char,1,1)*1;
		} else {
			$idx=index($code128c,$char);
		}
	}
	return($bar128[$idx],$idx);
}

sub encode_128_char {
	my ($code,$char)=@_;
	my ($b)=encode_128_char_idx($code,$char);
	return($b);
}

sub encode_128_string {
	my ($code,$str)=@_;
	my ($bar,@chk,$c,$desc,$b,$i,@bars);
	my @chars=split(//,$str);
	while(defined($c=shift @chars)) {
		if($c=~/[\xf1-\xf4]/) {
			($b,$i)=encode_128_char_idx($code,$c);
		} elsif($c=~/[\xca-\xcc]/) {
			($b,$i)=encode_128_char_idx($code,$c);
			if($c eq "\xca") {
				$code='a';
			} elsif($c eq "\xcb") {
				$code='b';
			} elsif($c eq "\xcc") {
				$code='c';
			}
		} else {
			if($code ne 'c') {
				if($c eq $bar128sh) {
					($b,$i)=encode_128_char_idx($code,$c);
					push(@bars,$b);
					push(@chk,$i);
					$c=shift(@chars);
					($b,$i)=encode_128_char_idx($code eq 'a' ? 'b':'a',$c);
				} else {
					($b,$i)=encode_128_char_idx($code,$c);
				}
			} else {
				$c.=shift(@chars) if($c=~/\d/);
				if($c=~/^\d[^\d]*$/) {
					($b,$i)=encode_128_char_idx($code,"\xcb");
					push(@bars,$b);
					push(@chk,$i);
					$code='b';
					unshift(@chars,substr($c,1,1));
					$c=substr($c,0,1);
				} 
				($b,$i)=encode_128_char_idx($code,$c);
			}
		}
		$c='' if($c=~/[^\x20-\x7e]/);
		push(@bars,[$b,$c]);
		push(@chk,$i);
	}
	return([@bars],@chk);
}

sub encode_128 {
	my ($code,$str)=@_;
	my (@bar,$b,@chk,$c);
	if($code eq 'a') {
		push(@bar,encode_128_char($code,$bar128Sa));
		$c=103;
	} elsif($code eq 'b') {
		push(@bar,encode_128_char($code,$bar128Sb));
		$c=104;
	} elsif($code eq 'c') {
		push(@bar,encode_128_char($code,$bar128Sc));
		$c=105;
	}
	($b,@chk)=encode_128_string($code,$str);
	# b ... bars
	# chk ... chknums
	push(@bar,@{$b});
	#calc chksum
	foreach my $i (1..scalar @chk) {
		$c+=$i*$chk[$i-1];
	}
	$c%=103;
	push(@bar,$bar128[$c]);
	push(@bar,encode_128_char($code,$bar128St));
	return(@bar);
}

sub encode_ean128 {
	my ($str)=@_;
	$str=~s/[^a-zA-Z\d]+//g;
	$str=~s/(\d+)([a-zA-Z]+)/$1\xcb$2/g;
	$str=~s/([a-zA-Z]+)(\d+)/$1\xcc$2/g;
	return(encode_128('c',"\xf1$str"));
}

sub encode_3of9_char {
	my $char=shift @_;
	return($bar3of9[index($code3of9,$char)]);
}

sub encode_3of9_string {
	my $string=shift @_;
	my $bar;
	my @c=split(//,$string);

	foreach my $char (@c) {
		$bar.=encode_3of9_char($char);
	}
	return($bar);
}

sub encode_3of9_string_w_chk {
	my $string=shift @_;
	my ($bar,$num);
	my @c=split(//,$string);

	foreach my $char (@c) {
		$num+=index($code3of9,$char);
		$bar.=encode_3of9_char($char);
	}
	$num%=43;
	$bar.=$bar3of9[$num];
	return($bar);
}

sub encode_3of9 {
	my $string=shift @_;
	my @bar;

	$string=uc($string);
	$string=~s/[^0-9A-Z\-\.\ \$\/\+\%]+//g;

	push(@bar, encode_3of9_char('*') );
	push(@bar, [ encode_3of9_string($string), $string ] );
	push(@bar, $bar[0] );

	return(@bar);
}

sub encode_3of9_w_chk {
	my $string=shift @_;
	my @bar;

	$string=uc($string);
	$string=~s/[^0-9A-Z\-\.\ \$\/\+\%]+//g;

	push(@bar, encode_3of9_char('*') );
	push(@bar, [ encode_3of9_string_w_chk($string), $string ] );
	push(@bar, $bar[0] );

	return(@bar);
}

sub encode_3of9_ext {
	my $string=shift @_;
	my @c=split(//,$string);
	my ($enc,@bar);
	map { $enc.=$bar3of9ext{$_}; } (@c);

	push(@bar, encode_3of9_char('*') );
	push(@bar, [ encode_3of9_string($enc), $string ] );
	push(@bar, $bar[0] );

	return(@bar);
}

sub encode_3of9_ext_w_chk {
	my $string=shift @_;
	my @c=split(//,$string);
	my ($enc,@bar);
	map { $enc.=$bar3of9ext{$_}; } (@c);

	push(@bar, encode_3of9_char('*') );
	push(@bar, [ encode_3of9_string_w_chk($enc), $string ] );
	push(@bar, $bar[0] );

	return(@bar);
}

=head2 PDF::API2::Barcode

Subclassed from PDF::API2::Hybrid.

=item $bc = PDF::API2::Barcode->new $pdfkey, %options

Returns a new barcode object (called from $pdf->barcode).

B<Example:>

	PDF::API2::Barcode->new(
		$key,
		-font	=> $fontobj,	# the font to use for text
		-type	=> '3of9',	# the type of barcode
		-code	=> '0123456789', # the code of the barcode
		-extn	=> '012345',	# the extension of the barcode
					# (if applicable)
		-umzn	=> 10,		# (u)pper (m)ending (z)o(n)e
		-lmzn	=> 10,		# (l)ower (m)ending (z)o(n)e
		-zone	=> 50,		# height (zone) of bars 	
		-quzn	=> 10,		# (qu)iet (z)o(n)e
		-ofwt	=> 0.01,	# (o)ver(f)low (w)id(t)h
		-fnsz	=> 10,		# (f)o(n)t(s)i(z)e
		-text	=> 'alternative text'
	);

B<Note:> There is currently only support for the following barcodes:

	3of9, 3of9ext, 3of9chk, 3of9extchk,
	code128a, code128b, code128c, ean128

=cut

sub new {
	my $class=shift @_;
	my $key=shift @_;
	my %opts=@_;
	my $self = $class->SUPER::new;
	$self->{' stream'}='';
	my (@bar,@ext);
	
	$opts{-type}=lc($opts{-type});
	$self->{' font'}=$opts{-font};
	
	$self->{' umzn'}=$opts{-umzn};		# (u)pper (m)ending (z)o(n)e
	$self->{' lmzn'}=$opts{-lmzn};		# (l)ower (m)ending (z)o(n)e
	$self->{' zone'}=$opts{-zone};
	$self->{' quzn'}=$opts{-quzn};		# (qu)iet (z)o(n)e
	$self->{' ofwt'}=$opts{-ofwt};		# (o)ver(f)low (w)id(t)h
	$self->{' fnsz'}=$opts{-fnsz};		# (f)o(n)t(s)i(z)e
	$self->{' spcr'}=$opts{-spcr}||'';

        $self->{'Type'}=PDFName('XObject');
        $self->{'Subtype'}=PDFName('Form');
        $self->{'Name'}=PDFName($key);
        $self->{'Formtype'}=PDFNum(1);
        $self->{'BBox'}=PDFArray(PDFNum(0),PDFNum(0),PDFNum(1000),PDFNum(1000));
	
	if( $opts{-type}=~/^3of9/ ) {
		if( $opts{-type} eq '3of9' ) {
			@bar = encode_3of9($opts{-code});
		} elsif ( $opts{-type} eq '3of9ext' ) {
			@bar = encode_3of9_ext($opts{-code});
		} elsif ( $opts{-type} eq '3of9chk' ) {
			@bar = encode_3of9_w_chk($opts{-code});
		} elsif ( $opts{-type} eq '3of9extchk' ) {
			@bar = encode_3of9_ext_w_chk($opts{-code});
		}
	} elsif( $opts{-type}=~/^code128/ ) {
		if( $opts{-type} eq 'code128a' ) {
			@bar = encode_128('a',$opts{-code});
		} elsif ( $opts{-type} eq 'code128b' ) {
			@bar = encode_128('b',$opts{-code});
		} elsif ( $opts{-type} eq 'code128c' ) {
			@bar = encode_128('c',$opts{-code});
		}
	} elsif( $opts{-type}=~/^ean128/ ) {
		@bar = encode_ean128($opts{-code});
	}

	if(scalar @ext < 1) {
		$self->drawbar([@bar],$opts{-text});
	} else {
		$self->drawbar([@bar],$opts{-text},[@ext]);
	}
	
	return($self);
}

sub drawbar {
	my $self=shift @_;
	my @bar=@{shift @_};
	my $bartext=shift @_;
	my $ext=shift @_;

	my $x=$self->{' quzn'};
	my ($code,$str,$bw,$f,$t,$l,$h,$xo);
	$self->fillcolorbyname('black');
	$self->strokecolorbyname('black');
	
	foreach my $b (@bar) {
		if(ref($b)) {
			($code,$str)=@{$b};
		} else {
			$code=$b;
			$str=undef;
		}
		$bw=1;
		$xo=0;
		foreach my $c (split(//,$code)) {
			my $w=$bar_wdt{$c};
			$xo+=$w/2;
			if($c=~/[0-9]/) {
				$l=$self->{' quzn'} + $self->{' lmzn'};
				$h=$self->{' quzn'} + $self->{' lmzn'} + $self->{' zone'} + $self->{' umzn'};
				$t=$self->{' quzn'};
				$f=$self->{' fnsz'}||$self->{' lmzn'};
			} elsif($c=~/[a-z]/) {
				$l=$self->{' quzn'};
				$h=$self->{' quzn'} + $self->{' lmzn'} + $self->{' zone'} + $self->{' umzn'};
				$t=$self->{' quzn'} + $self->{' lmzn'} + $self->{' zone'} + $self->{' umzn'};
				$f=$self->{' fnsz'}||$self->{' umzn'};
			} elsif($c=~/[A-Z]/) {
				$l=$self->{' quzn'};
				$h=$self->{' quzn'} + $self->{' lmzn'} + $self->{' zone'};
				$f=$self->{' fnsz'}||$self->{' umzn'};
				$t=$self->{' quzn'} + $self->{' lmzn'} + $self->{' zone'} + $self->{' umzn'} - $f;
			} else {
				$l=$self->{' quzn'} + $self->{' lmzn'};
				$h=$self->{' quzn'} + $self->{' lmzn'} + $self->{' zone'} + $self->{' umzn'};
				$t=$self->{' quzn'};
				$f=$self->{' fnsz'}||$self->{' lmzn'};
			}
			if($bw) {
				$self->linewidth($w-$self->{' ofwt'});
				$self->move($x+$xo,$l);
				$self->line($x+$xo,$h);
				$self->stroke;
				$bw=0;
			} else {
				$bw=1;
			}
			$xo+=$w/2;
		}
		if(defined($str) && ($self->{' lmzn'}>0)) {
			$str=join($self->{' spcr'},split(//,$str));
			$self->textstart;
			$self->translate($x+($xo/2),$t);
			$self->font($self->{' font'},$f);
			$self->text_center($str);
			$self->textend;
		}
		$x+=$xo;
	}	
	if(defined $bartext) {
		$f=$self->{' fnsz'}||$self->{' lmzn'};
		$t=$self->{' quzn'}-$f;
		$self->textstart;
		$self->translate(($self->{' quzn'}+$x)/2,$t);
		$self->font($self->{' font'},$f);
		$self->text_center($bartext);
		$self->textend;
	}	
	$self->{' w'}=$self->{' quzn'}+$x;
	$self->{' h'}=2*$self->{' quzn'} + $self->{' lmzn'} + $self->{' zone'} + $self->{' umzn'};
}

=item $wd = $bc->width

=cut

sub width {
	my $self = shift @_;
	return($self->{' w'});
}

=item $ht = $bc->height

=cut

sub height {
	my $self = shift @_;
	return($self->{' h'});
}

sub font {
	my ($self,$font,$size)=@_;
	$self->{' font'}=$font;
	$self->{' fontsize'}=$size;
	$self->add("/".$font->{' apiname'},float($size),'Tf');

##	$self->resource('Font',$font->{' apiname'},$font);

	return($self);
}

sub outobjdeep {
	my ($self, $fh, $pdf) = @_;
	use Text::PDF::Dict;
	Text::PDF::Dict::outobjdeep($self,$fh, $pdf);
}

#==================================================================
#	PDF::API2::Image
#==================================================================
package PDF::API2::Image;
use strict;
use PDF::API2::Util;
use Text::PDF::Utils;

=head2 PDF::API2::Image

=item $img = PDF::API2::Image->new $pdf, $imgfile

Returns a new image object (called from $pdf->image).

=cut

sub new {
	my ($class,$pdf,$file,$tt)=@_;
	my ($obj,$buf);
	open(INF,$file);
	binmode(INF);
	read(INF,$buf,10,0);
	close(INF);
	if ($buf=~/^\xFF\xD8/) {
		$obj=PDF::API2::JPEG->new($file,$tt);
	} elsif ($buf=~/^\x89PNG/) {
		$obj=PDF::API2::PNG->new($file,$tt);
	} elsif ($buf=~/^P[456][\s\n]/) {
		$obj=PDF::API2::PPM->new($file,$tt);
	} else {
		die sprintf("image '$file' has unknown format with signature '%02x%02x%02x%02x%02x%02x'",
			ord(substr($buf,0,1)),
			ord(substr($buf,1,1)),
			ord(substr($buf,2,1)),
			ord(substr($buf,3,1)),
			ord(substr($buf,4,1)),
			ord(substr($buf,5,1))
		);
	}
	$pdf->new_obj($obj);
	$obj->{' apipdf'}.=$pdf;
	return($obj);
}

=item $wd = $img->width

=cut

sub width {
	my $self = shift @_;
	return($self->{' width'});
}

=item $ht = $img->height

=cut

sub height {
	my $self = shift @_;
	return($self->{' height'});
}


#==================================================================
#	PDF::API2::PPM
#==================================================================
package PDF::API2::PPM;
use strict;
use PDF::API2::Util;
use Text::PDF::Utils;

use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict PDF::API2::Image);

sub new {
	my ($class,$file,$tt)=@_;
	my $self = $class->SUPER::new();
	$self->{' apiname'}='IMGxPPMx'.pdfkey($file).$tt;

	my ($w,$h,$bpc,$cs,$img)=parsePNM($file);

	$self->{'Type'}=PDFName('XObject');
	$self->{'Subtype'}=PDFName('Image');
	$self->{'Name'}=PDFName($self->{' apiname'});
	$self->{'Width'}=PDFNum(intg($w));
	$self->{'Height'}=PDFNum(intg($h));
	$self->{'Filter'}=PDFArray(PDFName('FlateDecode'));
	$self->{'BitsPerComponent'}=PDFNum(intg($bpc));
	$self->{'ColorSpace'}=PDFName($cs);
	$self->{' stream'}=$img;
	$self->{' height'}=$h;
	$self->{' width'}=$w;

	return($self);
}

sub parsePNM {
	my $file=shift @_;
	my $buf=shift @_;
	my ($t,$s,$line);
	my ($w,$h,$bpc,$cs,$img,@img)=(0,0,'','','');
	open(INF,$file);
	binmode(INF);
	$buf=<INF>;
	$buf.=<INF>;
	($t)=($buf=~/^(P\d+)\s+/);
	if($t eq 'P4') {
		($t,$w,$h)=($buf=~/^(P\d+)\s+(\d+)\s+(\d+)\s+/);
		$bpc=1;
		$s=0;
		for($line=($w*$h/8);$line>0;$line--) {
			read(INF,$buf,1);
			push(@img,$buf);
		}
		$cs='DeviceGray';
	} elsif($t eq 'P5') {
		$buf.=<INF>;
		($t,$w,$h,$bpc)=($buf=~/^(P\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+/);
		if($bpc==255){
			$s=0;
		} else {
			$s=255/$bpc;
		}
		$bpc=8;
		for($line=($w*$h);$line>0;$line--) {
			read(INF,$buf,1);
			if($s>0) {
				$buf=pack('C',(unpack('C',$buf)*$s));
			}
			push(@img,$buf);
		}
		$cs='DeviceGray';
	} elsif($t eq 'P6') {
		$buf.=<INF>;
		($t,$w,$h,$bpc)=($buf=~/^(P\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+/);
		if($bpc==255){
			$s=0;
		} else {
			$s=255/$bpc;
		}
		$bpc=8;
		if($s>0) {
			for($line=($w*$h);$line>0;$line--) {
				read(INF,$buf,1);
				push(@img,pack('C',(unpack('C',$buf)*$s)));
				read(INF,$buf,1);
				push(@img,pack('C',(unpack('C',$buf)*$s)));
				read(INF,$buf,1);
				push(@img,pack('C',(unpack('C',$buf)*$s)));
			}
		} else {
			@img=<INF>;
		}
		$cs='DeviceRGB';
	}
	close(INF);
	return ($w,$h,$bpc,$cs,join('',@img));
}


#==================================================================
#	PDF::API2::JPEG
#==================================================================
package PDF::API2::JPEG;
use strict;
use PDF::API2::Util;
use Text::PDF::Utils;

use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict PDF::API2::Image);

sub new {
	my ($class,$file,$tt)=@_;
	my $self = $class->SUPER::new();
	$self->{' apiname'}='IMGxJPEGx'.pdfkey($file).$tt;

	my ($buf, $p, $h, $w, $c);

	open(JF,$file);
	binmode(JF);
	read(JF,$buf,2);
	while (1) {
		read(JF,$buf,4);
		my($ff, $mark, $len) = unpack("CCn", $buf);
		last if( $ff != 0xFF);
		last if( $mark == 0xDA || $mark == 0xD9);  # SOS/EOI
		last if( $len < 2);
		last if( eof(JF));
		read(JF,$buf,$len-2);
		next if ($mark == 0xFE);
		next if ($mark >= 0xE0 && $mark <= 0xEF);
		if (($mark >= 0xC0) && ($mark <= 0xCF)) {
			($p, $h, $w, $c) = unpack("CnnC", substr($buf, 0, 6));
			last;
		}
	}
	close(JF);

	$self->{'Type'}=PDFName('XObject');
	$self->{'Subtype'}=PDFName('Image');
	$self->{'Name'}=PDFName($self->{' apiname'});
	$self->{'Width'}=PDFNum(intg($w));
	$self->{'Height'}=PDFNum(intg($h));
	$self->{'Filter'}=PDFArray(PDFName('DCTDecode'));
	$self->{' nofilt'}=1;
	$self->{'BitsPerComponent'}=PDFNum($p);
	if($c==3) {
	        $self->{'ColorSpace'}=PDFName('DeviceRGB');
	} elsif($c==4) {
	        $self->{'ColorSpace'}=PDFName('DeviceCMYK');
	} elsif($c==1) {
	        $self->{'ColorSpace'}=PDFName('DeviceGray');
	}

	$self->{' streamfile'}=$file;
	$self->{'Length'}=PDFNum(intg(-s $file));

	$self->{' height'}=$h;
	$self->{' width'}=$w;

	return($self);
}


#==================================================================
#	PDF::API2::PNG
#==================================================================
package PDF::API2::PNG;
use strict;
use PDF::API2::Util;
use Text::PDF::Utils;

use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict PDF::API2::Image);

sub new {
	my ($class,$file,$tt)=@_;
	my $self = $class->SUPER::new();
	$self->{' apiname'}='IMGxPNGx'.pdfkey($file).$tt;

	my ($w,$h,$bpc,$cs,$img)=parsePNG($file);

	$self->{'Type'}=PDFName('XObject');
	$self->{'Subtype'}=PDFName('Image');
	$self->{'Name'}=PDFName($self->{' apiname'});
	$self->{'Width'}=PDFNum(intg($w));
	$self->{'Height'}=PDFNum(intg($h));
	$self->{'Filter'}=PDFArray(PDFName('FlateDecode'));
	$self->{'BitsPerComponent'}=PDFNum(intg($bpc));
	$self->{'ColorSpace'}=PDFName($cs);
	$self->{' stream'}=$img;
	$self->{' height'}=$h;
	$self->{' width'}=$w;

	return($self);
}

sub parsePNG {
	my $file=shift @_;
	my $buf=shift @_;
	my ($l,$crc,$w,$h,$bpc,$cs,$cm,$fm,$im,@pal,$img,@img,$filter);
	open(INF,$file);
	binmode(INF);
	seek(INF,8,0);
	while(!eof(INF)) {
		read(INF,$buf,4);
		$l=unpack('N',$buf);
		read(INF,$buf,4);
		if($buf eq 'IHDR') {
			read(INF,$buf,$l);
			($w,$h,$bpc,$cs,$cm,$fm,$im)=unpack('NNCCCCC',$buf);
			if($im>0) {die "PNG InterlaceMethod=$im not supported";}
		} elsif($buf eq 'PLTE') {
			while($l) {
				read(INF,$buf,3);
				push(@pal,$buf);
				$l-=3;
			}
		} elsif($buf eq 'IDAT') {
			while($l>512) {
				read(INF,$buf,512);
				push(@img,$buf);
				$l-=512;
			}
			read(INF,$buf,$l);
			push(@img,$buf);
		} elsif($buf eq '') {
		} elsif($buf eq 'IEND') {
			last;
		} else {
			# skip ahead
			seek(INF,$l,1);
		}
		read(INF,$buf,4);
		$crc=$buf;
	}
	close(INF);
	$img=join('',@img);
	use Compress::Zlib;
	$img=uncompress($img);
	@img=split(//,$img);
	$img='';
	my $bpcm=($bpc>8) ? 8 : $bpc/8;
	foreach my $y (1..$h) {
		$filter=unpack('C',shift(@img));
		if($filter>0){
			##die "PNG FilterType=$filter unsupported";
		}
		foreach my $x (1..POSIX::ceil($w*$bpcm)) {
			if($cs==0) { # grayscale
				if($bpc==1) {
					$buf=shift(@img);
					$buf=unpack('C',$buf);
					foreach my $bit (7,6,5,4,3,2,1,0) {
						$img.=pack('C',(($buf >> $bit) & 1)*255);
					}
				} elsif($bpc==2) {
					$buf=shift(@img);
					$buf=unpack('C',$buf);
					foreach my $bit (6,4,2,0) {
						$img.=pack('C',((($buf >> $bit) & 3)+1)*64-1);
					}
				} elsif($bpc==4) {
					$buf=shift(@img);
					$buf=unpack('C',$buf);
					foreach my $bit (4,0) {
						$img.=pack('C',((($buf >> $bit) & 15)+1)*16-1);
					}
				} elsif($bpc==8) {
					$img.=shift(@img);
				} elsif($bpc==16) {
					$buf=shift(@img).shift(@img);
					$buf=unpack('n',$buf);
					$buf=(($buf+1)/256)-1;
					$img.=pack('C',$buf);
				}
			} elsif($cs==2) { # RGB
				if($bpc==8) {
					$img.=shift(@img).shift(@img).shift(@img);
				} elsif($bpc==16) {
					foreach(1..3) {
						$buf=shift(@img).shift(@img);
						$buf=unpack('n',$buf);
						$buf=(($buf+1)/256)-1;
						$img.=pack('C',$buf);
					}
				}
			} elsif($cs==3) { # indexed
				if($bpc==1) {
					$buf=shift(@img);
					$buf=unpack('C',$buf);
					foreach my $bit (7,6,5,4,3,2,1,0) {
						$img.=$pal[(($buf >> $bit) & 1)];
					}
				} elsif($bpc==2) {
					$buf=shift(@img);
					$buf=unpack('C',$buf);
					foreach my $bit (6,4,2,0) {
						$img.=$pal[(($buf >> $bit) & 3)];
					}
				} elsif($bpc==4) {
					$buf=shift(@img);
					$buf=unpack('C',$buf);
					foreach my $bit (4,0) {
						$img.=$pal[(($buf >> $bit) & 15)];
					}
				} elsif($bpc==8) {
					$img.=$pal[unpack('C',shift(@img))];
				}
			} elsif($cs==4) { # gray + alpha
				if($bpc==8) {
					$img.=shift(@img);
					shift(@img);
				} elsif($bpc==16) {
					$buf=shift(@img).shift(@img);
					$buf=unpack('n',$buf);
					$buf=(($buf+1)/256)-1;
					$img.=pack('C',$buf);
					shift(@img);
					shift(@img);
				}
			} elsif($cs==6) { # RGB + alpha
				if($bpc==8) {
					$img.=shift(@img).shift(@img).shift(@img);
					shift(@img);
				} elsif($bpc==16) {
					foreach(1..3) {
						$buf=shift(@img).shift(@img);
						$buf=unpack('n',$buf);
						$buf=(($buf+1)/256)-1;
						$img.=pack('C',$buf);
					}
					shift(@img);
					shift(@img);
				}
			}
		}
	}
	if( ($cs==0) || ($cs==4) ) { 
		$cs='DeviceGray';
	} elsif ( ($cs==2) || ($cs==3) || ($cs==6) ) {
		$cs='DeviceRGB';
	} else {
		$cs='';
	}
	$bpc=8; # all images have been converted to 8bit values !!
	return ($w,$h,$bpc,$cs,$img);
}


#==================================================================
#
# Copyright 1998-2000 Gisle Aas.
#
# This library is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# modified by Alfred Reibenschuh <areibens@cpan.org> for PDF::API2
#
#==================================================================
package PDF::API2::IOString;

require 5.005_03;
use strict;
use vars qw($VERSION $DEBUG $IO_CONSTANTS);
$VERSION = "1.02";

use Symbol ();

sub new
{
    my $class = shift;
    my $self = bless Symbol::gensym(), ref($class) || $class;
    tie *$self, $self;
    $self->open(@_);
    $self;
}

sub import {
	my $self = shift;
	my $file = shift;
	my $buf = "";
	*$self->{buf} = \$buf;
	*$self->{pos} = 0;
	*$self->{lno} = 0;
	
	my $in;
	open(INF,$file);
	binmode(INF);
	while(!eof(INF)) {
		read(INF,$in,512);
		$self->print($in);	
	}
	close(INF);
	$self->seek(0,0);
	
	$self;
}

sub open
{
    my $self = shift;
    return $self->new(@_) unless ref($self);

    if (@_) {
	my $bufref = ref($_[0]) ? $_[0] : \$_[0];
	$$bufref = "" unless defined $$bufref;
	*$self->{buf} = $bufref;
    } else {
	my $buf = "";
	*$self->{buf} = \$buf;
    }
    *$self->{pos} = 0;
    *$self->{lno} = 0;
    $self;
}

sub pad
{
    my $self = shift;
    my $old = *$self->{pad};
    *$self->{pad} = substr($_[0], 0, 1) if @_;
    return "\0" unless defined($old) && length($old);
    $old;
}

sub dump
{
    require Data::Dumper;
    my $self = shift;
    print Data::Dumper->Dump([$self], ['*self']);
    print Data::Dumper->Dump([*$self{HASH}], ['$self{HASH}']);
}

sub TIEHANDLE
{
    print "TIEHANDLE @_\n" if $DEBUG;
    return $_[0] if ref($_[0]);
    my $class = shift;
    my $self = bless Symbol::gensym(), $class;
    $self->open(@_);
    $self;
}

sub DESTROY
{
    print "DESTROY @_\n" if $DEBUG;
}

sub close {
    my $self = shift;
    $self;
}

sub realclose
{
    my $self = shift;
    delete *$self->{buf};
    delete *$self->{pos};
    delete *$self->{lno};
    $self;
}

sub opened
{
    my $self = shift;
    defined *$self->{buf};
}

sub getc
{
    my $self = shift;
    my $buf;
    return $buf if $self->read($buf, 1);
    return undef;
}

sub ungetc
{
    my $self = shift;
    $self->setpos($self->getpos() - 1)
}

sub eof
{
    my $self = shift;
    length(${*$self->{buf}}) <= *$self->{pos};
}

sub print
{
    my $self = shift;
    if (defined $\) {
	if (defined $,) {
	    $self->write(join($,, @_).$\);
	} else {
	    $self->write(join("",@_).$\);
	}
    } else {
	if (defined $,) {
	    $self->write(join($,, @_));
	} else {
	    $self->write(join("",@_));
	}
    }
}
*printflush = \*print;

sub printf
{
    my $self = shift;
    print "PRINTF(@_)\n" if $DEBUG;
    my $fmt = shift;
    $self->write(sprintf($fmt, @_));
}


my($SEEK_SET, $SEEK_CUR, $SEEK_END);

sub _init_seek_constants
{
    if ($IO_CONSTANTS) {
	require IO::Handle;
	$SEEK_SET = &IO::Handle::SEEK_SET;
	$SEEK_CUR = &IO::Handle::SEEK_CUR;
	$SEEK_END = &IO::Handle::SEEK_END;
    } else {
	$SEEK_SET = 0;
	$SEEK_CUR = 1;
	$SEEK_END = 2;
    }
}


sub seek
{
    my($self,$off,$whence) = @_;
    my $buf = *$self->{buf} || return;
    my $len = length($$buf);
    my $pos = *$self->{pos};

    _init_seek_constants() unless defined $SEEK_SET;

    if    ($whence == $SEEK_SET) { $pos = $off }
    elsif ($whence == $SEEK_CUR) { $pos += $off }
    elsif ($whence == $SEEK_END) { $pos = $len + $off }
    else { die "Bad whence ($whence)" }
    print "SEEK(POS=$pos,OFF=$off,LEN=$len)\n" if $DEBUG;

    $pos = 0 if $pos < 0;
    $self->truncate($pos) if $pos > $len;  # extend file
    *$self->{lno} = 0;
    *$self->{pos} = $pos;
}

sub pos
{
    my $self = shift;
    my $old = *$self->{pos};
    if (@_) {
	my $pos = shift || 0;
	my $buf = *$self->{buf};
	my $len = $buf ? length($$buf) : 0;
	$pos = $len if $pos > $len;
	*$self->{lno} = 0;
	*$self->{pos} = $pos;
    }
    $old;
}

sub getpos { shift->pos; }

*sysseek = \&seek;
*setpos  = \&pos;
*tell    = \&getpos;



sub getline
{
    my $self = shift;
    my $buf  = *$self->{buf} || return;
    my $len  = length($$buf);
    my $pos  = *$self->{pos};
    return if $pos >= $len;

    unless (defined $/) {  # slurp
	*$self->{pos} = $len;
	return substr($$buf, $pos);
    }

    unless (length $/) {  # paragraph mode
	# XXX slow&lazy implementation using getc()
	my $para = "";
	my $eol = 0;
	my $c;
	while (defined($c = $self->getc)) {
	    if ($c eq "\n") {
		$eol++;
	    } elsif ($eol > 1) {
		$self->ungetc($c);
		last;
	    }
	    $para .= $c;
	}
	return $para;   # XXX wantarray
    }

    my $idx = index($$buf,$/,$pos);
    if ($idx < 0) {
	# return rest of it
	*$self->{pos} = $len;
	$. = ++ *$self->{lno};
	return substr($$buf, $pos);
    }
    $len = $idx - $pos + length($/);
    *$self->{pos} += $len;
    $. = ++ *$self->{lno};
    return substr($$buf, $pos, $len);
}

sub getlines
{
    die "getlines() called in scalar context\n" unless wantarray;
    my $self = shift;
    my($line, @lines);
    push(@lines, $line) while defined($line = $self->getline);
    return @lines;
}

sub READLINE
{
    goto &getlines if wantarray;
    goto &getline;
}

sub input_line_number
{
    my $self = shift;
    my $old = *$self->{lno};
    *$self->{lno} = shift if @_;
    $old;
}

sub truncate
{
    my $self = shift;
    my $len = shift || 0;
    my $buf = *$self->{buf};
    if (length($$buf) >= $len) {
	substr($$buf, $len) = '';
	*$self->{pos} = $len if $len < *$self->{pos};
    } else {
	$$buf .= ($self->pad x ($len - length($$buf)));
    }
    $self;
}

sub read
{
    my $self = shift;
    my $buf = *$self->{buf};
    return unless $buf;

    my $pos = *$self->{pos};
    my $rem = length($$buf) - $pos;
    my $len = $_[1];
    $len = $rem if $len > $rem;
    if (@_ > 2) { # read offset
	substr($_[0],$_[2]) = substr($$buf, $pos, $len);
    } else {
	$_[0] = substr($$buf, $pos, $len);
    }
    *$self->{pos} += $len;
    return $len;
}

sub write
{
    my $self = shift;
    my $buf = *$self->{buf};
    return unless $buf;

    my $pos = *$self->{pos};
    my $slen = length($_[0]);
    my $len = $slen;
    my $off = 0;
    if (@_ > 1) {
	$len = $_[1] if $_[1] < $len;
	if (@_ > 2) {
	    $off = $_[2] || 0;
	    die "Offset outside string" if $off > $slen;
	    if ($off < 0) {
		$off += $slen;
		die "Offset outside string" if $off < 0;
	    }
	    my $rem = $slen - $off;
	    $len = $rem if $rem < $len;
	}
    }
    substr($$buf, $pos, $len) = substr($_[0], $off, $len);
    *$self->{pos} += $len;
    $len;
}

*sysread = \&read;
*syswrite = \&write;

sub stat
{
    my $self = shift;
    return unless $self->opened;
    return 1 unless wantarray;
    my $len = length ${*$self->{buf}};

    return (
     undef, undef,  # dev, ino
     0666,          # filemode
     1,             # links
     $>,            # user id
     $),            # group id
     undef,         # device id
     $len,          # size
     undef,         # atime
     undef,         # mtime
     undef,         # ctime
     512,           # blksize
     int(($len+511)/512)  # blocks
    );
}

sub blocking {
    my $self = shift;
    my $old = *$self->{blocking} || 0;
    *$self->{blocking} = shift if @_;
    $old;
}

my $notmuch = sub { return };

*fileno    = $notmuch;
*FILENO    = $notmuch; # for activeperl ?
*error     = $notmuch;
*clearerr  = $notmuch;
*sync      = $notmuch;
*flush     = $notmuch;
*setbuf    = $notmuch;
*setvbuf   = $notmuch;

*untaint   = $notmuch;
*autoflush = $notmuch;
*fcntl     = $notmuch;
*ioctl     = $notmuch;

*GETC   = \&getc;
*PRINT  = \&print;
*PRINTF = \&printf;
*READ   = \&read;
*WRITE  = \&write;
*CLOSE  = \&close;
*SEEK   = \&seek;

sub string_ref
{
    my $self = shift;
    *$self->{buf};
}
*sref = \&string_ref;


# Matrix.pm -- 
# Author          : Ulrich Pfeifer
# Created On      : Tue Oct 24 18:34:08 1995
# Last Modified By: Ulrich Pfeifer
# Last Modified On: Wed Jul 10 20:12:18 1996
# Language        : Perl
# Update Count    : 143
# Status          : Unknown, Use with caution!
# 
# (C) Copyright 1995, Universität Dortmund, all rights reserved.
# 
# $Locker:  $
# $Log: API2.pm,v $
# Revision 1.1  2001/11/22 20:51:56  Administrator
# genesis
#
# Revision 0.2  1996/07/10 17:48:14  pfeifer
# Fixes from Mike Beachy <beachy@chem.columbia.edu>
#
# Revision 0.1  1995/10/25  09:48:39  pfeifer
# Initial revision
#
# modified for use by PDF::API2 by alfred reibenschuh 2001-08-20
# documentation deleted !

package PDF::API2::Matrix;

sub new {
    my $type = shift;
    my $self = [];
    my $len = scalar(@{$_[0]});
    for (@_) {
        return undef if scalar(@{$_}) != $len;
        push(@{$self}, [@{$_}]);
    }
    bless $self, $type;
}

sub concat {
    my $self = shift;
    my $other = shift;
    my $result = new PDF::API2::Matrix (@{$self});
    
    return undef if scalar(@{$self}) != scalar(@{$other});
    for my $i (0 .. $#{$self}) {	
	push @{$result->[$i]}, @{$other->[$i]};
    }
    $result;
}

sub transpose {
    my $self = shift;
    my @result;
    my $m;

    for my $col (@{$self->[0]}) {
        push @result, [];
    }
    for my $row (@{$self}) {
        $m=0;
        for my $col (@{$row}) {
            push(@{$result[$m++]}, $col);
        }
    }
    new PDF::API2::Matrix (@result);
}

sub vekpro {
    my($a, $b) = @_;
    my $result=0;

    for my $i (0 .. $#{$a}) {
        $result += $a->[$i] * $b->[$i];
    }
    $result;
}
                  
sub multiply {
    my $self  = shift;
    my $other = shift->transpose;
    my @result;
    my $m;
    
    return undef if $#{$self->[0]} != $#{$other->[0]};
    for my $row (@{$self}) {
        my $rescol = [];
	for my $col (@{$other}) {
            push(@{$rescol}, vekpro($row,$col));
        }
        push(@result, $rescol);
    }
    new PDF::API2::Matrix (@result);
}


sub solve {
    my $m    = new PDF::API2::Matrix (@{$_[0]});
    my $mr   = $#{$m};
    my $mc   = $#{$m->[0]};
    my $f;
    my $try;
    my $k;
    my $i;
    my $j;
    my $eps = 0.000001;

    return undef if $mc <= $mr;
    ROW: for($i = 0; $i <= $mr; $i++) {
	$try=$i;
	# make diagonal element nonzero if possible
	while (abs($m->[$i]->[$i]) < $eps) {
	    last ROW if $try++ > $mr;
	    my $row = splice(@{$m},$i,1);
	    push(@{$m}, $row);
	}

	# normalize row
	$f = $m->[$i]->[$i];
	for($k = 0; $k <= $mc; $k++) {
            $m->[$i]->[$k] /= $f;
	}
	# subtract multiple of designated row from other rows
        for($j = 0; $j <= $mr; $j++) {
	    next if $i == $j;
            $f = $m->[$j]->[$i];
            for($k = 0; $k <= $mc; $k++) {
                $m->[$j]->[$k] -= $m->[$i]->[$k] * $f;
            }
        }
    }
# Answer is in augmented column    
    transpose new PDF::API2::Matrix @{$m->transpose}[$mr+1 .. $mc];
}

sub print {
    my $self = shift;
    
    print @_ if scalar(@_);
    for my $row (@{$self}) {
        for my $col (@{$row}) {
            printf "%10.5f ", $col;
        }
        print "\n";
    }
}


=head1 AUTHOR

alfred reibenschuh

=cut


1;

__END__
