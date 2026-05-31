import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Gera um site 100% estático na pasta `out/` (HTML/CSS/JS).
  // É isso que faz o Next.js rodar em S3 + CloudFront sem precisar de servidor Node.
  output: "export",

  // Sem servidor, a otimização de imagens on-demand do Next não roda.
  // Esta flag faz o <Image> servir o arquivo original direto.
  images: {
    unoptimized: true,
  },

  // Gera /sobre/index.html em vez de /sobre.html — combina melhor com o
  // roteamento baseado em "diretório" do S3/CloudFront.
  trailingSlash: true,
};

export default nextConfig;
