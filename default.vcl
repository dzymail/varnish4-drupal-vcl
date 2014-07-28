#
# This is an example VCL file for Varnish.
#
# It does not do anything by default, delegating control to the
# builtin VCL. The builtin VCL is called when there is no explicit
# return statement.
#
# See the VCL chapters in the Users Guide at https://www.varnish-cache.org/docs/
# and http://varnish-cache.org/trac/wiki/VCLExamples for more examples.

# Marker to tell the VCL compiler that this VCL has been adapted to the
# new 4.0 format.
vcl 4.0;
import directors;
include "normalize_UA.vcl";
# Default backend definition. Set this to point to your content server.

backend host1 {
    .host = "192.168.1.1";
    .port = "81";
    .probe = {
                 .url = "/";
                .interval = 5s;
                .timeout = 1 s;
                .window = 5;
                .threshold = 3;
  }
}
backend host2 {
    .host = "192.168.1.2";
    .port = "80";
    .probe = {
                 .url = "/";
                .interval = 5s;
                .timeout = 1 s;
                .window = 5;
                .threshold = 3;
  }
}

sub vcl_init {
  new rr = directors.round_robin();
  rr.add_backend(host1);
  rr.add_backend(host2);
}
sub vcl_recv {
    # Happens before we check if we have this in cache already.
    # 
    # Typically you clean up the request here, removing cookies you don't need,
    # rewriting the request, etc.
    if (req.http.host ~ "inventory.example.com") {
        set req.backend_hint = tesla;
        return (pass);
 }

elseif (req.http.host ~ "demo.example.com") {
        set req.backend_hint = tesla;
        return (pass);
 }

elseif (req.http.host ~ "wordpress.example.com") {
        set req.backend_hint = tesla;
        return (pass);
 }
    else {
        set req.backend_hint = rr.backend();
}

# Get ride of progress.js query params
   if (req.url ~ "^/misc/progress\.js\?[0-9]+$") {
       set req.url = "/misc/progress.js";
         }

   if (req.url ~ "^/update\.php$" ||
      req.url ~ "^/ooyala/ping$" ||
      req.url ~ "^/admin" ||
      req.url ~ "^/admin/.*$" ||
      req.url ~ "^/node/.*$" ||
      req.url ~ "^/user" ||
      req.url ~ "^/user/.*$" ||
      req.url ~ "^/users/.*$" ||
      req.url ~ "^/info/.*$" ||
      req.url ~ "^/flag/.*$" ||
      req.url ~ "^.*/ajax/.*$" ||
      req.url ~ "^.*/ahah/.*$") {
      return (pass);
     }
call normalize_user_agent;

if (req.http.Vary ~ "User-Agent") {
    set req.http.Vary = regsub(req.http.Vary, "(^|; ) *User-Agent,? *", "\1");
    if (req.http.Vary == "") {
        unset req.http.Vary;
    }
}

if (req.http.Accept-Encoding) {
        if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
            # No point in compressing these
            unset req.http.Accept-Encoding;
        } elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } elsif (req.http.Accept-Encoding ~ "deflate" && req.http.user-agent !~ "MSIE") {
            set req.http.Accept-Encoding = "deflate";
       } else {
            # unkown algorithm
            unset req.http.Accept-Encoding;
       }
       }
       if (req.url ~ "(?i)\.(png|gif|jpeg|jpg|ico|swf|css|js)(\?[a-z0-9]+)?$") {
            unset req.http.Cookie;
       }

# Remove cookies
       if (req.http.Cookie) {
       set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(__[a-z]+|has_js|Drupal.toolbar.collapsed)=[^;]*", "");
  set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");
  if (req.http.Cookie ~ "^\s*$") {
    unset req.http.Cookie;
  }

    else {
        return (pass);
    }
}

  if (req.restarts == 0) {
    if (req.http.x-forwarded-for) {
      set req.http.X-Forwarded-For =
      req.http.X-Forwarded-For + ", " + client.ip;
    } else {
      set req.http.X-Forwarded-For = client.ip;
    }
  }
  if (req.method != "GET" &&
    req.method != "HEAD" &&
    req.method != "PUT" &&
    req.method != "POST" &&
    req.method != "TRACE" &&
    req.method != "OPTIONS" &&
    req.method != "DELETE") {
    /* Non-RFC2616 or CONNECT which is weird. */
    return (pipe);
  }
  if (req.method != "GET" && req.method != "HEAD") {
      /* We only deal with GET and HEAD by default */
      return (pass);
  }

} # end of vcl_recv

sub vcl_pipe {
    set bereq.http.connection = "close";
    }

sub vcl_hash {
  if (req.http.Cookie) {
   hash_data(req.url);
  }
}


sub vcl_hit {
  if (req.method == "PURGE") {
    purge;
    return (synth(200, "Purged"));
  }
}

sub vcl_miss {
  if (req.method == "PURGE") {
    purge;
    return (synth(200, "Purged"));
  }
}

sub vcl_backend_response {
    if (bereq.url ~ "(?i)\.(png|gif|jpeg|jpg|ico|swf|css|js)(\?[a-z0-9]+)?$") {
    unset beresp.http.set-cookie;
    set beresp.ttl   = 365d;
  }
  else if (beresp.http.Cache-Control) {
    unset beresp.http.Expires;
  }
  if (beresp.status == 301) {
    set beresp.ttl = 1h;
    return(deliver);
  }
  set beresp.grace = 1h;
}


sub vcl_deliver {
    # Happens when we have all the pieces we need, and are about to send the
    # response to the client.
    # 
    # You can do accounting or modifying the final object here.
    if (obj.hits > 0) {
    set resp.http.X-Varnish-Cache = "WE GOT A HIT";
    }
    else {
    set resp.http.X-Varnish-Cache = "MISSED ME";
    }
}

#sub vcl_backend_error {
#     set resp.http.Content-Type = "text/html; charset=utf-8";
#     set resp.http.Retry-After = "5";
#     synthetic {"
#<?xml version="1.0" encoding="utf-8"?>
#<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
#  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
#<html>
#   <head>
#     <title>"} + beresp.status + " " + beresp.response + {"</title>
#   </head>
#   <body>
#     <h1>Error "} + beresp.status + " " + beresp.response + {"</h1>
#     <p>"} + beresp.response + {"</p>
#     <h3>Guru Meditation:</h3>
#     <p>XID: "} + req.xid + {"</p>
#     <hr>
#     <p>Varnish cache server</p>
#   </body>
#</html>
#"};
#     return (deliver);
#}

