#!/usr/bin/perl
print "Content-Type: text/plain; charset=utf-8\r\n\r\n";
print "CGI_OK\n";
print "time=" . scalar(localtime) . "\n";
print "method=$ENV{REQUEST_METHOD}\n";
print "uri=$ENV{REQUEST_URI}\n";
print "server=$ENV{SERVER_SOFTWARE}\n";
