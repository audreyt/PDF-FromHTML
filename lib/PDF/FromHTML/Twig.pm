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

use constant FontFace => 'Helvetica';
use constant InlineTags => { map {$_ => 1} qw(
    #PCDATA font
) };
use constant DeleteTags => { map {$_ => 1} qw(
    head style
) };
use constant IgnoreTags => { map {$_ => 1} qw(
    title center u a b
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
                $_->wrap_in(row => { h => 19 - $size });
                $_->set_tag('textbox'),
                $_->set_att( w => '100%' );
            };
        })->($_)), 1..6),
        sup => sub {
            $_->set_tag('font');
            $_->set_att( h => 8 );
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
                    face => +FontFace,
                    h => 10,
                }
            );
            my $pagedef = $_->parent->parent;
            my $head = $pagedef->insert_new_elt(first_child => header => { header_height => 24 } );
            my $row = $head->insert_new_elt(first_child => 'row');
            $row->insert_new_elt(first_child => textbox => { w => '100%', text => '' });
            foreach my $child ($_->children('#PCDATA')) {
                $child->wrap_in('row');
                $child->wrap_in(textbox => { w => '100%' });
                my $textbox = $child->insert_new_elt(
                    after => 'textbox', { w => '100%' }
                );
                $textbox->wrap_in('row');
            }
            $_->erase;
        },
        p => sub {
            my @children;
            foreach my $child ($_->children) {
                +InlineTags->{$child->tag} or last;
                push @children, $child->cut;
            }

            if (@children) {
                my $textbox = $_->insert_new_elt(
                    before => 'textbox', { w => '100%' }
                );
                $textbox->wrap_in('row');
                $_->paste( last_child => $textbox ) for @children;
            }
            my $textbox = $_->insert_new_elt(
                after => 'textbox', { w => '100%' }
            );
            $textbox->wrap_in('row');
            $_->erase;
        },
        table => sub {
            $_->root->del_att('#widths');
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
                int(100 / (1 + $_->prev_siblings + $_->next_siblings)) . '%'
            ));
            $_->set_att(w => $width);
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
            $_->delete if +DeleteTags->{$_->tag};
        }
    },
    pretty_print => 'indented',
    empty_tags   => 'html',
    start_tag_handlers => {
        _all_ => sub {
            if (my $w = $_->att('width')) {
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

1;

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
