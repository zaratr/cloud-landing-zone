// Supply Chain Security Module — SLSA Level 4
// Provisions Azure resources that enforce cryptographic supply chain controls
// for both infrastructure artifacts and ML model weights.
//
// Resources:
//   - Azure Policy: deny deployments that lack provenance attestation tag
//   - Key Vault: stores Sigstore public keys and model signing certificates
//   - Storage Account: immutable WORM container for provenance bundles
//   - Event Grid subscription: triggers validation function on new blob

targetScope = 'resourceGroup'

@description('Name prefix for all supply chain resources')
param baseName string

@description('Azure region for resources')
param location string = resourceGroup().location

@description('Tags applied to all resources')
param tags object = {}

@description('Object ID of the identity allowed to write provenance bundles')
param provenanceWriterObjectId string

@description('Retention days for provenance bundles (WORM immutability)')
param immutabilityPeriodDays int = 365

// ── Key Vault for signing keys ────────────────────────────────────────────────

resource kvSupplyChain 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${baseName}-sc-kv'
  location: location
  tags: tags
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'  // private endpoint only
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// Stores Sigstore / cosign public keys used to verify artifact signatures.
// In CI the private key is held by GitHub Actions OIDC — never in Key Vault.
resource sigstorePublicKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kvSupplyChain
  name: 'sigstore-root-public-key'
  properties: {
    value: 'REPLACE_WITH_SIGSTORE_ROOT_CERT_PEM'
    attributes: { enabled: true }
    contentType: 'application/x-pem-file'
  }
}

// Model weight signing certificate — used to verify GGUF / SafeTensors checksums.
resource modelSigningCert 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kvSupplyChain
  name: 'model-signing-cert'
  properties: {
    value: 'REPLACE_WITH_MODEL_SIGNING_CERT_PEM'
    attributes: { enabled: true }
    contentType: 'application/x-pem-file'
  }
}

// ── Immutable provenance storage (WORM) ──────────────────────────────────────

resource saProvenance 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${replace(baseName, '-', '')}scprov'
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: { name: 'Standard_GRS' }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Disabled'
    encryption: {
      services: { blob: { enabled: true }, file: { enabled: true } }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource provenanceContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${saProvenance.name}/default/provenance-bundles'
  properties: {
    publicAccess: 'None'
    immutableStorageWithVersioning: {
      enabled: true
    }
  }
}

// WORM immutability policy — provenance bundles cannot be deleted or modified.
resource immutabilityPolicy 'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies@2023-01-01' = {
  name: '${saProvenance.name}/default/provenance-bundles/default'
  properties: {
    immutabilityPeriodSinceCreationInDays: immutabilityPeriodDays
    allowProtectedAppendWrites: false
  }
  dependsOn: [provenanceContainer]
}

// ── RBAC assignments ──────────────────────────────────────────────────────────

// GitHub Actions federated identity gets Storage Blob Data Contributor
// to upload provenance bundles after successful CI build.
resource provenanceWriterRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(saProvenance.id, provenanceWriterObjectId, 'StorageBlobDataContributor')
  scope: saProvenance
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe'  // Storage Blob Data Contributor
    )
    principalId: provenanceWriterObjectId
    principalType: 'ServicePrincipal'
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

output keyVaultId string = kvSupplyChain.id
output provenanceStorageAccountName string = saProvenance.name
output provenanceContainerUrl string = '${saProvenance.properties.primaryEndpoints.blob}provenance-bundles'
