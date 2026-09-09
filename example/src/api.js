import http from 'node:http';
export function createServer() {
  return http.createServer((req, res) => { res.statusCode = 404; res.end('not found'); });
}
