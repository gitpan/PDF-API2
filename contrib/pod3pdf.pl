#!/usr/local/bin/perl
BEGIN {
	eval "use PDF::API2;";
}
package MyParser;
BEGIN {
	eval "use PDF::API2;";
}

use Pod::Parser;
@ISA = qw( Pod::Parser );


sub newpage {
	my $self=shift @_;
	$self->{page}=$self->{pdf}->page;
	$self->{page}->mediabox(595,842);
	$self->{txt}=$self->{page}->text;
	$self->{gfx}=$self->{page}->gfx;
	$self->{txt}->fillcolor($self->{textcolor});
	$self->{x}=0;
	$self->{y}=$self->{top};
	$self->{idt}=0;
	$self->{wasbreak}=1;

}
sub pdfsave {
	my $self=shift @_;
	$self->{pdf}->saveas(shift @_);
}

sub new {
	my ($class)=@_;
	my $self=$class->SUPER::new;
	$self->{pdf}=PDF::API2->new;
	$self->{pdf}->{forcecompress}=1;
	$self->{dfont}=$self->{pdf}->corefont("Verdana");
	$self->{pdf}->resource('Font','dfont',$self->{dfont});
	$self->{dfontb}=$self->{pdf}->corefont("Verdana,Bold");
	$self->{pdf}->resource('Font','dfontb',$self->{dfontb});
	$self->{dfonti}=$self->{pdf}->corefont("Verdana,Italic");
	$self->{pdf}->resource('Font','dfonti',$self->{dfonti});
	$self->{dfontbi}=$self->{pdf}->corefont("Verdana,BoldItalic");
	$self->{pdf}->resource('Font','dfontbi',$self->{dfontbi});
	$self->{mfont}=$self->{pdf}->corefont("Courier",1);
	$self->{pdf}->resource('Font','mfont',$self->{mfont});
	$self->{mfontb}=$self->{pdf}->corefont("Courier-Bold",1);
	$self->{pdf}->resource('Font','mfontb',$self->{mfontb});
	$self->{mfonti}=$self->{pdf}->corefont("Courier-Oblique",1);
	$self->{pdf}->resource('Font','mfonti',$self->{mfonti});
	$self->{mfontbi}=$self->{pdf}->corefont("Courier-BoldOblique",1);
	$self->{pdf}->resource('Font','mfontbi',$self->{mfontbi});
	$self->{otl}=[$self->{pdf}->outlines];
	$self->{textcolor}="black";
	$self->{headcolor}="#0050B2";
	$self->{itemcolor}="#B25000";
	$self->{'lastitem'}=0;
	$self->{left}=50;
	$self->{top}=780;
	$self->{bot}=50;
	$self->{width}=500;
	$self->newpage;
	return($self);
}

   sub begin_pod {
	my ($p)=@_;
	$p->{wasbreak}=0;
   }

   sub end_pod {
	my ($p)=@_;
	$p->{wasbreak}=0;
   }

   sub command {
       my ($p, $command, $paragraph, $line_num) = @_;
       print STDERR "\ncmd=$command [$line_num] ";
       my @txt = $p->interpolate($paragraph, $line_num);
       my $first=1;
       $p->{x}=0;
	if($command eq 'title'){
		$p->{idt}=0;
		if($p->{wasbreak}==1) {
			$p->{y}-=25;
		} else {
			$p->{y}-=40;
		}
	       foreach my $t (@txt) {
		       my $text=ref($t)?$$t:$t;
		       while(length($text)){
			       my @ovl=();
				$p->newpage unless($first);
				$first=1;
			       $p->{txt}->font($p->{dfontbi},30);
			       $p->{txt}->fillcolor($p->{headcolor});
				($p->{idt},$p->{y},@ovl)=$p->{txt}->paragraph(
					$text,
					-x => $p->{left},
					-y => $p->{y},
					-h => $p->{y}-$p->{bot},
					-w => $p->{width},
					-lead => 30,
					-flindent => $p->{idt},
				);
				$text=join(' ',@ovl);
				$first=0 if(scalar @ovl);
			}
		}
		$p->{idt}=0;
		$p->{y}-=20;
	} elsif(($x)=$command=~/head(\d)/i){
		$p->{idt}=0;

		if($p->{wasbreak}==1) {
			$p->{y}-=25-4*$1;
		} else {
			$p->{y}-=40-4*$1;
		}

		splice(@{$p->{otl}},$1);
		my $o=@{$p->{otl}}->[-1]->outline->title(join(' ',map {ref($_)?$$_:$_}@txt))->dest($p->{page},-fith=>$p->{y}+25);
		push(@{$p->{otl}},$o);

	       foreach my $t (@txt) {
		       my $text=ref($t)?$$t:$t;
		       while(length($text)){
			       my @ovl=();
				$p->newpage unless($first);
				$p->{x}=0 unless($first);
				$first=1;
			       $p->{txt}->font($p->{dfontb},20-1.5*$1);
			       $p->{txt}->fillcolor($p->{headcolor});
				print "\nx=$p->{x},y=$p->{y},l=$p->{left},t='$text'\n";
				($p->{idt},$p->{y},@ovl)=$p->{txt}->paragraph(
					$text,
					-x => $p->{left},
					-y => $p->{y},
					-h => $p->{y}-$p->{bot},
					-w => $p->{width},
					-lead => 20-1.5*$1,
					-flindent => $p->{idt},
				);
				print " -> x=$p->{x},y=$p->{y}\n";
				$text=join(' ',@ovl);
				$first=0 if(scalar @ovl);
			}
		}
		$p->{idt}=0;
		$p->{y}-=10;
	} elsif ($command eq 'item') {
		@{$p->{otl}}->[-1]->outline->title(join(' ',map {ref($_)?$$_:$_} @txt))->dest($p->{page},-fith=>$p->{y});
		$p->{y}-=20;
		$p->{idt}=0;
	       foreach my $t (@txt) {
		       my $text=ref($t)?$$t:$t;
		       while(length($text)){
			       my @ovl=();
				$p->newpage unless($first);
				$p->{x}=0 unless($first);
				$first=1;
				if(ref($t) eq 'B') {
				       $p->{txt}->font($p->{dfontb},9);
				} elsif (ref($t) eq 'I') {
				       $p->{txt}->font($p->{dfonti},9);
				} else {
				       $p->{txt}->font($p->{dfontb},9);
				}
			       $p->{txt}->fillcolor($p->{itemcolor});
				($p->{idt},$p->{y},@ovl)=$p->{txt}->paragraph(
					$text,
					-x => $p->{left},
					-y => $p->{y},
					-h => $p->{y}-$p->{bot},
					-w => $p->{width},
					-lead => 10,
					-flindent => $p->{idt},
				);
				$text=join(' ',@ovl);
				$first=0 if(scalar @ovl);
			}
		}
		$p->{idt}=0;
	} elsif($command=~/^over/i){
		$p->{left}=50+5*$expansion;
		$p->{width}-=5*$expansion;
	} elsif($command=~/^back/i){
		$p->{left}=50;
		$p->{width}=500;
	} elsif($command=~/^begin/i && $expansion=~/pod3pdf/i){
		my ($wd,$ht)=($expansion=~/\(\s*([\d\.]+)\s*\,\s*([\d\.]+)\s*\)/);
		$p->newpage unless($p->{bot} < ($p->{y}-$ht));
		$p->{y}-=$ht;
		$p->{pod3pdf}=1;
		$p->{pod3obj}=$p->{page}->hybrid;
		$p->{pod3obj}->translate($p->{left}+($p->{width}/2)-($wd/2),$p->{y});
	} elsif($command=~/^end/i && $expansion=~/pod3pdf/i){
		$p->{pod3pdf}=0;
		delete $p->{pod3obj};
	} elsif($command=~/^for/i && $expansion=~/pod3pdf/i){
		my $cmd=$expansion;
		$cmd=~s/^\s*pod3pdf\s+//i;
		if($cmd=~/newpage/) {
			$p->newpage;
		} elsif ($cmd=~/loadimage\s+(\S+)\s+(\S+)\s*/) {
			my $img=$p->{pdf}->image($2);
			$p->{pdf}->resource('XObject',$1,$img);
		} elsif ($cmd=~/image\s+(\S+)\s+(\S+)\s*/) {
			my $img=$p->{pdf}->image($1);
			$p->newpage unless($p->{bot} < ($p->{y}-$img->height*($2||1)));
			$p->{y}-=$img->height*($2||1);
			$p->{gfx}->image($img,$p->{left}+($p->{width}/2)-($img->width*($2||1)/2),$p->{y},($2||1));
		} elsif ($cmd=~/corefont\s+(\S+)\s+(\S+)\s*/) {
			$p->{pdf}->resource('Font',$2,$p->{pdf}->corefont($1,1));
		}
	} else {
		$p->{y}-=15;
		$p->{idt}=0;
	       foreach my $t (@txt) {
		       my $text=ref($t)?$$t:$t;
		       while(length($text)){
			       my @ovl=();
				$p->newpage unless($first);
				$p->{x}=0 unless($first);
				$first=1;
				if(ref($t) eq 'B') {
				       $p->{txt}->font($p->{dfontb},10);
				} elsif (ref($t) eq 'I') {
				       $p->{txt}->font($p->{dfonti},10);
				} else {
				       $p->{txt}->font($p->{dfont},10);
				}
			       $p->{txt}->fillcolor($p->{textcolor});
	
				($p->{idt},$p->{y},@ovl)=$p->{txt}->paragraph(
					$text,
					-x => $p->{left},
					-y => $p->{y},
					-h => $p->{y}-$p->{bot},
					-w => $p->{width},
					-lead => 10,
					-flindent => $p->{idt},
				);
				print " -> x=$p->{x},y=$p->{y}\n";
				$text=join(' ',@ovl);
				$first=0 if(scalar @ovl);
			}
		}
		$p->{idt}=0;
	}
	$p->{x}=$p->{left};
	$p->{wasbreak}=0;
   }

   sub verbatim {
       my ($p, $paragraph, $line_num) = @_;
       if($p->{pod3pdf}==1) {
		$p->{pod3obj}->add($paragraph);
	       print STDERR "pod3pdf verbatim($p->{x},$p->{y}) [$line_num] ";
		$p->{y}-=10;
		return;
       }

       my $left=$p->{left};
       $p->{left}+=25;
       print STDERR "verbatim($p->{x},$p->{y}) [$line_num] ";
       my $expansion = $p->interpolate_verb($paragraph, $line_num);
	$p->{y}-=15;
       foreach my $line (split(/\n/,$expansion)) {
		$p->newpage if($p->{y}<$p->{bot});
		$line=~s/\t/        /g;
		$line=~s/\x20/\xA0/g;
	       $p->{txt}->font($p->{mfont},9);
	       $p->{txt}->fillcolor($p->{textcolor});
	       $p->{txt}->hspace(80);
	       $p->{txt}->translate($p->{left},$p->{y});
	       $p->{txt}->text($line);
	       $p->{y}-=10;
       }
       $p->{txt}->hspace(100);
       $p->{left}=$left;
	$p->{x}=$p->{left};
	$p->{wasbreak}=0;
   }

   sub textblock {
       my ($p, $paragraph, $line_num) = @_;
       if($p->{pod3pdf}==1) {
		$p->{pod3obj}->add($paragraph);
	       print STDERR "pod3pdf textblock($p->{x},$p->{y}) [$line_num] ";
		$p->{y}-=10;
		return;
       }
       print STDERR "textblock($p->{x},$p->{y}) [$line_num] ";
	$p->{y}-=15;
       my @txt = $p->interpolate($paragraph, $line_num);
       my $first=1;
	$p->{idt}=0;
       foreach my $t (@txt) {
	       my $text=ref($t)?$$t:$t;
	       while(length($text)){
		       my @ovl=();
			$p->newpage unless($first);
			$first=1;
			if(ref($t) eq 'B') {
			       $p->{txt}->font($p->{dfontb},10);
			       $p->{txt}->fillcolor($p->{textcolor});
			} elsif (ref($t) eq 'I') {
			       $p->{txt}->font($p->{dfonti},10);
			       $p->{txt}->fillcolor($p->{textcolor});
			} elsif (ref($t) eq 'L') {
			       $p->{txt}->font($p->{dfont},10);
			       $p->{txt}->fillcolor('darkred');
			} else {
			       $p->{txt}->font($p->{dfont},10);
			       $p->{txt}->fillcolor($p->{textcolor});
			}
			print "\nx=$p->{x},y=$p->{y},l=$p->{left},i=$p->{idt},t='$text'\n";
			($p->{idt},$p->{y},@ovl)=$p->{txt}->paragraph(
				$text,
				-x => $p->{left},
				-y => $p->{y},
				-h => $p->{y}-$p->{bot},
				-w => $p->{width},
				-lead => 10,
				-flindent => $p->{idt},
			);
			print " -> x=$p->{x},y=$p->{y},i=$p->{idt}\n";
			$text=join(' ',@ovl);
			$first=0 if(scalar @ovl);
		}
	}
	$p->{idt}=0;
	$p->{x}=$p->{left};
	$p->{wasbreak}=0;
}

