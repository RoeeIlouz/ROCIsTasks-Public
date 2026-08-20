import json
import sys
from pathlib import Path

try:
    from graphify.detect import detect_incremental, save_manifest
    from graphify.extract import collect_files, extract
    from graphify.build import build_merge
    from graphify.cluster import cluster, score_all
    from graphify.analyze import god_nodes, surprising_connections, suggest_questions
    from graphify.report import generate
    from graphify.export import to_json
except ImportError as e:
    print(f"Graphify import error: {e}")
    sys.exit(1)

root = Path('.')
inc = detect_incremental(root)
new_total = inc.get('new_total', 0)
deleted = list(inc.get('deleted_files', []))
print(f"Incremental detection: {new_total} changed files, {len(deleted)} deleted files")

if new_total == 0 and not deleted:
    print("No changes to update in graphify.")
    sys.exit(0)

# Collect code files
new_files = inc.get('new_files', {})
code_files = []
for f in new_files.get('code', []):
    p = Path(f)
    code_files.extend(collect_files(p) if p.is_dir() else [p])

ast_result = {'nodes': [], 'edges': [], 'input_tokens': 0, 'output_tokens': 0}
if code_files:
    print(f"Extracting AST for {len(code_files)} code files...")
    ast_result = extract(code_files, cache_root=root)
    print(f"AST: {len(ast_result['nodes'])} nodes, {len(ast_result['edges'])} edges")

prune = list(deleted) or None
G = build_merge(
    [ast_result],
    graph_path='graphify-out/graph.json',
    prune_sources=prune,
    root='.',
    directed=False,
)
print(f"Merged graph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges")

communities = cluster(G)
cohesion = score_all(G, communities)
tokens = {'input': 0, 'output': 0}
gods = god_nodes(G)
surprises = surprising_connections(G, communities)
labels = {cid: f"Community {cid}" for cid in communities}
questions = suggest_questions(G, communities, labels)

to_json(G, communities, 'graphify-out/graph.json', force=True)
detection_dict = {
    'total_files': inc.get('total_files', len(inc.get('files', {}))),
    'total_words': inc.get('total_words', 0),
}
report = generate(G, communities, cohesion, labels, gods, surprises, detection_dict, tokens, '.', suggested_questions=questions)
Path('graphify-out/GRAPH_REPORT.md').write_text(report, encoding="utf-8")
save_manifest(inc.get('files', {}), root='.')
print("Graphify update complete successfully!")
