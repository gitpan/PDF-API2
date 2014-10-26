package PDF::API2::PDF::Utils;

=head1 NAME

PDF::API2::PDF::Utils - Utility functions for PDF library

=head1 DESCRIPTION

A set of utility functions to save the fingers of the PDF library users!

=head1 FUNCTIONS

=cut

use strict;

use PDF::API2::PDF::Array;
use PDF::API2::PDF::Bool;
use PDF::API2::PDF::Dict;
use PDF::API2::PDF::Name;
use PDF::API2::PDF::Number;
use PDF::API2::PDF::String;

use Exporter;
use vars qw(@EXPORT @ISA);
@ISA = qw(Exporter);
@EXPORT = qw(PDFBool PDFArray PDFDict PDFName PDFNum PDFStr
             asPDFBool asPDFName asPDFNum asPDFStr);
# no warnings qw(uninitialized);


=head2 PDFBool

Creates a Bool via PDF::API2::PDF::Bool->new

=cut

sub PDFBool
{ PDF::API2::PDF::Bool->new(@_); }


=head2 PDFArray

Creates an array via PDF::API2::PDF::Array->new

=cut

sub PDFArray
{ PDF::API2::PDF::Array->new(@_); }


=head2 PDFDict

Creates a dict via PDF::API2::PDF::Dict->new

=cut

sub PDFDict
{ PDF::API2::PDF::Dict->new(@_); }


=head2 PDFName

Creates a name via PDF::API2::PDF::Name->new

=cut

sub PDFName
{ PDF::API2::PDF::Name->new(@_); }


=head2 PDFNum

Creates a number via PDF::API2::PDF::Number->new

=cut

sub PDFNum
{ PDF::API2::PDF::Number->new(@_); }


=head2 PDFStr

Creates a string via PDF::API2::PDF::String->new

=cut

sub PDFStr
{ PDF::API2::PDF::String->new(@_); }


=head2 asPDFBool

Returns a boolean value in PDF output form

=cut

sub asPDFBool
{ PDF::API2::PDF::Bool->new(@_)->as_pdf; }


=head2 asPDFStr

Returns a string in PDF output form (including () or <>)

=cut

sub asPDFStr
{ PDF::API2::PDF::String->new(@_)->as_pdf; }


=head2 asPDFName

Returns a Name in PDF Output form (including /)

=cut

sub asPDFName
{ PDF::API2::PDF::Name->new(@_)->as_pdf (@_); }


=head2 asPDFNum

Returns a number in PDF output form

=cut

sub asPDFNum
{ $_[0]; }          # no translation needed


=head2 unpacku($str)

Returns a list of unicode values for the given UTF8 string

=cut

sub unpacku
{
    my ($str) = @_;
    my (@res);

#    return (unpack("U*", $str)) if ($^V && $^V ge v5.6.0);
    return (unpack("U*", $str)) if ($] >= 5.006);       # so much for $^V!
    
    $str = "$str";              # copy $str
    while (length($str))        # Thanks to Gisle Aas for some of his old code
    {
        $str =~ s/^[\x80-\xBF]+//o;
        if ($str =~ s/^([\x00-\x7F]+)//o)
        { push(@res, unpack("C*", $1)); }
        elsif ($str =~ s/^([\xC0-\xDF])([\x80-\xBF])//o)
        { push(@res, ((ord($1) & 0x1F) << 6) | (ord($2) & 0x3F)); }
        elsif ($str =~ s/^([\0xE0-\xEF])([\x80-\xBF])([\x80-\xBF])//o)
        { push(@res, ((ord($1) & 0x0F) << 12)
                          | ((ord($2) & 0x3F) << 6)
                          | (ord($3) & 0x3F)); }
        elsif ($str =~ s/^([\xF0-\xF7])([\x80-\xBF])([\x80-\xBF])([\x80-\xBF])//o)
        {
            my ($b1, $b2, $b3, $b4) = (ord($1), ord($2), ord($3), ord($4));
            push(@res, ((($b1 & 0x07) << 8) | (($b2 & 0x3F) << 2)
                            | (($b3 & 0x30) >> 4)) + 0xD600);  # account for offset
            push(@res, ((($b3 & 0x0F) << 6) | ($b4 & 0x3F)) + 0xDC00);
        }
        elsif ($str =~ s/^[\xF8-\xFF][\x80-\xBF]*//o)
        { }
    }
    @res;
}


1;

