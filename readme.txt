
	 ____  ____  _____              _    ____ ___   ____
	|  _ \|  _ \|  ___|  _   _     / \  |  _ \_ _| |___ \
	| |_) | | | | |_    (_) (_)   / _ \ | |_) | |    __) |
	|  __/| |_| |  _|    _   _   / ___ \|  __/| |   / __/
	|_|   |____/|_|     (_) (_) /_/   \_\_|  |___| |_____|


There seem to be a growing plethora of Perl modules for creating and
manipulating PDF files. 

This module is 'The Next Generation' of Text::PDF::API which initially 
provided a nice API around the Text::PDF::* modules created by Martin Hosken.


FEATURES

	.  Works with more than one PDF file open at once
	.  It presents a object-oriented API to the user
	.  Supports the 14 base PDF Core Fonts 
	.  Supports the Microsoft Webfonts via an optional module
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
	Text::PDF-0.20	 - Low-level Pdf-Object Handling
	Font::TTF-0.28	 - Truetype Handling


NOTES

For Type1 font support to work correctly you have to have a postscript font file,
either binary (pfb) or ascii (pfa) format and an adobe font metrics file (afm).


Thanks.


INSTALLATION (on Unix)

Installation is as per the standard module installation approach:

	perl Makefile.PL
	make
	make install


INSTALLATION (on Windows: ActiveState Perl, or IndigoPerl, and NMAKE)

Another way to install as a traditional Perl module, using 
"perl Makefile.PL" and Microsoft's NMAKE, included with 
MS DevStudio. Here's what one user has to say on this subject:

    nmake works nicely, and the installation process looks the same 
    as on other platforms.

    My understanding is that nmake.exe is available for free from
    Redmond. In fact I downloaded it just a few minutes ago, 
    following the suggestion found on the IndigoPerl home page:

      Installing CPAN modules requires that you have Microsoft
      DevStudio or nmake.exe installed.  If you are installing 
      modules that contain xs files, then you need DevStudio,
      otherwise you only need nmake.exe.  You can download 
      nmake from [the url below].

      Run the self-extracting exe and copy nmake.exe to the perl\bin
      directory.

[the URL is:
http://download.microsoft.com/download/vc15/Patch/1.52/W95/EN-US/Nmake15.exe
]

    Nmake15.exe expands to nmake.exe (64K) and Nmake.Err (5k) - a text
    file.  I copied both to C:\perl\bin, then renamed nmake.exe to
    make.exe and now I can pretend to be on Unix:

        H:\devperl\some-module>perl Makefile.PL
        Writing Makefile for some-module

        H:\devperl\some-module>make all test

        H:\devperl\some-module>make install
        ...


CONTACT

There is a mailing-list available:

Post message:  perl-text-pdf-modules@yahoogroups.com
   Subscribe:  perl-text-pdf-modules-subscribe@yahoogroups.com
 Unsubscribe:  perl-text-pdf-modules-unsubscribe@yahoogroups.com
     Archive:  http://groups.yahoo.com/group/perl-text-pdf-modules
  List owner:  perl-text-pdf-modules-owner@yahoogroups.com


DOWNLOAD SITE

    Primary:  http://pdfapi2.sf.net/
Alternative:  http://penguin.at0.net/~fredo/files/
       CPAN:  ftp://ftp.funet.fi/pub/CPAN/authors/id/A/AR/AREIBENS/
     Linked:  http://freshmeat.net/projects/pdf-api2/


COPYRIGHTS & LICENSING

This module is copyrighted by Alfred Reibenschuh and can be used under
perl's "Artistic License" which has been included in this archive.