#!/usr/local/bin/perl

use inc::Module::Install;

name		('PDF-FromHTML');
author		('Autrijus Tang <autrijus@autrijus.org>');
abstract	('Convert HTML documents to PDF');
license		('perl');
version_from	('lib/PDF/FromHTML.pm');
install_script  ('script/html2pdf.pl');

eval { require PDF::API2; PDF::API2->VERSION ge '0.40_52' } and
eval { require PDF::Template; $INC{'PDF/Writer.pm'} } or
    die << '.';

This module requires two 'developer release' modules on CPAN:

    http://search.cpan.org/dist/PDF-API2/
    http://search.cpan.org/dist/PDF-Template-PDFAPI2/

Please install them by downloading manually, because CPAN.pm
may not be able to find them.

.

requires(
    'XML::Twig'     => undef,
    'XML::Clean'    => undef,
    'Hook::LexWrap' => undef,
    'Color::Rgb'    => undef,
    'PDF::Writer'   => '0.03',
    'PDF::API2'     => '0.40_52',
    'PDF::Template' => '0.18',
);

WriteAll( sign => 1 );
