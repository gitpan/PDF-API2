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
	( $VERSION ) = '$Revisioning: 0.2.3.8 $ ' =~ /\$Revisioning:\s+([^\s]+)/;
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
use Text::PDF::AFont;
use Text::PDF::Page;
use Text::PDF::Utils;
use Text::PDF::TTFont;
use Text::PDF::TTFont0;

use PDF::API2::Util;
# use PDF::API2::cFont;

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
	$self->{pdf}->{' version'} = 3;
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
	my $key='FFx'.pdfkey($name,$light,$self->{time});

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
	weaken($obj->{' apipdf'}) if($hasWeakRef);
        $obj->{' api'}=$self;
	weaken($obj->{' api'}) if($hasWeakRef);

	$self->resource('Font',$key,$obj);

	$self->{pdf}->out_obj($self->{pages});
	return($obj);
}

#sub cfont {
#	my ($self,@opts)=@_;
#
#	my $obj=PDF::API2::cFont->new($self->{pdf},@opts);
#	my $key=$obj->{' apiname'};
#
#	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));
#
#	$self->resource('Font',$key,$obj);
#
#	$self->{pdf}->out_obj($self->{pages});
#	return($obj);
#}

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

#=item $pdf->imagemask $img, $file
#
#Appends an image mask to image object.
#
#B<Examples:>
#
#	$img=$pdf->image('yetanotherfun.jpg');
#	$pdf->imagemask($img,'yetanotherfun_mask.jpg');
#
#	$img=$pdf->image('truly24bitpic.png');
#	$pdf->imagemask($img,'truly24bitpic.png');
#
#	$img=$pdf->image('reallargefile.pnm');
#	$pdf->imagemask($img,'reallargefile_mask.pnm');
#
#B<Note:> This appends a pdf1.4 (Acrobat 5.x) transparency mask
#(aka. Soft Mask) to the specified image. The mask may be a grayscale
#JPG or PNM which is used as the transparency/opacity information.
#
#B<PNG Note:> In case of a PNG the actual transparency or
#alpha-channel information is read, but works only for
#the following imagetypes:
#
#	Indexed plus tRNS-Chunk
#	Grayscale plus Alpha-Channel
#	RGBA
#
#=cut

