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
			return if($file!~/\.pm$/);
			open(INF,$file);
			@lines=<INF>;
			$l=join('',@lines);
			close(INF);
			$l=~/\$Revisioning:\s+([^\s]+)\s+/gm;
			if($1) {
				$l=~s/(\$Revisioning:\s+)[^\s]+(\s+)/$1$opts{-version}$2/gm;
				open(INF,">$file");
				print INF $l;
				close(INF);
				print "fixing versioning in $file.\n";
			}
		}, './lib/PDF');

	}
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
					'Text::PDF::File'	=> 0.19,
					'Font::TTF::Font'	=> 0.28,
				},
);

sub MY::postamble
{
    my $self = shift;
    return <<'EOT';

docs: install docs/pdf-api2.pm.html pod-pdf

docs/pdf-api2.pm.html: lib/PDF/API2.pm 
	perl pod3html -i $< -o $@

docs/pdf-api2.pm.pdf: lib/PDF/API2.pm 
	perl pod3pdf -i $< -o $@

pod-pdf: docs/*.pod
	for x in $?; do \
		perl pod3pdf -i $$x -o $$x.pdf ;\
	done

EOT
}

print "anything else ? NO.\n";
exit;

__END__

