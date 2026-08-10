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
pretextuais/             capa, folha de rosto, modelos, anexos e resumo
capitulos/               conteúdo textual do relatório
referencias.bib          referências bibliográficas
estrutura.sty            configuração do modelo
abntex2-custom/          estilo bibliográfico institucional
fontes/                  códigos usados nos exemplos
imagens/                 figuras, experimentos e diagramas
.github/                 automação de validação e publicação
```

Novos capítulos devem ficar em `capitulos/` e ser incluídos por `main.tex`.
Elementos anteriores ao texto devem ficar em `pretextuais/`. Arquivos auxiliares
e PDFs gerados não devem ser versionados.

## Validação e PDF

O GitHub Actions é a fonte oficial da validação. O fluxo separa a execução em
estágios para detectar mudanças, renderizar diagramas, compilar o LaTeX,
publicar o PDF como artifact e, quando autorizado, criar uma release.

Em uma execução concluída, o PDF pode ser obtido na seção **Artifacts** com o
nome `compiled-thesis`. Pull requests validam o documento sem publicar release.
O acionamento manual permite forçar todos os estágios, renderizar somente as
imagens ou autorizar a publicação.

## Compilação local opcional

Para inspeções locais, use uma distribuição com `abnTeX2`, BibTeX e `latexmk`:

```bash
latexmk -pdf main.tex
latexmk -c
```

A aceitação do documento continua sendo determinada pelo CI, que executa a
mesma entrada `main.tex` em ambiente reproduzível.

## Diagramas e imagens

As fontes Mermaid e PlantUML ficam em `imagens/diagramas/`. O CI atualiza as
imagens PNG correspondentes quando necessário. As demais figuras devem ser
armazenadas na categoria apropriada dentro de `imagens/` e referenciadas por
rótulos LaTeX, evitando números de seção ou figura escritos manualmente.

## Documentos institucionais

O repositório inclui modelos da ficha catalográfica e da ata de defesa. Quando
as versões oficiais estiverem disponíveis, substitua os arquivos existentes,
mantendo exatamente estes caminhos e nomes:

```text
pretextuais/modelos/fichaCatalografica.pdf
pretextuais/modelos/ataDefesa.pdf
```

## Modelo institucional

O projeto utiliza o Template LaTeX — Relatório Técnico — IFSP-SBV, baseado em
`abnTeX2`, versão 1.6.5 de 17/11/2025, desenvolvido pelo Prof. Dr. David Buzatto.
O conteúdo permanece em revisão até a aprovação do autor e do orientador.
