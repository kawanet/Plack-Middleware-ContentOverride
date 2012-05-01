#!/usr/bin/env perl -w

use strict;
use Test::More tests => 30;
use Plack::Test;
use Plack::Request;
use HTTP::Request;
use HTTP::Message;
use URI;
use URI::Escape;

BEGIN { use_ok 'Plack::Middleware::ContentOverride' or die; }

my $jsontext  = '{"key"=>"val"}';
my $jsonenc   = URI::Escape::uri_escape($jsontext);
my $jsontype  = 'application/json';
my $formtype  = 'application/x-www-form-urlencoded';
my $multitype = 'multipart/form-data';

my $base_app = sub {
    my $env = shift;
    my $req  = Plack::Request->new($env);
    my $type = $req->content_type;
    my $body = $req->content;
    my $len  = length($body);

    return [
        200,
        ['Content-Type' => $type, 'Content-Length' => $len],
        [ $body ]
    ];
};

my $mw_app = Plack::Middleware::ContentOverride->wrap($base_app);
ok $mw_app, 'Create ContentOverride app with no args';

my $opt_app = Plack::Middleware::ContentOverride->wrap($base_app,
    payload => 'content', content_type => $jsontype);
ok $opt_app, 'Create ContentOverride app with args';

my $uri = URI->new('/');

test_psgi $base_app, sub {
    my $app = shift;
    my $req = HTTP::Request->new(GET => $uri);
    my $res = $app->($req);
    is $res->content_length, 0, 'BASE GET content empty';
};

test_psgi $mw_app, sub {
    my $app = shift;
    my $req = HTTP::Request->new(GET => $uri);
    my $res = $app->($req);
    is $res->content_length, 0, 'MW GET content empty';
};

test_psgi $opt_app, sub {
    my $app = shift;
    my $req = HTTP::Request->new(GET => $uri);
    my $res = $app->($req);
    is $res->content_length, 0, 'OPT GET content empty';
};

test_psgi $mw_app, sub {
    my $app = shift;
    my $req = make_get_request('payload');
    my $res = $app->($req);
    isnt $res->content_type, $formtype, "MW GET urlencoded content type";
    is $res->content_length, length($jsontext), "MW GET urlencoded content length";
    is $res->content, $jsontext, "MW GET urlencoded content body";
};

test_psgi $opt_app, sub {
    my $app = shift;
    my $req = make_get_request('content');
    my $res = $app->($req);
    isnt $res->content_type, $formtype, "OPT GET urlencoded content type";
    is $res->content_length, length($jsontext), "OPT GET urlencoded content length";
    is $res->content, $jsontext, "OPT GET urlencoded content body";
};

test_psgi $mw_app, sub {
    my $app = shift;
    my $req = make_get_request('wrong');
    my $res = $app->($req);
    is $res->content_length, 0, "MISS GET urlencoded content length";
};

test_psgi $base_app, sub {
    my $app  = shift;
    my $req  = HTTP::Request->new(POST => $uri);
    my $type = 'text/plain';
    $req->header('Content-Type' => $type);
    $req->header('Content-Length' => length($jsontext));
    $req->content($jsontext);

    my $res = $app->($req);
    is $res->content_type, $type, "BASE POST content type";
    is $res->content_length, length($jsontext), "BASE POST content length";
    is $res->content, $jsontext, "BASE POST content body";
};

test_psgi $mw_app, sub {
    my $app = shift;
    my $req = get_urlencoded_request('payload');
    my $res = $app->($req);
    isnt $res->content_type, $formtype, "MW POST urlencoded content type";
    is $res->content_length, length($jsontext), "MW POST urlencoded content length";
    is $res->content, $jsontext, "MW POST urlencoded content body";
};

test_psgi $opt_app, sub {
    my $app = shift;
    my $req = get_urlencoded_request('content');
    my $res = $app->($req);
    is $res->content_type, $jsontype, "OPT POST urlencoded content type";
    is $res->content_length, length($jsontext), "OPT POST urlencoded content length";
    is $res->content, $jsontext, "OPT POST urlencoded content body";
};

test_psgi $mw_app, sub {
    my $app = shift;
    my $req = get_urlencoded_request('wrong');
    my $res = $app->($req);
    is $res->content_length, 0, "MISS POST urlencoded content length";
};

test_psgi $mw_app, sub {
    my $app = shift;
    my $req = get_multipart_request('payload');
    my $res = $app->($req);
    isnt $res->content_type, $multitype, "MW POST multipart content type";
    is $res->content_length, length($jsontext), "MW POST multipart content length";
    is $res->content, $jsontext, "MW POST multipart content body";
};

test_psgi $opt_app, sub {
    my $app = shift;
    my $req = get_multipart_request('content');
    my $res = $app->($req);
    is $res->content_type, $jsontype, "OPT POST multipart content type";
    is $res->content_length, length($jsontext), "OPT POST multipart content length";
    is $res->content, $jsontext, "OPT POST multipart content body";
};

test_psgi $mw_app, sub {
    my $app = shift;
    my $req = get_multipart_request('wrong');
    my $res = $app->($req);
    is $res->content_length, 0, "MISS POST multipart content length";
};

sub make_get_request {
    my $name = shift;
    my $get  = $uri->clone;
    $get->query_form( $name => $jsontext );
    my $req = HTTP::Request->new(GET => $get);
    $req;
}

sub get_urlencoded_request {
    my $name = shift;
    my $req  = HTTP::Request->new(POST => $uri);
    my $body = $name.'='.$jsonenc;
    $req->header('Content-Type' => $formtype);
    $req->header('Content-Length' => length($body));
    $req->content($body);
    $req;
}

sub get_multipart_request {
    my $name = shift;

    my $file = HTTP::Message->new;
    $file->headers->header('Content-Type', $jsontype);

    my $disp = sprintf('form-data; name="%s"', $name);
    $file->headers->header('Content-Disposition', $disp);

    $file->content($jsontext);

    my $mess = HTTP::Message->new;
    $mess->parts($file);

    my $type = $mess->headers->header('Content-Type');
    $type =~ s:^multipart/[^\;\s]+:$multitype:;
    $mess->headers->header('Content-Type', $type);

    my $req = HTTP::Request->new(POST => $uri, $mess->headers, $mess->content);
    $req;
}
