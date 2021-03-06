
# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v5.013.
use strict;
use warnings;

use 5.008001;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Facilitates the creation and modification of PDF files",
  "AUTHOR" => "Steve Simms <steve\@deefs.net>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "PDF-API2",
  "EXE_FILES" => [],
  "LICENSE" => "lgpl",
  "NAME" => "PDF::API2",
  "PREREQ_PM" => {
    "Compress::Zlib" => "1.0",
    "Font::TTF" => 0
  },
  "TEST_REQUIRES" => {},
  "VERSION" => "2.023",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Compress::Zlib" => "1.0",
  "Font::TTF" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



