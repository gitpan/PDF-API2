#!perl
#=======================================================================
#    ____  ____  _____              _    ____ ___   ____
#   |  _ \|  _ \|  ___|  _   _     / \  |  _ \_ _| |___ \
#   | |_) | | | | |_    (_) (_)   / _ \ | |_) | |    __) |
#   |  __/| |_| |  _|    _   _   / ___ \|  __/| |   / __/
#   |_|   |____/|_|     (_) (_) /_/   \_\_|  |___| |_____|
#
#   A Perl Module Chain to faciliate the Creation and Modification
#   of High-Quality "Portable Document Format (PDF)" Files.
#
#   Copyright 1999-2004 Alfred Reibenschuh <areibens@cpan.org>.
#
#=======================================================================
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Lesser General Public
#   License as published by the Free Software Foundation; either
#   version 2 of the License, or (at your option) any later version.
#
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public
#   License along with this library; if not, write to the
#   Free Software Foundation, Inc., 59 Temple Place - Suite 330,
#   Boston, MA 02111-1307, USA.
#
#   $Id: Makefile.PL,v 1.15 2004/06/15 09:00:00 fredo Exp $
#
#=======================================================================

require 5.008;

use ExtUtils::MakeMaker;

my $versionfile = "lib/PDF/API2.pm";

print STDERR <<'EOT';
      _   _    ____  ____  _____      _    ____ ___   ____
  _  |_|_|_|  |  _ \|  _ \|  ___|    / \  |  _ \_ _| |___ \
 |_| _|_||_|  | |_) | | | | |_      / _ \ | |_) | |    __) |
 _  |_||_|_|  |  __/| |_| |  _|    / ___ \|  __/| |   / __/
|_|  |_|_|_|  |_|   |____/|_|     /_/   \_\_|  |___| |_____|
EOT

eval { require $versionfile; };

print <<EOT;
                                        VERSION $PDF::API2::VERSION
EOT

WriteMakefile (
    NAME         =>  "PDF::API2",
    VERSION      =>  $PDF::API2::VERSION,
    AUTHOR       =>  "areibens\@cpan.org",
    ABSTRACT     =>  "TheNextGen PDF Create/Modify API",
    dist         =>  {
        ZIP         =>  "zip ",
        ZIPFLAGS    =>  " -v -o -r -9 ",
        COMPRESS    =>  "gzip -9 -f ",
    },
    MAN1PODS     =>  {},
    MAN3PODS     =>  {},
    PREREQ_PM    =>  {
                    'Compress::Zlib'    => 1.0,
                },
);


exit;

__END__
         
# $Log: Makefile.PL,v $
# Revision 1.15  2004/06/15 09:00:00  fredo
# changed versioning to API.pm
#
# Revision 1.14  2004/01/22 14:19:31  fredo
# final versioning update for 0.40_17 and beyond
#
# Revision 1.13  2004/01/21 23:21:11  fredo
# updated logo string
#
# Revision 1.12  2004/01/21 12:44:11  fredo
# fixed MakeMaker VERSION_FROM parameter
#
# Revision 1.11  2004/01/21 12:29:06  fredo
# moved release versioning to PDF::API2::Version
#
# Revision 1.10  2004/01/19 14:16:02  fredo
# update for 0.40_16
#
# Revision 1.9  2004/01/14 18:25:12  fredo
# release update 0.40_15
#
# Revision 1.8  2004/01/12 13:52:17  fredo
# update for 0.40_14
#
# Revision 1.7  2003/12/08 21:37:46  Administrator
# updated  copyright date
#
# Revision 1.6  2003/12/08 11:39:47  Administrator
# updated for req. perl >= 5.8 of 0.40_13 release
#
# Revision 1.5  2003/11/30 17:04:08  Administrator
# merged into default
#