sub imagemask {
	my ($self,$img,$file)=@_;
        my $obj=PDF::API2::Image->newMask($self->{pdf},$img,$file,$self->{time});
	$self->{pdf}->new_obj($obj) unless($obj->is_obj($self->{pdf}));

	$obj->{' apipdf'}=$self->{pdf};
	weaken($obj->{' apipdf'}) if($hasWeakRef);
        $obj->{' api'}=$self;
	weaken($obj->{' api'}) if($hasWeakRef);

#	$self->resource('XObject',$obj->{' apiname'},$obj,1);

	$self->{pdf}->out_obj($self->{pages});
	return($img);
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
#
#	PDF::API2::Outlines
#
#=======================================================================
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
#
#	PDF::API2::Outline
#
#=======================================================================
package PDF::API2::Outline;

BEGIN {
	use strict;
	use vars qw( @ISA $hasWeakRef );
	eval " use WeakRef; ";
	$hasWeakRef= $@ ? 0 : 1;
	@ISA = qw(Text::PDF::Dict);
}

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
	weaken($self->{' apipdf'}) if($hasWeakRef);
	$self->{' api'}=$api;
	weaken($self->{' api'}) if($hasWeakRef);
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
	foreach my $k (qw/ api apipdf apipage /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	my @ret=$self->SUPER::outobjdeep(@param);
	foreach my $k (qw/ First Parent Next Last Prev /) {
		$self->{$k}=undef;
		delete($self->{$k});
	}
	return @ret;
}

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
#
#	PDF::API2::ColorSpace
#
#=======================================================================
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

sub outobjdeep {
	my ($self, @opts) = @_;
	foreach my $k (qw/ api apipdf /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	$self->SUPER::outobjdeep(@opts);
}

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
#
#	PDF::API2::ExtGState
#
#=======================================================================
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

sub outobjdeep {
	my ($self, @opts) = @_;
	foreach my $k (qw/ api apipdf /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	$self->SUPER::outobjdeep(@opts);
}

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
#
#	PDF::API2::Font
#
#=======================================================================
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

	$res->{' api'}->resource('Font',$res->{' apiname'},$res);

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
	my $newtext='';
	foreach my $g (0..length($text)-1) {
		$newtext.=
			(substr($text,$g,1)=~/[\x00-\x1f\\\{\}\[\]\(\)]/)
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
	my $width=0;
	foreach (unpack("C*", $text)) {
		$width += $self->{' AFM'}{'wx'}{$self->{' AFM'}{'char'}[$_]||'space'}||0;
	}
	$width/=1000;
	return($width);
}

=item @widths = $font->width_array $text

Returns the widths of the words in $text as if they were at size 1.

=cut

sub width_array {
	my ($self,$text)=@_;
	my @text=split(/\s+/,$text);
	my @widths=map {$self->width($_)} @text;
	return(@widths);
}

sub ascent      { return $_[0]->{' ascent'}; }
sub descent     { return $_[0]->{' descent'}; }
sub italicangle { return $_[0]->{' italicangle'}; }
sub fontbbx     { return @{$_[0]->{' fontbbox'}}; }
sub capheight   { return $_[0]->{' capheight'}; }
sub xheight     { return $_[0]->{' xheight'}; }

sub outobjdeep {
	my ($self, @opts) = @_;
	foreach my $k (qw/ api apipdf /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	$self->SUPER::outobjdeep(@opts);
}


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
#
#	PDF::API2::CoreFont
#
#=======================================================================
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
	if((defined $light) && ($light==1)) {
		$self = $class->SUPER::newCoreLight($pdf,$name,$key);
		$self->{' apifontlight'}=1;
	} else {
		$self = $class->SUPER::newCore($pdf,$name,$key);
	}
	$self->{' apiname'}=$key;
	$self->{' apipdf'}=$pdf;
	if(($name ne 'ZapfDingbats') && ($name ne 'Symbol')) {
		$self->encodeProperLight('latin1',32,255) ;
	} else {
		$self->encodeProperLight('asis') ;
	}
	return($self);
}

sub coerce {
	my ($class,$font,$pdf,$name,$key,$light) = @_;
	my ($self) = {};

	$class = ref $class if ref $class;
	if((defined $light) && ($light==1)) {
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

sub outobjdeep {
	my ($self, @opts) = @_;
	foreach my $k (qw/ api apipdf /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	$self->SUPER::outobjdeep(@opts);
}

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
#
#	PDF::API2::PSFont
#
#=======================================================================
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

sub outobjdeep {
	my ($self, @opts) = @_;
	foreach my $k (qw/ api apipdf /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	$self->SUPER::outobjdeep(@opts);
}


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
#
#	PDF::API2::TTFont
#
#=======================================================================
package PDF::API2::TTFont;
use strict;
use PDF::API2::UniMap qw( utf8_to_ucs2 );
use PDF::API2::Util;
use Text::PDF::Utils;
use POSIX;

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

	my $font=$self->{' font'};
	$font->{'cmap'}->read;
	$font->{'hmtx'}->read;
	$font->{'post'}->read;
	$font->{'loca'}->read;
	my $upem = $font->{'head'}->read->{'unitsPerEm'};

	$self->{' unicid'}=();
	$self->{' uniwidth'}=();
	$self->{' unibbx'}=();
	my @map=$font->{'cmap'}->reverse;
	foreach my $x (0..scalar(@map)) {
		$self->{' unicid'}{$map[$x]||0}=$x;
		$self->{' uniwidth'}{$map[$x]||0}=$font->{'hmtx'}{'advance'}[$x]*1000/$upem;
		$self->{' unibbx'}{$map[$x]||0}=[
			ceil($font->{'loca'}->{'glyphs'}[$x]->read->{'xMin'} * 1000 / $upem),
			ceil($font->{'loca'}->{'glyphs'}[$x]->{'yMin'} * 1000 / $upem),
			ceil($font->{'loca'}->{'glyphs'}[$x]->{'xMax'} * 1000 / $upem),
			ceil($font->{'loca'}->{'glyphs'}[$x]->{'yMax'} * 1000 / $upem)
		] if($font->{'loca'}->{'glyphs'}[$x]);
	}
	$self->{' encoding'}='latin1';
	$self->{' chrcid'}={};
	$self->{' chrcid'}->{'latin1'}=();
	$self->{' chrwidth'}={};
	$self->{' chrwidth'}->{'latin1'}=();
	$self->{' chrbbx'}={};
	$self->{' chrbbx'}->{'latin1'}=();
	foreach my $x (0..255) {
		$self->{' chrcid'}->{'latin1'}{$x}=$self->{' unicid'}{$x}||$self->{' unicid'}{32};
		$self->{' chrwidth'}->{'latin1'}{$x}=$self->{' uniwidth'}{$x}||$self->{' uniwidth'}{32};
		$self->{' chrbbx'}->{'latin1'}{$x}=$self->{' unibbx'}{$x}||$self->{' unibbx'}{32};
	}
    
    $self->{' ascent'}=int($font->{'hhea'}->read->{'Ascender'} * 1000 / $upem);
    $self->{' descent'}=int($font->{'hhea'}{'Descender'} * 1000 / $upem);

	eval {
		$self->{' capheight'}=int(
			$font->{'loca'}->read->{'glyphs'}[
				$font->{'post'}{'STRINGS'}{"H"}||0
			]->read->{'yMax'}
			* 1000 / $upem
		);
	};
	$self->{' capheight'}||=0;
	
	eval {
		$self->{' xheight'}=int(
			$font->{'loca'}->read->{'glyphs'}[
				$font->{'post'}{'STRINGS'}{"x"}||0
			]->read->{'yMax'}
			* 1000 / $upem
		);
	};
	$self->{' xheight'}||=0;

	$self->{' italicangle'}=$font->{'post'}->read->{'italicAngle'};

	$self->{' fontbbox'}=[
		int($font->{'head'}{'xMin'} * 1000 / $upem),
	        int($font->{'head'}{'yMin'} * 1000 / $upem),
	        int($font->{'head'}{'xMax'} * 1000 / $upem),
		int($font->{'head'}{'yMax'} * 1000 / $upem)
	];

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
	my $newtext='';
	$self->{' subvec'}='' unless($self->{' subvec'});
	foreach (unpack("C*", $text)) {
		my $g=$self->{' chrcid'}{$enc}{$_}||32;
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
		my $g=$self->{' unicid'}{vec($text,$x,16)}||0;
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
	my $width=0;
	foreach (unpack("C*", $text)) {
		$width += $self->{' chrwidth'}{$enc}{$_||0};
	}
	$width/=1000;
	return($width);
}

=item @widths = $font->width_array $text

Returns the widths of the words in $text as if they were at size 1.

=cut

sub width_array {
	my ($self,$text)=@_;
	my @text=split(/\s+/,$text);
	my @widths=map {$self->width($_)} @text;
	return(@widths);
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

=item ($llx,$lly,$urx,$ury) = $font->bbox $text

Returns the texts bounding-box as if it were at size 1.

=cut

sub bbox {
	my ($self,$text,$enc)=@_;
	$enc=$enc||$self->{' encoding'};
	my $width=$self->width(substr($text,0,length($text)-1),$enc);
	my @f=@{$self->{' chrbbx'}{$enc}{unpack("C",substr($text,0,1))}};
	my @l=@{$self->{' chrbbx'}{$enc}{unpack("C",substr($text,-1,1))}};
	my ($high,$low);
	foreach (unpack("C*", $text)) {
		$high = $self->{' chrbbx'}{$enc}{$_}->[3]>$high ? $self->{' chrbbx'}{$enc}{$_}->[3] : $high;
		$low  = $self->{' chrbbx'}{$enc}{$_}->[1]<$low  ? $self->{' chrbbx'}{$enc}{$_}->[1] : $low;
	}
	return map {$_/1000} ($f[0],$low,(($width*1000)+$l[2]),$high);
}

=item ($llx,$lly,$urx,$ury) = $font->bbox_utf8 $utf8text

Returns the texts bounding-box as if it were at size 1.

=cut

sub bbox_utf8 {
	my ($self,$text)=@_;
	$text=utf8_to_ucs2($text);
	my $width=$self->width_utf8($text);
	my @f=@{$self->{' unibbx'}{vec($text,0,16)}};
	my @l=@{$self->{' unibbx'}{vec($text,(length($text)>>1)-1,16)}};
	my ($high,$low);
	foreach my $x (0..(length($text)>>1)-1) {
		$high = $self->{' unibbx'}{vec($text,$x,16)}->[3]>$high ? $self->{' unibbx'}{vec($text,$x,16)}->[3] : $high;
		$low  = $self->{' unibbx'}{vec($text,$x,16)}->[1]<$low  ? $self->{' unibbx'}{vec($text,$x,16)}->[1] : $low;
	}
	return map {$_/1000} ($f[0],$low,(($width*1000)+$l[2]),$high);
}

=item $font->encode $encoding

Changes the encoding of the font object. Since encodings are one virtual
in ::API2 for truetype fonts you DONT have to use 'clone'.

=cut

sub encode {
	my ($self,$enc)=@_;

	my $map=PDF::API2::UniMap->new($enc);

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

sub outobjdeep {
	my ($self, @opts) = @_;
	foreach my $k (qw/ api apipdf /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	$self->SUPER::outobjdeep(@opts);
}

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
#
#	PDF::API2::Page
#
#=======================================================================
package PDF::API2::Page;

use strict;
use vars qw(@ISA %pgsz);
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

%pgsz=(
	'4a'		=>	[ 4760	, 6716	],
	'2a'		=>	[ 3368	, 4760	],
	'a0'		=>	[ 2380	, 3368	],
	'a1'		=>	[ 1684	, 2380	],
	'a2'		=>	[ 1190	, 1684	],
	'a3'		=>	[ 842	, 1190	],
	'a4'		=>	[ 595	, 842	],
	'a5'		=>	[ 421	, 595	],
	'a6'		=>	[ 297	, 421	],
	'4b'		=>	[ 5656	, 8000	],
	'2b'		=>	[ 4000	, 5656	],
	'b0'		=>	[ 2828	, 4000	],
	'b1'		=>	[ 2000	, 2828	],
	'b2'		=>	[ 1414	, 2000	],
	'b3'		=>	[ 1000	, 1414	],
	'b4'		=>	[ 707	, 1000	],
	'b5'		=>	[ 500	, 707	],
	'b6'		=>	[ 353	, 500	],
	'letter'	=>	[ 612	, 792	],
	'broadsheet'	=>	[ 1296	, 1584	],
	'ledger'	=>	[ 1224	, 792	],
	'tabloid'	=>	[ 792	, 1224	],
	'legal'		=>	[ 612	, 1008	],
	'executive'	=>	[ 522	, 756	],
	'36x36'		=>	[ 2592	, 2592	],
);

sub _pagesize {
	my $s=shift @_;
	if($pgsz{lc($s)}) {
		return @{$pgsz{lc($s)}};
	} elsif($s=~/^[\d\.]+$/) {
		return($s,$s);
	} else {
		return(595,842);
	}
}

=item $page = PDF::API2::Page->coerce $pdf, $pdfpage

Returns a page object converted from $pdfpage (called from $pdf->openpage).

=cut

sub coerce {
	my ($class, $pdf, $page) = @_;
	my ($self) = {};
	bless($self,$class);
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

=item $page->mediabox $alias

Sets the mediabox.  This method supports the following aliases: 
'4A', '2A', 'A0', 'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 
'4B', '2B', 'B0', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 
'LETTER', 'BROADSHEET', 'LEDGER', 'TABLOID', 'LEGAL', 
'EXECUTIVE', and '36X36'.

=cut

sub mediabox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'MediaBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} elsif(defined $y1) {
		$self->{'MediaBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	} else {
		$self->{'MediaBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,_pagesize($x1))
		);
	}
	$self;
}

=item $page->cropbox $w, $h

=item $page->cropbox $llx, $lly, $urx, $ury

=item $page->cropbox $alias

Sets the cropbox.  This method supports the same aliases as mediabox.

=cut

sub cropbox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'CropBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} elsif(defined $y1) {
		$self->{'CropBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	} else {
		$self->{'CropBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,_pagesize($x1))
		);
	}
	$self;
}

=item $page->bleedbox $w, $h

=item $page->bleedbox $llx, $lly, $urx, $ury

=item $page->bleedbox $alias

Sets the bleedbox.  This method supports the same aliases as mediabox.

=cut

sub bleedbox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'BleedBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} elsif(defined $y1) {
		$self->{'BleedBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	} else {
		$self->{'BleedBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,_pagesize($x1))
		);
	}
	$self;
}

=item $page->trimbox $w, $h

=item $page->trimbox $llx, $lly, $urx, $ury

Sets the trimbox.  This method supports the same aliases as mediabox.

=cut

sub trimbox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'TrimBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} elsif(defined $y1) {
		$self->{'TrimBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	} else {
		$self->{'TrimBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,_pagesize($x1))
		);
	}
	$self;
}

=item $page->artbox $w, $h

=item $page->artbox $llx, $lly, $urx, $ury

=item $page->artbox $alias

Sets the artbox.  This method supports the same aliases as mediabox.

=cut

sub artbox {
	my ($self,$x1,$y1,$x2,$y2) = @_;
	if(defined $x2) {
		$self->{'ArtBox'}=PDFArray(
			map { PDFNum(float($_)) } ($x1,$y1,$x2,$y2)
		);
	} elsif(defined $y1) {
		$self->{'ArtBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,$x1,$y1)
		);
	} else {
		$self->{'ArtBox'}=PDFArray(
			map { PDFNum(float($_)) } (0,0,_pagesize($x1))
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

sub addcontent {
	my ($self,@objs) = @_;
        $self->fixcontents;
        $self->{'Contents'}->add_elements(@objs);
}

sub gfx {
	my ($self) = @_;
	my $gfx=PDF::API2::Gfx->new();
        $self->addcontent($gfx);
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
	my $text=PDF::API2::Text->new();
        $self->addcontent($text);
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
	my $hyb=PDF::API2::Hybrid->new();
        $self->addcontent($hyb);
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

sub outobjdeep {
	my ($self, @opts) = @_;
	foreach my $k (qw/ api apipdf /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	$self->SUPER::outobjdeep(@opts);
}

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
#
#	PDF::API2::Annotation
#
#=======================================================================
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

sub outobjdeep {
	my ($self, @opts) = @_;
	foreach my $k (qw/ api apipdf apipage /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	$self->SUPER::outobjdeep(@opts);
}

=item $ant->link $page, %opts

Defines the annotation as launch-page with page $page and
options %opts (-rect, -border or 'dest-options').

=cut

sub link {
	my ($self,$page,%opts)=@_;
	$self->{Subtype}=PDFName('Link');
	$self->dest($page,%opts);
	$self->rect(@{$opts{-rect}}) if(defined $opts{-rect});
	$self->border(@{$opts{-border}}) if(defined $opts{-border});
	return($self);
}

=item $ant->url $url, %opts

Defines the annotation as launch-url with url $url and
options %opts (-rect and/or -border).

=cut

sub url {
	my ($self,$url,%opts)=@_;
	$self->{Subtype}=PDFName('Link');
	$self->{A}=PDFDict();
	$self->{A}->{S}=PDFName('URI');
	$self->{A}->{URI}=PDFStr($url);
	$self->rect(@{$opts{-rect}}) if(defined $opts{-rect});
	$self->border(@{$opts{-border}}) if(defined $opts{-border});
	return($self);
}

=item $ant->file $file, %opts

Defines the annotation as launch-file with filepath $file and
options %opts (-rect and/or -border).

=cut

sub file {
	my ($self,$file,%opts)=@_;
	$self->{Subtype}=PDFName('Link');
	$self->{A}=PDFDict();
	$self->{A}->{S}=PDFName('Launch');
	$self->{A}->{F}=PDFStr($file);
	$self->rect(@{$opts{-rect}}) if(defined $opts{-rect});
	$self->border(@{$opts{-border}}) if(defined $opts{-border});
	return($self);
}

=item $ant->text $text, %opts

Defines the annotation as textnote with content $text and
options %opts (-rect and/or -open).

=cut

sub text {
	my ($self,$text,%opts)=@_;
	$self->{Subtype}=PDFName('Text');
	$self->content($text);
	$self->rect(@{$opts{-rect}}) if(defined $opts{-rect});
	$self->open($opts{-open}) if(defined $opts{-open});
	return($self);
}

=item $ant->rect $llx, $lly, $urx, $ury

Sets the rectangle of the annotation.

=cut

sub rect {
	my ($self,@r)=@_;
	die "insufficient parameters to annotation->rect( ) " unless(scalar @r == 4);
	$self->{Rect}=PDFArray( map { PDFNum($_) } $r[0],$r[1],$r[2],$r[3], );
	return($self);
}

=item $ant->border @b

Sets the border-styles of the annotation, if applicable.

=cut

sub border {
	my ($self,@r)=@_;
	die "insufficient parameters to annotation->border( ) " unless(scalar @r == 3);
	$self->{Border}=PDFArray( map { PDFNum($_) } $r[0],$r[1],$r[2] );
	return($self);
}

=item $ant->content @lines

Sets the text-content of the annotation, if applicable.

=cut

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

=item $ant->open $bool

Display the annotation either open or closed, if applicable.

=cut

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
#
#	PDF::API2::Content
#
#=======================================================================
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
	my ($self, @opts) = @_;
	$self->restore;
	foreach my $k (qw/ api apipdf apipage /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	$self->SUPER::outobjdeep(@opts);
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
	if($a[0]=~/^\-/){
		my %a=@a;
		$a{-pattern}=[$a{-full}||0,$a{-clear}||0] unless($a{-pattern});
		$self->add('[',floats(@{$a{-pattern}}),']',intg($a{-shift}||0),'d');
	} else {
		if(scalar @a < 1) {
			$self->add('[ ] 0 d');
		} else {
			$self->add('[',floats(@a),'] 0 d');
		}
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
#
#	PDF::API2::Gfx
#
#=======================================================================
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
#
#	PDF::API2::Text
#
#=======================================================================
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
	$self->{' font'}=undef;
	$self->{' fontsize'}=0;
	$self->{' charspace'}=0;
	$self->{' hspace'}=100;
	$self->{' wordspace'}=0;
	$self->{' lead'}=0;
	$self->{' rise'}=0;
	$self->{' render'}=0;
	$self->{' matrix'}=[1,0,0,1,0,0];
	$self->{' fillcolor'}=[0];
	$self->{' strokecolor'}=[0];
	$self->{' translate'}=[0,0];
	$self->{' scale'}=[1,1];
	$self->{' skew'}=[0,0];
	$self->{' rotate'}=0;
	return($self);
}

=item %state = $txt->textstate %state

Sets or gets the current text-object state.

=cut

sub textstate {
	my $self=shift @_;
	my %state;
	if(scalar @_) {
		%state=@_;
		foreach my $k (qw( charspace hspace wordspace lead rise render )) {
			next unless($state{$k});
			eval " \$self->$k(\$state{\$k}); ";
		}
		if($state{font} && $state{fontsize}) {
			$self->font($state{font},$state{fontsize});
		}
		if($state{matrix}) {
			$self->matrix(@{$state{matrix}});
			@{$self->{' translate'}}=@{$state{translate}};
			$self->{' rotate'}=$state{rotate};
			@{$self->{' scale'}}=@{$state{scale}};
			@{$self->{' skew'}}=@{$state{skew}};
		}
		if($state{fillcolor}) {
			$self->fillcolor(@{$state{fillcolor}});
		}
		if($state{strokecolor}) {
			$self->strokecolor(@{$state{strokecolor}});
		}
		%state=();
	} else {
		foreach my $k (qw( font fontsize charspace hspace wordspace lead rise render )) {
			$state{$k}=$self->{" $k"};
		}
		$state{matrix}=[@{$self->{" matrix"}}];
		$state{rotate}=$self->{" rotate"};
		$state{scale}=[@{$self->{" scale"}}];
		$state{skew}=[@{$self->{" skew"}}];
		$state{translate}=[@{$self->{" translate"}}];
		$state{fillcolor}=[@{$self->{" fillcolor"}}];
		$state{strokecolor}=[@{$self->{" strokecolor"}}];
	}
	return(%state);
}

=item ($tx,$ty) = $txt->textpos

Gets the current estimated text position.

=cut

sub textpos {
	my $self=shift @_;
	my (@m)=$self->matrix;
	return($m[4],$m[5]);
}

=item $txt->matrix $a, $b, $c, $d, $e, $f

Sets the matrix.

B<PLEASE NOTE:> This method is not expected to be called by the user
and else will 'die'. This was implemented to keep proper state in the
text-object, so please use transform, transform_rel, translate, scale, 
skew or rotate instead.

=cut

sub matrix {
	my $self=shift @_;
	my $cl=caller;
	my @cl=caller;
	die sprintf("unauthorized call from package=%s,file=%s,line=%i",@cl) if($cl !~ /^PDF::API2/);
	if(scalar @_) {
		my ($a,$b,$c,$d,$e,$f)=@_;
		$self->add((floats($a,$b,$c,$d,$e,$f)),'Tm');
		@{$self->{' matrix'}}=($a,$b,$c,$d,$e,$f);
	}
	return(@{$self->{' matrix'}});
}

sub transform {
	my ($self,%opt)=@_;
	$self->SUPER::transform(%opt);
	if($opt{-translate}) {
		@{$self->{' translate'}}=@{$opt{-translate}};
	} else {
		@{$self->{' translate'}}=(0,0);
	}
	if($opt{-rotate}) {
		$self->{' rotate'}=$opt{-rotate};
	} else {
		$self->{' rotate'}=0;
	}
	if($opt{-scale}) {
		@{$self->{' scale'}}=@{$opt{-scale}};
	} else {
		@{$self->{' scale'}}=(1,1);
	}
	if($opt{-skew}) {
		@{$self->{' skew'}}=@{$opt{-skew}};
	} else {
		@{$self->{' skew'}}=(0,0);
	}
	return($self);
}

sub translate {
	my ($self,$x,$y)=@_;
	$self->transform(-translate=>[$x,$y]);
}

sub scale {
	my ($self,$sx,$sy)=@_;
	$self->transform(-scale=>[$sx,$sy]);
}

sub skew {
	my ($self,$a,$b)=@_;
	$self->transform(-skew=>[$a,$b]);
}

sub rotate {
	my ($self,$a)=@_;
	$self->transform(-rotate=>$a);
}

=item $txt->transform_rel %opts

Sets transformations (eg. translate, rotate, scale, skew) in pdf-canonical order, 
but relative to the previously set values.

B<Example:>

	$txt->transform_rel(
		-translate => [$x,$y],
		-rotate    => $rot,
		-scale     => [$sx,$sy],
		-skew      => [$sa,$sb],
	)

=cut 

sub transform_rel {
	my ($self,%opt)=@_;
	my ($sa1,$sb1)=@{$opt{-skew} ? $opt{-skew} : [0,0]};
	my ($sa0,$sb0)=@{$self->{" skew"}};
	

	my ($sx1,$sy1)=@{$opt{-scale} ? $opt{-scale} : [1,1]};
	my ($sx0,$sy0)=@{$self->{" scale"}};

	my $rot1=$opt{"-rotate"} || 0;
	my $rot0=$self->{" rotate"};

	my ($tx1,$ty1)=@{$opt{-translate} ? $opt{-translate} : [0,0]};
	my ($tx0,$ty0)=@{$self->{" translate"}};

	$self->transform(
		-skew=>[$sa0+$sa1,$sb0+$sb1],
		-scale=>[$sx0*$sx1,$sy0*$sy1],
		-rotate=>$rot0+$rot1,
		-translate=>[$tx0+$tx1,$ty0+$ty1],
	);
	return($self);
}

sub matrix_update {
	my ($self,$tx,$ty)=@_;
	my ($a,$b,$c,$d,$e,$f)=$self->matrix;
	my $mtx=PDF::API2::Matrix->new([$a,$b,0],[$c,$d,0],[$e,$f,1]);
	my $tmtx=PDF::API2::Matrix->new([$tx,$ty,1]);
	$tmtx=$tmtx->multiply($mtx);
	@{$self->{' matrix'}}=(
		$a,$b,
		$c,$d,
		$tmtx->[0][0],$tmtx->[0][1]
	);
	@{$self->{' translate'}}=($tmtx->[0][0],$tmtx->[0][1]);
	return($self);
}

sub outobjdeep {
	my ($self, @opts) = @_;
	$self->add('ET');
	foreach my $k (qw/ api apipdf apipage font fontsize charspace hspace wordspace lead rise render matrix fillcolor strokecolor translate scale skew rotate /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	$self->SUPER::outobjdeep(@opts);
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

=item $spacing = $txt->charspace $spacing

=cut

sub charspace {
	my ($self,$para)=@_;
	if($para) {
		$self->{' charspace'}=$para;
		$self->add(float($para,6),'Tc');
	}
	return $self->{' charspace'};
}

=item $spacing = $txt->wordspace $spacing

=cut

sub wordspace {
	my ($self,$para)=@_;
	if($para) {
		$self->{' wordspace'}=$para;
		$self->add(float($para,6),'Tw');
	}
	return $self->{' wordspace'};
}

=item $spacing = $txt->hspace $spacing

=cut

sub hspace {
	my ($self,$para)=@_;
	if($para) {
		$self->{' hspace'}=$para;
		$self->add(float($para,6),'Tz');
	}
	return $self->{' hspace'};
}

=item $leading = $txt->lead $leading

=cut

sub lead {
        my ($self,$para)=@_;
        if (defined ($para)) {
                $self->{' lead'} = $para;
                $self->add(float($para),'TL');
        }
        return $self->{' lead'};
}

=item $rise = $txt->rise $rise

=cut

sub rise {
        my ($self,$para)=@_;
        if (defined ($para)) {
                $self->{' rise'} = $para;
                $self->add(float($para),'Ts');
        }
        return $self->{' rise'};
}

=item $rendering = $txt->render $rendering

=cut

sub render {
	my ($self,$para)=@_;
        if (defined ($para)) {
                $self->{' render'} = $para;
		$self->add(intg($para),'Tr');
        }
        return $self->{' render'};
}

=item $txt->cr $linesize

takes an optional argument giving a custom leading between lines.

=cut

sub cr {
	my ($self,$para)=@_;
	if(defined($para)) {
		$self->add(0,float($para),'Td');
		$self->matrix_update(0,$para);
	} else {
		$self->add('T*');
		$self->matrix_update(0,$self->lead);
	}
}

=item $txt->nl

=cut

sub nl {
	my ($self)=@_;
	$self->add('T*');
	$self->matrix_update(0,$self->lead);
}

=item $txt->distance $dx,$dy

=cut

sub distance {
	my ($self,$dx,$dy)=@_;
	$self->add(float($dx),float($dy),'Td');
	$self->matrix_update($dx,$dy);
}

=item $width = $txt->advancewidth $string

Returns the width of the string based on all currently set text-attributes.

=cut

sub advancewidth {
	my ($self,@txt)=@_;
	my $text=join(' ',@txt);
	@txt=split(/\s+/,$text);
	my $num_space=(scalar @txt)-1;
	$text=join(' ',@txt);
	my $num_char=length($text);
	my $glyph_width=$self->{' font'}->width($text)*$self->{' fontsize'};
	my $word_spaces=$self->wordspace*$num_space;
	my $char_spaces=$self->charspace*$num_char;
	my $advance=($glyph_width+$word_spaces+$char_spaces)*$self->{' hspace'}/100;
	return $advance;
}

=item $width = $txt->text $string

Applys text to the content and optionally returns the width of the given text.

=cut

sub text {
	my ($self,@txt)=@_;
	my $text=join(' ',@txt);
	@txt=split(/\s+/,$text);
	$text=join(' ',@txt);
	$self->add($self->{' font'}->text($text),'Tj');
	my $wd=$self->advancewidth($text);
	$self->matrix_update($wd,0);
	return($wd);

}

=item $txt->text_center $string

=cut

sub text_center {
	my ($self,$text)=@_;
	my $width=$self->advancewidth($text);
	$self->distance(float(-($width/2)),0);
	$self->text($text);
##	$self->distance(float($width/2),0);
}

=item $txt->text_right $string

=cut

sub text_right {
	my ($self,$text)=@_;
	my $width=$self->advancewidth($text);
	$self->distance(float(-$width),0);
	$self->text($text);
##	$self->distance(float($width),0);
}

=item ($flowwidth, $overflow) = $txt->text_justify $width, $string [, -overflow => 1 ] [, -underflow => 1 ]

If -overflow is given, $overflow will contain any text, which wont 
fit into width without exessive scaling and $flowwidth will be 0. 

If -underflow is given, and $text is smaller than $width, $flowwidth will contain the delta between
$width and the text-advancewidth AND text will typeset using $txt->text. 

=cut

sub text_justify {
	my ($self,$width,$text,%opts)=@_;

	my @texts=split(/\s+/,$text);
	$text=join(' ',@texts);
	my ($overflow,$ofw);

	if($opts{-overflow}) {
		my @linetext=();
		
		while(($self->advancewidth(join(' ',@linetext)) < $width) && scalar @texts){
			push @linetext, shift @texts;
		}
		$overflow=join(' ',@texts);
		$text=join(' ',@linetext);
	} else {
		$text=join(' ',@texts);
	}

	if($opts{-underflow} && ($self->advancewidth($text) < $width)) {
		$ofw=$width-$self->advancewidth($text);
		$self->text($text);
		return ($ofw,$overflow);
	} else {
		$ofw=0;
	}

	my @wds=$self->{' font'}->width_array($text);
	my $swt=$self->{' font'}->width(' ');
	my $wth=$self->advancewidth($text);

#	if(($wth < $width) && (scalar @wds >1)) {
#		$self->wordspace(
#		(($width-$wth)/(scalar @wds -1))-$swt-($self->wordspace*$self->hspace/100)
#		);
#		$self->add($self->{' font'}->text($text),'Tj');
#		$self->wordspace(0);
#	} else {
		my $hs=$self->hspace;
		$self->hspace($hs*$width/$wth);
		$self->text($text);
		$self->hspace($hs);
#	}
	return ($ofw,$overflow);
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
		$self->text($text);
		$self->nl;
	}
}

=item $txt->paragraph $x, $y, $width, $heigth, $indent, @text

=cut

sub paragraph {
	my ($self,$x,$y,$wd,$ht,$idt,@txt)=@_;
	my $text=join(' ',@txt);
	my $h=$ht;
	my $sz=$self->{' fontsize'};
	@txt=split(/\s+/,$text);
	$self->lead($sz) if not defined $self->lead();

	my @line=();
	while((defined $txt[0]) && ($ht>0)) {
		$self->translate($x+$idt,$y+$ht-$h);
		@line=();
		while( (defined $txt[0]) && ($self->{' font'}->width(join(' ',@line,$txt[0]))*($self->{' hspace'}/100)*$sz<($wd-$idt)) ) {
			push(@line, shift @txt);
		}
		@line=(shift @txt) if(scalar @line ==0  && $self->{' font'}->width($txt[0])*($self->{' hspace'}/100)*$sz>($wd-$idt) );
		my $l=$self->{' font'}->width(join(' ',@line))*$sz*($self->{' hspace'}/100);
		$self->wordspace(($wd-$idt-$l)/(scalar @line -1)) if(defined $txt[0] && scalar @line>0);
		$idt=$l+$self->{' font'}->width(' ')*$sz;
		$self->text(join(' ',@line));
		if(defined $txt[0]) { $ht-= $self->lead(); $idt=0; }
		$self->wordspace(0);
	}
	return($idt,$y+$ht-$h,@txt);
}

#sub paragraphformat {
#	my ($self,$x,$y,$wd,$ht,$idt,@txtobj)=@_;
#	my $yy=$y-$ht;
#	my @t;
#	while(scalar @txtobj>0 && $y>$yy) {
#		my $text=shift @txtobj;
#		if(ref($text)=~/Font/i) {
#			$self->font($text,$self->{' fontsize'});
#			next; 
#		}
#		while(ref($text) ? scalar @{$text}>0 : (defined $text) && ($text ne '')) {
#			($idt,$y,@t)=$self->paragraph($x,$y,$wd,$y-$yy,$idt,ref($text) ? @{$text} : $text);
#			$text=[@t];
#		}
#	}
#	return($idt,$y,@txtobj);
#}

sub fillcolor {
	my $self=shift @_;
	if(scalar @_) {
		$self->SUPER::fillcolor(@_);
		@{$self->{' fillcolor'}}=@_;
	}
	return(@{$self->{' fillcolor'}});
}

sub strokecolor {
	my $self=shift @_;
	if(scalar @_) {
		$self->SUPER::strokecolor(@_);
		@{$self->{' strokecolor'}}=@_;
	}
	return(@{$self->{' strokecolor'}});
}

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
#
#	PDF::API2::Hybrid
#
#=======================================================================
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
	$self->{' font'}=undef;
	$self->{' fontsize'}=0;
	$self->{' charspace'}=0;
	$self->{' hspace'}=100;
	$self->{' wordspace'}=0;
	$self->{' lead'}=0;
	$self->{' rise'}=0;
	$self->{' render'}=0;
	$self->{' matrix'}=[1,0,0,1,0,0];
	$self->{' fillcolor'}=[0];
	$self->{' strokecolor'}=[0];
	$self->{' translate'}=[0,0];
	$self->{' scale'}=[1,1];
	$self->{' skew'}=[0,0];
	$self->{' rotate'}=0;
	return($self);
}

=item $hyb->matrix $a, $b, $c, $d, $e, $f

Sets the matrix.

=cut

sub matrix {
	my ($self,$a,$b,$c,$d,$e,$f)= @_;
	if($self->{' apiistext'} == 1) {
		return PDF::API2::Text::matrix(@_);
	} else {
		$self->add(floats($a,$b,$c,$d,$e,$f),'cm');
	}
	return($self);
}


sub outobjdeep {
	my ($self) = @_;
	if($self->{' apiistext'} != 1) {
		$self->add('ET');
	}
	foreach my $k (qw/ api apipdf apipage font fontsize charspace hspace wordspace lead rise render matrix fillcolor strokecolor translate scale skew rotate /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	PDF::API2::Content::outobjdeep(@_);
}

sub transform {
	my ($self)=@_;
	if($self->{' apiistext'} != 1) {
		PDF::API2::Content::transform(@_);
	} else {
		PDF::API2::Text::transform(@_);
	}
	return($self);
}

=item $hyb->textstart

=cut

sub textstart {
	my ($self)=@_;
	if(!defined($self->{' apiistext'}) || $self->{' apiistext'} != 1) {
		$self->add('BT');
		$self->{' apiistext'}=1;
		$self->{' font'}=undef;
		$self->{' fontsize'}=0;
		$self->{' charspace'}=0;
		$self->{' hspace'}=100;
		$self->{' wordspace'}=0;
		$self->{' lead'}=0;
		$self->{' rise'}=0;
		$self->{' render'}=0;
		@{$self->{' matrix'}}=(1,0,0,1,0,0);
		@{$self->{' fillcolor'}}=(0);
		@{$self->{' strokecolor'}}=(0);
		@{$self->{' translate'}}=(0,0);
		@{$self->{' scale'}}=(1,1);
		@{$self->{' skew'}}=(0,0);
		$self->{' rotate'}=0;
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
#
#	PDF::API2::PdfImage
#
#=======================================================================
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

sub outobjdeep {
	my ($self, @opts) = @_;
	foreach my $k (qw/ api apipdf /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	$self->SUPER::outobjdeep(@opts);
}

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
#
#	PDF::API2::Barcode
#
#=======================================================================
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

	@ean_code_odd
	@ean_code_even

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


@ean_code_odd =qw( 3211 2221 2122 1411 1132 1231 1114 1312 1213 3112 );
@ean_code_even=qw( 1123 1222 2212 1141 2311 1321 4111 2131 3121 2113 );

sub encode_ean13 {
	my $string=shift @_;
	my @c=split(//,$string);
	my ($enc,@bar);
	my $v=shift @c;
	push(@bar,['07',"$v"]);
	push(@bar,'a1a');
	if($v==0) {
		foreach(0..5) {
			my $f=shift @c;
			push(@bar,[$ean_code_odd[$f],"$f"]);
		}
	} elsif($v==1) {
		my $f=shift @c;
		push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
	} elsif($v==2) {
		my $f=shift @c;
		push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
	} elsif($v==3) {
		my $f=shift @c;
		push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
	} elsif($v==4) {
		my $f=shift @c;
		push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
	} elsif($v==5) {
		my $f=shift @c;
		push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
	} elsif($v==6) {
		my $f=shift @c;
		push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
	} elsif($v==7) {
		my $f=shift @c;
		push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
	} elsif($v==8) {
		my $f=shift @c;
		push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
	} elsif($v==9) {
		my $f=shift @c;
		push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_even[$f],"$f"]);
		$f=shift @c; push(@bar,[$ean_code_odd[$f],"$f"]);
	}
	push(@bar,'1a1a1');
	foreach(0..5) {
		my $f=shift @c;
		push(@bar,[$ean_code_odd[$f],"$f"]);
	}
	push(@bar,'a1a');
	return @bar;
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
	code128a, code128b, code128c, ean128,
	ean13

=cut

sub new {
	my $class=shift @_;
	my $key=shift @_;
	my %opts=@_;
	my $self = $class->SUPER::new;
	$self->{' stream'}='';
	my (@bar,@ext);

	$opts{-type}=lc($opts{-type});
	$self->{' bfont'}=$opts{-font};

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
	} elsif( $opts{-type}=~/^ean13/ ) {
		@bar = encode_ean13($opts{-code});
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
	my ($code,$str,$f,$t,$l,$h,$xo);
	$self->fillcolorbyname('black');
	$self->strokecolorbyname('black');

	my $bw=1;
	foreach my $b (@bar) {
		if(ref($b)) {
			($code,$str)=@{$b};
		} else {
			$code=$b;
			$str=undef;
		}
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
				if($c ne '0') {
					$self->linewidth($w-$self->{' ofwt'});
					$self->move($x+$xo,$l);
					$self->line($x+$xo,$h);
					$self->stroke;
				}
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
			$self->font($self->{' bfont'},$f);
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
		$self->font($self->{' bfont'},$f);
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
	my ($self, @opts) = @_;
	foreach my $k (qw/ api apipdf apipage font fontsize charspace hspace wordspace lead rise render matrix fillcolor strokecolor translate scale skew rotate bfont /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	use Text::PDF::Dict;
	Text::PDF::Dict::outobjdeep(@_);
}

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
#
#	PDF::API2::Image
#
#=======================================================================
package PDF::API2::Image;
use strict;
use PDF::API2::Util;
use Text::PDF::Utils;
use Text::PDF::ImageJPEG;
use Text::PDF::ImageGD;
use Text::PDF::ImagePPM;
use Text::PDF::ImagePNG;

=head2 PDF::API2::Image

=item $img = PDF::API2::Image->new $pdf, $imgfile

Returns a new image object (called from $pdf->image).

=cut

sub new {
	my ($class,$pdf,$file,$tt)=@_;
	my ($obj,$buf);
	if(ref $file) {
		if(UNIVERSAL::isa($file,'GD::Image')) {
			$obj=Text::PDF::ImageGD->new($pdf,'IMGxGDx'.pdfkey($file),$file);
			$obj->{' apiname'}='IMGxGDx'.pdfkey($file);
		} elsif(UNIVERSAL::isa($file,'Image::Base')) {
			$obj=Text::PDF::ImageIMAGE->new($pdf,'IMGxIMAGEx'.pdfkey($file),$file);
			$obj->{' apiname'}='IMGxIMAGEx'.pdfkey($file);
		} else {
			die "Unknown Object '$file'";
		}
	} else {
		open(INF,$file);
		binmode(INF);
		read(INF,$buf,10,0);
		close(INF);
		if ($buf=~/^\xFF\xD8/) {
			$obj=Text::PDF::ImageJPEG->new($pdf,'IMGxJPEGx'.pdfkey($file),$file);
			$obj->{' apiname'}='IMGxJPEGx'.pdfkey($file);
		} elsif ($buf=~/^\x89PNG/) {
			$obj=Text::PDF::ImagePNG->new($pdf,'IMGxPNGx'.pdfkey($file),$file);
			$obj->{' apiname'}='IMGxPNGx'.pdfkey($file);
		} elsif ($buf=~/^P[456][\s\n]/) {
			$obj=Text::PDF::ImagePPM->new($pdf,'IMGxPPMx'.pdfkey($file),$file);
			$obj->{' apiname'}='IMGxPPMx'.pdfkey($file);
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
	###	$pdf->new_obj($obj);
	####	$obj->{' apipdf'}.=$pdf;
	}
	return($obj);
}

sub newMask {
	my ($class,$pdf,$img,$file,$tt)=@_;
	my ($obj,$buf);
	open(INF,$file);
	binmode(INF);
	read(INF,$buf,10,0);
	close(INF);
	if ($buf=~/^\xFF\xD8/) {
		$obj=PDF::API2::JPEG->newMask($img,$file,$tt);
	} elsif ($buf=~/^\x89PNG/) {
		$obj=PDF::API2::PNG->newMask($img,$file,$tt);
	} elsif ($buf=~/^P[456][\s\n]/) {
		$obj=PDF::API2::PPM->newMask($img,$file,$tt);
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
#
#	PDF::API2::IOString
#	Original Copyright 1998-2000 Gisle Aas.
#	modified by Alfred Reibenschuh <areibens@cpan.org> for PDF::API2
#
#=======================================================================
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
#
#	PDF::API2::Matrix
#	Original Copyright 1995-96 Ulrich Pfeifer.
#	modified by Alfred Reibenschuh <areibens@cpan.org> for PDF::API2
#
#=======================================================================
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

    print STDERR "Matrix: \n";
    print @_ if scalar(@_);
    for my $row (@{$self}) {
        for my $col (@{$row}) {
            printf STDERR "%10.5f ", $col;
        }
        print STDERR "\n";
    }
}


=head1 AUTHOR

alfred reibenschuh

=cut


1;

__END__

