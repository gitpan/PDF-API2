#!/usr/bin/perl
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
#   PERMISSION TO USE, COPY, MODIFY, AND DISTRIBUTE THIS FILE FOR
#   ANY PURPOSE WITH OR WITHOUT FEE IS HEREBY GRANTED, PROVIDED THAT
#   THE ABOVE COPYRIGHT NOTICE AND THIS PERMISSION NOTICE APPEAR IN ALL
#   COPIES.
#
#   THIS FILE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED
#   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#   MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#   IN NO EVENT SHALL THE AUTHORS AND COPYRIGHT HOLDERS AND THEIR
#   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
#   USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#   ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
#   OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
#   OF THE USE OF THIS FILE, EVEN IF ADVISED OF THE POSSIBILITY OF
#   SUCH DAMAGE.
#
#   $Id: 022corefunc.t,v 1.1 2004/04/18 15:51:59 fredo Exp $
#
#=======================================================================

use Encode qw(:all);
use utf8;

use PDF::API2;
use PDF::API2::Util;
use Unicode::UCD 'charinfo';
use Test::More;

my @fonts=qw(
    Times-Roman Times-Italic        Times-Bold          Times-BoldItalic
    Courier     Courier-Oblique     Courier-Bold        Courier-BoldOblique
    Helvetica   Helvetica-Oblique   Helvetica-Bold      Helvetica-BoldOblique
    Georgia     Georgia-Italic      Georgia-Bold        Georgia-BoldItalic
    Trebuchet   Trebuchet-Italic    Trebuchet-Bold      Trebuchet-BoldItalic 
    Verdana     Verdana-Italic      Verdana-Bold        Verdana-BoldItalic
    Symbol      ZapfDingbats        Wingdings           Webdings
);

my @rcfnc=qw{
    new new_api name
};
my @bffnc=qw{
    new new_api data descrByData fontname altname subname apiname issymbol iscff 
    fontbbox capheight xheight missingwidth maxwidth avgwidth flags stemv stemh 
    italicangle isfixedpitch underlineposition underlinethickness ascender descender 
    glyphNames glyphNum uniByGlyph uniByEnc uniByMap encByGlyph encByUni mapByGlyph 
    mapByUni glyphByUni glyphByEnc glyphByMap wxByGlyph wxByUni wxByEnc wxByMap 
    width width_array utfByStr strByUtf textByStr text
};
my @fnfnc=qw{
    encodeByData text automap remap 
};
my @cffnc=qw{
    _look_for_font _look_for_fontfile new new_api 
};
my @ilfnc=qw{
    nurmi surmi gurmi geek hack peck dudul saulus paulus jesus god
};

plan tests => scalar(@fonts) 
    * ( 4 
        + scalar(@rcfnc) 
        + scalar(@bffnc) 
        + scalar(@fnfnc)
        + scalar(@cffnc)
        + scalar(@ilfnc)
    );

foreach $fn (@fonts) {
    $pdf=PDF::API2->new;
    my $err=0;
    my $fnt=$pdf->corefont($fn,-encode => 'latin1');
    
    isa_ok($fnt,'PDF::API2::Resource');
    isa_ok($fnt,'PDF::API2::Resource::BaseFont');
    isa_ok($fnt,'PDF::API2::Resource::Font');
    isa_ok($fnt,'PDF::API2::Resource::Font::CoreFont');
    
    foreach my $f (@rcfnc) { can_ok($fnt,$f); }                 # test Resource Methods
    foreach my $f (@bffnc) { can_ok($fnt,$f); }                 # test BaseFont Methods
    foreach my $f (@fnfnc) { can_ok($fnt,$f); }                 # test Font Methods
    foreach my $f (@cffnc) { can_ok($fnt,$f); }                 # test CoreFont Methods
    foreach my $f (@ilfnc) { ok(!UNIVERSAL::can($fnt,$f),$f); } # test illegal Methods
    
    # ok($err == 0,"font=$fn, encoding=$enc, errors=$err.");
    $pdf->end();
}

exit;

__END__

    $Log: 022corefunc.t,v $
    Revision 1.1  2004/04/18 15:51:59  fredo
    genesis

    Revision 1.2  2004/04/18 13:46:44  fredo
    added cvs-log tag

    