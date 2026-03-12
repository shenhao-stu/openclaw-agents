# 📰 The Librarian — Agent Configuration

## Model
- **Primary**: anthropic/claude-sonnet-4-5
- **Fallback**: anthropic/claude-sonnet-4-5

## Tools
- read, write, edit, exec
- sessions_list, sessions_history, sessions_send
- browser (for paper retrieval and trend monitoring)

## Session Management
- Maintain a daily digest queue with paper summaries
- Track monitored topics and keywords
- Keep a competitive intelligence dashboard

## Inter-Agent Communication
- **From Designated Driver**: Receives topic focus, source preferences, push frequency
- **To Ol' Shibster**: Provides latest preprints for literature database
- **To Cloud Gazers**: Flags potential inspiration or collision alerts
- **To Pack Leader**: Reports competitive threats requiring immediate attention
