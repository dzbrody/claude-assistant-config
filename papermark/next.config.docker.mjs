import path from "path";

/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
  reactStrictMode: true,
  pageExtensions: ["js", "jsx", "ts", "tsx", "mdx"],
  transpilePackages: ["@boxyhq/saml-jackson", "@libpdf/core"],
  // Docker build: skip type/lint errors from Vercel-specific code paths
  typescript: { ignoreBuildErrors: true },
  eslint: { ignoreDuringBuilds: true },
  images: {
    minimumCacheTTL: 2592000,
    unoptimized: true,
    remotePatterns: prepareRemotePatterns(),
  },
  skipTrailingSlashRedirect: true,
  // assetPrefix omitted — Vercel-only, breaks Docker CDN assumptions
  async rewrites() {
    const afterFiles = [
      { source: "/oauth/:path*", destination: "/api/oauth/:path*" },
      {
        source: "/.well-known/openid-configuration",
        destination: "/api/oauth/.well-known/openid-configuration",
      },
      {
        source: "/.well-known/oauth-protected-resource",
        destination: "/api/well-known/oauth-protected-resource",
      },
      {
        source: "/.well-known/openai-apps-challenge",
        destination: "/api/well-known/openai-apps-challenge",
      },
    ];
    const beforeFiles = [];
    const apiHost = process.env.NEXT_PUBLIC_API_BASE_HOST;
    if (apiHost) {
      beforeFiles.push(
        {
          source: "/v1/:path*",
          destination: "/api/v1/:path*",
          has: [{ type: "host", value: apiHost }],
        },
        {
          source: "/oauth/:path*",
          destination: "/404",
          has: [{ type: "host", value: apiHost }],
        },
        {
          source: "/.well-known/:path*",
          destination: "/404",
          has: [{ type: "host", value: apiHost }],
        },
        {
          source: "/favicon.ico",
          destination: "/404",
          has: [{ type: "host", value: apiHost }],
        },
        {
          source: "/sitemap.xml",
          destination: "/404",
          has: [{ type: "host", value: apiHost }],
        },
        {
          source: "/robots.txt",
          destination: "/404",
          has: [{ type: "host", value: apiHost }],
        },
      );
    }
    const mcpHost = process.env.NEXT_PUBLIC_MCP_BASE_HOST;
    if (mcpHost) {
      beforeFiles.push(
        {
          source: "/mcp",
          destination: "/api/mcp",
          has: [{ type: "host", value: mcpHost }],
        },
        {
          source: "/.well-known/oauth-protected-resource",
          destination: "/api/well-known/oauth-protected-resource",
          has: [{ type: "host", value: mcpHost }],
        },
        {
          source: "/.well-known/openai-apps-challenge",
          destination: "/api/well-known/openai-apps-challenge",
          has: [{ type: "host", value: mcpHost }],
        },
        {
          source: "/.well-known/openid-configuration",
          destination: "/api/mcp-oauth/openid-configuration",
          has: [{ type: "host", value: mcpHost }],
        },
        {
          source: "/oauth/authorize",
          destination: "/mcp-oauth/authorize",
          has: [{ type: "host", value: mcpHost }],
        },
        {
          source: "/oauth/:path*",
          destination: "/api/oauth/:path*",
          has: [{ type: "host", value: mcpHost }],
        },
      );
    }
    return { beforeFiles, afterFiles, fallback: [] };
  },
  async redirects() {
    const redirects = [
      {
        source: "/",
        destination: "/dashboard",
        permanent: false,
        has: [{ type: "host", value: process.env.NEXT_PUBLIC_APP_BASE_HOST }],
      },
      {
        source: "/settings",
        destination: "/settings/general",
        permanent: false,
      },
      {
        source: "/:path*",
        destination: "https://presentation.atelierbatalla.com/:path*",
        permanent: true,
        has: [{ type: "host", value: "pitchdeck.jonpagels.com" }],
      },
    ];
    const mcpHost = process.env.NEXT_PUBLIC_MCP_BASE_HOST;
    const mcpDocsUrl =
      process.env.NEXT_PUBLIC_MCP_DOCS_URL ??
      "https://www.papermark.com/docs/mcp";
    if (mcpHost) {
      redirects.push({
        source: "/",
        destination: mcpDocsUrl,
        permanent: false,
        has: [{ type: "host", value: mcpHost }],
      });
    }
    return redirects;
  },
  async headers() {
    const isDev = process.env.NODE_ENV === "development";
    return [
      {
        source: "/:path*",
        headers: [
          { key: "Referrer-Policy", value: "no-referrer-when-downgrade" },
          { key: "X-DNS-Prefetch-Control", value: "on" },
          { key: "X-Frame-Options", value: "SAMEORIGIN" },
          {
            key: "Report-To",
            value: JSON.stringify({
              group: "csp-endpoint",
              max_age: 10886400,
              endpoints: [{ url: "/api/csp-report" }],
            }),
          },
          {
            key: "Content-Security-Policy-Report-Only",
            value:
              `default-src 'self' https: ${isDev ? "http:" : ""}; ` +
              `script-src 'self' 'unsafe-inline' 'unsafe-eval' https: ${isDev ? "http:" : ""}; ` +
              `style-src 'self' 'unsafe-inline' https: ${isDev ? "http:" : ""}; ` +
              `img-src 'self' data: blob: https: ${isDev ? "http:" : ""}; ` +
              `font-src 'self' data: https: ${isDev ? "http:" : ""}; ` +
              `frame-ancestors 'none'; ` +
              `connect-src 'self' https: ${isDev ? "http: ws: wss:" : ""}; ` +
              `${isDev ? "" : "upgrade-insecure-requests;"} ` +
              "report-to csp-endpoint;",
          },
        ],
      },
      {
        source: "/view/:path*",
        headers: [{ key: "X-Robots-Tag", value: "noindex" }],
      },
      {
        source: "/login",
        has: [{ type: "query", key: "next" }],
        headers: [{ key: "X-Robots-Tag", value: "noindex, nofollow" }],
      },
      {
        source: "/view/:path*/embed",
        headers: [
          {
            key: "Content-Security-Policy",
            value:
              `default-src 'self' https: ${isDev ? "http:" : ""}; ` +
              `script-src 'self' 'unsafe-inline' 'unsafe-eval' https: ${isDev ? "http:" : ""}; ` +
              `style-src 'self' 'unsafe-inline' https: ${isDev ? "http:" : ""}; ` +
              `img-src 'self' data: blob: https: ${isDev ? "http:" : ""}; ` +
              `font-src 'self' data: https: ${isDev ? "http:" : ""}; ` +
              "frame-ancestors *; " +
              `connect-src 'self' https: ${isDev ? "http: ws: wss:" : ""}; ` +
              `${isDev ? "" : "upgrade-insecure-requests;"}`,
          },
          { key: "X-Robots-Tag", value: "noindex" },
        ],
      },
      {
        source: "/services/:path*",
        has: [{ type: "host", value: process.env.NEXT_PUBLIC_WEBHOOK_BASE_HOST }],
        headers: [{ key: "X-Robots-Tag", value: "noindex" }],
      },
      {
        source: "/api/webhooks/services/:path*",
        headers: [{ key: "X-Robots-Tag", value: "noindex" }],
      },
      {
        source: "/unsubscribe",
        headers: [{ key: "X-Robots-Tag", value: "noindex" }],
      },
    ];
  },
  experimental: {
    optimizePackageImports: ["lucide-react", "@tremor/react", "date-fns", "lodash"],
    missingSuspenseWithCSRBailout: false,
    serverComponentsExternalPackages: ["oidc-provider", "koa"],
  },
  webpack: (config, { isServer }) => {
    // oidc-provider / koa use dynamic requires webpack can't analyze — keep external
    if (isServer) {
      const externals = Array.isArray(config.externals)
        ? config.externals
        : [config.externals].filter(Boolean);
      externals.push("oidc-provider", "koa");
      config.externals = externals;
    }

    config.resolve.alias = {
      ...config.resolve.alias,
      // Map ALL @/ee/* imports to the stub file.
      // Trailing-$ means exact match; without it, webpack prefix-matches sub-paths too.
      "@/ee": path.resolve("/app/ee-stub.tsx"),
      // Explicit prefix match for all sub-paths: @/ee/features/..., @/ee/stripe/... etc.
      "@/ee/": path.resolve("/app/ee-stub.tsx"),
      // Original: optional deps not present in Docker
      "@google-cloud/kms": false,
      "@google-cloud/secret-manager": false,
      mongodb: false,
      mysql: false,
      "react-native-sqlite-storage": false,
      aws4: false,
      "@sap/hana-client": false,
      "@sap/hana-client/extension/Stream": false,
      "hdb-pool": false,
      // Docker: enterprise / Vercel / Stripe features unavailable self-hosted
      "@react-email/components": false,
      stripe: false,
      "@ai-sdk/google-vertex": false,
      "@ai-sdk/openai": false,
      "@trigger.dev/sdk": false,
      "@tus/s3-store": false,
      "@tus/server": false,
      "@upstash/ratelimit": false,
      "@vercel/edge-config": false,
      "@vercel/functions": false,
      "@calcom/embed-react": false,
    };

    config.resolve.fallback = {
      ...config.resolve.fallback,
      fs: false,
      net: false,
      tls: false,
    };

    // Suppress critical dependency warnings from dynamic requires (Jackson, koa)
    config.module = {
      ...config.module,
      exprContextCritical: false,
    };

    return config;
  },
};

