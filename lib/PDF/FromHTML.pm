package PDF::FromHTML;
$PDF::FromHTML::VERSION = '0.05';

use strict;
use warnings;

BEGIN {
    foreach my $method ( qw( pdf twig tidy args ) ) {
        no strict 'refs';
        *$method = sub { $#_ ? ($_[0]{$method} = $_[1]) : $_[0]{$method} };
    }
}

use Cwd;
use File::Temp;
use File::Basename;

use PDF::Writer 'pdfapi2';
use PDF::Template;
use PDF::FromHTML::Twig;

=head1 NAME

PDF::FromHTML - Convert HTML documents to PDF

=head1 VERSION

This document describes version 0.05 of PDF::FromHTML, released 
November 18, 2004.

=head1 SYNOPSIS

    my $pdf = PDF::FromHTML->new( encoding => 'utf-8' );
    $pdf->load_file('source.html');
    $pdf->convert(
        Font => '/path/to/font.ttf',
        LineHeight => 10,
        Landscape => 1,
    );
    $pdf->write_file('target.pdf');

=head1 DESCRIPTION

This module transforms HTML into PDF, using an assortment of XML
transformations implemented in L<PDF::FromHTML::Twig>.

There is also a command-line utility, L<html2pdf.pl>, that comes
with this distribution.

More documentation is expected soon.

=cut

sub new {
    my $class = shift;
    bless({
        twig => PDF::FromHTML::Twig->new,
        tidy => eval { require HTML::Tidy; HTML::Tidy->new },
        args => { @_ },
    }, $class);
}

sub load_file {
    my ($self, $file) = @_;
    $self->{file} = $file;
}

sub parse_file {
    my $self = shift;
    my $file = $self->{file};
    my $content = '';

    my $dir = Cwd::getcwd();

    if (!ref $file) {
        open my $fh, $file or die $!;
        chdir File::Basename::dirname($file);
        $content = do { local $/; <$fh> };
    }
    else {
        $content = $$file;
    }

    if (my $encoding = ($self->args->{encoding} || 'utf8') and $] >= 5.007003) {
        require Encode;
        $content = Encode::decode($encoding, $content, Encode::FB_XMLCREF());
    }

    $content =~ s{&nbsp;}{}g;
    $content =~ s{<!--.*?-->}{}gs;

    if (my $tidy = $self->tidy) {
        if ($] >= 5.007003) {
            $content = Encode::encode( ascii => $content, Encode::FB_XMLCREF());
        }
        $content = $self->tidy->clean(
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<html xmlns="http://www.w3.org/1999/xhtml">',
            $content,
        );
    }
    else {
        require XML::Clean;
        $content =~ s{&#(\d+);}{chr $1}eg;
        $content =~ s{&#x([\da-fA-F]+);}{chr hex $1}eg;
        $content = XML::Clean::clean($content, '1.0', { encoding => 'UTF-8' });
        $content =~ s{<(/?\w+)}{<\L$1}g;
    }

    $self->twig->parse( $content );

    chdir $dir;
}

sub convert {
    my ($self, %args) = @_;

    {
        # import arguments into Twig parameters
        no strict 'refs';
        ${"PDF::FromHTML::Twig::$_"} = $args{$_} foreach keys %args;
    }

    $self->parse_file;

    my ($fh, $filename) = File::Temp::tempfile(
        SUFFIX => '.xml',
        UNLINK => 1,
    );

    binmode($fh, ($] >= 5.007003) ? (':utf8') : ());

    # print STDERR "==> Temp file written to $filename\n";
    print $fh $self->twig->sprint;
    close $fh;

    local $^W;
    $self->pdf(eval { PDF::Template->new( filename => $filename ) })
      or die "$filename: $@";
    $self->pdf->param(@_);
}

sub write_file {
    my $self = shift;
    local $^W;
    $self->pdf->write_file(@_);
}

1;

=head1 SEE ALSO

L<PDF::FromHTML::Twig>, L<PDF::Template>, L<XML::Twig>.

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
