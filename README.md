# GUY — Relatório Técnico em LaTeX

Documento acadêmico do **GUY**, uma extensão do Visual Studio Code que analisa
código-fonte Python e gera o Grafo de Fluxo de Controle (GFC). O relatório foi
desenvolvido no Bacharelado em Ciência da Computação do IFSP — Câmpus São João
da Boa Vista, na modalidade de relatório técnico.

- Autor: Gabriel Maia Miguel
- Orientador: Prof. Dr. Breno Lisi Romano
- Implementação: [gm64x/guy-vscode](https://github.com/gm64x/guy-vscode)

## Organização

```text
main.tex                 documento raiz
capitulos/               conteúdo textual do relatório
pretextuais/             capa, folha de rosto, documentos institucionais e resumo
referencias.bib          referências bibliográficas
fontes/codigos/          códigos usados nos exemplos e experimentos
fontes/imagens/          figuras, experimentos e diagramas
.config/tex/             configuração e estilo bibliográfico do modelo
.config/infra/docker/    build reproduzível do documento
.pdf/                   saída local da compilação (não versionada)
.github/                 automação de validação e publicação
```

Novos capítulos devem ficar em `capitulos/` e ser incluídos por `main.tex`.
Elementos anteriores ao texto devem ficar em `pretextuais/`. Arquivos auxiliares
e PDFs gerados não devem ser versionados.

## Validação e PDF

O GitHub Actions é a fonte oficial da validação. O fluxo detecta os arquivos
afetados, compara o SHA-256 de cada fonte de diagrama e renderiza somente os
arquivos alterados. Antes de compilar, também calcula um hash das entradas do
repositório e reutiliza o PDF em cache quando o conteúdo é idêntico. Actions de
terceiros são fixadas por commit e o cache do BuildKit é compartilhado entre
execuções que realmente precisam compilar.

Em uma execução concluída na branch principal, o PDF é anexado diretamente à
**Release** criada pelo workflow. Pull requests validam o documento sem
publicar release nem versionar o PDF.
O acionamento manual permite forçar todos os estágios, renderizar somente as
imagens ou autorizar a publicação.

## Compilação local

O build reproduzível usa Docker e exporta somente o PDF final:

```bash
docker buildx build \
  --file .config/infra/docker/Dockerfile \
  --output type=local,dest=.pdf \
  .
```

O resultado fica em `.pdf/main.pdf`. O mesmo Dockerfile é usado pelo CI,
evitando diferenças entre a compilação local e a publicada pelo GitHub Actions.
O estágio de compilação usa Debian por sua compatibilidade com os pacotes do
TeX Live; o estágio entregue usa `scratch` e contém somente o PDF.

O Dockerfile também aceita projetos com outro arquivo raiz ou nome de saída:

```bash
docker buildx build \
  --build-arg LATEX_ROOT=relatorio.tex \
  --build-arg OUTPUT_NAME=relatorio.pdf \
  --file .config/infra/docker/Dockerfile \
  --output type=local,dest=.pdf \
  .
```

## Action reutilizável

A Action de build pode ser usada em outro repositório LaTeX. Após publicar uma
tag estável deste repositório, referencie-a assim (em projetos de terceiros,
prefira trocar `v1` pelo SHA completo da versão revisada):

```yaml
steps:
  - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
  - uses: gm64x/guy-tex/.github/actions/build-latex@v1
    with:
      root-file: main.tex
      output-dir: .pdf
      output-name: main.pdf
```

Ela primeiro tenta restaurar um PDF identificado pelo hash dos arquivos do
repositório. Em caso de cache miss, configura o Buildx, reaproveita o cache de
camadas do GitHub Actions, usa o Dockerfile versionado neste projeto e verifica
se o PDF foi realmente gerado. O input `force-build: true` ignora o acerto do
cache. Um Dockerfile próprio também pode ser informado pelo input `dockerfile`,
desde que aceite os argumentos `LATEX_ROOT`, `OUTPUT_NAME` e `PDF_VERSION`.

## Diagramas e imagens

As fontes Mermaid e PlantUML ficam em `fontes/imagens/diagramas/`. O CI mantém
em cache um manifesto com o SHA-256 de cada fonte e atualiza somente os PNGs
novos ou alterados; saídas de fontes removidas também são excluídas. Mudanças na
versão do renderizador ou no próprio script invalidam os hashes. As demais
figuras devem ser armazenadas na categoria apropriada dentro de
`fontes/imagens/` e referenciadas por rótulos LaTeX, evitando números de seção
ou figura escritos manualmente.

## Documentos institucionais

O repositório inclui modelos da ficha catalográfica e da ata de defesa. Quando
as versões oficiais estiverem disponíveis, substitua os arquivos existentes,
mantendo exatamente estes caminhos e nomes:

```text
pretextuais/institucionais/fichaCatalografica.pdf
pretextuais/institucionais/ataDefesa.pdf
```

## Modelo institucional

O projeto utiliza o Template LaTeX — Relatório Técnico — IFSP-SBV, baseado em
`abnTeX2`, versão 1.6.5 de 17/11/2025, desenvolvido pelo Prof. Dr. David Buzatto.
O conteúdo permanece em revisão até a aprovação do autor e do orientador.
