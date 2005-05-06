#!/usr/local/bin/perl

use inc::Module::Install;

name		('PDF-FromHTML');
author		('Autrijus Tang <autrijus@autrijus.org>');
abstract	('Convert HTML documents to PDF');
license		('perl');
version_from	('lib/PDF/FromHTML.pm');
install_script  ('script/html2pdf.pl');

eval { require PDF::Template; $INC{'PDF/Writer.pm'} } or
    die << '.';

This module requires a 'developer release' modules on CPAN:

    http://search.cpan.org/dist/PDF-Template-PDFAPI2/

Please install it by downloading manually, because CPAN.pm
may not be able to find it.

Also, if you cannot install HTML::Tidy, you may use the XML::Clean
module instead; however, you will run probably run into more
"XML not well-formed" errors that way.

.

requires(qw(
    perl                    5.6.1
    List::Util              0
    XML::Twig               0
    HTML::Tidy              0
    Graphics::ColorNames    0
    LWP::Simple             0
    Image::Size             0
    PDF::Writer             0.03
    PDF::API2               0.40
    PDF::Template           0.18
));

WriteAll( sign => 1 );
