package PDF::FromHTML::Twig;

use strict;
use warnings;
use base 'XML::Twig';

use charnames ':full';
use Graphics::ColorNames qw( hex2tuple );
use File::Spec;
use File::Basename;
use List::Util qw( sum first reduce );

=head1 NAME

PDF::FromHTML::Twig - PDF::FromHTML guts

=head1 SYNOPSIS

(internal use only)

=head1 DESCRIPTION

No user-serviceable parts inside.

=cut

sub new {
    my $class = shift;
    return $class->SUPER::new( $class->TwigArguments, @_ );
}

our $PageWidth = 640;
our $PageResolution = 540;
our $FontBold = 'HelveticaBold';
our $FontOblique = 'HelveticaOblique';
our $FontBoldOblique = 'HelveticaBoldOblique';
our $LineHeight = 12;
our $FontUnicode = 'Helvetica';
our $Font = $FontUnicode;
# $Font = '/usr/local/share/fonts/TrueType/minguni.ttf';

our $PageSize = 'A4';
our $Landscape = 0;
use constant SuperScript => [
    "\N{SUPERSCRIPT ZERO}",  "\N{SUPERSCRIPT ONE}",   "\N{SUPERSCRIPT TWO}",
    "\N{SUPERSCRIPT THREE}", "\N{SUPERSCRIPT FOUR}",  "\N{SUPERSCRIPT FIVE}",
    "\N{SUPERSCRIPT SIX}",   "\N{SUPERSCRIPT SEVEN}", "\N{SUPERSCRIPT EIGHT}",
    "\N{SUPERSCRIPT NINE}",
];
use constant SubScript => [
    "\N{SUBSCRIPT ZERO}",    "\N{SUBSCRIPT ONE}",     "\N{SUBSCRIPT TWO}",
    "\N{SUBSCRIPT THREE}",   "\N{SUBSCRIPT FOUR}",    "\N{SUBSCRIPT FIVE}",
    "\N{SUBSCRIPT SIX}",     "\N{SUBSCRIPT SEVEN}",   "\N{SUBSCRIPT EIGHT}",
    "\N{SUBSCRIPT NINE}",
];
use constant InlineTags => { map {$_ => 1} '#PCDATA', 'font' };
use constant DeleteTags => { map {$_ => 1} qw(
    head style applet script
) };
use constant IgnoreTags => { map {$_ => 1} qw(
    title a ul

    del address blockquote colgroup fieldset
    input form frameset object noframes noscript
    small optgroup isindex area textarea col
    pre frame param menu acronym abbr bdo
    label basefont big caption option cite
    dd dfn dt base code map iframe ins kbd legend
    samp span dir strike meta link tbody q tfoot
    button thead var tt select s 
) };
use constant TwigArguments => (
    twig_handlers => {
        html => sub {
            $_->del_atts;
            $_->set_gi( 'pdftemplate' );
        },
        map(("h$_" => (sub {
            my $size = shift;
            sub {
                $_->insert_new_elt( before => 'textbox' )
                  ->wrap_in('row')
                  ->wrap_in( font => { face => $FontBold } );
                $_->wrap_in(font => { h => $LineHeight + 6 - $size });
                $_->wrap_in(row => { h => $LineHeight + 8 - $size });
                $_->set_tag('textbox'),
                $_->set_att( w => '100%' );
            };
        })->($_)), 1..6),
        center => sub {
            foreach my $child ($_->children('p')) {
                # XXX - revert other blocklevel to left/original alignment
                $child->set_att( align => 'center' );
            }
            $_->erase;
        },
        sup => sub {
            my $digits = $_->text;
            my $text = '';
            $text .= +SuperScript->[$1] while $digits =~ s/(\d)//;
            $_->set_text($text);
            $_->erase;
        },
        sub => sub {
            my $digits = $_->text;
            my $text = '';
            $text .= +SubScript->[$1] while $digits =~ s/(\d)//;
            $_->set_text($text);
            $_->erase;
        },
        u => sub {
            _set(underline => 1, $_);
            $_->erase;
        },
        em => sub {
            _set(font => $FontOblique, $_);
            $_->erase;
        },
        i => sub {
            _set(font => $FontOblique, $_);
            $_->erase;
        },
        strong => sub {
            _set(font => $FontBold, $_);
            $_->erase;
        },
        b => sub {
            _set(font => $FontBold, $_);
            $_->erase;
        },
        div => sub {
            if (my $tag = (_type(header => $_) || _type(footer => $_))) {
                $_->set_tag($tag);
                $_->set_att(
                    "${tag}_height" => int(sum(
                        $LineHeight * 2,
                        grep defined, map $_->att('h'), $_->descendants
                    )),
                );
            }
            else {
                $_->erase;
            }
        },
        hr => sub {
            $_->insert_new_elt( first_child => (_type(pagebreak => $_) || 'hr') );
            $_->erase;
        },
        img => sub {
            my $file = File::Spec->rel2abs($_->att('src'));
            my $image = $_->insert_new_elt(first_child => image => {
                filename => $file,
                w => ($_->att('width') / $PageWidth * $PageResolution),
                h => ($_->att('height') / $PageWidth * $PageResolution),
                type => '',
            } );
            $image->wrap_in('row');
            $_->erase;
        },
        body => sub {
            # XXX make pagedef into parameters
            if ($Landscape) {
                require PDF::Template;
                $PageSize = 'A4LANDSCAPE';
                $PDF::Template::Constants::Verify{PAGESIZE}{__DEFAULT__} = 'A4LANDSCAPE';
                $PDF::Template::Constants::Verify{PAGESIZE}{A4LANDSCAPE} = {
                    PAGE_WIDTH => 842,
                    PAGE_HEIGHT => 595,
                };
            }

            $_->wrap_in(
                pagedef => {
                    pagesize => $PageSize,
                    landscape => $Landscape,
                    margins => $LineHeight - 2,
                },
            );
            $_->wrap_in(
                font => {
                    face => $Font,
                    h => $LineHeight - 2,
                }
            );
            my $pagedef = $_->parent->parent;
            my $head = ($pagedef->descendants('header'))[0] || $pagedef->insert_new_elt(
                first_child => header => { header_height => $LineHeight * 2 }
            );
            my $row = $head->insert_new_elt(first_child => 'row');
            $row->insert_new_elt(first_child => textbox => { w => '100%', text => '' });
            foreach my $child ($_->children('#PCDATA')) {
                $child->set_text(join(' ', grep length, split(/\n+/, $child->text)));
                if ($child->text =~ /[^\x00-\x7f]/) {
                    $child->wrap_in(font => { face => $FontUnicode });
                }
                $child->wrap_in('row');
                $child->wrap_in(textbox => { w => '100%' });
                $child->insert_new_elt( after => 'textbox' )->wrap_in('row');
            }

            $_->erase;
        },
        p => \&_p,
        li => \&_p,
        table => sub {
            $_->root->del_att('#widths');
            $_->insert_new_elt(last_child => row => { h => $LineHeight });
            $_->erase;
        },
        ol => sub {
            my $count = 1;
            foreach my $child ($_->descendants('counter')) {
                $child->set_tag('textbox');
                $child->set_text("$count. ");
                $count++;
            }
            $_->insert_new_elt(last_child => row => { h => $LineHeight });
            $_->erase;
        },
        br => sub {
            $_->insert_new_elt(last_child => row => { h => $LineHeight });
            $_->erase;
        },
        ul => sub {
            foreach my $child ($_->descendants('counter')) {
                $child->set_tag('textbox');
                $child->set_text("* ");
            }
            $_->insert_new_elt(last_child => row => { h => $LineHeight });
            $_->erase;
        },
        dl => sub {
            foreach my $child ($_->descendants('counter')) {
                $child->delete;
            }
            $_->insert_new_elt(last_child => row => { h => $LineHeight });
            $_->erase;
        },
        tr => sub {
            return $_->erase if $_->descendants('row');

            our @RowSpan;
            foreach my $cell (reverse @{ shift(@RowSpan) || [] }) {
                $_->insert_new_elt( first_child => 'textbox', $cell )
            }

            my @children = $_->descendants('textbox');
            my $cols = sum( map { $_->att('colspan') || 1 } @children );
            # print STDERR "==> Total cols: $cols :".@children.$/;

            my $widths = $_->root->att('#widths') || [];
            my $width = $_->att('w') || ($widths->[$_->pos] ||= (
                int(_percentify($_->parent('table')->att('width'))
                    / $cols )
            ));

            my $sum = 100;
            my $last_child = pop(@children);
            foreach my $child (@children) {
                my $w = ($width * ($child->att('colspan') || 1));
                $child->set_att( w => "$w%" );
                $sum -= $w;
            }

            $last_child->set_att( w => "$sum%" ) if $last_child;

            $_->set_tag('row');
            $_->set_att(lmargin => '3');
            $_->set_att(rmargin => '3');
            $_->set_att(border => $_->parent('table')->att('border'));
        },
        td => \&_td,
        th => \&_td,
        font => sub {
            $_->del_att('face');

            if ($_->att_names) {
                $_->set_att(face => $Font);
                $_->erase; # XXX
            }
            else {
                $_->erase;
            }
        },
        _default_ => sub {
            $_->erase if +IgnoreTags->{$_->tag};
            $_->delete if +DeleteTags->{$_->tag};
        }
    },
    pretty_print => 'indented',
    empty_tags   => 'html',
    start_tag_handlers => {
        _all_ => sub {
            if (my $w = $_->att('width') and 0) {
                $_->set_att(w => $w);
                my $widths = $_->root->att('#widths') || [];
                $widths->[$_->pos] = $w;
                $_->root->set_att('#widths' => $widths);
            }
            if (my $h = $_->att('size')) {
                $_->set_att(h => $LineHeight + (2 * ($h - 4)));
            }
            if (my $bgcolor = $_->att('bgcolor')) {
                $_->set_att( bgcolor => _to_color($bgcolor) );
            }
            $_->del_att(qw(
                color bordercolor bordercolordark bordercolorlight
                cellpadding cellspacing size href
            ));
        },
    }
);


