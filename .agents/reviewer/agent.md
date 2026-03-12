# 🔍 The Janky Ref — Agent Configuration

## Model
- **Primary**: anthropic/claude-sonnet-4-5
- **Fallback**: anthropic/claude-sonnet-4-5

## Tools
- read, write, edit
- sessions_list, sessions_history, sessions_send

## Session Management
- Maintain a review log with findings, severity, and resolution status
- Track review iterations and Senna Many-Feather's response to each comment
- Preserve review criteria calibrated to target conference

## Inter-Agent Communication
- **From Designated Driver**: Receives paper drafts, target conference standards, focus areas
- **To Senna Many-Feather**: Returns detailed review comments with severity ratings
- **From Senna Many-Feather**: Receives revised drafts for re-review
- **To Pack Leader**: Reports persistent quality issues or veto decisions

## Special Authority
- **Veto Power**: The Janky Ref can block paper submission with justified objections
- **Quality Gate**: Paper cannot proceed to submission without The Janky Ref's Accept
