#==================================================================
#	Text::PDF::Image
#==================================================================
package Text::PDF::Image;

use strict;
use Text::PDF::Dict;
use Text::PDF::Utils;
use vars qw(@ISA);

@ISA = qw(Text::PDF::Dict);

=head2 Text::PDF::Image

=item $img = Text::PDF::Image->new $pdf, $name

Returns a new image object.

=cut

sub new {
	my ($class,$pdf,$name)=@_;
	my $self = $class->SUPER::new();

	$self->{Type}=PDFName('XObject');
	$self->{Subtype}=PDFName('Image');
	$self->{Name}=PDFName($name) if(defined $name);
	
	$pdf->new_obj($self);
	
	return($self);
}

=item $wd = $img->width

=cut

sub width {
	my $self = shift @_;
	my $x=shift @_;
	$self->{Width}=PDFNum($x) if(defined $x);
	return($self->{Width}->val);
}

=item $ht = $img->height

=cut

sub height {
	my $self = shift @_;
	my $x=shift @_;
	$self->{Height}=PDFNum($x) if(defined $x);
	return($self->{Height}->val);
}

=item $img->smask $smaskobj

=cut

sub smask {
	my $self = shift @_;
	my $maskobj = shift @_;
	$self->{SMask}=$maskobj;
	return $self;
}

=item $img->mask @maskcolorange

=cut

sub mask {
	my $self = shift @_;
	$self->{Mask}=PDFArray(map { PDFNum($_) } @_);
	return $self;
}

=item $img->imask $maskobj

=cut

sub imask {
	my $self = shift @_;
	$self->{Mask}=shift @_;
	return $self;
}

=item $img->colorspace $csobj

=cut

sub colorspace {
	my $self = shift @_;
	my $obj = shift @_;
	$self->{'ColorSpace'}=ref $obj ? $obj : PDFName($obj) ;
	return $self;
}

=item $img->filters @filternames

=cut

sub filters {
	my $self = shift @_;
	$self->{Filter}=PDFArray(map { PDFName($_) } @_);
	return $self;
}

=item $img->bpc $num

=cut

sub bpc {
	my $self = shift @_;
	$self->{BitsPerComponent}=PDFNum(shift @_);
	return $self;
}

1;