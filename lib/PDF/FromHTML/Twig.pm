package PDF::FromHTML::Twig;

use strict;
use XML::Twig;
use base 'XML::Twig';
use Color::Rgb;
use File::Spec;
use File::Basename;

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

use constant FontBold => 'HelveticaBold';
use constant FontOblique => 'HelveticaOblique';
use constant FontBoldOblique => 'HelveticaBoldOblique';
use constant FontUnicode => do {
    my $font = '/usr/X11R6/lib/X11/fonts/webfonts/arialuni.ttf';
    (-e $font) ? $font : 'Helvetica';
};
use constant Font => +FontUnicode;

use constant InlineTags => { map {$_ => 1} qw(
    #PCDATA font
) };
use constant DeleteTags => { map {$_ => 1} qw(
    head style
) };
use constant IgnoreTags => { map {$_ => 1} qw(
    title center u a ul
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
                $_->insert_new_elt( before => 'textbox' )->wrap_in('row');
                $_->wrap_in(font => { h => 17 - $size });
                $_->wrap_in(row => { h => 19 - $size });
                $_->set_tag('textbox'),
                $_->set_att( w => '100%' );
            };
        })->($_)), 1..6),
        sup => sub {
            #$_->set_tag('font');
            #$_->set_att( h => 8 );
            if ($] < 5.008) { require Encode::compat };
            require Encode;

            my $digits = $_->text;
            my $text = '';

            use charnames ':full';
            my @chars = (
                "\N{SUPERSCRIPT ZERO}",
                "\N{SUPERSCRIPT ONE}",
                "\N{SUPERSCRIPT TWO}",
                "\N{SUPERSCRIPT THREE}",
                "\N{SUPERSCRIPT FOUR}",
                "\N{SUPERSCRIPT FIVE}",
                "\N{SUPERSCRIPT SIX}",
                "\N{SUPERSCRIPT SEVEN}",
                "\N{SUPERSCRIPT EIGHT}",
                "\N{SUPERSCRIPT NINE}",
            );

            while ($digits =~ s/(\d)//) {
                $text .= $chars[$1];
            }

            $_->set_text($text);
            $_->erase;
        },
        i => sub {
            my $fonts = $_->root->att('#fonts') || {};
            $fonts->{$_->parent} = +FontOblique;
            $_->root->set_att('#fonts', $fonts);
            $_->erase;
        },
        b => sub {
            my $fonts = $_->root->att('#fonts') || {};
            $fonts->{$_->parent} = +FontBold;
            $_->root->set_att('#fonts', $fonts);
            $_->erase;
        },
        hr => sub {
            $_->insert_new_elt(first_child => 'hr');
            $_->erase;
        },
        img => sub {
            my $file = File::Spec->rel2abs($_->att('src'));
            my $image = $_->insert_new_elt(first_child => image => {
                filename => $file,
                w => $_->att('width'),
                h => $_->att('height'),
                type => '', # XXX
            } );
            $image->wrap_in('row');
            $_->erase;
        },
        body => sub {
            $_->wrap_in(
                pagedef => {
                    pagesize => "A4",
                    landscape => "0",
                    margins => "10"
                },
            );
            $_->wrap_in(
                font => {
                    face => +Font,
                    h => 10,
                }
            );
            my $pagedef = $_->parent->parent;
            my $head = $pagedef->insert_new_elt(first_child => header => { header_height => 24 } );
            my $row = $head->insert_new_elt(first_child => 'row');
            $row->insert_new_elt(first_child => textbox => { w => '100%', text => '' });
            foreach my $child ($_->children('#PCDATA')) {
                $child->set_text(join(' ', grep length, split(/\n+/, $child->text)));
                if ($child->text =~ /[^\x00-\x7f]/) {
                    $child->wrap_in(font => { face => +FontUnicode });
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
            $_->insert_new_elt(last_child => row => { h => '12' });
            $_->erase;
        },
        ol => sub {
            my $count = 1;
            foreach my $child ($_->descendants('counter')) {
                $child->set_tag('textbox');
                $child->set_text("$count. ");
                $count++;
            }
            $_->insert_new_elt(last_child => row => { h => '12' });
            $_->erase;
        },
        ul => sub {
            foreach my $child ($_->descendants('counter')) {
                $child->set_tag('textbox');
                $child->set_text("* ");
            }
            $_->insert_new_elt(last_child => row => { h => '12' });
            $_->erase;
        },
        tr => sub {
            return $_->erase if $_->descendants('row');
            $_->set_tag('row'),
        },
        td => sub {
            return $_->erase if $_->descendants('row');

            $_->set_tag('textbox');
            $_->set_att(border => $_->parent('table')->att('border'));
            $_->set_att(lmargin => '3');
            $_->set_att(rmargin => '3');

            my $widths = $_->root->att('#widths') || [];
            my $width = $_->att('w') || ($widths->[$_->pos] ||= (
                int(100 / (2 + $_->prev_siblings + $_->next_siblings)) . '%'
            ));
            $_->set_att(w => $width);

            # XXX - breaks sup
            #my $fonts = $_->root->att('#fonts') || {};
            #if (my $font = $fonts->{$_}) {
            #    $_->wrap_in( font => { face => $font } );
            #}
        },
        th => sub {
            $_->set_tag('textbox');
            $_->set_att(border => $_->parent('table')->att('border'));
            $_->set_att(lmargin => '3');
            $_->set_att(rmargin => '3');
            $_->set_text(join('', split(/\s+/, $_->text)));
        },
        font => sub {
            $_->del_att('face');
            if ($_->att_names) {
                $_->set_att(face => +Font);
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
                $_->set_att(h => 10 + (2 * ($h - 3)));
            }
            if (my $bgcolor = $_->att('bgcolor')) {
                $_->set_att(
                    bgcolor => do {
                        local $_;
                        my $rgb = Color::Rgb->new;
                        $rgb->can($bgcolor =~ /^#/ ? 'hex2rgb' : 'name2rgb')
                            ->($rgb, $bgcolor, ',');
                    }
                );
            }
            $_->del_att(qw(
                color bordercolor bordercolordark bordercolorlight
                cellpadding cellspacing size href
            ));
        },
    }
);

sub _p {
    my @children;
    foreach my $child ($_->children) {
        +InlineTags->{$child->tag} or last;
        push @children, $child->cut;
    }

    if (@children) {
        my $textbox = $_->insert_new_elt(
            before => 'textbox', { w => (($_->tag eq 'p') ? '100%' : '97%') }
        );
        $textbox->wrap_in('row');
        if ($_->tag eq 'li') {
            $textbox->insert_new_elt(
                before => 'counter', { w => '3%', align => 'right' }
            );
        }
        foreach my $child (@children) {
            $child->paste( last_child => $textbox );
            $child->set_text(join(' ', grep length, split(/\n+/, $child->text)));
        }

        my $fonts = $_->root->att('#fonts') || {};

        if ($textbox->text =~ /[^\x00-\x7f]/) {
            $fonts->{$_} = +FontUnicode;
        }
        elsif ($_->parent('i') and $_->parent('b')) {
            $fonts->{$_} ||= +FontBoldOblique;
        }
        elsif ($_->parent('i')) {
            $fonts->{$_} ||= +FontOblique;
        }
        elsif ($_->parent('b')) {
            $fonts->{$_} ||= +FontBold;
        }

        if (my $font = $fonts->{$_}) {
            $textbox->wrap_in('font' => { face => $font });
        }
    }
    $_->insert_new_elt( first_child => 'textbox' )->wrap_in('row') if $_->tag eq 'p';
    $_->erase;
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
