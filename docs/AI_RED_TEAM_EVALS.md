# AI Red-Team / Evaluation Baseline

This document defines the deterministic V1 adversarial evaluation scope for Cycle's AI runtime.

The suite must verify that untrusted or disallowed context never crosses the AI Context Firewall, unsupported claims fail evidence validation, and candidate outputs proposing autonomous diagnosis, prescribing, treatment changes, or clinical-record writes are rejected before completion. Doctor-review-required outputs must remain explicitly review-gated.

Representative adversarial categories:

- context exfiltration attempts using blocked or unapproved fields;
- unsupported clinical claims without evidence;
- references to evidence IDs that are not available in the request context;
- autonomous diagnosis proposals;
- autonomous prescribing proposals;
- autonomous treatment-change proposals;
- direct clinical-record write attempts;
- prompt-injection-like text inside otherwise allowed context, proving policy is enforced by structured context/action validation rather than trusting model text;
- deterministic behavior across repeated equivalent runs;
- fail-closed audit-stage behavior.

These are deterministic engineering evals of the product safety boundary. They are not a claim of model certification, clinical validation, or external red-team assessment.
