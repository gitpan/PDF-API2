                            PDF::API2

There seem to be a growing plethora of Perl modules for creating and
manipulating PDF files. 

This module is 'The Next Generation' of Text::PDF::API which initially 
provided a nice API around the Text::PDF::* modules created by Martin Hosken.


FEATURES

	.  Works with more than one PDF file open at once
	.  It presents a object-oriented API to the user
	.  Supports the 14 base PDF Core Fonts 
	.  Supports TrueType fonts 
	.  Supports Adobe-Type1 Fonts (pfb/pfa/afm) 
	.  Supports native Embedding of bitmap images (jpeg,ppm,png)
	.  Supports modification of existing pdfs
		and import/cloning of pages


UN-FEATURES (which will one day be fixed)

	.  Documentation is currently rather sparse
	.  This is beta code in development which works 
	   for my apps, your milage may vary :)


REQUIREMENTS

This module set requires you to have installed the following other perl modules:

	Module		Required for
	------------------------------------------------------
	Compress::Zlib	 - Compression of PDF object streams
	Text::PDF-0.19	 - Low-level Pdf-Object Handling
	Font::TTF	 - Truetype Handling


NOTES

For Type1 font support to work correctly you have to have a postscript font file,
either binary (pfb) or ascii (pfa) format and an adobe font metrics file (afm).


Thanks.


INSTALLATION

Installation is as per the standard module installation approach:

	perl Makefile.PL
	make
	make install


CONTACT

There is a mailing-list available:

Post message:	perl-text-pdf-modules@yahoogroups.com
Subscribe:	perl-text-pdf-modules-subscribe@yahoogroups.com
Unsubscribe:	perl-text-pdf-modules-unsubscribe@yahoogroups.com
List owner:	perl-text-pdf-modules-owner@yahoogroups.com
URL to page:	http://groups.yahoo.com/group/perl-text-pdf-modules


DOWNLOAD SITE

 Primary:  http://www.penguin.at0.net/~fredo/files/
    CPAN:  ftp://ftp.funet.fi/pub/CPAN/authors/id/A/AR/AREIBENS/
  Linked:  http://freshmeat.net/projects/pdf-api2/


COPYRIGHTS & LICENSING

This module is copyrighted by Alfred Reibenschuh and can be used under
perl's "Artistic License" which has been included in this archive.