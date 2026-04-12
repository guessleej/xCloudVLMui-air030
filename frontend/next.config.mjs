// next.config.mjs — Next.js 14 設定（.ts 格式僅 Next.js 15+ 支援）
/** @type {import('next').NextConfig} */
const nextConfig = {
  // 允許將 live-vlm-webui 嵌入 iframe
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Frame-Options",        value: "SAMEORIGIN" },
          { key: "X-Content-Type-Options",  value: "nosniff" },
        ],
      },
    ];
  },

  // 反向代理：/vlm-api/* → llama.cpp :8080
  async rewrites() {
    return [
      {
        source:      "/vlm-api/:path*",
        destination: `${process.env.LLAMA_BASE_URL || "http://localhost:8080"}/:path*`,
      },
      {
        source:      "/backend-api/:path*",
        destination: `${process.env.BACKEND_URL || "http://localhost:8000"}/:path*`,
      },
    ];
  },

  // 允許外部圖片域名（Next.js 14 使用 remotePatterns）
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "avatars.githubusercontent.com", pathname: "/**" },
      { protocol: "https", hostname: "lh3.googleusercontent.com",    pathname: "/**" },
      { protocol: "https", hostname: "*.googleusercontent.com",       pathname: "/**" },
    ],
  },

  // 關閉嚴格模式以相容 WebRTC iframe
  reactStrictMode: false,

  // Docker 多階段建置需要 standalone 輸出
  output: "standalone",
};

export default nextConfig;
