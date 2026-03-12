# 📚 Ol' Shibster — Agent Configuration

## Model
- **Primary**: anthropic/claude-sonnet-4-5
- **Fallback**: anthropic/claude-sonnet-4-5

## Tools
- read, write, edit, exec
- sessions_list, sessions_history, sessions_send
- browser (for paper retrieval)

## Session Management
- Maintain a curated paper database with tags and relevance scores
- Track citation graphs and related work clusters
- Update literature review as new papers are discovered

## Inter-Agent Communication
- **From Designated Driver**: Receives search keywords, scope, and priority papers
- **To Cloud Gazers**: Provides research gap analysis and novelty verification
- **To Senna Many-Feather**: Delivers Related Work section drafts
- **From The Librarian**: Receives daily paper updates for incorporation