sub interpolate {
    my($self, $text, $line_num) = @_;
    my %parse_opts = ( -expand_seq => 'interior_sequence' );
    my $ptree = $self->parse_text( \%parse_opts, $text, $line_num );
    return($ptree->children());
}
   sub interior_sequence {
       my ($parser, $seq_command, $seq_argument) = @_;
       my $t;
       if($seq_command eq 'E') {
	       if($seq_argument eq 'lt') {
			$t='<';
		} elsif($seq_argument eq 'gt') {
			$t='>';
		} elsif($seq_argument eq 'sol') {
			$t='/';
		} elsif($seq_argument eq 'verbar') {
			$t='|';
		} elsif($seq_argument=~/^\d+$/) {
			$t=chr($seq_argument);
		} else {
			$t=$seq_argument;
		}
	} else {
	       $t=\$seq_argument;
	       bless $t, $seq_command;
	}
	return $t;
   }

sub interpolate_verb {
    my($self, $text, $line_num) = @_;
    my %parse_opts = ( -expand_seq => 'interior_sequence_verb' );
    my $ptree = $self->parse_text( \%parse_opts, $text, $line_num );
    return(join ' ',$ptree->children());
}
   sub interior_sequence_verb {
       my ($parser, $seq_command, $seq_argument) = @_;

	return $seq_argument;
   }

package main;

use Getopt::Std;

getopts('d:m:b:t:i:o:h',\%opts);

$opts{h}=1 unless($opts{i} || defined $ARGV[0]);

print <<'EOT' if($opts{h});
pod_to_html [options] infile [outfile]

where options are:

	-i file		inputfile
	-o file		outputfile

	-h		this help

EOT

exit(0) if($opts{h});

$parser = new MyParser();

($infile,$outfile)=@ARGV;

$infile=$opts{i} if(defined($opts{i}));
$outfile=$opts{o} if(defined($opts{o}));

$parser->parse_from_file($infile,$outfile);
$parser->pdfsave($outfile);

__END__
