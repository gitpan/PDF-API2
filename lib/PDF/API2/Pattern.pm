#=======================================================================
#	 ____  ____  _____              _    ____ ___   ____
#	|  _ \|  _ \|  ___|  _   _     / \  |  _ \_ _| |___ \
#	| |_) | | | | |_    (_) (_)   / _ \ | |_) | |    __) |
#	|  __/| |_| |  _|    _   _   / ___ \|  __/| |   / __/
#	|_|   |____/|_|     (_) (_) /_/   \_\_|  |___| |_____|
#
#	Copyright 1999-2001 Alfred Reibenschuh <areibens@cpan.org>.
#
#	This library is free software; you can redistribute it 
#	and/or modify it under the same terms as Perl itself.
#
#=======================================================================
#
#	PDF::API2::Pattern
#
#=======================================================================
package PDF::API2::Pattern;

use strict;
use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict);

use Text::PDF::Utils;
use Text::PDF::Dict;
use PDF::API2::Util;

=head2 PDF::API2::Pattern

Subclassed from Text::PDF::Dict.

=item $otls = PDF::API2::Pattern->new

Returns a new pattern object (called from $pdf->pattern).

=cut

sub new {
	my ($class,%opts)=@_;
	my $self = $class->SUPER::new;
	my $key='PTx'.pdfkey(%opts || 'pattern'.localtime() );

	$self->{' apiname'}=$key;
	$self->{Type}=PDFName('Pattern');

	return($self);
}

1;

__END__

=head1 AUTHOR

alfred reibenschuh

=cut
