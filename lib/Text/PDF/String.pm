package Text::PDF::String;

=head1 NAME

Text::PDF::String - PDF String type objects and superclass for simple objects
that are basically stringlike (Number, Name, etc.)

=head1 METHODS

=cut

use strict;
use vars qw(@ISA %trans %out_trans);
no warnings qw(uninitialized);

use Text::PDF::Objind;
@ISA = qw(Text::PDF::Objind);

%trans = (
    "n" => "\n",
    "r" => "\r",
    "t" => "\t",
    "b" => "\b",
    "f" => "\f",
    "\\" => "\\",
    "(" => "(",
    ")" => ")"
        );

%out_trans = (
    "\n" => "n",
    "\r" => "r",
    "\t" => "t",
    "\b" => "b",
    "\f" => "f",
    "\\" => "\\",
    "(" => "(",
    ")" => ")"
             );


=head2 Text::PDF::String->from_pdf($string)

Creates a new string object (not a full object yet) from a given string.
The string is parsed according to input criteria with escaping working.

=cut

sub from_pdf
{
    my ($class, $str) = @_;
    my ($self) = {};

    bless $self, $class;
    $self->{'val'} = $self->convert($str);
    $self->{' realised'} = 1;
    return $self;
}


=head2 Text::PDF::String->new($string, %opts)

Creates a new string object (not a full object yet) from a given string.
The string is parsed according to input criteria with escaping working.

=cut

sub new
{
    my ($class, $str, %opts) = @_;
    my ($self) = {};

    bless $self, $class;
    $self->{'val'} = $str;
    $self->{' realised'} = 1;
    return $self;
}


=head2 $s->convert($str, %opts)

Returns $str converted as per criteria for input from PDF file

=cut

sub convert
{
    my ($self, $str, %opts) = @_;

    $str =~ s/\\([nrtbf\\()])/$trans{$1}/ogi;
    $str =~ s/\\([0-7]+)/oct($1)/oegi;
    1 while $str =~ s/\<([0-9a-f]{2})/hex($1)."\<"/oige;
    $str =~ s/\<([0-9a-f])\>/hex($1 . "0")/oige;
    $str =~ s/\<\>//og;
    return $str;
}


=head2 $s->val

Returns the value of this string (the string itself).

=cut

sub val
{ $_[0]->{'val'}; }


=head2 $->as_pdf

Returns the string formatted for output as PDF

=cut

sub as_pdf
{
    my ($self,$str, %opts) = @_;
    $str = $str || $self->{'val'};
    
    if($opts{-hexit}) {
        $str =~ s/(.)/sprintf("%02x", ord($1))/oge;
        return "<$str>";
    } elsif($self->{' nohex'}) {
        $str =~ s/([\n\r\t\b\f\\()])/\\$out_trans{$1}/ogi;
        return "($str)";
    } elsif($str =~ m/[^\n\r\t\b\f\040-\176\200-\377]/oi) {
        $str =~ s/(.)/sprintf("%02x", ord($1))/oge;
        return "<$str>";
    } else {
        $str =~ s/([\n\r\t\b\f\\()])/\\$out_trans{$1}/ogi;
        return "($str)";
    }
}

=head2 $s->outobjdeep

Outputs the string in PDF format, complete with necessary conversions

=cut

sub outobjdeep
{
    my ($self, $fh, $pdf, %opts) = @_;

    if($self->{' nohex'}) {
	$fh->print($self->as_pdf($self->val));
    } elsif($self->{' ashex'}) {
 	$fh->print($self->as_pdf($self->val, -hexit => 1));
    } else {
	$fh->print($self->as_pdf);
    }
}

