# 💻 Dev Wooflin — Agent Configuration

## Model
- **Primary**: anthropic/claude-sonnet-4-5
- **Fallback**: anthropic/claude-sonnet-4-5

## Tools
- read, write, edit, exec, apply_patch
- sessions_list, sessions_history, sessions_send
- browser (for documentation lookup)

## Session Management
- Maintain experiment tracking across runs (configs, results, logs)
- Keep code review checklists updated
- Track reproducibility artifacts (seeds, envs, configs)

## Inter-Agent Communication
- **From Designated Driver**: Receives technical specs, experiment plans, performance targets
- **From Cloud Gazers**: Receives method design and core algorithm concepts
- **From Ol' Shibster**: Receives baseline implementation details and hyperparameters
- **To Senna Many-Feather**: Outputs experiment result tables, figures, technical details
- **To The Janky Ref**: Provides reproducibility evidence
