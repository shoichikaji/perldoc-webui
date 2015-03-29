#!/usr/bin/env perl
use Mojolicious::Lite;
use Distribution::Metadata;
use Mojo::URL;

plugin 'PODRenderer';

sub parts {
    state $parts = do {
        my %modules;
        for my $module (split /,/, $ENV{PERL_MODULES} || 'Mojolicious') {
            my $dist = Distribution::Metadata->new_from_module($module);
            if (my $hash = $dist->install_json_hash) {
                $modules{$_}++ for keys %{$hash->{provides}};
            }
        }
        my @parts;
        for my $module (sort keys %modules) {
            ( my $path = $module ) =~ s{::}{/}g;
            push @parts, [$module, Mojo::URL->new("/perldoc/$path") ];
        }
        \@parts;
    };
    # must copy
    [ map { [$_->[0], $_->[1]] } @$parts ];
}

get '/' => sub {
    my $c = shift;
    $c->content_for(perldoc => "");
    $c->stash(module => $ENV{PERL_MODULES} || 'Mojolicious');
    my $template = $c->app->renderer->_bundled('perldoc');
    $c->render(inline => $template, title => "perldoc", parts => parts);
};

hook after_render => sub {
    my ($c, $out_ref) = @_;
    my $dom = Mojo::DOM->new( $$out_ref );
    my $first = $dom->find('#mojobar-logo a')->first;
    if ($first) {
        $first->attr({href => "/"});
        $$out_ref = $dom->to_string;
    }
};

app->start(@ARGV ? @ARGV : "daemon");
