#!/usr/local/bin/perl

package MyParser;

use Pod::Parser;
@ISA = qw( Pod::Parser );

sub new {
	my ($class)=@_;
	my $self=$class->SUPER::new;
	$self->{hc}="#0050B2";
	$self->{ic}="#B25000";
	return($self);
}

sub begin_pod {
	my ($p)=@_;
	my $fh = $p->output_handle();
	print $fh <<'EOT';
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<HTML>
	<HEAD>
		<TITLE></TITLE>
		<META NAME="Generator" CONTENT="pdf_to_html">
	</HEAD>
<BODY
	BGCOLOR="#FFFFFF"
	TEXT="#000000"
	LINK="#0000FF"
	VLINK="#808000"
	ALINK="#FF00FF"
>
EOT
}

sub end_pod {
	my ($p)=@_;
	my $fh = $p->output_handle();
	print $fh <<'EOT';
</BODY>
</HTML>
EOT
}

sub command {
	my ($p, $command, $paragraph, $line_num) = @_;
	my $txt = $p->interpolate($paragraph, $line_num);
	my $fh = $p->output_handle();
	if(($x)=$command=~/head(\d)/i){
		$txt=qq|<H$x><FONT FACE="Verdana, Arial" COLOR="$p->{hc}">$txt</FONT></H$x>|;
	} elsif ($command eq 'item') {
		$txt=qq|</TD></TR><TR><TD> &nbsp; &nbsp; &nbsp; &nbsp; </TD></TR><TR><TD COLSPAN="2"><FONT FACE="Verdana, Arial" COLOR="$p->{ic}" SIZE="3"><B>$txt</B></FONT></TD></TR><TR><TD>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</TD><TD>|;
	} elsif($command=~/^over/i){
		$txt='<TABLE CELLSPACING="0" CELLPADDING="0" BORDER="0"><TR><TD>';
	} elsif($command=~/^back/i){
		$txt='</TD></TR></TABLE>';
	}
	print $fh qq|$txt\n|;
}

sub verbatim {
	my ($p, $paragraph, $line_num) = @_;
	my $txt = $p->interpolate($paragraph, $line_num);
	my $fh = $p->output_handle();
	print $fh qq|<TABLE WIDTH="100%" CELLSPACING="0" CELLPADDING="0" BORDER="0"><TR><TD BGCOLOR="#DDDDDD"><PRE><FONT SIZE="2">\n$txt</FONT></PRE></TD></TR></TABLE>\n|;
}

sub textblock {
	my ($p, $paragraph, $line_num) = @_;
	my $txt = $p->interpolate($paragraph, $line_num);
	my $fh = $p->output_handle();
	print $fh qq|<P><FONT FACE="Verdana, Arial" SIZE="3">$txt</FONT></P>\n|;
}

sub interior_sequence {
	my ($parser, $seq_command, $seq_argument) = @_;
	my $t;
	if($seq_command eq 'E') {
		if($seq_argument eq 'sol') {
			$t='/';
		} elsif($seq_argument eq 'verbar') {
			$t='|';
		} elsif($seq_argument=~/^\d+$/) {
			$t="&#$seq_argument;";
		} else {
			$t="&$seq_argument;";
		}
	} elsif($seq_command eq 'B') {
		$t="<B>$seq_argument</B>";
	} elsif($seq_command eq 'I') {
		$t="<I>$seq_argument</I>";
	} elsif($seq_command eq 'S') {
		$t="<NOBR>$seq_argument</NOBR>";
	} elsif($seq_command eq 'C') {
		$t="<CODE>$seq_argument</CODE>";
	} elsif($seq_command eq 'F') {
		$t="<PRE>$seq_argument</PRE>";
	} elsif($seq_command eq 'X') {
		$t=qq|<A NAME="$seq_argument">&nbsp;</A>|;
	} elsif($seq_command eq 'L') {
		if($seq_argument=~/^([^\|]+)\|(.+)$/) {
			$t=qq|<A HREF="$2">$1</A>|;
		} else {
			$t=qq|<A HREF="$seq_argument">$seq_argument</A>|;
		}
	}
	return $t;
}

package main;

use Getopt::Std;

getopts('i:o:h',\%opts);

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

__END__
