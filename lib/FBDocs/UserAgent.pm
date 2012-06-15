package FBDocs::UserAgent;
use strict;
use warnings;
use Furl;
use Encode;

sub new {
    my $class = shift;
    my $args = shift || +{};

    my $self = bless $args, $class;
}

sub ua {
    my $self = shift;
    return $self->{__ua__} ||= Furl->new(
        agent => $self->{agent} || 'FBDocs/0.01',
        timeout => $self->{timeout} || 10,
    );
}

sub get_content {
    my ( $self, $url ) = @_;
    my $res = $self->ua->get( $url );
    unless ( $res->is_success ) {
        warn $res->status_line;
        return undef;
    }

    my $content_type = $res->content_type;
    $content_type =~ /charset=([A-Za-z0-9_\-]+)/io;
    my $charset = $1 || 'utf-8';

    return Encode::decode($charset, $res->content);
}

1;