sub _set {
    my ($key, $value, $elt) = @_;
    my $att = $elt->root->att("#$key") || {};
    $att->{$elt->parent} = $value;
    $elt->root->set_att("#$key", $att);
}

sub _get {
    my ($key, $elt) = @_;
    my $att = $elt->root->att("#$key") || {};
    return $att->{$elt};
}

sub _p {
    my @children;
    foreach my $child ($_->children) {
        +InlineTags->{$child->tag} or last;
        push @children, $child->cut;
    }

    if (@children) {
        my $textbox = $_->insert_new_elt(
            before => textbox => {
                w => (($_->tag eq 'p') ? '100%' : '97%'),
                align => $_->att('align')
            },
        );
        $textbox->wrap_in('row');
        if ($_->tag eq 'li') {
            $textbox->insert_new_elt(
                before => counter => { w => '3%', align => 'right' }
            );
        }
        foreach my $child (@children) {
            $child->paste( last_child => $textbox );
            $child->set_text(
                join(' ', grep {length and $_ ne 1} split(/\n+/, $child->text))
            );
        }

        my $font = _get(font => $_);

        if ($textbox->text =~ /[^\x00-\x7f]/) {
            $font = $FontUnicode;
        }
        elsif ($_->parent('i') and $_->parent('b')) {
            $font ||= $FontBoldOblique;
        }
        elsif ($_->parent('i')) {
            $font ||= $FontOblique;
        }
        elsif ($_->parent('b')) {
            $font ||= $FontBold;
        }

        my %attr;
        $attr{face} = $font if $font;
        if (_get(underline => $_)) {
            my $align = $textbox->att('align');
            $align .= '_underline';
            $textbox->del_att('align');

            require PDF::Template::Constants;
            $PDF::Template::Constants::Verify{ALIGN}{$align} = 1
              if %PDF::Template::Constants::Verify;
            $attr{align} = $align;
        }

        $textbox->wrap_in('font' => \%attr) if %attr;
    }

    $_->insert_new_elt( first_child => 'textbox' )->wrap_in('row') if $_->tag eq 'p';
    $_->erase;
}

sub _td {
    return $_->erase if $_->descendants('row');

    $_->set_tag('textbox');

    if (my $font = _get(font => $_)) {
        $_->wrap_in( font => { face => $font } );
    }

    if (my $rowspan = $_->att('rowspan')) {
        # ok, we can't really do this.
        # what we can do, though, is to add 'fake' cells in the next row.
        our @RowSpan;
        foreach my $i (1..($rowspan-1)) {
            push @{ $RowSpan[$i] }, $_->atts;
        }
    }
}

sub _percentify {
    my $num = shift;
    return $1 if $num =~ /(\d+)%/;
    return int($num / $PageWidth * 100);
}

sub _type {
    my ($val, $elt) = @_;
    return first { $_ eq $val } grep defined, map $elt->att($_), qw(type class);
}

sub _to_color {
    my ($color) = @_;

    if ($color !~ s/^#//) {
        $color = Graphics::ColorNames->new('Netscape')->hex($color);
    }

    return join ',', hex2tuple($color);
}

1;

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
