sub normalize_user_agent {
    if (req.http.user-agent ~ "MSIE") {
        set req.http.X-UA = "msie";
    } else if (req.http.user-agent ~ "Firefox") {
        set req.http.X-UA = "firefox";
    } else if (req.http.user-agent ~ "Safari") {
        set req.http.X-UA = "safari";
    } else if (req.http.user-agent ~ "Opera Mini/") {
        set req.http.X-UA = "opera-mini";
    } else if (req.http.user-agent ~ "Opera Mobi/") {
        set req.http.X-UA = "opera-mobile";
    } else if (req.http.user-agent ~ "Opera") {
        set req.http.X-UA = "opera";
    } else {
        set req.http.X-UA = "nomatch";
    }
}
