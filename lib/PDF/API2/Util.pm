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
#   $Id: Util.pm,v 1.12 2004/06/21 22:33:37 fredo Exp $
#
#=======================================================================
package PDF::API2::Util;

BEGIN {

    use utf8;
    use Encode qw(:all);

    use vars qw(
        $VERSION 
        @ISA 
        @EXPORT 
        @EXPORT_OK 
        %colors 
        $key_var 
        %u2n 
        %n2u 
        %u2n_o 
        %n2u_o 
        $pua
    );
    use Math::Trig;
    use List::Util qw(min max);
    use PDF::API2::Basic::PDF::Utils;
    use PDF::API2::Basic::PDF::Filter;

    use POSIX qw( HUGE_VAL floor );

    use Exporter;
    @ISA = qw(Exporter);
    @EXPORT = qw(
        pdfkey
        float floats floats5 intg intgs
        mMin mMax
        HSVtoRGB RGBtoHSV HSLtoRGB RGBtoHSL RGBtoLUM
        namecolor namecolor_cmyk namecolor_lab optInvColor defineColor
        dofilter unfilter
        nameByUni uniByName initNameTable defineName
        page_size
    );
    @EXPORT_OK = qw(
        pdfkey
        digest digestx digest16 digest32
        float floats floats5 intg intgs
        mMin mMax
        cRGB cRGB8 RGBasCMYK
        HSVtoRGB RGBtoHSV HSLtoRGB RGBtoHSL RGBtoLUM
        namecolor namecolor_cmyk namecolor_lab optInvColor defineColor
        dofilter unfilter
        nameByUni uniByName initNameTable defineName
        page_size
    );


    ( $VERSION ) = '$Revision: 1.12 $' =~ /Revision: (\S+)\s/; # $Date: 2004/06/21 22:33:37 $

    $key_var='BAAAAA';

    $pua=0xE000;

    %u2n_o=(
            '32' => 'space',                    # 0x0020 # Adobe Glyph List
            '33' => 'exclam',                   # 0x0021 # Adobe Glyph List
            '34' => 'quotedbl',                 # 0x0022 # Adobe Glyph List
            '35' => 'numbersign',               # 0x0023 # Adobe Glyph List
            '36' => 'dollar',                   # 0x0024 # Adobe Glyph List
            '37' => 'percent',                  # 0x0025 # Adobe Glyph List
            '38' => 'ampersand',                # 0x0026 # Adobe Glyph List
            '39' => 'quotesingle',              # 0x0027 # Adobe Glyph List
            '40' => 'parenleft',                # 0x0028 # Adobe Glyph List
            '41' => 'parenright',               # 0x0029 # Adobe Glyph List
            '42' => 'asterisk',                 # 0x002A # Adobe Glyph List
            '43' => 'plus',                     # 0x002B # Adobe Glyph List
            '44' => 'comma',                    # 0x002C # Adobe Glyph List
            '45' => 'hyphen',                   # 0x002D # Adobe Glyph List
            '46' => 'period',                   # 0x002E # Adobe Glyph List
            '47' => 'slash',                    # 0x002F # Adobe Glyph List
            '48' => 'zero',                     # 0x0030 # Adobe Glyph List
            '49' => 'one',                      # 0x0031 # Adobe Glyph List
            '50' => 'two',                      # 0x0032 # Adobe Glyph List
            '51' => 'three',                    # 0x0033 # Adobe Glyph List
            '52' => 'four',                     # 0x0034 # Adobe Glyph List
            '53' => 'five',                     # 0x0035 # Adobe Glyph List
            '54' => 'six',                      # 0x0036 # Adobe Glyph List
            '55' => 'seven',                    # 0x0037 # Adobe Glyph List
            '56' => 'eight',                    # 0x0038 # Adobe Glyph List
            '57' => 'nine',                     # 0x0039 # Adobe Glyph List
            '58' => 'colon',                    # 0x003A # Adobe Glyph List
            '59' => 'semicolon',                # 0x003B # Adobe Glyph List
            '60' => 'less',                     # 0x003C # Adobe Glyph List
            '61' => 'equal',                    # 0x003D # Adobe Glyph List
            '62' => 'greater',                  # 0x003E # Adobe Glyph List
            '63' => 'question',                 # 0x003F # Adobe Glyph List
            '64' => 'at',                       # 0x0040 # Adobe Glyph List
            '65' => 'A',                        # 0x0041 # Adobe Glyph List
            '66' => 'B',                        # 0x0042 # Adobe Glyph List
            '67' => 'C',                        # 0x0043 # Adobe Glyph List
            '68' => 'D',                        # 0x0044 # Adobe Glyph List
            '69' => 'E',                        # 0x0045 # Adobe Glyph List
            '70' => 'F',                        # 0x0046 # Adobe Glyph List
            '71' => 'G',                        # 0x0047 # Adobe Glyph List
            '72' => 'H',                        # 0x0048 # Adobe Glyph List
            '73' => 'I',                        # 0x0049 # Adobe Glyph List
            '74' => 'J',                        # 0x004A # Adobe Glyph List
            '75' => 'K',                        # 0x004B # Adobe Glyph List
            '76' => 'L',                        # 0x004C # Adobe Glyph List
            '77' => 'M',                        # 0x004D # Adobe Glyph List
            '78' => 'N',                        # 0x004E # Adobe Glyph List
            '79' => 'O',                        # 0x004F # Adobe Glyph List
            '80' => 'P',                        # 0x0050 # Adobe Glyph List
            '81' => 'Q',                        # 0x0051 # Adobe Glyph List
            '82' => 'R',                        # 0x0052 # Adobe Glyph List
            '83' => 'S',                        # 0x0053 # Adobe Glyph List
            '84' => 'T',                        # 0x0054 # Adobe Glyph List
            '85' => 'U',                        # 0x0055 # Adobe Glyph List
            '86' => 'V',                        # 0x0056 # Adobe Glyph List
            '87' => 'W',                        # 0x0057 # Adobe Glyph List
            '88' => 'X',                        # 0x0058 # Adobe Glyph List
            '89' => 'Y',                        # 0x0059 # Adobe Glyph List
            '90' => 'Z',                        # 0x005A # Adobe Glyph List
            '91' => 'bracketleft',              # 0x005B # Adobe Glyph List
            '92' => 'backslash',                # 0x005C # Adobe Glyph List
            '93' => 'bracketright',             # 0x005D # Adobe Glyph List
            '94' => 'asciicircum',              # 0x005E # Adobe Glyph List
            '95' => 'underscore',               # 0x005F # Adobe Glyph List
            '96' => 'grave',                    # 0x0060 # Adobe Glyph List
            '97' => 'a',                        # 0x0061 # Adobe Glyph List
            '98' => 'b',                        # 0x0062 # Adobe Glyph List
            '99' => 'c',                        # 0x0063 # Adobe Glyph List
            '100' => 'd',                       # 0x0064 # Adobe Glyph List
            '101' => 'e',                       # 0x0065 # Adobe Glyph List
            '102' => 'f',                       # 0x0066 # Adobe Glyph List
            '103' => 'g',                       # 0x0067 # Adobe Glyph List
            '104' => 'h',                       # 0x0068 # Adobe Glyph List
            '105' => 'i',                       # 0x0069 # Adobe Glyph List
            '106' => 'j',                       # 0x006A # Adobe Glyph List
            '107' => 'k',                       # 0x006B # Adobe Glyph List
            '108' => 'l',                       # 0x006C # Adobe Glyph List
            '109' => 'm',                       # 0x006D # Adobe Glyph List
            '110' => 'n',                       # 0x006E # Adobe Glyph List
            '111' => 'o',                       # 0x006F # Adobe Glyph List
            '112' => 'p',                       # 0x0070 # Adobe Glyph List
            '113' => 'q',                       # 0x0071 # Adobe Glyph List
            '114' => 'r',                       # 0x0072 # Adobe Glyph List
            '115' => 's',                       # 0x0073 # Adobe Glyph List
            '116' => 't',                       # 0x0074 # Adobe Glyph List
            '117' => 'u',                       # 0x0075 # Adobe Glyph List
            '118' => 'v',                       # 0x0076 # Adobe Glyph List
            '119' => 'w',                       # 0x0077 # Adobe Glyph List
            '120' => 'x',                       # 0x0078 # Adobe Glyph List
            '121' => 'y',                       # 0x0079 # Adobe Glyph List
            '122' => 'z',                       # 0x007A # Adobe Glyph List
            '123' => 'braceleft',               # 0x007B # Adobe Glyph List
            '124' => 'bar',                     # 0x007C # Adobe Glyph List
            '125' => 'braceright',              # 0x007D # Adobe Glyph List
            '126' => 'asciitilde',              # 0x007E # Adobe Glyph List
            '127' => 'bullet',                  # 0x007F # WGL4 Substitute
            '128' => 'Euro',                    # 0x0080 # WGL4 Substitute
            '129' => 'bullet',                  # 0x0081 # WGL4 Substitute
            '130' => 'quotesinglbase',          # 0x0082 # WGL4 Substitute
            '131' => 'florin',                  # 0x0083 # WGL4 Substitute
            '132' => 'quotedblbase',            # 0x0084 # WGL4 Substitute
            '133' => 'ellipsis',                # 0x0085 # WGL4 Substitute
            '134' => 'dagger',                  # 0x0086 # WGL4 Substitute
            '135' => 'daggerdbl',               # 0x0087 # WGL4 Substitute
            '136' => 'circumflex',              # 0x0088 # WGL4 Substitute
            '137' => 'perthousand',             # 0x0089 # WGL4 Substitute
            '138' => 'Scaron',                  # 0x008A # WGL4 Substitute
            '139' => 'guilsinglleft',           # 0x008B # WGL4 Substitute
            '140' => 'OE',                      # 0x008C # WGL4 Substitute
            '141' => 'bullet',                  # 0x008D # WGL4 Substitute
            '142' => 'Zcaron',                  # 0x008E # WGL4 Substitute
            '143' => 'bullet',                  # 0x008F # WGL4 Substitute
            '144' => 'bullet',                  # 0x0090 # WGL4 Substitute
            '145' => 'quoteleft',               # 0x0091 # WGL4 Substitute
            '146' => 'quoteright',              # 0x0092 # WGL4 Substitute
            '147' => 'quotedblleft',            # 0x0093 # WGL4 Substitute
            '148' => 'quotedblright',           # 0x0094 # WGL4 Substitute
            '149' => 'bullet',                  # 0x0095 # WGL4 Substitute
            '150' => 'endash',                  # 0x0096 # WGL4 Substitute
            '151' => 'emdash',                  # 0x0097 # WGL4 Substitute
            '152' => 'tilde',                   # 0x0098 # WGL4 Substitute
            '153' => 'trademark',               # 0x0099 # WGL4 Substitute
            '154' => 'scaron',                  # 0x009A # WGL4 Substitute
            '155' => 'guilsinglright',          # 0x009B # WGL4 Substitute
            '156' => 'oe',                      # 0x009C # WGL4 Substitute
            '157' => 'bullet',                  # 0x009D # WGL4 Substitute
            '158' => 'zcaron',                  # 0x009E # WGL4 Substitute
            '159' => 'Ydieresis',               # 0x009F # WGL4 Substitute
            '160' => 'space',                   # 0x00A0 # Adobe Glyph List
            '161' => 'exclamdown',              # 0x00A1 # Adobe Glyph List
            '162' => 'cent',                    # 0x00A2 # Adobe Glyph List
            '163' => 'sterling',                # 0x00A3 # Adobe Glyph List
            '164' => 'currency',                # 0x00A4 # Adobe Glyph List
            '165' => 'yen',                     # 0x00A5 # Adobe Glyph List
            '166' => 'brokenbar',               # 0x00A6 # Adobe Glyph List
            '167' => 'section',                 # 0x00A7 # Adobe Glyph List
            '168' => 'dieresis',                # 0x00A8 # Adobe Glyph List
            '169' => 'copyright',               # 0x00A9 # Adobe Glyph List
            '170' => 'ordfeminine',             # 0x00AA # Adobe Glyph List
            '171' => 'guillemotleft',           # 0x00AB # Adobe Glyph List
            '172' => 'logicalnot',              # 0x00AC # Adobe Glyph List
            '173' => 'hyphen',                  # 0x00AD # Adobe Glyph List
            '174' => 'registered',              # 0x00AE # Adobe Glyph List
            '175' => 'macron',                  # 0x00AF # Adobe Glyph List
            '176' => 'degree',                  # 0x00B0 # Adobe Glyph List
            '177' => 'plusminus',               # 0x00B1 # Adobe Glyph List
            '178' => 'twosuperior',             # 0x00B2 # Adobe Glyph List
            '179' => 'threesuperior',           # 0x00B3 # Adobe Glyph List
            '180' => 'acute',                   # 0x00B4 # Adobe Glyph List
            '181' => 'mu',                      # 0x00B5 # Adobe Glyph List
            '182' => 'paragraph',               # 0x00B6 # Adobe Glyph List
            '183' => 'periodcentered',          # 0x00B7 # Adobe Glyph List
            '184' => 'cedilla',                 # 0x00B8 # Adobe Glyph List
            '185' => 'onesuperior',             # 0x00B9 # Adobe Glyph List
            '186' => 'ordmasculine',            # 0x00BA # Adobe Glyph List
            '187' => 'guillemotright',          # 0x00BB # Adobe Glyph List
            '188' => 'onequarter',              # 0x00BC # Adobe Glyph List
            '189' => 'onehalf',                 # 0x00BD # Adobe Glyph List
            '190' => 'threequarters',           # 0x00BE # Adobe Glyph List
            '191' => 'questiondown',            # 0x00BF # Adobe Glyph List
            '192' => 'Agrave',                  # 0x00C0 # Adobe Glyph List
            '193' => 'Aacute',                  # 0x00C1 # Adobe Glyph List
            '194' => 'Acircumflex',             # 0x00C2 # Adobe Glyph List
            '195' => 'Atilde',                  # 0x00C3 # Adobe Glyph List
            '196' => 'Adieresis',               # 0x00C4 # Adobe Glyph List
            '197' => 'Aring',                   # 0x00C5 # Adobe Glyph List
            '198' => 'AE',                      # 0x00C6 # Adobe Glyph List
            '199' => 'Ccedilla',                # 0x00C7 # Adobe Glyph List
            '200' => 'Egrave',                  # 0x00C8 # Adobe Glyph List
            '201' => 'Eacute',                  # 0x00C9 # Adobe Glyph List
            '202' => 'Ecircumflex',             # 0x00CA # Adobe Glyph List
            '203' => 'Edieresis',               # 0x00CB # Adobe Glyph List
            '204' => 'Igrave',                  # 0x00CC # Adobe Glyph List
            '205' => 'Iacute',                  # 0x00CD # Adobe Glyph List
            '206' => 'Icircumflex',             # 0x00CE # Adobe Glyph List
            '207' => 'Idieresis',               # 0x00CF # Adobe Glyph List
            '208' => 'Eth',                     # 0x00D0 # Adobe Glyph List
            '209' => 'Ntilde',                  # 0x00D1 # Adobe Glyph List
            '210' => 'Ograve',                  # 0x00D2 # Adobe Glyph List
            '211' => 'Oacute',                  # 0x00D3 # Adobe Glyph List
            '212' => 'Ocircumflex',             # 0x00D4 # Adobe Glyph List
            '213' => 'Otilde',                  # 0x00D5 # Adobe Glyph List
            '214' => 'Odieresis',               # 0x00D6 # Adobe Glyph List
            '215' => 'multiply',                # 0x00D7 # Adobe Glyph List
            '216' => 'Oslash',                  # 0x00D8 # Adobe Glyph List
            '217' => 'Ugrave',                  # 0x00D9 # Adobe Glyph List
            '218' => 'Uacute',                  # 0x00DA # Adobe Glyph List
            '219' => 'Ucircumflex',             # 0x00DB # Adobe Glyph List
            '220' => 'Udieresis',               # 0x00DC # Adobe Glyph List
            '221' => 'Yacute',                  # 0x00DD # Adobe Glyph List
            '222' => 'Thorn',                   # 0x00DE # Adobe Glyph List
            '223' => 'germandbls',              # 0x00DF # Adobe Glyph List
            '224' => 'agrave',                  # 0x00E0 # Adobe Glyph List
            '225' => 'aacute',                  # 0x00E1 # Adobe Glyph List
            '226' => 'acircumflex',             # 0x00E2 # Adobe Glyph List
            '227' => 'atilde',                  # 0x00E3 # Adobe Glyph List
            '228' => 'adieresis',               # 0x00E4 # Adobe Glyph List
            '229' => 'aring',                   # 0x00E5 # Adobe Glyph List
            '230' => 'ae',                      # 0x00E6 # Adobe Glyph List
            '231' => 'ccedilla',                # 0x00E7 # Adobe Glyph List
            '232' => 'egrave',                  # 0x00E8 # Adobe Glyph List
            '233' => 'eacute',                  # 0x00E9 # Adobe Glyph List
            '234' => 'ecircumflex',             # 0x00EA # Adobe Glyph List
            '235' => 'edieresis',               # 0x00EB # Adobe Glyph List
            '236' => 'igrave',                  # 0x00EC # Adobe Glyph List
            '237' => 'iacute',                  # 0x00ED # Adobe Glyph List
            '238' => 'icircumflex',             # 0x00EE # Adobe Glyph List
            '239' => 'idieresis',               # 0x00EF # Adobe Glyph List
            '240' => 'eth',                     # 0x00F0 # Adobe Glyph List
            '241' => 'ntilde',                  # 0x00F1 # Adobe Glyph List
            '242' => 'ograve',                  # 0x00F2 # Adobe Glyph List
            '243' => 'oacute',                  # 0x00F3 # Adobe Glyph List
            '244' => 'ocircumflex',             # 0x00F4 # Adobe Glyph List
            '245' => 'otilde',                  # 0x00F5 # Adobe Glyph List
            '246' => 'odieresis',               # 0x00F6 # Adobe Glyph List
            '247' => 'divide',                  # 0x00F7 # Adobe Glyph List
            '248' => 'oslash',                  # 0x00F8 # Adobe Glyph List
            '249' => 'ugrave',                  # 0x00F9 # Adobe Glyph List
            '250' => 'uacute',                  # 0x00FA # Adobe Glyph List
            '251' => 'ucircumflex',             # 0x00FB # Adobe Glyph List
            '252' => 'udieresis',               # 0x00FC # Adobe Glyph List
            '253' => 'yacute',                  # 0x00FD # Adobe Glyph List
            '254' => 'thorn',                   # 0x00FE # Adobe Glyph List
            '255' => 'ydieresis',               # 0x00FF # Adobe Glyph List
            '256' => 'Amacron',                 # 0x0100 # Adobe Glyph List
            '257' => 'amacron',                 # 0x0101 # Adobe Glyph List
            '258' => 'Abreve',                  # 0x0102 # Adobe Glyph List
            '259' => 'abreve',                  # 0x0103 # Adobe Glyph List
            '260' => 'Aogonek',                 # 0x0104 # Adobe Glyph List
            '261' => 'aogonek',                 # 0x0105 # Adobe Glyph List
            '262' => 'Cacute',                  # 0x0106 # Adobe Glyph List
            '263' => 'cacute',                  # 0x0107 # Adobe Glyph List
            '264' => 'Ccircumflex',             # 0x0108 # Adobe Glyph List
            '265' => 'ccircumflex',             # 0x0109 # Adobe Glyph List
            '266' => 'Cdotaccent',              # 0x010A # Adobe Glyph List
            '267' => 'cdotaccent',              # 0x010B # Adobe Glyph List
            '268' => 'Ccaron',                  # 0x010C # Adobe Glyph List
            '269' => 'ccaron',                  # 0x010D # Adobe Glyph List
            '270' => 'Dcaron',                  # 0x010E # Adobe Glyph List
            '271' => 'dcaron',                  # 0x010F # Adobe Glyph List
            '272' => 'Dcroat',                  # 0x0110 # Adobe Glyph List
            '273' => 'dcroat',                  # 0x0111 # Adobe Glyph List
            '274' => 'Emacron',                 # 0x0112 # Adobe Glyph List
            '275' => 'emacron',                 # 0x0113 # Adobe Glyph List
            '276' => 'Ebreve',                  # 0x0114 # Adobe Glyph List
            '277' => 'ebreve',                  # 0x0115 # Adobe Glyph List
            '278' => 'Edotaccent',              # 0x0116 # Adobe Glyph List
            '279' => 'edotaccent',              # 0x0117 # Adobe Glyph List
            '280' => 'Eogonek',                 # 0x0118 # Adobe Glyph List
            '281' => 'eogonek',                 # 0x0119 # Adobe Glyph List
            '282' => 'Ecaron',                  # 0x011A # Adobe Glyph List
            '283' => 'ecaron',                  # 0x011B # Adobe Glyph List
            '284' => 'Gcircumflex',             # 0x011C # Adobe Glyph List
            '285' => 'gcircumflex',             # 0x011D # Adobe Glyph List
            '286' => 'Gbreve',                  # 0x011E # Adobe Glyph List
            '287' => 'gbreve',                  # 0x011F # Adobe Glyph List
            '288' => 'Gdotaccent',              # 0x0120 # Adobe Glyph List
            '289' => 'gdotaccent',              # 0x0121 # Adobe Glyph List
            '290' => 'Gcommaaccent',            # 0x0122 # Adobe Glyph List
            '291' => 'gcommaaccent',            # 0x0123 # Adobe Glyph List
            '292' => 'Hcircumflex',             # 0x0124 # Adobe Glyph List
            '293' => 'hcircumflex',             # 0x0125 # Adobe Glyph List
            '294' => 'Hbar',                    # 0x0126 # Adobe Glyph List
            '295' => 'hbar',                    # 0x0127 # Adobe Glyph List
            '296' => 'Itilde',                  # 0x0128 # Adobe Glyph List
            '297' => 'itilde',                  # 0x0129 # Adobe Glyph List
            '298' => 'Imacron',                 # 0x012A # Adobe Glyph List
            '299' => 'imacron',                 # 0x012B # Adobe Glyph List
            '300' => 'Ibreve',                  # 0x012C # Adobe Glyph List
            '301' => 'ibreve',                  # 0x012D # Adobe Glyph List
            '302' => 'Iogonek',                 # 0x012E # Adobe Glyph List
            '303' => 'iogonek',                 # 0x012F # Adobe Glyph List
            '304' => 'Idotaccent',              # 0x0130 # Adobe Glyph List
            '305' => 'dotlessi',                # 0x0131 # Adobe Glyph List
            '306' => 'IJ',                      # 0x0132 # Adobe Glyph List
            '307' => 'ij',                      # 0x0133 # Adobe Glyph List
            '308' => 'Jcircumflex',             # 0x0134 # Adobe Glyph List
            '309' => 'jcircumflex',             # 0x0135 # Adobe Glyph List
            '310' => 'Kcommaaccent',            # 0x0136 # Adobe Glyph List
            '311' => 'kcommaaccent',            # 0x0137 # Adobe Glyph List
            '312' => 'kgreenlandic',            # 0x0138 # Adobe Glyph List
            '313' => 'Lacute',                  # 0x0139 # Adobe Glyph List
            '314' => 'lacute',                  # 0x013A # Adobe Glyph List
            '315' => 'Lcommaaccent',            # 0x013B # Adobe Glyph List
            '316' => 'lcommaaccent',            # 0x013C # Adobe Glyph List
            '317' => 'Lcaron',                  # 0x013D # Adobe Glyph List
            '318' => 'lcaron',                  # 0x013E # Adobe Glyph List
            '319' => 'Ldot',                    # 0x013F # Adobe Glyph List
            '320' => 'ldot',                    # 0x0140 # Adobe Glyph List
            '321' => 'Lslash',                  # 0x0141 # Adobe Glyph List
            '322' => 'lslash',                  # 0x0142 # Adobe Glyph List
            '323' => 'Nacute',                  # 0x0143 # Adobe Glyph List
            '324' => 'nacute',                  # 0x0144 # Adobe Glyph List
            '325' => 'Ncommaaccent',            # 0x0145 # Adobe Glyph List
            '326' => 'ncommaaccent',            # 0x0146 # Adobe Glyph List
            '327' => 'Ncaron',                  # 0x0147 # Adobe Glyph List
            '328' => 'ncaron',                  # 0x0148 # Adobe Glyph List
            '329' => 'napostrophe',             # 0x0149 # Adobe Glyph List
            '330' => 'Eng',                     # 0x014A # Adobe Glyph List
            '331' => 'eng',                     # 0x014B # Adobe Glyph List
            '332' => 'Omacron',                 # 0x014C # Adobe Glyph List
            '333' => 'omacron',                 # 0x014D # Adobe Glyph List
            '334' => 'Obreve',                  # 0x014E # Adobe Glyph List
            '335' => 'obreve',                  # 0x014F # Adobe Glyph List
            '336' => 'Ohungarumlaut',           # 0x0150 # Adobe Glyph List
            '337' => 'ohungarumlaut',           # 0x0151 # Adobe Glyph List
            '338' => 'OE',                      # 0x0152 # Adobe Glyph List
            '339' => 'oe',                      # 0x0153 # Adobe Glyph List
            '340' => 'Racute',                  # 0x0154 # Adobe Glyph List
            '341' => 'racute',                  # 0x0155 # Adobe Glyph List
            '342' => 'Rcommaaccent',            # 0x0156 # Adobe Glyph List
            '343' => 'rcommaaccent',            # 0x0157 # Adobe Glyph List
            '344' => 'Rcaron',                  # 0x0158 # Adobe Glyph List
            '345' => 'rcaron',                  # 0x0159 # Adobe Glyph List
            '346' => 'Sacute',                  # 0x015A # Adobe Glyph List
            '347' => 'sacute',                  # 0x015B # Adobe Glyph List
            '348' => 'Scircumflex',             # 0x015C # Adobe Glyph List
            '349' => 'scircumflex',             # 0x015D # Adobe Glyph List
            '350' => 'Scedilla',                # 0x015E # Adobe Glyph List
            '351' => 'scedilla',                # 0x015F # Adobe Glyph List
            '352' => 'Scaron',                  # 0x0160 # Adobe Glyph List
            '353' => 'scaron',                  # 0x0161 # Adobe Glyph List
            '354' => 'Tcommaaccent',            # 0x0162 # Adobe Glyph List
            '355' => 'tcommaaccent',            # 0x0163 # Adobe Glyph List
            '356' => 'Tcaron',                  # 0x0164 # Adobe Glyph List
            '357' => 'tcaron',                  # 0x0165 # Adobe Glyph List
            '358' => 'Tbar',                    # 0x0166 # Adobe Glyph List
            '359' => 'tbar',                    # 0x0167 # Adobe Glyph List
            '360' => 'Utilde',                  # 0x0168 # Adobe Glyph List
            '361' => 'utilde',                  # 0x0169 # Adobe Glyph List
            '362' => 'Umacron',                 # 0x016A # Adobe Glyph List
            '363' => 'umacron',                 # 0x016B # Adobe Glyph List
            '364' => 'Ubreve',                  # 0x016C # Adobe Glyph List
            '365' => 'ubreve',                  # 0x016D # Adobe Glyph List
            '366' => 'Uring',                   # 0x016E # Adobe Glyph List
            '367' => 'uring',                   # 0x016F # Adobe Glyph List
            '368' => 'Uhungarumlaut',           # 0x0170 # Adobe Glyph List
            '369' => 'uhungarumlaut',           # 0x0171 # Adobe Glyph List
            '370' => 'Uogonek',                 # 0x0172 # Adobe Glyph List
            '371' => 'uogonek',                 # 0x0173 # Adobe Glyph List
            '372' => 'Wcircumflex',             # 0x0174 # Adobe Glyph List
            '373' => 'wcircumflex',             # 0x0175 # Adobe Glyph List
            '374' => 'Ycircumflex',             # 0x0176 # Adobe Glyph List
            '375' => 'ycircumflex',             # 0x0177 # Adobe Glyph List
            '376' => 'Ydieresis',               # 0x0178 # Adobe Glyph List
            '377' => 'Zacute',                  # 0x0179 # Adobe Glyph List
            '378' => 'zacute',                  # 0x017A # Adobe Glyph List
            '379' => 'Zdotaccent',              # 0x017B # Adobe Glyph List
            '380' => 'zdotaccent',              # 0x017C # Adobe Glyph List
            '381' => 'Zcaron',                  # 0x017D # Adobe Glyph List
            '382' => 'zcaron',                  # 0x017E # Adobe Glyph List
            '383' => 'longs',                   # 0x017F # Adobe Glyph List
            '402' => 'florin',                  # 0x0192 # Adobe Glyph List
            '416' => 'Ohorn',                   # 0x01A0 # Adobe Glyph List
            '417' => 'ohorn',                   # 0x01A1 # Adobe Glyph List
            '431' => 'Uhorn',                   # 0x01AF # Adobe Glyph List
            '432' => 'uhorn',                   # 0x01B0 # Adobe Glyph List
            '486' => 'Gcaron',                  # 0x01E6 # Adobe Glyph List
            '487' => 'gcaron',                  # 0x01E7 # Adobe Glyph List
            '506' => 'Aringacute',              # 0x01FA # Adobe Glyph List
            '507' => 'aringacute',              # 0x01FB # Adobe Glyph List
            '508' => 'AEacute',                 # 0x01FC # Adobe Glyph List
            '509' => 'aeacute',                 # 0x01FD # Adobe Glyph List
            '510' => 'Oslashacute',             # 0x01FE # Adobe Glyph List
            '511' => 'oslashacute',             # 0x01FF # Adobe Glyph List
            '536' => 'Scommaaccent',            # 0x0218 # Adobe Glyph List
            '537' => 'scommaaccent',            # 0x0219 # Adobe Glyph List
            '538' => 'Tcommaaccent',            # 0x021A # Adobe Glyph List
            '539' => 'tcommaaccent',            # 0x021B # Adobe Glyph List
            '700' => 'afii57929',               # 0x02BC # Adobe Glyph List
            '701' => 'afii64937',               # 0x02BD # Adobe Glyph List
            '710' => 'circumflex',              # 0x02C6 # Adobe Glyph List
            '711' => 'caron',                   # 0x02C7 # Adobe Glyph List
            '713' => 'macron',                  # 0x02C9 # Adobe Glyph List
            '728' => 'breve',                   # 0x02D8 # Adobe Glyph List
            '729' => 'dotaccent',               # 0x02D9 # Adobe Glyph List
            '730' => 'ring',                    # 0x02DA # Adobe Glyph List
            '731' => 'ogonek',                  # 0x02DB # Adobe Glyph List
            '732' => 'tilde',                   # 0x02DC # Adobe Glyph List
            '733' => 'hungarumlaut',            # 0x02DD # Adobe Glyph List
            '768' => 'gravecomb',               # 0x0300 # Adobe Glyph List
            '769' => 'acutecomb',               # 0x0301 # Adobe Glyph List
            '771' => 'tildecomb',               # 0x0303 # Adobe Glyph List
            '777' => 'hookabovecomb',           # 0x0309 # Adobe Glyph List
            '803' => 'dotbelowcomb',            # 0x0323 # Adobe Glyph List
            '900' => 'tonos',                   # 0x0384 # Adobe Glyph List
            '901' => 'dieresistonos',           # 0x0385 # Adobe Glyph List
            '902' => 'Alphatonos',              # 0x0386 # Adobe Glyph List
            '903' => 'anoteleia',               # 0x0387 # Adobe Glyph List
            '904' => 'Epsilontonos',            # 0x0388 # Adobe Glyph List
            '905' => 'Etatonos',                # 0x0389 # Adobe Glyph List
            '906' => 'Iotatonos',               # 0x038A # Adobe Glyph List
            '908' => 'Omicrontonos',            # 0x038C # Adobe Glyph List
            '910' => 'Upsilontonos',            # 0x038E # Adobe Glyph List
            '911' => 'Omegatonos',              # 0x038F # Adobe Glyph List
            '912' => 'iotadieresistonos',       # 0x0390 # Adobe Glyph List
            '913' => 'Alpha',                   # 0x0391 # Adobe Glyph List
            '914' => 'Beta',                    # 0x0392 # Adobe Glyph List
            '915' => 'Gamma',                   # 0x0393 # Adobe Glyph List
            '916' => 'Delta',                   # 0x0394 # Adobe Glyph List
            '917' => 'Epsilon',                 # 0x0395 # Adobe Glyph List
            '918' => 'Zeta',                    # 0x0396 # Adobe Glyph List
            '919' => 'Eta',                     # 0x0397 # Adobe Glyph List
            '920' => 'Theta',                   # 0x0398 # Adobe Glyph List
            '921' => 'Iota',                    # 0x0399 # Adobe Glyph List
            '922' => 'Kappa',                   # 0x039A # Adobe Glyph List
            '923' => 'Lambda',                  # 0x039B # Adobe Glyph List
            '924' => 'Mu',                      # 0x039C # Adobe Glyph List
            '925' => 'Nu',                      # 0x039D # Adobe Glyph List
            '926' => 'Xi',                      # 0x039E # Adobe Glyph List
            '927' => 'Omicron',                 # 0x039F # Adobe Glyph List
            '928' => 'Pi',                      # 0x03A0 # Adobe Glyph List
            '929' => 'Rho',                     # 0x03A1 # Adobe Glyph List
            '931' => 'Sigma',                   # 0x03A3 # Adobe Glyph List
            '932' => 'Tau',                     # 0x03A4 # Adobe Glyph List
            '933' => 'Upsilon',                 # 0x03A5 # Adobe Glyph List
            '934' => 'Phi',                     # 0x03A6 # Adobe Glyph List
            '935' => 'Chi',                     # 0x03A7 # Adobe Glyph List
            '936' => 'Psi',                     # 0x03A8 # Adobe Glyph List
            '937' => 'Omega',                   # 0x03A9 # Adobe Glyph List
            '938' => 'Iotadieresis',            # 0x03AA # Adobe Glyph List
            '939' => 'Upsilondieresis',         # 0x03AB # Adobe Glyph List
            '940' => 'alphatonos',              # 0x03AC # Adobe Glyph List
            '941' => 'epsilontonos',            # 0x03AD # Adobe Glyph List
            '942' => 'etatonos',                # 0x03AE # Adobe Glyph List
            '943' => 'iotatonos',               # 0x03AF # Adobe Glyph List
            '944' => 'upsilondieresistonos',    # 0x03B0 # Adobe Glyph List
            '945' => 'alpha',                   # 0x03B1 # Adobe Glyph List
            '946' => 'beta',                    # 0x03B2 # Adobe Glyph List
            '947' => 'gamma',                   # 0x03B3 # Adobe Glyph List
            '948' => 'delta',                   # 0x03B4 # Adobe Glyph List
            '949' => 'epsilon',                 # 0x03B5 # Adobe Glyph List
            '950' => 'zeta',                    # 0x03B6 # Adobe Glyph List
            '951' => 'eta',                     # 0x03B7 # Adobe Glyph List
            '952' => 'theta',                   # 0x03B8 # Adobe Glyph List
            '953' => 'iota',                    # 0x03B9 # Adobe Glyph List
            '954' => 'kappa',                   # 0x03BA # Adobe Glyph List
            '955' => 'lambda',                  # 0x03BB # Adobe Glyph List
            '956' => 'mu',                      # 0x03BC # Adobe Glyph List
            '957' => 'nu',                      # 0x03BD # Adobe Glyph List
            '958' => 'xi',                      # 0x03BE # Adobe Glyph List
            '959' => 'omicron',                 # 0x03BF # Adobe Glyph List
            '960' => 'pi',                      # 0x03C0 # Adobe Glyph List
            '961' => 'rho',                     # 0x03C1 # Adobe Glyph List
            '962' => 'sigma1',                  # 0x03C2 # Adobe Glyph List
            '963' => 'sigma',                   # 0x03C3 # Adobe Glyph List
            '964' => 'tau',                     # 0x03C4 # Adobe Glyph List
            '965' => 'upsilon',                 # 0x03C5 # Adobe Glyph List
            '966' => 'phi',                     # 0x03C6 # Adobe Glyph List
            '967' => 'chi',                     # 0x03C7 # Adobe Glyph List
            '968' => 'psi',                     # 0x03C8 # Adobe Glyph List
            '969' => 'omega',                   # 0x03C9 # Adobe Glyph List
            '970' => 'iotadieresis',            # 0x03CA # Adobe Glyph List
            '971' => 'upsilondieresis',         # 0x03CB # Adobe Glyph List
            '972' => 'omicrontonos',            # 0x03CC # Adobe Glyph List
            '973' => 'upsilontonos',            # 0x03CD # Adobe Glyph List
            '974' => 'omegatonos',              # 0x03CE # Adobe Glyph List
            '977' => 'theta1',                  # 0x03D1 # Adobe Glyph List
            '978' => 'Upsilon1',                # 0x03D2 # Adobe Glyph List
            '981' => 'phi1',                    # 0x03D5 # Adobe Glyph List
            '982' => 'omega1',                  # 0x03D6 # Adobe Glyph List
            '1025' => 'afii10023',              # 0x0401 # Adobe Glyph List
            '1026' => 'afii10051',              # 0x0402 # Adobe Glyph List
            '1027' => 'afii10052',              # 0x0403 # Adobe Glyph List
            '1028' => 'afii10053',              # 0x0404 # Adobe Glyph List
            '1029' => 'afii10054',              # 0x0405 # Adobe Glyph List
            '1030' => 'afii10055',              # 0x0406 # Adobe Glyph List
            '1031' => 'afii10056',              # 0x0407 # Adobe Glyph List
            '1032' => 'afii10057',              # 0x0408 # Adobe Glyph List
            '1033' => 'afii10058',              # 0x0409 # Adobe Glyph List
            '1034' => 'afii10059',              # 0x040A # Adobe Glyph List
            '1035' => 'afii10060',              # 0x040B # Adobe Glyph List
            '1036' => 'afii10061',              # 0x040C # Adobe Glyph List
            '1038' => 'afii10062',              # 0x040E # Adobe Glyph List
            '1039' => 'afii10145',              # 0x040F # Adobe Glyph List
            '1040' => 'afii10017',              # 0x0410 # Adobe Glyph List
            '1041' => 'afii10018',              # 0x0411 # Adobe Glyph List
            '1042' => 'afii10019',              # 0x0412 # Adobe Glyph List
            '1043' => 'afii10020',              # 0x0413 # Adobe Glyph List
            '1044' => 'afii10021',              # 0x0414 # Adobe Glyph List
            '1045' => 'afii10022',              # 0x0415 # Adobe Glyph List
            '1046' => 'afii10024',              # 0x0416 # Adobe Glyph List
            '1047' => 'afii10025',              # 0x0417 # Adobe Glyph List
            '1048' => 'afii10026',              # 0x0418 # Adobe Glyph List
            '1049' => 'afii10027',              # 0x0419 # Adobe Glyph List
            '1050' => 'afii10028',              # 0x041A # Adobe Glyph List
            '1051' => 'afii10029',              # 0x041B # Adobe Glyph List
            '1052' => 'afii10030',              # 0x041C # Adobe Glyph List
            '1053' => 'afii10031',              # 0x041D # Adobe Glyph List
            '1054' => 'afii10032',              # 0x041E # Adobe Glyph List
            '1055' => 'afii10033',              # 0x041F # Adobe Glyph List
            '1056' => 'afii10034',              # 0x0420 # Adobe Glyph List
            '1057' => 'afii10035',              # 0x0421 # Adobe Glyph List
            '1058' => 'afii10036',              # 0x0422 # Adobe Glyph List
            '1059' => 'afii10037',              # 0x0423 # Adobe Glyph List
            '1060' => 'afii10038',              # 0x0424 # Adobe Glyph List
            '1061' => 'afii10039',              # 0x0425 # Adobe Glyph List
            '1062' => 'afii10040',              # 0x0426 # Adobe Glyph List
            '1063' => 'afii10041',              # 0x0427 # Adobe Glyph List
            '1064' => 'afii10042',              # 0x0428 # Adobe Glyph List
            '1065' => 'afii10043',              # 0x0429 # Adobe Glyph List
            '1066' => 'afii10044',              # 0x042A # Adobe Glyph List
            '1067' => 'afii10045',              # 0x042B # Adobe Glyph List
            '1068' => 'afii10046',              # 0x042C # Adobe Glyph List
            '1069' => 'afii10047',              # 0x042D # Adobe Glyph List
            '1070' => 'afii10048',              # 0x042E # Adobe Glyph List
            '1071' => 'afii10049',              # 0x042F # Adobe Glyph List
            '1072' => 'afii10065',              # 0x0430 # Adobe Glyph List
            '1073' => 'afii10066',              # 0x0431 # Adobe Glyph List
            '1074' => 'afii10067',              # 0x0432 # Adobe Glyph List
            '1075' => 'afii10068',              # 0x0433 # Adobe Glyph List
            '1076' => 'afii10069',              # 0x0434 # Adobe Glyph List
            '1077' => 'afii10070',              # 0x0435 # Adobe Glyph List
            '1078' => 'afii10072',              # 0x0436 # Adobe Glyph List
            '1079' => 'afii10073',              # 0x0437 # Adobe Glyph List
            '1080' => 'afii10074',              # 0x0438 # Adobe Glyph List
            '1081' => 'afii10075',              # 0x0439 # Adobe Glyph List
            '1082' => 'afii10076',              # 0x043A # Adobe Glyph List
            '1083' => 'afii10077',              # 0x043B # Adobe Glyph List
            '1084' => 'afii10078',              # 0x043C # Adobe Glyph List
            '1085' => 'afii10079',              # 0x043D # Adobe Glyph List
            '1086' => 'afii10080',              # 0x043E # Adobe Glyph List
            '1087' => 'afii10081',              # 0x043F # Adobe Glyph List
            '1088' => 'afii10082',              # 0x0440 # Adobe Glyph List
            '1089' => 'afii10083',              # 0x0441 # Adobe Glyph List
            '1090' => 'afii10084',              # 0x0442 # Adobe Glyph List
            '1091' => 'afii10085',              # 0x0443 # Adobe Glyph List
            '1092' => 'afii10086',              # 0x0444 # Adobe Glyph List
            '1093' => 'afii10087',              # 0x0445 # Adobe Glyph List
            '1094' => 'afii10088',              # 0x0446 # Adobe Glyph List
            '1095' => 'afii10089',              # 0x0447 # Adobe Glyph List
            '1096' => 'afii10090',              # 0x0448 # Adobe Glyph List
            '1097' => 'afii10091',              # 0x0449 # Adobe Glyph List
            '1098' => 'afii10092',              # 0x044A # Adobe Glyph List
            '1099' => 'afii10093',              # 0x044B # Adobe Glyph List
            '1100' => 'afii10094',              # 0x044C # Adobe Glyph List
            '1101' => 'afii10095',              # 0x044D # Adobe Glyph List
            '1102' => 'afii10096',              # 0x044E # Adobe Glyph List
            '1103' => 'afii10097',              # 0x044F # Adobe Glyph List
            '1105' => 'afii10071',              # 0x0451 # Adobe Glyph List
            '1106' => 'afii10099',              # 0x0452 # Adobe Glyph List
            '1107' => 'afii10100',              # 0x0453 # Adobe Glyph List
            '1108' => 'afii10101',              # 0x0454 # Adobe Glyph List
            '1109' => 'afii10102',              # 0x0455 # Adobe Glyph List
            '1110' => 'afii10103',              # 0x0456 # Adobe Glyph List
            '1111' => 'afii10104',              # 0x0457 # Adobe Glyph List
            '1112' => 'afii10105',              # 0x0458 # Adobe Glyph List
            '1113' => 'afii10106',              # 0x0459 # Adobe Glyph List
            '1114' => 'afii10107',              # 0x045A # Adobe Glyph List
            '1115' => 'afii10108',              # 0x045B # Adobe Glyph List
            '1116' => 'afii10109',              # 0x045C # Adobe Glyph List
            '1118' => 'afii10110',              # 0x045E # Adobe Glyph List
            '1119' => 'afii10193',              # 0x045F # Adobe Glyph List
            '1122' => 'afii10146',              # 0x0462 # Adobe Glyph List
            '1123' => 'afii10194',              # 0x0463 # Adobe Glyph List
            '1138' => 'afii10147',              # 0x0472 # Adobe Glyph List
            '1139' => 'afii10195',              # 0x0473 # Adobe Glyph List
            '1140' => 'afii10148',              # 0x0474 # Adobe Glyph List
            '1141' => 'afii10196',              # 0x0475 # Adobe Glyph List
            '1168' => 'afii10050',              # 0x0490 # Adobe Glyph List
            '1169' => 'afii10098',              # 0x0491 # Adobe Glyph List
            '1241' => 'afii10846',              # 0x04D9 # Adobe Glyph List
            '1456' => 'afii57799',              # 0x05B0 # Adobe Glyph List
            '1457' => 'afii57801',              # 0x05B1 # Adobe Glyph List
            '1458' => 'afii57800',              # 0x05B2 # Adobe Glyph List
            '1459' => 'afii57802',              # 0x05B3 # Adobe Glyph List
            '1460' => 'afii57793',              # 0x05B4 # Adobe Glyph List
            '1461' => 'afii57794',              # 0x05B5 # Adobe Glyph List
            '1462' => 'afii57795',              # 0x05B6 # Adobe Glyph List
            '1463' => 'afii57798',              # 0x05B7 # Adobe Glyph List
            '1464' => 'afii57797',              # 0x05B8 # Adobe Glyph List
            '1465' => 'afii57806',              # 0x05B9 # Adobe Glyph List
            '1467' => 'afii57796',              # 0x05BB # Adobe Glyph List
            '1468' => 'afii57807',              # 0x05BC # Adobe Glyph List
            '1469' => 'afii57839',              # 0x05BD # Adobe Glyph List
            '1470' => 'afii57645',              # 0x05BE # Adobe Glyph List
            '1471' => 'afii57841',              # 0x05BF # Adobe Glyph List
            '1472' => 'afii57842',              # 0x05C0 # Adobe Glyph List
            '1473' => 'afii57804',              # 0x05C1 # Adobe Glyph List
            '1474' => 'afii57803',              # 0x05C2 # Adobe Glyph List
            '1475' => 'afii57658',              # 0x05C3 # Adobe Glyph List
            '1488' => 'afii57664',              # 0x05D0 # Adobe Glyph List
            '1489' => 'afii57665',              # 0x05D1 # Adobe Glyph List
            '1490' => 'afii57666',              # 0x05D2 # Adobe Glyph List
            '1491' => 'afii57667',              # 0x05D3 # Adobe Glyph List
            '1492' => 'afii57668',              # 0x05D4 # Adobe Glyph List
            '1493' => 'afii57669',              # 0x05D5 # Adobe Glyph List
            '1494' => 'afii57670',              # 0x05D6 # Adobe Glyph List
            '1495' => 'afii57671',              # 0x05D7 # Adobe Glyph List
            '1496' => 'afii57672',              # 0x05D8 # Adobe Glyph List
            '1497' => 'afii57673',              # 0x05D9 # Adobe Glyph List
            '1498' => 'afii57674',              # 0x05DA # Adobe Glyph List
            '1499' => 'afii57675',              # 0x05DB # Adobe Glyph List
            '1500' => 'afii57676',              # 0x05DC # Adobe Glyph List
            '1501' => 'afii57677',              # 0x05DD # Adobe Glyph List
            '1502' => 'afii57678',              # 0x05DE # Adobe Glyph List
            '1503' => 'afii57679',              # 0x05DF # Adobe Glyph List
            '1504' => 'afii57680',              # 0x05E0 # Adobe Glyph List
            '1505' => 'afii57681',              # 0x05E1 # Adobe Glyph List
            '1506' => 'afii57682',              # 0x05E2 # Adobe Glyph List
            '1507' => 'afii57683',              # 0x05E3 # Adobe Glyph List
            '1508' => 'afii57684',              # 0x05E4 # Adobe Glyph List
            '1509' => 'afii57685',              # 0x05E5 # Adobe Glyph List
            '1510' => 'afii57686',              # 0x05E6 # Adobe Glyph List
            '1511' => 'afii57687',              # 0x05E7 # Adobe Glyph List
            '1512' => 'afii57688',              # 0x05E8 # Adobe Glyph List
            '1513' => 'afii57689',              # 0x05E9 # Adobe Glyph List
            '1514' => 'afii57690',              # 0x05EA # Adobe Glyph List
            '1520' => 'afii57716',              # 0x05F0 # Adobe Glyph List
            '1521' => 'afii57717',              # 0x05F1 # Adobe Glyph List
            '1522' => 'afii57718',              # 0x05F2 # Adobe Glyph List
            '1548' => 'afii57388',              # 0x060C # Adobe Glyph List
            '1563' => 'afii57403',              # 0x061B # Adobe Glyph List
            '1567' => 'afii57407',              # 0x061F # Adobe Glyph List
            '1569' => 'afii57409',              # 0x0621 # Adobe Glyph List
            '1570' => 'afii57410',              # 0x0622 # Adobe Glyph List
            '1571' => 'afii57411',              # 0x0623 # Adobe Glyph List
            '1572' => 'afii57412',              # 0x0624 # Adobe Glyph List
            '1573' => 'afii57413',              # 0x0625 # Adobe Glyph List
            '1574' => 'afii57414',              # 0x0626 # Adobe Glyph List
            '1575' => 'afii57415',              # 0x0627 # Adobe Glyph List
            '1576' => 'afii57416',              # 0x0628 # Adobe Glyph List
            '1577' => 'afii57417',              # 0x0629 # Adobe Glyph List
            '1578' => 'afii57418',              # 0x062A # Adobe Glyph List
            '1579' => 'afii57419',              # 0x062B # Adobe Glyph List
            '1580' => 'afii57420',              # 0x062C # Adobe Glyph List
            '1581' => 'afii57421',              # 0x062D # Adobe Glyph List
            '1582' => 'afii57422',              # 0x062E # Adobe Glyph List
            '1583' => 'afii57423',              # 0x062F # Adobe Glyph List
            '1584' => 'afii57424',              # 0x0630 # Adobe Glyph List
            '1585' => 'afii57425',              # 0x0631 # Adobe Glyph List
            '1586' => 'afii57426',              # 0x0632 # Adobe Glyph List
            '1587' => 'afii57427',              # 0x0633 # Adobe Glyph List
            '1588' => 'afii57428',              # 0x0634 # Adobe Glyph List
            '1589' => 'afii57429',              # 0x0635 # Adobe Glyph List
            '1590' => 'afii57430',              # 0x0636 # Adobe Glyph List
            '1591' => 'afii57431',              # 0x0637 # Adobe Glyph List
            '1592' => 'afii57432',              # 0x0638 # Adobe Glyph List
            '1593' => 'afii57433',              # 0x0639 # Adobe Glyph List
            '1594' => 'afii57434',              # 0x063A # Adobe Glyph List
            '1600' => 'afii57440',              # 0x0640 # Adobe Glyph List
            '1601' => 'afii57441',              # 0x0641 # Adobe Glyph List
            '1602' => 'afii57442',              # 0x0642 # Adobe Glyph List
            '1603' => 'afii57443',              # 0x0643 # Adobe Glyph List
            '1604' => 'afii57444',              # 0x0644 # Adobe Glyph List
            '1605' => 'afii57445',              # 0x0645 # Adobe Glyph List
            '1606' => 'afii57446',              # 0x0646 # Adobe Glyph List
            '1607' => 'afii57470',              # 0x0647 # Adobe Glyph List
            '1608' => 'afii57448',              # 0x0648 # Adobe Glyph List
            '1609' => 'afii57449',              # 0x0649 # Adobe Glyph List
            '1610' => 'afii57450',              # 0x064A # Adobe Glyph List
            '1611' => 'afii57451',              # 0x064B # Adobe Glyph List
            '1612' => 'afii57452',              # 0x064C # Adobe Glyph List
            '1613' => 'afii57453',              # 0x064D # Adobe Glyph List
            '1614' => 'afii57454',              # 0x064E # Adobe Glyph List
            '1615' => 'afii57455',              # 0x064F # Adobe Glyph List
            '1616' => 'afii57456',              # 0x0650 # Adobe Glyph List
            '1617' => 'afii57457',              # 0x0651 # Adobe Glyph List
            '1618' => 'afii57458',              # 0x0652 # Adobe Glyph List
            '1632' => 'afii57392',              # 0x0660 # Adobe Glyph List
            '1633' => 'afii57393',              # 0x0661 # Adobe Glyph List
            '1634' => 'afii57394',              # 0x0662 # Adobe Glyph List
            '1635' => 'afii57395',              # 0x0663 # Adobe Glyph List
            '1636' => 'afii57396',              # 0x0664 # Adobe Glyph List
            '1637' => 'afii57397',              # 0x0665 # Adobe Glyph List
            '1638' => 'afii57398',              # 0x0666 # Adobe Glyph List
            '1639' => 'afii57399',              # 0x0667 # Adobe Glyph List
            '1640' => 'afii57400',              # 0x0668 # Adobe Glyph List
            '1641' => 'afii57401',              # 0x0669 # Adobe Glyph List
            '1642' => 'afii57381',              # 0x066A # Adobe Glyph List
            '1645' => 'afii63167',              # 0x066D # Adobe Glyph List
            '1657' => 'afii57511',              # 0x0679 # Adobe Glyph List
            '1662' => 'afii57506',              # 0x067E # Adobe Glyph List
            '1670' => 'afii57507',              # 0x0686 # Adobe Glyph List
            '1672' => 'afii57512',              # 0x0688 # Adobe Glyph List
            '1681' => 'afii57513',              # 0x0691 # Adobe Glyph List
            '1688' => 'afii57508',              # 0x0698 # Adobe Glyph List
            '1700' => 'afii57505',              # 0x06A4 # Adobe Glyph List
            '1711' => 'afii57509',              # 0x06AF # Adobe Glyph List
            '1722' => 'afii57514',              # 0x06BA # Adobe Glyph List
            '1746' => 'afii57519',              # 0x06D2 # Adobe Glyph List
            '1749' => 'afii57534',              # 0x06D5 # Adobe Glyph List
            '7808' => 'Wgrave',                 # 0x1E80 # Adobe Glyph List
            '7809' => 'wgrave',                 # 0x1E81 # Adobe Glyph List
            '7810' => 'Wacute',                 # 0x1E82 # Adobe Glyph List
            '7811' => 'wacute',                 # 0x1E83 # Adobe Glyph List
            '7812' => 'Wdieresis',              # 0x1E84 # Adobe Glyph List
            '7813' => 'wdieresis',              # 0x1E85 # Adobe Glyph List
            '7922' => 'Ygrave',                 # 0x1EF2 # Adobe Glyph List
            '7923' => 'ygrave',                 # 0x1EF3 # Adobe Glyph List
            '8204' => 'afii61664',              # 0x200C # Adobe Glyph List
            '8205' => 'afii301',                # 0x200D # Adobe Glyph List
            '8206' => 'afii299',                # 0x200E # Adobe Glyph List
            '8207' => 'afii300',                # 0x200F # Adobe Glyph List
            '8210' => 'figuredash',             # 0x2012 # Adobe Glyph List
            '8211' => 'endash',                 # 0x2013 # Adobe Glyph List
            '8212' => 'emdash',                 # 0x2014 # Adobe Glyph List
            '8213' => 'afii00208',              # 0x2015 # Adobe Glyph List
            '8215' => 'underscoredbl',          # 0x2017 # Adobe Glyph List
            '8216' => 'quoteleft',              # 0x2018 # Adobe Glyph List
            '8217' => 'quoteright',             # 0x2019 # Adobe Glyph List
            '8218' => 'quotesinglbase',         # 0x201A # Adobe Glyph List
            '8219' => 'quotereversed',          # 0x201B # Adobe Glyph List
            '8220' => 'quotedblleft',           # 0x201C # Adobe Glyph List
            '8221' => 'quotedblright',          # 0x201D # Adobe Glyph List
            '8222' => 'quotedblbase',           # 0x201E # Adobe Glyph List
            '8224' => 'dagger',                 # 0x2020 # Adobe Glyph List
            '8225' => 'daggerdbl',              # 0x2021 # Adobe Glyph List
            '8226' => 'bullet',                 # 0x2022 # Adobe Glyph List
            '8228' => 'onedotenleader',         # 0x2024 # Adobe Glyph List
            '8229' => 'twodotenleader',         # 0x2025 # Adobe Glyph List
            '8230' => 'ellipsis',               # 0x2026 # Adobe Glyph List
            '8236' => 'afii61573',              # 0x202C # Adobe Glyph List
            '8237' => 'afii61574',              # 0x202D # Adobe Glyph List
            '8238' => 'afii61575',              # 0x202E # Adobe Glyph List
            '8240' => 'perthousand',            # 0x2030 # Adobe Glyph List
            '8242' => 'minute',                 # 0x2032 # Adobe Glyph List
            '8243' => 'second',                 # 0x2033 # Adobe Glyph List
            '8249' => 'guilsinglleft',          # 0x2039 # Adobe Glyph List
            '8250' => 'guilsinglright',         # 0x203A # Adobe Glyph List
            '8252' => 'exclamdbl',              # 0x203C # Adobe Glyph List
            '8254' => 'overline',               # 0x203E # WGL4 Substitute
            '8260' => 'fraction',               # 0x2044 # Adobe Glyph List
            '8304' => 'zerosuperior',           # 0x2070 # Adobe Glyph List
            '8308' => 'foursuperior',           # 0x2074 # Adobe Glyph List
            '8309' => 'fivesuperior',           # 0x2075 # Adobe Glyph List
            '8310' => 'sixsuperior',            # 0x2076 # Adobe Glyph List
            '8311' => 'sevensuperior',          # 0x2077 # Adobe Glyph List
            '8312' => 'eightsuperior',          # 0x2078 # Adobe Glyph List
            '8313' => 'ninesuperior',           # 0x2079 # Adobe Glyph List
            '8317' => 'parenleftsuperior',      # 0x207D # Adobe Glyph List
            '8318' => 'parenrightsuperior',     # 0x207E # Adobe Glyph List
            '8319' => 'nsuperior',              # 0x207F # Adobe Glyph List
            '8320' => 'zeroinferior',           # 0x2080 # Adobe Glyph List
            '8321' => 'oneinferior',            # 0x2081 # Adobe Glyph List
            '8322' => 'twoinferior',            # 0x2082 # Adobe Glyph List
            '8323' => 'threeinferior',          # 0x2083 # Adobe Glyph List
            '8324' => 'fourinferior',           # 0x2084 # Adobe Glyph List
            '8325' => 'fiveinferior',           # 0x2085 # Adobe Glyph List
            '8326' => 'sixinferior',            # 0x2086 # Adobe Glyph List
            '8327' => 'seveninferior',          # 0x2087 # Adobe Glyph List
            '8328' => 'eightinferior',          # 0x2088 # Adobe Glyph List
            '8329' => 'nineinferior',           # 0x2089 # Adobe Glyph List
            '8333' => 'parenleftinferior',      # 0x208D # Adobe Glyph List
            '8334' => 'parenrightinferior',     # 0x208E # Adobe Glyph List
            '8353' => 'colonmonetary',          # 0x20A1 # Adobe Glyph List
            '8355' => 'franc',                  # 0x20A3 # Adobe Glyph List
            '8356' => 'lira',                   # 0x20A4 # Adobe Glyph List
            '8359' => 'peseta',                 # 0x20A7 # Adobe Glyph List
            '8362' => 'afii57636',              # 0x20AA # Adobe Glyph List
            '8363' => 'dong',                   # 0x20AB # Adobe Glyph List
            '8364' => 'Euro',                   # 0x20AC # Adobe Glyph List
            '8453' => 'afii61248',              # 0x2105 # Adobe Glyph List
            '8465' => 'Ifraktur',               # 0x2111 # Adobe Glyph List
            '8467' => 'afii61289',              # 0x2113 # Adobe Glyph List
            '8470' => 'afii61352',              # 0x2116 # Adobe Glyph List
            '8472' => 'weierstrass',            # 0x2118 # Adobe Glyph List
            '8476' => 'Rfraktur',               # 0x211C # Adobe Glyph List
            '8478' => 'prescription',           # 0x211E # Adobe Glyph List
            '8482' => 'trademark',              # 0x2122 # Adobe Glyph List
            '8486' => 'Omega',                  # 0x2126 # Adobe Glyph List
            '8494' => 'estimated',              # 0x212E # Adobe Glyph List
            '8501' => 'aleph',                  # 0x2135 # Adobe Glyph List
            '8531' => 'onethird',               # 0x2153 # Adobe Glyph List
            '8532' => 'twothirds',              # 0x2154 # Adobe Glyph List
            '8539' => 'oneeighth',              # 0x215B # Adobe Glyph List
            '8540' => 'threeeighths',           # 0x215C # Adobe Glyph List
            '8541' => 'fiveeighths',            # 0x215D # Adobe Glyph List
            '8542' => 'seveneighths',           # 0x215E # Adobe Glyph List
            '8592' => 'arrowleft',              # 0x2190 # Adobe Glyph List
            '8593' => 'arrowup',                # 0x2191 # Adobe Glyph List
            '8594' => 'arrowright',             # 0x2192 # Adobe Glyph List
            '8595' => 'arrowdown',              # 0x2193 # Adobe Glyph List
            '8596' => 'arrowboth',              # 0x2194 # Adobe Glyph List
            '8597' => 'arrowupdn',              # 0x2195 # Adobe Glyph List
            '8616' => 'arrowupdnbse',           # 0x21A8 # Adobe Glyph List
            '8629' => 'carriagereturn',         # 0x21B5 # Adobe Glyph List
            '8656' => 'arrowdblleft',           # 0x21D0 # Adobe Glyph List
            '8657' => 'arrowdblup',             # 0x21D1 # Adobe Glyph List
            '8658' => 'arrowdblright',          # 0x21D2 # Adobe Glyph List
            '8659' => 'arrowdbldown',           # 0x21D3 # Adobe Glyph List
            '8660' => 'arrowdblboth',           # 0x21D4 # Adobe Glyph List
            '8704' => 'universal',              # 0x2200 # Adobe Glyph List
            '8706' => 'partialdiff',            # 0x2202 # Adobe Glyph List
            '8707' => 'existential',            # 0x2203 # Adobe Glyph List
            '8709' => 'emptyset',               # 0x2205 # Adobe Glyph List
            '8710' => 'Delta',                  # 0x2206 # Adobe Glyph List
            '8711' => 'gradient',               # 0x2207 # Adobe Glyph List
            '8712' => 'element',                # 0x2208 # Adobe Glyph List
            '8713' => 'notelement',             # 0x2209 # Adobe Glyph List
            '8715' => 'suchthat',               # 0x220B # Adobe Glyph List
            '8719' => 'product',                # 0x220F # Adobe Glyph List
            '8721' => 'summation',              # 0x2211 # Adobe Glyph List
            '8722' => 'minus',                  # 0x2212 # Adobe Glyph List
            '8725' => 'fraction',               # 0x2215 # Adobe Glyph List
            '8727' => 'asteriskmath',           # 0x2217 # Adobe Glyph List
            '8729' => 'periodcentered',         # 0x2219 # Adobe Glyph List
            '8730' => 'radical',                # 0x221A # Adobe Glyph List
            '8733' => 'proportional',           # 0x221D # Adobe Glyph List
            '8734' => 'infinity',               # 0x221E # Adobe Glyph List
            '8735' => 'orthogonal',             # 0x221F # Adobe Glyph List
            '8736' => 'angle',                  # 0x2220 # Adobe Glyph List
            '8743' => 'logicaland',             # 0x2227 # Adobe Glyph List
            '8744' => 'logicalor',              # 0x2228 # Adobe Glyph List
            '8745' => 'intersection',           # 0x2229 # Adobe Glyph List
            '8746' => 'union',                  # 0x222A # Adobe Glyph List
            '8747' => 'integral',               # 0x222B # Adobe Glyph List
            '8756' => 'therefore',              # 0x2234 # Adobe Glyph List
            '8764' => 'similar',                # 0x223C # Adobe Glyph List
            '8773' => 'congruent',              # 0x2245 # Adobe Glyph List
            '8776' => 'approxequal',            # 0x2248 # Adobe Glyph List
            '8800' => 'notequal',               # 0x2260 # Adobe Glyph List
            '8801' => 'equivalence',            # 0x2261 # Adobe Glyph List
            '8804' => 'lessequal',              # 0x2264 # Adobe Glyph List
            '8805' => 'greaterequal',           # 0x2265 # Adobe Glyph List
            '8834' => 'propersubset',           # 0x2282 # Adobe Glyph List
            '8835' => 'propersuperset',         # 0x2283 # Adobe Glyph List
            '8836' => 'notsubset',              # 0x2284 # Adobe Glyph List
            '8838' => 'reflexsubset',           # 0x2286 # Adobe Glyph List
            '8839' => 'reflexsuperset',         # 0x2287 # Adobe Glyph List
            '8853' => 'circleplus',             # 0x2295 # Adobe Glyph List
            '8855' => 'circlemultiply',         # 0x2297 # Adobe Glyph List
            '8869' => 'perpendicular',          # 0x22A5 # Adobe Glyph List
            '8901' => 'dotmath',                # 0x22C5 # Adobe Glyph List
            '8962' => 'house',                  # 0x2302 # Adobe Glyph List
            '8976' => 'revlogicalnot',          # 0x2310 # Adobe Glyph List
            '8992' => 'integraltp',             # 0x2320 # Adobe Glyph List
            '8993' => 'integralbt',             # 0x2321 # Adobe Glyph List
            '9001' => 'angleleft',              # 0x2329 # Adobe Glyph List
            '9002' => 'angleright',             # 0x232A # Adobe Glyph List
            '9312' => 'a120',                   # 0x2460 # WGL4 Substitute
            '9313' => 'a121',                   # 0x2461 # WGL4 Substitute
            '9314' => 'a122',                   # 0x2462 # WGL4 Substitute
            '9315' => 'a123',                   # 0x2463 # WGL4 Substitute
            '9316' => 'a124',                   # 0x2464 # WGL4 Substitute
            '9317' => 'a125',                   # 0x2465 # WGL4 Substitute
            '9318' => 'a126',                   # 0x2466 # WGL4 Substitute
            '9319' => 'a127',                   # 0x2467 # WGL4 Substitute
            '9320' => 'a128',                   # 0x2468 # WGL4 Substitute
            '9321' => 'a129',                   # 0x2469 # WGL4 Substitute
            '9472' => 'SF100000',               # 0x2500 # Adobe Glyph List
            '9474' => 'SF110000',               # 0x2502 # Adobe Glyph List
            '9484' => 'SF010000',               # 0x250C # Adobe Glyph List
            '9488' => 'SF030000',               # 0x2510 # Adobe Glyph List
            '9492' => 'SF020000',               # 0x2514 # Adobe Glyph List
            '9496' => 'SF040000',               # 0x2518 # Adobe Glyph List
            '9500' => 'SF080000',               # 0x251C # Adobe Glyph List
            '9508' => 'SF090000',               # 0x2524 # Adobe Glyph List
            '9516' => 'SF060000',               # 0x252C # Adobe Glyph List
            '9524' => 'SF070000',               # 0x2534 # Adobe Glyph List
            '9532' => 'SF050000',               # 0x253C # Adobe Glyph List
            '9552' => 'SF430000',               # 0x2550 # Adobe Glyph List
            '9553' => 'SF240000',               # 0x2551 # Adobe Glyph List
            '9554' => 'SF510000',               # 0x2552 # Adobe Glyph List
            '9555' => 'SF520000',               # 0x2553 # Adobe Glyph List
            '9556' => 'SF390000',               # 0x2554 # Adobe Glyph List
            '9557' => 'SF220000',               # 0x2555 # Adobe Glyph List
            '9558' => 'SF210000',               # 0x2556 # Adobe Glyph List
            '9559' => 'SF250000',               # 0x2557 # Adobe Glyph List
            '9560' => 'SF500000',               # 0x2558 # Adobe Glyph List
            '9561' => 'SF490000',               # 0x2559 # Adobe Glyph List
            '9562' => 'SF380000',               # 0x255A # Adobe Glyph List
            '9563' => 'SF280000',               # 0x255B # Adobe Glyph List
            '9564' => 'SF270000',               # 0x255C # Adobe Glyph List
            '9565' => 'SF260000',               # 0x255D # Adobe Glyph List
            '9566' => 'SF360000',               # 0x255E # Adobe Glyph List
            '9567' => 'SF370000',               # 0x255F # Adobe Glyph List
            '9568' => 'SF420000',               # 0x2560 # Adobe Glyph List
            '9569' => 'SF190000',               # 0x2561 # Adobe Glyph List
            '9570' => 'SF200000',               # 0x2562 # Adobe Glyph List
            '9571' => 'SF230000',               # 0x2563 # Adobe Glyph List
            '9572' => 'SF470000',               # 0x2564 # Adobe Glyph List
            '9573' => 'SF480000',               # 0x2565 # Adobe Glyph List
            '9574' => 'SF410000',               # 0x2566 # Adobe Glyph List
            '9575' => 'SF450000',               # 0x2567 # Adobe Glyph List
            '9576' => 'SF460000',               # 0x2568 # Adobe Glyph List
            '9577' => 'SF400000',               # 0x2569 # Adobe Glyph List
            '9578' => 'SF540000',               # 0x256A # Adobe Glyph List
            '9579' => 'SF530000',               # 0x256B # Adobe Glyph List
            '9580' => 'SF440000',               # 0x256C # Adobe Glyph List
            '9600' => 'upblock',                # 0x2580 # Adobe Glyph List
            '9604' => 'dnblock',                # 0x2584 # Adobe Glyph List
            '9608' => 'block',                  # 0x2588 # Adobe Glyph List
            '9612' => 'lfblock',                # 0x258C # Adobe Glyph List
            '9616' => 'rtblock',                # 0x2590 # Adobe Glyph List
            '9617' => 'ltshade',                # 0x2591 # Adobe Glyph List
            '9618' => 'shade',                  # 0x2592 # Adobe Glyph List
            '9619' => 'dkshade',                # 0x2593 # Adobe Glyph List
            '9632' => 'filledbox',              # 0x25A0 # Adobe Glyph List
            '9633' => 'H22073',                 # 0x25A1 # Adobe Glyph List
            '9642' => 'H18543',                 # 0x25AA # Adobe Glyph List
            '9643' => 'H18551',                 # 0x25AB # Adobe Glyph List
            '9644' => 'filledrect',             # 0x25AC # Adobe Glyph List
            '9650' => 'triagup',                # 0x25B2 # Adobe Glyph List
            '9658' => 'triagrt',                # 0x25BA # Adobe Glyph List
            '9660' => 'triagdn',                # 0x25BC # Adobe Glyph List
            '9668' => 'triaglf',                # 0x25C4 # Adobe Glyph List
            '9670' => 'a78',                    # 0x25C6 # WGL4 Substitute
            '9674' => 'lozenge',                # 0x25CA # Adobe Glyph List
            '9675' => 'circle',                 # 0x25CB # Adobe Glyph List
            '9679' => 'H18533',                 # 0x25CF # Adobe Glyph List
            '9687' => 'a81',                    # 0x25D7 # WGL4 Substitute
            '9688' => 'invbullet',              # 0x25D8 # Adobe Glyph List
            '9689' => 'invcircle',              # 0x25D9 # Adobe Glyph List
            '9702' => 'openbullet',             # 0x25E6 # Adobe Glyph List
            '9733' => 'a35',                    # 0x2605 # WGL4 Substitute
            '9742' => 'a4',                     # 0x260E # WGL4 Substitute
            '9755' => 'a11',                    # 0x261B # WGL4 Substitute
            '9758' => 'a12',                    # 0x261E # WGL4 Substitute
            '9786' => 'smileface',              # 0x263A # Adobe Glyph List
            '9787' => 'invsmileface',           # 0x263B # Adobe Glyph List
            '9788' => 'sun',                    # 0x263C # Adobe Glyph List
            '9792' => 'female',                 # 0x2640 # Adobe Glyph List
            '9794' => 'male',                   # 0x2642 # Adobe Glyph List
            '9824' => 'spade',                  # 0x2660 # Adobe Glyph List
            '9827' => 'club',                   # 0x2663 # Adobe Glyph List
            '9829' => 'heart',                  # 0x2665 # Adobe Glyph List
            '9830' => 'diamond',                # 0x2666 # Adobe Glyph List
            '9834' => 'musicalnote',            # 0x266A # Adobe Glyph List
            '9835' => 'musicalnotedbl',         # 0x266B # Adobe Glyph List
            '9985' => 'a1',                     # 0x2701 # WGL4 Substitute
            '9986' => 'a2',                     # 0x2702 # WGL4 Substitute
            '9987' => 'a202',                   # 0x2703 # WGL4 Substitute
            '9988' => 'a3',                     # 0x2704 # WGL4 Substitute
            '9990' => 'a5',                     # 0x2706 # WGL4 Substitute
            '9991' => 'a119',                   # 0x2707 # WGL4 Substitute
            '9992' => 'a118',                   # 0x2708 # WGL4 Substitute
            '9993' => 'a117',                   # 0x2709 # WGL4 Substitute
            '9996' => 'a13',                    # 0x270C # WGL4 Substitute
            '9997' => 'a14',                    # 0x270D # WGL4 Substitute
            '9998' => 'a15',                    # 0x270E # WGL4 Substitute
            '9999' => 'a16',                    # 0x270F # WGL4 Substitute
            '10000' => 'a105',                  # 0x2710 # WGL4 Substitute
            '10001' => 'a17',                   # 0x2711 # WGL4 Substitute
            '10002' => 'a18',                   # 0x2712 # WGL4 Substitute
            '10003' => 'a19',                   # 0x2713 # WGL4 Substitute
            '10004' => 'a20',                   # 0x2714 # WGL4 Substitute
            '10005' => 'a21',                   # 0x2715 # WGL4 Substitute
            '10006' => 'a22',                   # 0x2716 # WGL4 Substitute
            '10007' => 'a23',                   # 0x2717 # WGL4 Substitute
            '10008' => 'a24',                   # 0x2718 # WGL4 Substitute
            '10009' => 'a25',                   # 0x2719 # WGL4 Substitute
            '10010' => 'a26',                   # 0x271A # WGL4 Substitute
            '10011' => 'a27',                   # 0x271B # WGL4 Substitute
            '10012' => 'a28',                   # 0x271C # WGL4 Substitute
            '10013' => 'a6',                    # 0x271D # WGL4 Substitute
            '10014' => 'a7',                    # 0x271E # WGL4 Substitute
            '10015' => 'a8',                    # 0x271F # WGL4 Substitute
            '10016' => 'a9',                    # 0x2720 # WGL4 Substitute
            '10017' => 'a10',                   # 0x2721 # WGL4 Substitute
            '10018' => 'a29',                   # 0x2722 # WGL4 Substitute
            '10019' => 'a30',                   # 0x2723 # WGL4 Substitute
            '10020' => 'a31',                   # 0x2724 # WGL4 Substitute
            '10021' => 'a32',                   # 0x2725 # WGL4 Substitute
            '10022' => 'a33',                   # 0x2726 # WGL4 Substitute
            '10023' => 'a34',                   # 0x2727 # WGL4 Substitute
            '10025' => 'a36',                   # 0x2729 # WGL4 Substitute
            '10026' => 'a37',                   # 0x272A # WGL4 Substitute
            '10027' => 'a38',                   # 0x272B # WGL4 Substitute
            '10028' => 'a39',                   # 0x272C # WGL4 Substitute
            '10029' => 'a40',                   # 0x272D # WGL4 Substitute
            '10030' => 'a41',                   # 0x272E # WGL4 Substitute
            '10031' => 'a42',                   # 0x272F # WGL4 Substitute
            '10032' => 'a43',                   # 0x2730 # WGL4 Substitute
            '10033' => 'a44',                   # 0x2731 # WGL4 Substitute
            '10034' => 'a45',                   # 0x2732 # WGL4 Substitute
            '10035' => 'a46',                   # 0x2733 # WGL4 Substitute
            '10036' => 'a47',                   # 0x2734 # WGL4 Substitute
            '10037' => 'a48',                   # 0x2735 # WGL4 Substitute
            '10038' => 'a49',                   # 0x2736 # WGL4 Substitute
            '10039' => 'a50',                   # 0x2737 # WGL4 Substitute
            '10040' => 'a51',                   # 0x2738 # WGL4 Substitute
            '10041' => 'a52',                   # 0x2739 # WGL4 Substitute
            '10042' => 'a53',                   # 0x273A # WGL4 Substitute
            '10043' => 'a54',                   # 0x273B # WGL4 Substitute
            '10044' => 'a55',                   # 0x273C # WGL4 Substitute
            '10045' => 'a56',                   # 0x273D # WGL4 Substitute
            '10046' => 'a57',                   # 0x273E # WGL4 Substitute
            '10047' => 'a58',                   # 0x273F # WGL4 Substitute
            '10048' => 'a59',                   # 0x2740 # WGL4 Substitute
            '10049' => 'a60',                   # 0x2741 # WGL4 Substitute
            '10050' => 'a61',                   # 0x2742 # WGL4 Substitute
            '10051' => 'a62',                   # 0x2743 # WGL4 Substitute
            '10052' => 'a63',                   # 0x2744 # WGL4 Substitute
            '10053' => 'a64',                   # 0x2745 # WGL4 Substitute
            '10054' => 'a65',                   # 0x2746 # WGL4 Substitute
            '10055' => 'a66',                   # 0x2747 # WGL4 Substitute
            '10056' => 'a67',                   # 0x2748 # WGL4 Substitute
            '10057' => 'a68',                   # 0x2749 # WGL4 Substitute
            '10058' => 'a69',                   # 0x274A # WGL4 Substitute
            '10059' => 'a70',                   # 0x274B # WGL4 Substitute
            '10061' => 'a72',                   # 0x274D # WGL4 Substitute
            '10063' => 'a74',                   # 0x274F # WGL4 Substitute
            '10064' => 'a203',                  # 0x2750 # WGL4 Substitute
            '10065' => 'a75',                   # 0x2751 # WGL4 Substitute
            '10066' => 'a204',                  # 0x2752 # WGL4 Substitute
            '10070' => 'a79',                   # 0x2756 # WGL4 Substitute
            '10072' => 'a82',                   # 0x2758 # WGL4 Substitute
            '10073' => 'a83',                   # 0x2759 # WGL4 Substitute
            '10074' => 'a84',                   # 0x275A # WGL4 Substitute
            '10075' => 'a97',                   # 0x275B # WGL4 Substitute
            '10076' => 'a98',                   # 0x275C # WGL4 Substitute
            '10077' => 'a99',                   # 0x275D # WGL4 Substitute
            '10078' => 'a100',                  # 0x275E # WGL4 Substitute
            '10081' => 'a101',                  # 0x2761 # WGL4 Substitute
            '10082' => 'a102',                  # 0x2762 # WGL4 Substitute
            '10083' => 'a103',                  # 0x2763 # WGL4 Substitute
            '10084' => 'a104',                  # 0x2764 # WGL4 Substitute
            '10085' => 'a106',                  # 0x2765 # WGL4 Substitute
            '10086' => 'a107',                  # 0x2766 # WGL4 Substitute
            '10087' => 'a108',                  # 0x2767 # WGL4 Substitute
            '10102' => 'a130',                  # 0x2776 # WGL4 Substitute
            '10103' => 'a131',                  # 0x2777 # WGL4 Substitute
            '10104' => 'a132',                  # 0x2778 # WGL4 Substitute
            '10105' => 'a133',                  # 0x2779 # WGL4 Substitute
            '10106' => 'a134',                  # 0x277A # WGL4 Substitute
            '10107' => 'a135',                  # 0x277B # WGL4 Substitute
            '10108' => 'a136',                  # 0x277C # WGL4 Substitute
            '10109' => 'a137',                  # 0x277D # WGL4 Substitute
            '10110' => 'a138',                  # 0x277E # WGL4 Substitute
            '10111' => 'a139',                  # 0x277F # WGL4 Substitute
            '10112' => 'a140',                  # 0x2780 # WGL4 Substitute
            '10113' => 'a141',                  # 0x2781 # WGL4 Substitute
            '10114' => 'a142',                  # 0x2782 # WGL4 Substitute
            '10115' => 'a143',                  # 0x2783 # WGL4 Substitute
            '10116' => 'a144',                  # 0x2784 # WGL4 Substitute
            '10117' => 'a145',                  # 0x2785 # WGL4 Substitute
            '10118' => 'a146',                  # 0x2786 # WGL4 Substitute
            '10119' => 'a147',                  # 0x2787 # WGL4 Substitute
            '10120' => 'a148',                  # 0x2788 # WGL4 Substitute
            '10121' => 'a149',                  # 0x2789 # WGL4 Substitute
            '10122' => 'a150',                  # 0x278A # WGL4 Substitute
            '10123' => 'a151',                  # 0x278B # WGL4 Substitute
            '10124' => 'a152',                  # 0x278C # WGL4 Substitute
            '10125' => 'a153',                  # 0x278D # WGL4 Substitute
            '10126' => 'a154',                  # 0x278E # WGL4 Substitute
            '10127' => 'a155',                  # 0x278F # WGL4 Substitute
            '10128' => 'a156',                  # 0x2790 # WGL4 Substitute
            '10129' => 'a157',                  # 0x2791 # WGL4 Substitute
            '10130' => 'a158',                  # 0x2792 # WGL4 Substitute
            '10131' => 'a159',                  # 0x2793 # WGL4 Substitute
            '10132' => 'a160',                  # 0x2794 # WGL4 Substitute
            '10136' => 'a196',                  # 0x2798 # WGL4 Substitute
            '10137' => 'a165',                  # 0x2799 # WGL4 Substitute
            '10138' => 'a192',                  # 0x279A # WGL4 Substitute
            '10139' => 'a166',                  # 0x279B # WGL4 Substitute
            '10140' => 'a167',                  # 0x279C # WGL4 Substitute
            '10141' => 'a168',                  # 0x279D # WGL4 Substitute
            '10142' => 'a169',                  # 0x279E # WGL4 Substitute
            '10143' => 'a170',                  # 0x279F # WGL4 Substitute
            '10144' => 'a171',                  # 0x27A0 # WGL4 Substitute
            '10145' => 'a172',                  # 0x27A1 # WGL4 Substitute
            '10146' => 'a173',                  # 0x27A2 # WGL4 Substitute
            '10147' => 'a162',                  # 0x27A3 # WGL4 Substitute
            '10148' => 'a174',                  # 0x27A4 # WGL4 Substitute
            '10149' => 'a175',                  # 0x27A5 # WGL4 Substitute
            '10150' => 'a176',                  # 0x27A6 # WGL4 Substitute
            '10151' => 'a177',                  # 0x27A7 # WGL4 Substitute
            '10152' => 'a178',                  # 0x27A8 # WGL4 Substitute
            '10153' => 'a179',                  # 0x27A9 # WGL4 Substitute
            '10154' => 'a193',                  # 0x27AA # WGL4 Substitute
            '10155' => 'a180',                  # 0x27AB # WGL4 Substitute
            '10156' => 'a199',                  # 0x27AC # WGL4 Substitute
            '10157' => 'a181',                  # 0x27AD # WGL4 Substitute
            '10158' => 'a200',                  # 0x27AE # WGL4 Substitute
            '10159' => 'a182',                  # 0x27AF # WGL4 Substitute
            '10161' => 'a201',                  # 0x27B1 # WGL4 Substitute
            '10162' => 'a183',                  # 0x27B2 # WGL4 Substitute
            '10163' => 'a184',                  # 0x27B3 # WGL4 Substitute
            '10164' => 'a197',                  # 0x27B4 # WGL4 Substitute
            '10165' => 'a185',                  # 0x27B5 # WGL4 Substitute
            '10166' => 'a194',                  # 0x27B6 # WGL4 Substitute
            '10167' => 'a198',                  # 0x27B7 # WGL4 Substitute
            '10168' => 'a186',                  # 0x27B8 # WGL4 Substitute
            '10169' => 'a195',                  # 0x27B9 # WGL4 Substitute
            '10170' => 'a187',                  # 0x27BA # WGL4 Substitute
            '10171' => 'a188',                  # 0x27BB # WGL4 Substitute
            '10172' => 'a189',                  # 0x27BC # WGL4 Substitute
            '10173' => 'a190',                  # 0x27BD # WGL4 Substitute
            '10174' => 'a191',                  # 0x27BE # WGL4 Substitute
            '61441' => 'fi',                    # 0xF001 # WGL4 Substitute
            '61442' => 'fl',                    # 0xF002 # WGL4 Substitute
            '61472' => 'space',                 # 0xF020 # MS Wingdings
            '61473' => 'pencil',                # 0xF021 # MS Wingdings
            '61474' => 'scissors',              # 0xF022 # MS Wingdings
            '61475' => 'scissorscutting',       # 0xF023 # MS Wingdings
            '61476' => 'readingglasses',        # 0xF024 # MS Wingdings
            '61477' => 'bell',                  # 0xF025 # MS Wingdings
            '61478' => 'book',                  # 0xF026 # MS Wingdings
            '61479' => 'candle',                # 0xF027 # MS Wingdings
            '61480' => 'telephonesolid',        # 0xF028 # MS Wingdings
            '61481' => 'telhandsetcirc',        # 0xF029 # MS Wingdings
            '61482' => 'envelopeback',          # 0xF02A # MS Wingdings
            '61483' => 'envelopefront',         # 0xF02B # MS Wingdings
            '61484' => 'mailboxflagdwn',        # 0xF02C # MS Wingdings
            '61485' => 'mailboxflagup',         # 0xF02D # MS Wingdings
            '61486' => 'mailbxopnflgup',        # 0xF02E # MS Wingdings
            '61487' => 'mailbxopnflgdwn',       # 0xF02F # MS Wingdings
            '61488' => 'folder',                # 0xF030 # MS Wingdings
            '61489' => 'folderopen',            # 0xF031 # MS Wingdings
            '61490' => 'filetalltext1',         # 0xF032 # MS Wingdings
            '61491' => 'filetalltext',          # 0xF033 # MS Wingdings
            '61492' => 'filetalltext3',         # 0xF034 # MS Wingdings
            '61493' => 'filecabinet',           # 0xF035 # MS Wingdings
            '61494' => 'hourglass',             # 0xF036 # MS Wingdings
            '61495' => 'keyboard',              # 0xF037 # MS Wingdings
            '61496' => 'mouse2button',          # 0xF038 # MS Wingdings
            '61497' => 'ballpoint',             # 0xF039 # MS Wingdings
            '61498' => 'pc',                    # 0xF03A # MS Wingdings
            '61499' => 'harddisk',              # 0xF03B # MS Wingdings
            '61500' => 'floppy3',               # 0xF03C # MS Wingdings
            '61501' => 'floppy5',               # 0xF03D # MS Wingdings
            '61502' => 'tapereel',              # 0xF03E # MS Wingdings
            '61503' => 'handwrite',             # 0xF03F # MS Wingdings
            '61504' => 'handwriteleft',         # 0xF040 # MS Wingdings
            '61505' => 'handv',                 # 0xF041 # MS Wingdings
            '61506' => 'handok',                # 0xF042 # MS Wingdings
            '61507' => 'thumbup',               # 0xF043 # MS Wingdings
            '61508' => 'thumbdown',             # 0xF044 # MS Wingdings
            '61509' => 'handptleft',            # 0xF045 # MS Wingdings
            '61510' => 'handptright',           # 0xF046 # MS Wingdings
            '61511' => 'handptup',              # 0xF047 # MS Wingdings
            '61512' => 'handptdwn',             # 0xF048 # MS Wingdings
            '61513' => 'handhalt',              # 0xF049 # MS Wingdings
            '61514' => 'smileface',             # 0xF04A # MS Wingdings
            '61515' => 'neutralface',           # 0xF04B # MS Wingdings
            '61516' => 'frownface',             # 0xF04C # MS Wingdings
            '61517' => 'bomb',                  # 0xF04D # MS Wingdings
            '61518' => 'skullcrossbones',       # 0xF04E # MS Wingdings
            '61519' => 'flag',                  # 0xF04F # MS Wingdings
            '61520' => 'pennant',               # 0xF050 # MS Wingdings
            '61521' => 'airplane',              # 0xF051 # MS Wingdings
            '61522' => 'sunshine',              # 0xF052 # MS Wingdings
            '61523' => 'droplet',               # 0xF053 # MS Wingdings
            '61524' => 'snowflake',             # 0xF054 # MS Wingdings
            '61525' => 'crossoutline',          # 0xF055 # MS Wingdings
            '61526' => 'crossshadow',           # 0xF056 # MS Wingdings
            '61527' => 'crossceltic',           # 0xF057 # MS Wingdings
            '61528' => 'crossmaltese',          # 0xF058 # MS Wingdings
            '61529' => 'starofdavid',           # 0xF059 # MS Wingdings
            '61530' => 'crescentstar',          # 0xF05A # MS Wingdings
            '61531' => 'yinyang',               # 0xF05B # MS Wingdings
            '61532' => 'om',                    # 0xF05C # MS Wingdings
            '61533' => 'wheel',                 # 0xF05D # MS Wingdings
            '61534' => 'aries',                 # 0xF05E # MS Wingdings
            '61535' => 'taurus',                # 0xF05F # MS Wingdings
            '61536' => 'gemini',                # 0xF060 # MS Wingdings
            '61537' => 'cancer',                # 0xF061 # MS Wingdings
            '61538' => 'leo',                   # 0xF062 # MS Wingdings
            '61539' => 'virgo',                 # 0xF063 # MS Wingdings
            '61540' => 'libra',                 # 0xF064 # MS Wingdings
            '61541' => 'scorpio',               # 0xF065 # MS Wingdings
            '61542' => 'saggitarius',           # 0xF066 # MS Wingdings
            '61543' => 'capricorn',             # 0xF067 # MS Wingdings
            '61544' => 'aquarius',              # 0xF068 # MS Wingdings
            '61545' => 'pisces',                # 0xF069 # MS Wingdings
            '61546' => 'ampersanditlc',         # 0xF06A # MS Wingdings
            '61547' => 'ampersandit',           # 0xF06B # MS Wingdings
            '61548' => 'circle6',               # 0xF06C # MS Wingdings
            '61549' => 'circleshadowdwn',       # 0xF06D # MS Wingdings
            '61550' => 'square6',               # 0xF06E # MS Wingdings
            '61551' => 'box3',                  # 0xF06F # MS Wingdings
            '61552' => 'box4',                  # 0xF070 # MS Wingdings
            '61553' => 'boxshadowdwn',          # 0xF071 # MS Wingdings
            '61554' => 'boxshadowup',           # 0xF072 # MS Wingdings
            '61555' => 'lozenge4',              # 0xF073 # MS Wingdings
            '61556' => 'lozenge6',              # 0xF074 # MS Wingdings
            '61557' => 'rhombus6',              # 0xF075 # MS Wingdings
            '61558' => 'xrhombus',              # 0xF076 # MS Wingdings
            '61559' => 'rhombus4',              # 0xF077 # MS Wingdings
            '61560' => 'clear',                 # 0xF078 # MS Wingdings
            '61561' => 'escape',                # 0xF079 # MS Wingdings
            '61562' => 'command',               # 0xF07A # MS Wingdings
            '61563' => 'rosette',               # 0xF07B # MS Wingdings
            '61564' => 'rosettesolid',          # 0xF07C # MS Wingdings
            '61565' => 'quotedbllftbld',        # 0xF07D # MS Wingdings
            '61566' => 'quotedblrtbld',         # 0xF07E # MS Wingdings
            '61568' => 'zerosans',              # 0xF080 # MS Wingdings
            '61569' => 'onesans',               # 0xF081 # MS Wingdings
            '61570' => 'twosans',               # 0xF082 # MS Wingdings
            '61571' => 'threesans',             # 0xF083 # MS Wingdings
            '61572' => 'foursans',              # 0xF084 # MS Wingdings
            '61573' => 'fivesans',              # 0xF085 # MS Wingdings
            '61574' => 'sixsans',               # 0xF086 # MS Wingdings
            '61575' => 'sevensans',             # 0xF087 # MS Wingdings
            '61576' => 'eightsans',             # 0xF088 # MS Wingdings
            '61577' => 'ninesans',              # 0xF089 # MS Wingdings
            '61578' => 'tensans',               # 0xF08A # MS Wingdings
            '61579' => 'zerosansinv',           # 0xF08B # MS Wingdings
            '61580' => 'onesansinv',            # 0xF08C # MS Wingdings
            '61581' => 'twosansinv',            # 0xF08D # MS Wingdings
            '61582' => 'threesansinv',          # 0xF08E # MS Wingdings
            '61583' => 'foursansinv',           # 0xF08F # MS Wingdings
            '61584' => 'fivesansinv',           # 0xF090 # MS Wingdings
            '61585' => 'sixsansinv',            # 0xF091 # MS Wingdings
            '61586' => 'sevensansinv',          # 0xF092 # MS Wingdings
            '61587' => 'eightsansinv',          # 0xF093 # MS Wingdings
            '61588' => 'ninesansinv',           # 0xF094 # MS Wingdings
            '61589' => 'tensansinv',            # 0xF095 # MS Wingdings
            '61590' => 'budleafne',             # 0xF096 # MS Wingdings
            '61591' => 'budleafnw',             # 0xF097 # MS Wingdings
            '61592' => 'budleafsw',             # 0xF098 # MS Wingdings
            '61593' => 'budleafse',             # 0xF099 # MS Wingdings
            '61594' => 'vineleafboldne',        # 0xF09A # MS Wingdings
            '61595' => 'vineleafboldnw',        # 0xF09B # MS Wingdings
            '61596' => 'vineleafboldsw',        # 0xF09C # MS Wingdings
            '61597' => 'vineleafboldse',        # 0xF09D # MS Wingdings
            '61598' => 'circle2',               # 0xF09E # MS Wingdings
            '61599' => 'circle4',               # 0xF09F # MS Wingdings
            '61600' => 'square2',               # 0xF0A0 # MS Wingdings
            '61601' => 'ring2',                 # 0xF0A1 # MS Wingdings
            '61602' => 'ring4',                 # 0xF0A2 # MS Wingdings
            '61603' => 'ring6',                 # 0xF0A3 # MS Wingdings
            '61604' => 'ringbutton2',           # 0xF0A4 # MS Wingdings
            '61605' => 'target',                # 0xF0A5 # MS Wingdings
            '61606' => 'circleshadowup',        # 0xF0A6 # MS Wingdings
            '61607' => 'square4',               # 0xF0A7 # MS Wingdings
            '61608' => 'box2',                  # 0xF0A8 # MS Wingdings
            '61609' => 'tristar2',              # 0xF0A9 # MS Wingdings
            '61610' => 'crosstar2',             # 0xF0AA # MS Wingdings
            '61611' => 'pentastar2',            # 0xF0AB # MS Wingdings
            '61612' => 'hexstar2',              # 0xF0AC # MS Wingdings
            '61613' => 'octastar2',             # 0xF0AD # MS Wingdings
            '61614' => 'dodecastar3',           # 0xF0AE # MS Wingdings
            '61615' => 'octastar4',             # 0xF0AF # MS Wingdings
            '61616' => 'registersquare',        # 0xF0B0 # MS Wingdings
            '61617' => 'registercircle',        # 0xF0B1 # MS Wingdings
            '61618' => 'cuspopen',              # 0xF0B2 # MS Wingdings
            '61619' => 'cuspopen1',             # 0xF0B3 # MS Wingdings
            '61620' => 'query',                 # 0xF0B4 # MS Wingdings
            '61621' => 'circlestar',            # 0xF0B5 # MS Wingdings
            '61622' => 'starshadow',            # 0xF0B6 # MS Wingdings
            '61623' => 'oneoclock',             # 0xF0B7 # MS Wingdings
            '61624' => 'twooclock',             # 0xF0B8 # MS Wingdings
            '61625' => 'threeoclock',           # 0xF0B9 # MS Wingdings
            '61626' => 'fouroclock',            # 0xF0BA # MS Wingdings
            '61627' => 'fiveoclock',            # 0xF0BB # MS Wingdings
            '61628' => 'sixoclock',             # 0xF0BC # MS Wingdings
            '61629' => 'sevenoclock',           # 0xF0BD # MS Wingdings
            '61630' => 'eightoclock',           # 0xF0BE # MS Wingdings
            '61631' => 'nineoclock',            # 0xF0BF # MS Wingdings
            '61632' => 'tenoclock',             # 0xF0C0 # MS Wingdings
            '61633' => 'elevenoclock',          # 0xF0C1 # MS Wingdings
            '61634' => 'twelveoclock',          # 0xF0C2 # MS Wingdings
            '61635' => 'arrowdwnleft1',         # 0xF0C3 # MS Wingdings
            '61636' => 'arrowdwnrt1',           # 0xF0C4 # MS Wingdings
            '61637' => 'arrowupleft1',          # 0xF0C5 # MS Wingdings
            '61638' => 'arrowuprt1',            # 0xF0C6 # MS Wingdings
            '61639' => 'arrowleftup1',          # 0xF0C7 # MS Wingdings
            '61640' => 'arrowrtup1',            # 0xF0C8 # MS Wingdings
            '61641' => 'arrowleftdwn1',         # 0xF0C9 # MS Wingdings
            '61642' => 'arrowrtdwn1',           # 0xF0CA # MS Wingdings
            '61643' => 'quiltsquare2',          # 0xF0CB # MS Wingdings
            '61644' => 'quiltsquare2inv',       # 0xF0CC # MS Wingdings
            '61645' => 'leafccwsw',             # 0xF0CD # MS Wingdings
            '61646' => 'leafccwnw',             # 0xF0CE # MS Wingdings
            '61647' => 'leafccwse',             # 0xF0CF # MS Wingdings
            '61648' => 'leafccwne',             # 0xF0D0 # MS Wingdings
            '61649' => 'leafnw',                # 0xF0D1 # MS Wingdings
            '61650' => 'leafsw',                # 0xF0D2 # MS Wingdings
            '61651' => 'leafne',                # 0xF0D3 # MS Wingdings
            '61652' => 'leafse',                # 0xF0D4 # MS Wingdings
            '61653' => 'deleteleft',            # 0xF0D5 # MS Wingdings
            '61654' => 'deleteright',           # 0xF0D6 # MS Wingdings
            '61655' => 'head2left',             # 0xF0D7 # MS Wingdings
            '61656' => 'head2right',            # 0xF0D8 # MS Wingdings
            '61657' => 'head2up',               # 0xF0D9 # MS Wingdings
            '61658' => 'head2down',             # 0xF0DA # MS Wingdings
            '61659' => 'circleleft',            # 0xF0DB # MS Wingdings
            '61660' => 'circleright',           # 0xF0DC # MS Wingdings
            '61661' => 'circleup',              # 0xF0DD # MS Wingdings
            '61662' => 'circledown',            # 0xF0DE # MS Wingdings
            '61663' => 'barb2left',             # 0xF0DF # MS Wingdings
            '61664' => 'barb2right',            # 0xF0E0 # MS Wingdings
            '61665' => 'barb2up',               # 0xF0E1 # MS Wingdings
            '61666' => 'barb2down',             # 0xF0E2 # MS Wingdings
            '61667' => 'barb2nw',               # 0xF0E3 # MS Wingdings
            '61668' => 'barb2ne',               # 0xF0E4 # MS Wingdings
            '61669' => 'barb2sw',               # 0xF0E5 # MS Wingdings
            '61670' => 'barb2se',               # 0xF0E6 # MS Wingdings
            '61671' => 'barb4left',             # 0xF0E7 # MS Wingdings
            '61672' => 'barb4right',            # 0xF0E8 # MS Wingdings
            '61673' => 'barb4up',               # 0xF0E9 # MS Wingdings
            '61674' => 'barb4down',             # 0xF0EA # MS Wingdings
            '61675' => 'barb4nw',               # 0xF0EB # MS Wingdings
            '61676' => 'barb4ne',               # 0xF0EC # MS Wingdings
            '61677' => 'barb4sw',               # 0xF0ED # MS Wingdings
            '61678' => 'barb4se',               # 0xF0EE # MS Wingdings
            '61679' => 'bleft',                 # 0xF0EF # MS Wingdings
            '61680' => 'bright',                # 0xF0F0 # MS Wingdings
            '61681' => 'bup',                   # 0xF0F1 # MS Wingdings
            '61682' => 'bdown',                 # 0xF0F2 # MS Wingdings
            '61683' => 'bleftright',            # 0xF0F3 # MS Wingdings
            '61684' => 'bupdown',               # 0xF0F4 # MS Wingdings
            '61685' => 'bnw',                   # 0xF0F5 # MS Wingdings
            '61686' => 'bne',                   # 0xF0F6 # MS Wingdings
            '61687' => 'bsw',                   # 0xF0F7 # MS Wingdings
            '61688' => 'bse',                   # 0xF0F8 # MS Wingdings
            '61689' => 'bdash1',                # 0xF0F9 # MS Wingdings
            '61690' => 'bdash2',                # 0xF0FA # MS Wingdings
            '61691' => 'xmarkbld',              # 0xF0FB # MS Wingdings
            '61692' => 'checkbld',              # 0xF0FC # MS Wingdings
            '61693' => 'boxxmarkbld',           # 0xF0FD # MS Wingdings
            '61694' => 'boxcheckbld',           # 0xF0FE # MS Wingdings
            '61695' => 'windowslogo',           # 0xF0FF # MS Wingdings
            '63166' => 'dotlessj',              # 0xF6BE # Adobe Glyph List
            '63167' => 'LL',                    # 0xF6BF # Adobe Glyph List
            '63168' => 'll',                    # 0xF6C0 # Adobe Glyph List
            '63169' => 'Scedilla',              # 0xF6C1 # Adobe Glyph List
            '63170' => 'scedilla',              # 0xF6C2 # Adobe Glyph List
            '63171' => 'commaaccent',           # 0xF6C3 # Adobe Glyph List
            '63172' => 'afii10063',             # 0xF6C4 # Adobe Glyph List
            '63173' => 'afii10064',             # 0xF6C5 # Adobe Glyph List
            '63174' => 'afii10192',             # 0xF6C6 # Adobe Glyph List
            '63175' => 'afii10831',             # 0xF6C7 # Adobe Glyph List
            '63176' => 'afii10832',             # 0xF6C8 # Adobe Glyph List
            '63177' => 'Acute',                 # 0xF6C9 # Adobe Glyph List
            '63178' => 'Caron',                 # 0xF6CA # Adobe Glyph List
            '63179' => 'Dieresis',              # 0xF6CB # Adobe Glyph List
            '63180' => 'DieresisAcute',         # 0xF6CC # Adobe Glyph List
            '63181' => 'DieresisGrave',         # 0xF6CD # Adobe Glyph List
            '63182' => 'Grave',                 # 0xF6CE # Adobe Glyph List
            '63183' => 'Hungarumlaut',          # 0xF6CF # Adobe Glyph List
            '63184' => 'Macron',                # 0xF6D0 # Adobe Glyph List
            '63185' => 'cyrBreve',              # 0xF6D1 # Adobe Glyph List
            '63186' => 'cyrFlex',               # 0xF6D2 # Adobe Glyph List
            '63187' => 'dblGrave',              # 0xF6D3 # Adobe Glyph List
            '63188' => 'cyrbreve',              # 0xF6D4 # Adobe Glyph List
            '63189' => 'cyrflex',               # 0xF6D5 # Adobe Glyph List
            '63190' => 'dblgrave',              # 0xF6D6 # Adobe Glyph List
            '63191' => 'dieresisacute',         # 0xF6D7 # Adobe Glyph List
            '63192' => 'dieresisgrave',         # 0xF6D8 # Adobe Glyph List
            '63193' => 'copyrightserif',        # 0xF6D9 # Adobe Glyph List
            '63194' => 'registerserif',         # 0xF6DA # Adobe Glyph List
            '63195' => 'trademarkserif',        # 0xF6DB # Adobe Glyph List
            '63196' => 'onefitted',             # 0xF6DC # Adobe Glyph List
            '63197' => 'rupiah',                # 0xF6DD # Adobe Glyph List
            '63198' => 'threequartersemdash',   # 0xF6DE # Adobe Glyph List
            '63199' => 'centinferior',          # 0xF6DF # Adobe Glyph List
            '63200' => 'centsuperior',          # 0xF6E0 # Adobe Glyph List
            '63201' => 'commainferior',         # 0xF6E1 # Adobe Glyph List
            '63202' => 'commasuperior',         # 0xF6E2 # Adobe Glyph List
            '63203' => 'dollarinferior',        # 0xF6E3 # Adobe Glyph List
            '63204' => 'dollarsuperior',        # 0xF6E4 # Adobe Glyph List
            '63205' => 'hypheninferior',        # 0xF6E5 # Adobe Glyph List
            '63206' => 'hyphensuperior',        # 0xF6E6 # Adobe Glyph List
            '63207' => 'periodinferior',        # 0xF6E7 # Adobe Glyph List
            '63208' => 'periodsuperior',        # 0xF6E8 # Adobe Glyph List
            '63209' => 'asuperior',             # 0xF6E9 # Adobe Glyph List
            '63210' => 'bsuperior',             # 0xF6EA # Adobe Glyph List
            '63211' => 'dsuperior',             # 0xF6EB # Adobe Glyph List
            '63212' => 'esuperior',             # 0xF6EC # Adobe Glyph List
            '63213' => 'isuperior',             # 0xF6ED # Adobe Glyph List
            '63214' => 'lsuperior',             # 0xF6EE # Adobe Glyph List
            '63215' => 'msuperior',             # 0xF6EF # Adobe Glyph List
            '63216' => 'osuperior',             # 0xF6F0 # Adobe Glyph List
            '63217' => 'rsuperior',             # 0xF6F1 # Adobe Glyph List
            '63218' => 'ssuperior',             # 0xF6F2 # Adobe Glyph List
            '63219' => 'tsuperior',             # 0xF6F3 # Adobe Glyph List
            '63220' => 'Brevesmall',            # 0xF6F4 # Adobe Glyph List
            '63221' => 'Caronsmall',            # 0xF6F5 # Adobe Glyph List
            '63222' => 'Circumflexsmall',       # 0xF6F6 # Adobe Glyph List
            '63223' => 'Dotaccentsmall',        # 0xF6F7 # Adobe Glyph List
            '63224' => 'Hungarumlautsmall',     # 0xF6F8 # Adobe Glyph List
            '63225' => 'Lslashsmall',           # 0xF6F9 # Adobe Glyph List
            '63226' => 'OEsmall',               # 0xF6FA # Adobe Glyph List
            '63227' => 'Ogoneksmall',           # 0xF6FB # Adobe Glyph List
            '63228' => 'Ringsmall',             # 0xF6FC # Adobe Glyph List
            '63229' => 'Scaronsmall',           # 0xF6FD # Adobe Glyph List
            '63230' => 'Tildesmall',            # 0xF6FE # Adobe Glyph List
            '63231' => 'Zcaronsmall',           # 0xF6FF # Adobe Glyph List
            '63265' => 'exclamsmall',           # 0xF721 # Adobe Glyph List
            '63268' => 'dollaroldstyle',        # 0xF724 # Adobe Glyph List
            '63270' => 'ampersandsmall',        # 0xF726 # Adobe Glyph List
            '63280' => 'zerooldstyle',          # 0xF730 # Adobe Glyph List
            '63281' => 'oneoldstyle',           # 0xF731 # Adobe Glyph List
            '63282' => 'twooldstyle',           # 0xF732 # Adobe Glyph List
            '63283' => 'threeoldstyle',         # 0xF733 # Adobe Glyph List
            '63284' => 'fouroldstyle',          # 0xF734 # Adobe Glyph List
            '63285' => 'fiveoldstyle',          # 0xF735 # Adobe Glyph List
            '63286' => 'sixoldstyle',           # 0xF736 # Adobe Glyph List
            '63287' => 'sevenoldstyle',         # 0xF737 # Adobe Glyph List
            '63288' => 'eightoldstyle',         # 0xF738 # Adobe Glyph List
            '63289' => 'nineoldstyle',          # 0xF739 # Adobe Glyph List
            '63295' => 'questionsmall',         # 0xF73F # Adobe Glyph List
            '63328' => 'Gravesmall',            # 0xF760 # Adobe Glyph List
            '63329' => 'Asmall',                # 0xF761 # Adobe Glyph List
            '63330' => 'Bsmall',                # 0xF762 # Adobe Glyph List
            '63331' => 'Csmall',                # 0xF763 # Adobe Glyph List
            '63332' => 'Dsmall',                # 0xF764 # Adobe Glyph List
            '63333' => 'Esmall',                # 0xF765 # Adobe Glyph List
            '63334' => 'Fsmall',                # 0xF766 # Adobe Glyph List
            '63335' => 'Gsmall',                # 0xF767 # Adobe Glyph List
            '63336' => 'Hsmall',                # 0xF768 # Adobe Glyph List
            '63337' => 'Ismall',                # 0xF769 # Adobe Glyph List
            '63338' => 'Jsmall',                # 0xF76A # Adobe Glyph List
            '63339' => 'Ksmall',                # 0xF76B # Adobe Glyph List
            '63340' => 'Lsmall',                # 0xF76C # Adobe Glyph List
            '63341' => 'Msmall',                # 0xF76D # Adobe Glyph List
            '63342' => 'Nsmall',                # 0xF76E # Adobe Glyph List
            '63343' => 'Osmall',                # 0xF76F # Adobe Glyph List
            '63344' => 'Psmall',                # 0xF770 # Adobe Glyph List
            '63345' => 'Qsmall',                # 0xF771 # Adobe Glyph List
            '63346' => 'Rsmall',                # 0xF772 # Adobe Glyph List
            '63347' => 'Ssmall',                # 0xF773 # Adobe Glyph List
            '63348' => 'Tsmall',                # 0xF774 # Adobe Glyph List
            '63349' => 'Usmall',                # 0xF775 # Adobe Glyph List
            '63350' => 'Vsmall',                # 0xF776 # Adobe Glyph List
            '63351' => 'Wsmall',                # 0xF777 # Adobe Glyph List
            '63352' => 'Xsmall',                # 0xF778 # Adobe Glyph List
            '63353' => 'Ysmall',                # 0xF779 # Adobe Glyph List
            '63354' => 'Zsmall',                # 0xF77A # Adobe Glyph List
            '63393' => 'exclamdownsmall',       # 0xF7A1 # Adobe Glyph List
            '63394' => 'centoldstyle',          # 0xF7A2 # Adobe Glyph List
            '63400' => 'Dieresissmall',         # 0xF7A8 # Adobe Glyph List
            '63407' => 'Macronsmall',           # 0xF7AF # Adobe Glyph List
            '63412' => 'Acutesmall',            # 0xF7B4 # Adobe Glyph List
            '63416' => 'Cedillasmall',          # 0xF7B8 # Adobe Glyph List
            '63423' => 'questiondownsmall',     # 0xF7BF # Adobe Glyph List
            '63456' => 'Agravesmall',           # 0xF7E0 # Adobe Glyph List
            '63457' => 'Aacutesmall',           # 0xF7E1 # Adobe Glyph List
            '63458' => 'Acircumflexsmall',      # 0xF7E2 # Adobe Glyph List
            '63459' => 'Atildesmall',           # 0xF7E3 # Adobe Glyph List
            '63460' => 'Adieresissmall',        # 0xF7E4 # Adobe Glyph List
            '63461' => 'Aringsmall',            # 0xF7E5 # Adobe Glyph List
            '63462' => 'AEsmall',               # 0xF7E6 # Adobe Glyph List
            '63463' => 'Ccedillasmall',         # 0xF7E7 # Adobe Glyph List
            '63464' => 'Egravesmall',           # 0xF7E8 # Adobe Glyph List
            '63465' => 'Eacutesmall',           # 0xF7E9 # Adobe Glyph List
            '63466' => 'Ecircumflexsmall',      # 0xF7EA # Adobe Glyph List
            '63467' => 'Edieresissmall',        # 0xF7EB # Adobe Glyph List
            '63468' => 'Igravesmall',           # 0xF7EC # Adobe Glyph List
            '63469' => 'Iacutesmall',           # 0xF7ED # Adobe Glyph List
            '63470' => 'Icircumflexsmall',      # 0xF7EE # Adobe Glyph List
            '63471' => 'Idieresissmall',        # 0xF7EF # Adobe Glyph List
            '63472' => 'Ethsmall',              # 0xF7F0 # Adobe Glyph List
            '63473' => 'Ntildesmall',           # 0xF7F1 # Adobe Glyph List
            '63474' => 'Ogravesmall',           # 0xF7F2 # Adobe Glyph List
            '63475' => 'Oacutesmall',           # 0xF7F3 # Adobe Glyph List
            '63476' => 'Ocircumflexsmall',      # 0xF7F4 # Adobe Glyph List
            '63477' => 'Otildesmall',           # 0xF7F5 # Adobe Glyph List
            '63478' => 'Odieresissmall',        # 0xF7F6 # Adobe Glyph List
            '63480' => 'Oslashsmall',           # 0xF7F8 # Adobe Glyph List
            '63481' => 'Ugravesmall',           # 0xF7F9 # Adobe Glyph List
            '63482' => 'Uacutesmall',           # 0xF7FA # Adobe Glyph List
            '63483' => 'Ucircumflexsmall',      # 0xF7FB # Adobe Glyph List
            '63484' => 'Udieresissmall',        # 0xF7FC # Adobe Glyph List
            '63485' => 'Yacutesmall',           # 0xF7FD # Adobe Glyph List
            '63486' => 'Thornsmall',            # 0xF7FE # Adobe Glyph List
            '63487' => 'Ydieresissmall',        # 0xF7FF # Adobe Glyph List
            '63703' => 'a89',                   # 0xF8D7 # WGL4 Substitute
            '63704' => 'a90',                   # 0xF8D8 # WGL4 Substitute
            '63705' => 'a93',                   # 0xF8D9 # WGL4 Substitute
            '63706' => 'a94',                   # 0xF8DA # WGL4 Substitute
            '63707' => 'a91',                   # 0xF8DB # WGL4 Substitute
            '63708' => 'a92',                   # 0xF8DC # WGL4 Substitute
            '63709' => 'a205',                  # 0xF8DD # WGL4 Substitute
            '63710' => 'a85',                   # 0xF8DE # WGL4 Substitute
            '63711' => 'a206',                  # 0xF8DF # WGL4 Substitute
            '63712' => 'a86',                   # 0xF8E0 # WGL4 Substitute
            '63713' => 'a87',                   # 0xF8E1 # WGL4 Substitute
            '63714' => 'a88',                   # 0xF8E2 # WGL4 Substitute
            '63715' => 'a95',                   # 0xF8E3 # WGL4 Substitute
            '63716' => 'a96',                   # 0xF8E4 # WGL4 Substitute
            '63717' => 'radicalex',             # 0xF8E5 # Adobe Glyph List
            '63718' => 'arrowvertex',           # 0xF8E6 # Adobe Glyph List
            '63719' => 'arrowhorizex',          # 0xF8E7 # Adobe Glyph List
            '63720' => 'registersans',          # 0xF8E8 # Adobe Glyph List
            '63721' => 'copyrightsans',         # 0xF8E9 # Adobe Glyph List
            '63722' => 'trademarksans',         # 0xF8EA # Adobe Glyph List
            '63723' => 'parenlefttp',           # 0xF8EB # Adobe Glyph List
            '63724' => 'parenleftex',           # 0xF8EC # Adobe Glyph List
            '63725' => 'parenleftbt',           # 0xF8ED # Adobe Glyph List
            '63726' => 'bracketlefttp',         # 0xF8EE # Adobe Glyph List
            '63727' => 'bracketleftex',         # 0xF8EF # Adobe Glyph List
            '63728' => 'bracketleftbt',         # 0xF8F0 # Adobe Glyph List
            '63729' => 'bracelefttp',           # 0xF8F1 # Adobe Glyph List
            '63730' => 'braceleftmid',          # 0xF8F2 # Adobe Glyph List
            '63731' => 'braceleftbt',           # 0xF8F3 # Adobe Glyph List
            '63732' => 'braceex',               # 0xF8F4 # Adobe Glyph List
            '63733' => 'integralex',            # 0xF8F5 # Adobe Glyph List
            '63734' => 'parenrighttp',          # 0xF8F6 # Adobe Glyph List
            '63735' => 'parenrightex',          # 0xF8F7 # Adobe Glyph List
            '63736' => 'parenrightbt',          # 0xF8F8 # Adobe Glyph List
            '63737' => 'bracketrighttp',        # 0xF8F9 # Adobe Glyph List
            '63738' => 'bracketrightex',        # 0xF8FA # Adobe Glyph List
            '63739' => 'bracketrightbt',        # 0xF8FB # Adobe Glyph List
            '63740' => 'bracerighttp',          # 0xF8FC # Adobe Glyph List
            '63741' => 'bracerightmid',         # 0xF8FD # Adobe Glyph List
            '63742' => 'bracerightbt',          # 0xF8FE # Adobe Glyph List
            '64256' => 'ff',                    # 0xFB00 # Adobe Glyph List
            '64257' => 'fi',                    # 0xFB01 # Adobe Glyph List
            '64258' => 'fl',                    # 0xFB02 # Adobe Glyph List
            '64259' => 'ffi',                   # 0xFB03 # Adobe Glyph List
            '64260' => 'ffl',                   # 0xFB04 # Adobe Glyph List
            '64287' => 'afii57705',             # 0xFB1F # Adobe Glyph List
            '64298' => 'afii57694',             # 0xFB2A # Adobe Glyph List
            '64299' => 'afii57695',             # 0xFB2B # Adobe Glyph List
            '64309' => 'afii57723',             # 0xFB35 # Adobe Glyph List
            '64331' => 'afii57700',             # 0xFB4B # Adobe Glyph List
    );
    %n2u_o=(
            'space' => '32',                    # 0x0020 # Adobe Glyph List
            'excl' => '33',                     # 0x0021 # SGML Substitute
            'exclam' => '33',                   # 0x0021 # Adobe Glyph List
            'quot' => '34',                     # 0x0022 # XML Substitute
            'quotedbl' => '34',                 # 0x0022 # Adobe Glyph List
            'num' => '35',                      # 0x0023 # SGML Substitute
            'numbersign' => '35',               # 0x0023 # Adobe Glyph List
            'dollar' => '36',                   # 0x0024 # Adobe Glyph List
            'percent' => '37',                  # 0x0025 # Adobe Glyph List
            'percnt' => '37',                   # 0x0025 # SGML Substitute
            'amp' => '38',                      # 0x0026 # XML Substitute
            'ampersand' => '38',                # 0x0026 # Adobe Glyph List
            'apos' => '39',                     # 0x0027 # XML Substitute
            'quotesingle' => '39',              # 0x0027 # Adobe Glyph List
            'lpar' => '40',                     # 0x0028 # SGML Substitute
            'parenleft' => '40',                # 0x0028 # Adobe Glyph List
            'parenright' => '41',               # 0x0029 # Adobe Glyph List
            'rpar' => '41',                     # 0x0029 # SGML Substitute
            'ast' => '42',                      # 0x002A # SGML Substitute
            'asterisk' => '42',                 # 0x002A # Adobe Glyph List
            'plus' => '43',                     # 0x002B # Adobe Glyph List
            'comma' => '44',                    # 0x002C # Adobe Glyph List
            'hyphen' => '45',                   # 0x002D # Adobe Glyph List
            'period' => '46',                   # 0x002E # Adobe Glyph List
            'slash' => '47',                    # 0x002F # Adobe Glyph List
            'sol' => '47',                      # 0x002F # SGML Substitute
            'zero' => '48',                     # 0x0030 # Adobe Glyph List
            'one' => '49',                      # 0x0031 # Adobe Glyph List
            'two' => '50',                      # 0x0032 # Adobe Glyph List
            'three' => '51',                    # 0x0033 # Adobe Glyph List
            'four' => '52',                     # 0x0034 # Adobe Glyph List
            'five' => '53',                     # 0x0035 # Adobe Glyph List
            'six' => '54',                      # 0x0036 # Adobe Glyph List
            'seven' => '55',                    # 0x0037 # Adobe Glyph List
            'eight' => '56',                    # 0x0038 # Adobe Glyph List
            'nine' => '57',                     # 0x0039 # Adobe Glyph List
            'colon' => '58',                    # 0x003A # Adobe Glyph List
            'semi' => '59',                     # 0x003B # SGML Substitute
            'semicolon' => '59',                # 0x003B # Adobe Glyph List
            'less' => '60',                     # 0x003C # Adobe Glyph List
            'lt' => '60',                       # 0x003C # XML Substitute
            'equal' => '61',                    # 0x003D # Adobe Glyph List
            'equals' => '61',                   # 0x003D # SGML Substitute
            'greater' => '62',                  # 0x003E # Adobe Glyph List
            'gt' => '62',                       # 0x003E # XML Substitute
            'quest' => '63',                    # 0x003F # SGML Substitute
            'question' => '63',                 # 0x003F # Adobe Glyph List
            'at' => '64',                       # 0x0040 # Adobe Glyph List
            'commat' => '64',                   # 0x0040 # SGML Substitute
            'A' => '65',                        # 0x0041 # Adobe Glyph List
            'B' => '66',                        # 0x0042 # Adobe Glyph List
            'C' => '67',                        # 0x0043 # Adobe Glyph List
            'D' => '68',                        # 0x0044 # Adobe Glyph List
            'E' => '69',                        # 0x0045 # Adobe Glyph List
            'F' => '70',                        # 0x0046 # Adobe Glyph List
            'G' => '71',                        # 0x0047 # Adobe Glyph List
            'H' => '72',                        # 0x0048 # Adobe Glyph List
            'I' => '73',                        # 0x0049 # Adobe Glyph List
            'J' => '74',                        # 0x004A # Adobe Glyph List
            'K' => '75',                        # 0x004B # Adobe Glyph List
            'L' => '76',                        # 0x004C # Adobe Glyph List
            'M' => '77',                        # 0x004D # Adobe Glyph List
            'N' => '78',                        # 0x004E # Adobe Glyph List
            'O' => '79',                        # 0x004F # Adobe Glyph List
            'P' => '80',                        # 0x0050 # Adobe Glyph List
            'Q' => '81',                        # 0x0051 # Adobe Glyph List
            'R' => '82',                        # 0x0052 # Adobe Glyph List
            'S' => '83',                        # 0x0053 # Adobe Glyph List
            'T' => '84',                        # 0x0054 # Adobe Glyph List
            'U' => '85',                        # 0x0055 # Adobe Glyph List
            'V' => '86',                        # 0x0056 # Adobe Glyph List
            'W' => '87',                        # 0x0057 # Adobe Glyph List
            'X' => '88',                        # 0x0058 # Adobe Glyph List
            'Y' => '89',                        # 0x0059 # Adobe Glyph List
            'Z' => '90',                        # 0x005A # Adobe Glyph List
            'bracketleft' => '91',              # 0x005B # Adobe Glyph List
            'lsqb' => '91',                     # 0x005B # SGML Substitute
            'backslash' => '92',                # 0x005C # Adobe Glyph List
            'bsol' => '92',                     # 0x005C # SGML Substitute
            'bracketright' => '93',             # 0x005D # Adobe Glyph List
            'rsqb' => '93',                     # 0x005D # SGML Substitute
            'asciicircum' => '94',              # 0x005E # Adobe Glyph List
            'lowbar' => '95',                   # 0x005F # SGML Substitute
            'underscore' => '95',               # 0x005F # Adobe Glyph List
            'grave' => '96',                    # 0x0060 # Adobe Glyph List
            'a' => '97',                        # 0x0061 # Adobe Glyph List
            'b' => '98',                        # 0x0062 # Adobe Glyph List
            'c' => '99',                        # 0x0063 # Adobe Glyph List
            'd' => '100',                       # 0x0064 # Adobe Glyph List
            'e' => '101',                       # 0x0065 # Adobe Glyph List
            'f' => '102',                       # 0x0066 # Adobe Glyph List
            'g' => '103',                       # 0x0067 # Adobe Glyph List
            'h' => '104',                       # 0x0068 # Adobe Glyph List
            'i' => '105',                       # 0x0069 # Adobe Glyph List
            'j' => '106',                       # 0x006A # Adobe Glyph List
            'k' => '107',                       # 0x006B # Adobe Glyph List
            'l' => '108',                       # 0x006C # Adobe Glyph List
            'm' => '109',                       # 0x006D # Adobe Glyph List
            'n' => '110',                       # 0x006E # Adobe Glyph List
            'o' => '111',                       # 0x006F # Adobe Glyph List
            'p' => '112',                       # 0x0070 # Adobe Glyph List
            'q' => '113',                       # 0x0071 # Adobe Glyph List
            'r' => '114',                       # 0x0072 # Adobe Glyph List
            's' => '115',                       # 0x0073 # Adobe Glyph List
            't' => '116',                       # 0x0074 # Adobe Glyph List
            'u' => '117',                       # 0x0075 # Adobe Glyph List
            'v' => '118',                       # 0x0076 # Adobe Glyph List
            'w' => '119',                       # 0x0077 # Adobe Glyph List
            'x' => '120',                       # 0x0078 # Adobe Glyph List
            'y' => '121',                       # 0x0079 # Adobe Glyph List
            'z' => '122',                       # 0x007A # Adobe Glyph List
            'braceleft' => '123',               # 0x007B # Adobe Glyph List
            'lcub' => '123',                    # 0x007B # SGML Substitute
            'bar' => '124',                     # 0x007C # Adobe Glyph List
            'verbar' => '124',                  # 0x007C # SGML Substitute
            'braceright' => '125',              # 0x007D # Adobe Glyph List
            'rcub' => '125',                    # 0x007D # SGML Substitute
            'asciitilde' => '126',              # 0x007E # Adobe Glyph List
            'nbsp' => '160',                    # 0x00A0 # XHTML Substitute
            'exclamdown' => '161',              # 0x00A1 # Adobe Glyph List
            'iexcl' => '161',                   # 0x00A1 # XHTML Substitute
            'cent' => '162',                    # 0x00A2 # Adobe Glyph List
            'pound' => '163',                   # 0x00A3 # XHTML Substitute
            'sterling' => '163',                # 0x00A3 # Adobe Glyph List
            'curren' => '164',                  # 0x00A4 # XHTML Substitute
            'currency' => '164',                # 0x00A4 # Adobe Glyph List
            'yen' => '165',                     # 0x00A5 # Adobe Glyph List
            'brokenbar' => '166',               # 0x00A6 # Adobe Glyph List
            'brvbar' => '166',                  # 0x00A6 # XHTML Substitute
            'sect' => '167',                    # 0x00A7 # XHTML Substitute
            'section' => '167',                 # 0x00A7 # Adobe Glyph List
            'Dot' => '168',                     # 0x00A8 # SGML Substitute
            'die' => '168',                     # 0x00A8 # SGML Substitute
            'dieresis' => '168',                # 0x00A8 # Adobe Glyph List
            'uml' => '168',                     # 0x00A8 # XHTML Substitute
            'copy' => '169',                    # 0x00A9 # XHTML Substitute
            'copyright' => '169',               # 0x00A9 # Adobe Glyph List
            'ordf' => '170',                    # 0x00AA # XHTML Substitute
            'ordfeminine' => '170',             # 0x00AA # Adobe Glyph List
            'guillemotleft' => '171',           # 0x00AB # Adobe Glyph List
            'laquo' => '171',                   # 0x00AB # XHTML Substitute
            'logicalnot' => '172',              # 0x00AC # Adobe Glyph List
            'not' => '172',                     # 0x00AC # XHTML Substitute
            'shy' => '173',                     # 0x00AD # XHTML Substitute
            'reg' => '174',                     # 0x00AE # XHTML Substitute
            'registered' => '174',              # 0x00AE # Adobe Glyph List
            'macr' => '175',                    # 0x00AF # XHTML Substitute
            'macron' => '175',                  # 0x00AF # Adobe Glyph List
            'deg' => '176',                     # 0x00B0 # XHTML Substitute
            'degree' => '176',                  # 0x00B0 # Adobe Glyph List
            'plusminus' => '177',               # 0x00B1 # Adobe Glyph List
            'plusmn' => '177',                  # 0x00B1 # XHTML Substitute
            'sup2' => '178',                    # 0x00B2 # XHTML Substitute
            'twosuperior' => '178',             # 0x00B2 # Adobe Glyph List
            'sup3' => '179',                    # 0x00B3 # XHTML Substitute
            'threesuperior' => '179',           # 0x00B3 # Adobe Glyph List
            'acute' => '180',                   # 0x00B4 # Adobe Glyph List
            'micro' => '181',                   # 0x00B5 # XHTML Substitute
            'mu' => '181',                      # 0x00B5 # Adobe Glyph List
            'para' => '182',                    # 0x00B6 # XHTML Substitute
            'paragraph' => '182',               # 0x00B6 # Adobe Glyph List
            'middot' => '183',                  # 0x00B7 # XHTML Substitute
            'periodcentered' => '183',          # 0x00B7 # Adobe Glyph List
            'cedil' => '184',                   # 0x00B8 # XHTML Substitute
            'cedilla' => '184',                 # 0x00B8 # Adobe Glyph List
            'onesuperior' => '185',             # 0x00B9 # Adobe Glyph List
            'sup1' => '185',                    # 0x00B9 # XHTML Substitute
            'ordm' => '186',                    # 0x00BA # XHTML Substitute
            'ordmasculine' => '186',            # 0x00BA # Adobe Glyph List
            'guillemotright' => '187',          # 0x00BB # Adobe Glyph List
            'raquo' => '187',                   # 0x00BB # XHTML Substitute
            'frac14' => '188',                  # 0x00BC # XHTML Substitute
            'onequarter' => '188',              # 0x00BC # Adobe Glyph List
            'frac12' => '189',                  # 0x00BD # XHTML Substitute
            'onehalf' => '189',                 # 0x00BD # Adobe Glyph List
            'frac34' => '190',                  # 0x00BE # XHTML Substitute
            'threequarters' => '190',           # 0x00BE # Adobe Glyph List
            'iquest' => '191',                  # 0x00BF # XHTML Substitute
            'questiondown' => '191',            # 0x00BF # Adobe Glyph List
            'Agrave' => '192',                  # 0x00C0 # Adobe Glyph List
            'Aacute' => '193',                  # 0x00C1 # Adobe Glyph List
            'Acirc' => '194',                   # 0x00C2 # XHTML Substitute
            'Acircumflex' => '194',             # 0x00C2 # Adobe Glyph List
            'Atilde' => '195',                  # 0x00C3 # Adobe Glyph List
            'Adieresis' => '196',               # 0x00C4 # Adobe Glyph List
            'Auml' => '196',                    # 0x00C4 # XHTML Substitute
            'Aring' => '197',                   # 0x00C5 # Adobe Glyph List
            'AE' => '198',                      # 0x00C6 # Adobe Glyph List
            'AElig' => '198',                   # 0x00C6 # XHTML Substitute
            'Ccedil' => '199',                  # 0x00C7 # XHTML Substitute
            'Ccedilla' => '199',                # 0x00C7 # Adobe Glyph List
            'Egrave' => '200',                  # 0x00C8 # Adobe Glyph List
            'Eacute' => '201',                  # 0x00C9 # Adobe Glyph List
            'Ecirc' => '202',                   # 0x00CA # XHTML Substitute
            'Ecircumflex' => '202',             # 0x00CA # Adobe Glyph List
            'Edieresis' => '203',               # 0x00CB # Adobe Glyph List
            'Euml' => '203',                    # 0x00CB # XHTML Substitute
            'Igrave' => '204',                  # 0x00CC # Adobe Glyph List
            'Iacute' => '205',                  # 0x00CD # Adobe Glyph List
            'Icirc' => '206',                   # 0x00CE # XHTML Substitute
            'Icircumflex' => '206',             # 0x00CE # Adobe Glyph List
            'Idieresis' => '207',               # 0x00CF # Adobe Glyph List
            'Iuml' => '207',                    # 0x00CF # XHTML Substitute
            'ETH' => '208',                     # 0x00D0 # XHTML Substitute
            'Eth' => '208',                     # 0x00D0 # Adobe Glyph List
            'Ntilde' => '209',                  # 0x00D1 # Adobe Glyph List
            'Ograve' => '210',                  # 0x00D2 # Adobe Glyph List
            'Oacute' => '211',                  # 0x00D3 # Adobe Glyph List
            'Ocirc' => '212',                   # 0x00D4 # XHTML Substitute
            'Ocircumflex' => '212',             # 0x00D4 # Adobe Glyph List
            'Otilde' => '213',                  # 0x00D5 # Adobe Glyph List
            'Odieresis' => '214',               # 0x00D6 # Adobe Glyph List
            'Ouml' => '214',                    # 0x00D6 # XHTML Substitute
            'multiply' => '215',                # 0x00D7 # Adobe Glyph List
            'times' => '215',                   # 0x00D7 # XHTML Substitute
            'Oslash' => '216',                  # 0x00D8 # Adobe Glyph List
            'Ugrave' => '217',                  # 0x00D9 # Adobe Glyph List
            'Uacute' => '218',                  # 0x00DA # Adobe Glyph List
            'Ucirc' => '219',                   # 0x00DB # XHTML Substitute
            'Ucircumflex' => '219',             # 0x00DB # Adobe Glyph List
            'Udieresis' => '220',               # 0x00DC # Adobe Glyph List
            'Uuml' => '220',                    # 0x00DC # XHTML Substitute
            'Yacute' => '221',                  # 0x00DD # Adobe Glyph List
            'THORN' => '222',                   # 0x00DE # XHTML Substitute
            'Thorn' => '222',                   # 0x00DE # Adobe Glyph List
            'germandbls' => '223',              # 0x00DF # Adobe Glyph List
            'szlig' => '223',                   # 0x00DF # XHTML Substitute
            'agrave' => '224',                  # 0x00E0 # Adobe Glyph List
            'aacute' => '225',                  # 0x00E1 # Adobe Glyph List
            'acirc' => '226',                   # 0x00E2 # XHTML Substitute
            'acircumflex' => '226',             # 0x00E2 # Adobe Glyph List
            'atilde' => '227',                  # 0x00E3 # Adobe Glyph List
            'adieresis' => '228',               # 0x00E4 # Adobe Glyph List
            'auml' => '228',                    # 0x00E4 # XHTML Substitute
            'aring' => '229',                   # 0x00E5 # Adobe Glyph List
            'ae' => '230',                      # 0x00E6 # Adobe Glyph List
            'aelig' => '230',                   # 0x00E6 # XHTML Substitute
            'ccedil' => '231',                  # 0x00E7 # XHTML Substitute
            'ccedilla' => '231',                # 0x00E7 # Adobe Glyph List
            'egrave' => '232',                  # 0x00E8 # Adobe Glyph List
            'eacute' => '233',                  # 0x00E9 # Adobe Glyph List
            'ecirc' => '234',                   # 0x00EA # XHTML Substitute
            'ecircumflex' => '234',             # 0x00EA # Adobe Glyph List
            'edieresis' => '235',               # 0x00EB # Adobe Glyph List
            'euml' => '235',                    # 0x00EB # XHTML Substitute
            'igrave' => '236',                  # 0x00EC # Adobe Glyph List
            'iacute' => '237',                  # 0x00ED # Adobe Glyph List
            'icirc' => '238',                   # 0x00EE # XHTML Substitute
            'icircumflex' => '238',             # 0x00EE # Adobe Glyph List
            'idieresis' => '239',               # 0x00EF # Adobe Glyph List
            'iuml' => '239',                    # 0x00EF # XHTML Substitute
            'eth' => '240',                     # 0x00F0 # Adobe Glyph List
            'ntilde' => '241',                  # 0x00F1 # Adobe Glyph List
            'ograve' => '242',                  # 0x00F2 # Adobe Glyph List
            'oacute' => '243',                  # 0x00F3 # Adobe Glyph List
            'ocirc' => '244',                   # 0x00F4 # XHTML Substitute
            'ocircumflex' => '244',             # 0x00F4 # Adobe Glyph List
            'otilde' => '245',                  # 0x00F5 # Adobe Glyph List
            'odieresis' => '246',               # 0x00F6 # Adobe Glyph List
            'ouml' => '246',                    # 0x00F6 # XHTML Substitute
            'divide' => '247',                  # 0x00F7 # Adobe Glyph List
            'oslash' => '248',                  # 0x00F8 # Adobe Glyph List
            'ugrave' => '249',                  # 0x00F9 # Adobe Glyph List
            'uacute' => '250',                  # 0x00FA # Adobe Glyph List
            'ucirc' => '251',                   # 0x00FB # XHTML Substitute
            'ucircumflex' => '251',             # 0x00FB # Adobe Glyph List
            'udieresis' => '252',               # 0x00FC # Adobe Glyph List
            'uuml' => '252',                    # 0x00FC # XHTML Substitute
            'yacute' => '253',                  # 0x00FD # Adobe Glyph List
            'thorn' => '254',                   # 0x00FE # Adobe Glyph List
            'ydieresis' => '255',               # 0x00FF # Adobe Glyph List
            'yuml' => '255',                    # 0x00FF # XHTML Substitute
            'Amacr' => '256',                   # 0x0100 # SGML Substitute
            'Amacron' => '256',                 # 0x0100 # Adobe Glyph List
            'amacr' => '257',                   # 0x0101 # SGML Substitute
            'amacron' => '257',                 # 0x0101 # Adobe Glyph List
            'Abreve' => '258',                  # 0x0102 # Adobe Glyph List
            'abreve' => '259',                  # 0x0103 # Adobe Glyph List
            'Aogon' => '260',                   # 0x0104 # SGML Substitute
            'Aogonek' => '260',                 # 0x0104 # Adobe Glyph List
            'aogon' => '261',                   # 0x0105 # SGML Substitute
            'aogonek' => '261',                 # 0x0105 # Adobe Glyph List
            'Cacute' => '262',                  # 0x0106 # Adobe Glyph List
            'cacute' => '263',                  # 0x0107 # Adobe Glyph List
            'Ccirc' => '264',                   # 0x0108 # SGML Substitute
            'Ccircumflex' => '264',             # 0x0108 # Adobe Glyph List
            'ccirc' => '265',                   # 0x0109 # SGML Substitute
            'ccircumflex' => '265',             # 0x0109 # Adobe Glyph List
            'Cdot' => '266',                    # 0x010A # SGML Substitute
            'Cdotaccent' => '266',              # 0x010A # Adobe Glyph List
            'cdot' => '267',                    # 0x010B # SGML Substitute
            'cdotaccent' => '267',              # 0x010B # Adobe Glyph List
            'Ccaron' => '268',                  # 0x010C # Adobe Glyph List
            'ccaron' => '269',                  # 0x010D # Adobe Glyph List
            'Dcaron' => '270',                  # 0x010E # Adobe Glyph List
            'dcaron' => '271',                  # 0x010F # Adobe Glyph List
            'Dcroat' => '272',                  # 0x0110 # Adobe Glyph List
            'Dstrok' => '272',                  # 0x0110 # SGML Substitute
            'dcroat' => '273',                  # 0x0111 # Adobe Glyph List
            'dstrok' => '273',                  # 0x0111 # SGML Substitute
            'Emacr' => '274',                   # 0x0112 # SGML Substitute
            'Emacron' => '274',                 # 0x0112 # Adobe Glyph List
            'emacr' => '275',                   # 0x0113 # SGML Substitute
            'emacron' => '275',                 # 0x0113 # Adobe Glyph List
            'Ebreve' => '276',                  # 0x0114 # Adobe Glyph List
            'ebreve' => '277',                  # 0x0115 # Adobe Glyph List
            'Edot' => '278',                    # 0x0116 # SGML Substitute
            'Edotaccent' => '278',              # 0x0116 # Adobe Glyph List
            'edot' => '279',                    # 0x0117 # SGML Substitute
            'edotaccent' => '279',              # 0x0117 # Adobe Glyph List
            'Eogon' => '280',                   # 0x0118 # SGML Substitute
            'Eogonek' => '280',                 # 0x0118 # Adobe Glyph List
            'eogon' => '281',                   # 0x0119 # SGML Substitute
            'eogonek' => '281',                 # 0x0119 # Adobe Glyph List
            'Ecaron' => '282',                  # 0x011A # Adobe Glyph List
            'ecaron' => '283',                  # 0x011B # Adobe Glyph List
            'Gcirc' => '284',                   # 0x011C # SGML Substitute
            'Gcircumflex' => '284',             # 0x011C # Adobe Glyph List
            'gcirc' => '285',                   # 0x011D # SGML Substitute
            'gcircumflex' => '285',             # 0x011D # Adobe Glyph List
            'Gbreve' => '286',                  # 0x011E # Adobe Glyph List
            'gbreve' => '287',                  # 0x011F # Adobe Glyph List
            'Gdot' => '288',                    # 0x0120 # SGML Substitute
            'Gdotaccent' => '288',              # 0x0120 # Adobe Glyph List
            'gdot' => '289',                    # 0x0121 # SGML Substitute
            'gdotaccent' => '289',              # 0x0121 # Adobe Glyph List
            'Gcedil' => '290',                  # 0x0122 # SGML Substitute
            'Gcommaaccent' => '290',            # 0x0122 # Adobe Glyph List
            'gcedil' => '291',                  # 0x0123 # SGML Substitute
            'gcommaaccent' => '291',            # 0x0123 # Adobe Glyph List
            'Hcirc' => '292',                   # 0x0124 # SGML Substitute
            'Hcircumflex' => '292',             # 0x0124 # Adobe Glyph List
            'hcirc' => '293',                   # 0x0125 # SGML Substitute
            'hcircumflex' => '293',             # 0x0125 # Adobe Glyph List
            'Hbar' => '294',                    # 0x0126 # Adobe Glyph List
            'Hstrok' => '294',                  # 0x0126 # SGML Substitute
            'hbar' => '295',                    # 0x0127 # Adobe Glyph List
            'hstrok' => '295',                  # 0x0127 # SGML Substitute
            'Itilde' => '296',                  # 0x0128 # Adobe Glyph List
            'itilde' => '297',                  # 0x0129 # Adobe Glyph List
            'Imacr' => '298',                   # 0x012A # SGML Substitute
            'Imacron' => '298',                 # 0x012A # Adobe Glyph List
            'imacr' => '299',                   # 0x012B # SGML Substitute
            'imacron' => '299',                 # 0x012B # Adobe Glyph List
            'Ibreve' => '300',                  # 0x012C # Adobe Glyph List
            'ibreve' => '301',                  # 0x012D # Adobe Glyph List
            'Iogon' => '302',                   # 0x012E # SGML Substitute
            'Iogonek' => '302',                 # 0x012E # Adobe Glyph List
            'iogon' => '303',                   # 0x012F # SGML Substitute
            'iogonek' => '303',                 # 0x012F # Adobe Glyph List
            'Idot' => '304',                    # 0x0130 # SGML Substitute
            'Idotaccent' => '304',              # 0x0130 # Adobe Glyph List
            'dotlessi' => '305',                # 0x0131 # Adobe Glyph List
            'inodot' => '305',                  # 0x0131 # SGML Substitute
            'IJ' => '306',                      # 0x0132 # Adobe Glyph List
            'IJlig' => '306',                   # 0x0132 # SGML Substitute
            'ij' => '307',                      # 0x0133 # Adobe Glyph List
            'ijlig' => '307',                   # 0x0133 # SGML Substitute
            'Jcirc' => '308',                   # 0x0134 # SGML Substitute
            'Jcircumflex' => '308',             # 0x0134 # Adobe Glyph List
            'jcirc' => '309',                   # 0x0135 # SGML Substitute
            'jcircumflex' => '309',             # 0x0135 # Adobe Glyph List
            'Kcedil' => '310',                  # 0x0136 # SGML Substitute
            'Kcommaaccent' => '310',            # 0x0136 # Adobe Glyph List
            'kcedil' => '311',                  # 0x0137 # SGML Substitute
            'kcommaaccent' => '311',            # 0x0137 # Adobe Glyph List
            'kgreen' => '312',                  # 0x0138 # SGML Substitute
            'kgreenlandic' => '312',            # 0x0138 # Adobe Glyph List
            'Lacute' => '313',                  # 0x0139 # Adobe Glyph List
            'lacute' => '314',                  # 0x013A # Adobe Glyph List
            'Lcedil' => '315',                  # 0x013B # SGML Substitute
            'Lcommaaccent' => '315',            # 0x013B # Adobe Glyph List
            'lcedil' => '316',                  # 0x013C # SGML Substitute
            'lcommaaccent' => '316',            # 0x013C # Adobe Glyph List
            'Lcaron' => '317',                  # 0x013D # Adobe Glyph List
            'lcaron' => '318',                  # 0x013E # Adobe Glyph List
            'Ldot' => '319',                    # 0x013F # Adobe Glyph List
            'Lmidot' => '319',                  # 0x013F # SGML Substitute
            'ldot' => '320',                    # 0x0140 # Adobe Glyph List
            'lmidot' => '320',                  # 0x0140 # SGML Substitute
            'Lslash' => '321',                  # 0x0141 # Adobe Glyph List
            'Lstrok' => '321',                  # 0x0141 # SGML Substitute
            'lslash' => '322',                  # 0x0142 # Adobe Glyph List
            'lstrok' => '322',                  # 0x0142 # SGML Substitute
            'Nacute' => '323',                  # 0x0143 # Adobe Glyph List
            'nacute' => '324',                  # 0x0144 # Adobe Glyph List
            'Ncedil' => '325',                  # 0x0145 # SGML Substitute
            'Ncommaaccent' => '325',            # 0x0145 # Adobe Glyph List
            'ncedil' => '326',                  # 0x0146 # SGML Substitute
            'ncommaaccent' => '326',            # 0x0146 # Adobe Glyph List
            'Ncaron' => '327',                  # 0x0147 # Adobe Glyph List
            'ncaron' => '328',                  # 0x0148 # Adobe Glyph List
            'napos' => '329',                   # 0x0149 # SGML Substitute
            'napostrophe' => '329',             # 0x0149 # Adobe Glyph List
            'ENG' => '330',                     # 0x014A # SGML Substitute
            'Eng' => '330',                     # 0x014A # Adobe Glyph List
            'eng' => '331',                     # 0x014B # Adobe Glyph List
            'Omacr' => '332',                   # 0x014C # SGML Substitute
            'Omacron' => '332',                 # 0x014C # Adobe Glyph List
            'omacr' => '333',                   # 0x014D # SGML Substitute
            'omacron' => '333',                 # 0x014D # Adobe Glyph List
            'Obreve' => '334',                  # 0x014E # Adobe Glyph List
            'obreve' => '335',                  # 0x014F # Adobe Glyph List
            'Odblac' => '336',                  # 0x0150 # SGML Substitute
            'Ohungarumlaut' => '336',           # 0x0150 # Adobe Glyph List
            'odblac' => '337',                  # 0x0151 # SGML Substitute
            'ohungarumlaut' => '337',           # 0x0151 # Adobe Glyph List
            'OE' => '338',                      # 0x0152 # Adobe Glyph List
            'OElig' => '338',                   # 0x0152 # XHTML Substitute
            'oe' => '339',                      # 0x0153 # Adobe Glyph List
            'oelig' => '339',                   # 0x0153 # XHTML Substitute
            'Racute' => '340',                  # 0x0154 # Adobe Glyph List
            'racute' => '341',                  # 0x0155 # Adobe Glyph List
            'Rcedil' => '342',                  # 0x0156 # SGML Substitute
            'Rcommaaccent' => '342',            # 0x0156 # Adobe Glyph List
            'rcedil' => '343',                  # 0x0157 # SGML Substitute
            'rcommaaccent' => '343',            # 0x0157 # Adobe Glyph List
            'Rcaron' => '344',                  # 0x0158 # Adobe Glyph List
            'rcaron' => '345',                  # 0x0159 # Adobe Glyph List
            'Sacute' => '346',                  # 0x015A # Adobe Glyph List
            'sacute' => '347',                  # 0x015B # Adobe Glyph List
            'Scirc' => '348',                   # 0x015C # SGML Substitute
            'Scircumflex' => '348',             # 0x015C # Adobe Glyph List
            'scirc' => '349',                   # 0x015D # SGML Substitute
            'scircumflex' => '349',             # 0x015D # Adobe Glyph List
            'Scedil' => '350',                  # 0x015E # SGML Substitute
            'Scedilla' => '350',                # 0x015E # Adobe Glyph List
            'scedil' => '351',                  # 0x015F # SGML Substitute
            'scedilla' => '351',                # 0x015F # Adobe Glyph List
            'Scaron' => '352',                  # 0x0160 # Adobe Glyph List
            'scaron' => '353',                  # 0x0161 # Adobe Glyph List
            'Tcedil' => '354',                  # 0x0162 # SGML Substitute
            'Tcommaaccent' => '354',            # 0x0162 # Adobe Glyph List
            'tcedil' => '355',                  # 0x0163 # SGML Substitute
            'tcommaaccent' => '355',            # 0x0163 # Adobe Glyph List
            'Tcaron' => '356',                  # 0x0164 # Adobe Glyph List
            'tcaron' => '357',                  # 0x0165 # Adobe Glyph List
            'Tbar' => '358',                    # 0x0166 # Adobe Glyph List
            'Tstrok' => '358',                  # 0x0166 # SGML Substitute
            'tbar' => '359',                    # 0x0167 # Adobe Glyph List
            'tstrok' => '359',                  # 0x0167 # SGML Substitute
            'Utilde' => '360',                  # 0x0168 # Adobe Glyph List
            'utilde' => '361',                  # 0x0169 # Adobe Glyph List
            'Umacr' => '362',                   # 0x016A # SGML Substitute
            'Umacron' => '362',                 # 0x016A # Adobe Glyph List
            'umacr' => '363',                   # 0x016B # SGML Substitute
            'umacron' => '363',                 # 0x016B # Adobe Glyph List
            'Ubreve' => '364',                  # 0x016C # Adobe Glyph List
            'ubreve' => '365',                  # 0x016D # Adobe Glyph List
            'Uring' => '366',                   # 0x016E # Adobe Glyph List
            'uring' => '367',                   # 0x016F # Adobe Glyph List
            'Udblac' => '368',                  # 0x0170 # SGML Substitute
            'Uhungarumlaut' => '368',           # 0x0170 # Adobe Glyph List
            'udblac' => '369',                  # 0x0171 # SGML Substitute
            'uhungarumlaut' => '369',           # 0x0171 # Adobe Glyph List
            'Uogon' => '370',                   # 0x0172 # SGML Substitute
            'Uogonek' => '370',                 # 0x0172 # Adobe Glyph List
            'uogon' => '371',                   # 0x0173 # SGML Substitute
            'uogonek' => '371',                 # 0x0173 # Adobe Glyph List
            'Wcirc' => '372',                   # 0x0174 # SGML Substitute
            'Wcircumflex' => '372',             # 0x0174 # Adobe Glyph List
            'wcirc' => '373',                   # 0x0175 # SGML Substitute
            'wcircumflex' => '373',             # 0x0175 # Adobe Glyph List
            'Ycirc' => '374',                   # 0x0176 # SGML Substitute
            'Ycircumflex' => '374',             # 0x0176 # Adobe Glyph List
            'ycirc' => '375',                   # 0x0177 # SGML Substitute
            'ycircumflex' => '375',             # 0x0177 # Adobe Glyph List
            'Ydieresis' => '376',               # 0x0178 # Adobe Glyph List
            'Yuml' => '376',                    # 0x0178 # XHTML Substitute
            'Zacute' => '377',                  # 0x0179 # Adobe Glyph List
            'zacute' => '378',                  # 0x017A # Adobe Glyph List
            'Zdot' => '379',                    # 0x017B # SGML Substitute
            'Zdotaccent' => '379',              # 0x017B # Adobe Glyph List
            'zdot' => '380',                    # 0x017C # SGML Substitute
            'zdotaccent' => '380',              # 0x017C # Adobe Glyph List
            'Zcaron' => '381',                  # 0x017D # Adobe Glyph List
            'zcaron' => '382',                  # 0x017E # Adobe Glyph List
            'longs' => '383',                   # 0x017F # Adobe Glyph List
            'florin' => '402',                  # 0x0192 # Adobe Glyph List
            'fnof' => '402',                    # 0x0192 # XHTML Substitute
            'Ohorn' => '416',                   # 0x01A0 # Adobe Glyph List
            'ohorn' => '417',                   # 0x01A1 # Adobe Glyph List
            'Uhorn' => '431',                   # 0x01AF # Adobe Glyph List
            'uhorn' => '432',                   # 0x01B0 # Adobe Glyph List
            'Gcaron' => '486',                  # 0x01E6 # Adobe Glyph List
            'gcaron' => '487',                  # 0x01E7 # Adobe Glyph List
            'Aringacute' => '506',              # 0x01FA # Adobe Glyph List
            'aringacute' => '507',              # 0x01FB # Adobe Glyph List
            'AEacute' => '508',                 # 0x01FC # Adobe Glyph List
            'aeacute' => '509',                 # 0x01FD # Adobe Glyph List
            'Oslashacute' => '510',             # 0x01FE # Adobe Glyph List
            'oslashacute' => '511',             # 0x01FF # Adobe Glyph List
            'Scommaaccent' => '536',            # 0x0218 # Adobe Glyph List
            'scommaaccent' => '537',            # 0x0219 # Adobe Glyph List
            'afii57929' => '700',               # 0x02BC # Adobe Glyph List
            'afii64937' => '701',               # 0x02BD # Adobe Glyph List
            'circ' => '710',                    # 0x02C6 # XHTML Substitute
            'circumflex' => '710',              # 0x02C6 # Adobe Glyph List
            'caron' => '711',                   # 0x02C7 # Adobe Glyph List
            'breve' => '728',                   # 0x02D8 # Adobe Glyph List
            'dot' => '729',                     # 0x02D9 # SGML Substitute
            'dotaccent' => '729',               # 0x02D9 # Adobe Glyph List
            'ring' => '730',                    # 0x02DA # Adobe Glyph List
            'ogon' => '731',                    # 0x02DB # SGML Substitute
            'ogonek' => '731',                  # 0x02DB # Adobe Glyph List
            'tilde' => '732',                   # 0x02DC # Adobe Glyph List
            'dblac' => '733',                   # 0x02DD # SGML Substitute
            'hungarumlaut' => '733',            # 0x02DD # Adobe Glyph List
            'gravecomb' => '768',               # 0x0300 # Adobe Glyph List
            'acutecomb' => '769',               # 0x0301 # Adobe Glyph List
            'tildecomb' => '771',               # 0x0303 # Adobe Glyph List
            'hookabovecomb' => '777',           # 0x0309 # Adobe Glyph List
            'dotbelowcomb' => '803',            # 0x0323 # Adobe Glyph List
            'tonos' => '900',                   # 0x0384 # Adobe Glyph List
            'dieresistonos' => '901',           # 0x0385 # Adobe Glyph List
            'Aacgr' => '902',                   # 0x0386 # SGML Substitute
            'Alphatonos' => '902',              # 0x0386 # Adobe Glyph List
            'anoteleia' => '903',               # 0x0387 # Adobe Glyph List
            'Eacgr' => '904',                   # 0x0388 # SGML Substitute
            'Epsilontonos' => '904',            # 0x0388 # Adobe Glyph List
            'EEacgr' => '905',                  # 0x0389 # SGML Substitute
            'Etatonos' => '905',                # 0x0389 # Adobe Glyph List
            'Iacgr' => '906',                   # 0x038A # SGML Substitute
            'Iotatonos' => '906',               # 0x038A # Adobe Glyph List
            'Oacgr' => '908',                   # 0x038C # SGML Substitute
            'Omicrontonos' => '908',            # 0x038C # Adobe Glyph List
            'Uacgr' => '910',                   # 0x038E # SGML Substitute
            'Upsilontonos' => '910',            # 0x038E # Adobe Glyph List
            'OHacgr' => '911',                  # 0x038F # SGML Substitute
            'Omegatonos' => '911',              # 0x038F # Adobe Glyph List
            'idiagr' => '912',                  # 0x0390 # SGML Substitute
            'iotadieresistonos' => '912',       # 0x0390 # Adobe Glyph List
            'Agr' => '913',                     # 0x0391 # SGML Substitute
            'Alpha' => '913',                   # 0x0391 # Adobe Glyph List
            'Beta' => '914',                    # 0x0392 # Adobe Glyph List
            'Bgr' => '914',                     # 0x0392 # SGML Substitute
            'Gamma' => '915',                   # 0x0393 # Adobe Glyph List
            'Ggr' => '915',                     # 0x0393 # SGML Substitute
            'Delta' => '916',                   # 0x0394 # Adobe Glyph List
            'Dgr' => '916',                     # 0x0394 # SGML Substitute
            'Egr' => '917',                     # 0x0395 # SGML Substitute
            'Epsilon' => '917',                 # 0x0395 # Adobe Glyph List
            'Zeta' => '918',                    # 0x0396 # Adobe Glyph List
            'Zgr' => '918',                     # 0x0396 # SGML Substitute
            'EEgr' => '919',                    # 0x0397 # SGML Substitute
            'Eta' => '919',                     # 0x0397 # Adobe Glyph List
            'THgr' => '920',                    # 0x0398 # SGML Substitute
            'Theta' => '920',                   # 0x0398 # Adobe Glyph List
            'Igr' => '921',                     # 0x0399 # SGML Substitute
            'Iota' => '921',                    # 0x0399 # Adobe Glyph List
            'Kappa' => '922',                   # 0x039A # Adobe Glyph List
            'Kgr' => '922',                     # 0x039A # SGML Substitute
            'Lambda' => '923',                  # 0x039B # Adobe Glyph List
            'Lgr' => '923',                     # 0x039B # SGML Substitute
            'Mgr' => '924',                     # 0x039C # SGML Substitute
            'Mu' => '924',                      # 0x039C # Adobe Glyph List
            'Ngr' => '925',                     # 0x039D # SGML Substitute
            'Nu' => '925',                      # 0x039D # Adobe Glyph List
            'Xgr' => '926',                     # 0x039E # SGML Substitute
            'Xi' => '926',                      # 0x039E # Adobe Glyph List
            'Ogr' => '927',                     # 0x039F # SGML Substitute
            'Omicron' => '927',                 # 0x039F # Adobe Glyph List
            'Pgr' => '928',                     # 0x03A0 # SGML Substitute
            'Pi' => '928',                      # 0x03A0 # Adobe Glyph List
            'Rgr' => '929',                     # 0x03A1 # SGML Substitute
            'Rho' => '929',                     # 0x03A1 # Adobe Glyph List
            'Sgr' => '931',                     # 0x03A3 # SGML Substitute
            'Sigma' => '931',                   # 0x03A3 # Adobe Glyph List
            'Tau' => '932',                     # 0x03A4 # Adobe Glyph List
            'Tgr' => '932',                     # 0x03A4 # SGML Substitute
            'Ugr' => '933',                     # 0x03A5 # SGML Substitute
            'Upsi' => '933',                    # 0x03A5 # SGML Substitute
            'Upsilon' => '933',                 # 0x03A5 # Adobe Glyph List
            'PHgr' => '934',                    # 0x03A6 # SGML Substitute
            'Phi' => '934',                     # 0x03A6 # Adobe Glyph List
            'Chi' => '935',                     # 0x03A7 # Adobe Glyph List
            'KHgr' => '935',                    # 0x03A7 # SGML Substitute
            'PSgr' => '936',                    # 0x03A8 # SGML Substitute
            'Psi' => '936',                     # 0x03A8 # Adobe Glyph List
            'OHgr' => '937',                    # 0x03A9 # SGML Substitute
            'Omega' => '937',                   # 0x03A9 # Adobe Glyph List
            'Idigr' => '938',                   # 0x03AA # SGML Substitute
            'Iotadieresis' => '938',            # 0x03AA # Adobe Glyph List
            'Udigr' => '939',                   # 0x03AB # SGML Substitute
            'Upsilondieresis' => '939',         # 0x03AB # Adobe Glyph List
            'aacgr' => '940',                   # 0x03AC # SGML Substitute
            'alphatonos' => '940',              # 0x03AC # Adobe Glyph List
            'eacgr' => '941',                   # 0x03AD # SGML Substitute
            'epsilontonos' => '941',            # 0x03AD # Adobe Glyph List
            'eeacgr' => '942',                  # 0x03AE # SGML Substitute
            'etatonos' => '942',                # 0x03AE # Adobe Glyph List
            'iacgr' => '943',                   # 0x03AF # SGML Substitute
            'iotatonos' => '943',               # 0x03AF # Adobe Glyph List
            'udiagr' => '944',                  # 0x03B0 # SGML Substitute
            'upsilondieresistonos' => '944',    # 0x03B0 # Adobe Glyph List
            'agr' => '945',                     # 0x03B1 # SGML Substitute
            'alpha' => '945',                   # 0x03B1 # Adobe Glyph List
            'beta' => '946',                    # 0x03B2 # Adobe Glyph List
            'bgr' => '946',                     # 0x03B2 # SGML Substitute
            'gamma' => '947',                   # 0x03B3 # Adobe Glyph List
            'ggr' => '947',                     # 0x03B3 # SGML Substitute
            'delta' => '948',                   # 0x03B4 # Adobe Glyph List
            'dgr' => '948',                     # 0x03B4 # SGML Substitute
            'egr' => '949',                     # 0x03B5 # SGML Substitute
            'epsi' => '949',                    # 0x03B5 # SGML Substitute
            'epsilon' => '949',                 # 0x03B5 # Adobe Glyph List
            'zeta' => '950',                    # 0x03B6 # Adobe Glyph List
            'zgr' => '950',                     # 0x03B6 # SGML Substitute
            'eegr' => '951',                    # 0x03B7 # SGML Substitute
            'eta' => '951',                     # 0x03B7 # Adobe Glyph List
            'theta' => '952',                   # 0x03B8 # Adobe Glyph List
            'thetas' => '952',                  # 0x03B8 # SGML Substitute
            'thgr' => '952',                    # 0x03B8 # SGML Substitute
            'igr' => '953',                     # 0x03B9 # SGML Substitute
            'iota' => '953',                    # 0x03B9 # Adobe Glyph List
            'kappa' => '954',                   # 0x03BA # Adobe Glyph List
            'kgr' => '954',                     # 0x03BA # SGML Substitute
            'lambda' => '955',                  # 0x03BB # Adobe Glyph List
            'lgr' => '955',                     # 0x03BB # SGML Substitute
            'mgr' => '956',                     # 0x03BC # SGML Substitute
            'ngr' => '957',                     # 0x03BD # SGML Substitute
            'nu' => '957',                      # 0x03BD # Adobe Glyph List
            'xgr' => '958',                     # 0x03BE # SGML Substitute
            'xi' => '958',                      # 0x03BE # Adobe Glyph List
            'ogr' => '959',                     # 0x03BF # SGML Substitute
            'omicron' => '959',                 # 0x03BF # Adobe Glyph List
            'pgr' => '960',                     # 0x03C0 # SGML Substitute
            'pi' => '960',                      # 0x03C0 # Adobe Glyph List
            'rgr' => '961',                     # 0x03C1 # SGML Substitute
            'rho' => '961',                     # 0x03C1 # Adobe Glyph List
            'sfgr' => '962',                    # 0x03C2 # SGML Substitute
            'sigma1' => '962',                  # 0x03C2 # Adobe Glyph List
            'sigmav' => '962',                  # 0x03C2 # SGML Substitute
            'sgr' => '963',                     # 0x03C3 # SGML Substitute
            'sigma' => '963',                   # 0x03C3 # Adobe Glyph List
            'tau' => '964',                     # 0x03C4 # Adobe Glyph List
            'tgr' => '964',                     # 0x03C4 # SGML Substitute
            'ugr' => '965',                     # 0x03C5 # SGML Substitute
            'upsi' => '965',                    # 0x03C5 # SGML Substitute
            'upsilon' => '965',                 # 0x03C5 # Adobe Glyph List
            'phgr' => '966',                    # 0x03C6 # SGML Substitute
            'phi' => '966',                     # 0x03C6 # Adobe Glyph List
            'phis' => '966',                    # 0x03C6 # SGML Substitute
            'chi' => '967',                     # 0x03C7 # Adobe Glyph List
            'khgr' => '967',                    # 0x03C7 # SGML Substitute
            'psgr' => '968',                    # 0x03C8 # SGML Substitute
            'psi' => '968',                     # 0x03C8 # Adobe Glyph List
            'ohgr' => '969',                    # 0x03C9 # SGML Substitute
            'omega' => '969',                   # 0x03C9 # Adobe Glyph List
            'idigr' => '970',                   # 0x03CA # SGML Substitute
            'iotadieresis' => '970',            # 0x03CA # Adobe Glyph List
            'udigr' => '971',                   # 0x03CB # SGML Substitute
            'upsilondieresis' => '971',         # 0x03CB # Adobe Glyph List
            'oacgr' => '972',                   # 0x03CC # SGML Substitute
            'omicrontonos' => '972',            # 0x03CC # Adobe Glyph List
            'uacgr' => '973',                   # 0x03CD # SGML Substitute
            'upsilontonos' => '973',            # 0x03CD # Adobe Glyph List
            'ohacgr' => '974',                  # 0x03CE # SGML Substitute
            'omegatonos' => '974',              # 0x03CE # Adobe Glyph List
            'theta1' => '977',                  # 0x03D1 # Adobe Glyph List
            'thetasym' => '977',                # 0x03D1 # XHTML Substitute
            'thetav' => '977',                  # 0x03D1 # SGML Substitute
            'Upsilon1' => '978',                # 0x03D2 # Adobe Glyph List
            'upsih' => '978',                   # 0x03D2 # XHTML Substitute
            'phi1' => '981',                    # 0x03D5 # Adobe Glyph List
            'phiv' => '981',                    # 0x03D5 # SGML Substitute
            'omega1' => '982',                  # 0x03D6 # Adobe Glyph List
            'piv' => '982',                     # 0x03D6 # XHTML Substitute
            'gammad' => '989',                  # 0x03DD # SGML Substitute
            'kappav' => '1008',                 # 0x03F0 # SGML Substitute
            'rhov' => '1009',                   # 0x03F1 # SGML Substitute
            'IOcy' => '1025',                   # 0x0401 # SGML Substitute
            'afii10023' => '1025',              # 0x0401 # Adobe Glyph List
            'DJcy' => '1026',                   # 0x0402 # SGML Substitute
            'afii10051' => '1026',              # 0x0402 # Adobe Glyph List
            'GJcy' => '1027',                   # 0x0403 # SGML Substitute
            'afii10052' => '1027',              # 0x0403 # Adobe Glyph List
            'Jukcy' => '1028',                  # 0x0404 # SGML Substitute
            'afii10053' => '1028',              # 0x0404 # Adobe Glyph List
            'DScy' => '1029',                   # 0x0405 # SGML Substitute
            'afii10054' => '1029',              # 0x0405 # Adobe Glyph List
            'Iukcy' => '1030',                  # 0x0406 # SGML Substitute
            'afii10055' => '1030',              # 0x0406 # Adobe Glyph List
            'YIcy' => '1031',                   # 0x0407 # SGML Substitute
            'afii10056' => '1031',              # 0x0407 # Adobe Glyph List
            'Jsercy' => '1032',                 # 0x0408 # SGML Substitute
            'afii10057' => '1032',              # 0x0408 # Adobe Glyph List
            'LJcy' => '1033',                   # 0x0409 # SGML Substitute
            'afii10058' => '1033',              # 0x0409 # Adobe Glyph List
            'NJcy' => '1034',                   # 0x040A # SGML Substitute
            'afii10059' => '1034',              # 0x040A # Adobe Glyph List
            'TSHcy' => '1035',                  # 0x040B # SGML Substitute
            'afii10060' => '1035',              # 0x040B # Adobe Glyph List
            'KJcy' => '1036',                   # 0x040C # SGML Substitute
            'afii10061' => '1036',              # 0x040C # Adobe Glyph List
            'Ubrcy' => '1038',                  # 0x040E # SGML Substitute
            'afii10062' => '1038',              # 0x040E # Adobe Glyph List
            'DZcy' => '1039',                   # 0x040F # SGML Substitute
            'afii10145' => '1039',              # 0x040F # Adobe Glyph List
            'Acy' => '1040',                    # 0x0410 # SGML Substitute
            'afii10017' => '1040',              # 0x0410 # Adobe Glyph List
            'Bcy' => '1041',                    # 0x0411 # SGML Substitute
            'afii10018' => '1041',              # 0x0411 # Adobe Glyph List
            'Vcy' => '1042',                    # 0x0412 # SGML Substitute
            'afii10019' => '1042',              # 0x0412 # Adobe Glyph List
            'Gcy' => '1043',                    # 0x0413 # SGML Substitute
            'afii10020' => '1043',              # 0x0413 # Adobe Glyph List
            'afii10021' => '1044',              # 0x0414 # Adobe Glyph List
            'dcy' => '1044',                    # 0x0414 # SGML Substitute
            'IEcy' => '1045',                   # 0x0415 # SGML Substitute
            'afii10022' => '1045',              # 0x0415 # Adobe Glyph List
            'ZHcy' => '1046',                   # 0x0416 # SGML Substitute
            'afii10024' => '1046',              # 0x0416 # Adobe Glyph List
            'Zcy' => '1047',                    # 0x0417 # SGML Substitute
            'afii10025' => '1047',              # 0x0417 # Adobe Glyph List
            'Icy' => '1048',                    # 0x0418 # SGML Substitute
            'afii10026' => '1048',              # 0x0418 # Adobe Glyph List
            'Jcy' => '1049',                    # 0x0419 # SGML Substitute
            'afii10027' => '1049',              # 0x0419 # Adobe Glyph List
            'Kcy' => '1050',                    # 0x041A # SGML Substitute
            'afii10028' => '1050',              # 0x041A # Adobe Glyph List
            'Lcy' => '1051',                    # 0x041B # SGML Substitute
            'afii10029' => '1051',              # 0x041B # Adobe Glyph List
            'Mcy' => '1052',                    # 0x041C # SGML Substitute
            'afii10030' => '1052',              # 0x041C # Adobe Glyph List
            'Ncy' => '1053',                    # 0x041D # SGML Substitute
            'afii10031' => '1053',              # 0x041D # Adobe Glyph List
            'Ocy' => '1054',                    # 0x041E # SGML Substitute
            'afii10032' => '1054',              # 0x041E # Adobe Glyph List
            'Pcy' => '1055',                    # 0x041F # SGML Substitute
            'afii10033' => '1055',              # 0x041F # Adobe Glyph List
            'Rcy' => '1056',                    # 0x0420 # SGML Substitute
            'afii10034' => '1056',              # 0x0420 # Adobe Glyph List
            'Scy' => '1057',                    # 0x0421 # SGML Substitute
            'afii10035' => '1057',              # 0x0421 # Adobe Glyph List
            'Tcy' => '1058',                    # 0x0422 # SGML Substitute
            'afii10036' => '1058',              # 0x0422 # Adobe Glyph List
            'Ucy' => '1059',                    # 0x0423 # SGML Substitute
            'afii10037' => '1059',              # 0x0423 # Adobe Glyph List
            'Fcy' => '1060',                    # 0x0424 # SGML Substitute
            'afii10038' => '1060',              # 0x0424 # Adobe Glyph List
            'KHcy' => '1061',                   # 0x0425 # SGML Substitute
            'afii10039' => '1061',              # 0x0425 # Adobe Glyph List
            'TScy' => '1062',                   # 0x0426 # SGML Substitute
            'afii10040' => '1062',              # 0x0426 # Adobe Glyph List
            'CHcy' => '1063',                   # 0x0427 # SGML Substitute
            'afii10041' => '1063',              # 0x0427 # Adobe Glyph List
            'SHcy' => '1064',                   # 0x0428 # SGML Substitute
            'afii10042' => '1064',              # 0x0428 # Adobe Glyph List
            'SHCHcy' => '1065',                 # 0x0429 # SGML Substitute
            'afii10043' => '1065',              # 0x0429 # Adobe Glyph List
            'HARDcy' => '1066',                 # 0x042A # SGML Substitute
            'afii10044' => '1066',              # 0x042A # Adobe Glyph List
            'Ycy' => '1067',                    # 0x042B # SGML Substitute
            'afii10045' => '1067',              # 0x042B # Adobe Glyph List
            'SOFTcy' => '1068',                 # 0x042C # SGML Substitute
            'afii10046' => '1068',              # 0x042C # Adobe Glyph List
            'Ecy' => '1069',                    # 0x042D # SGML Substitute
            'afii10047' => '1069',              # 0x042D # Adobe Glyph List
            'YUcy' => '1070',                   # 0x042E # SGML Substitute
            'afii10048' => '1070',              # 0x042E # Adobe Glyph List
            'YAcy' => '1071',                   # 0x042F # SGML Substitute
            'afii10049' => '1071',              # 0x042F # Adobe Glyph List
            'acy' => '1072',                    # 0x0430 # SGML Substitute
            'afii10065' => '1072',              # 0x0430 # Adobe Glyph List
            'afii10066' => '1073',              # 0x0431 # Adobe Glyph List
            'bcy' => '1073',                    # 0x0431 # SGML Substitute
            'afii10067' => '1074',              # 0x0432 # Adobe Glyph List
            'vcy' => '1074',                    # 0x0432 # SGML Substitute
            'afii10068' => '1075',              # 0x0433 # Adobe Glyph List
            'gcy' => '1075',                    # 0x0433 # SGML Substitute
            'afii10069' => '1076',              # 0x0434 # Adobe Glyph List
            'afii10070' => '1077',              # 0x0435 # Adobe Glyph List
            'iecy' => '1077',                   # 0x0435 # SGML Substitute
            'afii10072' => '1078',              # 0x0436 # Adobe Glyph List
            'zhcy' => '1078',                   # 0x0436 # SGML Substitute
            'afii10073' => '1079',              # 0x0437 # Adobe Glyph List
            'zcy' => '1079',                    # 0x0437 # SGML Substitute
            'afii10074' => '1080',              # 0x0438 # Adobe Glyph List
            'icy' => '1080',                    # 0x0438 # SGML Substitute
            'afii10075' => '1081',              # 0x0439 # Adobe Glyph List
            'jcy' => '1081',                    # 0x0439 # SGML Substitute
            'afii10076' => '1082',              # 0x043A # Adobe Glyph List
            'kcy' => '1082',                    # 0x043A # SGML Substitute
            'afii10077' => '1083',              # 0x043B # Adobe Glyph List
            'lcy' => '1083',                    # 0x043B # SGML Substitute
            'afii10078' => '1084',              # 0x043C # Adobe Glyph List
            'mcy' => '1084',                    # 0x043C # SGML Substitute
            'afii10079' => '1085',              # 0x043D # Adobe Glyph List
            'ncy' => '1085',                    # 0x043D # SGML Substitute
            'afii10080' => '1086',              # 0x043E # Adobe Glyph List
            'ocy' => '1086',                    # 0x043E # SGML Substitute
            'afii10081' => '1087',              # 0x043F # Adobe Glyph List
            'pcy' => '1087',                    # 0x043F # SGML Substitute
            'afii10082' => '1088',              # 0x0440 # Adobe Glyph List
            'rcy' => '1088',                    # 0x0440 # SGML Substitute
            'afii10083' => '1089',              # 0x0441 # Adobe Glyph List
            'scy' => '1089',                    # 0x0441 # SGML Substitute
            'afii10084' => '1090',              # 0x0442 # Adobe Glyph List
            'tcy' => '1090',                    # 0x0442 # SGML Substitute
            'afii10085' => '1091',              # 0x0443 # Adobe Glyph List
            'ucy' => '1091',                    # 0x0443 # SGML Substitute
            'afii10086' => '1092',              # 0x0444 # Adobe Glyph List
            'fcy' => '1092',                    # 0x0444 # SGML Substitute
            'afii10087' => '1093',              # 0x0445 # Adobe Glyph List
            'khcy' => '1093',                   # 0x0445 # SGML Substitute
            'afii10088' => '1094',              # 0x0446 # Adobe Glyph List
            'tscy' => '1094',                   # 0x0446 # SGML Substitute
            'afii10089' => '1095',              # 0x0447 # Adobe Glyph List
            'chcy' => '1095',                   # 0x0447 # SGML Substitute
            'afii10090' => '1096',              # 0x0448 # Adobe Glyph List
            'shcy' => '1096',                   # 0x0448 # SGML Substitute
            'afii10091' => '1097',              # 0x0449 # Adobe Glyph List
            'shchcy' => '1097',                 # 0x0449 # SGML Substitute
            'afii10092' => '1098',              # 0x044A # Adobe Glyph List
            'hardcy' => '1098',                 # 0x044A # SGML Substitute
            'afii10093' => '1099',              # 0x044B # Adobe Glyph List
            'ycy' => '1099',                    # 0x044B # SGML Substitute
            'afii10094' => '1100',              # 0x044C # Adobe Glyph List
            'softcy' => '1100',                 # 0x044C # SGML Substitute
            'afii10095' => '1101',              # 0x044D # Adobe Glyph List
            'ecy' => '1101',                    # 0x044D # SGML Substitute
            'afii10096' => '1102',              # 0x044E # Adobe Glyph List
            'yucy' => '1102',                   # 0x044E # SGML Substitute
            'afii10097' => '1103',              # 0x044F # Adobe Glyph List
            'yacy' => '1103',                   # 0x044F # SGML Substitute
            'afii10071' => '1105',              # 0x0451 # Adobe Glyph List
            'iocy' => '1105',                   # 0x0451 # SGML Substitute
            'afii10099' => '1106',              # 0x0452 # Adobe Glyph List
            'djcy' => '1106',                   # 0x0452 # SGML Substitute
            'afii10100' => '1107',              # 0x0453 # Adobe Glyph List
            'gjcy' => '1107',                   # 0x0453 # SGML Substitute
            'afii10101' => '1108',              # 0x0454 # Adobe Glyph List
            'jukcy' => '1108',                  # 0x0454 # SGML Substitute
            'afii10102' => '1109',              # 0x0455 # Adobe Glyph List
            'dscy' => '1109',                   # 0x0455 # SGML Substitute
            'afii10103' => '1110',              # 0x0456 # Adobe Glyph List
            'iukcy' => '1110',                  # 0x0456 # SGML Substitute
            'afii10104' => '1111',              # 0x0457 # Adobe Glyph List
            'yicy' => '1111',                   # 0x0457 # SGML Substitute
            'afii10105' => '1112',              # 0x0458 # Adobe Glyph List
            'jsercy' => '1112',                 # 0x0458 # SGML Substitute
            'afii10106' => '1113',              # 0x0459 # Adobe Glyph List
            'ljcy' => '1113',                   # 0x0459 # SGML Substitute
            'afii10107' => '1114',              # 0x045A # Adobe Glyph List
            'njcy' => '1114',                   # 0x045A # SGML Substitute
            'afii10108' => '1115',              # 0x045B # Adobe Glyph List
            'tshcy' => '1115',                  # 0x045B # SGML Substitute
            'afii10109' => '1116',              # 0x045C # Adobe Glyph List
            'kjcy' => '1116',                   # 0x045C # SGML Substitute
            'afii10110' => '1118',              # 0x045E # Adobe Glyph List
            'ubrcy' => '1118',                  # 0x045E # SGML Substitute
            'afii10193' => '1119',              # 0x045F # Adobe Glyph List
            'dzcy' => '1119',                   # 0x045F # SGML Substitute
            'afii10146' => '1122',              # 0x0462 # Adobe Glyph List
            'afii10194' => '1123',              # 0x0463 # Adobe Glyph List
            'afii10147' => '1138',              # 0x0472 # Adobe Glyph List
            'afii10195' => '1139',              # 0x0473 # Adobe Glyph List
            'afii10148' => '1140',              # 0x0474 # Adobe Glyph List
            'afii10196' => '1141',              # 0x0475 # Adobe Glyph List
            'afii10050' => '1168',              # 0x0490 # Adobe Glyph List
            'afii10098' => '1169',              # 0x0491 # Adobe Glyph List
            'afii10846' => '1241',              # 0x04D9 # Adobe Glyph List
            'afii57799' => '1456',              # 0x05B0 # Adobe Glyph List
            'afii57801' => '1457',              # 0x05B1 # Adobe Glyph List
            'afii57800' => '1458',              # 0x05B2 # Adobe Glyph List
            'afii57802' => '1459',              # 0x05B3 # Adobe Glyph List
            'afii57793' => '1460',              # 0x05B4 # Adobe Glyph List
            'afii57794' => '1461',              # 0x05B5 # Adobe Glyph List
            'afii57795' => '1462',              # 0x05B6 # Adobe Glyph List
            'afii57798' => '1463',              # 0x05B7 # Adobe Glyph List
            'afii57797' => '1464',              # 0x05B8 # Adobe Glyph List
            'afii57806' => '1465',              # 0x05B9 # Adobe Glyph List
            'afii57796' => '1467',              # 0x05BB # Adobe Glyph List
            'afii57807' => '1468',              # 0x05BC # Adobe Glyph List
            'afii57839' => '1469',              # 0x05BD # Adobe Glyph List
            'afii57645' => '1470',              # 0x05BE # Adobe Glyph List
            'afii57841' => '1471',              # 0x05BF # Adobe Glyph List
            'afii57842' => '1472',              # 0x05C0 # Adobe Glyph List
            'afii57804' => '1473',              # 0x05C1 # Adobe Glyph List
            'afii57803' => '1474',              # 0x05C2 # Adobe Glyph List
            'afii57658' => '1475',              # 0x05C3 # Adobe Glyph List
            'afii57664' => '1488',              # 0x05D0 # Adobe Glyph List
            'afii57665' => '1489',              # 0x05D1 # Adobe Glyph List
            'afii57666' => '1490',              # 0x05D2 # Adobe Glyph List
            'afii57667' => '1491',              # 0x05D3 # Adobe Glyph List
            'afii57668' => '1492',              # 0x05D4 # Adobe Glyph List
            'afii57669' => '1493',              # 0x05D5 # Adobe Glyph List
            'afii57670' => '1494',              # 0x05D6 # Adobe Glyph List
            'afii57671' => '1495',              # 0x05D7 # Adobe Glyph List
            'afii57672' => '1496',              # 0x05D8 # Adobe Glyph List
            'afii57673' => '1497',              # 0x05D9 # Adobe Glyph List
            'afii57674' => '1498',              # 0x05DA # Adobe Glyph List
            'afii57675' => '1499',              # 0x05DB # Adobe Glyph List
            'afii57676' => '1500',              # 0x05DC # Adobe Glyph List
            'afii57677' => '1501',              # 0x05DD # Adobe Glyph List
            'afii57678' => '1502',              # 0x05DE # Adobe Glyph List
            'afii57679' => '1503',              # 0x05DF # Adobe Glyph List
            'afii57680' => '1504',              # 0x05E0 # Adobe Glyph List
            'afii57681' => '1505',              # 0x05E1 # Adobe Glyph List
            'afii57682' => '1506',              # 0x05E2 # Adobe Glyph List
            'afii57683' => '1507',              # 0x05E3 # Adobe Glyph List
            'afii57684' => '1508',              # 0x05E4 # Adobe Glyph List
            'afii57685' => '1509',              # 0x05E5 # Adobe Glyph List
            'afii57686' => '1510',              # 0x05E6 # Adobe Glyph List
            'afii57687' => '1511',              # 0x05E7 # Adobe Glyph List
            'afii57688' => '1512',              # 0x05E8 # Adobe Glyph List
            'afii57689' => '1513',              # 0x05E9 # Adobe Glyph List
            'afii57690' => '1514',              # 0x05EA # Adobe Glyph List
            'afii57716' => '1520',              # 0x05F0 # Adobe Glyph List
            'afii57717' => '1521',              # 0x05F1 # Adobe Glyph List
            'afii57718' => '1522',              # 0x05F2 # Adobe Glyph List
            'afii57388' => '1548',              # 0x060C # Adobe Glyph List
            'afii57403' => '1563',              # 0x061B # Adobe Glyph List
            'afii57407' => '1567',              # 0x061F # Adobe Glyph List
            'afii57409' => '1569',              # 0x0621 # Adobe Glyph List
            'afii57410' => '1570',              # 0x0622 # Adobe Glyph List
            'afii57411' => '1571',              # 0x0623 # Adobe Glyph List
            'afii57412' => '1572',              # 0x0624 # Adobe Glyph List
            'afii57413' => '1573',              # 0x0625 # Adobe Glyph List
            'afii57414' => '1574',              # 0x0626 # Adobe Glyph List
            'afii57415' => '1575',              # 0x0627 # Adobe Glyph List
            'afii57416' => '1576',              # 0x0628 # Adobe Glyph List
            'afii57417' => '1577',              # 0x0629 # Adobe Glyph List
            'afii57418' => '1578',              # 0x062A # Adobe Glyph List
            'afii57419' => '1579',              # 0x062B # Adobe Glyph List
            'afii57420' => '1580',              # 0x062C # Adobe Glyph List
            'afii57421' => '1581',              # 0x062D # Adobe Glyph List
            'afii57422' => '1582',              # 0x062E # Adobe Glyph List
            'afii57423' => '1583',              # 0x062F # Adobe Glyph List
            'afii57424' => '1584',              # 0x0630 # Adobe Glyph List
            'afii57425' => '1585',              # 0x0631 # Adobe Glyph List
            'afii57426' => '1586',              # 0x0632 # Adobe Glyph List
            'afii57427' => '1587',              # 0x0633 # Adobe Glyph List
            'afii57428' => '1588',              # 0x0634 # Adobe Glyph List
            'afii57429' => '1589',              # 0x0635 # Adobe Glyph List
            'afii57430' => '1590',              # 0x0636 # Adobe Glyph List
            'afii57431' => '1591',              # 0x0637 # Adobe Glyph List
            'afii57432' => '1592',              # 0x0638 # Adobe Glyph List
            'afii57433' => '1593',              # 0x0639 # Adobe Glyph List
            'afii57434' => '1594',              # 0x063A # Adobe Glyph List
            'afii57440' => '1600',              # 0x0640 # Adobe Glyph List
            'afii57441' => '1601',              # 0x0641 # Adobe Glyph List
            'afii57442' => '1602',              # 0x0642 # Adobe Glyph List
            'afii57443' => '1603',              # 0x0643 # Adobe Glyph List
            'afii57444' => '1604',              # 0x0644 # Adobe Glyph List
            'afii57445' => '1605',              # 0x0645 # Adobe Glyph List
            'afii57446' => '1606',              # 0x0646 # Adobe Glyph List
            'afii57470' => '1607',              # 0x0647 # Adobe Glyph List
            'afii57448' => '1608',              # 0x0648 # Adobe Glyph List
            'afii57449' => '1609',              # 0x0649 # Adobe Glyph List
            'afii57450' => '1610',              # 0x064A # Adobe Glyph List
            'afii57451' => '1611',              # 0x064B # Adobe Glyph List
            'afii57452' => '1612',              # 0x064C # Adobe Glyph List
            'afii57453' => '1613',              # 0x064D # Adobe Glyph List
            'afii57454' => '1614',              # 0x064E # Adobe Glyph List
            'afii57455' => '1615',              # 0x064F # Adobe Glyph List
            'afii57456' => '1616',              # 0x0650 # Adobe Glyph List
            'afii57457' => '1617',              # 0x0651 # Adobe Glyph List
            'afii57458' => '1618',              # 0x0652 # Adobe Glyph List
            'afii57392' => '1632',              # 0x0660 # Adobe Glyph List
            'afii57393' => '1633',              # 0x0661 # Adobe Glyph List
            'afii57394' => '1634',              # 0x0662 # Adobe Glyph List
            'afii57395' => '1635',              # 0x0663 # Adobe Glyph List
            'afii57396' => '1636',              # 0x0664 # Adobe Glyph List
            'afii57397' => '1637',              # 0x0665 # Adobe Glyph List
            'afii57398' => '1638',              # 0x0666 # Adobe Glyph List
            'afii57399' => '1639',              # 0x0667 # Adobe Glyph List
            'afii57400' => '1640',              # 0x0668 # Adobe Glyph List
            'afii57401' => '1641',              # 0x0669 # Adobe Glyph List
            'afii57381' => '1642',              # 0x066A # Adobe Glyph List
            'afii63167' => '1645',              # 0x066D # Adobe Glyph List
            'afii57511' => '1657',              # 0x0679 # Adobe Glyph List
            'afii57506' => '1662',              # 0x067E # Adobe Glyph List
            'afii57507' => '1670',              # 0x0686 # Adobe Glyph List
            'afii57512' => '1672',              # 0x0688 # Adobe Glyph List
            'afii57513' => '1681',              # 0x0691 # Adobe Glyph List
            'afii57508' => '1688',              # 0x0698 # Adobe Glyph List
            'afii57505' => '1700',              # 0x06A4 # Adobe Glyph List
            'afii57509' => '1711',              # 0x06AF # Adobe Glyph List
            'afii57514' => '1722',              # 0x06BA # Adobe Glyph List
            'afii57519' => '1746',              # 0x06D2 # Adobe Glyph List
            'afii57534' => '1749',              # 0x06D5 # Adobe Glyph List
            'Wgrave' => '7808',                 # 0x1E80 # Adobe Glyph List
            'wgrave' => '7809',                 # 0x1E81 # Adobe Glyph List
            'Wacute' => '7810',                 # 0x1E82 # Adobe Glyph List
            'wacute' => '7811',                 # 0x1E83 # Adobe Glyph List
            'Wdieresis' => '7812',              # 0x1E84 # Adobe Glyph List
            'wdieresis' => '7813',              # 0x1E85 # Adobe Glyph List
            'Ygrave' => '7922',                 # 0x1EF2 # Adobe Glyph List
            'ygrave' => '7923',                 # 0x1EF3 # Adobe Glyph List
            'ensp' => '8194',                   # 0x2002 # XHTML Substitute
            'emsp' => '8195',                   # 0x2003 # XHTML Substitute
            'emsp13' => '8196',                 # 0x2004 # SGML Substitute
            'emsp14' => '8197',                 # 0x2005 # SGML Substitute
            'numsp' => '8199',                  # 0x2007 # SGML Substitute
            'puncsp' => '8200',                 # 0x2008 # SGML Substitute
            'thinsp' => '8201',                 # 0x2009 # XHTML Substitute
            'hairsp' => '8202',                 # 0x200A # SGML Substitute
            'afii61664' => '8204',              # 0x200C # Adobe Glyph List
            'zwnj' => '8204',                   # 0x200C # XHTML Substitute
            'afii301' => '8205',                # 0x200D # Adobe Glyph List
            'afii299' => '8206',                # 0x200E # Adobe Glyph List
            'afii300' => '8207',                # 0x200F # Adobe Glyph List
            'dash' => '8208',                   # 0x2010 # SGML Substitute
            'figuredash' => '8210',             # 0x2012 # Adobe Glyph List
            'endash' => '8211',                 # 0x2013 # Adobe Glyph List
            'ndash' => '8211',                  # 0x2013 # XHTML Substitute
            'emdash' => '8212',                 # 0x2014 # Adobe Glyph List
            'mdash' => '8212',                  # 0x2014 # XHTML Substitute
            'afii00208' => '8213',              # 0x2015 # Adobe Glyph List
            'horbar' => '8213',                 # 0x2015 # SGML Substitute
            'Verbar' => '8214',                 # 0x2016 # SGML Substitute
            'underscoredbl' => '8215',          # 0x2017 # Adobe Glyph List
            'lsquo' => '8216',                  # 0x2018 # XHTML Substitute
            'quoteleft' => '8216',              # 0x2018 # Adobe Glyph List
            'rsquor' => '8216',                 # 0x2018 # SGML Substitute
            'quoteright' => '8217',             # 0x2019 # Adobe Glyph List
            'rsquo' => '8217',                  # 0x2019 # XHTML Substitute
            'lsquor' => '8218',                 # 0x201A # SGML Substitute
            'quotesinglbase' => '8218',         # 0x201A # Adobe Glyph List
            'sbquo' => '8218',                  # 0x201A # XHTML Substitute
            'quotereversed' => '8219',          # 0x201B # Adobe Glyph List
            'ldquo' => '8220',                  # 0x201C # XHTML Substitute
            'quotedblleft' => '8220',           # 0x201C # Adobe Glyph List
            'rdquor' => '8220',                 # 0x201C # SGML Substitute
            'quotedblright' => '8221',          # 0x201D # Adobe Glyph List
            'rdquo' => '8221',                  # 0x201D # XHTML Substitute
            'bdquo' => '8222',                  # 0x201E # XHTML Substitute
            'ldquor' => '8222',                 # 0x201E # SGML Substitute
            'quotedblbase' => '8222',           # 0x201E # Adobe Glyph List
            'dagger' => '8224',                 # 0x2020 # Adobe Glyph List
            'Dagger' => '8225',                 # 0x2021 # XHTML Substitute
            'daggerdbl' => '8225',              # 0x2021 # Adobe Glyph List
            'bull' => '8226',                   # 0x2022 # XHTML Substitute
            'bullet' => '8226',                 # 0x2022 # Adobe Glyph List
            'onedotenleader' => '8228',         # 0x2024 # Adobe Glyph List
            'nldr' => '8229',                   # 0x2025 # SGML Substitute
            'twodotenleader' => '8229',         # 0x2025 # Adobe Glyph List
            'ellipsis' => '8230',               # 0x2026 # Adobe Glyph List
            'hellip' => '8230',                 # 0x2026 # XHTML Substitute
            'mldr' => '8230',                   # 0x2026 # SGML Substitute
            'afii61573' => '8236',              # 0x202C # Adobe Glyph List
            'afii61574' => '8237',              # 0x202D # Adobe Glyph List
            'afii61575' => '8238',              # 0x202E # Adobe Glyph List
            'permil' => '8240',                 # 0x2030 # XHTML Substitute
            'perthousand' => '8240',            # 0x2030 # Adobe Glyph List
            'minute' => '8242',                 # 0x2032 # Adobe Glyph List
            'prime' => '8242',                  # 0x2032 # XHTML Substitute
            'vprime' => '8242',                 # 0x2032 # SGML Substitute
            'Prime' => '8243',                  # 0x2033 # XHTML Substitute
            'second' => '8243',                 # 0x2033 # Adobe Glyph List
            'tprime' => '8244',                 # 0x2034 # SGML Substitute
            'bprime' => '8245',                 # 0x2035 # SGML Substitute
            'guilsinglleft' => '8249',          # 0x2039 # Adobe Glyph List
            'lsaquo' => '8249',                 # 0x2039 # XHTML Substitute
            'guilsinglright' => '8250',         # 0x203A # Adobe Glyph List
            'rsaquo' => '8250',                 # 0x203A # XHTML Substitute
            'exclamdbl' => '8252',              # 0x203C # Adobe Glyph List
            'oline' => '8254',                  # 0x203E # XHTML Substitute
            'overline' => '8254',               # 0x203E # WGL4 Substitute
            'caret' => '8257',                  # 0x2041 # SGML Substitute
            'hybull' => '8259',                 # 0x2043 # SGML Substitute
            'fraction' => '8260',               # 0x2044 # Adobe Glyph List
            'frasl' => '8260',                  # 0x2044 # XHTML Substitute
            'zerosuperior' => '8304',           # 0x2070 # Adobe Glyph List
            'foursuperior' => '8308',           # 0x2074 # Adobe Glyph List
            'fivesuperior' => '8309',           # 0x2075 # Adobe Glyph List
            'sixsuperior' => '8310',            # 0x2076 # Adobe Glyph List
            'sevensuperior' => '8311',          # 0x2077 # Adobe Glyph List
            'eightsuperior' => '8312',          # 0x2078 # Adobe Glyph List
            'ninesuperior' => '8313',           # 0x2079 # Adobe Glyph List
            'parenleftsuperior' => '8317',      # 0x207D # Adobe Glyph List
            'parenrightsuperior' => '8318',     # 0x207E # Adobe Glyph List
            'nsuperior' => '8319',              # 0x207F # Adobe Glyph List
            'zeroinferior' => '8320',           # 0x2080 # Adobe Glyph List
            'oneinferior' => '8321',            # 0x2081 # Adobe Glyph List
            'twoinferior' => '8322',            # 0x2082 # Adobe Glyph List
            'threeinferior' => '8323',          # 0x2083 # Adobe Glyph List
            'fourinferior' => '8324',           # 0x2084 # Adobe Glyph List
            'fiveinferior' => '8325',           # 0x2085 # Adobe Glyph List
            'sixinferior' => '8326',            # 0x2086 # Adobe Glyph List
            'seveninferior' => '8327',          # 0x2087 # Adobe Glyph List
            'eightinferior' => '8328',          # 0x2088 # Adobe Glyph List
            'nineinferior' => '8329',           # 0x2089 # Adobe Glyph List
            'parenleftinferior' => '8333',      # 0x208D # Adobe Glyph List
            'parenrightinferior' => '8334',     # 0x208E # Adobe Glyph List
            'colonmonetary' => '8353',          # 0x20A1 # Adobe Glyph List
            'franc' => '8355',                  # 0x20A3 # Adobe Glyph List
            'lira' => '8356',                   # 0x20A4 # Adobe Glyph List
            'peseta' => '8359',                 # 0x20A7 # Adobe Glyph List
            'afii57636' => '8362',              # 0x20AA # Adobe Glyph List
            'dong' => '8363',                   # 0x20AB # Adobe Glyph List
            'Euro' => '8364',                   # 0x20AC # Adobe Glyph List
            'euro' => '8364',                   # 0x20AC # XHTML Substitute
            'tdot' => '8411',                   # 0x20DB # SGML Substitute
            'DotDot' => '8412',                 # 0x20DC # SGML Substitute
            'afii61248' => '8453',              # 0x2105 # Adobe Glyph List
            'incare' => '8453',                 # 0x2105 # SGML Substitute
            'hamilt' => '8459',                 # 0x210B # SGML Substitute
            'planck' => '8463',                 # 0x210F # SGML Substitute
            'Ifraktur' => '8465',               # 0x2111 # Adobe Glyph List
            'image' => '8465',                  # 0x2111 # XHTML Substitute
            'lagran' => '8466',                 # 0x2112 # SGML Substitute
            'afii61289' => '8467',              # 0x2113 # Adobe Glyph List
            'ell' => '8467',                    # 0x2113 # SGML Substitute
            'afii61352' => '8470',              # 0x2116 # Adobe Glyph List
            'numero' => '8470',                 # 0x2116 # SGML Substitute
            'copysr' => '8471',                 # 0x2117 # SGML Substitute
            'weierp' => '8472',                 # 0x2118 # XHTML Substitute
            'weierstrass' => '8472',            # 0x2118 # Adobe Glyph List
            'Rfraktur' => '8476',               # 0x211C # Adobe Glyph List
            'real' => '8476',                   # 0x211C # XHTML Substitute
            'prescription' => '8478',           # 0x211E # Adobe Glyph List
            'rx' => '8478',                     # 0x211E # SGML Substitute
            'trade' => '8482',                  # 0x2122 # XHTML Substitute
            'trademark' => '8482',              # 0x2122 # Adobe Glyph List
            'ohm' => '8486',                    # 0x2126 # SGML Substitute
            'angst' => '8491',                  # 0x212B # SGML Substitute
            'bernou' => '8492',                 # 0x212C # SGML Substitute
            'estimated' => '8494',              # 0x212E # Adobe Glyph List
            'phmmat' => '8499',                 # 0x2133 # SGML Substitute
            'order' => '8500',                  # 0x2134 # SGML Substitute
            'alefsym' => '8501',                # 0x2135 # XHTML Substitute
            'aleph' => '8501',                  # 0x2135 # Adobe Glyph List
            'beth' => '8502',                   # 0x2136 # SGML Substitute
            'gimel' => '8503',                  # 0x2137 # SGML Substitute
            'daleth' => '8504',                 # 0x2138 # SGML Substitute
            'frac13' => '8531',                 # 0x2153 # SGML Substitute
            'onethird' => '8531',               # 0x2153 # Adobe Glyph List
            'frac23' => '8532',                 # 0x2154 # SGML Substitute
            'twothirds' => '8532',              # 0x2154 # Adobe Glyph List
            'frac15' => '8533',                 # 0x2155 # SGML Substitute
            'frac25' => '8534',                 # 0x2156 # SGML Substitute
            'frac35' => '8535',                 # 0x2157 # SGML Substitute
            'frac45' => '8536',                 # 0x2158 # SGML Substitute
            'frac16' => '8537',                 # 0x2159 # SGML Substitute
            'frac56' => '8538',                 # 0x215A # SGML Substitute
            'frac18' => '8539',                 # 0x215B # SGML Substitute
            'oneeighth' => '8539',              # 0x215B # Adobe Glyph List
            'frac38' => '8540',                 # 0x215C # SGML Substitute
            'threeeighths' => '8540',           # 0x215C # Adobe Glyph List
            'fiveeighths' => '8541',            # 0x215D # Adobe Glyph List
            'frac58' => '8541',                 # 0x215D # SGML Substitute
            'frac78' => '8542',                 # 0x215E # SGML Substitute
            'seveneighths' => '8542',           # 0x215E # Adobe Glyph List
            'arrowleft' => '8592',              # 0x2190 # Adobe Glyph List
            'larr' => '8592',                   # 0x2190 # XHTML Substitute
            'arrowup' => '8593',                # 0x2191 # Adobe Glyph List
            'uarr' => '8593',                   # 0x2191 # XHTML Substitute
            'arrowright' => '8594',             # 0x2192 # Adobe Glyph List
            'rarr' => '8594',                   # 0x2192 # XHTML Substitute
            'arrowdown' => '8595',              # 0x2193 # Adobe Glyph List
            'darr' => '8595',                   # 0x2193 # XHTML Substitute
            'arrowboth' => '8596',              # 0x2194 # Adobe Glyph List
            'harr' => '8596',                   # 0x2194 # XHTML Substitute
            'arrowupdn' => '8597',              # 0x2195 # Adobe Glyph List
            'varr' => '8597',                   # 0x2195 # SGML Substitute
            'nwarr' => '8598',                  # 0x2196 # SGML Substitute
            'nearr' => '8599',                  # 0x2197 # SGML Substitute
            'drarr' => '8600',                  # 0x2198 # SGML Substitute
            'dlarr' => '8601',                  # 0x2199 # SGML Substitute
            'nlarr' => '8602',                  # 0x219A # SGML Substitute
            'nrarr' => '8603',                  # 0x219B # SGML Substitute
            'rarrw' => '8605',                  # 0x219D # SGML Substitute
            'Larr' => '8606',                   # 0x219E # SGML Substitute
            'Rarr' => '8608',                   # 0x21A0 # SGML Substitute
            'larrtl' => '8610',                 # 0x21A2 # SGML Substitute
            'rarrtl' => '8611',                 # 0x21A3 # SGML Substitute
            'map' => '8614',                    # 0x21A6 # SGML Substitute
            'arrowupdnbse' => '8616',           # 0x21A8 # Adobe Glyph List
            'larrhk' => '8617',                 # 0x21A9 # SGML Substitute
            'rarrhk' => '8618',                 # 0x21AA # SGML Substitute
            'larrlp' => '8619',                 # 0x21AB # SGML Substitute
            'rarrlp' => '8620',                 # 0x21AC # SGML Substitute
            'harrw' => '8621',                  # 0x21AD # SGML Substitute
            'nharr' => '8622',                  # 0x21AE # SGML Substitute
            'lsh' => '8624',                    # 0x21B0 # SGML Substitute
            'rsh' => '8625',                    # 0x21B1 # SGML Substitute
            'carriagereturn' => '8629',         # 0x21B5 # Adobe Glyph List
            'crarr' => '8629',                  # 0x21B5 # XHTML Substitute
            'cularr' => '8630',                 # 0x21B6 # SGML Substitute
            'curarr' => '8631',                 # 0x21B7 # SGML Substitute
            'olarr' => '8634',                  # 0x21BA # SGML Substitute
            'orarr' => '8635',                  # 0x21BB # SGML Substitute
            'lharu' => '8636',                  # 0x21BC # SGML Substitute
            'lhard' => '8637',                  # 0x21BD # SGML Substitute
            'uharr' => '8638',                  # 0x21BE # SGML Substitute
            'uharl' => '8639',                  # 0x21BF # SGML Substitute
            'rharu' => '8640',                  # 0x21C0 # SGML Substitute
            'rhard' => '8641',                  # 0x21C1 # SGML Substitute
            'dharr' => '8642',                  # 0x21C2 # SGML Substitute
            'dharl' => '8643',                  # 0x21C3 # SGML Substitute
            'rlarr2' => '8644',                 # 0x21C4 # SGML Substitute
            'lrarr2' => '8646',                 # 0x21C6 # SGML Substitute
            'larr2' => '8647',                  # 0x21C7 # SGML Substitute
            'uarr2' => '8648',                  # 0x21C8 # SGML Substitute
            'rarr2' => '8649',                  # 0x21C9 # SGML Substitute
            'darr2' => '8650',                  # 0x21CA # SGML Substitute
            'lrhar2' => '8651',                 # 0x21CB # SGML Substitute
            'rlhar2' => '8652',                 # 0x21CC # SGML Substitute
            'nlArr' => '8653',                  # 0x21CD # SGML Substitute
            'nhArr' => '8654',                  # 0x21CE # SGML Substitute
            'nrArr' => '8655',                  # 0x21CF # SGML Substitute
            'arrowdblleft' => '8656',           # 0x21D0 # Adobe Glyph List
            'lArr' => '8656',                   # 0x21D0 # XHTML Substitute
            'arrowdblup' => '8657',             # 0x21D1 # Adobe Glyph List
            'uArr' => '8657',                   # 0x21D1 # XHTML Substitute
            'arrowdblright' => '8658',          # 0x21D2 # Adobe Glyph List
            'rArr' => '8658',                   # 0x21D2 # XHTML Substitute
            'arrowdbldown' => '8659',           # 0x21D3 # Adobe Glyph List
            'dArr' => '8659',                   # 0x21D3 # XHTML Substitute
            'arrowdblboth' => '8660',           # 0x21D4 # Adobe Glyph List
            'hArr' => '8660',                   # 0x21D4 # XHTML Substitute
            'iff' => '8660',                    # 0x21D4 # SGML Substitute
            'vArr' => '8661',                   # 0x21D5 # SGML Substitute
            'lAarr' => '8666',                  # 0x21DA # SGML Substitute
            'rAarr' => '8667',                  # 0x21DB # SGML Substitute
            'forall' => '8704',                 # 0x2200 # XHTML Substitute
            'universal' => '8704',              # 0x2200 # Adobe Glyph List
            'comp' => '8705',                   # 0x2201 # SGML Substitute
            'part' => '8706',                   # 0x2202 # XHTML Substitute
            'partialdiff' => '8706',            # 0x2202 # Adobe Glyph List
            'exist' => '8707',                  # 0x2203 # XHTML Substitute
            'existential' => '8707',            # 0x2203 # Adobe Glyph List
            'nexist' => '8708',                 # 0x2204 # SGML Substitute
            'empty' => '8709',                  # 0x2205 # XHTML Substitute
            'emptyset' => '8709',               # 0x2205 # Adobe Glyph List
            'gradient' => '8711',               # 0x2207 # Adobe Glyph List
            'nabla' => '8711',                  # 0x2207 # XHTML Substitute
            'element' => '8712',                # 0x2208 # Adobe Glyph List
            'isin' => '8712',                   # 0x2208 # XHTML Substitute
            'notelement' => '8713',             # 0x2209 # Adobe Glyph List
            'notin' => '8713',                  # 0x2209 # XHTML Substitute
            'epsis' => '8714',                  # 0x220A # SGML Substitute
            'ni' => '8715',                     # 0x220B # XHTML Substitute
            'suchthat' => '8715',               # 0x220B # Adobe Glyph List
            'bepsi' => '8717',                  # 0x220D # SGML Substitute
            'prod' => '8719',                   # 0x220F # XHTML Substitute
            'product' => '8719',                # 0x220F # Adobe Glyph List
            'amalg' => '8720',                  # 0x2210 # SGML Substitute
            'coprod' => '8720',                 # 0x2210 # SGML Substitute
            'samalg' => '8720',                 # 0x2210 # SGML Substitute
            'sum' => '8721',                    # 0x2211 # XHTML Substitute
            'summation' => '8721',              # 0x2211 # Adobe Glyph List
            'minus' => '8722',                  # 0x2212 # Adobe Glyph List
            'mnplus' => '8723',                 # 0x2213 # SGML Substitute
            'plusdo' => '8724',                 # 0x2214 # SGML Substitute
            'setmn' => '8726',                  # 0x2216 # SGML Substitute
            'asteriskmath' => '8727',           # 0x2217 # Adobe Glyph List
            'lowast' => '8727',                 # 0x2217 # XHTML Substitute
            'compfn' => '8728',                 # 0x2218 # SGML Substitute
            'radic' => '8730',                  # 0x221A # XHTML Substitute
            'radical' => '8730',                # 0x221A # Adobe Glyph List
            'prop' => '8733',                   # 0x221D # XHTML Substitute
            'proportional' => '8733',           # 0x221D # Adobe Glyph List
            'vprop' => '8733',                  # 0x221D # SGML Substitute
            'infin' => '8734',                  # 0x221E # XHTML Substitute
            'infinity' => '8734',               # 0x221E # Adobe Glyph List
            'ang90' => '8735',                  # 0x221F # SGML Substitute
            'orthogonal' => '8735',             # 0x221F # Adobe Glyph List
            'ang' => '8736',                    # 0x2220 # XHTML Substitute
            'angle' => '8736',                  # 0x2220 # Adobe Glyph List
            'angmsd' => '8737',                 # 0x2221 # SGML Substitute
            'angsph' => '8738',                 # 0x2222 # SGML Substitute
            'mid' => '8739',                    # 0x2223 # SGML Substitute
            'nmid' => '8740',                   # 0x2224 # SGML Substitute
            'par' => '8741',                    # 0x2225 # SGML Substitute
            'npar' => '8742',                   # 0x2226 # SGML Substitute
            'and' => '8743',                    # 0x2227 # XHTML Substitute
            'logicaland' => '8743',             # 0x2227 # Adobe Glyph List
            'logicalor' => '8744',              # 0x2228 # Adobe Glyph List
            'or' => '8744',                     # 0x2228 # XHTML Substitute
            'cap' => '8745',                    # 0x2229 # XHTML Substitute
            'intersection' => '8745',           # 0x2229 # Adobe Glyph List
            'cup' => '8746',                    # 0x222A # XHTML Substitute
            'union' => '8746',                  # 0x222A # Adobe Glyph List
            'int' => '8747',                    # 0x222B # XHTML Substitute
            'integral' => '8747',               # 0x222B # Adobe Glyph List
            'conint' => '8750',                 # 0x222E # SGML Substitute
            'there4' => '8756',                 # 0x2234 # XHTML Substitute
            'therefore' => '8756',              # 0x2234 # Adobe Glyph List
            'becaus' => '8757',                 # 0x2235 # SGML Substitute
            'sim' => '8764',                    # 0x223C # XHTML Substitute
            'similar' => '8764',                # 0x223C # Adobe Glyph List
            'thksim' => '8764',                 # 0x223C # SGML Substitute
            'bsim' => '8765',                   # 0x223D # SGML Substitute
            'wreath' => '8768',                 # 0x2240 # SGML Substitute
            'nsim' => '8769',                   # 0x2241 # SGML Substitute
            'sime' => '8771',                   # 0x2243 # SGML Substitute
            'nsime' => '8772',                  # 0x2244 # SGML Substitute
            'cong' => '8773',                   # 0x2245 # XHTML Substitute
            'congruent' => '8773',              # 0x2245 # Adobe Glyph List
            'ncong' => '8775',                  # 0x2247 # SGML Substitute
            'ap' => '8776',                     # 0x2248 # SGML Substitute
            'approxequal' => '8776',            # 0x2248 # Adobe Glyph List
            'asymp' => '8776',                  # 0x2248 # XHTML Substitute
            'thkap' => '8776',                  # 0x2248 # SGML Substitute
            'nap' => '8777',                    # 0x2249 # SGML Substitute
            'ape' => '8778',                    # 0x224A # SGML Substitute
            'bcong' => '8780',                  # 0x224C # SGML Substitute
            'bump' => '8782',                   # 0x224E # SGML Substitute
            'bumpe' => '8783',                  # 0x224F # SGML Substitute
            'esdot' => '8784',                  # 0x2250 # SGML Substitute
            'eDot' => '8785',                   # 0x2251 # SGML Substitute
            'efDot' => '8786',                  # 0x2252 # SGML Substitute
            'erDot' => '8787',                  # 0x2253 # SGML Substitute
            'colone' => '8788',                 # 0x2254 # SGML Substitute
            'ecolon' => '8789',                 # 0x2255 # SGML Substitute
            'ecir' => '8790',                   # 0x2256 # SGML Substitute
            'cire' => '8791',                   # 0x2257 # SGML Substitute
            'wedgeq' => '8793',                 # 0x2259 # SGML Substitute
            'trie' => '8796',                   # 0x225C # SGML Substitute
            'ne' => '8800',                     # 0x2260 # XHTML Substitute
            'notequal' => '8800',               # 0x2260 # Adobe Glyph List
            'equiv' => '8801',                  # 0x2261 # XHTML Substitute
            'equivalence' => '8801',            # 0x2261 # Adobe Glyph List
            'nequiv' => '8802',                 # 0x2262 # SGML Substitute
            'le' => '8804',                     # 0x2264 # XHTML Substitute
            'les' => '8804',                    # 0x2264 # SGML Substitute
            'lessequal' => '8804',              # 0x2264 # Adobe Glyph List
            'ge' => '8805',                     # 0x2265 # XHTML Substitute
            'ges' => '8805',                    # 0x2265 # SGML Substitute
            'greaterequal' => '8805',           # 0x2265 # Adobe Glyph List
            'lE' => '8806',                     # 0x2266 # SGML Substitute
            'gE' => '8807',                     # 0x2267 # SGML Substitute
            'lnE' => '8808',                    # 0x2268 # SGML Substitute
            'lvnE' => '8808',                   # 0x2268 # SGML Substitute
            'gnE' => '8809',                    # 0x2269 # SGML Substitute
            'gvnE' => '8809',                   # 0x2269 # SGML Substitute
            'Lt' => '8810',                     # 0x226A # SGML Substitute
            'Gt' => '8811',                     # 0x226B # SGML Substitute
            'twixt' => '8812',                  # 0x226C # SGML Substitute
            'nlt' => '8814',                    # 0x226E # SGML Substitute
            'ngt' => '8815',                    # 0x226F # SGML Substitute
            'nle' => '8816',                    # 0x2270 # SGML Substitute
            'nles' => '8816',                   # 0x2270 # SGML Substitute
            'nge' => '8817',                    # 0x2271 # SGML Substitute
            'nges' => '8817',                   # 0x2271 # SGML Substitute
            'lsim' => '8818',                   # 0x2272 # SGML Substitute
            'gsim' => '8819',                   # 0x2273 # SGML Substitute
            'lg' => '8822',                     # 0x2276 # SGML Substitute
            'gl' => '8823',                     # 0x2277 # SGML Substitute
            'pr' => '8826',                     # 0x227A # SGML Substitute
            'sc' => '8827',                     # 0x227B # SGML Substitute
            'cupre' => '8828',                  # 0x227C # SGML Substitute
            'sccue' => '8829',                  # 0x227D # SGML Substitute
            'prsim' => '8830',                  # 0x227E # SGML Substitute
            'scsim' => '8831',                  # 0x227F # SGML Substitute
            'npr' => '8832',                    # 0x2280 # SGML Substitute
            'nsc' => '8833',                    # 0x2281 # SGML Substitute
            'propersubset' => '8834',           # 0x2282 # Adobe Glyph List
            'sub' => '8834',                    # 0x2282 # XHTML Substitute
            'propersuperset' => '8835',         # 0x2283 # Adobe Glyph List
            'sup' => '8835',                    # 0x2283 # XHTML Substitute
            'notsubset' => '8836',              # 0x2284 # Adobe Glyph List
            'nsub' => '8836',                   # 0x2284 # XHTML Substitute
            'nsup' => '8837',                   # 0x2285 # SGML Substitute
            'reflexsubset' => '8838',           # 0x2286 # Adobe Glyph List
            'sube' => '8838',                   # 0x2286 # XHTML Substitute
            'reflexsuperset' => '8839',         # 0x2287 # Adobe Glyph List
            'supe' => '8839',                   # 0x2287 # XHTML Substitute
            'nsube' => '8840',                  # 0x2288 # SGML Substitute
            'nsupe' => '8841',                  # 0x2289 # SGML Substitute
            'subnE' => '8842',                  # 0x228A # SGML Substitute
            'supnE' => '8843',                  # 0x228B # SGML Substitute
            'uplus' => '8846',                  # 0x228E # SGML Substitute
            'sqsub' => '8847',                  # 0x228F # SGML Substitute
            'sqsup' => '8848',                  # 0x2290 # SGML Substitute
            'sqsube' => '8849',                 # 0x2291 # SGML Substitute
            'sqsupe' => '8850',                 # 0x2292 # SGML Substitute
            'sqcap' => '8851',                  # 0x2293 # SGML Substitute
            'sqcup' => '8852',                  # 0x2294 # SGML Substitute
            'circleplus' => '8853',             # 0x2295 # Adobe Glyph List
            'oplus' => '8853',                  # 0x2295 # XHTML Substitute
            'ominus' => '8854',                 # 0x2296 # SGML Substitute
            'circlemultiply' => '8855',         # 0x2297 # Adobe Glyph List
            'otimes' => '8855',                 # 0x2297 # XHTML Substitute
            'osol' => '8856',                   # 0x2298 # SGML Substitute
            'odot' => '8857',                   # 0x2299 # SGML Substitute
            'ocir' => '8858',                   # 0x229A # SGML Substitute
            'oast' => '8859',                   # 0x229B # SGML Substitute
            'odash' => '8861',                  # 0x229D # SGML Substitute
            'plusb' => '8862',                  # 0x229E # SGML Substitute
            'minusb' => '8863',                 # 0x229F # SGML Substitute
            'timesb' => '8864',                 # 0x22A0 # SGML Substitute
            'sdotb' => '8865',                  # 0x22A1 # SGML Substitute
            'vdash' => '8866',                  # 0x22A2 # SGML Substitute
            'dashv' => '8867',                  # 0x22A3 # SGML Substitute
            'top' => '8868',                    # 0x22A4 # SGML Substitute
            'bottom' => '8869',                 # 0x22A5 # SGML Substitute
            'perp' => '8869',                   # 0x22A5 # XHTML Substitute
            'perpendicular' => '8869',          # 0x22A5 # Adobe Glyph List
            'models' => '8871',                 # 0x22A7 # SGML Substitute
            'vDash' => '8872',                  # 0x22A8 # SGML Substitute
            'Vdash' => '8873',                  # 0x22A9 # SGML Substitute
            'Vvdash' => '8874',                 # 0x22AA # SGML Substitute
            'nvdash' => '8876',                 # 0x22AC # SGML Substitute
            'nvDash' => '8877',                 # 0x22AD # SGML Substitute
            'nVdash' => '8878',                 # 0x22AE # SGML Substitute
            'nVDash' => '8879',                 # 0x22AF # SGML Substitute
            'vltri' => '8882',                  # 0x22B2 # SGML Substitute
            'vrtri' => '8883',                  # 0x22B3 # SGML Substitute
            'ltrie' => '8884',                  # 0x22B4 # SGML Substitute
            'rtrie' => '8885',                  # 0x22B5 # SGML Substitute
            'mumap' => '8888',                  # 0x22B8 # SGML Substitute
            'intcal' => '8890',                 # 0x22BA # SGML Substitute
            'veebar' => '8891',                 # 0x22BB # SGML Substitute
            'barwed' => '8892',                 # 0x22BC # SGML Substitute
            'diam' => '8900',                   # 0x22C4 # SGML Substitute
            'dotmath' => '8901',                # 0x22C5 # Adobe Glyph List
            'sdot' => '8901',                   # 0x22C5 # XHTML Substitute
            'sstarf' => '8902',                 # 0x22C6 # SGML Substitute
            'divonx' => '8903',                 # 0x22C7 # SGML Substitute
            'bowtie' => '8904',                 # 0x22C8 # SGML Substitute
            'ltimes' => '8905',                 # 0x22C9 # SGML Substitute
            'rtimes' => '8906',                 # 0x22CA # SGML Substitute
            'lthree' => '8907',                 # 0x22CB # SGML Substitute
            'rthree' => '8908',                 # 0x22CC # SGML Substitute
            'bsime' => '8909',                  # 0x22CD # SGML Substitute
            'cuvee' => '8910',                  # 0x22CE # SGML Substitute
            'cuwed' => '8911',                  # 0x22CF # SGML Substitute
            'Sub' => '8912',                    # 0x22D0 # SGML Substitute
            'Sup' => '8913',                    # 0x22D1 # SGML Substitute
            'Cap' => '8914',                    # 0x22D2 # SGML Substitute
            'Cup' => '8915',                    # 0x22D3 # SGML Substitute
            'fork' => '8916',                   # 0x22D4 # SGML Substitute
            'gsdot' => '8919',                  # 0x22D7 # SGML Substitute
            'Ll' => '8920',                     # 0x22D8 # SGML Substitute
            'Gg' => '8921',                     # 0x22D9 # SGML Substitute
            'leg' => '8922',                    # 0x22DA # SGML Substitute
            'gel' => '8923',                    # 0x22DB # SGML Substitute
            'els' => '8924',                    # 0x22DC # SGML Substitute
            'egs' => '8925',                    # 0x22DD # SGML Substitute
            'cuepr' => '8926',                  # 0x22DE # SGML Substitute
            'cuesc' => '8927',                  # 0x22DF # SGML Substitute
            'npre' => '8928',                   # 0x22E0 # SGML Substitute
            'nsce' => '8929',                   # 0x22E1 # SGML Substitute
            'lnsim' => '8934',                  # 0x22E6 # SGML Substitute
            'gnsim' => '8935',                  # 0x22E7 # SGML Substitute
            'prnsim' => '8936',                 # 0x22E8 # SGML Substitute
            'scnsim' => '8937',                 # 0x22E9 # SGML Substitute
            'nltri' => '8938',                  # 0x22EA # SGML Substitute
            'nrtri' => '8939',                  # 0x22EB # SGML Substitute
            'nltrie' => '8940',                 # 0x22EC # SGML Substitute
            'nrtrie' => '8941',                 # 0x22ED # SGML Substitute
            'vellip' => '8942',                 # 0x22EE # SGML Substitute
            'house' => '8962',                  # 0x2302 # Adobe Glyph List
            'Barwed' => '8966',                 # 0x2306 # SGML Substitute
            'lceil' => '8968',                  # 0x2308 # XHTML Substitute
            'rceil' => '8969',                  # 0x2309 # XHTML Substitute
            'lfloor' => '8970',                 # 0x230A # XHTML Substitute
            'rfloor' => '8971',                 # 0x230B # XHTML Substitute
            'drcrop' => '8972',                 # 0x230C # SGML Substitute
            'dlcrop' => '8973',                 # 0x230D # SGML Substitute
            'urcrop' => '8974',                 # 0x230E # SGML Substitute
            'ulcrop' => '8975',                 # 0x230F # SGML Substitute
            'revlogicalnot' => '8976',          # 0x2310 # Adobe Glyph List
            'telrec' => '8981',                 # 0x2315 # SGML Substitute
            'ulcorn' => '8988',                 # 0x231C # SGML Substitute
            'urcorn' => '8989',                 # 0x231D # SGML Substitute
            'dlcorn' => '8990',                 # 0x231E # SGML Substitute
            'drcorn' => '8991',                 # 0x231F # SGML Substitute
            'integraltp' => '8992',             # 0x2320 # Adobe Glyph List
            'integralbt' => '8993',             # 0x2321 # Adobe Glyph List
            'frown' => '8994',                  # 0x2322 # SGML Substitute
            'smile' => '8995',                  # 0x2323 # SGML Substitute
            'angleleft' => '9001',              # 0x2329 # Adobe Glyph List
            'lang' => '9001',                   # 0x2329 # XHTML Substitute
            'angleright' => '9002',             # 0x232A # Adobe Glyph List
            'rang' => '9002',                   # 0x232A # XHTML Substitute
            'blank' => '9251',                  # 0x2423 # SGML Substitute
            'a120' => '9312',                   # 0x2460 # WGL4 Substitute
            'a121' => '9313',                   # 0x2461 # WGL4 Substitute
            'a122' => '9314',                   # 0x2462 # WGL4 Substitute
            'a123' => '9315',                   # 0x2463 # WGL4 Substitute
            'a124' => '9316',                   # 0x2464 # WGL4 Substitute
            'a125' => '9317',                   # 0x2465 # WGL4 Substitute
            'a126' => '9318',                   # 0x2466 # WGL4 Substitute
            'a127' => '9319',                   # 0x2467 # WGL4 Substitute
            'a128' => '9320',                   # 0x2468 # WGL4 Substitute
            'a129' => '9321',                   # 0x2469 # WGL4 Substitute
            'oS' => '9416',                     # 0x24C8 # SGML Substitute
            'SF100000' => '9472',               # 0x2500 # Adobe Glyph List
            'boxh' => '9472',                   # 0x2500 # SGML Substitute
            'SF110000' => '9474',               # 0x2502 # Adobe Glyph List
            'boxv' => '9474',                   # 0x2502 # SGML Substitute
            'SF010000' => '9484',               # 0x250C # Adobe Glyph List
            'boxdr' => '9484',                  # 0x250C # SGML Substitute
            'SF030000' => '9488',               # 0x2510 # Adobe Glyph List
            'boxdl' => '9488',                  # 0x2510 # SGML Substitute
            'SF020000' => '9492',               # 0x2514 # Adobe Glyph List
            'boxur' => '9492',                  # 0x2514 # SGML Substitute
            'SF040000' => '9496',               # 0x2518 # Adobe Glyph List
            'boxul' => '9496',                  # 0x2518 # SGML Substitute
            'SF080000' => '9500',               # 0x251C # Adobe Glyph List
            'boxvr' => '9500',                  # 0x251C # SGML Substitute
            'SF090000' => '9508',               # 0x2524 # Adobe Glyph List
            'boxvl' => '9508',                  # 0x2524 # SGML Substitute
            'SF060000' => '9516',               # 0x252C # Adobe Glyph List
            'boxhd' => '9516',                  # 0x252C # SGML Substitute
            'SF070000' => '9524',               # 0x2534 # Adobe Glyph List
            'boxhu' => '9524',                  # 0x2534 # SGML Substitute
            'SF050000' => '9532',               # 0x253C # Adobe Glyph List
            'boxvh' => '9532',                  # 0x253C # SGML Substitute
            'SF430000' => '9552',               # 0x2550 # Adobe Glyph List
            'boxH' => '9552',                   # 0x2550 # SGML Substitute
            'SF240000' => '9553',               # 0x2551 # Adobe Glyph List
            'boxV' => '9553',                   # 0x2551 # SGML Substitute
            'SF510000' => '9554',               # 0x2552 # Adobe Glyph List
            'boxdR' => '9554',                  # 0x2552 # SGML Substitute
            'SF520000' => '9555',               # 0x2553 # Adobe Glyph List
            'boxDr' => '9555',                  # 0x2553 # SGML Substitute
            'SF390000' => '9556',               # 0x2554 # Adobe Glyph List
            'boxDR' => '9556',                  # 0x2554 # SGML Substitute
            'SF220000' => '9557',               # 0x2555 # Adobe Glyph List
            'boxdL' => '9557',                  # 0x2555 # SGML Substitute
            'SF210000' => '9558',               # 0x2556 # Adobe Glyph List
            'boxDl' => '9558',                  # 0x2556 # SGML Substitute
            'SF250000' => '9559',               # 0x2557 # Adobe Glyph List
            'boxDL' => '9559',                  # 0x2557 # SGML Substitute
            'SF500000' => '9560',               # 0x2558 # Adobe Glyph List
            'boxuR' => '9560',                  # 0x2558 # SGML Substitute
            'SF490000' => '9561',               # 0x2559 # Adobe Glyph List
            'boxUr' => '9561',                  # 0x2559 # SGML Substitute
            'SF380000' => '9562',               # 0x255A # Adobe Glyph List
            'boxUR' => '9562',                  # 0x255A # SGML Substitute
            'SF280000' => '9563',               # 0x255B # Adobe Glyph List
            'boxuL' => '9563',                  # 0x255B # SGML Substitute
            'SF270000' => '9564',               # 0x255C # Adobe Glyph List
            'boxUl' => '9564',                  # 0x255C # SGML Substitute
            'SF260000' => '9565',               # 0x255D # Adobe Glyph List
            'boxUL' => '9565',                  # 0x255D # SGML Substitute
            'SF360000' => '9566',               # 0x255E # Adobe Glyph List
            'boxvR' => '9566',                  # 0x255E # SGML Substitute
            'SF370000' => '9567',               # 0x255F # Adobe Glyph List
            'boxVr' => '9567',                  # 0x255F # SGML Substitute
            'SF420000' => '9568',               # 0x2560 # Adobe Glyph List
            'boxVR' => '9568',                  # 0x2560 # SGML Substitute
            'SF190000' => '9569',               # 0x2561 # Adobe Glyph List
            'boxvL' => '9569',                  # 0x2561 # SGML Substitute
            'SF200000' => '9570',               # 0x2562 # Adobe Glyph List
            'boxVl' => '9570',                  # 0x2562 # SGML Substitute
            'SF230000' => '9571',               # 0x2563 # Adobe Glyph List
            'boxVL' => '9571',                  # 0x2563 # SGML Substitute
            'SF470000' => '9572',               # 0x2564 # Adobe Glyph List
            'boxHd' => '9572',                  # 0x2564 # SGML Substitute
            'SF480000' => '9573',               # 0x2565 # Adobe Glyph List
            'boxhD' => '9573',                  # 0x2565 # SGML Substitute
            'SF410000' => '9574',               # 0x2566 # Adobe Glyph List
            'boxHD' => '9574',                  # 0x2566 # SGML Substitute
            'SF450000' => '9575',               # 0x2567 # Adobe Glyph List
            'boxHu' => '9575',                  # 0x2567 # SGML Substitute
            'SF460000' => '9576',               # 0x2568 # Adobe Glyph List
            'boxhU' => '9576',                  # 0x2568 # SGML Substitute
            'SF400000' => '9577',               # 0x2569 # Adobe Glyph List
            'boxHU' => '9577',                  # 0x2569 # SGML Substitute
            'SF540000' => '9578',               # 0x256A # Adobe Glyph List
            'boxvH' => '9578',                  # 0x256A # SGML Substitute
            'SF530000' => '9579',               # 0x256B # Adobe Glyph List
            'boxVh' => '9579',                  # 0x256B # SGML Substitute
            'SF440000' => '9580',               # 0x256C # Adobe Glyph List
            'boxVH' => '9580',                  # 0x256C # SGML Substitute
            'uhblk' => '9600',                  # 0x2580 # SGML Substitute
            'upblock' => '9600',                # 0x2580 # Adobe Glyph List
            'dnblock' => '9604',                # 0x2584 # Adobe Glyph List
            'lhblk' => '9604',                  # 0x2584 # SGML Substitute
            'block' => '9608',                  # 0x2588 # Adobe Glyph List
            'lfblock' => '9612',                # 0x258C # Adobe Glyph List
            'rtblock' => '9616',                # 0x2590 # Adobe Glyph List
            'blk14' => '9617',                  # 0x2591 # SGML Substitute
            'ltshade' => '9617',                # 0x2591 # Adobe Glyph List
            'blk12' => '9618',                  # 0x2592 # SGML Substitute
            'shade' => '9618',                  # 0x2592 # Adobe Glyph List
            'blk34' => '9619',                  # 0x2593 # SGML Substitute
            'dkshade' => '9619',                # 0x2593 # Adobe Glyph List
            'filledbox' => '9632',              # 0x25A0 # Adobe Glyph List
            'H22073' => '9633',                 # 0x25A1 # Adobe Glyph List
            'squ' => '9633',                    # 0x25A1 # SGML Substitute
            'square' => '9633',                 # 0x25A1 # SGML Substitute
            'H18543' => '9642',                 # 0x25AA # Adobe Glyph List
            'squf' => '9642',                   # 0x25AA # SGML Substitute
            'H18551' => '9643',                 # 0x25AB # Adobe Glyph List
            'filledrect' => '9644',             # 0x25AC # Adobe Glyph List
            'rect' => '9645',                   # 0x25AD # SGML Substitute
            'marker' => '9646',                 # 0x25AE # SGML Substitute
            'triagup' => '9650',                # 0x25B2 # Adobe Glyph List
            'xutri' => '9651',                  # 0x25B3 # SGML Substitute
            'utrif' => '9652',                  # 0x25B4 # SGML Substitute
            'utri' => '9653',                   # 0x25B5 # SGML Substitute
            'rtrif' => '9656',                  # 0x25B8 # SGML Substitute
            'rtri' => '9657',                   # 0x25B9 # SGML Substitute
            'triagrt' => '9658',                # 0x25BA # Adobe Glyph List
            'triagdn' => '9660',                # 0x25BC # Adobe Glyph List
            'xdtri' => '9661',                  # 0x25BD # SGML Substitute
            'dtrif' => '9662',                  # 0x25BE # SGML Substitute
            'dtri' => '9663',                   # 0x25BF # SGML Substitute
            'ltrif' => '9666',                  # 0x25C2 # SGML Substitute
            'ltri' => '9667',                   # 0x25C3 # SGML Substitute
            'triaglf' => '9668',                # 0x25C4 # Adobe Glyph List
            'a78' => '9670',                    # 0x25C6 # WGL4 Substitute
            'loz' => '9674',                    # 0x25CA # XHTML Substitute
            'lozenge' => '9674',                # 0x25CA # Adobe Glyph List
            'cir' => '9675',                    # 0x25CB # SGML Substitute
            'circle' => '9675',                 # 0x25CB # Adobe Glyph List
            'xcirc' => '9675',                  # 0x25CB # SGML Substitute
            'H18533' => '9679',                 # 0x25CF # Adobe Glyph List
            'a81' => '9687',                    # 0x25D7 # WGL4 Substitute
            'invbullet' => '9688',              # 0x25D8 # Adobe Glyph List
            'invcircle' => '9689',              # 0x25D9 # Adobe Glyph List
            'openbullet' => '9702',             # 0x25E6 # Adobe Glyph List
            'a35' => '9733',                    # 0x2605 # WGL4 Substitute
            'starf' => '9733',                  # 0x2605 # SGML Substitute
            'star' => '9734',                   # 0x2606 # SGML Substitute
            'a4' => '9742',                     # 0x260E # WGL4 Substitute
            'phone' => '9742',                  # 0x260E # SGML Substitute
            'a11' => '9755',                    # 0x261B # WGL4 Substitute
            'a12' => '9758',                    # 0x261E # WGL4 Substitute
            'smileface' => '9786',              # 0x263A # Adobe Glyph List
            'invsmileface' => '9787',           # 0x263B # Adobe Glyph List
            'sun' => '9788',                    # 0x263C # Adobe Glyph List
            'female' => '9792',                 # 0x2640 # Adobe Glyph List
            'male' => '9794',                   # 0x2642 # Adobe Glyph List
            'spade' => '9824',                  # 0x2660 # Adobe Glyph List
            'spades' => '9824',                 # 0x2660 # XHTML Substitute
            'club' => '9827',                   # 0x2663 # Adobe Glyph List
            'clubs' => '9827',                  # 0x2663 # XHTML Substitute
            'heart' => '9829',                  # 0x2665 # Adobe Glyph List
            'hearts' => '9829',                 # 0x2665 # XHTML Substitute
            'diamond' => '9830',                # 0x2666 # Adobe Glyph List
            'diams' => '9830',                  # 0x2666 # XHTML Substitute
            'musicalnote' => '9834',            # 0x266A # Adobe Glyph List
            'sung' => '9834',                   # 0x266A # SGML Substitute
            'musicalnotedbl' => '9835',         # 0x266B # Adobe Glyph List
            'flat' => '9837',                   # 0x266D # SGML Substitute
            'natur' => '9838',                  # 0x266E # SGML Substitute
            'sharp' => '9839',                  # 0x266F # SGML Substitute
            'a1' => '9985',                     # 0x2701 # WGL4 Substitute
            'a2' => '9986',                     # 0x2702 # WGL4 Substitute
            'a202' => '9987',                   # 0x2703 # WGL4 Substitute
            'a3' => '9988',                     # 0x2704 # WGL4 Substitute
            'a5' => '9990',                     # 0x2706 # WGL4 Substitute
            'a119' => '9991',                   # 0x2707 # WGL4 Substitute
            'a118' => '9992',                   # 0x2708 # WGL4 Substitute
            'a117' => '9993',                   # 0x2709 # WGL4 Substitute
            'a13' => '9996',                    # 0x270C # WGL4 Substitute
            'a14' => '9997',                    # 0x270D # WGL4 Substitute
            'a15' => '9998',                    # 0x270E # WGL4 Substitute
            'a16' => '9999',                    # 0x270F # WGL4 Substitute
            'a105' => '10000',                  # 0x2710 # WGL4 Substitute
            'a17' => '10001',                   # 0x2711 # WGL4 Substitute
            'a18' => '10002',                   # 0x2712 # WGL4 Substitute
            'a19' => '10003',                   # 0x2713 # WGL4 Substitute
            'check' => '10003',                 # 0x2713 # SGML Substitute
            'a20' => '10004',                   # 0x2714 # WGL4 Substitute
            'a21' => '10005',                   # 0x2715 # WGL4 Substitute
            'a22' => '10006',                   # 0x2716 # WGL4 Substitute
            'a23' => '10007',                   # 0x2717 # WGL4 Substitute
            'cross' => '10007',                 # 0x2717 # SGML Substitute
            'a24' => '10008',                   # 0x2718 # WGL4 Substitute
            'a25' => '10009',                   # 0x2719 # WGL4 Substitute
            'a26' => '10010',                   # 0x271A # WGL4 Substitute
            'a27' => '10011',                   # 0x271B # WGL4 Substitute
            'a28' => '10012',                   # 0x271C # WGL4 Substitute
            'a6' => '10013',                    # 0x271D # WGL4 Substitute
            'a7' => '10014',                    # 0x271E # WGL4 Substitute
            'a8' => '10015',                    # 0x271F # WGL4 Substitute
            'a9' => '10016',                    # 0x2720 # WGL4 Substitute
            'malt' => '10016',                  # 0x2720 # SGML Substitute
            'a10' => '10017',                   # 0x2721 # WGL4 Substitute
            'a29' => '10018',                   # 0x2722 # WGL4 Substitute
            'a30' => '10019',                   # 0x2723 # WGL4 Substitute
            'a31' => '10020',                   # 0x2724 # WGL4 Substitute
            'a32' => '10021',                   # 0x2725 # WGL4 Substitute
            'a33' => '10022',                   # 0x2726 # WGL4 Substitute
            'lozf' => '10022',                  # 0x2726 # SGML Substitute
            'a34' => '10023',                   # 0x2727 # WGL4 Substitute
            'a36' => '10025',                   # 0x2729 # WGL4 Substitute
            'a37' => '10026',                   # 0x272A # WGL4 Substitute
            'a38' => '10027',                   # 0x272B # WGL4 Substitute
            'a39' => '10028',                   # 0x272C # WGL4 Substitute
            'a40' => '10029',                   # 0x272D # WGL4 Substitute
            'a41' => '10030',                   # 0x272E # WGL4 Substitute
            'a42' => '10031',                   # 0x272F # WGL4 Substitute
            'a43' => '10032',                   # 0x2730 # WGL4 Substitute
            'a44' => '10033',                   # 0x2731 # WGL4 Substitute
            'a45' => '10034',                   # 0x2732 # WGL4 Substitute
            'a46' => '10035',                   # 0x2733 # WGL4 Substitute
            'a47' => '10036',                   # 0x2734 # WGL4 Substitute
            'a48' => '10037',                   # 0x2735 # WGL4 Substitute
            'a49' => '10038',                   # 0x2736 # WGL4 Substitute
            'sextile' => '10038',               # 0x2736 # SGML Substitute
            'a50' => '10039',                   # 0x2737 # WGL4 Substitute
            'a51' => '10040',                   # 0x2738 # WGL4 Substitute
            'a52' => '10041',                   # 0x2739 # WGL4 Substitute
            'a53' => '10042',                   # 0x273A # WGL4 Substitute
            'a54' => '10043',                   # 0x273B # WGL4 Substitute
            'a55' => '10044',                   # 0x273C # WGL4 Substitute
            'a56' => '10045',                   # 0x273D # WGL4 Substitute
            'a57' => '10046',                   # 0x273E # WGL4 Substitute
            'a58' => '10047',                   # 0x273F # WGL4 Substitute
            'a59' => '10048',                   # 0x2740 # WGL4 Substitute
            'a60' => '10049',                   # 0x2741 # WGL4 Substitute
            'a61' => '10050',                   # 0x2742 # WGL4 Substitute
            'a62' => '10051',                   # 0x2743 # WGL4 Substitute
            'a63' => '10052',                   # 0x2744 # WGL4 Substitute
            'a64' => '10053',                   # 0x2745 # WGL4 Substitute
            'a65' => '10054',                   # 0x2746 # WGL4 Substitute
            'a66' => '10055',                   # 0x2747 # WGL4 Substitute
            'a67' => '10056',                   # 0x2748 # WGL4 Substitute
            'a68' => '10057',                   # 0x2749 # WGL4 Substitute
            'a69' => '10058',                   # 0x274A # WGL4 Substitute
            'a70' => '10059',                   # 0x274B # WGL4 Substitute
            'a72' => '10061',                   # 0x274D # WGL4 Substitute
            'a74' => '10063',                   # 0x274F # WGL4 Substitute
            'a203' => '10064',                  # 0x2750 # WGL4 Substitute
            'a75' => '10065',                   # 0x2751 # WGL4 Substitute
            'a204' => '10066',                  # 0x2752 # WGL4 Substitute
            'a79' => '10070',                   # 0x2756 # WGL4 Substitute
            'a82' => '10072',                   # 0x2758 # WGL4 Substitute
            'a83' => '10073',                   # 0x2759 # WGL4 Substitute
            'a84' => '10074',                   # 0x275A # WGL4 Substitute
            'a97' => '10075',                   # 0x275B # WGL4 Substitute
            'a98' => '10076',                   # 0x275C # WGL4 Substitute
            'a99' => '10077',                   # 0x275D # WGL4 Substitute
            'a100' => '10078',                  # 0x275E # WGL4 Substitute
            'a101' => '10081',                  # 0x2761 # WGL4 Substitute
            'a102' => '10082',                  # 0x2762 # WGL4 Substitute
            'a103' => '10083',                  # 0x2763 # WGL4 Substitute
            'a104' => '10084',                  # 0x2764 # WGL4 Substitute
            'a106' => '10085',                  # 0x2765 # WGL4 Substitute
            'a107' => '10086',                  # 0x2766 # WGL4 Substitute
            'a108' => '10087',                  # 0x2767 # WGL4 Substitute
            'a130' => '10102',                  # 0x2776 # WGL4 Substitute
            'a131' => '10103',                  # 0x2777 # WGL4 Substitute
            'a132' => '10104',                  # 0x2778 # WGL4 Substitute
            'a133' => '10105',                  # 0x2779 # WGL4 Substitute
            'a134' => '10106',                  # 0x277A # WGL4 Substitute
            'a135' => '10107',                  # 0x277B # WGL4 Substitute
            'a136' => '10108',                  # 0x277C # WGL4 Substitute
            'a137' => '10109',                  # 0x277D # WGL4 Substitute
            'a138' => '10110',                  # 0x277E # WGL4 Substitute
            'a139' => '10111',                  # 0x277F # WGL4 Substitute
            'a140' => '10112',                  # 0x2780 # WGL4 Substitute
            'a141' => '10113',                  # 0x2781 # WGL4 Substitute
            'a142' => '10114',                  # 0x2782 # WGL4 Substitute
            'a143' => '10115',                  # 0x2783 # WGL4 Substitute
            'a144' => '10116',                  # 0x2784 # WGL4 Substitute
            'a145' => '10117',                  # 0x2785 # WGL4 Substitute
            'a146' => '10118',                  # 0x2786 # WGL4 Substitute
            'a147' => '10119',                  # 0x2787 # WGL4 Substitute
            'a148' => '10120',                  # 0x2788 # WGL4 Substitute
            'a149' => '10121',                  # 0x2789 # WGL4 Substitute
            'a150' => '10122',                  # 0x278A # WGL4 Substitute
            'a151' => '10123',                  # 0x278B # WGL4 Substitute
            'a152' => '10124',                  # 0x278C # WGL4 Substitute
            'a153' => '10125',                  # 0x278D # WGL4 Substitute
            'a154' => '10126',                  # 0x278E # WGL4 Substitute
            'a155' => '10127',                  # 0x278F # WGL4 Substitute
            'a156' => '10128',                  # 0x2790 # WGL4 Substitute
            'a157' => '10129',                  # 0x2791 # WGL4 Substitute
            'a158' => '10130',                  # 0x2792 # WGL4 Substitute
            'a159' => '10131',                  # 0x2793 # WGL4 Substitute
            'a160' => '10132',                  # 0x2794 # WGL4 Substitute
            'a196' => '10136',                  # 0x2798 # WGL4 Substitute
            'a165' => '10137',                  # 0x2799 # WGL4 Substitute
            'a192' => '10138',                  # 0x279A # WGL4 Substitute
            'a166' => '10139',                  # 0x279B # WGL4 Substitute
            'a167' => '10140',                  # 0x279C # WGL4 Substitute
            'a168' => '10141',                  # 0x279D # WGL4 Substitute
            'a169' => '10142',                  # 0x279E # WGL4 Substitute
            'a170' => '10143',                  # 0x279F # WGL4 Substitute
            'a171' => '10144',                  # 0x27A0 # WGL4 Substitute
            'a172' => '10145',                  # 0x27A1 # WGL4 Substitute
            'a173' => '10146',                  # 0x27A2 # WGL4 Substitute
            'a162' => '10147',                  # 0x27A3 # WGL4 Substitute
            'a174' => '10148',                  # 0x27A4 # WGL4 Substitute
            'a175' => '10149',                  # 0x27A5 # WGL4 Substitute
            'a176' => '10150',                  # 0x27A6 # WGL4 Substitute
            'a177' => '10151',                  # 0x27A7 # WGL4 Substitute
            'a178' => '10152',                  # 0x27A8 # WGL4 Substitute
            'a179' => '10153',                  # 0x27A9 # WGL4 Substitute
            'a193' => '10154',                  # 0x27AA # WGL4 Substitute
            'a180' => '10155',                  # 0x27AB # WGL4 Substitute
            'a199' => '10156',                  # 0x27AC # WGL4 Substitute
            'a181' => '10157',                  # 0x27AD # WGL4 Substitute
            'a200' => '10158',                  # 0x27AE # WGL4 Substitute
            'a182' => '10159',                  # 0x27AF # WGL4 Substitute
            'a201' => '10161',                  # 0x27B1 # WGL4 Substitute
            'a183' => '10162',                  # 0x27B2 # WGL4 Substitute
            'a184' => '10163',                  # 0x27B3 # WGL4 Substitute
            'a197' => '10164',                  # 0x27B4 # WGL4 Substitute
            'a185' => '10165',                  # 0x27B5 # WGL4 Substitute
            'a194' => '10166',                  # 0x27B6 # WGL4 Substitute
            'a198' => '10167',                  # 0x27B7 # WGL4 Substitute
            'a186' => '10168',                  # 0x27B8 # WGL4 Substitute
            'a195' => '10169',                  # 0x27B9 # WGL4 Substitute
            'a187' => '10170',                  # 0x27BA # WGL4 Substitute
            'a188' => '10171',                  # 0x27BB # WGL4 Substitute
            'a189' => '10172',                  # 0x27BC # WGL4 Substitute
            'a190' => '10173',                  # 0x27BD # WGL4 Substitute
            'a191' => '10174',                  # 0x27BE # WGL4 Substitute
            'pencil' => '61473',                # 0xF021 # MS Wingdings
            'scissors' => '61474',              # 0xF022 # MS Wingdings
            'scissorscutting' => '61475',       # 0xF023 # MS Wingdings
            'readingglasses' => '61476',        # 0xF024 # MS Wingdings
            'bell' => '61477',                  # 0xF025 # MS Wingdings
            'book' => '61478',                  # 0xF026 # MS Wingdings
            'candle' => '61479',                # 0xF027 # MS Wingdings
            'telephonesolid' => '61480',        # 0xF028 # MS Wingdings
            'telhandsetcirc' => '61481',        # 0xF029 # MS Wingdings
            'envelopeback' => '61482',          # 0xF02A # MS Wingdings
            'envelopefront' => '61483',         # 0xF02B # MS Wingdings
            'mailboxflagdwn' => '61484',        # 0xF02C # MS Wingdings
            'mailboxflagup' => '61485',         # 0xF02D # MS Wingdings
            'mailbxopnflgup' => '61486',        # 0xF02E # MS Wingdings
            'mailbxopnflgdwn' => '61487',       # 0xF02F # MS Wingdings
            'folder' => '61488',                # 0xF030 # MS Wingdings
            'folderopen' => '61489',            # 0xF031 # MS Wingdings
            'filetalltext1' => '61490',         # 0xF032 # MS Wingdings
            'filetalltext' => '61491',          # 0xF033 # MS Wingdings
            'filetalltext3' => '61492',         # 0xF034 # MS Wingdings
            'filecabinet' => '61493',           # 0xF035 # MS Wingdings
            'hourglass' => '61494',             # 0xF036 # MS Wingdings
            'keyboard' => '61495',              # 0xF037 # MS Wingdings
            'mouse2button' => '61496',          # 0xF038 # MS Wingdings
            'ballpoint' => '61497',             # 0xF039 # MS Wingdings
            'pc' => '61498',                    # 0xF03A # MS Wingdings
            'harddisk' => '61499',              # 0xF03B # MS Wingdings
            'floppy3' => '61500',               # 0xF03C # MS Wingdings
            'floppy5' => '61501',               # 0xF03D # MS Wingdings
            'tapereel' => '61502',              # 0xF03E # MS Wingdings
            'handwrite' => '61503',             # 0xF03F # MS Wingdings
            'handwriteleft' => '61504',         # 0xF040 # MS Wingdings
            'handv' => '61505',                 # 0xF041 # MS Wingdings
            'handok' => '61506',                # 0xF042 # MS Wingdings
            'thumbup' => '61507',               # 0xF043 # MS Wingdings
            'thumbdown' => '61508',             # 0xF044 # MS Wingdings
            'handptleft' => '61509',            # 0xF045 # MS Wingdings
            'handptright' => '61510',           # 0xF046 # MS Wingdings
            'handptup' => '61511',              # 0xF047 # MS Wingdings
            'handptdwn' => '61512',             # 0xF048 # MS Wingdings
            'handhalt' => '61513',              # 0xF049 # MS Wingdings
            'neutralface' => '61515',           # 0xF04B # MS Wingdings
            'frownface' => '61516',             # 0xF04C # MS Wingdings
            'bomb' => '61517',                  # 0xF04D # MS Wingdings
            'skullcrossbones' => '61518',       # 0xF04E # MS Wingdings
            'flag' => '61519',                  # 0xF04F # MS Wingdings
            'pennant' => '61520',               # 0xF050 # MS Wingdings
            'airplane' => '61521',              # 0xF051 # MS Wingdings
            'sunshine' => '61522',              # 0xF052 # MS Wingdings
            'droplet' => '61523',               # 0xF053 # MS Wingdings
            'snowflake' => '61524',             # 0xF054 # MS Wingdings
            'crossoutline' => '61525',          # 0xF055 # MS Wingdings
            'crossshadow' => '61526',           # 0xF056 # MS Wingdings
            'crossceltic' => '61527',           # 0xF057 # MS Wingdings
            'crossmaltese' => '61528',          # 0xF058 # MS Wingdings
            'starofdavid' => '61529',           # 0xF059 # MS Wingdings
            'crescentstar' => '61530',          # 0xF05A # MS Wingdings
            'yinyang' => '61531',               # 0xF05B # MS Wingdings
            'om' => '61532',                    # 0xF05C # MS Wingdings
            'wheel' => '61533',                 # 0xF05D # MS Wingdings
            'aries' => '61534',                 # 0xF05E # MS Wingdings
            'taurus' => '61535',                # 0xF05F # MS Wingdings
            'gemini' => '61536',                # 0xF060 # MS Wingdings
            'cancer' => '61537',                # 0xF061 # MS Wingdings
            'leo' => '61538',                   # 0xF062 # MS Wingdings
            'virgo' => '61539',                 # 0xF063 # MS Wingdings
            'libra' => '61540',                 # 0xF064 # MS Wingdings
            'scorpio' => '61541',               # 0xF065 # MS Wingdings
            'saggitarius' => '61542',           # 0xF066 # MS Wingdings
            'capricorn' => '61543',             # 0xF067 # MS Wingdings
            'aquarius' => '61544',              # 0xF068 # MS Wingdings
            'pisces' => '61545',                # 0xF069 # MS Wingdings
            'ampersanditlc' => '61546',         # 0xF06A # MS Wingdings
            'ampersandit' => '61547',           # 0xF06B # MS Wingdings
            'circle6' => '61548',               # 0xF06C # MS Wingdings
            'circleshadowdwn' => '61549',       # 0xF06D # MS Wingdings
            'square6' => '61550',               # 0xF06E # MS Wingdings
            'box3' => '61551',                  # 0xF06F # MS Wingdings
            'box4' => '61552',                  # 0xF070 # MS Wingdings
            'boxshadowdwn' => '61553',          # 0xF071 # MS Wingdings
            'boxshadowup' => '61554',           # 0xF072 # MS Wingdings
            'lozenge4' => '61555',              # 0xF073 # MS Wingdings
            'lozenge6' => '61556',              # 0xF074 # MS Wingdings
            'rhombus6' => '61557',              # 0xF075 # MS Wingdings
            'xrhombus' => '61558',              # 0xF076 # MS Wingdings
            'rhombus4' => '61559',              # 0xF077 # MS Wingdings
            'clear' => '61560',                 # 0xF078 # MS Wingdings
            'escape' => '61561',                # 0xF079 # MS Wingdings
            'command' => '61562',               # 0xF07A # MS Wingdings
            'rosette' => '61563',               # 0xF07B # MS Wingdings
            'rosettesolid' => '61564',          # 0xF07C # MS Wingdings
            'quotedbllftbld' => '61565',        # 0xF07D # MS Wingdings
            'quotedblrtbld' => '61566',         # 0xF07E # MS Wingdings
            'zerosans' => '61568',              # 0xF080 # MS Wingdings
            'onesans' => '61569',               # 0xF081 # MS Wingdings
            'twosans' => '61570',               # 0xF082 # MS Wingdings
            'threesans' => '61571',             # 0xF083 # MS Wingdings
            'foursans' => '61572',              # 0xF084 # MS Wingdings
            'fivesans' => '61573',              # 0xF085 # MS Wingdings
            'sixsans' => '61574',               # 0xF086 # MS Wingdings
            'sevensans' => '61575',             # 0xF087 # MS Wingdings
            'eightsans' => '61576',             # 0xF088 # MS Wingdings
            'ninesans' => '61577',              # 0xF089 # MS Wingdings
            'tensans' => '61578',               # 0xF08A # MS Wingdings
            'zerosansinv' => '61579',           # 0xF08B # MS Wingdings
            'onesansinv' => '61580',            # 0xF08C # MS Wingdings
            'twosansinv' => '61581',            # 0xF08D # MS Wingdings
            'threesansinv' => '61582',          # 0xF08E # MS Wingdings
            'foursansinv' => '61583',           # 0xF08F # MS Wingdings
            'fivesansinv' => '61584',           # 0xF090 # MS Wingdings
            'sixsansinv' => '61585',            # 0xF091 # MS Wingdings
            'sevensansinv' => '61586',          # 0xF092 # MS Wingdings
            'eightsansinv' => '61587',          # 0xF093 # MS Wingdings
            'ninesansinv' => '61588',           # 0xF094 # MS Wingdings
            'tensansinv' => '61589',            # 0xF095 # MS Wingdings
            'budleafne' => '61590',             # 0xF096 # MS Wingdings
            'budleafnw' => '61591',             # 0xF097 # MS Wingdings
            'budleafsw' => '61592',             # 0xF098 # MS Wingdings
            'budleafse' => '61593',             # 0xF099 # MS Wingdings
            'vineleafboldne' => '61594',        # 0xF09A # MS Wingdings
            'vineleafboldnw' => '61595',        # 0xF09B # MS Wingdings
            'vineleafboldsw' => '61596',        # 0xF09C # MS Wingdings
            'vineleafboldse' => '61597',        # 0xF09D # MS Wingdings
            'circle2' => '61598',               # 0xF09E # MS Wingdings
            'circle4' => '61599',               # 0xF09F # MS Wingdings
            'square2' => '61600',               # 0xF0A0 # MS Wingdings
            'ring2' => '61601',                 # 0xF0A1 # MS Wingdings
            'ring4' => '61602',                 # 0xF0A2 # MS Wingdings
            'ring6' => '61603',                 # 0xF0A3 # MS Wingdings
            'ringbutton2' => '61604',           # 0xF0A4 # MS Wingdings
            'target' => '61605',                # 0xF0A5 # MS Wingdings
            'circleshadowup' => '61606',        # 0xF0A6 # MS Wingdings
            'square4' => '61607',               # 0xF0A7 # MS Wingdings
            'box2' => '61608',                  # 0xF0A8 # MS Wingdings
            'tristar2' => '61609',              # 0xF0A9 # MS Wingdings
            'crosstar2' => '61610',             # 0xF0AA # MS Wingdings
            'pentastar2' => '61611',            # 0xF0AB # MS Wingdings
            'hexstar2' => '61612',              # 0xF0AC # MS Wingdings
            'octastar2' => '61613',             # 0xF0AD # MS Wingdings
            'dodecastar3' => '61614',           # 0xF0AE # MS Wingdings
            'octastar4' => '61615',             # 0xF0AF # MS Wingdings
            'registersquare' => '61616',        # 0xF0B0 # MS Wingdings
            'registercircle' => '61617',        # 0xF0B1 # MS Wingdings
            'cuspopen' => '61618',              # 0xF0B2 # MS Wingdings
            'cuspopen1' => '61619',             # 0xF0B3 # MS Wingdings
            'query' => '61620',                 # 0xF0B4 # MS Wingdings
            'circlestar' => '61621',            # 0xF0B5 # MS Wingdings
            'starshadow' => '61622',            # 0xF0B6 # MS Wingdings
            'oneoclock' => '61623',             # 0xF0B7 # MS Wingdings
            'twooclock' => '61624',             # 0xF0B8 # MS Wingdings
            'threeoclock' => '61625',           # 0xF0B9 # MS Wingdings
            'fouroclock' => '61626',            # 0xF0BA # MS Wingdings
            'fiveoclock' => '61627',            # 0xF0BB # MS Wingdings
            'sixoclock' => '61628',             # 0xF0BC # MS Wingdings
            'sevenoclock' => '61629',           # 0xF0BD # MS Wingdings
            'eightoclock' => '61630',           # 0xF0BE # MS Wingdings
            'nineoclock' => '61631',            # 0xF0BF # MS Wingdings
            'tenoclock' => '61632',             # 0xF0C0 # MS Wingdings
            'elevenoclock' => '61633',          # 0xF0C1 # MS Wingdings
            'twelveoclock' => '61634',          # 0xF0C2 # MS Wingdings
            'arrowdwnleft1' => '61635',         # 0xF0C3 # MS Wingdings
            'arrowdwnrt1' => '61636',           # 0xF0C4 # MS Wingdings
            'arrowupleft1' => '61637',          # 0xF0C5 # MS Wingdings
            'arrowuprt1' => '61638',            # 0xF0C6 # MS Wingdings
            'arrowleftup1' => '61639',          # 0xF0C7 # MS Wingdings
            'arrowrtup1' => '61640',            # 0xF0C8 # MS Wingdings
            'arrowleftdwn1' => '61641',         # 0xF0C9 # MS Wingdings
            'arrowrtdwn1' => '61642',           # 0xF0CA # MS Wingdings
            'quiltsquare2' => '61643',          # 0xF0CB # MS Wingdings
            'quiltsquare2inv' => '61644',       # 0xF0CC # MS Wingdings
            'leafccwsw' => '61645',             # 0xF0CD # MS Wingdings
            'leafccwnw' => '61646',             # 0xF0CE # MS Wingdings
            'leafccwse' => '61647',             # 0xF0CF # MS Wingdings
            'leafccwne' => '61648',             # 0xF0D0 # MS Wingdings
            'leafnw' => '61649',                # 0xF0D1 # MS Wingdings
            'leafsw' => '61650',                # 0xF0D2 # MS Wingdings
            'leafne' => '61651',                # 0xF0D3 # MS Wingdings
            'leafse' => '61652',                # 0xF0D4 # MS Wingdings
            'deleteleft' => '61653',            # 0xF0D5 # MS Wingdings
            'deleteright' => '61654',           # 0xF0D6 # MS Wingdings
            'head2left' => '61655',             # 0xF0D7 # MS Wingdings
            'head2right' => '61656',            # 0xF0D8 # MS Wingdings
            'head2up' => '61657',               # 0xF0D9 # MS Wingdings
            'head2down' => '61658',             # 0xF0DA # MS Wingdings
            'circleleft' => '61659',            # 0xF0DB # MS Wingdings
            'circleright' => '61660',           # 0xF0DC # MS Wingdings
            'circleup' => '61661',              # 0xF0DD # MS Wingdings
            'circledown' => '61662',            # 0xF0DE # MS Wingdings
            'barb2left' => '61663',             # 0xF0DF # MS Wingdings
            'barb2right' => '61664',            # 0xF0E0 # MS Wingdings
            'barb2up' => '61665',               # 0xF0E1 # MS Wingdings
            'barb2down' => '61666',             # 0xF0E2 # MS Wingdings
            'barb2nw' => '61667',               # 0xF0E3 # MS Wingdings
            'barb2ne' => '61668',               # 0xF0E4 # MS Wingdings
            'barb2sw' => '61669',               # 0xF0E5 # MS Wingdings
            'barb2se' => '61670',               # 0xF0E6 # MS Wingdings
            'barb4left' => '61671',             # 0xF0E7 # MS Wingdings
            'barb4right' => '61672',            # 0xF0E8 # MS Wingdings
            'barb4up' => '61673',               # 0xF0E9 # MS Wingdings
            'barb4down' => '61674',             # 0xF0EA # MS Wingdings
            'barb4nw' => '61675',               # 0xF0EB # MS Wingdings
            'barb4ne' => '61676',               # 0xF0EC # MS Wingdings
            'barb4sw' => '61677',               # 0xF0ED # MS Wingdings
            'barb4se' => '61678',               # 0xF0EE # MS Wingdings
            'bleft' => '61679',                 # 0xF0EF # MS Wingdings
            'bright' => '61680',                # 0xF0F0 # MS Wingdings
            'bup' => '61681',                   # 0xF0F1 # MS Wingdings
            'bdown' => '61682',                 # 0xF0F2 # MS Wingdings
            'bleftright' => '61683',            # 0xF0F3 # MS Wingdings
            'bupdown' => '61684',               # 0xF0F4 # MS Wingdings
            'bnw' => '61685',                   # 0xF0F5 # MS Wingdings
            'bne' => '61686',                   # 0xF0F6 # MS Wingdings
            'bsw' => '61687',                   # 0xF0F7 # MS Wingdings
            'bse' => '61688',                   # 0xF0F8 # MS Wingdings
            'bdash1' => '61689',                # 0xF0F9 # MS Wingdings
            'bdash2' => '61690',                # 0xF0FA # MS Wingdings
            'xmarkbld' => '61691',              # 0xF0FB # MS Wingdings
            'checkbld' => '61692',              # 0xF0FC # MS Wingdings
            'boxxmarkbld' => '61693',           # 0xF0FD # MS Wingdings
            'boxcheckbld' => '61694',           # 0xF0FE # MS Wingdings
            'windowslogo' => '61695',           # 0xF0FF # MS Wingdings
            'dotlessj' => '63166',              # 0xF6BE # Adobe Glyph List
            'LL' => '63167',                    # 0xF6BF # Adobe Glyph List
            'll' => '63168',                    # 0xF6C0 # Adobe Glyph List
            'commaaccent' => '63171',           # 0xF6C3 # Adobe Glyph List
            'afii10063' => '63172',             # 0xF6C4 # Adobe Glyph List
            'afii10064' => '63173',             # 0xF6C5 # Adobe Glyph List
            'afii10192' => '63174',             # 0xF6C6 # Adobe Glyph List
            'afii10831' => '63175',             # 0xF6C7 # Adobe Glyph List
            'afii10832' => '63176',             # 0xF6C8 # Adobe Glyph List
            'Acute' => '63177',                 # 0xF6C9 # Adobe Glyph List
            'Caron' => '63178',                 # 0xF6CA # Adobe Glyph List
            'Dieresis' => '63179',              # 0xF6CB # Adobe Glyph List
            'DieresisAcute' => '63180',         # 0xF6CC # Adobe Glyph List
            'DieresisGrave' => '63181',         # 0xF6CD # Adobe Glyph List
            'Grave' => '63182',                 # 0xF6CE # Adobe Glyph List
            'Hungarumlaut' => '63183',          # 0xF6CF # Adobe Glyph List
            'Macron' => '63184',                # 0xF6D0 # Adobe Glyph List
            'cyrBreve' => '63185',              # 0xF6D1 # Adobe Glyph List
            'cyrFlex' => '63186',               # 0xF6D2 # Adobe Glyph List
            'dblGrave' => '63187',              # 0xF6D3 # Adobe Glyph List
            'cyrbreve' => '63188',              # 0xF6D4 # Adobe Glyph List
            'cyrflex' => '63189',               # 0xF6D5 # Adobe Glyph List
            'dblgrave' => '63190',              # 0xF6D6 # Adobe Glyph List
            'dieresisacute' => '63191',         # 0xF6D7 # Adobe Glyph List
            'dieresisgrave' => '63192',         # 0xF6D8 # Adobe Glyph List
            'copyrightserif' => '63193',        # 0xF6D9 # Adobe Glyph List
            'registerserif' => '63194',         # 0xF6DA # Adobe Glyph List
            'trademarkserif' => '63195',        # 0xF6DB # Adobe Glyph List
            'onefitted' => '63196',             # 0xF6DC # Adobe Glyph List
            'rupiah' => '63197',                # 0xF6DD # Adobe Glyph List
            'threequartersemdash' => '63198',   # 0xF6DE # Adobe Glyph List
            'centinferior' => '63199',          # 0xF6DF # Adobe Glyph List
            'centsuperior' => '63200',          # 0xF6E0 # Adobe Glyph List
            'commainferior' => '63201',         # 0xF6E1 # Adobe Glyph List
            'commasuperior' => '63202',         # 0xF6E2 # Adobe Glyph List
            'dollarinferior' => '63203',        # 0xF6E3 # Adobe Glyph List
            'dollarsuperior' => '63204',        # 0xF6E4 # Adobe Glyph List
            'hypheninferior' => '63205',        # 0xF6E5 # Adobe Glyph List
            'hyphensuperior' => '63206',        # 0xF6E6 # Adobe Glyph List
            'periodinferior' => '63207',        # 0xF6E7 # Adobe Glyph List
            'periodsuperior' => '63208',        # 0xF6E8 # Adobe Glyph List
            'asuperior' => '63209',             # 0xF6E9 # Adobe Glyph List
            'bsuperior' => '63210',             # 0xF6EA # Adobe Glyph List
            'dsuperior' => '63211',             # 0xF6EB # Adobe Glyph List
            'esuperior' => '63212',             # 0xF6EC # Adobe Glyph List
            'isuperior' => '63213',             # 0xF6ED # Adobe Glyph List
            'lsuperior' => '63214',             # 0xF6EE # Adobe Glyph List
            'msuperior' => '63215',             # 0xF6EF # Adobe Glyph List
            'osuperior' => '63216',             # 0xF6F0 # Adobe Glyph List
            'rsuperior' => '63217',             # 0xF6F1 # Adobe Glyph List
            'ssuperior' => '63218',             # 0xF6F2 # Adobe Glyph List
            'tsuperior' => '63219',             # 0xF6F3 # Adobe Glyph List
            'Brevesmall' => '63220',            # 0xF6F4 # Adobe Glyph List
            'Caronsmall' => '63221',            # 0xF6F5 # Adobe Glyph List
            'Circumflexsmall' => '63222',       # 0xF6F6 # Adobe Glyph List
            'Dotaccentsmall' => '63223',        # 0xF6F7 # Adobe Glyph List
            'Hungarumlautsmall' => '63224',     # 0xF6F8 # Adobe Glyph List
            'Lslashsmall' => '63225',           # 0xF6F9 # Adobe Glyph List
            'OEsmall' => '63226',               # 0xF6FA # Adobe Glyph List
            'Ogoneksmall' => '63227',           # 0xF6FB # Adobe Glyph List
            'Ringsmall' => '63228',             # 0xF6FC # Adobe Glyph List
            'Scaronsmall' => '63229',           # 0xF6FD # Adobe Glyph List
            'Tildesmall' => '63230',            # 0xF6FE # Adobe Glyph List
            'Zcaronsmall' => '63231',           # 0xF6FF # Adobe Glyph List
            'exclamsmall' => '63265',           # 0xF721 # Adobe Glyph List
            'dollaroldstyle' => '63268',        # 0xF724 # Adobe Glyph List
            'ampersandsmall' => '63270',        # 0xF726 # Adobe Glyph List
            'zerooldstyle' => '63280',          # 0xF730 # Adobe Glyph List
            'oneoldstyle' => '63281',           # 0xF731 # Adobe Glyph List
            'twooldstyle' => '63282',           # 0xF732 # Adobe Glyph List
            'threeoldstyle' => '63283',         # 0xF733 # Adobe Glyph List
            'fouroldstyle' => '63284',          # 0xF734 # Adobe Glyph List
            'fiveoldstyle' => '63285',          # 0xF735 # Adobe Glyph List
            'sixoldstyle' => '63286',           # 0xF736 # Adobe Glyph List
            'sevenoldstyle' => '63287',         # 0xF737 # Adobe Glyph List
            'eightoldstyle' => '63288',         # 0xF738 # Adobe Glyph List
            'nineoldstyle' => '63289',          # 0xF739 # Adobe Glyph List
            'questionsmall' => '63295',         # 0xF73F # Adobe Glyph List
            'Gravesmall' => '63328',            # 0xF760 # Adobe Glyph List
            'Asmall' => '63329',                # 0xF761 # Adobe Glyph List
            'Bsmall' => '63330',                # 0xF762 # Adobe Glyph List
            'Csmall' => '63331',                # 0xF763 # Adobe Glyph List
            'Dsmall' => '63332',                # 0xF764 # Adobe Glyph List
            'Esmall' => '63333',                # 0xF765 # Adobe Glyph List
            'Fsmall' => '63334',                # 0xF766 # Adobe Glyph List
            'Gsmall' => '63335',                # 0xF767 # Adobe Glyph List
            'Hsmall' => '63336',                # 0xF768 # Adobe Glyph List
            'Ismall' => '63337',                # 0xF769 # Adobe Glyph List
            'Jsmall' => '63338',                # 0xF76A # Adobe Glyph List
            'Ksmall' => '63339',                # 0xF76B # Adobe Glyph List
            'Lsmall' => '63340',                # 0xF76C # Adobe Glyph List
            'Msmall' => '63341',                # 0xF76D # Adobe Glyph List
            'Nsmall' => '63342',                # 0xF76E # Adobe Glyph List
            'Osmall' => '63343',                # 0xF76F # Adobe Glyph List
            'Psmall' => '63344',                # 0xF770 # Adobe Glyph List
            'Qsmall' => '63345',                # 0xF771 # Adobe Glyph List
            'Rsmall' => '63346',                # 0xF772 # Adobe Glyph List
            'Ssmall' => '63347',                # 0xF773 # Adobe Glyph List
            'Tsmall' => '63348',                # 0xF774 # Adobe Glyph List
            'Usmall' => '63349',                # 0xF775 # Adobe Glyph List
            'Vsmall' => '63350',                # 0xF776 # Adobe Glyph List
            'Wsmall' => '63351',                # 0xF777 # Adobe Glyph List
            'Xsmall' => '63352',                # 0xF778 # Adobe Glyph List
            'Ysmall' => '63353',                # 0xF779 # Adobe Glyph List
            'Zsmall' => '63354',                # 0xF77A # Adobe Glyph List
            'exclamdownsmall' => '63393',       # 0xF7A1 # Adobe Glyph List
            'centoldstyle' => '63394',          # 0xF7A2 # Adobe Glyph List
            'Dieresissmall' => '63400',         # 0xF7A8 # Adobe Glyph List
            'Macronsmall' => '63407',           # 0xF7AF # Adobe Glyph List
            'Acutesmall' => '63412',            # 0xF7B4 # Adobe Glyph List
            'Cedillasmall' => '63416',          # 0xF7B8 # Adobe Glyph List
            'questiondownsmall' => '63423',     # 0xF7BF # Adobe Glyph List
            'Agravesmall' => '63456',           # 0xF7E0 # Adobe Glyph List
            'Aacutesmall' => '63457',           # 0xF7E1 # Adobe Glyph List
            'Acircumflexsmall' => '63458',      # 0xF7E2 # Adobe Glyph List
            'Atildesmall' => '63459',           # 0xF7E3 # Adobe Glyph List
            'Adieresissmall' => '63460',        # 0xF7E4 # Adobe Glyph List
            'Aringsmall' => '63461',            # 0xF7E5 # Adobe Glyph List
            'AEsmall' => '63462',               # 0xF7E6 # Adobe Glyph List
            'Ccedillasmall' => '63463',         # 0xF7E7 # Adobe Glyph List
            'Egravesmall' => '63464',           # 0xF7E8 # Adobe Glyph List
            'Eacutesmall' => '63465',           # 0xF7E9 # Adobe Glyph List
            'Ecircumflexsmall' => '63466',      # 0xF7EA # Adobe Glyph List
            'Edieresissmall' => '63467',        # 0xF7EB # Adobe Glyph List
            'Igravesmall' => '63468',           # 0xF7EC # Adobe Glyph List
            'Iacutesmall' => '63469',           # 0xF7ED # Adobe Glyph List
            'Icircumflexsmall' => '63470',      # 0xF7EE # Adobe Glyph List
            'Idieresissmall' => '63471',        # 0xF7EF # Adobe Glyph List
            'Ethsmall' => '63472',              # 0xF7F0 # Adobe Glyph List
            'Ntildesmall' => '63473',           # 0xF7F1 # Adobe Glyph List
            'Ogravesmall' => '63474',           # 0xF7F2 # Adobe Glyph List
            'Oacutesmall' => '63475',           # 0xF7F3 # Adobe Glyph List
            'Ocircumflexsmall' => '63476',      # 0xF7F4 # Adobe Glyph List
            'Otildesmall' => '63477',           # 0xF7F5 # Adobe Glyph List
            'Odieresissmall' => '63478',        # 0xF7F6 # Adobe Glyph List
            'Oslashsmall' => '63480',           # 0xF7F8 # Adobe Glyph List
            'Ugravesmall' => '63481',           # 0xF7F9 # Adobe Glyph List
            'Uacutesmall' => '63482',           # 0xF7FA # Adobe Glyph List
            'Ucircumflexsmall' => '63483',      # 0xF7FB # Adobe Glyph List
            'Udieresissmall' => '63484',        # 0xF7FC # Adobe Glyph List
            'Yacutesmall' => '63485',           # 0xF7FD # Adobe Glyph List
            'Thornsmall' => '63486',            # 0xF7FE # Adobe Glyph List
            'Ydieresissmall' => '63487',        # 0xF7FF # Adobe Glyph List
            'a89' => '63703',                   # 0xF8D7 # WGL4 Substitute
            'a90' => '63704',                   # 0xF8D8 # WGL4 Substitute
            'a93' => '63705',                   # 0xF8D9 # WGL4 Substitute
            'a94' => '63706',                   # 0xF8DA # WGL4 Substitute
            'a91' => '63707',                   # 0xF8DB # WGL4 Substitute
            'a92' => '63708',                   # 0xF8DC # WGL4 Substitute
            'a205' => '63709',                  # 0xF8DD # WGL4 Substitute
            'a85' => '63710',                   # 0xF8DE # WGL4 Substitute
            'a206' => '63711',                  # 0xF8DF # WGL4 Substitute
            'a86' => '63712',                   # 0xF8E0 # WGL4 Substitute
            'a87' => '63713',                   # 0xF8E1 # WGL4 Substitute
            'a88' => '63714',                   # 0xF8E2 # WGL4 Substitute
            'a95' => '63715',                   # 0xF8E3 # WGL4 Substitute
            'a96' => '63716',                   # 0xF8E4 # WGL4 Substitute
            'radicalex' => '63717',             # 0xF8E5 # Adobe Glyph List
            'arrowvertex' => '63718',           # 0xF8E6 # Adobe Glyph List
            'arrowhorizex' => '63719',          # 0xF8E7 # Adobe Glyph List
            'registersans' => '63720',          # 0xF8E8 # Adobe Glyph List
            'copyrightsans' => '63721',         # 0xF8E9 # Adobe Glyph List
            'trademarksans' => '63722',         # 0xF8EA # Adobe Glyph List
            'parenlefttp' => '63723',           # 0xF8EB # Adobe Glyph List
            'parenleftex' => '63724',           # 0xF8EC # Adobe Glyph List
            'parenleftbt' => '63725',           # 0xF8ED # Adobe Glyph List
            'bracketlefttp' => '63726',         # 0xF8EE # Adobe Glyph List
            'bracketleftex' => '63727',         # 0xF8EF # Adobe Glyph List
            'bracketleftbt' => '63728',         # 0xF8F0 # Adobe Glyph List
            'bracelefttp' => '63729',           # 0xF8F1 # Adobe Glyph List
            'braceleftmid' => '63730',          # 0xF8F2 # Adobe Glyph List
            'braceleftbt' => '63731',           # 0xF8F3 # Adobe Glyph List
            'braceex' => '63732',               # 0xF8F4 # Adobe Glyph List
            'integralex' => '63733',            # 0xF8F5 # Adobe Glyph List
            'parenrighttp' => '63734',          # 0xF8F6 # Adobe Glyph List
            'parenrightex' => '63735',          # 0xF8F7 # Adobe Glyph List
            'parenrightbt' => '63736',          # 0xF8F8 # Adobe Glyph List
            'bracketrighttp' => '63737',        # 0xF8F9 # Adobe Glyph List
            'bracketrightex' => '63738',        # 0xF8FA # Adobe Glyph List
            'bracketrightbt' => '63739',        # 0xF8FB # Adobe Glyph List
            'bracerighttp' => '63740',          # 0xF8FC # Adobe Glyph List
            'bracerightmid' => '63741',         # 0xF8FD # Adobe Glyph List
            'bracerightbt' => '63742',          # 0xF8FE # Adobe Glyph List
            'ff' => '64256',                    # 0xFB00 # Adobe Glyph List
            'fi' => '64257',                    # 0xFB01 # Adobe Glyph List
            'fl' => '64258',                    # 0xFB02 # Adobe Glyph List
            'ffi' => '64259',                   # 0xFB03 # Adobe Glyph List
            'ffl' => '64260',                   # 0xFB04 # Adobe Glyph List
            'afii57705' => '64287',             # 0xFB1F # Adobe Glyph List
            'afii57694' => '64298',             # 0xFB2A # Adobe Glyph List
            'afii57695' => '64299',             # 0xFB2B # Adobe Glyph List
            'afii57723' => '64309',             # 0xFB35 # Adobe Glyph List
            'afii57700' => '64331',             # 0xFB4B # Adobe Glyph List
    );

    %u2n=%u2n_o;
    %n2u=%n2u_o;

    %colors=(
        'aliceblue'                => '#EFF7FF',   #
        'antiquewhite'             => '#F9EAD7',   #
        'antiquewhite1'            => '#FFEEDB',   #
        'antiquewhite2'            => '#EDDFCC',   #
        'antiquewhite3'            => '#CDBFB0',   #
        'antiquewhite4'            => '#8A8278',   #
        'aqua'                     => '#00FFFF',   #
        'aquamarine'               => '#7FFFD4',   #
        'aquamarine1'              => '#7FFFD4',   #
        'aquamarine2'              => '#76EDC5',   #
        'aquamarine3'              => '#66CDAA',   #
        'aquamarine4'              => '#458A74',   #
        'azure'                    => '#EFFFFF',   #
        'azure1'                   => '#EFFFFF',   #
        'azure2'                   => '#E0EDED',   #
        'azure3'                   => '#C0CDCD',   #
        'azure4'                   => '#828A8A',   #
        'beige'                    => '#F4F4DC',   #
        'bisque'                   => '#FFE4C3',   #
        'bisque1'                  => '#FFE4C3',   #
        'bisque2'                  => '#EDD5B6',   #
        'bisque3'                  => '#CDB69E',   #
        'bisque4'                  => '#8A7D6B',   #
        'black'                    => '#000000',   #
        'blanchedalmond'           => '#FFEACD',   #
        'blue'                     => '#0000FF',   #
        'blue1'                    => '#0000FF',   #
        'blue2'                    => '#0000ED',   #
        'blue3'                    => '#0000CD',   #
        'blue4'                    => '#00008A',   #
        'blueviolet'               => '#9F5E9F',   #
        'brass'                    => '#B4A642',   #
        'brightgold'               => '#D9D918',   #
        'bronze'                   => '#8B7852',   #
        'bronzeii'                 => '#A67D3D',   #
        'brown'                    => '#A52929',   #
        'brown1'                   => '#FF4040',   #
        'brown2'                   => '#ED3B3B',   #
        'brown3'                   => '#CD3333',   #
        'brown4'                   => '#8A2222',   #
        'burlywood'                => '#DEB786',   #
        'burlywood1'               => '#FFD39B',   #
        'burlywood2'               => '#EDC490',   #
        'burlywood3'               => '#CDAA7D',   #
        'burlywood4'               => '#8A7354',   #
        'cadetblue'                => '#5E9EA0',   #
        'cadetblue1'               => '#98F4FF',   #
        'cadetblue2'               => '#8DE5ED',   #
        'cadetblue3'               => '#7AC4CD',   #
        'cadetblue4'               => '#52858A',   #
        'chartreuse'               => '#7FFF00',   #
        'chartreuse1'              => '#7FFF00',   #
        'chartreuse2'              => '#76ED00',   #
        'chartreuse3'              => '#66CD00',   #
        'chartreuse4'              => '#458A00',   #
        'chocolate'                => '#D2691D',   #
        'chocolate1'               => '#FF7F23',   #
        'chocolate2'               => '#ED7620',   #
        'chocolate3'               => '#CD661C',   #
        'chocolate4'               => '#8A4512',   #
        'coolcopper'               => '#D98618',   #
        'coral'                    => '#FF7F4F',   #
        'coral1'                   => '#FF7255',   #
        'coral2'                   => '#ED6A4F',   #
        'coral3'                   => '#CD5A45',   #
        'coral4'                   => '#8A3E2E',   #
        'cornflowerblue'           => '#6394EC',   #
        'cornsilk'                 => '#FFF7DC',   #
        'cornsilk1'                => '#FFF7DC',   #
        'cornsilk2'                => '#EDE7CD',   #
        'cornsilk3'                => '#CDC7B1',   #
        'cornsilk4'                => '#8A8778',   #
        'crimson'                  => '#DC143C',   #
        'cyan'                     => '#00FFFF',   #
        'cyan1'                    => '#00FFFF',   #
        'cyan2'                    => '#00EDED',   #
        'cyan3'                    => '#00CDCD',   #
        'cyan4'                    => '#008A8A',   #
        'darkblue'                 => '#00008A',   #
        'darkcyan'                 => '#008A8A',   #
        'darkgoldenrod'            => '#B7850B',   #
        'darkgoldenrod1'           => '#FFB80E',   #
        'darkgoldenrod2'           => '#EDAD0D',   #
        'darkgoldenrod3'           => '#CD940C',   #
        'darkgoldenrod4'           => '#8A6507',   #
        'darkgray'                 => '#A9A9A9',   #
        'darkgreen'                => '#006300',   #
        'darkgrey'                 => '#A9A9A9',   #
        'darkkhaki'                => '#BCB66B',   #
        'darkmagenta'              => '#8A008A',   #
        'darkolivegreen'           => '#546B2E',   #
        'darkolivegreen1'          => '#CAFF70',   #
        'darkolivegreen2'          => '#BBED68',   #
        'darkolivegreen3'          => '#A2CD59',   #
        'darkolivegreen4'          => '#6E8A3D',   #
        'darkorange'               => '#FF8B00',   #
        'darkorange1'              => '#FF7F00',   #
        'darkorange2'              => '#ED7600',   #
        'darkorange3'              => '#CD6600',   #
        'darkorange4'              => '#8A4500',   #
        'darkorchid'               => '#9931CC',   #
        'darkorchid1'              => '#BE3EFF',   #
        'darkorchid2'              => '#B13AED',   #
        'darkorchid3'              => '#9A31CD',   #
        'darkorchid4'              => '#68218A',   #
        'darkred'                  => '#8A0000',   #
        'darksalmon'               => '#E8957A',   #
        'darkseagreen'             => '#8EBB8E',   #
        'darkseagreen1'            => '#C0FFC0',   #
        'darkseagreen2'            => '#B4EDB4',   #
        'darkseagreen3'            => '#9BCD9B',   #
        'darkseagreen4'            => '#698A69',   #
        'darkslateblue'            => '#483D8A',   #
        'darkslategray'            => '#2E4E4E',   #
        'darkslategray1'           => '#97FFFF',   #
        'darkslategray2'           => '#8CEDED',   #
        'darkslategray3'           => '#79CDCD',   #
        'darkslategray4'           => '#518A8A',   #
        'darkslategrey'            => '#2E4E4E',   #
        'darkturquoise'            => '#00CED1',   #
        'darkviolet'               => '#9300D3',   #
        'darkwood'                 => '#845D42',   #
        'deeppink'                 => '#FF1492',   #
        'deeppink1'                => '#FF1492',   #
        'deeppink2'                => '#ED1188',   #
        'deeppink3'                => '#CD1076',   #
        'deeppink4'                => '#8A0A4F',   #
        'deepskyblue'              => '#00BEFF',   #
        'deepskyblue1'             => '#00BEFF',   #
        'deepskyblue2'             => '#00B1ED',   #
        'deepskyblue3'             => '#009ACD',   #
        'deepskyblue4'             => '#00688A',   #
        'dimgray'                  => '#696969',   #
        'dimgrey'                  => '#696969',   #
        'dodgerblue'               => '#1D8FFF',   #
        'dodgerblue1'              => '#1D8FFF',   #
        'dodgerblue2'              => '#1B85ED',   #
        'dodgerblue3'              => '#1774CD',   #
        'dodgerblue4'              => '#104D8A',   #
        'dustyrose'                => '#846262',   #
        'feldspar'                 => '#D19175',   #
        'firebrick'                => '#B12121',   #
        'firebrick1'               => '#FF2F2F',   #
        'firebrick2'               => '#ED2B2B',   #
        'firebrick3'               => '#CD2525',   #
        'firebrick4'               => '#8A1919',   #
        'flesh'                    => '#F4CCB0',   #
        'floralwhite'              => '#FFF9EF',   #
        'forestgreen'              => '#218A21',   #
        'fuchsia'                  => '#FF00FF',   #
        'gainsboro'                => '#DCDCDC',   #
        'ghostwhite'               => '#F7F7FF',   #
        'gold'                     => '#FFD700',   #
        'gold1'                    => '#FFD700',   #
        'gold2'                    => '#EDC900',   #
        'gold3'                    => '#CDAD00',   #
        'gold4'                    => '#8A7500',   #
        'goldenrod'                => '#DAA51F',   #
        'goldenrod1'               => '#FFC024',   #
        'goldenrod2'               => '#EDB421',   #
        'goldenrod3'               => '#CD9B1C',   #
        'goldenrod4'               => '#8A6914',   #
        'gray'                     => '#7F7F7F',   #
        'gray0'                    => '#000000',   #
        'gray1'                    => '#020202',   #
        'gray10'                   => '#191919',   #
        'gray100'                  => '#FFFFFF',   #
        'gray11'                   => '#1B1B1B',   #
        'gray12'                   => '#1E1E1E',   #
        'gray13'                   => '#202020',   #
        'gray14'                   => '#232323',   #
        'gray15'                   => '#252525',   #
        'gray16'                   => '#282828',   #
        'gray17'                   => '#2A2A2A',   #
        'gray18'                   => '#2D2D2D',   #
        'gray19'                   => '#2F2F2F',   #
        'gray2'                    => '#050505',   #
        'gray20'                   => '#333333',   #
        'gray21'                   => '#363636',   #
        'gray22'                   => '#383838',   #
        'gray23'                   => '#3B3B3B',   #
        'gray24'                   => '#3D3D3D',   #
        'gray25'                   => '#404040',   #
        'gray26'                   => '#424242',   #
        'gray27'                   => '#454545',   #
        'gray28'                   => '#474747',   #
        'gray29'                   => '#4A4A4A',   #
        'gray3'                    => '#070707',   #
        'gray30'                   => '#4C4C4C',   #
        'gray31'                   => '#4E4E4E',   #
        'gray32'                   => '#515151',   #
        'gray33'                   => '#535353',   #
        'gray34'                   => '#565656',   #
        'gray35'                   => '#585858',   #
        'gray36'                   => '#5B5B5B',   #
        'gray37'                   => '#5D5D5D',   #
        'gray38'                   => '#606060',   #
        'gray39'                   => '#626262',   #
        'gray4'                    => '#0A0A0A',   #
        'gray40'                   => '#666666',   #
        'gray41'                   => '#696969',   #
        'gray42'                   => '#6B6B6B',   #
        'gray43'                   => '#6E6E6E',   #
        'gray44'                   => '#707070',   #
        'gray45'                   => '#737373',   #
        'gray46'                   => '#757575',   #
        'gray47'                   => '#787878',   #
        'gray48'                   => '#7A7A7A',   #
        'gray49'                   => '#7D7D7D',   #
        'gray5'                    => '#0C0C0C',   #
        'gray50'                   => '#7F7F7F',   #
        'gray51'                   => '#818181',   #
        'gray52'                   => '#848484',   #
        'gray53'                   => '#868686',   #
        'gray54'                   => '#898989',   #
        'gray55'                   => '#8B8B8B',   #
        'gray56'                   => '#8E8E8E',   #
        'gray57'                   => '#909090',   #
        'gray58'                   => '#939393',   #
        'gray59'                   => '#959595',   #
        'gray6'                    => '#0E0E0E',   #
        'gray60'                   => '#999999',   #
        'gray61'                   => '#9C9C9C',   #
        'gray62'                   => '#9E9E9E',   #
        'gray63'                   => '#A1A1A1',   #
        'gray64'                   => '#A3A3A3',   #
        'gray65'                   => '#A6A6A6',   #
        'gray66'                   => '#A8A8A8',   #
        'gray67'                   => '#ABABAB',   #
        'gray68'                   => '#ADADAD',   #
        'gray69'                   => '#B0B0B0',   #
        'gray7'                    => '#111111',   #
        'gray70'                   => '#B2B2B2',   #
        'gray71'                   => '#B4B4B4',   #
        'gray72'                   => '#B7B7B7',   #
        'gray73'                   => '#B9B9B9',   #
        'gray74'                   => '#BCBCBC',   #
        'gray75'                   => '#BEBEBE',   #
        'gray76'                   => '#C1C1C1',   #
        'gray77'                   => '#C3C3C3',   #
        'gray78'                   => '#C6C6C6',   #
        'gray79'                   => '#C9C9C9',   #
        'gray8'                    => '#141414',   #
        'gray80'                   => '#CCCCCC',   #
        'gray81'                   => '#CFCFCF',   #
        'gray82'                   => '#D1D1D1',   #
        'gray83'                   => '#D4D4D4',   #
        'gray84'                   => '#D6D6D6',   #
        'gray85'                   => '#D9D9D9',   #
        'gray86'                   => '#DBDBDB',   #
        'gray87'                   => '#DEDEDE',   #
        'gray88'                   => '#E0E0E0',   #
        'gray89'                   => '#E2E2E2',   #
        'gray9'                    => '#161616',   #
        'gray90'                   => '#E5E5E5',   #
        'gray91'                   => '#E7E7E7',   #
        'gray92'                   => '#EAEAEA',   #
        'gray93'                   => '#ECECEC',   #
        'gray94'                   => '#EFEFEF',   #
        'gray95'                   => '#F1F1F1',   #
        'gray96'                   => '#F4F4F4',   #
        'gray97'                   => '#F6F6F6',   #
        'gray98'                   => '#F9F9F9',   #
        'gray99'                   => '#FBFBFB',   #
        'green'                    => '#007F00',   #
        'green1'                   => '#00FF00',   #
        'green2'                   => '#00ED00',   #
        'green3'                   => '#00CD00',   #
        'green4'                   => '#008A00',   #
        'greencopper'              => '#846262',   #
        'greenyellow'              => '#D19175',   #
        'grey'                     => '#BDBDBD',   #
        'grey0'                    => '#000000',   #
        'grey1'                    => '#020202',   #
        'grey10'                   => '#191919',   #
        'grey100'                  => '#FFFFFF',   #
        'grey11'                   => '#1B1B1B',   #
        'grey12'                   => '#1E1E1E',   #
        'grey13'                   => '#202020',   #
        'grey14'                   => '#232323',   #
        'grey15'                   => '#252525',   #
        'grey16'                   => '#282828',   #
        'grey17'                   => '#2A2A2A',   #
        'grey18'                   => '#2D2D2D',   #
        'grey19'                   => '#2F2F2F',   #
        'grey2'                    => '#050505',   #
        'grey20'                   => '#333333',   #
        'grey21'                   => '#363636',   #
        'grey22'                   => '#383838',   #
        'grey23'                   => '#3B3B3B',   #
        'grey24'                   => '#3D3D3D',   #
        'grey25'                   => '#404040',   #
        'grey26'                   => '#424242',   #
        'grey27'                   => '#454545',   #
        'grey28'                   => '#474747',   #
        'grey29'                   => '#4A4A4A',   #
        'grey3'                    => '#070707',   #
        'grey30'                   => '#4C4C4C',   #
        'grey31'                   => '#4E4E4E',   #
        'grey32'                   => '#515151',   #
        'grey33'                   => '#535353',   #
        'grey34'                   => '#565656',   #
        'grey35'                   => '#585858',   #
        'grey36'                   => '#5B5B5B',   #
        'grey37'                   => '#5D5D5D',   #
        'grey38'                   => '#606060',   #
        'grey39'                   => '#626262',   #
        'grey4'                    => '#0A0A0A',   #
        'grey40'                   => '#666666',   #
        'grey41'                   => '#696969',   #
        'grey42'                   => '#6B6B6B',   #
        'grey43'                   => '#6E6E6E',   #
        'grey44'                   => '#707070',   #
        'grey45'                   => '#737373',   #
        'grey46'                   => '#757575',   #
        'grey47'                   => '#787878',   #
        'grey48'                   => '#7A7A7A',   #
        'grey49'                   => '#7D7D7D',   #
        'grey5'                    => '#0C0C0C',   #
        'grey50'                   => '#7F7F7F',   #
        'grey51'                   => '#818181',   #
        'grey52'                   => '#848484',   #
        'grey53'                   => '#868686',   #
        'grey54'                   => '#898989',   #
        'grey55'                   => '#8B8B8B',   #
        'grey56'                   => '#8E8E8E',   #
        'grey57'                   => '#909090',   #
        'grey58'                   => '#939393',   #
        'grey59'                   => '#959595',   #
        'grey6'                    => '#0E0E0E',   #
        'grey60'                   => '#999999',   #
        'grey61'                   => '#9C9C9C',   #
        'grey62'                   => '#9E9E9E',   #
        'grey63'                   => '#A1A1A1',   #
        'grey64'                   => '#A3A3A3',   #
        'grey65'                   => '#A6A6A6',   #
        'grey66'                   => '#A8A8A8',   #
        'grey67'                   => '#ABABAB',   #
        'grey68'                   => '#ADADAD',   #
        'grey69'                   => '#B0B0B0',   #
        'grey7'                    => '#111111',   #
        'grey70'                   => '#B2B2B2',   #
        'grey71'                   => '#B4B4B4',   #
        'grey72'                   => '#B7B7B7',   #
        'grey73'                   => '#B9B9B9',   #
        'grey74'                   => '#BCBCBC',   #
        'grey75'                   => '#BEBEBE',   #
        'grey76'                   => '#C1C1C1',   #
        'grey77'                   => '#C3C3C3',   #
        'grey78'                   => '#C6C6C6',   #
        'grey79'                   => '#C9C9C9',   #
        'grey8'                    => '#141414',   #
        'grey80'                   => '#CCCCCC',   #
        'grey81'                   => '#CFCFCF',   #
        'grey82'                   => '#D1D1D1',   #
        'grey83'                   => '#D4D4D4',   #
        'grey84'                   => '#D6D6D6',   #
        'grey85'                   => '#D9D9D9',   #
        'grey86'                   => '#DBDBDB',   #
        'grey87'                   => '#DEDEDE',   #
        'grey88'                   => '#E0E0E0',   #
        'grey89'                   => '#E2E2E2',   #
        'grey9'                    => '#161616',   #
        'grey90'                   => '#E5E5E5',   #
        'grey91'                   => '#E7E7E7',   #
        'grey92'                   => '#EAEAEA',   #
        'grey93'                   => '#ECECEC',   #
        'grey94'                   => '#EFEFEF',   #
        'grey95'                   => '#F1F1F1',   #
        'grey96'                   => '#F4F4F4',   #
        'grey97'                   => '#F6F6F6',   #
        'grey98'                   => '#F9F9F9',   #
        'grey99'                   => '#FBFBFB',   #
        'honeydew'                 => '#EFFFEF',   #
        'honeydew1'                => '#EFFFEF',   #
        'honeydew2'                => '#E0EDE0',   #
        'honeydew3'                => '#C0CDC0',   #
        'honeydew4'                => '#828A82',   #
        'hotpink'                  => '#FF69B4',   #
        'hotpink1'                 => '#FF6EB4',   #
        'hotpink2'                 => '#ED6AA7',   #
        'hotpink3'                 => '#CD5F8F',   #
        'hotpink4'                 => '#8A3A61',   #
        'indianred'                => '#F4CCB0',   #
        'indianred1'               => '#FF6A6A',   #
        'indianred2'               => '#ED6262',   #
        'indianred3'               => '#CD5454',   #
        'indianred4'               => '#8A3A3A',   #
        'indigo'                   => '#4B0081',   #
        'ivory'                    => '#FFFFEF',   #
        'ivory1'                   => '#FFFFEF',   #
        'ivory2'                   => '#EDEDE0',   #
        'ivory3'                   => '#CDCDC0',   #
        'ivory4'                   => '#8A8A82',   #
        'khaki'                    => '#EFE68B',   #
        'khaki1'                   => '#FFF58E',   #
        'khaki2'                   => '#EDE684',   #
        'khaki3'                   => '#CDC573',   #
        'khaki4'                   => '#8A854D',   #
        'lavender'                 => '#E6E6F9',   #
        'lavenderblush'            => '#FFEFF4',   #
        'lavenderblush1'           => '#FFEFF4',   #
        'lavenderblush2'           => '#EDE0E5',   #
        'lavenderblush3'           => '#CDC0C4',   #
        'lavenderblush4'           => '#8A8285',   #
        'lawngreen'                => '#7CFB00',   #
        'lemonchiffon'             => '#FFF9CD',   #
        'lemonchiffon1'            => '#FFF9CD',   #
        'lemonchiffon2'            => '#EDE8BE',   #
        'lemonchiffon3'            => '#CDC9A5',   #
        'lemonchiffon4'            => '#8A8870',   #
        'lightblue'                => '#ADD8E6',   #
        'lightblue1'               => '#BEEEFF',   #
        'lightblue2'               => '#B1DFED',   #
        'lightblue3'               => '#9ABFCD',   #
        'lightblue4'               => '#68828A',   #
        'lightcoral'               => '#EF7F7F',   #
        'lightcyan'                => '#E0FFFF',   #
        'lightcyan1'               => '#E0FFFF',   #
        'lightcyan2'               => '#D1EDED',   #
        'lightcyan3'               => '#B4CDCD',   #
        'lightcyan4'               => '#7A8A8A',   #
        'lightgoldenrod'           => '#EDDD81',   #
        'lightgoldenrod1'          => '#FFEB8A',   #
        'lightgoldenrod2'          => '#EDDC81',   #
        'lightgoldenrod3'          => '#CDBD70',   #
        'lightgoldenrod4'          => '#8A804C',   #
        'lightgoldenrodyellow'     => '#F9F9D2',   #
        'lightgray'                => '#D3D3D3',   #
        'lightgreen'               => '#8FED8F',   #
        'lightgrey'                => '#D3D3D3',   #
        'lightpink'                => '#FFB5C0',   #
        'lightpink1'               => '#FFAEB8',   #
        'lightpink2'               => '#EDA2AD',   #
        'lightpink3'               => '#CD8B94',   #
        'lightpink4'               => '#8A5E65',   #
        'lightsalmon'              => '#FFA07A',   #
        'lightsalmon1'             => '#FFA07A',   #
        'lightsalmon2'             => '#ED9472',   #
        'lightsalmon3'             => '#CD8061',   #
        'lightsalmon4'             => '#8A5642',   #
        'lightseagreen'            => '#1FB1AA',   #
        'lightskyblue'             => '#86CEF9',   #
        'lightskyblue1'            => '#B0E2FF',   #
        'lightskyblue2'            => '#A4D3ED',   #
        'lightskyblue3'            => '#8CB5CD',   #
        'lightskyblue4'            => '#5F7B8A',   #
        'lightslateblue'           => '#8370FF',   #
        'lightslategray'           => '#778799',   #
        'lightslategrey'           => '#778799',   #
        'lightsteelblue'           => '#B0C3DE',   #
        'lightsteelblue1'          => '#CAE1FF',   #
        'lightsteelblue2'          => '#BBD2ED',   #
        'lightsteelblue3'          => '#A2B4CD',   #
        'lightsteelblue4'          => '#6E7B8A',   #
        'lightyellow'              => '#FFFFE0',   #
        'lightyellow1'             => '#FFFFE0',   #
        'lightyellow2'             => '#EDEDD1',   #
        'lightyellow3'             => '#CDCDB4',   #
        'lightyellow4'             => '#8A8A7A',   #
        'lime'                     => '#00FF00',   #
        'limegreen'                => '#31CD31',   #
        'linen'                    => '#F9EFE6',   #
        'magenta'                  => '#FF00FF',   #
        'magenta1'                 => '#FF00FF',   #
        'magenta2'                 => '#ED00ED',   #
        'magenta3'                 => '#CD00CD',   #
        'magenta4'                 => '#8A008A',   #
        'mandarianorange'          => '#8D2222',   #
        'maroon'                   => '#7F0000',   #
        'maroon1'                  => '#FF34B2',   #
        'maroon2'                  => '#ED2FA7',   #
        'maroon3'                  => '#CD288F',   #
        'maroon4'                  => '#8A1B61',   #
        'mediumaquamarine'         => '#66CDAA',   #
        'mediumblue'               => '#0000CD',   #
        'mediumorchid'             => '#B954D3',   #
        'mediumorchid1'            => '#E066FF',   #
        'mediumorchid2'            => '#D15EED',   #
        'mediumorchid3'            => '#B451CD',   #
        'mediumorchid4'            => '#7A378A',   #
        'mediumpurple'             => '#9270DB',   #
        'mediumpurple1'            => '#AB81FF',   #
        'mediumpurple2'            => '#9F79ED',   #
        'mediumpurple3'            => '#8868CD',   #
        'mediumpurple4'            => '#5C478A',   #
        'mediumseagreen'           => '#3CB271',   #
        'mediumslateblue'          => '#7B68ED',   #
        'mediumspringgreen'        => '#00F99A',   #
        'mediumturquoise'          => '#48D1CC',   #
        'mediumvioletred'          => '#C61584',   #
        'midnightblue'             => '#2E2E4E',   #
        'mintcream'                => '#F4FFF9',   #
        'mistyrose'                => '#FFE4E1',   #
        'mistyrose1'               => '#FFE4E1',   #
        'mistyrose2'               => '#EDD5D2',   #
        'mistyrose3'               => '#CDB6B4',   #
        'mistyrose4'               => '#8A7D7B',   #
        'moccasin'                 => '#FFE4B4',   #
        'navajowhite'              => '#FFDEAD',   #
        'navajowhite1'             => '#FFDEAD',   #
        'navajowhite2'             => '#EDCFA1',   #
        'navajowhite3'             => '#CDB28A',   #
        'navajowhite4'             => '#8A795D',   #
        'navy'                     => '#00007F',   #
        'navyblue'                 => '#00007F',   #
        'neonblue'                 => '#4C4CFF',   #
        'neonpink'                 => '#FF6EC6',   #
        'none'                     => '#000000',   #
        'oldlace'                  => '#FCF4E6',   #
        'olive'                    => '#7F7F00',   #
        'olivedrab'                => '#6B8D22',   #
        'olivedrab1'               => '#BFFF3E',   #
        'olivedrab2'               => '#B2ED3A',   #
        'olivedrab3'               => '#9ACD31',   #
        'olivedrab4'               => '#698A21',   #
        'orange'                   => '#FFA500',   #
        'orange1'                  => '#FFA500',   #
        'orange2'                  => '#ED9A00',   #
        'orange3'                  => '#CD8400',   #
        'orange4'                  => '#8A5900',   #
        'orangered'                => '#FF4500',   #
        'orangered1'               => '#FF4500',   #
        'orangered2'               => '#ED4000',   #
        'orangered3'               => '#CD3700',   #
        'orangered4'               => '#8A2400',   #
        'orchid'                   => '#DA70D6',   #
        'orchid1'                  => '#FF82F9',   #
        'orchid2'                  => '#ED7AE8',   #
        'orchid3'                  => '#CD69C9',   #
        'orchid4'                  => '#8A4788',   #
        'palegoldenrod'            => '#EDE7AA',   #
        'palegreen'                => '#98FB98',   #
        'palegreen1'               => '#9AFF9A',   #
        'palegreen2'               => '#8FED8F',   #
        'palegreen3'               => '#7CCD7C',   #
        'palegreen4'               => '#538A53',   #
        'paleturquoise'            => '#AFEDED',   #
        'paleturquoise1'           => '#BAFFFF',   #
        'paleturquoise2'           => '#AEEDED',   #
        'paleturquoise3'           => '#95CDCD',   #
        'paleturquoise4'           => '#668A8A',   #
        'palevioletred'            => '#DB7092',   #
        'palevioletred1'           => '#FF81AB',   #
        'palevioletred2'           => '#ED799F',   #
        'palevioletred3'           => '#CD6888',   #
        'palevioletred4'           => '#8A475C',   #
        'papayawhip'               => '#FFEED5',   #
        'peachpuff'                => '#FFDAB8',   #
        'peachpuff1'               => '#FFDAB8',   #
        'peachpuff2'               => '#EDCBAD',   #
        'peachpuff3'               => '#CDAF94',   #
        'peachpuff4'               => '#8A7765',   #
        'peru'                     => '#CD843F',   #
        'pink'                     => '#FFBFCB',   #
        'pink1'                    => '#FFB4C4',   #
        'pink2'                    => '#EDA9B7',   #
        'pink3'                    => '#CD909E',   #
        'pink4'                    => '#8A626C',   #
        'plum'                     => '#DDA0DD',   #
        'plum1'                    => '#FFBAFF',   #
        'plum2'                    => '#EDAEED',   #
        'plum3'                    => '#CD95CD',   #
        'plum4'                    => '#8A668A',   #
        'powderblue'               => '#B0E0E6',   #
        'purple'                   => '#7F007F',   #
        'purple1'                  => '#9B2FFF',   #
        'purple2'                  => '#902BED',   #
        'purple3'                  => '#7D25CD',   #
        'purple4'                  => '#54198A',   #
        'quartz'                   => '#D9D9F2',   #
        'red'                      => '#FF0000',   #
        'red1'                     => '#FF0000',   #
        'red2'                     => '#ED0000',   #
        'red3'                     => '#CD0000',   #
        'red4'                     => '#8A0000',   #
        'richblue'                 => '#5858AB',   #
        'rosybrown'                => '#BB8E8E',   #
        'rosybrown1'               => '#FFC0C0',   #
        'rosybrown2'               => '#EDB4B4',   #
        'rosybrown3'               => '#CD9B9B',   #
        'rosybrown4'               => '#8A6969',   #
        'royalblue'                => '#4169E1',   #
        'royalblue1'               => '#4876FF',   #
        'royalblue2'               => '#436EED',   #
        'royalblue3'               => '#3A5ECD',   #
        'royalblue4'               => '#26408A',   #
        'saddlebrown'              => '#8A4512',   #
        'salmon'                   => '#F97F72',   #
        'salmon1'                  => '#FF8B69',   #
        'salmon2'                  => '#ED8161',   #
        'salmon3'                  => '#CD7053',   #
        'salmon4'                  => '#8A4C39',   #
        'sandybrown'               => '#F3A45F',   #
        'seagreen'                 => '#2D8A56',   #
        'seagreen1'                => '#53FF9F',   #
        'seagreen2'                => '#4DED93',   #
        'seagreen3'                => '#43CD7F',   #
        'seagreen4'                => '#2D8A56',   #
        'seashell'                 => '#FFF4ED',   #
        'seashell1'                => '#FFF4ED',   #
        'seashell2'                => '#EDE5DE',   #
        'seashell3'                => '#CDC4BE',   #
        'seashell4'                => '#8A8581',   #
        'sienna'                   => '#A0512C',   #
        'sienna1'                  => '#FF8147',   #
        'sienna2'                  => '#ED7942',   #
        'sienna3'                  => '#CD6839',   #
        'sienna4'                  => '#8A4725',   #
        'silver'                   => '#BFBFBF',   #
        'skyblue'                  => '#86CEEA',   #
        'skyblue1'                 => '#86CEFF',   #
        'skyblue2'                 => '#7EBFED',   #
        'skyblue3'                 => '#6CA6CD',   #
        'skyblue4'                 => '#4A708A',   #
        'slateblue'                => '#6A59CD',   #
        'slateblue1'               => '#826FFF',   #
        'slateblue2'               => '#7A67ED',   #
        'slateblue3'               => '#6958CD',   #
        'slateblue4'               => '#473C8A',   #
        'slategray'                => '#707F8F',   #
        'slategray1'               => '#C5E2FF',   #
        'slategray2'               => '#B8D3ED',   #
        'slategray3'               => '#9FB5CD',   #
        'slategray4'               => '#6C7B8A',   #
        'slategrey'                => '#707F8F',   #
        'snow'                     => '#FFF9F9',   #
        'snow1'                    => '#FFF9F9',   #
        'snow2'                    => '#EDE8E8',   #
        'snow3'                    => '#CDC9C9',   #
        'snow4'                    => '#8A8888',   #
        'springgreen'              => '#00FF7F',   #
        'springgreen1'             => '#00FF7F',   #
        'springgreen2'             => '#00ED76',   #
        'springgreen3'             => '#00CD66',   #
        'springgreen4'             => '#008A45',   #
        'steelblue'                => '#4681B4',   #
        'steelblue1'               => '#62B7FF',   #
        'steelblue2'               => '#5BACED',   #
        'steelblue3'               => '#4E93CD',   #
        'steelblue4'               => '#36638A',   #
        'summersky'                => '#38B0DE',   #
        'tan'                      => '#D2B48B',   #
        'tan1'                     => '#FFA54E',   #
        'tan2'                     => '#ED9A49',   #
        'tan3'                     => '#CD843F',   #
        'tan4'                     => '#8A592A',   #
        'teal'                     => '#007F7F',   #
        'thistle'                  => '#D8BED8',   #
        'thistle1'                 => '#FFE1FF',   #
        'thistle2'                 => '#EDD2ED',   #
        'thistle3'                 => '#CDB4CD',   #
        'thistle4'                 => '#8A7B8A',   #
        'tomato'                   => '#FF6247',   #
        'tomato1'                  => '#FF6247',   #
        'tomato2'                  => '#ED5B42',   #
        'tomato3'                  => '#CD4E39',   #
        'tomato4'                  => '#8A3625',   #
        'turquoise'                => '#40E0D0',   #
        'turquoise1'               => '#00F4FF',   #
        'turquoise2'               => '#00E5ED',   #
        'turquoise3'               => '#00C4CD',   #
        'turquoise4'               => '#00858A',   #
        'violet'                   => '#ED81ED',   #
        'violetred'                => '#D01F8F',   #
        'violetred1'               => '#FF3E95',   #
        'violetred2'               => '#ED3A8B',   #
        'violetred3'               => '#CD3178',   #
        'violetred4'               => '#8A2151',   #
        'wheat'                    => '#F4DEB2',   #
        'wheat1'                   => '#FFE6B9',   #
        'wheat2'                   => '#EDD8AE',   #
        'wheat3'                   => '#CDB995',   #
        'wheat4'                   => '#8A7E66',   #
        'white'                    => '#FFFFFF',   #
        'whitesmoke'               => '#F4F4F4',   #
        'yellow'                   => '#FFFF00',   #
        'yellow1'                  => '#FFFF00',   #
        'yellow2'                  => '#EDED00',   #
        'yellow3'                  => '#CDCD00',   #
        'yellow4'                  => '#8A8A00',   #
        'yellowgreen'              => '#99CC31',   #
    );
}

sub pdfkey {
    return($PDF::API2::Util::key_var++);
}

sub pdfkey2 {
  if(scalar @_>0 && defined($_[0])) {
    my $ddata=join('',@_);
    my $mdkey='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789gT';
    my $xdata="0" x 8;
    my $off=0;
    foreach my $set (0..(length($ddata)<<1)) {
        $off+=vec($ddata,$set,4);
        $off+=vec($xdata,($set & 7),8);
        vec($xdata,($set & 7),8)=vec($mdkey,($off & 0x3f),8);
    }
    return($xdata);
  } else {
    return($PDF::API2::Util::key_var++);
  }
}

sub digestx {
    my $len=shift @_;
    my $mask=$len-1;
    my $ddata=join('',@_);
    my $mdkey='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789gT';
    my $xdata="0" x $len;
    my $off=0;
    my $set;
    foreach $set (0..(length($ddata)<<1)) {
        $off+=vec($ddata,$set,4);
        $off+=vec($xdata,($set & $mask),8);
        vec($xdata,($set & ($mask<<1 |1)),4)=vec($mdkey,($off & 0x7f),4);
    }

#   foreach $set (0..$mask) {
#       vec($xdata,$set,8)=(vec($xdata,$set,8) & 0x7f) | 0x40;
#   }

#   $off=0;
#   foreach $set (0..$mask) {
#       $off+=vec($xdata,$set,8);
#       vec($xdata,$set,8)=vec($mdkey,($off & 0x3f),8);
#   }

    return($xdata);
}

sub digest {
    return(digestx(32,@_));
}

sub digest16 {
    return(digestx(16,@_));
}

sub digest32 {
    return(digestx(32,@_));
}

sub xlog10 {
    my $n = shift;
    if($n) {
            return log(abs($n))/log(10);
    } else { return 0; }
}

sub float {
    my $f=shift @_;
    my $mxd=shift @_||4;
    $f=0 if(abs($f)<0.0000000000000001);
    my $ad=floor(xlog10($f)-$mxd);
    if(abs($f-int($f)) < (10**(-$mxd))) {
        # just in case we have an integer
        return sprintf('%i',$f);
    } elsif($ad>0){
        return sprintf('%f',$f);
    } else {
        return sprintf('%.'.abs($ad).'f',$f);
    }
}
sub floats { return map { float($_); } @_; }
sub floats5 { return map { float($_,5); } @_; }


sub intg {
    my $f=shift @_;
    return sprintf('%i',$f);
}
sub intgs { return map { intg($_); } @_; }

sub mMin {
    my $n=HUGE_VAL;
    map { $n=($n>$_) ? $_ : $n } @_;
    return($n);
}

sub mMax {
    my $n=-(HUGE_VAL);
    map { $n=($n<$_) ? $_ : $n } @_;
    return($n);
}

sub cRGB {
    my @cmy=(map { 1-$_ } @_);
    my $k=mMin(@cmy);
    return((map { $_-$k } @cmy),$k);
}

sub cRGB8 {
    return cRGB(map { $_/255 } @_);
}

sub RGBtoLUM {
    my ($r,$g,$b)=@_;
    return($r*0.299+$g*0.587+$b*0.114);
}

sub RGBasCMYK {
    my @rgb=@_;
    my @cmy=(map { 1-$_ } @rgb);
    my $k=mMin(@cmy)*0.44;
    return((map { $_-$k } @cmy),$k);
}

sub HSVtoRGB {
    my ($h,$s,$v)=@_;
    my ($r,$g,$b,$i,$f,$p,$q,$t);

    if( $s == 0 ) {
        ## achromatic (grey)
        return ($v,$v,$v);
    }

    $h %= 360;
    $h /= 60;       ## sector 0 to 5
    $i = POSIX::floor( $h );
    $f = $h - $i;   ## factorial part of h
    $p = $v * ( 1 - $s );
    $q = $v * ( 1 - $s * $f );
    $t = $v * ( 1 - $s * ( 1 - $f ) );

    if($i<1) {
        $r = $v;
        $g = $t;
        $b = $p;
    } elsif($i<2){
        $r = $q;
        $g = $v;
        $b = $p;
    } elsif($i<3){
        $r = $p;
        $g = $v;
        $b = $t;
    } elsif($i<4){
        $r = $p;
        $g = $q;
        $b = $v;
    } elsif($i<5){
        $r = $t;
        $g = $p;
        $b = $v;
    } else {
        $r = $v;
        $g = $p;
        $b = $q;
    }
    return ($r,$g,$b);
}
sub _HSVtoRGB { # test
    my ($h,$s,$v)=@_;
    my ($r,$g,$b,$i,$f,$p,$q,$t);

    if( $s == 0 ) {
        ## achromatic (grey)
        return ($v,$v,$v);
    }
    
    $h %= 360;
    
    $r = 2*cos(deg2rad($h));
    $g = 2*cos(deg2rad($h+120));
    $b = 2*cos(deg2rad($h+240));

    $p = max($r,$g,$b);
    $q = min($r,$g,$b);
    ($p,$q) = map { ($_<0 ? 0 : ($_>1 ? 1 : $_)) } ($p,$q);
    $f = $p - $q;
    
    #if($p>=$v) {
    #    ($r,$g,$b) = map { $_*$v/$p } ($r,$g,$b);
    #} else {
    #    ($r,$g,$b) = map { $_*$p/$v } ($r,$g,$b);
    #}
    #
    #if($f>=$s) {
    #    ($r,$g,$b) = map { (($_-$q/2)*$f/$s)+$q/2 } ($r,$g,$b);
    #} else {
    #    ($r,$g,$b) = map { (($_-$q/2)*$s/$f)+$q/2 } ($r,$g,$b);
    #}

    ($r,$g,$b) = map { ($_<0 ? 0 : ($_>1 ? 1 : $_)) } ($r,$g,$b);

    return ($r,$g,$b);
}

sub RGBquant ($$$) {
    my($q1,$q2,$h)=@_;
    while($h<0){$h+=360;}
    $h%=360;
    if ($h<60) {
        return($q1+(($q2-$q1)*$h/60));
    } elsif ($h<180) {
        return($q2);
    } elsif ($h<240) {
        return($q1+(($q2-$q1)*(240-$h)/60));
    } else {
        return($q1);
    }
}

sub RGBtoHSV {
    my ($r,$g,$b)=@_;
    my ($h,$s,$v,$min,$max,$delta);

    $min= mMin($r,$g,$b);
    $max= mMax($r,$g,$b);

    $v = $max;

    $delta = $max - $min;

    if( $delta > 0.000000001 ) {
        $s = $delta / $max;
    } else {
        $s = 0;
        $h = 0;
        return($h,$s,$v);
    }

    if( $r == $max ) {
        $h = ( $g - $b ) / $delta;
    } elsif( $g == $max ) {
        $h = 2 + ( $b - $r ) / $delta;
    } else {
        $h = 4 + ( $r - $g ) / $delta;
    }
    $h *= 60;
    if( $h < 0 ) {$h += 360;}
    return($h,$s,$v);
}

sub RGBtoHSL {
    my ($r,$g,$b)=@_;
    my ($h,$s,$v,$l,$min,$max,$delta);

    $min= mMin($r,$g,$b);
    $max= mMax($r,$g,$b);
    ($h,$s,$v)=RGBtoHSV($r,$g,$b);
    $l=($max+$min)/2.0;
        $delta = $max - $min;
    if($delta<0.00000000001){
        return(0,0,$l);
    } else {
        if($l<=0.5){
            $s=$delta/($max+$min);
        } else {
            $s=$delta/(2-$max-$min);
        }
    }
    return($h,$s,$l);
}

sub HSLtoRGB {
    my($h,$s,$l,$r,$g,$b,$p1,$p2)=@_;
    if($l<=0.5){
        $p2=$l*(1+$s);
    } else {
        $p2=$l+$s-($l*$s);
    }
    $p1=2*$l-$p2;
    if($s<0.0000000000001){
        $r=$l; $g=$l; $b=$l;
    } else {
        $r=RGBquant($p1,$p2,$h+120);
        $g=RGBquant($p1,$p2,$h);
        $b=RGBquant($p1,$p2,$h-120);
    }
    return($r,$g,$b);
}

sub optInvColor {
    my ($r,$g,$b) = @_;

    my $ab = (0.2*$r) + (0.7*$g) + (0.1*$b);

    if($ab > 0.45) {
        return(0,0,0);
    } else {
        return(1,1,1);
    }
}

sub defineColor {
    my ($name,$mx,$r,$g,$b)=@_;
    $colors{$name}||=[ map {$_/$mx} ($r,$g,$b) ];
    return($colors{$name});
}

sub rgbHexValues {
    my $name=lc(shift @_);
    my ($r,$g,$b);
    if(length($name)<5) {       # zb. #fa4,          #cf0
        $r=hex(substr($name,1,1))/0xf;
        $g=hex(substr($name,2,1))/0xf;
        $b=hex(substr($name,3,1))/0xf;
    } elsif(length($name)<8) {  # zb. #ffaa44,       #ccff00
        $r=hex(substr($name,1,2))/0xff;
        $g=hex(substr($name,3,2))/0xff;
        $b=hex(substr($name,5,2))/0xff;
    } elsif(length($name)<11) { # zb. #fffaaa444,    #cccfff000
        $r=hex(substr($name,1,3))/0xfff;
        $g=hex(substr($name,4,3))/0xfff;
        $b=hex(substr($name,7,3))/0xfff;
    } else {            # zb. #ffffaaaa4444, #ccccffff0000
        $r=hex(substr($name,1,4))/0xffff;
        $g=hex(substr($name,5,4))/0xffff;
        $b=hex(substr($name,9,4))/0xffff;
    }
    return($r,$g,$b);
}
sub cmykHexValues {
    my $name=lc(shift @_);
    my ($c,$m,$y,$k);
    if(length($name)<6) {       # zb. %cmyk
        $c=hex(substr($name,1,1))/0xf;
        $m=hex(substr($name,2,1))/0xf;
        $y=hex(substr($name,3,1))/0xf;
        $k=hex(substr($name,4,1))/0xf;
    } elsif(length($name)<10) { # zb. %ccmmyykk
        $c=hex(substr($name,1,2))/0xff;
        $m=hex(substr($name,3,2))/0xff;
        $y=hex(substr($name,5,2))/0xff;
        $k=hex(substr($name,7,2))/0xff;
    } elsif(length($name)<14) { # zb. %cccmmmyyykkk
        $c=hex(substr($name,1,3))/0xfff;
        $m=hex(substr($name,4,3))/0xfff;
        $y=hex(substr($name,7,3))/0xfff;
        $k=hex(substr($name,10,3))/0xfff;
    } else {            # zb. %ccccmmmmyyyykkkk
        $c=hex(substr($name,1,4))/0xffff;
        $m=hex(substr($name,5,4))/0xffff;
        $y=hex(substr($name,9,4))/0xffff;
        $k=hex(substr($name,13,4))/0xffff;
    }
    return($c,$m,$y,$k);
}
sub hsvHexValues {
    my $name=lc(shift @_);
    my ($h,$s,$v);
    if(length($name)<5) {
        $h=360*hex(substr($name,1,1))/0x10;
        $s=hex(substr($name,2,1))/0xf;
        $v=hex(substr($name,3,1))/0xf;
    } elsif(length($name)<8) {
        $h=360*hex(substr($name,1,2))/0x100;
        $s=hex(substr($name,3,2))/0xff;
        $v=hex(substr($name,5,2))/0xff;
    } elsif(length($name)<11) {
        $h=360*hex(substr($name,1,3))/0x1000;
        $s=hex(substr($name,4,3))/0xfff;
        $v=hex(substr($name,7,3))/0xfff;
    } else {
        $h=360*hex(substr($name,1,4))/0x10000;
        $s=hex(substr($name,5,4))/0xffff;
        $v=hex(substr($name,9,4))/0xffff;
    }
    return($h,$s,$v);
}
sub labHexValues {
    my $name=lc(shift @_);
    my ($l,$a,$b);
    if(length($name)<5) {
        $l=100*hex(substr($name,1,1))/0xf;
        $a=(200*hex(substr($name,2,1))/0xf)-100;
        $b=(200*hex(substr($name,3,1))/0xf)-100;
    } elsif(length($name)<8) {
        $l=100*hex(substr($name,1,2))/0xff;
        $a=(200*hex(substr($name,3,2))/0xff)-100;
        $b=(200*hex(substr($name,5,2))/0xff)-100;
    } elsif(length($name)<11) {
        $l=100*hex(substr($name,1,3))/0xfff;
        $a=(200*hex(substr($name,4,3))/0xfff)-100;
        $b=(200*hex(substr($name,7,3))/0xfff)-100;
    } else {
        $l=100*hex(substr($name,1,4))/0xffff;
        $a=(200*hex(substr($name,5,4))/0xffff)-100;
        $b=(200*hex(substr($name,9,4))/0xffff)-100;
    }
    return($l,$a,$b);
}

sub namecolor {
    my $name=shift @_;
    unless(ref $name) {
        $name=lc($name);
        $name=~s/[^\#!%\&\$a-z0-9]//go;
    }
    if($name=~/^[a-z]/) { # name spec.
        return(namecolor($colors{$name}));
    } elsif($name=~/^#/) { # rgb spec.
        return(floats5(rgbHexValues($name)));
    } elsif($name=~/^%/) { # cmyk spec.
        return(floats5(cmykHexValues($name)));
    } elsif($name=~/^!/) { # hsv spec.
        return(floats5(HSVtoRGB(hsvHexValues($name))));
    } elsif($name=~/^&/) { # hsl spec.
        return(floats5(HSLtoRGB(hsvHexValues($name))));
    } else { # or it is a ref ?
        return(floats5(@{$name || [0.5,0.5,0.5]}));
    }
}
sub namecolor_cmyk {
    my $name=shift @_;
    unless(ref $name) {
        $name=lc($name);
        $name=~s/[^\#!%\&\$a-z0-9]//go;
    }
    if($name=~/^[a-z]/) { # name spec.
        return(namecolor_cmyk($colors{$name}));
    } elsif($name=~/^#/) { # rgb spec.
        return(floats5(RGBasCMYK(rgbHexValues($name))));
    } elsif($name=~/^%/) { # cmyk spec.
        return(floats5(cmykHexValues($name)));
    } elsif($name=~/^!/) { # hsv spec.
        return(floats5(RGBasCMYK(HSVtoRGB(hsvHexValues($name)))));
    } elsif($name=~/^&/) { # hsl spec.
        return(floats5(RGBasCMYK(HSLtoRGB(hsvHexValues($name)))));
    } else { # or it is a ref ?
        return(floats5(RGBasCMYK(@{$name || [0.5,0.5,0.5]})));
    }
}
sub namecolor_lab {
    my $name=shift @_;
    unless(ref $name) {
        $name=lc($name);
        $name=~s/[^\#!%\&\$a-z0-9]//go;
    }
    if($name=~/^[a-z]/) { # name spec.
        return(namecolor_lab($colors{$name}));
    } elsif($name=~/^\$/) { # lab spec.
        return(floats5(labHexValues($name)));
    } elsif($name=~/^#/) { # rgb spec.
        my ($h,$s,$v)=RGBtoHSV(rgbHexValues($name));
        my $a=cos(deg2rad $h)*$s*100;
        my $b=sin(deg2rad $h)*$s*100;
        my $l=100*$v;
        return(floats5($l,$a,$b));
    } elsif($name=~/^!/) { # hsv spec.
        # fake conversion
        my ($h,$s,$v)=hsvHexValues($name);
        my $a=cos(deg2rad $h)*$s*100;
        my $b=sin(deg2rad $h)*$s*100;
        my $l=100*$v;
        return(floats5($l,$a,$b));
    } elsif($name=~/^&/) { # hsl spec.
        my ($h,$s,$v)=hsvHexValues($name);
        my $a=cos(deg2rad $h)*$s*100;
        my $b=sin(deg2rad $h)*$s*100;
        ($h,$s,$v)=RGBtoHSV(HSLtoRGB($h,$s,$v));
        my $l=100*$v;
        return(floats5($l,$a,$b));
    } else { # or it is a ref ?
        my ($h,$s,$v)=RGBtoHSV(@{$name || [0.5,0.5,0.5]});
        my $a=cos(deg2rad $h)*$s*100;
        my $b=sin(deg2rad $h)*$s*100;
        my $l=100*$v;
        return(floats5($l,$a,$b));
    }
}

sub unfilter {
    my ($filter,$stream)=@_;

    if((defined $filter) ) {
        # we need to fix filter because it MAY be
        # an array BUT IT COULD BE only a name
        if(ref($filter)!~/Array$/) {
               $filter = PDFArray($filter);
        }
        my @filts;
        my ($hasflate) = -1;
        my ($temp, $i, $temp1);

        @filts=(map { ("PDF::API2::Basic::PDF::".($_->val))->new } $filter->elementsof);

        foreach my $f (@filts) {
            $stream = $f->infilt($stream, 1);
        }
    }
    return($stream);
}

sub dofilter {
    my ($filter,$stream)=@_;

    if((defined $filter) ) {
        # we need to fix filter because it MAY be
        # an array BUT IT COULD BE only a name
        if(ref($filter)!~/Array$/) {
               $filter = PDFArray($filter);
        }
        my @filts;
        my ($hasflate) = -1;
        my ($temp, $i, $temp1);

        @filts=(map { ("PDF::API2::Basic::PDF::".($_->val))->new } $filter->elementsof);

        foreach my $f (@filts) {
            $stream = $f->outfilt($stream, 1);
        }
    }
    return($stream);
}

sub nameByUni {
  my ($e)=@_;
  return($u2n{$e} || sprintf('uni%04X',$e));
}

sub uniByName {
  my ($e)=@_;
  if($e=~/^uni([0-9A-F]{4})$/) {
    return(hex($1));
  }
  return($n2u{$e} || undef);
}

sub initNameTable {
    %u2n=(); %u2n=%u2n_o;
    %n2u=(); %n2u=%n2u_o;
    $pua=0xE000;
    1;
}
sub defineName {
    my $name=shift @_;
    return($n2u{$name}) if(defined $n2u{$name});

    while(defined $u2n{$pua}) { $pua++; }

    $u2n{$pua}=$name;
    $n2u{$name}=$pua;

    return($pua);
}

sub page_size {
    my %pgsz=(
        '4a'        =>  [ 4760  , 6716  ],
        '2a'        =>  [ 3368  , 4760  ],
        'a0'        =>  [ 2380  , 3368  ],
        'a1'        =>  [ 1684  , 2380  ],
        'a2'        =>  [ 1190  , 1684  ],
        'a3'        =>  [ 842   , 1190  ],
        'a4'        =>  [ 595   , 842   ],
        'a5'        =>  [ 421   , 595   ],
        'a6'        =>  [ 297   , 421   ],
        '4b'        =>  [ 5656  , 8000  ],
        '2b'        =>  [ 4000  , 5656  ],
        'b0'        =>  [ 2828  , 4000  ],
        'b1'        =>  [ 2000  , 2828  ],
        'b2'        =>  [ 1414  , 2000  ],
        'b3'        =>  [ 1000  , 1414  ],
        'b4'        =>  [ 707   , 1000  ],
        'b5'        =>  [ 500   , 707   ],
        'b6'        =>  [ 353   , 500   ],
        'letter'    =>  [ 612   , 792   ],
        'broadsheet'    =>  [ 1296  , 1584  ],
        'ledger'    =>  [ 1224  , 792   ],
        'tabloid'   =>  [ 792   , 1224  ],
        'legal'     =>  [ 612   , 1008  ],
        'executive' =>  [ 522   , 756   ],
        '36x36'     =>  [ 2592  , 2592  ],
    );
    my ($x1,$y1,$x2,$y2) = @_;
    if(defined $x2) {
        # full bbox
        return($x1,$y1,$x2,$y2);
    } elsif(defined $y1) {
        # half bbox
        return(0,0,$x1,$y1);
    } elsif(defined $pgsz{lc($x1)}) {
        # textual spec.
        return(0,0,@{$pgsz{lc($x1)}});
    } elsif($x1=~/^[\d\.]+$/) {
        # single quadratic
        return(0,0,$x1,$x1);
    } else {
        # pdf default.
        return(0,0,612,792);
    }
}


1;


__END__

function xRGBhex_to_aRGBhex ( $hstring, $lightness = 1.0 ) {

    $color=hexdec($hstring);

    $r=(($color & 0xff0000) >> 16)/255;
    $g=(($color & 0xff00) >> 8)/255;
    $b=($color & 0xff)/255;

    $rgbmax=max($r,$g,$b);

    $rgbmin=min($r,$g,$b);

    $rgbavg=($r+$g+$b)/3.0;


    if($rgbmin==$rgbmax) {
        return $hstring;
    }

    if ( $r == $rgbmax ) {
        $h = ( $g - $b ) / ( $rgbmax - $rgbmin );
    } elseif ( $g == $rgbmax ) {
        $h = 2.0 + ( $b - $r ) / ( $rgbmax - $rgbmin );
    } elseif ( $b == $rgbmax ) {
        $h = 4.0 + ( $r - $g ) / ( $rgbmax - $rgbmin );
    }
    if ( $h >= 6.0 ) {
        $h-=6.0;
    } elseif ( $h < 0.0 ) {
        $h+=6.0;
    }
    $s = ( $rgbmax - $rgbmin ) / $rgbmax;
    $s = $s>0.8 ? $s : 0.8;
    $ab = (0.3*$r) + (0.5*$g) + (0.2*$b);
    $v=$lightness*(pow($ab,(1/3)));

    $i=floor($h);
    $f=$h-$i;
    $p=$v*(1.0-$s);
    $q=$v*(1.0-$s*$f);
    $t=$v*(1.0-$s+$s*$f);

    if ($i==0) {
        return sprintf("%02X%02X%02X",$v*255,$t*255,$p*255);
    } elseif ($i==1) {
        return sprintf("%02X%02X%02X",$q*255,$v*255,$p*255);
    } elseif ($i==2) {
        return sprintf("%02X%02X%02X",$p*255,$v*255,$t*255);
    } elseif ($i==3) {
        return sprintf("%02X%02X%02X",$p*255,$q*255,$v*255);
    } elseif ($i==4) {
        return sprintf("%02X%02X%02X",$t*255,$p*255,$v*255);
    } else {
        return sprintf("%02X%02X%02X",$v*255,$p*255,$q*255);
    }
}


function RGBhex_bwinv ( $hstring ) {
        $color=hexdec($hstring);

        $r=(($color & 0xff0000) >> 16)/255;
        $g=(($color & 0xff00) >> 8)/255;
        $b=($color & 0xff)/255;

    $ab = (0.2*$r) + (0.7*$g) + (0.1*$b);

    if($ab > 0.45) {
        return "000000";
    } else {
        return "FFFFFF";
    }
}

=head1 NAME

PDF::API2::Util - utility package for often use methods across the package.

=head1 PREDEFINED COLORS

aliceblue antiquewhite antiquewhite1 antiquewhite2 antiquewhite3 antiquewhite4 aqua aquamarine
aquamarine1 aquamarine2 aquamarine3 aquamarine4 azure azure1 azure2 azure3 azure4 beige bisque bisque1
bisque2 bisque3 bisque4 black blanchedalmond blue blue1 blue2 blue3 blue4 blueviolet brass brightgold
bronze bronzeii brown brown1 brown2 brown3 brown4 burlywood burlywood1 burlywood2 burlywood3 burlywood4
cadetblue cadetblue1 cadetblue2 cadetblue3 cadetblue4 chartreuse chartreuse1 chartreuse2 chartreuse3
chartreuse4 chocolate chocolate1 chocolate2 chocolate3 chocolate4 coolcopper coral coral1 coral2 coral3
coral4 cornflowerblue cornsilk cornsilk1 cornsilk2 cornsilk3 cornsilk4 crimson cyan cyan1 cyan2 cyan3
cyan4 darkblue darkcyan darkgoldenrod darkgoldenrod1 darkgoldenrod2 darkgoldenrod3 darkgoldenrod4
darkgray darkgreen darkgrey darkkhaki darkmagenta darkolivegreen darkolivegreen1 darkolivegreen2
darkolivegreen3 darkolivegreen4 darkorange darkorange1 darkorange2 darkorange3 darkorange4 darkorchid
darkorchid1 darkorchid2 darkorchid3 darkorchid4 darkred darksalmon darkseagreen darkseagreen1
darkseagreen2 darkseagreen3 darkseagreen4 darkslateblue darkslategray darkslategray1 darkslategray2
darkslategray3 darkslategray4 darkslategrey darkturquoise darkviolet darkwood deeppink deeppink1
deeppink2 deeppink3 deeppink4 deepskyblue deepskyblue1 deepskyblue2 deepskyblue3 deepskyblue4 dimgray
dimgrey dodgerblue dodgerblue1 dodgerblue2 dodgerblue3 dodgerblue4 dustyrose feldspar firebrick
firebrick1 firebrick2 firebrick3 firebrick4 flesh floralwhite forestgreen fuchsia gainsboro ghostwhite
gold gold1 gold2 gold3 gold4 goldenrod goldenrod1 goldenrod2 goldenrod3 goldenrod4 gray gray0 gray1
gray10 gray100 gray11 gray12 gray13 gray14 gray15 gray16 gray17 gray18 gray19 gray2 gray20 gray21
gray22 gray23 gray24 gray25 gray26 gray27 gray28 gray29 gray3 gray30 gray31 gray32 gray33 gray34 gray35
gray36 gray37 gray38 gray39 gray4 gray40 gray41 gray42 gray43 gray44 gray45 gray46 gray47 gray48 gray49
gray5 gray50 gray51 gray52 gray53 gray54 gray55 gray56 gray57 gray58 gray59 gray6 gray60 gray61 gray62
gray63 gray64 gray65 gray66 gray67 gray68 gray69 gray7 gray70 gray71 gray72 gray73 gray74 gray75 gray76
gray77 gray78 gray79 gray8 gray80 gray81 gray82 gray83 gray84 gray85 gray86 gray87 gray88 gray89 gray9
gray90 gray91 gray92 gray93 gray94 gray95 gray96 gray97 gray98 gray99 green green1 green2 green3 green4
greencopper greenyellow grey grey0 grey1 grey10 grey100 grey11 grey12 grey13 grey14 grey15 grey16
grey17 grey18 grey19 grey2 grey20 grey21 grey22 grey23 grey24 grey25 grey26 grey27 grey28 grey29 grey3
grey30 grey31 grey32 grey33 grey34 grey35 grey36 grey37 grey38 grey39 grey4 grey40 grey41 grey42 grey43
grey44 grey45 grey46 grey47 grey48 grey49 grey5 grey50 grey51 grey52 grey53 grey54 grey55 grey56 grey57
grey58 grey59 grey6 grey60 grey61 grey62 grey63 grey64 grey65 grey66 grey67 grey68 grey69 grey7 grey70
grey71 grey72 grey73 grey74 grey75 grey76 grey77 grey78 grey79 grey8 grey80 grey81 grey82 grey83 grey84
grey85 grey86 grey87 grey88 grey89 grey9 grey90 grey91 grey92 grey93 grey94 grey95 grey96 grey97 grey98
grey99 honeydew honeydew1 honeydew2 honeydew3 honeydew4 hotpink hotpink1 hotpink2 hotpink3 hotpink4
indianred indianred1 indianred2 indianred3 indianred4 indigo ivory ivory1 ivory2 ivory3 ivory4 khaki
khaki1 khaki2 khaki3 khaki4 lavender lavenderblush lavenderblush1 lavenderblush2 lavenderblush3
lavenderblush4 lawngreen lemonchiffon lemonchiffon1 lemonchiffon2 lemonchiffon3 lemonchiffon4 lightblue
lightblue1 lightblue2 lightblue3 lightblue4 lightcoral lightcyan lightcyan1 lightcyan2 lightcyan3
lightcyan4 lightgoldenrod lightgoldenrod1 lightgoldenrod2 lightgoldenrod3 lightgoldenrod4
lightgoldenrodyellow lightgray lightgreen lightgrey lightpink lightpink1 lightpink2 lightpink3
lightpink4 lightsalmon lightsalmon1 lightsalmon2 lightsalmon3 lightsalmon4 lightseagreen lightskyblue
lightskyblue1 lightskyblue2 lightskyblue3 lightskyblue4 lightslateblue lightslategray lightslategrey
lightsteelblue lightsteelblue1 lightsteelblue2 lightsteelblue3 lightsteelblue4 lightyellow lightyellow1
lightyellow2 lightyellow3 lightyellow4 lime limegreen linen magenta magenta1 magenta2 magenta3 magenta4
mandarianorange maroon maroon1 maroon2 maroon3 maroon4 mediumaquamarine mediumblue mediumorchid
mediumorchid1 mediumorchid2 mediumorchid3 mediumorchid4 mediumpurple mediumpurple1 mediumpurple2
mediumpurple3 mediumpurple4 mediumseagreen mediumslateblue mediumspringgreen mediumturquoise
mediumvioletred midnightblue mintcream mistyrose mistyrose1 mistyrose2 mistyrose3 mistyrose4 moccasin
navajowhite navajowhite1 navajowhite2 navajowhite3 navajowhite4 navy navyblue neonblue neonpink none
oldlace olive olivedrab olivedrab1 olivedrab2 olivedrab3 olivedrab4 orange orange1 orange2 orange3
orange4 orangered orangered1 orangered2 orangered3 orangered4 orchid orchid1 orchid2 orchid3 orchid4
palegoldenrod palegreen palegreen1 palegreen2 palegreen3 palegreen4 paleturquoise paleturquoise1
paleturquoise2 paleturquoise3 paleturquoise4 palevioletred palevioletred1 palevioletred2 palevioletred3
palevioletred4 papayawhip peachpuff peachpuff1 peachpuff2 peachpuff3 peachpuff4 peru pink pink1 pink2
pink3 pink4 plum plum1 plum2 plum3 plum4 powderblue purple purple1 purple2 purple3 purple4 quartz red
red1 red2 red3 red4 richblue rosybrown rosybrown1 rosybrown2 rosybrown3 rosybrown4 royalblue royalblue1
royalblue2 royalblue3 royalblue4 saddlebrown salmon salmon1 salmon2 salmon3 salmon4 sandybrown seagreen
seagreen1 seagreen2 seagreen3 seagreen4 seashell seashell1 seashell2 seashell3 seashell4 sienna sienna1
sienna2 sienna3 sienna4 silver skyblue skyblue1 skyblue2 skyblue3 skyblue4 slateblue slateblue1
slateblue2 slateblue3 slateblue4 slategray slategray1 slategray2 slategray3 slategray4 slategrey snow
snow1 snow2 snow3 snow4 springgreen springgreen1 springgreen2 springgreen3 springgreen4 steelblue
steelblue1 steelblue2 steelblue3 steelblue4 summersky tan tan1 tan2 tan3 tan4 teal thistle thistle1
thistle2 thistle3 thistle4 tomato tomato1 tomato2 tomato3 tomato4 turquoise turquoise1 turquoise2
turquoise3 turquoise4 violet violetred violetred1 violetred2 violetred3 violetred4 wheat wheat1 wheat2
wheat3 wheat4 white whitesmoke yellow yellow1 yellow2 yellow3 yellow4 yellowgreen

B<Please Note:> This is an amalgamation of the X11, SGML and (X)HTML specification sets.

=head1 PREDEFINED GLYPH-NAMES

a a1 a10 a100 a101 a102 a103 a104 a105 a106 a107 a108 a11 a117 a118 a119 a12 a120 a121 a122 a123 a124
a125 a126 a127 a128 a129 a13 a130 a131 a132 a133 a134 a135 a136 a137 a138 a139 a14 a140 a141 a142 a143
a144 a145 a146 a147 a148 a149 a15 a150 a151 a152 a153 a154 a155 a156 a157 a158 a159 a16 a160 a162 a165
a166 a167 a168 a169 a17 a170 a171 a172 a173 a174 a175 a176 a177 a178 a179 a18 a180 a181 a182 a183 a184
a185 a186 a187 a188 a189 a19 a190 a191 a192 a193 a194 a195 a196 a197 a198 a199 a2 a20 a200 a201 a202 a203
a204 a205 a206 a21 a22 a23 a24 a25 a26 a27 a28 a29 a3 a30 a31 a32 a33 a34 a35 a36 a37 a38 a39 a4 a40 a41
a42 a43 a44 a45 a46 a47 a48 a49 a5 a50 a51 a52 a53 a54 a55 a56 a57 a58 a59 a6 a60 a61 a62 a63 a64 a65 a66
a67 a68 a69 a7 a70 a72 a74 a75 a78 a79 a8 a81 a82 a83 a84 a85 a86 a87 a88 a89 a9 a90 a91 a92 a93 a94 a95
a96 a97 a98 a99 aacgr aacute Aacutesmall abreve acirc acircumflex Acircumflexsmall acute acutecomb
Acutesmall acy adieresis Adieresissmall ae aeacute aelig AEsmall afii00208 afii10017 afii10018 afii10019
afii10020 afii10021 afii10022 afii10023 afii10024 afii10025 afii10026 afii10027 afii10028 afii10029
afii10030 afii10031 afii10032 afii10033 afii10034 afii10035 afii10036 afii10037 afii10038 afii10039
afii10040 afii10041 afii10042 afii10043 afii10044 afii10045 afii10046 afii10047 afii10048 afii10049
afii10050 afii10051 afii10052 afii10053 afii10054 afii10055 afii10056 afii10057 afii10058 afii10059
afii10060 afii10061 afii10062 afii10063 afii10064 afii10065 afii10066 afii10067 afii10068 afii10069
afii10070 afii10071 afii10072 afii10073 afii10074 afii10075 afii10076 afii10077 afii10078 afii10079
afii10080 afii10081 afii10082 afii10083 afii10084 afii10085 afii10086 afii10087 afii10088 afii10089
afii10090 afii10091 afii10092 afii10093 afii10094 afii10095 afii10096 afii10097 afii10098 afii10099
afii10100 afii10101 afii10102 afii10103 afii10104 afii10105 afii10106 afii10107 afii10108 afii10109
afii10110 afii10145 afii10146 afii10147 afii10148 afii10192 afii10193 afii10194 afii10195 afii10196
afii10831 afii10832 afii10846 afii299 afii300 afii301 afii57381 afii57388 afii57392 afii57393 afii57394
afii57395 afii57396 afii57397 afii57398 afii57399 afii57400 afii57401 afii57403 afii57407 afii57409
afii57410 afii57411 afii57412 afii57413 afii57414 afii57415 afii57416 afii57417 afii57418 afii57419
afii57420 afii57421 afii57422 afii57423 afii57424 afii57425 afii57426 afii57427 afii57428 afii57429
afii57430 afii57431 afii57432 afii57433 afii57434 afii57440 afii57441 afii57442 afii57443 afii57444
afii57445 afii57446 afii57448 afii57449 afii57450 afii57451 afii57452 afii57453 afii57454 afii57455
afii57456 afii57457 afii57458 afii57470 afii57505 afii57506 afii57507 afii57508 afii57509 afii57511
afii57512 afii57513 afii57514 afii57519 afii57534 afii57636 afii57645 afii57658 afii57664 afii57665
afii57666 afii57667 afii57668 afii57669 afii57670 afii57671 afii57672 afii57673 afii57674 afii57675
afii57676 afii57677 afii57678 afii57679 afii57680 afii57681 afii57682 afii57683 afii57684 afii57685
afii57686 afii57687 afii57688 afii57689 afii57690 afii57694 afii57695 afii57700 afii57705 afii57716
afii57717 afii57718 afii57723 afii57793 afii57794 afii57795 afii57796 afii57797 afii57798 afii57799
afii57800 afii57801 afii57802 afii57803 afii57804 afii57806 afii57807 afii57839 afii57841 afii57842
afii57929 afii61248 afii61289 afii61352 afii61573 afii61574 afii61575 afii61664 afii63167 afii64937 agr
agrave Agravesmall airplane alefsym aleph alpha alphatonos amacr amacron amalg amp ampersand ampersandit
ampersanditlc ampersandsmall and ang ang90 angle angleleft angleright angmsd angsph angst anoteleia aogon
aogonek ap ape apos approxequal aquarius aries aring aringacute Aringsmall arrowboth arrowdblboth
arrowdbldown arrowdblleft arrowdblright arrowdblup arrowdown arrowdwnleft1 arrowdwnrt1 arrowhorizex
arrowleft arrowleftdwn1 arrowleftup1 arrowright arrowrtdwn1 arrowrtup1 arrowup arrowupdn arrowupdnbse
arrowupleft1 arrowuprt1 arrowvertex asciicircum asciitilde Asmall ast asterisk asteriskmath asuperior
asymp at atilde Atildesmall auml b backslash ballpoint bar barb2down barb2left barb2ne barb2nw barb2right
barb2se barb2sw barb2up barb4down barb4left barb4ne barb4nw barb4right barb4se barb4sw barb4up barwed
bcong bcy bdash1 bdash2 bdown bdquo becaus bell bepsi bernou beta beth bgr blank bleft bleftright blk12
blk14 blk34 block bne bnw bomb book bottom bowtie box2 box3 box4 boxcheckbld boxdl boxdr boxh boxhd boxhu
boxshadowdwn boxshadowup boxul boxur boxv boxvh boxvl boxvr boxxmarkbld bprime braceex braceleft
braceleftbt braceleftmid bracelefttp braceright bracerightbt bracerightmid bracerighttp bracketleft
bracketleftbt bracketleftex bracketlefttp bracketright bracketrightbt bracketrightex bracketrighttp breve
Brevesmall bright brokenbar brvbar bse bsim bsime Bsmall bsol bsuperior bsw budleafne budleafnw budleafse
budleafsw bull bullet bump bumpe bup bupdown c cacute cancer candle cap capricorn caret caron Caronsmall
carriagereturn ccaron ccedil ccedilla Ccedillasmall ccirc ccircumflex cdot cdotaccent cedil cedilla
Cedillasmall cent centinferior centoldstyle centsuperior chcy check checkbld chi cir circ circle circle2
circle4 circle6 circledown circleleft circlemultiply circleplus circleright circleshadowdwn
circleshadowup circlestar circleup circumflex Circumflexsmall cire clear club clubs colon colone
colonmonetary comma commaaccent commainferior command commasuperior commat comp compfn cong congruent
conint coprod copy copyright copyrightsans copyrightserif copysr crarr crescentstar cross crossceltic
crossmaltese crossoutline crossshadow crosstar2 Csmall cuepr cuesc cularr cup cupre curarr curren
currency cuspopen cuspopen1 cuvee cuwed cyrbreve cyrflex d dagger daggerdbl daleth darr darr2 dash dashv
dblac dblgrave dcaron dcroat dcy deg degree deleteleft deleteright delta dgr dharl dharr diam diamond
diams die dieresis dieresisacute dieresisgrave Dieresissmall dieresistonos divide divonx djcy dkshade
dlarr dlcorn dlcrop dnblock dodecastar3 dollar dollarinferior dollaroldstyle dollarsuperior dong dot
dotaccent Dotaccentsmall dotbelowcomb DotDot dotlessi dotlessj dotmath drarr drcorn drcrop droplet dscy
Dsmall dstrok dsuperior dtri dtrif dzcy e eacgr eacute Eacutesmall ebreve ecaron ecir ecirc ecircumflex
Ecircumflexsmall ecolon ecy edieresis Edieresissmall edot edotaccent eeacgr eegr efDot egr egrave
Egravesmall egs eight eightinferior eightoclock eightoldstyle eightsans eightsansinv eightsuperior
element elevenoclock ell ellipsis els emacr emacron emdash empty emptyset emsp emsp13 emsp14 endash eng
ensp envelopeback envelopefront eogon eogonek epsi epsilon epsilontonos epsis equal equals equiv
equivalence erDot escape esdot Esmall estimated esuperior eta etatonos eth Ethsmall euml euro excl exclam
exclamdbl exclamdown exclamdownsmall exclamsmall exist existential f fcy female ff ffi ffl fi figuredash
filecabinet filetalltext filetalltext1 filetalltext3 filledbox filledrect five fiveeighths fiveinferior
fiveoclock fiveoldstyle fivesans fivesansinv fivesuperior fl flag flat floppy3 floppy5 florin fnof folder
folderopen forall fork four fourinferior fouroclock fouroldstyle foursans foursansinv foursuperior frac12
frac13 frac14 frac15 frac16 frac18 frac23 frac25 frac34 frac35 frac38 frac45 frac56 frac58 frac78
fraction franc frasl frown frownface Fsmall g gamma gammad gbreve gcaron gcedil gcirc gcircumflex
gcommaaccent gcy gdot gdotaccent ge gel gemini germandbls ges Gg ggr gimel gjcy gl gnE gnsim gradient
grave gravecomb Gravesmall greater greaterequal gsdot gsim Gsmall gt guillemotleft guillemotright
guilsinglleft guilsinglright gvnE h H18533 H18543 H18551 H22073 hairsp hamilt handhalt handok handptdwn
handptleft handptright handptup handv handwrite handwriteleft hardcy harddisk harr harrw hbar hcirc
hcircumflex head2down head2left head2right head2up heart hearts hellip hexstar2 hookabovecomb horbar
hourglass house Hsmall hstrok hungarumlaut Hungarumlautsmall hybull hyphen hypheninferior hyphensuperior
i iacgr iacute Iacutesmall ibreve icirc icircumflex Icircumflexsmall icy idiagr idieresis Idieresissmall
idigr Idot Idotaccent iecy iexcl iff Ifraktur igr igrave Igravesmall ij ijlig imacr imacron image incare
infin infinity inodot int intcal integral integralbt integralex integraltp intersection invbullet
invcircle invsmileface iocy iogon iogonek iota iotadieresis iotadieresistonos iotatonos iquest isin
Ismall isuperior itilde iukcy iuml j jcirc jcircumflex jcy jsercy Jsmall jukcy k kappa kappav kcedil
kcommaaccent kcy keyboard kgr kgreen kgreenlandic khcy khgr kjcy Ksmall l lAarr lacute lagran lambda lang
laquo larr larr2 larrhk larrlp larrtl lcaron lcedil lceil lcommaaccent lcub lcy ldot ldquo ldquor le
leafccwne leafccwnw leafccwse leafccwsw leafne leafnw leafse leafsw leg leo les less lessequal lfblock
lfloor lg lgr lhard lharu lhblk libra lira ljcy ll lmidot lnE lnsim logicaland logicalnot logicalor longs
lowast lowbar loz lozenge lozenge4 lozenge6 lozf lpar lrarr2 lrhar2 lsaquo lsh lsim lslash Lslashsmall
Lsmall lsqb lsquo lsquor lstrok lsuperior lt lthree ltimes ltri ltrie ltrif ltshade lvnE m macr macron
Macronsmall mailboxflagdwn mailboxflagup mailbxopnflgdwn mailbxopnflgup male malt map marker mcy mdash
mgr micro mid middot minus minusb minute mldr mnplus models mouse2button Msmall msuperior mu multiply
mumap musicalnote musicalnotedbl n nabla nacute nap napos napostrophe natur nbsp ncaron ncedil
ncommaaccent ncong ncy ndash ne nearr nequiv neutralface nexist nge nges ngr ngt nharr ni nine
nineinferior nineoclock nineoldstyle ninesans ninesansinv ninesuperior njcy nlarr nldr nle nles nlt nltri
nltrie nmid not notelement notequal notin notsubset npar npr npre nrarr nrtri nrtrie nsc nsce nsim nsime
Nsmall nsub nsube nsup nsupe nsuperior ntilde Ntildesmall nu num numbersign numero numsp nvdash nwarr o
oacgr oacute Oacutesmall oast obreve ocir ocirc ocircumflex Ocircumflexsmall octastar2 octastar4 ocy
odash odblac odieresis Odieresissmall odot oe oelig OEsmall ogon ogonek Ogoneksmall ogr ograve
Ogravesmall ohacgr ohgr ohm ohorn ohungarumlaut olarr oline om omacr omacron omega omega1 omegatonos
omicron omicrontonos ominus one onedotenleader oneeighth onefitted onehalf oneinferior oneoclock
oneoldstyle onequarter onesans onesansinv onesuperior onethird openbullet oplus or orarr order ordf
ordfeminine ordm ordmasculine orthogonal oS oslash oslashacute Oslashsmall Osmall osol osuperior otilde
Otildesmall otimes ouml overline p par para paragraph parenleft parenleftbt parenleftex parenleftinferior
parenleftsuperior parenlefttp parenright parenrightbt parenrightex parenrightinferior parenrightsuperior
parenrighttp part partialdiff pc pcy pencil pennant pentastar2 percent percnt period periodcentered
periodinferior periodsuperior permil perp perpendicular perthousand peseta pgr phgr phi phi1 phis phiv
phmmat phone pi pisces piv planck plus plusb plusdo plusminus plusmn pound pr prescription prime prnsim
prod product prop propersubset propersuperset proportional prsim psgr psi Psmall puncsp q Qsmall query
quest question questiondown questiondownsmall questionsmall quiltsquare2 quiltsquare2inv quot quotedbl
quotedblbase quotedblleft quotedbllftbld quotedblright quotedblrtbld quoteleft quotereversed quoteright
quotesinglbase quotesingle r rAarr racute radic radical radicalex rang raquo rarr rarr2 rarrhk rarrlp
rarrtl rarrw rcaron rcedil rceil rcommaaccent rcub rcy rdquo rdquor readingglasses real rect reflexsubset
reflexsuperset reg registercircle registered registersans registerserif registersquare revlogicalnot
rfloor Rfraktur rgr rhard rharu rho rhombus4 rhombus6 rhov ring ring2 ring4 ring6 ringbutton2 Ringsmall
rlarr2 rlhar2 rosette rosettesolid rpar rsaquo rsh Rsmall rsqb rsquo rsquor rsuperior rtblock rthree
rtimes rtri rtrie rtrif rupiah rx s sacute saggitarius samalg sbquo sc scaron Scaronsmall sccue scedil
scedilla scirc scircumflex scissors scissorscutting scnsim scommaaccent scorpio scsim scy sdot sdotb
second sect section semi semicolon setmn seven seveneighths seveninferior sevenoclock sevenoldstyle
sevensans sevensansinv sevensuperior sextile SF010000 SF020000 SF030000 SF040000 SF050000 SF060000
SF070000 SF080000 SF090000 SF100000 SF110000 SF190000 SF200000 SF210000 SF220000 SF230000 SF240000
SF250000 SF260000 SF270000 SF280000 SF360000 SF370000 SF380000 SF390000 SF400000 SF410000 SF420000
SF430000 SF440000 SF450000 SF460000 SF470000 SF480000 SF490000 SF500000 SF510000 SF520000 SF530000
SF540000 sfgr sgr shade sharp shchcy shcy shy sigma sigma1 sigmav sim sime similar six sixinferior
sixoclock sixoldstyle sixsans sixsansinv sixsuperior skullcrossbones slash smile smileface snowflake
softcy sol space spade spades sqcap sqcup sqsub sqsube sqsup sqsupe squ square square2 square4 square6
squf Ssmall sstarf ssuperior star starf starofdavid starshadow sterling sub sube subnE suchthat sum
summation sun sung sunshine sup sup1 sup2 sup3 supe supnE szlig t tapereel target tau taurus tbar tcaron
tcedil tcommaaccent tcy tdot telephonesolid telhandsetcirc telrec tenoclock tensans tensansinv tgr there4
therefore theta theta1 thetas thetasym thetav thgr thinsp thkap thksim thorn Thornsmall three
threeeighths threeinferior threeoclock threeoldstyle threequarters threequartersemdash threesans
threesansinv threesuperior thumbdown thumbup tilde tildecomb Tildesmall times timesb tonos top tprime
trade trademark trademarksans trademarkserif triagdn triaglf triagrt triagup trie tristar2 tscy tshcy
Tsmall tstrok tsuperior twelveoclock twixt two twodotenleader twoinferior twooclock twooldstyle twosans
twosansinv twosuperior twothirds u uacgr uacute Uacutesmall uarr uarr2 ubrcy ubreve ucirc ucircumflex
Ucircumflexsmall ucy udblac udiagr udieresis Udieresissmall udigr ugr ugrave Ugravesmall uharl uharr
uhblk uhorn uhungarumlaut ulcorn ulcrop umacr umacron uml underscore underscoredbl union universal uogon
uogonek upblock uplus upsi upsih upsilon Upsilon1 upsilondieresis upsilondieresistonos upsilontonos
urcorn urcrop uring Usmall utilde utri utrif uuml v varr vcy vdash veebar vellip verbar vineleafboldne
vineleafboldnw vineleafboldse vineleafboldsw virgo vltri vprime vprop vrtri Vsmall Vvdash w wacute wcirc
wcircumflex wdieresis wedgeq weierp weierstrass wgrave wheel windowslogo wreath Wsmall x xcirc xdtri xgr
xi xmarkbld xrhombus Xsmall xutri y yacute Yacutesmall yacy ycirc ycircumflex ycy ydieresis
Ydieresissmall yen ygrave yicy yinyang Ysmall yucy yuml z zacute zcaron Zcaronsmall zcy zdot zdotaccent
zero zeroinferior zerooldstyle zerosans zerosansinv zerosuperior zeta zgr zhcy Zsmall zwnj

B<Please Note:> You may notice that apart from the 'AGL/WGL4', names from the XML, (X)HTML and SGML
specification sets have been included to enable interoperability towards PDF.

=head1 HISTORY

    $Log: Util.pm,v $
    Revision 1.12  2004/06/21 22:33:37  fredo
    added basic pattern/shading handling

    Revision 1.11  2004/06/15 09:11:38  fredo
    removed cr+lf

    Revision 1.10  2004/06/07 19:44:12  fredo
    cleaned out cr+lf for lf

    Revision 1.9  2004/02/12 14:39:22  fredo
    start work on better HSV code

    Revision 1.8  2004/02/10 15:53:57  fredo
    corrected pdfkeys

    Revision 1.7  2004/02/05 22:21:48  fredo
    fixed lab behavior

    Revision 1.6  2004/02/05 16:13:23  fredo
    fixed namecolor methods

    Revision 1.5  2004/02/05 11:28:48  fredo
    simplified namecolor,
    added *_lab/*_cmyk methods,
    corrected rgb->cmyk conversion to practical parameters

    Revision 1.4  2003/12/08 13:05:19  Administrator
    corrected to proper licencing statement

    Revision 1.3  2003/11/30 17:20:10  Administrator
    merged into default

    Revision 1.2.2.1  2003/11/30 16:56:22  Administrator
    merged into default

    Revision 1.2  2003/11/30 11:32:17  Administrator
    added CVS id/log


=cut