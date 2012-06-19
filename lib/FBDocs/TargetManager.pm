package FBDocs::TargetManager;
use warnings;
use strict;

use URI;

sub new {
    my $class = shift;
    my $args  = shift || +{};

    my $self = bless +{
        targets => [],
        count   => 0,
        %$args,
    }, $class;

    return $self;
}

sub add_targets {
    my ( $self, $targets ) = @_;
    $self->add_target( $_ ) for @$targets;
}

sub add_target {
    my ( $self, $target ) = @_;
    return unless $target;

    #my $uri = URI->new( $target );
    my $uri = URI->new_abs( $target, 'https://developers.facebook.com/' );

    # only add https://developers.facebook.com/docs/*
    my $path = $uri->path;
    return unless $uri->can( 'host' );
    return unless $uri->host eq 'developers.facebook.com';
    return unless $path && $path =~ /^\/docs\//;

    $uri->fragment( undef );
    $uri->query( undef );
    $uri->scheme('https');
    my $url = $uri->canonical;
    $url .= '/' unless  $url =~ /\/$/; #XXX

    return if $self->{target_url}->{$url}; # already exists

    $self->{target_url}->{$url} = +{
        scraped => 0,
    };
    push @{$self->{targets}}, $url;
}

sub has_more_target {
    my $self = shift;
    return scalar @{$self->{targets}} ? 1 : 0;
}

sub next {
    my $self = shift;
    $self->{count}++;
    return pop @{$self->{targets}};
}

sub count {
    return shift->{count};
}

sub list {
    my $self = shift;
    my @links = sort { $a cmp $b } keys( %{$self->{target_url}});
    return \@links;
}

1;
