#!/usr/local/bin/perl

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

Copyright 2004 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
