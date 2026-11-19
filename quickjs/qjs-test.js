import * as std from 'std';
console.log('QJS_OK', 1 + 2, new Date().toISOString());
console.log('uri=' + std.getenv('REQUEST_URI'));
console.log('method=' + std.getenv('REQUEST_METHOD'));
