#!perl

use ExtUtils::MakeMaker;

require 'version.p';

print "Current version is: $version \n";

WriteMakefile (
	NAME		=>	"PDF::API2",
	VERSION		=>	"$version".'_beta',
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
);

sub MY::postamble
{
    my $self = shift;
    return <<'EOT';

htmldoc:
	perl pod3html -i lib/PDF/API2.pm -o docs/pdf-api2.pm.html

new-version: version.p
	perl -e 'require "version.p"; @v=split(/\./,$$version); $$v[0]++; print "\$$version=\"".join(".",@v)."\";1;\n";' >version.pp
	mv version.pp version.p
	perl Makefile.PL

new-release: version.p
	perl -e 'require "version.p"; @v=split(/\./,$$version); $$v[1]++; print "\$$version=\"".join(".",@v)."\";1;\n";' >version.pp
	mv version.pp version.p
	perl Makefile.PL

new-level: version.p
	perl -e 'require "version.p"; @v=split(/\./,$$version); $$v[2]++; print "\$$version=\"".join(".",@v)."\";1;\n";' >version.pp
	mv version.pp version.p
	perl Makefile.PL

version.p:
	perl -e 'print "\$version=\"0.0.1\";\n1;\n";' >version.p

EOT
}

print "anything else ? NO.\n";
exit;

__END__

