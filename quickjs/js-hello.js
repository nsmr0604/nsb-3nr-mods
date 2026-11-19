import * as std from 'std';

console.log('Content-Type: text/html; charset=utf-8');
console.log('');
console.log('<!doctype html><html><head><meta charset="utf-8"><title>QuickJS CGI</title></head><body>');
console.log('<h1>QuickJS CGI OK</h1>');
console.log('<p>time=' + new Date().toISOString() + '</p>');
console.log('<p>uri=' + std.getenv('REQUEST_URI') + '</p>');
console.log('<p>method=' + std.getenv('REQUEST_METHOD') + '</p>');
console.log('<p>ua=' + std.getenv('HTTP_USER_AGENT') + '</p>');
console.log('</body></html>');
