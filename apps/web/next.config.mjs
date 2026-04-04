/** @type {import("next").NextConfig} */
const nextConfig = {
  transpilePackages: ["@hanwoo-tmr/contracts"],
  experimental: {
    externalDir: true
  }
};

export default nextConfig;