package PDF::FromHTML::Twig;

use strict;
use charnames ':full';
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

use constant PageWidth => 640;
use constant FontBold => 'HelveticaBold';
use constant FontOblique => 'HelveticaOblique';
use constant FontBoldOblique => 'HelveticaBoldOblique';
use constant FontUnicode => 'Helvetica';
#use constant FontUnicode => do {
#    my $font = '/usr/X11R6/lib/X11/fonts/webfonts/arialuni.ttf' if 0;
#    (-e $font) ? $font : 'Helvetica';
#};
use constant Font => +FontUnicode;
use constant SuperScript => [
    "\N{SUPERSCRIPT ZERO}", "\N{SUPERSCRIPT ONE}", "\N{SUPERSCRIPT TWO}",
    "\N{SUPERSCRIPT THREE}", "\N{SUPERSCRIPT FOUR}", "\N{SUPERSCRIPT FIVE}",
    "\N{SUPERSCRIPT SIX}", "\N{SUPERSCRIPT SEVEN}", "\N{SUPERSCRIPT EIGHT}",
    "\N{SUPERSCRIPT NINE}",
];
use constant SubScript => [
    "\N{SUBSCRIPT ZERO}", "\N{SUBSCRIPT ONE}", "\N{SUBSCRIPT TWO}",
    "\N{SUBSCRIPT THREE}", "\N{SUBSCRIPT FOUR}", "\N{SUBSCRIPT FIVE}",
    "\N{SUBSCRIPT SIX}", "\N{SUBSCRIPT SEVEN}", "\N{SUBSCRIPT EIGHT}",
    "\N{SUBSCRIPT NINE}",
];
use constant InlineTags => { map {$_ => 1} '#PCDATA', 'font' };
use constant DeleteTags => { map {$_ => 1} qw(
    head style applet script
) };
use constant IgnoreTags => { map {$_ => 1} qw(
    title center a ul

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
                   ->wrap_in( font => { face => +FontBold } );
                $_->wrap_in(font => { h => 18 - $size });
                $_->wrap_in(row => { h => 20 - $size });
                $_->set_tag('textbox'),
                $_->set_att( w => '100%' );
            };
        })->($_)), 1..6),
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
        i => sub {
            _set(font => +FontOblique, $_);
            $_->erase;
        },
        b => sub {
            _set(font => +FontBold, $_);
            $_->erase;
        },
        div => sub {
            # XXX - deal with class="header" and class="footer"
            $_->erase;
        },
        hr => sub {
            $_->insert_new_elt(
                first_child => 
                    ($_->att('class') eq 'pagebreak') ? 'pagebreak' : 'hr'
            );
            $_->erase;
        },
        img => sub {
            my $file = File::Spec->rel2abs($_->att('src'));
            my $image = $_->insert_new_elt(first_child => image => {
                filename => $file,
                w => ($_->att('width') / PageWidth * 540),
                h => ($_->att('height') / PageWidth * 540),
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
        br => sub {
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
        dl => sub {
            foreach my $child ($_->descendants('counter')) {
                $child->delete;
            }
            $_->insert_new_elt(last_child => row => { h => '12' });
            $_->erase;
        },
        tr => sub {
            return $_->erase if $_->descendants('row');

            my @children = $_->descendants('textbox');

            my $widths = $_->root->att('#widths') || [];
            my $width = $_->att('w') || ($widths->[$_->pos] ||= (
                int(_percentify($_->parent('table')->att('width'))
                    / @children) . '%'
            ));

            foreach my $child (@children) {
                $child->set_att( w => $width );
            }
            $_->set_tag('row');
        },
        td => sub {
            return $_->erase if $_->descendants('row');

            $_->set_tag('textbox');
            $_->set_att(border => $_->parent('table')->att('border'));
            $_->set_att(lmargin => '3');
            $_->set_att(rmargin => '3');

            # XXX - breaks sup
            if (my $font = _get(font => $_)) {
                $_->wrap_in( font => { face => $font } );
            }
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
            $child->set_text(
                join(' ', grep {length and $_ ne 1} split(/\n+/, $child->text))
            );
        }

        my $font = _get(font => $_);

        if ($textbox->text =~ /[^\x00-\x7f]/) {
            $font = +FontUnicode;
        }
        elsif ($_->parent('i') and $_->parent('b')) {
            $font ||= +FontBoldOblique;
        }
        elsif ($_->parent('i')) {
            $font ||= +FontOblique;
        }
        elsif ($_->parent('b')) {
            $font ||= +FontBold;
        }

        my %attr;
        $attr{face} = $font if $font;
        if (_get(underline => $_)) {
            require PDF::Template::Constants;
            $PDF::Template::Constants::Verify{ALIGN}{underline} = 1;
            $attr{align} = 'underline' 
        }

        $textbox->wrap_in('font' => \%attr) if %attr;
    }

    $_->insert_new_elt( first_child => 'textbox' )->wrap_in('row') if $_->tag eq 'p';
    $_->erase;
}

sub _percentify {
    my $num = _perc($_[0]);
    return $num;
}

sub _perc {
    my $num = shift;
    return $1 if $num =~ /(\d+)%/;
    return int($num / PageWidth * 100);
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
