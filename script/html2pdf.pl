#!/usr/local/bin/perl

use strict;
use warnings;
use PDF::FromHTML;

=head1 NAME

html2pdf.pl - Turn HTML to PDF

=head1 SYNOPSIS

    % html2pdf.pl source.html > target.pdf

=cut

my $pdf = PDF::FromHTML->new(
    encoding    => 'utf-8',
);

local $SIG{__DIE__} = sub { require Carp; Carp::confess(@_) };

$pdf->load_file(shift || '-');
$pdf->convert(
#   Font        => 'traditional',
#   LineHeight  => 11,
#   Landscape   => 1,
);
#open X, '>/tmp/x';
#print X $pdf->twig->sprint;
#close X;
$pdf->write_file(shift || '-');

1;

__END__

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

=head1 COPYRIGHT

Copyright 2004, 2005, 2006, 2007 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

This software is released under the MIT license cited below.

=head2 The "MIT" License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

=cut
