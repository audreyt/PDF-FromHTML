#line 1 "inc/Module/Install/Scripts.pm - /usr/local/lib/perl5/site_perl/5.8.4/Module/Install/Scripts.pm"
# $File: //depot/cpan/Module-Install/lib/Module/Install/Scripts.pm $ $Author: autrijus $
# $Revision: #7 $ $Change: 1841 $ $DateTime: 2003/12/28 19:43:56 $ vim: expandtab shiftwidth=4

package Module::Install::Scripts;
use Module::Install::Base; @ISA = qw(Module::Install::Base);
$VERSION = '0.01';
use strict;
use File::Basename ();

sub prompt_script {
    my ($self, $script_file) = @_;
    my ($prompt, $abstract, $default);

    foreach my $line ( $self->_read_script($script_file) ) {
        last unless $line =~ /^#/;
        $prompt = $1   if $line =~ /^#\s*prompt:\s+(.*)/;
        $default = $1  if $line =~ /^#\s*default:\s+(.*)/;
        $abstract = $1 if $line =~ /^#\s*abstract:\s+(.*)/;
    }
    unless (defined $prompt) {
        my $script_name = File::Basename::basename($script_file);
        $prompt = "Do you want to install '$script_name'";
        $prompt .= " ($abstract)" if defined $abstract;
        $prompt .= '?';
    }
    return unless $self->prompt($prompt, ($default || 'n')) =~ /^[Yy]/;
    $self->install_script($script_file);
}

sub install_script {
    my ($self, $script_file) = @_;
    my $args = $self->makemaker_args;
    my $exe_files = $args->{EXE_FILES} ||= [];
    push @$exe_files, $script_file;
}

sub _read_script {
    my ($self, $script_file) = @_;
    local *SCRIPT;
    open SCRIPT, $script_file
      or die "Can't open '$script_file' for input: $!\n";
    return <SCRIPT>;
}

1;
