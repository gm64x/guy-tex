# GUY — Relatório Técnico em LaTeX

Código-fonte do relatório técnico **“GUY: ferramenta de análise de códigos-fonte para gerar, automaticamente, o Grafo de Fluxo de Controle (GFC)”**, desenvolvido como trabalho do Bacharelado em Ciência da Computação do IFSP — Câmpus São João da Boa Vista.

- **Autor:** Gabriel Maia Miguel
- **Orientador:** Prof. Dr. Breno Lisi Romano
- **Área:** Engenharia de Software
- **Documento:** Relatório Técnico conforme o modelo institucional baseado em `abnTeX2`

## Sobre o trabalho

O projeto GUY propõe uma ferramenta integrada ao Visual Studio Code para analisar código-fonte Python e gerar Grafos de Fluxo de Controle. O documento apresenta fundamentação teórica, metodologia, implementação, experimentos de validação, análise dos resultados e conclusões.

## Arquivo principal

O documento é compilado a partir de:

```text
Template Latex - Relatorio Tecnico - IFSP - SBV.tex
```

Esse arquivo inclui os elementos pré-textuais e os capítulos separados:

- `01Capa.tex`
- `02FolhaDeRosto.tex`
- `03FichaCatalografica.tex`
- `04AtaDefesa.tex`
- `05Resumo.tex`
- `capitulo01Introducao.tex`
- `capitulo02ConsideracoesGerais.tex`
- `capitulo03Metodologia.tex`
- `capitulo04AnaliseDosResultados.tex`
- `capitulo05ConclusoesRecomendacoes.tex`
- `referencias.bib`

## Requisitos

É necessária uma distribuição LaTeX com os pacotes utilizados pelo projeto, incluindo:

- `abnTeX2`;
- suporte a BibTeX;
- `latexmk` recomendado para automatizar as etapas de compilação.

Distribuições comuns:

- TeX Live em Linux;
- MiKTeX ou TeX Live em Windows;
- MacTeX em macOS.

## Compilação

Com `latexmk`:

```bash
latexmk -pdf "Template Latex - Relatorio Tecnico - IFSP - SBV.tex"
```

Para remover arquivos auxiliares:

```bash
latexmk -c
```

Sem `latexmk`, execute a sequência tradicional:

```bash
pdflatex "Template Latex - Relatorio Tecnico - IFSP - SBV.tex"
bibtex "Template Latex - Relatorio Tecnico - IFSP - SBV"
pdflatex "Template Latex - Relatorio Tecnico - IFSP - SBV.tex"
pdflatex "Template Latex - Relatorio Tecnico - IFSP - SBV.tex"
```

O número de execuções pode variar até que referências, sumário, citações e numeração estejam estabilizados.

## Organização de imagens

Figuras utilizadas no relatório devem ser armazenadas na pasta `imagens/` e referenciadas pelos capítulos correspondentes. Antes da entrega, verifique:

- se nenhuma figura ainda aponta para um placeholder;
- se todas as imagens possuem legenda, fonte e rótulo;
- se todas as referências cruzadas aparecem corretamente no PDF;
- se não existem arquivos ausentes durante a compilação.

## Relação com a aplicação

A implementação da ferramenta está no repositório `gm64x/guy-vscode`. O repositório agregador `gm64x/bcc-guy` referencia tanto a aplicação quanto este documento por meio de submódulos Git.

## Status

Documento acadêmico em desenvolvimento. O conteúdo e os resultados devem ser considerados definitivos somente após revisão do autor e do orientador.