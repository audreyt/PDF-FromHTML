#!/usr/local/bin/perl

use inc::Module::Install;

name		('PDF-FromHTML');
author		('Autrijus Tang <autrijus@autrijus.org>');
abstract	('Convert HTML documents to PDF');
license		('perl');
version_from	('lib/PDF/FromHTML.pm');
install_script  ('script/html2pdf.pl');

my @requires = qw(
    perl                    5.6.1
    List::Util              0
    XML::Twig               0
    Graphics::ColorNames    0
    LWP::Simple             0
    Image::Size             0
    PDF::Writer             0.05
    PDF::Template           0.30
);

unless (eval { require PDF::API2; 1 } or eval { require pdflib_pl; 1 }) {
    push @require, ('PDF::API2' => 0);
    print << '.';
*** If you cannot install PDF::API2, you may use the pdflib_pl
    module instead, available as a separate download on PDFLib homepage.
.
}

unless (eval { require HTML::Tidy; 1 } or eval { require XML::Clean; 1 }) {
    push @requires, ('HTML::Tidy' => 0);

    print << '.';
*** If you cannot install HTML::Tidy, you may use the XML::Clean
    module instead; however, you will run probably run into more
    "XML not well-formed" errors that way.
.
}

requires(@requires);
WriteAll( sign => 1 );
