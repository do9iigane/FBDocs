package FBDocs::Parser;
use strict;
use warnings;
use Web::Scraper;
use URI;
use Encode ();

sub new {
    my $class = shift;
    my $args  = shift || +{};

    my $self = bless +{
        base_url => 'https://developers.facebook.com/docs/',
        %$args,
    }, $class;
    
    $self->{scraper} ||= scraper {
        process '#bodyMenu', 'menu' => scraper {
            process '*', content => 'HTML',
            process 'a', 'links[]' => '@href',
        },
        process '#bodyText', 'body' => scraper {
            process '*', content => 'HTML',
           process 'a', 'links[]' => '@href',
        },
    };

    return $self;
}

sub parse {
    my ( $self, $input ) = @_;

    my $ret = eval {
        $self->{scraper}->scrape( $input );
    };
    if ($@ || !$ret) {
        warn $@ . ' : ' . $input;
        return undef;
    }

    return +{
        content => $self->_parse_html( $ret->{body}->{content} ) || '',
        menu    => $self->_parse_html( $ret->{menu}->{content} ) || '',
        links   => [ @{$ret->{menu}->{links} || []}, @{$ret->{body}->{links} || []} ],
    };
}

sub _parse_html {
    my ($self, $input) = @_;

    return unless $input;

    my $base_url = $self->{base_url};
    my $orig_uri = URI->new( $base_url );

    # fix link href
    $input =~ s{<a\s+([^>]*?)href="(.*?)"(.*?)>(.*?)</a>}{
        my $pre  = $1;
        my $href = $2;
        my $post = $3;
        my $text = $4;

        # h=XXX seems to be some rondom strings or token.
        # $uri->query_param_delete( 'h' ); will give us amp param because of &amp;.
        # http://developers.facebook.com/l.php?u=http%3A%2F%2Ffacebook.stackoverflow.com%2Fsearch%3Fq%3D%255Bfacebook%255DDisputes%2B%2526%2BChargebacks&amp;h=7AQG7DHsI
        $href =~ s/&amp;h=([^&]*)//;
        my $uri = URI->new_abs( $href, $base_url );

        # they have hTTTps://developers.facebook.com/docs/FOO so $uri->host doesn't work!!!
        my $target = '';
        if ( $uri->can( 'host' ) && $uri->host eq $orig_uri->host && $uri->path =~ /\/docs/ ) {
            # /docs/*
            $href = $uri->path;
            $href .= '/' unless $href =~ /\/$/;
            $href .= '?' . $uri->query if $uri->query;
            $href .= '#' . $uri->fragment if $uri->fragment;
        } else {
            # external links including /tools/*
            $target = ' target="_blank"' if ( $pre !~ /target="_blank"/ && $post !~ /target="_blank"/ );
            $href = $uri->canonical;
        }

        $pre =~ s/\sonmouse(down|up)="(.*?)"//ig;
        $post =~ s/\sonmouse(down|up)="(.*?)"//ig;

        sprintf( '<a %shref="%s"%s name="%s"%s>%s</a>', $pre, $href, $post, $uri->canonical, $target, $text );
    }esig;
    
    # fix img src
    $input =~ s{<img\s+([^>]*?)src="(.*?)"([^>]*?)>}{
        my $pre  = $1;
        my $src  = $2;
        my $post = $3;
        my $uri = URI->new_abs( $src, $base_url );
        sprintf( '<img %ssrc="%s"%s>', $pre, $uri->canonical, $post );
    }esig;
    
    # fix image src
    $input =~ s{<image\s+([^>]*?)src="(.*?)"([^>]*?)>(.*?)</image>}{
        my $pre  = $1;
        my $src  = $2;
        my $post = $3;
        my $uri = URI->new_abs( $src, $base_url );
        sprintf( '<image %ssrc="%s"%s></image>', $pre, $uri->canonical, $post )
    }esig;
    
    # avoid "Updated .. months ago." We don't want relative value
    # <abbr class="timestamp" data-utime="1337637047" title="2012年5月21日 14:50">約3週間前に更新</abbr>
    # <abbr class="date timestamp" data-utime="1339536392" title="2012年6月12日 14:26">4時間前に質問</abbr>
    $input =~ s{<abbr\s+(.*?)class="(.*?)timestamp(.*?)"(.*?)>(.*?)</abbr>}{
        my $pre = $1;
        my $class_pre  = $2;
        my $class_post = $3;
        my $post = $4;
        my $text = $5;
        if ( $pre =~ /title="(.*?)"/ || $post =~ /title="(.*?)"/) {
            $text = $1;
        }
        sprintf( '<abbr %sclass="%stimestamp%s"%s>%s</abbr>', $pre, $class_pre, $class_post, $post, $text )
    }esig;

    # <span class="timestamp">0 votes · 2 answers · 898 views · </span>
    $input =~ s/<span\s+(?:.*?)class="timestamp"(?:.*?)>(?:.*?)votes(?:.*?)answers(?:.*?)views(?:.*?)<\/span>//ig;
    
    # <div class="plugin_form" id="uppe9c_2">
    # <div class="plugin_example nofloat" id="u3cxk1_1">
    $input =~ s{<div\s+(.*?)class="(.*?)plugin_(form|example)(.*?)"(.*?)>}{
        my $pre        = $1;
        my $class_pre  = $2;
        my $name       = $3;
        my $class_post = $4;
        my $post       = $5;

        $post =~ s/\sid="(.*?)"//ig;
        sprintf( '<div %sclass="%splugin_%s%s"%s>', $pre, $class_pre, $name, $class_post,  $post );
    }esig;
    
    # <a class="uiButton" href="/docs/reference/plugins/send/code/?revision=330533710311758" id="uqkud0_3" ....
    $input =~ s{<a\s+(.*?)class="(.*?)uiButton(.*?)"(.*?)>}{
        my $pre        = $1;
        my $class_pre  = $2;
        my $class_post = $3;
        my $post       = $4;

        $post =~ s/\sid="(.*?)"//ig;
        sprintf( '<a %sclass="%suiButton%s"%s>', $pre, $class_pre, $class_post, $post );
    }esg;

    # no script
    $input =~ s/<script([^>]*?)>(.*?)<\/script>//;
    $input =~ s/></>\n</ig;

    return $input;
}

1;
