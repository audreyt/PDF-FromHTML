package PDF::FromHTML::Twig;

use strict;
use XML::Twig;
use base 'XML::Twig';
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

use constant FontFace => 'Helvetica';
use constant IgnoreTags => { map {$_ => 1} qw(
    head style title center u sup p a b
    ol ul li i
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
                $_->wrap_in(font => { h => 17 - $size });
                $_->wrap_in('row');
                $_->set_tag('textbox'),
                $_->set_att( w => '100%' );
            };
        })->($_)), 1..6),
        img => sub {
            my $file = File::Spec->rel2abs($_->att('src'));
            $_->del_att('src');
            $_->set_att(filename => $file);
            $_->set_att(w => $_->att('width'));
            $_->set_att(h => $_->att('height'));
            $_->set_att(type => lc((split(/\./, $file))[-1]));
            $_->set_tag('image');
        },
        body => sub {
            $_->wrap_in(
                pagedef => {
                    pagesize => "A4",
                    landscape => "1",
                    margins => "10"
                },
            );
            $_->wrap_in(
                font => {
                    face => +FontFace,
                    h => 10,
                }
            );
            my $pagedef = $_->parent->parent;
            my $head = $pagedef->insert_new_elt(first_child => header => { header_height => 24 } );
            my $row = $head->insert_new_elt(first_child => 'row');
            $row->insert_new_elt(first_child => textbox => { w => '100%', text => '' });
            $_->erase;
        },
        table => sub {
            $_->root->del_att('#widths');
            $_->erase;
        },
        tr => sub { $_->set_tag('row') },
        td => sub {
            $_->set_tag('textbox');
            $_->set_att(border => $_->parent('table')->att('border'));
            $_->set_att(lmargin => '3');
            $_->set_att(rmargin => '3');

            my $widths = $_->root->att('#widths') || [];
            $_->set_att(w => $_->att('w') || $widths->[$_->pos]);
        },
        th => sub {
            _->set_tag('textbox');
            $_->set_att(border => $_->parent('table')->att('border'));
            $_->set_att(lmargin => '3');
            $_->set_att(rmargin => '3');
            $_->set_text(join('', split(/\s+/, $_->text)));
        },
        font => sub {
            $_->del_att('face');
            if ($_->att_names) {
                $_->set_att(face => +FontFace);
                $_->erase; # XXX
            }
            else {
                $_->erase;
            }
        },
        _default_ => sub {
            $_->erase if +IgnoreTags->{$_->tag};
        }
    },
    pretty_print => 'indented',
    empty_tags   => 'html',
    start_tag_handlers => {
        _all_ => sub {
            $_->set_tag(lc($_->tag));

            if (my $w = $_->att('width')) {
                $_->set_att(w => $w);
                my $widths = $_->root->att('#widths') || [];
                $widths->[$_->pos] = $w;
                $_->root->set_att('#widths' => $widths);
            }
            if (my $h = $_->att('size')) {
                $_->set_att(h => 10 + (2 * ($h - 3)));
            }
            $_->del_att(qw(
                color bgcolor bordercolor bordercolordark bordercolorlight
                cellpadding cellspacing size href
            ));
        },
    }
);

1;

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
