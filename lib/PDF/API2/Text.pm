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

use PDF::API2::Content;
use PDF::API2::Gfx;
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
	use PDF::API2::Matrix;
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
	$self->add('ET') if(ref($self) eq 'PDF::API2::Text');
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
	my ($self,$text,%opts)=@_;
	my @txt=split(/\s+/,$text);
	my $num_space=(scalar @txt)-1;
	$text=join(' ',@txt);
	my $num_char=length($text);
	my $glyph_width=0;
	$glyph_width=$self->{' font'}->width($text,%opts)*$self->{' fontsize'};
	my $word_spaces=$self->wordspace*$num_space;
	my $char_spaces=$self->charspace*$num_char;
	my $advance=($glyph_width+$word_spaces+$char_spaces)*$self->{' hspace'}/100;
	return $advance;
}

=item $width = $txt->text $text, %options

Applys text to the content and optionally returns the width of the given text.

You can use the -utf8 option to give the text in utf8.

=cut

sub text {
	my ($self,$text,%opt)=@_;
	my @txt=split(/\s+/,$text);
	my %state1=();
	my %state2=();
	my $wd=0;
	$text=join(' ',@txt);
	if(scalar %opt) {
		%state1=$self->textstate;
		
		# look into font options
		if(defined $opt{-font} && defined $opt{-size}) {
			$self->font($opt{-font},$opt{-size});
		} elsif(defined $opt{-font}) {
			$self->font($opt{-font},$self->{' fontsize'});
		} elsif(defined $opt{-size}) {
			$self->font($self->{' font'},$opt{-size});
		}

		$self->fillcolor(@{$opt{-color}}) if(defined $opt{-color});
		
		%state2=$self->textstate;

		if(defined $opt{-underline}) {
			if(defined $opt{-indent}) {
				$self->matrix_update($opt{-indent},0);
			}
			my ($x1,$y1)=$self->textpos;
			my $wd=$self->advancewidth($text,%opt);
			$self->matrix_update($wd,0);
			my ($x2,$y2)=$self->textpos;
			
			my $x3=$x1+(($y2-$y1)/$wd)*($self->{' font'}->underlineposition*$self->{' fontsize'}/1000);
			my $y3=$y1+(($x2-$x1)/$wd)*($self->{' font'}->underlineposition*$self->{' fontsize'}/1000);
			
			my $x4=$x3+($x2-$x1);
			my $y4=$y3+($y2-$y1);
			$self->add('ET');
			PDF::API2::Content::save($self);
			PDF::API2::Content::linewidth($self,$opt{-underline});
			PDF::API2::Content::strokecolor($self,@{$state2{fillcolor}});
			PDF::API2::Gfx::move($self,$x3,$y3);
			PDF::API2::Gfx::line($self,$x4,$y4);
			PDF::API2::Gfx::stroke($self);
			PDF::API2::Content::restore($self);
			$self->add('BT');
			$self->textstate(%state2);
		}
	}
	if(defined $opt{-indent}) {
		if($opt{-utf8}){
			$self->add('[',(-$opt{-indent}*(1000/$self->{' fontsize'})*(100/$self->hspace)),$self->{' font'}->text_utf8($text),']','TJ');
		} else {
			$self->add('[',(-$opt{-indent}*(1000/$self->{' fontsize'})*(100/$self->hspace)),$self->{' font'}->text($text),']','TJ');
		}
		$wd=$self->advancewidth($text,%opt)+$opt{-indent};
	} else {
		if($opt{-utf8}){
			$self->add($self->{' font'}->text_utf8($text),'Tj');
		} else {
			$self->add($self->{' font'}->text($text),'Tj');
		}
		$wd=$self->advancewidth($text,%opt);
	}
	$self->textstate(%state1);

	$self->matrix_update($wd,0);
	return($wd);

}

=item $txt->text_center $text, %options

You can use the -utf8 option to give the text in utf8.

=cut

