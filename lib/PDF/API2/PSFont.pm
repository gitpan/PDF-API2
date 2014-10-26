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
#	PDF::API2::PSFont
#
#=======================================================================
package PDF::API2::PSFont;
use strict;
use PDF::API2::Util;
use PDF::API2::Font;
use Text::PDF::Utils;
use Text::PDF::AFont;

use vars qw(@ISA);
@ISA = qw( Text::PDF::AFont PDF::API2::Font );

=head2 PDF::API2::PSFont

Subclassed from Text::PDF::AFont and PDF::API2::Font.

=item $font = PDF::API2::PSFont->new @parameters

Returns a adobe type1 font object (called from $pdf->psfont).

=cut

sub new {
	my ($class, @para) = @_;
	my ($self) = {};

	$class = ref $class if ref $class;
	$self = $class->SUPER::new(@para);

	$self->{' apiname'}=$para[3];
	$self->{' apipdf'}=$para[0];

	return($self);
}

sub outobjdeep {
	my ($self, @opts) = @_;
	foreach my $k (qw/ api apipdf /) {
		$self->{" $k"}=undef;
		delete($self->{" $k"});
	}
	$self->SUPER::outobjdeep(@opts);
}


1;

__END__

=head1 AUTHOR

alfred reibenschuh

=cut
