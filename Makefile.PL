#!perl

use ExtUtils::MakeMaker;
use File::Find;
use File::stat;

find( sub {
	my $file=$_;
	return if($file!~/\.pm$/);
	my $st=stat($file);
	my ($ss,$mm,$hh,$dd,$mn,$yy)=localtime($st->mtime);
	my $tstr=sprintf('%04d%02d%02d.%02d%02d%02d',1900+$yy,$mn+1,$dd,$hh,$mm,$ss);
	my $touch=sprintf('%04d%02d%02d%02d%02d.%02d',1900+$yy,$mn+1,$dd,$hh,$mm,$ss);
	open(INF,$file);
	@lines=<INF>;
	$l=join('',@lines);
	close(INF);
	$l=~/\$Revisioning:\s+([^\s]+)\s+/gm;
	if($1 && ($tstr ne $1)) {
		$l=~s/(\$Revisioning:\s+)[^\s]+(\s+)/$1$tstr$2/gm;
		open(INF,">$file");
		print INF $l;
		close(INF);
		print `touch -m -t $touch $file`;
		print "fixing versioning in $file.\n";
	}
}, './lib/PDF');

require 'version.p';

print "Current version is: $version \n";

@ver=split(/\./,$version);

$tag='_dev';

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

new-version: version.p
	perl -e 'require "version.p"; @v=split(/\./,$$version); $$v[0]++;$$v[1]=0;$$v[2]=0;$$v[3]=0; print "\$$version=\"".join(".",@v)."\";1;\n";' >version.pp
	mv version.pp version.p
	perl Makefile.PL

new-release: version.p
	perl -e 'require "version.p"; @v=split(/\./,$$version); $$v[1]++;$$v[2]=0;$$v[3]=0; print "\$$version=\"".join(".",@v)."\";1;\n";' >version.pp
	mv version.pp version.p
	perl Makefile.PL

new-level: version.p
	perl -e 'require "version.p"; @v=split(/\./,$$version); $$v[2]++;$$v[3]=0; print "\$$version=\"".join(".",@v)."\";1;\n";' >version.pp
	mv version.pp version.p
	perl Makefile.PL

new-fix: version.p
	perl -e 'require "version.p"; @v=split(/\./,$$version); $$v[3]++; print "\$$version=\"".join(".",@v)."\";1;\n";' >version.pp
	mv version.pp version.p
	perl Makefile.PL

new: version.p
	perl -e 'require "version.p"; @v=split(/\./,$$version); $$v[2]++; if($$v[2]==100) { $$v[1]++;$$v[2]=0;$$v[3]=0; } print "\$$version=\"".join(".",@v)."\";1;\n";' >version.pp
	mv version.pp version.p
	perl Makefile.PL

version.p:
	perl -e 'print "\$version=\"0.0.1.0\";\n1;\n";' >version.p

EOT
}

print "anything else ? NO.\n";
exit;

__END__

