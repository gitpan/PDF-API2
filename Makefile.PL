#!perl

BEGIN {
	use ExtUtils::MakeMaker;
	use File::Find;
	use File::stat;

	%opts=@ARGV;

	if($opts{-version}) {
		open(INF,">version.p");
		print INF <<"EOT";
# version file, generated from Makefile.PL

\$version="$opts{-version}";
1;

EOT
		close(INF);	

		find( sub {
			my $file=$_;
			unlink($file) && return if($file=~/\.bak$/);
			return if($file!~/\.pm$/);
			open(INF,$file);
			@lines=<INF>;
			$l=join('',@lines);
			close(INF);
			$l=~/\$Revisioning:\s+([^\s]+)\s+/gm;
			if($1) {
				$l=~s/(\$Revisioning:\s+)[^\s]+(\s+)/$1$opts{-version}$2/gm;
				print "fixing version in file '$file'\n";
				open(INF,">$file");
				print INF $l;
				close(INF);
				print "fixing versioning in $file.\n";
			}
		}, './lib/PDF');

	}
}

if($opts{-docs}) {
	system(q# for x in `grep '.pm$' MANIFEST`; do y="`echo $x |tr '/' '_'|sed 's/^lib_//g'`"; ./contrib/pod_to_html.pl $x >docs/$y.html; done #);
}

require 'version.p';

@ver=split(/\./,$version);

$tag='_'.(defined($opts{-tag}) ? $opts{-tag} : 'dev') if(defined $opts{-tag});

print <<'EOT';
	 ____  ____  _____              _    ____ ___   ____
	|  _ \|  _ \|  ___|  _   _     / \  |  _ \_ _| |___ \
	| |_) | | | | |_    (_) (_)   / _ \ | |_) | |    __) |
	|  __/| |_| |  _|    _   _   / ___ \|  __/| |   / __/
	|_|   |____/|_|     (_) (_) /_/   \_\_|  |___| |_____|
EOT
print <<"EOT";
						($version$tag)
EOT



WriteMakefile (
	NAME		=>	"PDF::API2",
	VERSION		=>	"$version$tag",
	AUTHOR		=>	"areibens\@cpan.org",
	ABSTRACT	=>	"TNG PDF Generation API",
	dist		=>	{
		ZIP		=>	"zip ",
		ZIPFLAGS	=>	" -v -o -r -9 ",
		COMPRESS	=>	"gzip -9 -f ",
	},
	MAN1PODS	=>	{},
	MAN3PODS	=>	{},
	PREREQ_PM	=>	{
					'Compress::Zlib'	=> 1.03,
				},
	BINARY_LOCATION	=>  "PDF-API2-$version$tag-ppd.tar.gz",
);

sub MY::postamble
{
    my $self = shift;
    return <<"EOT";

ppdist: all ppd pm_to_blib
	tar zcvf PDF-API2-$version$tag-ppd.tar.gz blib
	\$(MV) PDF-API2.ppd PDF-API2-$version$tag.ppd

distme: all dist ppd ppdist

EOT
}

print "anything else ? NO.\n";
exit;

__END__

Date:  Mon, 15 Jul 2002 23:55:08 +0200
To: alfredreibenschuh@yahoo.com
From: "HERMIER Christophe" <proxima-cd@pelnet.com> | This is Spam | Add to Address Book
Subject: [PDF::API2] bug in PDF::API2::Text::paragraph

Hello,

I found out a bug in PDF::API2::Text::paragraph concerning the repartition 
of space in a line :
There is one space less than the number of words in a line.

Here is the fix :

4177c4177
< $self->wordspace(($wd-$idt-$l)/(scalar @line)) if(defined 
$txt[0] && scalar @line>0);
---
 > $self->wordspace(($wd-$idt-$l)/((scalar @line)-1)) 
if(defined $txt[0] && scalar @line>0);


By the way, I am working on a better version using a hyphenator object (ie 
:  TeX::Hyphen).
I plan to use the object without creating a dependency in the PDF::API2 
module : the object just has to "->can ( )" the right function.
That way other hyphenation objects could be used if they exist (there could 
be a "crude_hyphenator" that cut a word anywhere to act as a minimalist 
example).

If you're interested, I'll send it to put it in the PDF:API2 module.

bye : christophe.


--
Proxima CD SARL
40 rue damrémont
75018 PARIS

