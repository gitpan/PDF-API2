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
#   $Id: 020coreuse.t,v 1.3 2004/04/18 14:11:34 fredo Exp $
#
#=======================================================================

use Encode qw(:all);
use utf8;

use PDF::API2;
use PDF::API2::Util;
use Unicode::UCD 'charinfo';

@encodings=qw| 
    latin1 latin2 latin3 latin4 latin5 latin6 latin7 latin8 latin9 latin10
    iso-8859-5 iso-8859-6 iso-8859-7 iso-8859-8 
    koi8-f koi8-r koi8-u
    cp424 cp437 cp737 cp775
    cp850 cp852 cp855 cp856 cp857
    cp860 cp861 cp862 cp863 cp864 cp865 cp866 cp869 cp874
    WinLatin2 WinCyrillic WinLatin1 WinGreek WinTurkish WinHebrew WinArabic WinBaltic WinVietnamese
    MacArabic MacCentralEurRoman MacCroatian MacCyrillic MacFarsi MacGreek MacIcelandic MacRoman MacSami MacTurkish MacUkrainian
    AdobeStandardEncoding nextstep hp-roman8
|;
#   MacHebrew    MacThai     MacRomanian    MacRumanian
sub encodingToMaps ($) {
    my $e=shift @_;
    my @c=();
    my %c=();
    map{
        my $x=unpack('U',decode($e,chr($_)));
        $c[$_]=$x;
        $c{$x}=$_;
    } (0..255);
    return(\@c,\%c);
}

sub esc {
    my $newtext=shift @_;
    $newtext=~s/\\/\\\\/go;
    $newtext=~s/([\x00-\x1f])/sprintf('\%03lo',ord($1))/ge;
    $newtext=~s/([\{\}\[\]\(\)])/\\$1/g;
    return("($newtext)");
}

my @fonts=qw( Trebuchet );

use Test::More qw(no_plan);

foreach my $fn (@fonts) {

    foreach my $enc (@encodings) {
        $pdf=PDF::API2->new;

        my $fnt=$pdf->corefont($fn,-encode => $enc);
        ok(defined($fnt),"font=$fn enc=$enc.");
        my ($m,$h)=encodingToMaps($enc);
        foreach my $c (0..255) {
            my $t=chr($c);
            my $u=$fnt->strByUtf(chr($m->[$c]));
            ok(($t eq $u) || (nameByUni($fnt->uniByEnc($c)) eq nameByUni($m->[$c])),"font=$fn enc=$enc c=$c u=$m->[$c] t='$t'(".nameByUni($m->[$c]).")[".charinfo($m->[$c])->{name}."] u='$u'(".nameByUni($fnt->uniByEnc($c)).")[".charinfo($fnt->uniByEnc($c))->{name}."].");
        }
        eval {
            $fnt=$pdf->corefont("$fn illegal",-encode => $enc);
        };
        ok($@,"font=$fn enc=$enc illegal.");

        eval {
            $fnt=$pdf->corefont("$fn",-encode => "$enc illegal");
        };
        ok($@,"font=$fn illegal enc=$enc.");

        $pdf->end();
    }
}

exit;

__END__

    $Log: 020coreuse.t,v $
    Revision 1.3  2004/04/18 14:11:34  fredo
    fixed test for symbol fonts

    Revision 1.2  2004/04/18 14:01:14  fredo
    added defined/undefined test

    Revision 1.1  2004/04/18 13:54:21  fredo
    genesis

    