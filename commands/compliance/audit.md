# /compliance:audit

Run a structured audit aligned to the EU AI Act and ISO/IEC 42001 for an AI system, project, or organization.

## Arguments
- scope: short description of the audit target (system, model, org unit)
- use_case: intended use, users, and operational context
- jurisdiction: primary legal jurisdiction(s)
- standards: list of standards (default: ["EU AI Act", "ISO/IEC 42001"])
- risk_level: declared risk level if known (e.g., minimal, limited, high, prohibited)
- evidence_sources: locations for policies, logs, tests, model cards, SBOMs
- stakeholders: owners, DPO, security, legal, product
- timeline: target audit window and milestones

## Inputs
Provide or link to:
- system overview and architecture
- model inventory and data lineage
- risk assessment or DPIA (if available)
- monitoring, incident, and change logs
- security and privacy controls
- vendor and third-party dependencies

## Process
1. Intake and scope confirmation
2. Regulatory mapping and standard selection
3. Evidence collection plan
4. Control-by-control assessment
5. Gap analysis and risk rating
6. Remediation recommendations
7. Final report and sign-off

## EU AI Act Coverage Map
- Risk classification and justification
- Data governance and quality
- Technical documentation and recordkeeping
- Transparency, user information, and labeling
- Human oversight requirements
- Accuracy, robustness, and cybersecurity
- Post-market monitoring and incident reporting

## ISO/IEC 42001 Coverage Map
- AI management system scope and context
- Leadership and accountability
- Risk management framework
- Resource and competence management
- Operational planning and controls
- Performance evaluation and continuous improvement

## Audit Checklist Template
- Scope and boundaries confirmed
- Risk classification documented
- Model and data lineage documented
- Data protection and privacy controls
- Security controls and threat model
- Human oversight procedures
- Monitoring, logging, and incident response
- Change management and versioning
- Vendor risk management
- Documentation completeness

## Findings Template
- finding_id:
- title:
- severity: (low, medium, high, critical)
- requirement: (EU AI Act / ISO 42001 clause)
- evidence:
- gap:
- impact:
- recommendation:
- owner:
- due_date:

## Deliverables
- Audit plan
- Evidence map
- Findings register
- Remediation roadmap
- Final audit report

## Security Agent Integration
- Notify security agent for:
  - threat model review
  - penetration and red-team readiness
  - SBOM and dependency review
- Provide artifacts to security agents:
  - architecture diagrams
  - data flow diagrams
  - model cards
  - incident history

## Output Template
- Executive summary
- Scope and methodology
- Standards mapping
- Key findings
- Risk ratings
- Remediation plan
- Sign-off and next steps
