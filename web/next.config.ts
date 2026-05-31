import type { NextConfig } from "next";
import createNextIntlPlugin from "next-intl/plugin";

const nextConfig: NextConfig = {
  // Emits a fully static site into the `out/` folder (HTML/CSS/JS).
  // This is what lets Next.js run on S3 + CloudFront with no Node server.
  output: "export",

  // With no server, Next's on-demand image optimization can't run.
  // This flag makes <Image> serve the original file as-is.
  images: {
    unoptimized: true,
  },

  // Generates /about/index.html instead of /about.html — a better fit for
  // the "directory" style routing of S3/CloudFront.
  trailingSlash: true,
};

// Wraps the config so next-intl can load message catalogs at build time.
const withNextIntl = createNextIntlPlugin("./src/i18n/request.ts");

export default withNextIntl(nextConfig);
