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
#   $Id: Outlines.pm,v 1.4 2003/12/08 13:05:19 Administrator Exp $
#
#=======================================================================

package PDF::API2::Outlines;

BEGIN {

    use strict;
    use vars qw(@ISA $VERSION);

    use PDF::API2::Outline;
    use PDF::API2::Util;
    use PDF::API2::Basic::PDF::Utils;

    @ISA = qw(PDF::API2::Outline);

    ( $VERSION ) = '$Revision: 1.4 $' =~ /Revision: (\S+)\s/; # $Date: 2003/12/08 13:05:19 $

}

=head1 $otls = PDF::API2::Outlines->new $api

Returns a new outlines object (called from $pdf->outlines).

=cut

sub new {
    my ($class,$api)=@_;
    my $self = $class->SUPER::new($api);
    $self->{Type}=PDFName('Outlines');

    return($self);
}

1;

__END__

=head1 AUTHOR

alfred reibenschuh

=head1 HISTORY

    $Log: Outlines.pm,v $
    Revision 1.4  2003/12/08 13:05:19  Administrator
    corrected to proper licencing statement

    Revision 1.3  2003/11/30 17:16:39  Administrator
    merged into default


=cut