function prepareRemotePatterns() {
  const patterns = [
    { protocol: "https", hostname: "assets.papermark.io" },
    { protocol: "https", hostname: "cdn.papermarkassets.com" },
    { protocol: "https", hostname: "d2kgph70pw5d9n.cloudfront.net" },
    { protocol: "https", hostname: "pbs.twimg.com" },
    { protocol: "https", hostname: "media.licdn.com" },
    { protocol: "https", hostname: "lh3.googleusercontent.com" },
    { protocol: "https", hostname: "www.papermark.io" },
    { protocol: "https", hostname: "app.papermark.io" },
    { protocol: "https", hostname: "www.papermark.com" },
    { protocol: "https", hostname: "app.papermark.com" },
    { protocol: "https", hostname: "faisalman.github.io" },
    { protocol: "https", hostname: "d36r2enbzam0iu.cloudfront.net" },
    { protocol: "https", hostname: "d35vw2hoyyl88.cloudfront.net" },
  ];

  if (process.env.NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST)
    patterns.push({ protocol: "https", hostname: process.env.NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST });
  if (process.env.NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST)
    patterns.push({ protocol: "https", hostname: process.env.NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST });
  if (process.env.NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST_US)
    patterns.push({ protocol: "https", hostname: process.env.NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST_US });
  if (process.env.NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST_US)
    patterns.push({ protocol: "https", hostname: process.env.NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST_US });

  return patterns;
}

export default nextConfig;
