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
#=======================================================================
#
#   THIS IS A REUSED PERL MODULE, FOR PROPER LICENCING TERMS SEE BELOW:
#
#
#   Copyright Martin Hosken <Martin_Hosken@sil.org>
#
#   No warranty or expression of effectiveness, least of all regarding
#   anyone's safety, is implied in this software or documentation.
#
#   This specific module is licensed under the Perl Artistic License.
#
#
#   $Id: PSNames.pm,v 1.4 2004/06/07 19:44:35 fredo Exp $
#
#=======================================================================
package PDF::API2::Basic::TTF::PSNames;

use strict;
use vars qw(%names %doubles);

%names = (
    '0020' => 'space',
    '0021' => 'exclam',
    '0022' => 'quotedbl',
    '0023' => 'numbersign',
    '0024' => 'dollar',
    '0025' => 'percent',
    '0026' => 'ampersand',
    '0027' => 'quotesingle',
    '0028' => 'parenleft',
    '0029' => 'parenright',
    '002A' => 'asterisk',
    '002B' => 'plus',
    '002C' => 'comma',
    '002D' => 'hyphen',
    '002E' => 'period',
    '002F' => 'slash',
    '0030' => 'zero',
    '0031' => 'one',
    '0032' => 'two',
    '0033' => 'three',
    '0034' => 'four',
    '0035' => 'five',
    '0036' => 'six',
    '0037' => 'seven',
    '0038' => 'eight',
    '0039' => 'nine',
    '003A' => 'colon',
    '003B' => 'semicolon',
    '003C' => 'less',
    '003D' => 'equal',
    '003E' => 'greater',
    '003F' => 'question',
    '0040' => 'at',
    '0041' => 'A',
    '0042' => 'B',
    '0043' => 'C',
    '0044' => 'D',
    '0045' => 'E',
    '0046' => 'F',
    '0047' => 'G',
    '0048' => 'H',
    '0049' => 'I',
    '004A' => 'J',
    '004B' => 'K',
    '004C' => 'L',
    '004D' => 'M',
    '004E' => 'N',
    '004F' => 'O',
    '0050' => 'P',
    '0051' => 'Q',
    '0052' => 'R',
    '0053' => 'S',
    '0054' => 'T',
    '0055' => 'U',
    '0056' => 'V',
    '0057' => 'W',
    '0058' => 'X',
    '0059' => 'Y',
    '005A' => 'Z',
    '005B' => 'bracketleft',
    '005C' => 'backslash',
    '005D' => 'bracketright',
    '005E' => 'asciicircum',
    '005F' => 'underscore',
    '0060' => 'grave',
    '0061' => 'a',
    '0062' => 'b',
    '0063' => 'c',
    '0064' => 'd',
    '0065' => 'e',
    '0066' => 'f',
    '0067' => 'g',
    '0068' => 'h',
    '0069' => 'i',
    '006A' => 'j',
    '006B' => 'k',
    '006C' => 'l',
    '006D' => 'm',
    '006E' => 'n',
    '006F' => 'o',
    '0070' => 'p',
    '0071' => 'q',
    '0072' => 'r',
    '0073' => 's',
    '0074' => 't',
    '0075' => 'u',
    '0076' => 'v',
    '0077' => 'w',
    '0078' => 'x',
    '0079' => 'y',
    '007A' => 'z',
    '007B' => 'braceleft',
    '007C' => 'bar',
    '007D' => 'braceright',
    '007E' => 'asciitilde',
    '00A0' => 'space',
    '00A1' => 'exclamdown',
    '00A2' => 'cent',
    '00A3' => 'sterling',
    '00A4' => 'currency',
    '00A5' => 'yen',
    '00A6' => 'brokenbar',
    '00A7' => 'section',
    '00A8' => 'dieresis',
    '00A9' => 'copyright',
    '00AA' => 'ordfeminine',
    '00AB' => 'guillemotleft',
    '00AC' => 'logicalnot',
    '00AD' => 'hyphen',
    '00AE' => 'registered',
    '00AF' => 'macron',
    '00B0' => 'degree',
    '00B1' => 'plusminus',
    '00B2' => 'twosuperior',
    '00B3' => 'threesuperior',
    '00B4' => 'acute',
    '00B5' => 'mu',
    '00B6' => 'paragraph',
    '00B7' => 'periodcentered',
    '00B8' => 'cedilla',
    '00B9' => 'onesuperior',
    '00BA' => 'ordmasculine',
    '00BB' => 'guillemotright',
    '00BC' => 'onequarter',
    '00BD' => 'onehalf',
    '00BE' => 'threequarters',
    '00BF' => 'questiondown',
    '00C0' => 'Agrave',
    '00C1' => 'Aacute',
    '00C2' => 'Acircumflex',
    '00C3' => 'Atilde',
    '00C4' => 'Adieresis',
    '00C5' => 'Aring',
    '00C6' => 'AE',
    '00C7' => 'Ccedilla',
    '00C8' => 'Egrave',
    '00C9' => 'Eacute',
    '00CA' => 'Ecircumflex',
    '00CB' => 'Edieresis',
    '00CC' => 'Igrave',
    '00CD' => 'Iacute',
    '00CE' => 'Icircumflex',
    '00CF' => 'Idieresis',
    '00D0' => 'Eth',
    '00D1' => 'Ntilde',
    '00D2' => 'Ograve',
    '00D3' => 'Oacute',
    '00D4' => 'Ocircumflex',
    '00D5' => 'Otilde',
    '00D6' => 'Odieresis',
    '00D7' => 'multiply',
    '00D8' => 'Oslash',
    '00D9' => 'Ugrave',
    '00DA' => 'Uacute',
    '00DB' => 'Ucircumflex',
    '00DC' => 'Udieresis',
    '00DD' => 'Yacute',
    '00DE' => 'Thorn',
    '00DF' => 'germandbls',
    '00E0' => 'agrave',
    '00E1' => 'aacute',
    '00E2' => 'acircumflex',
    '00E3' => 'atilde',
    '00E4' => 'adieresis',
    '00E5' => 'aring',
    '00E6' => 'ae',
    '00E7' => 'ccedilla',
    '00E8' => 'egrave',
    '00E9' => 'eacute',
    '00EA' => 'ecircumflex',
    '00EB' => 'edieresis',
    '00EC' => 'igrave',
    '00ED' => 'iacute',
    '00EE' => 'icircumflex',
    '00EF' => 'idieresis',
    '00F0' => 'eth',
    '00F1' => 'ntilde',
    '00F2' => 'ograve',
    '00F3' => 'oacute',
    '00F4' => 'ocircumflex',
    '00F5' => 'otilde',
    '00F6' => 'odieresis',
    '00F7' => 'divide',
    '00F8' => 'oslash',
    '00F9' => 'ugrave',
    '00FA' => 'uacute',
    '00FB' => 'ucircumflex',
    '00FC' => 'udieresis',
    '00FD' => 'yacute',
    '00FE' => 'thorn',
    '00FF' => 'ydieresis',
    '0100' => 'Amacron',
    '0101' => 'amacron',
    '0102' => 'Abreve',
    '0103' => 'abreve',
    '0104' => 'Aogonek',
    '0105' => 'aogonek',
    '0106' => 'Cacute',
    '0107' => 'cacute',
    '0108' => 'Ccircumflex',
    '0109' => 'ccircumflex',
    '010A' => 'Cdotaccent',
    '010B' => 'cdotaccent',
    '010C' => 'Ccaron',
    '010D' => 'ccaron',
    '010E' => 'Dcaron',
    '010F' => 'dcaron',
    '0110' => 'Dcroat',
    '0111' => 'dcroat',
    '0112' => 'Emacron',
    '0113' => 'emacron',
    '0114' => 'Ebreve',
    '0115' => 'ebreve',
    '0116' => 'Edotaccent',
    '0117' => 'edotaccent',
    '0118' => 'Eogonek',
    '0119' => 'eogonek',
    '011A' => 'Ecaron',
    '011B' => 'ecaron',
    '011C' => 'Gcircumflex',
    '011D' => 'gcircumflex',
    '011E' => 'Gbreve',
    '011F' => 'gbreve',
    '0120' => 'Gdotaccent',
    '0121' => 'gdotaccent',
    '0122' => 'Gcommaaccent',
    '0123' => 'gcommaaccent',
    '0124' => 'Hcircumflex',
    '0125' => 'hcircumflex',
    '0126' => 'Hbar',
    '0127' => 'hbar',
    '0128' => 'Itilde',
    '0129' => 'itilde',
    '012A' => 'Imacron',
    '012B' => 'imacron',
    '012C' => 'Ibreve',
    '012D' => 'ibreve',
    '012E' => 'Iogonek',
    '012F' => 'iogonek',
    '0130' => 'Idotaccent',
    '0131' => 'dotlessi',
    '0132' => 'IJ',
    '0133' => 'ij',
    '0134' => 'Jcircumflex',
    '0135' => 'jcircumflex',
    '0136' => 'Kcommaaccent',
    '0137' => 'kcommaaccent',
    '0138' => 'kgreenlandic',
    '0139' => 'Lacute',
    '013A' => 'lacute',
    '013B' => 'Lcommaaccent',
    '013C' => 'lcommaaccent',
    '013D' => 'Lcaron',
    '013E' => 'lcaron',
    '013F' => 'Ldot',
    '0140' => 'ldot',
    '0141' => 'Lslash',
    '0142' => 'lslash',
    '0143' => 'Nacute',
    '0144' => 'nacute',
    '0145' => 'Ncommaaccent',
    '0146' => 'ncommaaccent',
    '0147' => 'Ncaron',
    '0148' => 'ncaron',
    '0149' => 'napostrophe',
    '014A' => 'Eng',
    '014B' => 'eng',
    '014C' => 'Omacron',
    '014D' => 'omacron',
    '014E' => 'Obreve',
    '014F' => 'obreve',
    '0150' => 'Ohungarumlaut',
    '0151' => 'ohungarumlaut',
    '0152' => 'OE',
    '0153' => 'oe',
    '0154' => 'Racute',
    '0155' => 'racute',
    '0156' => 'Rcommaaccent',
    '0157' => 'rcommaaccent',
    '0158' => 'Rcaron',
    '0159' => 'rcaron',
    '015A' => 'Sacute',
    '015B' => 'sacute',
    '015C' => 'Scircumflex',
    '015D' => 'scircumflex',
    '015E' => 'Scedilla',
    '015F' => 'scedilla',
    '0160' => 'Scaron',
    '0161' => 'scaron',
    '0162' => 'Tcommaaccent',
    '0163' => 'tcommaaccent',
    '0164' => 'Tcaron',
    '0165' => 'tcaron',
    '0166' => 'Tbar',
    '0167' => 'tbar',
    '0168' => 'Utilde',
    '0169' => 'utilde',
    '016A' => 'Umacron',
    '016B' => 'umacron',
    '016C' => 'Ubreve',
    '016D' => 'ubreve',
    '016E' => 'Uring',
    '016F' => 'uring',
    '0170' => 'Uhungarumlaut',
    '0171' => 'uhungarumlaut',
    '0172' => 'Uogonek',
    '0173' => 'uogonek',
    '0174' => 'Wcircumflex',
    '0175' => 'wcircumflex',
    '0176' => 'Ycircumflex',
    '0177' => 'ycircumflex',
    '0178' => 'Ydieresis',
    '0179' => 'Zacute',
    '017A' => 'zacute',
    '017B' => 'Zdotaccent',
    '017C' => 'zdotaccent',
    '017D' => 'Zcaron',
    '017E' => 'zcaron',
    '017F' => 'longs',
    '0192' => 'florin',
    '01A0' => 'Ohorn',
    '01A1' => 'ohorn',
    '01AF' => 'Uhorn',
    '01B0' => 'uhorn',
    '01E6' => 'Gcaron',
    '01E7' => 'gcaron',
    '01FA' => 'Aringacute',
    '01FB' => 'aringacute',
    '01FC' => 'AEacute',
    '01FD' => 'aeacute',
    '01FE' => 'Oslashacute',
    '01FF' => 'oslashacute',
    '0218' => 'Scommaaccent',
    '0219' => 'scommaaccent',
    '021A' => 'Tcommaaccent',
    '021B' => 'tcommaaccent',
    '02BC' => 'afii57929',
    '02BD' => 'afii64937',
    '02C6' => 'circumflex',
    '02C7' => 'caron',
    '02C9' => 'macron',
    '02D8' => 'breve',
    '02D9' => 'dotaccent',
    '02DA' => 'ring',
    '02DB' => 'ogonek',
    '02DC' => 'tilde',
    '02DD' => 'hungarumlaut',
    '0300' => 'gravecomb',
    '0301' => 'acutecomb',
    '0303' => 'tildecomb',
    '0309' => 'hookabovecomb',
    '0323' => 'dotbelowcomb',
    '0384' => 'tonos',
    '0385' => 'dieresistonos',
    '0386' => 'Alphatonos',
    '0387' => 'anoteleia',
    '0388' => 'Epsilontonos',
    '0389' => 'Etatonos',
    '038A' => 'Iotatonos',
    '038C' => 'Omicrontonos',
    '038E' => 'Upsilontonos',
    '038F' => 'Omegatonos',
    '0390' => 'iotadieresistonos',
    '0391' => 'Alpha',
    '0392' => 'Beta',
    '0393' => 'Gamma',
    '0394' => 'Delta',
    '0395' => 'Epsilon',
    '0396' => 'Zeta',
    '0397' => 'Eta',
    '0398' => 'Theta',
    '0399' => 'Iota',
    '039A' => 'Kappa',
    '039B' => 'Lambda',
    '039C' => 'Mu',
    '039D' => 'Nu',
    '039E' => 'Xi',
    '039F' => 'Omicron',
    '03A0' => 'Pi',
    '03A1' => 'Rho',
    '03A3' => 'Sigma',
    '03A4' => 'Tau',
    '03A5' => 'Upsilon',
    '03A6' => 'Phi',
    '03A7' => 'Chi',
    '03A8' => 'Psi',
    '03A9' => 'Omega',
    '03AA' => 'Iotadieresis',
    '03AB' => 'Upsilondieresis',
    '03AC' => 'alphatonos',
    '03AD' => 'epsilontonos',
    '03AE' => 'etatonos',
    '03AF' => 'iotatonos',
    '03B0' => 'upsilondieresistonos',
    '03B1' => 'alpha',
    '03B2' => 'beta',
    '03B3' => 'gamma',
    '03B4' => 'delta',
    '03B5' => 'epsilon',
    '03B6' => 'zeta',
    '03B7' => 'eta',
    '03B8' => 'theta',
    '03B9' => 'iota',
    '03BA' => 'kappa',
    '03BB' => 'lambda',
    '03BC' => 'mu',
    '03BD' => 'nu',
    '03BE' => 'xi',
    '03BF' => 'omicron',
    '03C0' => 'pi',
    '03C1' => 'rho',
    '03C2' => 'sigma1',
    '03C3' => 'sigma',
    '03C4' => 'tau',
    '03C5' => 'upsilon',
    '03C6' => 'phi',
    '03C7' => 'chi',
    '03C8' => 'psi',
    '03C9' => 'omega',
    '03CA' => 'iotadieresis',
    '03CB' => 'upsilondieresis',
    '03CC' => 'omicrontonos',
    '03CD' => 'upsilontonos',
    '03CE' => 'omegatonos',
    '03D1' => 'theta1',
    '03D2' => 'Upsilon1',
    '03D5' => 'phi1',
    '03D6' => 'omega1',
    '0401' => 'afii10023',
    '0402' => 'afii10051',
    '0403' => 'afii10052',
    '0404' => 'afii10053',
    '0405' => 'afii10054',
    '0406' => 'afii10055',
    '0407' => 'afii10056',
    '0408' => 'afii10057',
    '0409' => 'afii10058',
    '040A' => 'afii10059',
    '040B' => 'afii10060',
    '040C' => 'afii10061',
    '040E' => 'afii10062',
    '040F' => 'afii10145',
    '0410' => 'afii10017',
    '0411' => 'afii10018',
    '0412' => 'afii10019',
    '0413' => 'afii10020',
    '0414' => 'afii10021',
    '0415' => 'afii10022',
    '0416' => 'afii10024',
    '0417' => 'afii10025',
    '0418' => 'afii10026',
    '0419' => 'afii10027',
    '041A' => 'afii10028',
    '041B' => 'afii10029',
    '041C' => 'afii10030',
    '041D' => 'afii10031',
    '041E' => 'afii10032',
    '041F' => 'afii10033',
    '0420' => 'afii10034',
    '0421' => 'afii10035',
    '0422' => 'afii10036',
    '0423' => 'afii10037',
    '0424' => 'afii10038',
    '0425' => 'afii10039',
    '0426' => 'afii10040',
    '0427' => 'afii10041',
    '0428' => 'afii10042',
    '0429' => 'afii10043',
    '042A' => 'afii10044',
    '042B' => 'afii10045',
    '042C' => 'afii10046',
    '042D' => 'afii10047',
    '042E' => 'afii10048',
    '042F' => 'afii10049',
    '0430' => 'afii10065',
    '0431' => 'afii10066',
    '0432' => 'afii10067',
    '0433' => 'afii10068',
    '0434' => 'afii10069',
    '0435' => 'afii10070',
    '0436' => 'afii10072',
    '0437' => 'afii10073',
    '0438' => 'afii10074',
    '0439' => 'afii10075',
    '043A' => 'afii10076',
    '043B' => 'afii10077',
    '043C' => 'afii10078',
    '043D' => 'afii10079',
    '043E' => 'afii10080',
    '043F' => 'afii10081',
    '0440' => 'afii10082',
    '0441' => 'afii10083',
    '0442' => 'afii10084',
    '0443' => 'afii10085',
    '0444' => 'afii10086',
    '0445' => 'afii10087',
    '0446' => 'afii10088',
    '0447' => 'afii10089',
    '0448' => 'afii10090',
    '0449' => 'afii10091',
    '044A' => 'afii10092',
    '044B' => 'afii10093',
    '044C' => 'afii10094',
    '044D' => 'afii10095',
    '044E' => 'afii10096',
    '044F' => 'afii10097',
    '0451' => 'afii10071',
    '0452' => 'afii10099',
    '0453' => 'afii10100',
    '0454' => 'afii10101',
    '0455' => 'afii10102',
    '0456' => 'afii10103',
    '0457' => 'afii10104',
    '0458' => 'afii10105',
    '0459' => 'afii10106',
    '045A' => 'afii10107',
    '045B' => 'afii10108',
    '045C' => 'afii10109',
    '045E' => 'afii10110',
    '045F' => 'afii10193',
    '0462' => 'afii10146',
    '0463' => 'afii10194',
    '0472' => 'afii10147',
    '0473' => 'afii10195',
    '0474' => 'afii10148',
    '0475' => 'afii10196',
    '0490' => 'afii10050',
    '0491' => 'afii10098',
    '04D9' => 'afii10846',
    '05B0' => 'afii57799',
    '05B1' => 'afii57801',
    '05B2' => 'afii57800',
    '05B3' => 'afii57802',
    '05B4' => 'afii57793',
    '05B5' => 'afii57794',
    '05B6' => 'afii57795',
    '05B7' => 'afii57798',
    '05B8' => 'afii57797',
    '05B9' => 'afii57806',
    '05BB' => 'afii57796',
    '05BC' => 'afii57807',
    '05BD' => 'afii57839',
    '05BE' => 'afii57645',
    '05BF' => 'afii57841',
    '05C0' => 'afii57842',
    '05C1' => 'afii57804',
    '05C2' => 'afii57803',
    '05C3' => 'afii57658',
    '05D0' => 'afii57664',
    '05D1' => 'afii57665',
    '05D2' => 'afii57666',
    '05D3' => 'afii57667',
    '05D4' => 'afii57668',
    '05D5' => 'afii57669',
    '05D6' => 'afii57670',
    '05D7' => 'afii57671',
    '05D8' => 'afii57672',
    '05D9' => 'afii57673',
    '05DA' => 'afii57674',
    '05DB' => 'afii57675',
    '05DC' => 'afii57676',
    '05DD' => 'afii57677',
    '05DE' => 'afii57678',
    '05DF' => 'afii57679',
    '05E0' => 'afii57680',
    '05E1' => 'afii57681',
    '05E2' => 'afii57682',
    '05E3' => 'afii57683',
    '05E4' => 'afii57684',
    '05E5' => 'afii57685',
    '05E6' => 'afii57686',
    '05E7' => 'afii57687',
    '05E8' => 'afii57688',
    '05E9' => 'afii57689',
    '05EA' => 'afii57690',
    '05F0' => 'afii57716',
    '05F1' => 'afii57717',
    '05F2' => 'afii57718',
    '060C' => 'afii57388',
    '061B' => 'afii57403',
    '061F' => 'afii57407',
    '0621' => 'afii57409',
    '0622' => 'afii57410',
    '0623' => 'afii57411',
    '0624' => 'afii57412',
    '0625' => 'afii57413',
    '0626' => 'afii57414',
    '0627' => 'afii57415',
    '0628' => 'afii57416',
    '0629' => 'afii57417',
    '062A' => 'afii57418',
    '062B' => 'afii57419',
    '062C' => 'afii57420',
    '062D' => 'afii57421',
    '062E' => 'afii57422',
    '062F' => 'afii57423',
    '0630' => 'afii57424',
    '0631' => 'afii57425',
    '0632' => 'afii57426',
    '0633' => 'afii57427',
    '0634' => 'afii57428',
    '0635' => 'afii57429',
    '0636' => 'afii57430',
    '0637' => 'afii57431',
    '0638' => 'afii57432',
    '0639' => 'afii57433',
    '063A' => 'afii57434',
    '0640' => 'afii57440',
    '0641' => 'afii57441',
    '0642' => 'afii57442',
    '0643' => 'afii57443',
    '0644' => 'afii57444',
    '0645' => 'afii57445',
    '0646' => 'afii57446',
    '0647' => 'afii57470',
    '0648' => 'afii57448',
    '0649' => 'afii57449',
    '064A' => 'afii57450',
    '064B' => 'afii57451',
    '064C' => 'afii57452',
    '064D' => 'afii57453',
    '064E' => 'afii57454',
    '064F' => 'afii57455',
    '0650' => 'afii57456',
    '0651' => 'afii57457',
    '0652' => 'afii57458',
    '0660' => 'afii57392',
    '0661' => 'afii57393',
    '0662' => 'afii57394',
    '0663' => 'afii57395',
    '0664' => 'afii57396',
    '0665' => 'afii57397',
    '0666' => 'afii57398',
    '0667' => 'afii57399',
    '0668' => 'afii57400',
    '0669' => 'afii57401',
    '066A' => 'afii57381',
    '066D' => 'afii63167',
    '0679' => 'afii57511',
    '067E' => 'afii57506',
    '0686' => 'afii57507',
    '0688' => 'afii57512',
    '0691' => 'afii57513',
    '0698' => 'afii57508',
    '06A4' => 'afii57505',
    '06AF' => 'afii57509',
    '06BA' => 'afii57514',
    '06D2' => 'afii57519',
    '06D5' => 'afii57534',
    '1E80' => 'Wgrave',
    '1E81' => 'wgrave',
    '1E82' => 'Wacute',
    '1E83' => 'wacute',
    '1E84' => 'Wdieresis',
    '1E85' => 'wdieresis',
    '1EF2' => 'Ygrave',
    '1EF3' => 'ygrave',
    '200C' => 'afii61664',
    '200D' => 'afii301',
    '200E' => 'afii299',
    '200F' => 'afii300',
    '2012' => 'figuredash',
    '2013' => 'endash',
    '2014' => 'emdash',
    '2015' => 'afii00208',
    '2017' => 'underscoredbl',
    '2018' => 'quoteleft',
    '2019' => 'quoteright',
    '201A' => 'quotesinglbase',
    '201B' => 'quotereversed',
    '201C' => 'quotedblleft',
    '201D' => 'quotedblright',
    '201E' => 'quotedblbase',
    '2020' => 'dagger',
    '2021' => 'daggerdbl',
    '2022' => 'bullet',
    '2024' => 'onedotenleader',
    '2025' => 'twodotenleader',
    '2026' => 'ellipsis',
    '202C' => 'afii61573',
    '202D' => 'afii61574',
    '202E' => 'afii61575',
    '2030' => 'perthousand',
    '2032' => 'minute',
    '2033' => 'second',
    '2039' => 'guilsinglleft',
    '203A' => 'guilsinglright',
    '203C' => 'exclamdbl',
    '2044' => 'fraction',
    '2070' => 'zerosuperior',
    '2074' => 'foursuperior',
    '2075' => 'fivesuperior',
    '2076' => 'sixsuperior',
    '2077' => 'sevensuperior',
    '2078' => 'eightsuperior',
    '2079' => 'ninesuperior',
    '207D' => 'parenleftsuperior',
    '207E' => 'parenrightsuperior',
    '207F' => 'nsuperior',
    '2080' => 'zeroinferior',
    '2081' => 'oneinferior',
    '2082' => 'twoinferior',
    '2083' => 'threeinferior',
    '2084' => 'fourinferior',
    '2085' => 'fiveinferior',
    '2086' => 'sixinferior',
    '2087' => 'seveninferior',
    '2088' => 'eightinferior',
    '2089' => 'nineinferior',
    '208D' => 'parenleftinferior',
    '208E' => 'parenrightinferior',
    '20A1' => 'colonmonetary',
    '20A3' => 'franc',
    '20A4' => 'lira',
    '20A7' => 'peseta',
    '20AA' => 'afii57636',
    '20AB' => 'dong',
    '20AC' => 'Euro',
    '2105' => 'afii61248',
    '2111' => 'Ifraktur',
    '2113' => 'afii61289',
    '2116' => 'afii61352',
    '2118' => 'weierstrass',
    '211C' => 'Rfraktur',
    '211E' => 'prescription',
    '2122' => 'trademark',
    '2126' => 'Omega',
    '212E' => 'estimated',
    '2135' => 'aleph',
    '2153' => 'onethird',
    '2154' => 'twothirds',
    '215B' => 'oneeighth',
    '215C' => 'threeeighths',
    '215D' => 'fiveeighths',
    '215E' => 'seveneighths',
    '2190' => 'arrowleft',
    '2191' => 'arrowup',
    '2192' => 'arrowright',
    '2193' => 'arrowdown',
    '2194' => 'arrowboth',
    '2195' => 'arrowupdn',
    '21A8' => 'arrowupdnbse',
    '21B5' => 'carriagereturn',
    '21D0' => 'arrowdblleft',
    '21D1' => 'arrowdblup',
    '21D2' => 'arrowdblright',
    '21D3' => 'arrowdbldown',
    '21D4' => 'arrowdblboth',
    '2200' => 'universal',
    '2202' => 'partialdiff',
    '2203' => 'existential',
    '2205' => 'emptyset',
    '2206' => 'Delta',
    '2207' => 'gradient',
    '2208' => 'element',
    '2209' => 'notelement',
    '220B' => 'suchthat',
    '220F' => 'product',
    '2211' => 'summation',
    '2212' => 'minus',
    '2215' => 'fraction',
    '2217' => 'asteriskmath',
    '2219' => 'periodcentered',
    '221A' => 'radical',
    '221D' => 'proportional',
    '221E' => 'infinity',
    '221F' => 'orthogonal',
    '2220' => 'angle',
    '2227' => 'logicaland',
    '2228' => 'logicalor',
    '2229' => 'intersection',
    '222A' => 'union',
    '222B' => 'integral',
    '2234' => 'therefore',
    '223C' => 'similar',
    '2245' => 'congruent',
    '2248' => 'approxequal',
    '2260' => 'notequal',
    '2261' => 'equivalence',
    '2264' => 'lessequal',
    '2265' => 'greaterequal',
    '2282' => 'propersubset',
    '2283' => 'propersuperset',
    '2284' => 'notsubset',
    '2286' => 'reflexsubset',
    '2287' => 'reflexsuperset',
    '2295' => 'circleplus',
    '2297' => 'circlemultiply',
    '22A5' => 'perpendicular',
    '22C5' => 'dotmath',
    '2302' => 'house',
    '2310' => 'revlogicalnot',
    '2320' => 'integraltp',
    '2321' => 'integralbt',
    '2329' => 'angleleft',
    '232A' => 'angleright',
    '2500' => 'SF100000',
    '2502' => 'SF110000',
    '250C' => 'SF010000',
    '2510' => 'SF030000',
    '2514' => 'SF020000',
    '2518' => 'SF040000',
    '251C' => 'SF080000',
    '2524' => 'SF090000',
    '252C' => 'SF060000',
    '2534' => 'SF070000',
    '253C' => 'SF050000',
    '2550' => 'SF430000',
    '2551' => 'SF240000',
    '2552' => 'SF510000',
    '2553' => 'SF520000',
    '2554' => 'SF390000',
    '2555' => 'SF220000',
    '2556' => 'SF210000',
    '2557' => 'SF250000',
    '2558' => 'SF500000',
    '2559' => 'SF490000',
    '255A' => 'SF380000',
    '255B' => 'SF280000',
    '255C' => 'SF270000',
    '255D' => 'SF260000',
    '255E' => 'SF360000',
    '255F' => 'SF370000',
    '2560' => 'SF420000',
    '2561' => 'SF190000',
    '2562' => 'SF200000',
    '2563' => 'SF230000',
    '2564' => 'SF470000',
    '2565' => 'SF480000',
    '2566' => 'SF410000',
    '2567' => 'SF450000',
    '2568' => 'SF460000',
    '2569' => 'SF400000',
    '256A' => 'SF540000',
    '256B' => 'SF530000',
    '256C' => 'SF440000',
    '2580' => 'upblock',
    '2584' => 'dnblock',
    '2588' => 'block',
    '258C' => 'lfblock',
    '2590' => 'rtblock',
    '2591' => 'ltshade',
    '2592' => 'shade',
    '2593' => 'dkshade',
    '25A0' => 'filledbox',
    '25A1' => 'H22073',
    '25AA' => 'H18543',
    '25AB' => 'H18551',
    '25AC' => 'filledrect',
    '25B2' => 'triagup',
    '25BA' => 'triagrt',
    '25BC' => 'triagdn',
    '25C4' => 'triaglf',
    '25CA' => 'lozenge',
    '25CB' => 'circle',
    '25CF' => 'H18533',
    '25D8' => 'invbullet',
    '25D9' => 'invcircle',
    '25E6' => 'openbullet',
    '263A' => 'smileface',
    '263B' => 'invsmileface',
    '263C' => 'sun',
    '2640' => 'female',
    '2642' => 'male',
    '2660' => 'spade',
    '2663' => 'club',
    '2665' => 'heart',
    '2666' => 'diamond',
    '266A' => 'musicalnote',
    '266B' => 'musicalnotedbl',
    'FB00' => 'ff',
    'FB01' => 'fi',
    'FB02' => 'fl',
    'FB03' => 'ffi',
    'FB04' => 'ffl',
    'FB1F' => 'afii57705',
    'FB2A' => 'afii57694',
    'FB2B' => 'afii57695',
    'FB35' => 'afii57723',
    'FB4B' => 'afii57700',
);

%doubles = (map{$_ => "uni$_"} qw(0394 03A9 0162 2215 00AD 02C9 03BC 2219 00A0 0163));

sub lookup
{
    my ($num, $noalt) = @_;
    my ($val) = sprintf("%04X", $num);

    if (defined $names{$val})
    {
        return $names{$val} if ($noalt);
        return $doubles{$val} || $names{$val};
    }
    elsif ($num > 0xFFFF)
    { return "u$val"; }
    elsif ($num)
    { return "uni$val"; }
    else
    { return ".notdef"; }
}

1;
