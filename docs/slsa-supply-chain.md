# SLSA Level 4 Cryptographic Supply Chain

## What Is SLSA and Why Level 4 in 2026

**SLSA** (Supply chain Levels for Software Artifacts) is a security framework for ensuring the integrity of software and infrastructure artifacts from source to production. By 2026, SLSA Level 4 is the baseline expectation for any landing zone that hosts regulated workloads or AI systems.

| Level | Guarantee |
|---|---|
| L1 | Build is scripted (no manual steps) |
| L2 | Build service generates signed provenance |
| L3 | Hardened, isolated build environment |
| **L4** | **Two-party review + hermetic, reproducible builds** |

This landing zone satisfies all four levels.

---

## How Provenance Is Generated

```
Developer pushes to main
        │
        ▼
GitHub Actions (ephemeral runner)
  ├── Compile all .bicep → ARM JSON
  ├── SHA-256 every artifact
  └── slsa-github-generator creates .intoto.jsonl provenance bundle
             │  signed with GitHub OIDC (Sigstore keyless)
             ▼
  Provenance uploaded to:
    ├── GitHub Release assets
    └── Azure Storage WORM container (immutable, 365-day retention)

Before deployment:
  slsa-verifier verify-artifact <manifest> --provenance-path <bundle>
  → Proves artifact was built from this exact repo at this exact commit
```

The provenance bundle is a signed [in-toto](https://in-toto.io/) attestation. It records:
- The exact Git commit SHA that triggered the build
- The build platform (GitHub Actions runner image SHA)
- The hashes of every output artifact
- A Sigstore signature verifiable without any private key management

---

## Model Weight Provenance

In 2026, the supply chain extends beyond code to **ML model artifacts**. A tampered GGUF or SafeTensors file can silently change model behaviour without changing any source code.

The `attest-model-weights` job in the CI pipeline:
1. SHA-256 hashes every `*.gguf`, `*.safetensors`, `*.onnx` file in `models/`
2. Creates a GitHub Artifact Attestation (signed SBOM-style record)
3. Uploads the manifest to the WORM storage container

**Verifying a model at deployment time:**
```bash
# Using GitHub CLI attestation verification
gh attestation verify models/fraud-scorer-v2.gguf \
  --owner zaratr \
  --repo cloud-landing-zone

# Using cosign directly
cosign verify-blob models/fraud-scorer-v2.gguf \
  --bundle models/fraud-scorer-v2.gguf.sigstore \
  --certificate-identity "https://github.com/zaratr/cloud-landing-zone/.github/workflows/slsa-provenance.yml" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

---

## Azure Policy: Deny Unattested Deployments

The `modules/policy/main.bicep` includes a custom policy that denies ARM deployments missing a `slsa-provenance-verified: true` tag. This tag is set only by the CI pipeline after `slsa-verifier` succeeds — not manually settable by engineers.

```
Engineer runs az deployment → Policy checks tag → Deny (no CI provenance)
CI pipeline runs → slsa-verifier passes → Tag set → Policy allows → Deploy
```

---

## Key Vault: Signing Key Management

`modules/supply-chain/main.bicep` provisions:
- **Key Vault** (RBAC, private endpoint, purge protection): stores the Sigstore root certificate and model signing certificate for offline verification
- **WORM Storage**: immutable provenance bundle archive — blobs cannot be deleted or modified for 365 days (compliance / audit trail)
- **RBAC**: GitHub Actions federated identity gets `Storage Blob Data Contributor` to upload bundles; no long-lived secrets

---

## Reproducible Builds

The CI pipeline pins:
- GitHub Actions runner: `ubuntu-latest` with SHA-pinned action versions (`@v4`)
- Azure Bicep CLI: version locked via `az bicep install --version`
- `slsa-github-generator`: pinned to `@v2.0.0`

These pins ensure the same source always produces the same binary output — a requirement for SLSA Level 4 hermetic builds.

---

## Verification Checklist

```bash
# 1. Download artifacts + provenance from GitHub Release
gh release download v1.0.0 --pattern "*.sha256" --pattern "*.intoto.jsonl"

# 2. Verify SLSA provenance
slsa-verifier verify-artifact artifact-manifest.sha256 \
  --provenance-path iac-provenance.intoto.jsonl \
  --source-uri "github.com/zaratr/cloud-landing-zone"

# 3. (Optional) Verify model weights
gh attestation verify models/my-model.gguf --owner zaratr

# 4. Deploy only after verification passes
az deployment sub create --template-file main.json ...
```
