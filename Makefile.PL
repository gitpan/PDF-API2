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
				$t=scalar localtime();
				$l=~s/(\$Revisioning:\s+)[^\s]+(\s*)[^\$]*\s+(\$)/$1$opts{-version}$2 $t $3/gm;
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
  please look at http://www.penguin.at0.net/~fredo/files/
  for examples and contrib.
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

ecddist:
	tar zcvf examples+contrib+docs-$version$tag.tar.gz `cat MANIFEST.examples`

EOT
}

print "anything else ? NO.\n";
exit;

__END__

