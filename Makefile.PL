#!perl

use ExtUtils::MakeMaker;

require 'version.perl';

$versionfile='version.perl';

print "Current version is: ".$version->{'v_short'}." on a ";

#if($^O eq 'MSWin32') {
#	use Config;
#	print $Config{'archname'}."\n";
#} else {
#	`cp gif/Makefile.PL.org gif/Makefile.PL`;
#	`cp gif/giflib/Makefile.PL.org gif/giflib/Makefile.PL`;
#	print `./shtool guessos`."\n";
#}
        
WriteMakefile (
	NAME		=>	"PDF::API2",
	VERSION		=>	"$version->{'v_short'}_unstable",
	AUTHOR		=>	"areibens\@cpan.org",
	ABSTRACT	=>	"TNG PDF Generation API",
	dist		=>	{
		ZIP		=>	"zip ",
		ZIPFLAGS	=>	" -v -o -r -9 ",
		COMPRESS	=>	"gzip -9 -f ",
	},
	PREREQ_PM	=>	{
					'Compress::Zlib'	=> 1.03,
				},
);

sub MY::postamble
{
    my $self = shift;
    return <<"EOT";

htmldoc:
	perl pod3html -i lib/PDF/API2.pm -o docs/pdf-api2.pm.html

new-version: shtool
	./shtool version -l perl -n "PDF::API2" -i v $versionfile
	perl Makefile.PL

new-release: shtool
	./shtool version -l perl -n "PDF::API2" -i r $versionfile
	perl Makefile.PL

new-level: shtool
	./shtool version -l perl -n "PDF::API2" -i l $versionfile
	perl Makefile.PL

custom-version: shtool
	./shtool version -l perl -n "PDF::API2" -s \$(MODULEVERSION) $versionfile
	perl Makefile.PL


EOT
}

print "anything else ? NO.\n";
exit;

__END__

