# umedcta-formalization — Project Instructions for Claude

## What this repository is

This is the Prolog and manuscript formalization archive for *Understanding Mathematics as
an Emancipatory Discipline: A Critical Theory Approach* (UMEDCTA) — a philosophical
manuscript by Tio Savich.

This repo was split from `TioSavich/UMEDCTA` in March 2026. The formalization work
belongs here; the public-facing portfolio tools belong in `TioSavich/umedcta-portfolio`.
The design doc for that decision is at
`~/.gstack/projects/TioSavich-UMEDCTA/tio-main-design-20260319-114754.md`.

## What's here

- `prolog/` — Prolog formalization of reasoning strategies, incompatibility semantics,
  dialectical engine, and curriculum processing
- `prolog/Modal_Logic/` — LaTeX appendices connecting formalization to manuscript claims
- `prolog/Prolog/math/` — formal models of children's arithmetic strategies (Russell)

## Status: research archive

This material is not portfolio-ready and should not be presented as such. The Prolog
formalizations model specific reasoning structures — they do not implement Hegelian
dialectics or post-structural insights in any philosophically overreaching sense. The
interesting thing is where the formalizations fail or oversimplify; that breakdown is the
point of contact with the manuscript's central argument.

Do not surface `synthesized_paper.md` in any public-facing context — it is a ChatGPT
draft with no standing.

## The central argument (context)

The manuscript's claim: formalisms break productively (the Hegelian Infinite) when they
are *consistent* under Brandom's interpretation of Kant's synthetic unity of
apperception. The Prolog work is not a proof of this claim — it is a representation that
can be made to behave like the relevant reasoning strategies under controlled conditions.
The interesting thing is where the representation fails.

## Voice commitments

When writing documentation, README files, or comments in this repo:

- No puffery: `A powerful framework for...` → describe what it actually does
- No overclaiming: never say the code "implements" or "demonstrates" Hegelian or
  post-structural concepts in a philosophically significant sense
- Epistemic humility: the formalization is a tool for noticing where formalization stops

The full **epistemic-code-voice** skill (`/epistemic-code-voice`) applies to any
user-facing prose (README, docs). It does not apply to Prolog or Python code logic.

## gstack

Use the `/browse` skill from gstack for all web browsing. Never use
`mcp__claude-in-chrome__*` tools.

Available gstack skills:
- `/office-hours` - Office hours discussion
- `/plan-eng-review` - Engineering review planning
- `/review` - Code review
- `/ship` - Ship a change
- `/browse` - Web browsing
