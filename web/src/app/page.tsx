import { routing } from "@/i18n/routing";

// Static root page ("/"). In an export there is no middleware to redirect to a
// locale, so we render a tiny HTML page with a <meta refresh>. It works even
// without JS and points search engines at the canonical localized URL.
export default function RootPage() {
  const target = `/${routing.defaultLocale}/`;
  return (
    <html lang={routing.defaultLocale}>
      <head>
        <meta httpEquiv="refresh" content={`0; url=${target}`} />
        <link rel="canonical" href={target} />
      </head>
      <body>
        <noscript>
          <a href={target}>Continue to the site</a>
        </noscript>
      </body>
    </html>
  );
}
