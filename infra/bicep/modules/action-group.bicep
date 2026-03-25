// =============================================================================
// Action Group Module
// =============================================================================
// Deploys a default Azure Monitor Action Group for incident routing.
// Supports email, SMS, and webhook/Logic App callback URL integration.
// =============================================================================

@description('Action Group name')
param name string

@description('Azure region for deployment')
param location string

@description('Tags to apply to resources')
param tags object

@description('Action Group short name (max 12 chars)')
@maxLength(12)
param shortName string = 'srelabops'

@description('Email recipients for alert notifications')
param emailReceivers array = []

@description('SMS recipients for alert notifications')
param smsReceivers array = []

@secure()
@description('Optional webhook/Logic App callback URL for incident routing')
param webhookServiceUri string = ''

var hasWebhookReceiver = !empty(webhookServiceUri)

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: name
  location: 'global'
  tags: tags
  properties: {
    enabled: true
    groupShortName: shortName
    emailReceivers: emailReceivers
    smsReceivers: smsReceivers
    webhookReceivers: hasWebhookReceiver
      ? [
          {
            name: 'incident-webhook'
            serviceUri: webhookServiceUri
            useCommonAlertSchema: true
          }
        ]
      : []
  }
}

output actionGroupId string = actionGroup.id
output hasWebhookReceiver bool = hasWebhookReceiver
