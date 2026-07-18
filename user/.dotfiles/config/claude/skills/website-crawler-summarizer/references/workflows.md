# Crawl Workflows

## Competitor Analysis

```
"Crawl competitor site (max 20 pages, product/service pages only).
Extract: services, pricing mentions, features, key messaging.
Create structured comparison report."
```

Steps: crawl → extract structured fields → deduplicate → LLM summarize → report.

---

## Documentation Mirror

```
"Mirror https://docs.example.com — crawl all /docs/* pages,
download referenced images, convert to Markdown,
preserve link structure, generate offline index."
```

Steps: fetch sitemap or crawl breadth-first → convert each page with markitdown or Readability → rewrite internal links → write index.md.

---

## Research Aggregation

```
"Fetch these 20 URLs. Extract main content, key findings, quotes,
citations. Group by topic. Output annotated bibliography as Markdown."
```

Steps: parallel fetch → Readability extract → LLM summarize+tag → group by topic → structured output.

---

## Change Detection

```
"Fetch current version of https://example.com/pricing.
Compare with last week's version. Highlight changes. Generate change report."
```

Steps: fetch current → store snapshot → diff against prior → LLM narrate changes.

---

## Bulk File Conversion (markitdown)

```
"Convert all .docx and .pptx files in this folder to Markdown."
```

```bash
for f in *.docx *.pptx; do
  uvx markitdown "$f" -o "${f%.*}.md"
done
```

For PDFs with poor text layer, add `-d -e <azure-endpoint>`.
