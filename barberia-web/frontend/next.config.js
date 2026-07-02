const path = require('path');

/** @type {import('next').NextConfig} */
const nextConfig = {
  outputFileTracingRoot: path.join(__dirname),
  async rewrites() {
    const apiUrl = process.env.NEXT_PUBLIC_API_URL?.trim();
    if (apiUrl) {
      return [{ source: '/uploads/:path*', destination: `${apiUrl.replace(/\/$/, '')}/uploads/:path*` }];
    }
    return [{ source: '/uploads/:path*', destination: '/api/uploads/:path*' }];
  },
};

module.exports = nextConfig;