sub text_center {
	my ($self,$text,%opt)=@_;
	my $width=$self->advancewidth($text,%opt);
	$self->distance(float(-($width/2)),0);
	$self->text($text,%opt);
##	$self->distance(float($width/2),0);
}

=item $txt->text_right $text, %options

You can use the -utf8 option to give the text in utf8.

=cut

sub text_right {
	my ($self,$text,%opt)=@_;
	my $width=$self->advancewidth($text,%opt);
	$self->distance(float(-$width),0);
	$self->text($text,%opt);
##	$self->distance(float($width),0);
}

=item ($flowwidth, $overflow) = $txt->text_justify $text , -width => $width [, -overflow => 1 ] [, -underflow => 1 ] [, %options ]

If -overflow is given, $overflow will contain any text, which wont 
fit into width without exessive scaling and $flowwidth will be 0. 

If -underflow is given, and $text is smaller than $width, $flowwidth will contain the delta between
$width and the text-advancewidth AND text will typeset using $txt->text. 

You can use the -utf8 option to give the text in utf8.

=cut

sub text_justify {
	my ($self,$text,%opts)=@_;

	my @texts=split(/\s+/,$text);
	$text=join(' ',@texts);
	my ($overflow,$ofw);
	my $indent=$opts{-indent}||0;
	if($opts{-overflow}) {
		my @linetext=();
		
		while(($self->advancewidth(join(' ',@linetext),%opts) < ($opts{-width}-$indent)) && scalar @texts){
			push @linetext, shift @texts;
		}
		$overflow=join(' ',@texts);
		$text=join(' ',@linetext);
	} else {
		$text=join(' ',@texts);
	}

	if($opts{-underflow} && ($self->advancewidth($text,%opts) < ($opts{-width}-$indent))) {
		$ofw=($opts{-width}-$indent)-$self->advancewidth($text,%opts);
		$self->text($text,%opts);
		return ($ofw,$overflow);
	} else {
		$ofw=0;
	}

	my @wds=$self->{' font'}->width_array($text,%opts);
	my $swt=$self->{' font'}->width(' ');
	my $wth=$self->advancewidth($text,%opts);

	my $hs=$self->hspace;
	$self->hspace($hs*($opts{-width}-$indent)/$wth);
	$self->text($text,%opts);
	$self->hspace($hs);

	return ($ofw,$overflow);
}

=item $txt->paragraph $x, $y, $width, $heigth, $indent, $text, %options

You can use the -utf8 option to give the text in utf8.

=cut

sub paragraph {
	my ($self,$x,$y,$wd,$ht,$idt,$text,%opt)=@_;
	my $h=$ht;
	my $sz=$self->{' fontsize'};
	my @txt=split(/\s+/,$text);
	$self->lead($sz) if not defined $self->lead();

	my @line=();
	while((defined $txt[0]) && ($ht>0)) {
		$self->translate($x+$idt,$y+$ht-$h);
		@line=();
		while( (defined $txt[0]) && ($self->{' font'}->width(join(' ',@line,$txt[0]),%opt)*($self->{' hspace'}/100)*$sz<($wd-$idt)) ) {
			push(@line, shift @txt);
		}
		@line=(shift @txt) if(scalar @line ==0  && $self->{' font'}->width($txt[0],%opt)*($self->{' hspace'}/100)*$sz>($wd-$idt) );
		my $l=$self->{' font'}->width(join(' ',@line),%opt)*$sz*($self->{' hspace'}/100;
		$self->wordspace(($wd-$idt-$l)/(scalar @line -1)) if(defined $txt[0] && scalar @line>0);
		$idt=$l+$self->{' font'}->width(' ')*$sz;
		$self->text(join(' ',@line),%opt);
		if(defined $txt[0]) { $ht-= $self->lead(); $idt=0; }
		$self->wordspace(0);
	}
	return($idt,$y+$ht-$h,@txt);
}

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

1;

__END__

=head1 AUTHOR

alfred reibenschuh

=cut