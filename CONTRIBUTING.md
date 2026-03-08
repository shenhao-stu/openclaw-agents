# Contributing to OpenClaw Agents

Thank you for your interest in contributing to OpenClaw Agents! 🦞

## How to Contribute

### Reporting Issues

- Use GitHub Issues to report bugs or request features
- Include steps to reproduce, expected behavior, and actual results
- Label issues appropriately (`bug`, `enhancement`, `agent-config`, etc.)

### Adding New Agent Configurations

1. **Fork** this repository
2. **Create a branch**: `git checkout -b agent/your-agent-name`
3. Create agent files following the [Agent Structure Guide](#agent-structure-guide)
4. Update `agents.yaml` manifest and keep it in sync with `setup.sh` validation expectations
5. Run `make test` (or at minimum the shell checks) before submitting
6. Submit a **Pull Request**

### Agent Structure Guide

Each agent requires three core files in `.agents/<agent_name>/`:

| File | Purpose |
|------|---------|
| `soul.md` | Agent personality, capabilities, and decision-making principles |
| `agent.md` | Technical configuration, tool permissions, model preferences |
| `user.md` | Context about the user/team this agent serves |

### Modifying Existing Agents

- Keep changes backward-compatible when possible
- Document why changes are needed in the PR
- Test with `openclaw agents list --bindings` after changes

### Adding Workflow Templates

1. Create workflow file in `.agents/workflows/`
2. Include YAML frontmatter with `description`
3. Document all phases, roles, and expected outputs
4. Reference agents by their standard IDs

## Code of Conduct

- Be respectful and constructive
- Focus on the shared goal of building better AI workflows
- Provide actionable feedback in reviews

## Style Guide

- Use **Markdown** for all documentation
- Keep agent names lowercase with hyphens (e.g., `data-engineer`)
- Use emoji consistently for agent identification
- Write documentation in Chinese (primary) with English technical terms

## Questions?

Open a GitHub Discussion or contact the maintainers.
