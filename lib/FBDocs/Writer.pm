package FBDocs::Writer;
use warnings;
use strict;
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use IO::File;
use Encode;
use URI;

sub save_doc {
    my ($class, $base_dir, $url, $input) = @_;
    
    return unless $input;

    my $menu    = $input->{menu} || '';
    my $content = $input->{content} || '';
    $menu    = encode( 'utf-8', $menu ) if utf8::is_utf8( $menu );
    $content = encode( 'utf-8', $content ) if utf8::is_utf8( $content );
    
    my $uri  = URI->new( $url );
    my $path = $uri->path;
    $path .= 'index' if $path =~ m/\/$/;
    $path .= '.html';
    $path = $base_dir . $path;

    my $dir = dirname( $path );
    mkpath([$dir], 0, 0755) unless -d $dir;
    my $io = IO::File->new( $path, 'w' );
    $io->print(<<"HEADER")
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8" />
<title>$url</title>
<link rel="stylesheet" href="/css/common.css" media="screen" />
<script src="/js/common.js"></script>
</head>
<body>
HEADER
;
    $io->print( sprintf( "<a id=\"oklahomer-orig-url\" href=\"%s\">%s</a>\n\n", $url, $url ) );
    $io->print( "<div id=\"oklahomer-menu-wrapper\">\n" . $menu . "</div>\n\n" );
    $io->print( "<div id=\"oklahomer-content-wrapper\">\n" . $content . "</div>\n\n" );
    $io->print(<<"FOOTER");
</body>
</html>
FOOTER
;
    $io->close;
}

sub save_target_list {
    my ( $class, $base_dir, $targets ) = @_;

    my $path = $base_dir . '/../misc/scraped_url_list.txt';
    my $dir = dirname( $path );
    mkpath([$dir], 0, 0755) unless -d $dir;
    my $io = IO::File->new( $path, 'w' );
    $io->print( "$_\n") for @$targets;
    $io->close;
}

1;
