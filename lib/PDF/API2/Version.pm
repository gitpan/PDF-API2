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
#   $Id: Version.pm,v 1.3 2004/04/04 23:52:08 fredo Exp $
#
#=======================================================================

package PDF::API2::Version;

BEGIN {

    use vars qw( $VERSION );

    ( $VERSION ) = '0.40_18';

}


=head1 NAME

PDF::API2::Version - Helper Modules for Release Versioning

=cut

1;

__END__

=back

=head1 AUTHOR

alfred reibenschuh

=head1 HISTORY

    $Log: Version.pm,v $
    Revision 1.3  2004/04/04 23:52:08  fredo
    updated for release 0.40_18

    Revision 1.2  2004/01/21 13:24:21  fredo
    fixed errorneous use/require behaviour

    Revision 1.1  2004/01/21 12:29:06  fredo
    moved release versioning to PDF::API2::Version


=cut
