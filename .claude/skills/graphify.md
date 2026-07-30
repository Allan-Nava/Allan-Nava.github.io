---
name: graphify
description: Analyze repository structure with graphify and generate code graph visualization
when_to_use: When you need to understand the codebase structure, visualize dependencies, or generate a dependency graph of the project
---

# Graphify Analysis

Analyze the repository using the `graphify` CLI tool to generate a code graph visualization.

## What this skill does

- Runs `graphify` on the project directory to detect structure and dependencies
- Generates JSON node/edge data representing the code graph
- Outputs visualization data to `graphify-out/` directory
- Can be used to understand project architecture, dependencies, and relationships

## Usage

Run graphify on the current project:

```bash
graphify .
```

This will:
1. Analyze the code structure
2. Generate graph data in `graphify-out/` directory
3. Create node and edge JSON files
4. Generate labels and metadata

## Output

The `graphify-out/` directory contains:
- `.graphify_root` - root directory marker
- `.graphify_labels.json` - node labels and metadata
- `.graphify_chunk_*.json` - chunked graph data (nodes and edges)
- `.graphify_detect.json` - detection results

## Notes

- Results are cached in `graphify-out/`
- Add `graphify-out/` to `.gitignore` to avoid committing analysis artifacts
- Use the generated data for documentation, visualization, or architecture analysis
